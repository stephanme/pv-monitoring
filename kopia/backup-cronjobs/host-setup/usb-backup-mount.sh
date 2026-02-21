#!/bin/bash
# Auto-mount script for USB backup drive
# Triggered by udev rule when USB drive is attached/detached
# UUID: 4baeb9e1-2fbd-4985-9ea7-93fbf9f25589

UUID="4baeb9e1-2fbd-4985-9ea7-93fbf9f25589"
DEVICE_PATH="/dev/disk/by-uuid/$UUID"
MOUNT_POINT="/media/backup/$UUID"
BACKUP_USER="backup"
BACKUP_UID=1001
BACKUP_GID=1001
LOG_FILE="/var/log/usb-backup-mount.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

case "$ACTION" in
    add)
        log_message "USB backup drive detected"

        # Wait for device to be fully available
        MAX_WAIT=10
        WAIT_COUNT=0
        while [ ! -e "$DEVICE_PATH" ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
            sleep 1
            WAIT_COUNT=$((WAIT_COUNT + 1))
            log_message "Waiting for device to become available... ($WAIT_COUNT/$MAX_WAIT)"
        done

        if [ ! -e "$DEVICE_PATH" ]; then
            log_message "ERROR: Device $DEVICE_PATH not found after waiting"
            exit 1
        fi

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
        mount -t ext4 -o defaults,noatime "$DEVICE_PATH" "$MOUNT_POINT"
        if [ $? -eq 0 ]; then
            log_message "Successfully mounted $DEVICE_PATH to $MOUNT_POINT"

            # Set ownership to backup user
            chown "$BACKUP_UID:$BACKUP_GID" "$MOUNT_POINT"
            log_message "Set ownership to $BACKUP_USER ($BACKUP_UID:$BACKUP_GID)"
        else
            log_message "ERROR: Failed to mount $DEVICE_PATH"
            exit 1
        fi
        ;;

    remove)
        log_message "USB backup drive removed"

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
