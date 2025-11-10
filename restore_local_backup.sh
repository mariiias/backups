#!/bin/bash

# This script restores a backup chain (full, differential, incremental)
# based on a single backup file selected by the user.

CONFIG_FILE="$HOME/.backup_conf.txt" 

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found." >&2
    echo "Please run the 'setup_backup.sh' script first." >&2
    exit 1
fi

source "$CONFIG_FILE"

if [ -z "$DESTINATION_DIR" ] || [ ! -d "$DESTINATION_DIR" ]; then
    echo "Error: The backup directory '$DESTINATION_DIR' is invalid or does not exist." >&2
    exit 1
fi

echo "Searching for backups in: $DESTINATION_DIR"

mapfile -t backup_files < <(find "$DESTINATION_DIR" -maxdepth 1 -name "*_backup_*.tar.gz" | sort -r)

if [ ${#backup_files[@]} -eq 0 ]; then
    echo "No backups were found."
    exit 0
fi

echo "Please select the point-in-time you wish to restore to:"

PS3="Enter the backup number (or 'q' to quit): "

options=()
for file in "${backup_files[@]}"; do
    filename=$(basename "$file")
    date_time=$(echo "$filename" | cut -d'_' -f1-2 | sed 's/_/ /')
    type=$(echo "$filename" | cut -d'_' -f4 | cut -d'.' -f1)
    options+=("Date: $date_time  (Type: $type)")
done

select chosen_option in "${options[@]}" "Quit"; do
    if [[ "$REPLY" == "q" || "$chosen_option" == "Quit" ]]; then
        echo "Operation cancelled."
        exit 0
    fi

    if [[ "$REPLY" -gt 0 && "$REPLY" -le ${#options[@]} ]]; then
        selected_file="${backup_files[$((REPLY-1))]}"
        echo "You have selected: $(basename "$selected_file")"
        break 
    else
        echo "Invalid option. Please try again."
    fi
done

echo
echo "Analyzing backup chain..."
restore_chain=()
selected_file_type=$(echo "$(basename "$selected_file")" | cut -d'_' -f4 | cut -d'.' -f1)

full_backup_anchor=$(find "$DESTINATION_DIR" -maxdepth 1 -name "*_backup_monthly.tar.gz" -not -newer "$selected_file" | sort -r | head -n 1)

if [ -z "$full_backup_anchor" ]; then
    echo "Error: Could not find a full (monthly) backup anchor for the selected file." >&2
    echo "A full backup is required to start the restore chain." >&2
    exit 1
fi
restore_chain+=("$full_backup_anchor")

if [[ "$selected_file_type" == "weekly" || "$selected_file_type" == "daily" ]]; then
    weekly_backup_anchor=$(find "$DESTINATION_DIR" -maxdepth 1 -name "*_backup_weekly.tar.gz" -newer "$full_backup_anchor" -not -newer "$selected_file" | sort -r | head -n 1)
    if [ -n "$weekly_backup_anchor" ]; then
        restore_chain+=("$weekly_backup_anchor")
    fi
fi

if [[ "$selected_file_type" == "daily" ]]; then
    start_point="${weekly_backup_anchor:-$full_backup_anchor}"
    
    mapfile -t daily_backups < <(find "$DESTINATION_DIR" -maxdepth 1 -name "*_backup_daily.tar.gz" -newer "$start_point" -not -newer "$selected_file" | sort)
    for daily_file in "${daily_backups[@]}"; do
        restore_chain+=("$daily_file")
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
echo "--- RESTORE SUMMARY ---"
echo "The following backup chain will be restored in order:"
for file_in_chain in "${restore_chain[@]}"; do
    echo "  -> $(basename "$file_in_chain")"
done
echo
echo "Restore to:        $destination_path"
echo "-----------------------"
read -p "Are you sure you want to continue? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Restoring... please wait."
    
    for file_to_restore in "${restore_chain[@]}"; do
        echo "Applying: $(basename "$file_to_restore")"
        tar -xzf "$file_to_restore" -C "$destination_path"
        if [ $? -ne 0 ]; then
            echo "Error: A critical issue occurred during the restoration of $(basename "$file_to_restore")." >&2
            echo "The restore is incomplete and the data may be corrupted." >&2
            exit 1
        fi
    done
    
    echo
    echo "Success! The backup chain has been correctly restored to '$destination_path'."

else
    echo "Restore cancelled by user."
fi

exit 0