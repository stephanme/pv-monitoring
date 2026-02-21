# Backup with Kopia

[Documentation](https://kopia.io/docs/)

There are two backup procedures in place:
- longhorn backups PVs to `cifs://nasbox.fritz.box/backup-md0/longhorn`
- non-longhorn data (immich, music-assistent, nasbox shares, data from other machines) are backed up using Kopia

## Kopia Setup

- a kopia-server on nasbox maintains a repository
  - owned by `backup` user
  - located at `/srv/kopia/backup-repo`, i.e. on nasbox HDD 
- cronjobs or Kopia UI on other machines backup files to this kopia server

## External Backup

A manually triggered [cronjob backup-external](./backup-cronjobs/backup-external.yaml) mirrors the longhorn backups and the kopia repository to an external disk (USB drive).

After the back, the external USB drive needs to be powered off safely.
```
# on nasbox
sudo safe-eject-backup-drive.sh
```

See [host-setup/README.md](./backup-cronjobs/host-setup/README.md) for details.