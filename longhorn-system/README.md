# Longhorn

[Documentation](https://longhorn.io/docs)

- disks created on the 3 server nodes: nasbox, pi1, pi2
  - no disks on new nodes unless node label `node.longhorn.io/create-default-disk=true` is set
- 2 replicas per volume (default)
- daily trim and snapshots
  - also for volumes w/o backup to keep volume head small, see [Replica Rebuilding](https://longhorn.io/docs/1.10.1/advanced-resources/rebuilding/)
- weekly backups on nasbox Samba (HDD)
  - unless labeled with `recurring-job-group.longhorn.io/no-backup: enabled` (see e.g. [zot pvc](../zot/zot/zot.yaml))