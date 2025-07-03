#!/bin/bash

CONFIG_FILE="$HOME/.conf_copia_seg.txt"

show_usage() {
    echo "Usage: $0 <destination_path> <source_path>"
    echo "Example: $0 /home/user/backups /home/user/documents"
    echo
    echo "  <destination_path>: The directory where backups will be stored."
    echo "  <source_path>: The directory to be backed up."
}

if [ "#" -ne 2 ]; then
    echo "Error: Wrong number of arguments"
    show_usage
    exit 1
fi 

DEST_PATH=$1
SOURCE_PATH=$2

if [ ! -d "$SOURCE_PATH" ]; then
    echo "Warning: Source directory '$SOURCE_PATH' does not exist."
    echo "The configuration will be saved, please ensure the directory is created before the first backup."
fi

if [ ! -d "$DEST_PATH" ]; then
    echo "Warning: Destination directory '$DEST_PATH' does not exist."
    echo "The directory is being created..."
    mkdir -p "$DEST_PATH"
    if [ $? -ne 0 ]; then
        echo "Error: Could not create destination directory '$DEST_PATH'."
        exit 1
    fi
    echo "Destination directory created successfully."
fi

echo "DESTINATION_DIR=\"$DEST_PATH\"" > "$CONFIG_FILE"
echo "SOURCE_DIR=\"$SOURCE_PATH\"" >> "$CONFIG_FILE"

echo "--------------------------------------------------"
echo "Configuration saved successfully to $CONFIG_FILE"
echo "--------------------------------------------------"
echo "Source Directory:      $SOURCE_PATH"
echo "Destination Directory: $DEST_PATH"
echo