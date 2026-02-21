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

The [backup-external cronjob](./backup-cronjobs/backup-external.yaml) mirrors the longhorn backups and the kopia repository to an external USB drive.

### Automatic Trigger

When the USB backup drive (UUID: `4baeb9e1-2fbd-4985-9ea7-93fbf9f25589`) is plugged into nasbox:
1. A udev rule automatically mounts it to `/media/backup/4baeb9e1-2fbd-4985-9ea7-93fbf9f25589`
2. The [usb-backup-watcher DaemonSet](./backup-cronjobs/usb-backup-watcher.yaml) detects the mount (polls every 5 min)
3. A backup Job is automatically created from the `backup-external` CronJob template
4. The backup runs, syncing both Longhorn backups and the Kopia repository

**Implementation**: The watcher is a lightweight DaemonSet on nasbox that validates the mountpoint is ready before triggering the backup. It uses a state file to prevent duplicate triggers and resets when the drive is unmounted.

### Manual Trigger

You can also trigger the backup manually:
```bash
kubectl create job -n kopia backup-external-manual --from=cronjob/backup-external
```

### Safe Ejection

After the backup completes, safely eject the USB drive:
```bash
# on nasbox
sudo safe-eject-backup-drive.sh
```

See [host-setup/README.md](./backup-cronjobs/host-setup/README.md) for host setup details.