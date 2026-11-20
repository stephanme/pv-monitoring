# Immich

- https://immich.stephanme.de
- https://immich-kiosk.stephanme.de
- [Documentation](https://docs.immich.app/overview/quick-start)
- [Release Notes](https://github.com/immich-app/immich/releases)

## Installation

### Photo Storage

- photos are stored pi2 SSD: `/home/immich/immich-library`
- owned by `immich` user on pi2
- photos shared additionally via samba
- backup with kopia

### Redis

- simple deployment
- no persistence

### Database

- PostgreSQL instance installed by [CloudNativePG operator](https://cloudnative-pg.io/documentation/current/)
- single instance, no replication
- longhorn pvc with backup
- no superuser

How to access DB:
- ssh into `immich-database-1` pod
- `psql app`

### Immich Server

- assigned to pi2 so that `immich-library` can be accessed as `hostPath`
- authentication with Pocket ID: https://pocket-id.org/docs/client-examples/immich
- Note: Immich needs to be configured in the Admin UI to a large extend.

### Immich Machine Learning

- primary ML instance assigned to pi2
- uses RKNN HW acceleration
- uses pi2 SSD for model cache
  - models are ~8 GB on disk
  - download takes many h
- requires lots of mem, ~3G for 1 RKNN thread

- second (temporary) ML instance on pc02 (rocm)

### Immich Kiosk

- nice photo presentation app
- [Configuration](https://docs.immichkiosk.app/configuration/)