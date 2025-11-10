
# Advanced Bash Backup System with AWS S3

This project implements a robust, automated backup system using bash scripts, featuring a professional backup strategy (Full, Differential, Incremental) and off-site storage integration with AWS S3. It includes an intelligent restoration system capable of rebuilding the backup history from both local files and the cloud.

The system uses a unique "accelerated time" model, where days and weeks are simulated in minutes, allowing for rapid testing and demonstration of its long-term rotation policies.

## Key Features

-   **Professional Backup Strategy**: Implements a Full (monthly), Differential (weekly), and Incremental (daily) backup strategy to optimize speed and storage space.
-   **Cloud Integration**: Securely uploads every backup to an AWS S3 bucket, providing a robust off-site copy for disaster recovery.
-   **State Synchronization**: The "brain" of the incremental backup system (the `.snar` file) is also synced with S3, ensuring you can continue your backup chain even if the local machine is lost.
-   **Automated Rotation**: Automatically cleans up local backups to save disk space, while keeping a full history in the cloud.
-   **Dual Restore Options**: Includes two separate scripts for different recovery scenarios:
    -   `restore_local_backup.sh`: For quick recovery from local files.
    -   `restore_from_cloud.sh`: For disaster recovery, rebuilding everything from S3.
-   **Intelligent Chain Restoration**: The restore scripts automatically calculate the correct sequence of files (full -> differential -> incrementals) needed to restore to a specific point in time.
-   **Easy Configuration**: A single command sets up your source directory, local backup destination, and S3 bucket.
-   **Accelerated Time Model**: A unique feature that simulates months of backups in just a few hours, perfect for testing.

## How the Backup Strategy Works

This system is more efficient than creating a full backup every time. Here's how it works:

1.  **Monthly Backup (Full)**
    -   **What:** A complete, self-contained copy of all your data.
    -   **Why:** This is your solid anchor. Restoring a full backup is simple, but they are large and slow to create. The system ensures the very first backup is always a full one.

2.  **Weekly Backup (Differential)**
    -   **What:** Backs up all files that have changed *since the last FULL (monthly) backup*.
    -   **Why:** Faster than a full backup. To restore, you only need two files: the last full backup and this one weekly backup.

3.  **Daily Backup (Incremental)**
    -   **What:** Backs up only the files that have changed *since the PREVIOUS backup of any type*.
    -   **Why:** Extremely fast and small. To restore, you need the full backup, the last weekly backup, and all daily backups since then, applied in order. Our smart restore script handles this for you.

## Requirements

-   A Linux-based environment (like Ubuntu).
-   `bash`: The Bourne Again SHell.
-   `tar`: The GNU version of the tar archiving utility.
-   `crontab`: For scheduling automatic backups.
-   `awscli`: The AWS Command Line Interface.

## Setup and Installation

Follow these steps carefully to get the backup system up and running.

### 1. Prerequisites: AWS CLI Configuration

This system requires credentials to upload files to your S3 bucket.

1.  **Create an IAM User in AWS**: For security, do not use your root AWS account. Create a dedicated IAM user with programmatic access.
2.  **Attach Permissions**: Grant this user `AmazonS3FullAccess` permissions so it can read and write to your S3 buckets.
3.  **Generate Access Keys**: Create an `Access Key ID` and a `Secret Access Key` for this user. **Save them securely.**
4.  **Configure AWS CLI**: On your server, run `aws configure` and enter the credentials you just generated, along with your default AWS region (e.g., `us-east-1`).

### 2. Download and Prepare the Scripts

Place all the project scripts (`setup_backup.sh`, `create_backup.sh`, `restore_local_backup.sh`, `restore_from_cloud.sh`) in the same directory.

### 3. Make the Scripts Executable

```bash
chmod +x setup_backup.sh create_backup.sh restore_local_backup.sh restore_from_cloud.sh
```

### 4. Run the Configuration Script

This script creates the `~/.backup_conf.txt` file which stores your paths and S3 bucket name.

```bash
# Usage: ./setup_backup.sh <local_destination_path> <source_path> [s3_bucket_name]
# Example:
./setup_backup.sh /home/user/backups /var/www/my-website my-secure-backup-bucket-2025
```

### 5. Set up the Cron Job

The `create_backup.sh` script needs to run every minute to simulate the "accelerated time".

1.  Edit your crontab file: `crontab -e`
2.  Add the following line. **Replace `/path/to/project`** with the absolute path to where you saved the scripts.
    ```crontab
    * * * * * /path/to/project/create_backup.sh
    ```
3.  Save and exit. The system is now live and will start creating backups.

## Usage

### Creating Backups

Backups are created **automatically** by the cron job. The first time the script runs, it will automatically create a **Full (monthly)** backup to initialize the system, regardless of the time.

### Restoring Backups

You have two powerful scripts for restoration, depending on the scenario.

#### Scenario A: Quick Local Restore

Use this when your local backups are intact and you need a quick recovery (e.g., you accidentally deleted a file).

1.  Run the local restore script:
    ```bash
    ./restore_local_backup.sh
    ```
2.  The script will display a numbered list of all local backups.
3.  Choose the **point-in-time** you want to return to.
4.  The script will automatically find the required chain of backups (full, differential, and incrementals) and show you the restore plan.
5.  Enter a destination path (ideally an empty folder for safety) and confirm.

#### Scenario B: Disaster Recovery from the Cloud

Use this in a worst-case scenario where your server is lost or the local backup drive has failed.

1.  Run the cloud restore script:
    ```bash
    ./restore_from_cloud.sh
    ```
2.  The script will connect to your S3 bucket and show a list of all backups stored there.
3.  Choose the **point-in-time** you want to return to.
4.  The script will automatically calculate the chain of files needed, downloading them one by one and restoring them in the correct order.
5.  Enter a destination path and confirm.

## How It Works: The "Accelerated Time" Model

-   **1 Minute = 1 Day**
-   **4 Days = 1 Week** (Monday, Tuesday, Wednesday, Sunday)
-   **3 Weeks = 1 Month** (12 Days/Minutes total)

The backup type is determined by the current system minute (`n = current_minute + 1`):
-   **Monthly Backup**: If `n` is a multiple of 12 (`n % 12 == 0`).
-   **Weekly Backup**: If `n` is a multiple of 4 (but not 12). This simulates a "Sunday".
-   **Daily Backup**: In all other cases. This simulates "Monday", "Tuesday", or "Wednesday".

## File Structure

```
.
├── setup_backup.sh
├── create_backup.sh
├── restore_local_backup.sh
├── restore_from_cloud.sh
└── README.md
```

-   `~/.backup_conf.txt`: Stores your configuration.
-   `[destination_path]/backup.snar`: The "brain" file for `tar` that tracks incremental changes.
-   `[destination_path]/monthly_backup.snar`: A stable copy of the last full backup's state, used for differentials.