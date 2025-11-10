#!/bin/bash

# This script restores a backup chain (full, differential, incremental)
# by downloading the required files from an S3 bucket.

CONFIG_FILE="$HOME/.backup_conf.txt"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found." >&2
    exit 1
fi

source "$CONFIG_FILE"

if [ -z "$S3_BUCKET" ]; then
    echo "Error: S3_BUCKET variable is not defined in '$CONFIG_FILE'." >&2
    echo "This variable is required to restore from the cloud." >&2
    exit 1
fi

echo "Searching for backups in S3 bucket: $S3_BUCKET"

mapfile -t all_s3_files < <(aws s3 ls "s3://$S3_BUCKET/" | grep '\.tar\.gz$' | awk '{print $4}' | sort -r)

if [ ${#all_s3_files[@]} -eq 0 ]; then
    echo "No backups (.tar.gz files) found in the S3 bucket."
    exit 0
fi

echo "Please select the point-in-time you wish to restore to:"

PS3="Enter the backup number (or 'q' to quit): "

options=()
for filename in "${all_s3_files[@]}"; do
    if [ -n "$filename" ]; then
        date_time=$(echo "$filename" | cut -d'_' -f1-2 | sed 's/_/ /')
        type=$(echo "$filename" | cut -d'_' -f4 | cut -d'.' -f1)
        options+=("Date: $date_time  (Type: $type)")
    fi
done

select chosen_option in "${options[@]}" "Exit"; do
    if [[ "$REPLY" == "q" || "$chosen_option" == "Exit" ]]; then
        echo "Operation cancelled."
        exit 0
    fi

    if [[ "$REPLY" -gt 0 && "$REPLY" -le ${#options[@]} ]]; then
        selected_file="${all_s3_files[$((REPLY-1))]}"
        echo "You have selected: $selected_file"
        break
    else
        echo "Invalid option. Please try again."
    fi
done

echo
echo "Analyzing backup chain from S3..."
restore_chain=()
selected_file_type=$(echo "$selected_file" | cut -d'_' -f4 | cut -d'.' -f1)

full_backup_anchor=""
for file in "${all_s3_files[@]}"; do
    if [[ "$file" == *"_monthly.tar.gz" && "$file" < "$selected_file" || "$file" == "$selected_file" ]]; then
        full_backup_anchor=$file
        break
    fi
done

if [ -z "$full_backup_anchor" ]; then
    echo "Error: Could not find a full (monthly) backup anchor for the selected file." >&2
    exit 1
fi
restore_chain+=("$full_backup_anchor")

weekly_backup_anchor=""
if [[ "$selected_file_type" == "weekly" || "$selected_file_type" == "daily" ]]; then
    for file in "${all_s3_files[@]}"; do
        if [[ "$file" == *"_weekly.tar.gz" && "$file" > "$full_backup_anchor" && ("$file" < "$selected_file" || "$file" == "$selected_file") ]]; then
            weekly_backup_anchor=$file
            break
        fi
    done
    if [ -n "$weekly_backup_anchor" ]; then
        restore_chain+=("$weekly_backup_anchor")
    fi
fi

if [[ "$selected_file_type" == "daily" ]]; then
    start_point="${weekly_backup_anchor:-$full_backup_anchor}"
    
    daily_backups_to_add=()
    for file in "${all_s3_files[@]}"; do
        if [[ "$file" == *"_daily.tar.gz" && "$file" > "$start_point" && ("$file" < "$selected_file" || "$file" == "$selected_file") ]]; then
            daily_backups_to_add+=("$file")
        fi
    done
    for (( i=${#daily_backups_to_add[@]}-1 ; i>=0 ; i-- )); do
        restore_chain+=("${daily_backups_to_add[i]}")
    done
fi

echo
read -p "Enter the full path of the directory to restore the backup to: " destination_path
if [ -z "$destination_path" ]; then echo "Error: No destination path was specified." >&2; exit 1; fi
if [ ! -d "$destination_path" ]; then
    read -p "The directory '$destination_path' does not exist. Do you want to create it? (y/n): " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then mkdir -p "$destination_path"; else echo "Restore cancelled."; exit 0; fi
fi

echo
echo "--- S3 RESTORE SUMMARY ---"
echo "The following backup chain will be downloaded and restored in order:"
for file_in_chain in "${restore_chain[@]}"; do
    echo "  -> $file_in_chain"
done
echo
echo "Restore to:        $destination_path"
echo "--------------------------"
read -p "Are you sure you want to continue? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting restore process..."
    
    for file_to_restore in "${restore_chain[@]}"; do
        TEMP_DOWNLOAD_PATH="/tmp/$file_to_restore"
        
        echo "Downloading: $file_to_restore"
        aws s3 cp "s3://$S3_BUCKET/$file_to_restore" "$TEMP_DOWNLOAD_PATH"
        if [ $? -ne 0 ]; then echo "Error: Download failed for $file_to_restore." >&2; exit 1; fi

        echo "Applying: $file_to_restore"
        tar -xzf "$TEMP_DOWNLOAD_PATH" -C "$destination_path"
        if [ $? -ne 0 ]; then
            echo "Error: A critical issue occurred during the extraction of $file_to_restore." >&2
            exit 1
        fi
        
        rm "$TEMP_DOWNLOAD_PATH"
    done
    
    echo
    echo "Success! The backup chain has been correctly restored to '$destination_path'."

else
    echo "Restore cancelled by user."
fi

exit 0