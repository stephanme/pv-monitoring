# pv-monitoring

Manifests for a self-hosted k3s homelab (PV / EV charging / heat pump monitoring, photos,
documents, backups). This repo is the source of truth for all cluster manifests.

⚠️ **Live production cluster, no staging.** No `kubectl apply/delete/rollout` unless the user
asked; read-only kubectl is fine. Never merge a PR yourself — report only.

## Cluster

- nodes: `nasbox` amd64 (storage/Samba host), `pi1` arm64 (RPi 4), `pi2` arm64 (Orange Pi 5
  Max — its RK NPU is why `immich-machine-learning` has an arm64-only `-rknn` build), `pc02`
  amd64 (temporary agent). 3 embedded-etcd servers, API `k3s.fritz.box:6443`.
- `*.fritz.box` resolves via dnsmasq + patched coredns; ingress is Traefik v3 (DaemonSet);
  `*.stephanme.de` certs come from cert-manager netcup **DNS-01** (`cert-manager-system/README.md`).
- Storage: Longhorn, 2 replicas, disks only on nodes labelled `node.longhorn.io/create-default-disk=true`.
- k3s upgrades are automated; version pinned in `system-upgrade/k3s-upgrade.yaml`.
- Per-app `README.md` files carry operational notes and release-note links — read before touching.

## Deploys

One `<namespace>/<app>/deploy.sh` per app; the root `deploy.sh` applies namespaces in
dependency order — CRDs/operators first, consumers after their storage (`zot` after
`longhorn-system`, `paperless` after longhorn + smb-csi, `immich` after `cnpg-system`).
Scripts use `set -ex` and `scriptdir=$(dirname "$0")`, so run them from anywhere.

```bash
./monitoring/deploy.sh      # one namespace (./immich/server/deploy.sh for one app)
./check-deploy-wiring.sh    # exit 0 = wiring OK; else MISSING / NOT DEPLOYED / DEPLOYED TWICE / SYNTAX
```

No CI, no tests, no linter — validate statically: `kubectl kustomize <dir>`, `bash -n <script>`,
`kubectl apply --dry-run=client -f <file>`, `helm template <chart> --repo <repo> -f values.yaml`.

Three manifest styles: rancher **`HelmChart` CR** (`helm.cattle.io/v1` with inline
`valuesContent`; k3s reconciles it, there is no local `helm upgrade`), **kustomize** overlays
(tag lives in `images: [{name, newTag}]`, applied with `kubectl apply -k`; e.g.
`immich/server`, `zot/prefetch-image`), and plain `kubectl apply -f` manifests. Namespaces come
from `<ns>/namespace.yaml`.

## Renovate bumps

Renovate opens the PRs. Change **only the version value** — the machine-readable comments are
what Renovate parses, and rewriting them makes the version stale forever:

```yaml
spec:
  # renovate: HelmChart        # OCI charts: same marker, with "chart: oci://..."
  repo: https://prometheus-community.github.io/helm-charts
  chart: kube-prometheus-stack
  version: 93.3.0
# system-upgrade/k3s-upgrade.yaml: "#renovate: k3s" directly above "version: v1.37.2+k3s1"
```
```sh
# renovate: HelmChartCRD repo=<helm repo> chart=<name>              # above a CRD URL in deploy.sh
# renovate: datasource=docker depName=<image> [versioning=<v>]      # above VERSION="1.2.3"
```

Native managers also read plain `image:` keys and kustomize `images:` in any `*.yaml`.
Version-format quirks (searxng date tags, kopia fake dates, immich grouping) live in
`renovate.json` `packageRules`.

## Image mirroring

`registry.fritz.box` (zot) is a **pull-through cache** for docker.io / ghcr.io / quay.io /
registry.k8s.io (`/etc/rancher/k3s/registries.yaml`). Keep upstream image names in manifests;
an uncached tag still pulls from upstream, just slowly.

- `zot/regsync/config.yaml` decides what is cached nightly (`sync:` per repository,
  amd64+arm64, `allow:`/`deny:` tag regexes). Add an entry for new images; deployed versions
  move to `deny:` afterwards so pruning does not re-mirror them.
- **Never run regsync manually** — the `zot` CronJob owns it (`zot/README.md`).
- Merge gate for image/chart bumps: `./.pi/skills/pv-pr-merge-check/scripts/check_pr.sh <PR>`
  (usage, exit codes and arch exceptions in its SKILL.md).

## Secrets

`secrets.yaml` is gitignored, never committed. Keep the sibling `secrets.yaml.template`
(placeholders like `<api key>`) in sync when adding or renaming keys.

## Conventions

2-space YAML; `nodeSelector: kubernetes.io/hostname` for node-pinned workloads (backups,
USB/zigbee, zot prefetch); the Longhorn label `recurring-job-group.longhorn.io/no-backup: enabled`
excludes a PVC from backups; Grafana dashboards live in `<ns>/grafana-dashboards/` or
`*-grafana.yaml`. Branch `main` or `renovate/*`; commit messages are short imperatives
(`Update regsync config`, `homepage: serve via https on home.stephanme.de`).
