# Backup System Project (Proyecto D)

This project implements a simple yet robust automated backup system using bash scripts. It features a unique "accelerated time" model for demonstration and testing purposes, where days, weeks, and months are simulated in minutes.

The system is composed of three main scripts: one for configuration, one for performing the automated backups, and one for restoring from a backup.

## Features

-   **Easy Configuration**: Set your source and backup destination directories with a single command.
-   **Automated Backups**: Uses `cron` to run the backup script automatically every minute.
-   **Smart Rotation Policy**: Implements a rotation scheme for daily, weekly, and monthly backups to save space.
    -   Keeps the last 4 "daily" backups.
    -   Keeps the last 3 "weekly" backups.
    -   Keeps the last 12 "monthly" backups.
-   **Simple Restoration**: An interactive script allows you to view all available backups and choose one to restore.

## Requirements

To run this project, you will need a Linux-based environment (like Ubuntu) with the following tools installed:

-   `bash` (The Bourne Again SHell)
-   `tar` (The GNU version of the tar archiving utility)
-   `crontab` (for scheduling the automatic backups)

## How It Works: The "Accelerated Time" Model

To facilitate testing, this project does not use real-world time. Instead, it simulates a compressed timeline:

-   **1 Minute = 1 Day**
-   **4 Days = 1 Week** (Monday, Tuesday, Wednesday, Sunday)
-   **3 Weeks = 1 Month** (12 Days/Minutes total)

The backup type is determined by the current system minute (`n = current_minute + 1`):
-   **Monthly Backup**: If `n` is a multiple of 12 (`n % 12 == 0`).
-   **Weekly Backup**: If `n` is a multiple of 4 but not 12 (`n % 4 == 0`). This simulates a "Sunday".
-   **Daily Backup**: In all other cases (`n % 4` is 1, 2, or 3). This simulates "Monday", "Tuesday", or "Wednesday".

## Setup and Installation

Follow these steps to get the backup system up and running.

**1. Clone or Download the Scripts**

Place `configurar_copia_seg.sh`, `hacer_copia_seg.sh`, and `restaurar_copia_seg.sh` in the same directory.

**2. Make the Scripts Executable**

You need to grant execution permissions to the scripts.
```bash
chmod +x configurar_copia_seg.sh hacer_copia_seg.sh restaurar_copia_seg.sh
```

**3. Run the Configuration Script**

This script saves the source directory (what you want to back up) and the destination directory (where the backups will be stored).

```bash
# Usage: ./configurar_copia_seg.sh <destination_path> <source_path>
# Example:
./configurar_copia_seg.sh /home/user/backups /home/user/documents
```

This will create a configuration file at `~/.conf_copia_seg.txt`.

**4. Set up the Cron Job**

The `hacer_copia_seg.sh` script needs to run every minute. Edit your crontab file:

```bash
crontab -e
```

Add the following line to the file. **Make sure to replace `/path/to/project`** with the absolute path to the directory where you saved the scripts.

```crontab
* * * * * /path/to/project/hacer_copia_seg.sh
```

Save and exit the editor. The cron daemon will now execute the backup script every minute.

## Usage

### Making Backups

Backups are created automatically by the cron job you set up in the installation steps. There is no need to run the `hacer_copia_seg.sh` script manually.

### Restoring a Backup

To restore your files from a previous backup:

1.  Run the restoration script:
    ```bash
    ./restaurar_copia_seg.sh
    ```

2.  The script will display a numbered list of all available backups, showing their date and type (daily, weekly, monthly).

3.  Enter the number corresponding to the backup you wish to restore.

4.  The script will unpack the chosen backup archive into the source directory, overwriting existing files after confirmation.

## File Structure

```
.
├── configurar_copia_seg.sh   # Script to configure paths
├── hacer_copia_seg.sh      # Script to perform automatic backups
├── restaurar_copia_seg.sh    # Script to restore from a backup
└── README.md
```

The configuration file will be located in your home directory: `~/.conf_copia_seg.txt`.