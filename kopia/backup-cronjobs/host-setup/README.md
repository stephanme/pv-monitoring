# USB Backup Drive Auto-Mount Setup

This directory contains configuration files for auto-mounting the USB backup drive on the nasbox host.

## Overview

The USB backup drive (UUID: `4baeb9e1-2fbd-4985-9ea7-93fbf9f25589`) will automatically mount to:
```
/media/backup/4baeb9e1-2fbd-4985-9ea7-93fbf9f25589
```

When the drive is plugged in, a udev rule triggers a mount script that:
- Mounts the drive with appropriate options
- Sets ownership to the backup user (uid=1001, gid=1001)
- Logs all mount/unmount operations to `/var/log/usb-backup-mount.log`

## Installation

Run these commands on your nasbox host:

### 1. Copy the mount script
```bash
sudo cp usb-backup-mount.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/usb-backup-mount.sh
```

### 2. Copy the udev rule
```bash
sudo cp 99-usb-backup-mount.rules /etc/udev/rules.d/
```

### 3. Reload udev rules
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### 4. Install safe eject script (optional but recommended)
```bash
sudo cp safe-eject-backup-drive.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/safe-eject-backup-drive.sh
```

### 5. Test the setup
```bash
# Check if the drive is detected
lsblk -o NAME,FSTYPE,SIZE,UUID,MOUNTPOINT

# Check logs
sudo tail -f /var/log/usb-backup-mount.log

# Unplug and replug the USB drive - it should auto-mount
```

## Verification

After plugging in the USB drive, verify:

```bash
# Check if mounted
mountpoint /media/backup/4baeb9e1-2fbd-4985-9ea7-93fbf9f25589

# Check ownership
ls -ld /media/backup/4baeb9e1-2fbd-4985-9ea7-93fbf9f25589

# Check mount options
mount | grep 4baeb9e1-2fbd-4985-9ea7-93fbf9f25589
```

Expected output:
- Mount point should exist and be mounted
- Owner should be `backup:backup` (1001:1001)
- Filesystem should be ext4 with noatime option

## Safe Removal (HDD)

Since this is an HDD, it's important to properly spin down the drive before unplugging to prevent head crashes.

**Easy method (recommended):**
```bash
sudo safe-eject-backup-drive.sh
```

**Manual method:**
```bash
# 1. Sync pending writes
sync

# 2. Unmount the drive
sudo umount /media/backup/4baeb9e1-2fbd-4985-9ea7-93fbf9f25589

# 3. Power off the drive (spins down HDD, parks heads)
sudo udisksctl power-off -b /dev/disk/by-uuid/4baeb9e1-2fbd-4985-9ea7-93fbf9f25589

# Now safe to physically unplug
```

## Troubleshooting

### Check udev rule is loaded
```bash
udevadm test $(udevadm info -q path -n /dev/disk/by-uuid/4baeb9e1-2fbd-4985-9ea7-93fbf9f25589) 2>&1 | grep usb-backup-mount
```

### Manual mount/unmount
```bash
# Manual mount
sudo /usr/local/bin/usb-backup-mount.sh
# Set ACTION environment variable
sudo ACTION=add DEVNAME=/dev/disk/by-uuid/4baeb9e1-2fbd-4985-9ea7-93fbf9f25589 /usr/local/bin/usb-backup-mount.sh

# Manual unmount
sudo ACTION=remove DEVNAME=/dev/disk/by-uuid/4baeb9e1-2fbd-4985-9ea7-93fbf9f25589 /usr/local/bin/usb-backup-mount.sh
```

### Check logs
```bash
sudo tail -50 /var/log/usb-backup-mount.log
```
