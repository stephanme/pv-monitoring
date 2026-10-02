---
name: pv-pr-merge-check
description: Check whether a pv-monitoring PR (e.g. a Renovate dependency PR) can be merged by verifying that every container image introduced or changed by the PR is already mirrored to registry.fritz.box. Use when asked if a PR can be merged, before merging Renovate/helm chart bumps in the pv-monitoring repo, or to audit image mirroring.
compatibility: Requires gh (authenticated to the pv-monitoring GitHub repo), kubectl (cluster context), regctl, helm, yq, jq, git.
---

# pv-monitoring PR merge check

A PR in this repo is only mergeable when **every container image referenced by
the changed manifests is already mirrored to `registry.fritz.box`** for **all
CPU architectures present in the cluster** (the scan covers all images in each
changed YAML file, not just the bumped tag — conservative on purpose, since a
missing image means pods get stuck in `ImagePullBackOff`).

## How to check a PR

Run the bundled script from anywhere inside the pv-monitoring repo:

```bash
./.pi/skills/pv-pr-merge-check/scripts/check_pr.sh <PR-number>
```

Options:
- `--mirror <registry>` — defaults to `registry.fritz.box`
- `--arches "linux/amd64 linux/arm64"` — defaults to the architectures of the
  live cluster nodes (via `kubectl get nodes`); falls back to amd64+arm64.

Exit codes: `0` = mergeable, `1` = NOT mergeable, `2` = tooling/usage error.

## What the script does

1. `gh pr view` + `git fetch` to diff the PR against its base branch.
2. For each changed YAML file:
   - **rancher `HelmChart` resources** (`helm.cattle.io/v1`): renders the new
     chart version with the PR's `valuesContent` via `helm template` and
     extracts the resulting `image:` references (this is what actually gets
     deployed, including default tags derived from `appVersion`).
   - **`kustomization.yaml` changes**: runs `kustomize build` on the PR-head
     copy of the changed overlay directory (via a temporary git worktree) and
     extracts the rendered `image:` references. This catches `images:` name
     and `newTag` patches, which contain no literal `image:` key. Prefers
     `kubectl kustomize` (same kustomize version the deploy scripts use);
     standalone `kustomize build` is the fallback. If rendering fails, it
     degrades to extracting the overlay's own `images:` entries
     (`name:newTag`) instead of silently reporting no images.
   - **plain manifests**: extracts every `image:` key with `yq`.
3. Normalizes each image (default registry `docker.io`, `library/` prefix for
   Docker official images, `latest` fallback) and checks the mirror path
   `registry.fritz.box/<registry>/<repo>:<tag>` with
   `regctl manifest head --platform <arch>`.
   - Docker official images: a bare name under `docker.io` implicitly means
     `library/`, so `docker.io/busybox:latest` **is** `docker.io/library/busybox:latest`.
     The script checks the normalised `library/` path first and also tries the
     bare path as an alias; if either has all required arches the image is `OK`.
     Never report a bare/`library/` mismatch as a missing mirror.
4. Reports `OK` / `MISSING` per image and a final `MERGEABLE` / `NOT mergeable`
   verdict.

## Interpreting results

- **MERGEABLE** — all required image/arch combos exist on the mirror. Report the
  verdict; do not merge unless the user explicitly asks.
- **NOT mergeable** — list the missing images. Typical fix: run the regsync
  CronJob in the `zot` namespace (or `regsync once` with the repo config),
  then re-check.
- Before reporting NOT mergeable, classify each missing image by checking the
  rendered chart (`helm template ... | yq`): is it a normal container, a
  **hook** Job (`helm.sh/hook: pre-install,pre-upgrade` — these DO run on
  every deploy, e.g. the kube-prometheus-stack `crds-upgrade` Job using
  busybox + kubectl), or a **test** Pod (`helm.sh/hook: test` — only runs via
  `helm test`, usually NOT a merge blocker)? Report the distinction.
- If a missing image is also **denied** in `zot/regsync/config.yaml`, regsync
  will never mirror it — flag that a deny-list/allow-list change or manual
  mirror is required, not just a sync run.
- A differing top-level index digest between mirror and upstream is normal here
  (the regsync job recreates index manifests via `regctl index create`);
  per-architecture manifest digests are what must match upstream.

## Rules

- **Report only. Never merge** the PR yourself unless the user explicitly asks.
- If `kubectl` cannot reach the cluster, still run the check but say the
  architecture list was assumed (amd64+arm64).
- **Never start a regsync job yourself**; it should be managed by the CronJob in the `zot` namespace.
  Just report that the image is not yet mirrored.
