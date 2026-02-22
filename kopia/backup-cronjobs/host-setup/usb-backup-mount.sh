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

is_device_ready() {
    local device="$1"

    # Check if device path exists
    [ ! -e "$device" ] && return 1

    # Check if device is a block device
    [ ! -b "$device" ] && return 1

    # Check if device is readable
    [ ! -r "$device" ] && return 1

    # Verify the device has the expected UUID using blkid
    local detected_uuid=$(blkid -s UUID -o value "$device" 2>/dev/null)
    [ "$detected_uuid" != "$UUID" ] && return 1

    # Try to read the first block to ensure device is accessible
    dd if="$device" of=/dev/null bs=512 count=1 2>/dev/null || return 1

    return 0
}

case "$ACTION" in
    add)
        log_message "USB backup drive detected"

        # Wait for device to be fully available and ready
        MAX_WAIT=30
        WAIT_COUNT=0
        while ! is_device_ready "$DEVICE_PATH" && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
            sleep 1
            WAIT_COUNT=$((WAIT_COUNT + 1))
            log_message "Waiting for device to become ready... ($WAIT_COUNT/$MAX_WAIT)"
        done

        if ! is_device_ready "$DEVICE_PATH"; then
            log_message "ERROR: Device $DEVICE_PATH not ready after waiting"
            exit 1
        fi

        log_message "Device $DEVICE_PATH is ready"

        # Wait for udev to finish processing events
        udevadm settle --timeout=10
        log_message "Waited for udev to settle"

        # Sync to ensure all pending I/O is complete
        sync

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

        # Double-check the device is not already mounted elsewhere
        if grep -qs "$DEVICE_PATH" /proc/mounts; then
            EXISTING_MOUNT=$(grep "$DEVICE_PATH" /proc/mounts | cut -d' ' -f2)
            log_message "WARNING: Device already mounted at $EXISTING_MOUNT"
            exit 1
        fi

        # Mount the drive with filesystem check and retry logic
        MAX_MOUNT_RETRIES=5
        MOUNT_RETRY_DELAY=5
        MOUNT_STATUS=1
        RETRY_COUNT=0

        while [ $MOUNT_STATUS -ne 0 ] && [ $RETRY_COUNT -lt $MAX_MOUNT_RETRIES ]; do
            sleep $MOUNT_RETRY_DELAY

            # Capture mount error output
            MOUNT_ERROR=$(mount -t ext4 -o defaults,noatime "$DEVICE_PATH" "$MOUNT_POINT" 2>&1)
            MOUNT_STATUS=$?

            if [ $MOUNT_STATUS -eq 0 ]; then
                log_message "Successfully mounted $DEVICE_PATH to $MOUNT_POINT"
                break
            else
                log_message "Mount attempt $((RETRY_COUNT + 1)) failed with exit code: $MOUNT_STATUS"
                log_message "Mount error: $MOUNT_ERROR"

                # Log additional diagnostics
                log_message "Device status: $(ls -l $DEVICE_PATH 2>&1)"
                log_message "Filesystem check: $(blkid $DEVICE_PATH 2>&1)"
                log_message "Recent kernel messages: $(dmesg | tail -5 | grep -i 'usb\|mount\|ext4' || echo 'none')"

                RETRY_COUNT=$((RETRY_COUNT + 1))
            fi
        done

        if [ $MOUNT_STATUS -eq 0 ]; then
            # Set ownership to backup user
            chown "$BACKUP_UID:$BACKUP_GID" "$MOUNT_POINT"
            log_message "Set ownership to $BACKUP_USER ($BACKUP_UID:$BACKUP_GID)"
        else
            log_message "ERROR: Failed to mount $DEVICE_PATH after $MAX_MOUNT_RETRIES attempts (exit code: $MOUNT_STATUS)"
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
