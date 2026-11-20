# Pocket ID

- https://pocketid.stephanme.de
- OIDC single sign-on with passkeys
- [Documentation](https://pocket-id.org/docs)
- [Release Notes](https://pocket-id.org/changelog)

## Installation

kustomize manifests, no helm chart:

```
./pocketid/deploy.sh
```

One time setup after a fresh clone: `secrets.yaml` is gitignored but referenced by
`kustomization.yaml`, so copy the template and fill in the key before the first
deploy, otherwise `kubectl apply -k` fails.

### Application

- single container, SQLite database and uploads on a longhorn PVC mounted at `/app/data`
- `replicas: 1` and `strategy: Recreate`: only one Pocket ID instance may use the database and
  the volume is ReadWriteOnce
- distroless image, runs as uid/gid 65532 with read-only root filesystem
- `ENCRYPTION_KEY` encrypts the token signing keys stored in the database. Never change it
  afterwards, rotating requires the `encryption-key-rotate` command below
- metrics are exported by OpenTelemetry on port 9464 and scraped by the ServiceMonitor in
  [monitoring.yaml](./monitoring.yaml)

### First start

- open https://pocketid.stephanme.de and create the first account, it becomes admin
- add a passkey, WebAuthn requires the https origin of `APP_URL`
- `ALLOW_INSECURE_CALLBACK_URLS=false`, so OIDC clients must use https redirect URIs

### Backups

- PVC is backed up by the default longhorn recurring jobs
- logical backup is the `export` command below (there is no export page in the admin UI, and
  the feature is still marked experimental upstream)
- back up the export together with `ENCRYPTION_KEY` and the `APP_URL`: without the key the
  data is unreadable, and passkeys only work on the original URL
- never copy `pocket-id.db` alone from a running instance, recent data sits in the WAL files

### CLI

`pocket-id` CLI can be called with `kubectl exec` (no shell in the distroless image).

Subcommands: `healthcheck`, `one-time-access-token`, `export`, `import`, `key-rotate`,
`encryption-key-rotate`, `version`.

One-time login link for a user who lost all passkeys (or for yourself when the last admin
passkey is gone), also in the admin UI under Administration -> Users -> ... -> Login Code:

```bash
kubectl -n pocketid exec deploy/pocket-id -- /app/pocket-id one-time-access-token \<username or email\>
```

## Updates

- version is pinned in `kustomization.yaml` (`images: newTag`), bumped by renovate
- read the [release notes](https://pocket-id.org/changelog) before a major version, v3 has a
  redesigned UI
- database migrations run automatically on startup, keep a backup before updating
