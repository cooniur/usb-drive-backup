# USB Flash Backup Tool for MacOS

A safe, interactive macOS script to create a **bit-for-bit raw image backup** of a USB flash drive using `dd`.

------------------------------------------------------------------------

## ⚠️ Warning

This tool uses `dd` (sometimes called *disk destroyer*).

Selecting the wrong disk can permanently erase data.

Always double-check disk identifiers.

------------------------------------------------------------------------

## Requirements

-   macOS (Tahoe 26.3 or later recommended)
-   Terminal access
-   Admin privileges (sudo)

Built-in macOS tools used:

-   bash 
    -   `GNU bash, version 3.2.57(1)-release (x86_64-apple-darwin25)`
-   diskutil
-   dd
-   shasum
-   gzip (optional)

------------------------------------------------------------------------

## Usage

Run from Terminal:

    ./usb-drive-backup.sh

The script will:

1.  Display available disks
2.  Ask you to select the source disk (e.g. disk2)
3.  Require explicit confirmation
4.  Ask for output directory and filename
5.  Optionally enable gzip compression
6.  Unmount the disk
7.  Run the backup with progress display
8.  Generate SHA-256 checksum
9.  Remount the disk

------------------------------------------------------------------------

## Output Files

If not compressed:

    disk2_backup_YYYYMMDD_HHMMSS.img
    disk2_backup_YYYYMMDD_HHMMSS.img.sha256

If compressed:

    disk2_backup_YYYYMMDD_HHMMSS.img.gz
    disk2_backup_YYYYMMDD_HHMMSS.img.gz.sha256

------------------------------------------------------------------------

## Restore From Backup

### Restore uncompressed image

    diskutil list
    diskutil unmountDisk /dev/diskX

    sudo dd if=backup.img of=/dev/rdiskX bs=4m status=progress

    diskutil eject /dev/diskX

------------------------------------------------------------------------

### Restore compressed image

    gunzip -c backup.img.gz | sudo dd of=/dev/rdiskX bs=4m status=progress

------------------------------------------------------------------------

## How It Works

The script uses:

-   /dev/diskX → buffered device (slower)
-   /dev/rdiskX → raw device (faster)

Block size is set to:

    bs=4m

for optimal throughput on USB media.

------------------------------------------------------------------------

## Best Practices

-   Verify disk using `diskutil info`
-   Keep checksum file with image
-   Store backups on external drives or NAS
-   Never restore to a smaller drive

------------------------------------------------------------------------

## Disclaimer

Use at your own risk.

This script performs raw disk operations and can destroy data if
misused.

------------------------------------------------------------------------

## License (MIT)

See [LICENSE](LICENSE).
