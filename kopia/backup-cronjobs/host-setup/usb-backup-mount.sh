#!/bin/bash
# Auto-mount script for USB backup drive
# Triggered by udev rule when USB drive is attached/detached
# UUID: 4baeb9e1-2fbd-4985-9ea7-93fbf9f25589

MOUNT_POINT="/media/backup/4baeb9e1-2fbd-4985-9ea7-93fbf9f25589"
BACKUP_USER="backup"
BACKUP_UID=1001
BACKUP_GID=1001
LOG_FILE="/var/log/usb-backup-mount.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

case "$ACTION" in
    add)
        log_message "USB backup drive detected: $DEVNAME"

        # Create mount point if it doesn't exist
        if [ ! -d "$MOUNT_POINT" ]; then
            mkdir -p "$MOUNT_POINT"
            log_message "Created mount point: $MOUNT_POINT"
        fi

        # Check if already mounted
        if mountpoint -q "$MOUNT_POINT"; then
            log_message "Already mounted at $MOUNT_POINT"
            exit 0
        fi

        # Mount the drive
        mount -t ext4 -o defaults,noatime "$DEVNAME" "$MOUNT_POINT"
        if [ $? -eq 0 ]; then
            log_message "Successfully mounted $DEVNAME to $MOUNT_POINT"

            # Set ownership to backup user
            chown "$BACKUP_UID:$BACKUP_GID" "$MOUNT_POINT"
            log_message "Set ownership to $BACKUP_USER ($BACKUP_UID:$BACKUP_GID)"
        else
            log_message "ERROR: Failed to mount $DEVNAME"
            exit 1
        fi
        ;;

    remove)
        log_message "USB backup drive removed: $DEVNAME"

        # Unmount if still mounted
        if mountpoint -q "$MOUNT_POINT"; then
            umount "$MOUNT_POINT"
            if [ $? -eq 0 ]; then
                log_message "Successfully unmounted $MOUNT_POINT"
            else
                log_message "ERROR: Failed to unmount $MOUNT_POINT"
                # Force unmount as fallback
                umount -l "$MOUNT_POINT" 2>/dev/null
                log_message "Attempted lazy unmount of $MOUNT_POINT"
            fi
        fi
        ;;

    *)
        log_message "Unknown action: $ACTION"
        ;;
esac

exit 0
