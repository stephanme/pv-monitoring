#!/bin/sh
set -e

MOUNT_PATH="/media/backup/4baeb9e1-2fbd-4985-9ea7-93fbf9f25589"
STATE_FILE="/state/usb-backup-watcher-state"
POLL_INTERVAL=300

echo "USB Backup Watcher started"
echo "Watching mount path: $MOUNT_PATH"
echo "Poll interval: ${POLL_INTERVAL}s"
echo ""

# Function to check if USB drive is actually accessible
# When unmounted, the stale mountpoint appears as an empty directory
is_usb_available() {
  # Check if directory exists
  [ ! -d "$MOUNT_PATH" ] && return 1

  # Check if mount point has content - empty means unmounted/stale
  # A mounted backup drive should always have content
  if [ -z "$(ls -A "$MOUNT_PATH" 2>/dev/null)" ]; then
    return 1
  fi

  return 0
}

while true; do
  # Check if USB drive is actually accessible
  if is_usb_available; then
    # Only trigger once per mount cycle
    if [ ! -f "$STATE_FILE" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - USB backup drive mounted at $MOUNT_PATH"
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking for existing backup Jobs..."

      # Check if backup Job already running/completed recently
      if kubectl get jobs -n kopia -l cronjob=backup-external \
          --field-selector status.successful!=1,status.failed!=1 2>/dev/null | grep -q backup-external; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup Job already running, skipping trigger"
      else
        # Create Job from CronJob template
        JOB_NAME="backup-external-usb-$(date +%Y%m%d-%H%M%S)"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Creating backup Job: $JOB_NAME"

        if kubectl create job -n kopia "$JOB_NAME" --from=cronjob/backup-external; then
          echo "$(date '+%Y-%m-%d %H:%M:%S') - ✓ Backup Job created successfully"
          touch "$STATE_FILE"
        else
          echo "$(date '+%Y-%m-%d %H:%M:%S') - ✗ Failed to create backup Job"
        fi
      fi
    fi
  else
    # Mount not present, clear state to allow re-trigger on next mount
    if [ -f "$STATE_FILE" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - USB backup drive unmounted, resetting state"
      rm -f "$STATE_FILE"
    fi
  fi

  sleep $POLL_INTERVAL
done
