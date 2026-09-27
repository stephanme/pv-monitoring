#!/usr/bin/env bash
#
# check_pr.sh — Check whether a pv-monitoring PR can be merged.
#
# A PR is mergeable only if every container image that the PR introduces or
# changes is already mirrored to the local registry (registry.fritz.box)
# for all cluster architectures (linux/amd64 + linux/arm64).
#
# Handles:
#   * rancher HelmChart resources (helm.cattle.io/v1): resolves the images the
#     new chart version pulls by rendering the chart with the PR's valuesContent.
#   * plain manifests / kustomizations with explicit `image:` keys.
#
# Usage:  check_pr.sh <PR-number> [--mirror <registry>] [--arches "a b"]
#
# Exit codes: 0 = mergeable (all images mirrored), 1 = NOT mergeable,
#             2 = usage/tooling error.
#
set -uo pipefail

MIRROR="${MIRROR:-registry.fritz.box}"
ARCHES="${ARCHES:-}"
PR="${1:-}"
[[ -n "$PR" ]] && shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mirror) MIRROR="$2"; shift 2 ;;
    --arches) ARCHES="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

for t in gh git helm yq regctl kubectl; do
  command -v "$t" >/dev/null 2>&1 || { echo "missing required tool: $t" >&2; exit 2; }
done

# Determine required architectures from the live cluster (override with --arches).
if [[ -z "$ARCHES" ]]; then
  cluster_arches=$(kubectl get nodes -o json 2>/dev/null \
    | jq -r '.items[].status.nodeInfo.architecture' | sort -u | sed 's|^|linux/|' | tr '\n' ' ' | sed 's/ *$//')
  ARCHES="${cluster_arches:-linux/amd64 linux/arm64}"
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"; helm repo remove pvprcheck >/dev/null 2>&1 || true' EXIT

# ---------------------------------------------------------------- helpers ----

