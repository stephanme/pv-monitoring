---
name: pv-pr-merge-check
description: Check whether a pv-monitoring PR (e.g. a Renovate dependency PR) can be merged by verifying that every container image introduced or changed by the PR is already cached in the local zot registry (registry.fritz.box). Use when asked if a PR can be merged, before merging Renovate/helm chart bumps in the pv-monitoring repo, or to audit image caching.
compatibility: Requires gh (authenticated to the pv-monitoring GitHub repo), kubectl (cluster context), regctl, helm, yq, jq, git.
---

# pv-monitoring PR merge check

A PR in this repo is only mergeable when **every container image referenced by
the changed manifests is already cached in `registry.fritz.box`** for **all CPU
architectures present in the cluster** (the scan covers all images in each
changed YAML file, not just the bumped tag — conservative on purpose).

`registry.fritz.box` (zot) is a **pull-through cache**, not a hard gate: k3s
falls back to the upstream registry when a tag is missing locally (containerd
tries the origin registry after all mirror endpoints fail), so an uncached
image still starts — it just pulls over the WAN, and it fails if the upstream
registry rate-limits (docker.io anonymous pulls) or has dropped the tag.
Caching before merging is a policy for predictable, fast, offline-safe deploys
— not a way to prevent `ImagePullBackOff`.

### Architecture policy exceptions

Some images are intentionally not mirrored for every cluster architecture. The
script applies these per-image exceptions (implemented in `required_arches`):

- **`ghcr.io/immich-app/immich-machine-learning:*-rocm`** — never mirrored
  (the rocm ML build is pulled directly, outside the mirror path). The check
  **ignores these images entirely** (`SKIP`); they are never a merge blocker.
- **`docker.io/bats/bats`** — used only by the kube-prometheus-stack
  `grafana-test` Pod (`helm.sh/hook: test`, runs only via `helm test`). Not
  configured in regsync and never mirrored. The check **ignores it entirely**
  (`SKIP`); it is never a merge blocker.
- **`ghcr.io/immich-app/immich-machine-learning:*-rknn`** and
  **`ghcr.io/immich-app/immich-server`** — deployed on **arm64 nodes only**,
  so they are mirrored for `linux/arm64` only. The check requires
  `linux/arm64` only for these images; a missing `linux/amd64` variant is not
  a blocker (it also doesn't exist for the `-rknn` tags upstream).

New exceptions belong in `required_arches` in `scripts/check_pr.sh` — keep the
skill documentation and the script in sync.

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
4. Reports `OK` / `SKIP` / `MISSING` per image (respecting the architecture
   policy exceptions above) and a final `MERGEABLE` / `NOT mergeable` verdict.

## Interpreting results

- **MERGEABLE** — all required image/arch combos exist on the mirror. Report the
  verdict; do not merge unless the user explicitly asks.
- **NOT mergeable** — list the missing images and say what a miss costs: the pods
  would pull those layers from upstream instead of the LAN (slow on this link,
  docker.io rate-limit exposure, and a hard failure if upstream has since
  garbage-collected the tag). Typical fix: the nightly regsync CronJob in the
  `zot` namespace mirrors them once the config allows it — only the user should
  trigger a run early.
- Before reporting NOT mergeable, classify each missing image by checking the
  rendered chart (`helm template ... | yq`): is it a normal container, a
  **hook** Job (`helm.sh/hook: pre-install,pre-upgrade` — these DO run on
  every deploy, e.g. the kube-prometheus-stack `crds-upgrade` Job using
  busybox + kubectl), or a **test** Pod (`helm.sh/hook: test` — only runs via
  `helm test`, usually NOT a merge blocker)? Report the distinction.
- If a missing image is also **denied** in `zot/regsync/config.yaml`, regsync
  will never mirror it — flag that a deny-list/allow-list change or manual
  mirror is required, not just waiting for the next sync.
- A differing top-level index digest between mirror and upstream is normal here
  (the regsync job recreates index manifests via `regctl index create`);
  per-architecture manifest digests are what must match upstream.
- Cached image versions are usually denied in `zot/regsync/config.yaml` so that
  regsync doesn't mirror them again once a version was gc'ed. regsync garbage
  collects image versions and keeps only the latest pushed and pulled image
  version.

## Rules

- **Report only. Never merge** the PR yourself unless the user explicitly asks.
- If `kubectl` cannot reach the cluster, still run the check but say the
  architecture list was assumed (amd64+arm64).
- **Never start a regsync job yourself**; it is owned by the CronJob in the `zot`
  namespace. Just report that the image is not yet cached, and let the user
  decide whether to trigger a sync.
