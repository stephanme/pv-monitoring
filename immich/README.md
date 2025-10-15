# Immich

http://immich.fritz.box

## Installation

### Redis

- simple deployment
- no persistence

### Database

- PostgreSQL instance installed by cloudnative-pg operator
- longhorn pvc with backup

### Immich Server

- assigned to pi2
- uses pi2 SSD to store photos
  - owned by `immich` user on pi2
  - photos shared additionally via samba
  - backup with kopia

### Immich Machine Learning

- assigned to pi2
- uses RKNN HW acceleration
- uses pi2 SSD for model cache
  - models are ~8 GB
  - download takes many h

