#!/bin/bash

# This script performs automated backups and rotation.
# It is intended to be run as a cron job every minute.

CONFIG_FILE="$HOME/.backup_conf.txt"

if [ ! -f "$CONFIG_FILE" ]; then
    exit 0
fi

source "$CONFIG_FILE"

if [ ! -d "$SOURCE_DIR" ] || [ ! -d "$DESTINATION_DIR" ]; then
    exit 0
fi

SNAPSHOT_FILE="${DESTINATION_DIR}/backup.snar"
MONTHLY_SNAPSHOT_FILE="${DESTINATION_DIR}/monthly_backup.snar"

current_minute=$(date +%M)
n=$((10#$current_minute + 1))

if (( n % 12 == 0 )); then
    backup_type="monthly"
elif (( n % 4 == 0 )); then
    backup_type="weekly"
else
    backup_type="daily"
fi


if [ ! -f "$SNAPSHOT_FILE" ]; then
    if [ "$backup_type" != "monthly" ]; then
        echo "Warning: No base backup found. Promoting this backup to FULL (monthly)."
        backup_type="monthly"
    fi
fi

timestamp=$(date +%Y-%m-%d_%H-%M-%S)
archive_name="${timestamp}_backup_${backup_type}.tar.gz"
archive_path="${DESTINATION_DIR}/${archive_name}"


case "$backup_type" in
  "monthly")
    echo "Creating FULL monthly backup: $archive_name"
    rm -f "$SNAPSHOT_FILE"
    
    tar -czf "$archive_path" --listed-incremental="$SNAPSHOT_FILE" -C "$SOURCE_DIR" .
    
    if [ $? -eq 0 ]; then
        cp "$SNAPSHOT_FILE" "$MONTHLY_SNAPSHOT_FILE"
    fi
    ;;

  "weekly")
    echo "Creating DIFFERENTIAL weekly backup: $archive_name"
    if [ ! -f "$MONTHLY_SNAPSHOT_FILE" ]; then
        echo "Warning: Monthly snapshot not found. Promoting weekly backup to FULL."
        rm -f "$SNAPSHOT_FILE"
        tar -czf "$archive_path" --listed-incremental="$SNAPSHOT_FILE" -C "$SOURCE_DIR" .
    else
        tar -czf "$archive_path" --listed-incremental="$MONTHLY_SNAPSHOT_FILE" -C "$SOURCE_DIR" .
    fi
    ;;

  "daily")
    echo "Creating INCREMENTAL daily backup: $archive_name"
    tar -czf "$archive_path" --listed-incremental="$SNAPSHOT_FILE" -C "$SOURCE_DIR" .
    ;;
esac




if [ -n "$S3_BUCKET" ]; then
    echo "Uploading to S3 (Bucket: $S3_BUCKET)..."
    aws s3 cp "$archive_path" "s3://$S3_BUCKET/"

    if [ $? -eq 0 ]; then
        echo "Backup uploaded to S3 successfully."
    else
        echo "ERROR: S3 upload failed." >&2
    fi
else
    echo "Info: S3_BUCKET variable not set. Skipping S3 upload."
fi

echo "Performing cleanup of old backups..."

find "$DESTINATION_DIR" -maxdepth 1 -name "*_backup_daily.tar.gz" -type f | sort -r | tail -n +5 | xargs -r rm
echo "-> Daily backup cleanup complete."


find "$DESTINATION_DIR" -maxdepth 1 -name "*_backup_weekly.tar.gz" -type f | sort -r | tail -n +4 | xargs -r rm
echo "-> Weekly backup cleanup complete."



find "$DESTINATION_DIR" -maxdepth 1 -name "*_backup_monthly.tar.gz" -type f | sort -r | tail -n +13 | xargs -r rm
echo "-> Monthly backup cleanup complete."

echo "Backup and rotation process finished."
echo