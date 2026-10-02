# lazyBackup
Windows Backup & Restore a Windows Partiton from WinPE with a DISM batch script.

Fast Windows partition backup and restore using Microsoft's built-in DISM imaging tool.

lazyBackup is a portable batch script designed to run from WinPE. It uses marker files and simple configuration options to automate Windows partition backups and restores without requiring additional software.

## Features

- Backup Windows partitions to WIM images using DISM
- Restore WIM images to a target partition
- Automatic detection using marker files
- Support for local disks, USB storage and network shares
- Optional unattended operation through script configuration
- Computer name based image naming
- Optional computer-specific subdirectories
- Automatic shutdown or reboot after completion
- Designed for WinPE environments
- No installation required

## Requirements

- Windows PE (recommended)
- Administrator privileges
- DISM available in the environment

For Windows system partition backups and restores, running from WinPE is strongly recommended.

## Marker Files

lazyBackup can automatically detect required drives and settings using marker files.

### `.pcname`

Contains the desired computer name.

Example:

```text
OFFICE-PC
```

### `.DRIVETOBACKUP`

Place this file in the root of the Windows partition to be backed up.

Example:

```text
C:\.DRIVETOBACKUP
```

### `.DRIVETORESTORE`

Place this file in the root of the target partition for restore operations.

Example:

```text
D:\.DRIVETORESTORE
```

### `.BACKUPSTORE`

Marks a drive as a backup storage location.

Example:

```text
E:\.BACKUPSTORE
```

### `.USBBACKUPSTORE`

Marks an external drive as a backup storage location.

Example:

```text
F:\.USBBACKUPSTORE
```

`.USBBACKUPSTORE` has priority over `.BACKUPSTORE`.

## Storage Detection

lazyBackup selects storage in the following order:

1. Configured `STORAGE_PATH`
2. Drive containing `.USBBACKUPSTORE`
3. Drive containing `.BACKUPSTORE`
4. Manual user input

## Configuration

The following variables can be configured directly in the script.

### Backup Location

```batch
set "WIM_SUBDIR=WIM"
```

Examples:

```batch
set "WIM_SUBDIR=Images"
set "WIM_SUBDIR=Backups\Windows"
```

### Computer Name Subfolder

```batch
set "USE_COMPUTER_NAME_SUBFOLDER=Y"
```

Result:

```text
WIM\OFFICE-PC\OFFICE-PC_20261001_1200.wim
```

### Operation Mode

```batch
set "OPERATION_MODE=B"
```

Available values:

```text
B = Backup
R = Restore
E = Exit
```

### Post Operation Action

```batch
set "POST_OPERATION_ACTION=S"
```

Available values:

```text
R = Reboot
S = Shutdown
N = Nothing
```

### Network Configuration

Skip all network prompts:

```batch
set "MAP_NETWORK=N"
```

Any other value (including empty) enables network configuration.

### Fixed Storage Location

Example:

```batch
set "STORAGE_PATH=\\SERVER\Backups"
```

This bypasses marker-based storage detection and is useful for unattended operation.

## Backup Image Naming

Images are automatically named using:

```text
COMPUTERNAME_YYYYMMDD_HHMM.wim
```

Example:

```text
OFFICE-PC_20261001_2130.wim
```

## Network Shares

lazyBackup can store backups on network shares.

Example:

```text
\\SERVER\Backups
```

The script can map a network drive and then save or restore WIM images from that location.

## Typical Backup Workflow

1. Boot into WinPE
2. Start lazyBackup
3. Detect computer name
4. Detect source partition
5. Detect backup storage
6. Create WIM image
7. Reboot, shut down or exit

## Typical Restore Workflow

1. Boot into WinPE
2. Start lazyBackup
3. Select restore image
4. Select restore target
5. Optional partition format
6. Apply image using DISM
7. Reboot, shut down or exit

## Safety Features

- Confirmation before backup
- Confirmation before restore
- Additional confirmation before formatting
- Computer name verification during restore
- Restore image selection menu
- Optional format step before restore

## Example Unattended Backup

```batch
set "OPERATION_MODE=B"
set "POST_OPERATION_ACTION=S"
set "MAP_NETWORK=N"
set "STORAGE_PATH=\\SERVER\Backups"
```

This performs an unattended backup and shuts down the system afterwards.

## Version

Current release:

**v0.8.1**

## License

GPL-3.0
## Version 0.8.1

### Changes

- Improved Backup and Restore workflow
- Added configurable `STORAGE_PATH` for unattended operation
- Added automatic storage detection using:
  - `.BACKUPSTORE`
  - `.USBBACKUPSTORE`
- Added runtime storage handling:
  - `DETECTED_STORAGE_PATH`
  - `ACTIVE_STORAGE_PATH`
- Improved Backup and Restore summaries
- Improved restore safety checks
- Added computer-name verification before restore
- Improved configuration and help text
- Refactored code structure and variable naming