# normalize_image <image> -> prints "registry repo:tag" (docker.io/library defaults)
normalize_image() {
  local img="$1" registry remainder repo tag
  local first_part="${img%%[/:]*}"
  if [[ "$first_part" == *.* ]]; then
    registry="$first_part"
    remainder="${img#*/}"
    repo="${remainder%%:*}"
  else
    registry="docker.io"
    repo="${img%%:*}"
    [[ "$repo" != */* ]] && repo="library/$repo"
  fi
  tag="${img##*:}"
  [[ "$img" == "$tag" ]] && tag="latest"
  echo "$registry $repo:$tag"
}

# ------------------------------------------------------------------- PR ----

if ! pr_json=$(gh pr view "$PR" --json number,title,state,url,baseRefName,headRefName 2>&1); then
  echo "ERROR: gh pr view $PR failed: $pr_json" >&2
  exit 2
fi
title=$(echo "$pr_json" | jq -r .title)
state=$(echo "$pr_json" | jq -r .state)
base=$(echo "$pr_json" | jq -r .baseRefName)
head=$(echo "$pr_json" | jq -r .headRefName)
url=$(echo "$pr_json" | jq -r .url)

echo "PR #$PR: $title"
echo "  state: $state   base: $base   head: $head"

git fetch -q origin "$head" "$base"
BASE_SHA="origin/$base"
# Renovate PRs from branches in-repo; if head is a fork, gh gives refs/pull/N/head
if ! git rev-parse -q --verify "origin/$head" >/dev/null; then
  git fetch -q origin "+refs/pull/$PR/head:refs/remotes/origin/pr-$PR"
  BASE_SHA="origin/pr-$PR"
fi
HEAD_SHA="origin/$head"
git rev-parse -q --verify "$HEAD_SHA" >/dev/null || HEAD_SHA="origin/pr-$PR"

files=$(git diff --name-only "$BASE_SHA...$HEAD_SHA" -- '*.yaml' '*.yml')
if [[ -z "$files" ]]; then
  echo "  No YAML files changed -> no image changes. MERGEABLE (nothing to mirror)."
  exit 0
fi

images_file="$TMPDIR/images.txt"
: >"$images_file"

# ------------------------------------------- direct image refs in manifests --

for f in $files; do
  content=$(git show "$HEAD_SHA:$f" 2>/dev/null) || continue

  # plain `image:` keys anywhere in the changed manifests
  direct=$(echo "$content" | yq -N -r '[.. | select(has("image")) | .image] | .[]' 2>/dev/null | grep -v '^$' || true)

  # ---- rancher HelmChart resources ----
  charts=$(echo "$content" | yq -o=json -N '.' 2>/dev/null \
            | jq -c 'select(.kind=="HelmChart") | {repo:.spec.repo, chart:.spec.chart, version:.spec.version, values:.spec.valuesContent}' \
            || true)

  if [[ -n "$charts" ]]; then
    while IFS= read -r c; do
      [[ -z "$c" ]] && continue
      repo_url=$(echo "$c" | jq -r '.repo')
      chart=$(echo "$c" | jq -r '.chart')
      ver=$(echo "$c" | jq -r '.version')
      echo "$c" | jq -r '.values // ""' > "$TMPDIR/values.yaml"
      echo "  resolving helm chart $chart ($ver) from $repo_url [$f]" >&2
      helm repo add pvprcheck "$repo_url" --force-update >/dev/null 2>&1
      if ! helm template pvprcheck "pvprcheck/$chart" --version "$ver" \
             -f "$TMPDIR/values.yaml" > "$TMPDIR/rendered.yaml" 2>"$TMPDIR/helm.err"; then
        echo "    WARNING: helm template failed; falling back to chart defaults:" >&2
        sed 's/^/    /' "$TMPDIR/helm.err" >&2
      fi
      rendered_imgs=$(yq -N -r '[.. | select(has("image")) | .image] | .[]' "$TMPDIR/rendered.yaml" 2>/dev/null | grep -v '^$' || true)
      direct="$direct"$'\n'"$rendered_imgs"
      echo "  checking helm chart images: $(echo "$rendered_imgs" | sort -u | tr '\n' ' ')"
      # show what currently runs in the target namespace (context only)
      tns=$(echo "$content" | yq -N -r 'select(.kind=="HelmChart") | .spec.targetNamespace // "kube-system"' 2>/dev/null | head -1)
      cur=$(kubectl get pods -n "$tns" -o json 2>/dev/null \
             | jq -r '.items[].spec.containers[].image' | sort -u | tr '\n' ' ')
      [[ -n "$cur" ]] && echo "  current images in namespace $tns: $cur" >&2
    done <<< "$charts"
  fi

  for img in $direct; do
    [[ -n "$img" ]] && echo "$img" >> "$images_file"
  done
done

images=$(sort -u "$images_file" | grep -v '^$' || true)
if [[ -z "$images" ]]; then
  echo "  No container images found in the changed YAML. MERGEABLE (no mirroring needed)."
  exit 0
fi

# ---------------------------------------------------------- mirror check ----

regctl registry set --tls=disabled "$MIRROR" >/dev/null 2>&1 || true

echo
echo "Checking mirror $MIRROR (arches: $ARCHES) ..."
missing=0
checked=0
while read -r img; do
  read -r registry repo_tag <<< "$(normalize_image "$img")"
  if [[ "$registry" == "$MIRROR" ]]; then
    mirror_img="$img"          # already pointing at the mirror
  else
    mirror_img="$MIRROR/$registry/$repo_tag"
  fi
  arch_missing=()
  for arch in $ARCHES; do
    checked=$((checked+1))
    if ! regctl manifest head --platform "$arch" "$mirror_img" >/dev/null 2>&1; then
      arch_missing+=("$arch")
    fi
  done
  if [[ ${#arch_missing[@]} -gt 0 ]]; then
    missing=$((missing+1))
    echo "  MISSING  $img"
    echo "           -> $mirror_img  [${arch_missing[*]}]"
  else
    echo "  OK       $img  ->  $mirror_img"
  fi
done <<< "$images"

echo
if [[ $missing -gt 0 ]]; then
  echo "RESULT: NOT mergeable — $missing of $(echo "$images" | wc -l | tr -d ' ') image(s) not mirrored to $MIRROR."
  echo "Trigger the regsync job (zot namespace) or mirror them manually first."
  exit 1
else
  echo "RESULT: MERGEABLE — all $checked image/arch checks passed on $MIRROR."
  exit 0
fi
