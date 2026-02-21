#!/bin/bash
# Safe eject script for USB backup drive
# Syncs, unmounts, and powers off the drive before physical removal

MOUNT_POINT="/media/backup/4baeb9e1-2fbd-4985-9ea7-93fbf9f25589"
DEVICE_UUID="4baeb9e1-2fbd-4985-9ea7-93fbf9f25589"
DEVICE="/dev/disk/by-uuid/$DEVICE_UUID"

echo "Safe eject USB backup drive"
echo "============================"
echo ""

# Check if drive is mounted
if ! mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    echo "Drive is not mounted at $MOUNT_POINT"

    # Check if device exists
    if [ ! -e "$DEVICE" ]; then
        echo "Device not found. Already unplugged?"
        exit 0
    fi

    echo "Device exists but not mounted. Proceeding to power off..."
else
    echo "1. Syncing pending writes..."
    sync
    echo "   Done"

    echo ""
    echo "2. Unmounting drive from $MOUNT_POINT..."
    umount "$MOUNT_POINT"

    if [ $? -eq 0 ]; then
        echo "   Successfully unmounted"
    else
        echo "   ERROR: Failed to unmount"
        echo "   The drive may be in use. Check for open files:"
        echo "   sudo lsof | grep $MOUNT_POINT"
        exit 1
    fi
fi

echo ""
echo "3. Powering off drive (spinning down HDD)..."
udisksctl power-off -b "$DEVICE"

if [ $? -eq 0 ]; then
    echo "   Drive powered off successfully"
    echo ""
    echo "✓ Safe to unplug the USB drive now"
else
    echo "   WARNING: Power-off command failed"
    echo "   Drive may still be accessible by the system"
    echo ""
    echo "Try manual power-off:"
    echo "   sudo udisksctl power-off -b $DEVICE"
    exit 1
fi
