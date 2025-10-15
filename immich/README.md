# Immich

http://immich.fritz.box

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

### Immich Machine Learning

- assigned to pi2
- uses RKNN HW acceleration
- uses pi2 SSD for model cache
  - models are ~8 GB on disk
  - download takes many h
- requires lots of mem, ~4G for 1 RKNN thread
