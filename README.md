# lazyBackup

Fast offline backup and restore of Windows partitions with Microsoft's built-in DISM imaging tool.

lazyBackup is a portable batch-based recovery solution designed primarily for Windows PE. It can capture Windows partitions into WIM images, restore WIM or ESD images, use local, USB, UNC, or mapped network storage, build a dedicated WinPE ISO, integrate lazyBackup into the Windows Boot Manager, and create a combined Windows 11 and lazyBackup installation ISO.

## Important safety notice

Backup and restore operations work directly with partitions and image files. Formatting or restoring the wrong partition can permanently destroy data.

Always verify:

- source partition
- restore target
- storage path
- selected image
- computer name
- final summary

Test newly built recovery media in a virtual machine before using it on physical hardware.

## Current development version

```text
v0.9.1
```

## Main features

- Capture Windows partitions to WIM images with DISM
- Restore WIM and ESD images to a selected target partition
- Restore Windows installation images such as `install.wim` and `install.esd`
- Run from WinPE while the installed Windows system is offline
- Detect computer name, source, target, and storage through marker files
- Use interactive menus when marker files or configuration values are missing
- Support local disks, USB storage, mapped network drives, and UNC paths
- Prefer `.USBBACKUPSTORE` over `.BACKUPSTORE`
- Store images in optional computer-specific subdirectories
- Create timestamped image filenames
- Evaluate and persist DISM exit codes for Backup and Restore
- Optionally validate a newly created WIM with `DISM /Get-WimInfo`
- Persist the last operation result and a local DISM log copy on the Windows partition
- Show a success message after the next Windows logon
- Show a high-visibility HTA error dialog after a failed operation
- Optionally create `lazyBackup FAILED.txt` on the desktop
- Optionally write results to the Windows Application log
- Reboot after a failed unattended Backup by default so Windows can report the failure
- Keep WinPE open after a failed Restore by default
- Select a configurable WIM subdirectory, with `WIM` as the Enter default
- Select a free network drive letter automatically from `Z:` backwards
- Skip `X:` during automatic network mapping because `X:` is the WinPE RAM drive
- Configure DISM scratch storage automatically or manually
- Use Backup or Restore as a timed default while keeping manual selection available
- Start a configured backup automatically after a final confirmation countdown
- Keep Restore protected by explicit confirmations
- Select reboot, shutdown, or no action after completion
- Configure the post-operation delay in seconds
- Use external `.lazybackup.conf` files with priority handling
- Select or preconfigure the WinPE keyboard layout
- Build a BIOS and UEFI bootable lazyBackup WinPE ISO
- Build a combined Windows 11 and lazyBackup ISO with two boot entries
- Update lazyBackup in an existing combined Windows 11 ISO without rebuilding from the original Windows source ISO
- Integrate lazyBackup Recovery into the Windows Boot Manager
- Automatically request administrator privileges through Windows UAC in both ISO builders
- Use portable project-relative paths with optional absolute overrides

## Recommended project structure

```text
lazybackup\
├── lazybackup.bat
├── .lazybackup.conf
├── README.md
├── LICENSE
│
├── ResultNotification\
│   ├── lazyBackup_Result.hta
│   └── lazyBackup_ResultNotifier.ps1
│
├── Windows ISO here\
│   └── exactly one Windows ISO
│
├── ISO output\
│   ├── lazyBackup_WinPE.iso
│   └── <Windows-source-name>_lazy.iso
│
├── marker files examples\
│   ├── .BACKUPSTORE
│   ├── .DRIVETOBACKUP
│   ├── .DRIVETORESTORE
│   ├── .pcname
│   └── .USBBACKUPSTORE
│
├── ISO builder\
│   ├── build_lazyBackup_WinPE.bat
│   ├── build_Windows11_with_lazyBackup_in_ISO-boot-menu.bat
│   ├── update_lazyBackup_in_existing_Windows11_ISO.bat
│   └── Builder files\
│       ├── choice.exe
│       ├── findstr.exe
│       └── startnet.cmd
│
└── install lazyBackup to Boot Menu BCD\
    └── lazyBackup_BootIntegration.bat
```

The ISO builders determine their own location through `%~dp0` and use the parent directory as the lazyBackup project root. Therefore, the builders can be started from another current working directory.

Technical helper files are grouped under `ISO builder\Builder files`. Marker-file examples remain visible in `marker files examples` so they can be copied by the user when needed. The dedicated WinPE builder also copies these examples into the WinPE image.

The result-notification files belong in `ResultNotification\` beside the main project files. They run under the installed Windows system after reboot, not inside WinPE. The Boot Manager integration copies them to its stable local directory and registers the PowerShell notifier for user logon.

## Requirements

### Running lazyBackup

- Administrator privileges
- DISM available in the environment
- Windows PE or Windows Recovery Environment recommended

For system-partition backup and restore, run lazyBackup while the installed Windows partition is offline.

### Building WinPE and combined ISO media

Install:

- Windows ADK with **Deployment Tools**
- Matching Windows PE add-on

The builders use tools such as:

```text
copype.cmd
Dism.exe
Oscdimg.exe
Bcdedit.exe
Robocopy.exe
PowerShell.exe
```

Both builders check for administrator privileges. If required, the builder restarts itself with elevated rights and displays the normal Windows UAC prompt.

## Running lazyBackup

### Dedicated lazyBackup WinPE ISO

The dedicated ISO provides:

- Legacy BIOS boot
- UEFI boot
- no BIOS or UEFI keypress prompt
- configurable keyboard layout
- keyboard selection menu when no layout is preset
- lazyBackup startup menu
- automatic lazyBackup launch after a countdown
- Command Prompt access for maintenance

Typical flow:

```text
Computer or VM starts
        ↓
WinPE starts
        ↓
Configured keyboard layout is applied
or the keyboard menu is displayed
        ↓
lazyBackup WinPE menu
        ↓
lazyBackup starts automatically or manually
```

The WinPE menu provides:

```text
[L] Start lazyBackup
[C] Open Command Prompt
```

Type `exit` in the maintenance Command Prompt to return to the WinPE menu.

### Windows Recovery Environment

1. Start the Windows recovery environment.
2. Open **Troubleshoot**.
3. Open **Advanced options**.
4. Open **Command Prompt**.
5. Navigate to the directory containing `lazybackup.bat`.
6. Run:

```batch
lazybackup.bat
```

### Windows installation media

1. Boot from a Windows installation USB drive or ISO.
2. Wait for Windows Setup.
3. Press Shift+F10.
4. Navigate to the lazyBackup directory.
5. Run:

```batch
lazybackup.bat
```

## Marker files

Marker files are optional. If a required marker is missing, lazyBackup presents a menu or asks for the missing value.

### `.pcname`

Contains the computer name used for image naming.

```text
OFFICE-PC
```

### `.DRIVETOBACKUP`

Place this empty file in the root of the partition to capture.

```text
C:\.DRIVETOBACKUP
```

### `.DRIVETORESTORE`

Place this empty file in the root of the intended restore target.

```text
D:\.DRIVETORESTORE
```

### `.BACKUPSTORE`

Marks a local, mapped network, or other storage root as backup storage.

```text
E:\.BACKUPSTORE
Z:\.BACKUPSTORE
```

For automatic recognition of a mapped network share, place the empty marker in the root of the share:

```text
\\server\share\.BACKUPSTORE
```

### `.USBBACKUPSTORE`

Marks preferred USB backup storage.

```text
F:\.USBBACKUPSTORE
```

`.USBBACKUPSTORE` has priority over `.BACKUPSTORE`.

## Configuration files and priority

lazyBackup supports external `.lazybackup.conf` files.

The effective configuration is loaded in this priority order:

1. configuration on preferred USB storage containing `.USBBACKUPSTORE`
2. first configuration found in a drive root
3. configuration beside `lazybackup.bat`
4. built-in defaults in `lazybackup.bat`

Higher-priority settings override lower-priority settings when the configuration value is not empty.

Use this syntax:

```ini
NAME=Value
```

Do not use spaces around the equals sign:

```ini
# Correct
NAME=Value

# Incorrect
NAME = Value
```

Lines beginning with `#` are comments.

## Unattended backup requirements

For an unattended automatic backup, for example after a scheduled boot started by Task Scheduler, at least the following values must be configured and active:

```ini
WIM_SUBDIR=WIM
POST_OPERATION_ACTION=R
MAP_NETWORK=N
KEYBOARD_LAYOUT=0407:00000407
```

The automatic Backup mode and both countdowns must also be enabled:

```ini
OPERATION_MODE=B
OPERATION_MODE_TIMEOUT_SECONDS=15
BACKUP_CONFIRM_TIMEOUT_SECONDS=15
POST_OPERATION_DELAY_SECONDS=30
```

The required marker files should also be available:

```text
.pcname
.DRIVETOBACKUP
.BACKUPSTORE
```

For preferred USB backup storage, use:

```text
.USBBACKUPSTORE
```

With these settings and marker files, lazyBackup can select Backup, source partition, destination, WIM subdirectory, keyboard layout, final confirmation, and post-operation action without user interaction.

`MAP_NETWORK=N` is suitable only when the unattended backup does not need to create a network mapping. An unattended network backup additionally requires the network path, username, and authentication to be available without an interactive prompt.

Restore is not started automatically while `OPERATION_MODE=B`. Restore remains manually selectable by pressing `R` during the operation-mode countdown.

## Example interactive `.lazybackup.conf`

```ini
USE_COMPUTER_NAME_SUBFOLDER=Y

WIM_SUBDIR=
STORAGE_PATH=

OPERATION_MODE=B
OPERATION_MODE_TIMEOUT_SECONDS=15
BACKUP_CONFIRM_TIMEOUT_SECONDS=15

POST_OPERATION_ACTION=
POST_OPERATION_DELAY_SECONDS=30

MAP_NETWORK=
DRIVE_LETTER=
NETWORK_PATH=
NETWORK_USERNAME=
PASSWORD=

DISM_SCRATCH=

# Leave all keyboard presets commented to show the menu.
# KEYBOARD_LAYOUT=0407:00000407
```

This example keeps manual network, storage-subdirectory, keyboard, and post-operation choices available while using Backup as the timed default.

## Configuration reference

### `USE_COMPUTER_NAME_SUBFOLDER`

```ini
USE_COMPUTER_NAME_SUBFOLDER=Y
```

```text
Y = WIM_SUBDIR\COMPUTER_NAME\
N = store all images directly in WIM_SUBDIR\
```

### `WIM_SUBDIR`

```ini
WIM_SUBDIR=
```

An empty value displays the subdirectory prompt. Pressing Enter selects `WIM`.

```ini
WIM_SUBDIR=WIM
WIM_SUBDIR=Images
WIM_SUBDIR=Backups\Windows
```

### `STORAGE_PATH`

```ini
STORAGE_PATH=
```

An empty value allows marker-file detection or manual selection.

```ini
STORAGE_PATH=E
STORAGE_PATH=\\server\share
```

A fixed value takes priority over automatic storage detection.

### `OPERATION_MODE`

```text
B = Backup
R = Restore
```

A configured value becomes the timed default but does not remove the menu. During the countdown, another operation can still be selected.

```ini
OPERATION_MODE=B
```

Leave empty to wait indefinitely for a manual selection:

```ini
OPERATION_MODE=
```

### `OPERATION_MODE_TIMEOUT_SECONDS`

```ini
OPERATION_MODE_TIMEOUT_SECONDS=15
```

This timeout is used only when `OPERATION_MODE` contains `B`, `BACKUP`, `R`, or `RESTORE`.

```text
0 or empty = no automatic operation start
10         = wait 10 seconds
15         = wait 15 seconds
30         = wait 30 seconds
```

### `BACKUP_CONFIRM_TIMEOUT_SECONDS`

```ini
BACKUP_CONFIRM_TIMEOUT_SECONDS=15
```

At the final backup summary:

```text
Y        = start immediately
N        = cancel
No input = start automatically after the countdown
```

```text
0 or empty = wait indefinitely for Y or N
5          = start after 5 seconds
10         = start after 10 seconds
15         = start after 15 seconds
30         = start after 30 seconds
```

This timeout applies to Backup only. Restore keeps its explicit safety confirmations.

### `POST_OPERATION_ACTION`

```text
R = Reboot
S = Shutdown
N = No reboot or shutdown
```

Leave empty to display the action menu:

```ini
POST_OPERATION_ACTION=
```

### `POST_OPERATION_DELAY_SECONDS`

```ini
POST_OPERATION_DELAY_SECONDS=120
```

```text
0   = execute immediately
10  = wait 10 seconds
30  = wait 30 seconds
120 = wait 2 minutes
300 = wait 5 minutes
```

Invalid values fall back to 120 seconds.

### `MAP_NETWORK`

```ini
MAP_NETWORK=N
```

`N` skips all network prompts. Any other value, including an empty value, enables the network configuration prompt.

### `DRIVE_LETTER`

Recommended automatic setting:

```ini
DRIVE_LETTER=
```

When empty, lazyBackup searches backwards:

```text
Z:, Y:, W:, V: ... D:
```

`X:` is skipped because it is the WinPE RAM drive. Existing local volumes and network mappings are treated as occupied.

### `NETWORK_PATH`, `NETWORK_USERNAME`, and `PASSWORD`

```ini
NETWORK_PATH=
NETWORK_USERNAME=
PASSWORD=
```

Leave values empty for interactive entry.

```ini
NETWORK_PATH=\\192.168.170.9\v
NETWORK_USERNAME=DOMAIN\USER
```

Leaving `PASSWORD` empty lets `net use` request the password without displaying the entered characters. Avoid storing production passwords as readable text in scripts or configuration files.

### `DISM_SCRATCH`

```ini
DISM_SCRATCH=
```

An empty value enables automatic selection.

Automatic behavior:

- local WIM storage: use `lazyBackupTemp` on the storage volume
- UNC or mapped network storage: use a suitable local drive
- Backup: avoid the captured Windows partition
- Restore: avoid the restore target partition
- final fallback: use `X:\Temp`

### `VERIFY_BACKUP_IMAGE`

```ini
VERIFY_BACKUP_IMAGE=Y
```

`Y` runs an additional `DISM /Get-WimInfo` check against the newly created WIM before Backup is reported as successful. `N` disables this additional check.

### `BACKUP_FAILURE_ACTION`

```ini
BACKUP_FAILURE_ACTION=R
```

Action after a failed Backup:

- `R` = reboot
- `S` = shut down
- `N` = remain in WinPE

The default is `R`. The existing Windows installation remains available after a failed Backup, and Windows can display the persistent failure notification after reboot and logon.

### `RESTORE_FAILURE_ACTION`

```ini
RESTORE_FAILURE_ACTION=N
```

Action after a failed Restore:

- `R` = reboot
- `S` = shut down
- `N` = remain in WinPE

The safe default is `N`. An incomplete Restore can leave the target Windows installation unable to boot, so lazyBackup remains in WinPE instead of restarting automatically.

### Windows result notifications

```ini
SHOW_SUCCESS_MESSAGE=Y
SHOW_FAILURE_DIALOG=Y
CREATE_DESKTOP_NOTICE=Y
WRITE_EVENTLOG=Y
```

- `SHOW_SUCCESS_MESSAGE=Y` displays a Windows message box after a successful operation.
- `SHOW_FAILURE_DIALOG=Y` displays the large red HTA failure dialog.
- `CREATE_DESKTOP_NOTICE=Y` creates `lazyBackup FAILED.txt` on the desktop after failure.
- `WRITE_EVENTLOG=Y` writes the result to the Windows Application log using the source `lazyBackup`.

### `KEYBOARD_LAYOUT`

Available presets:

```ini
# German, Germany
KEYBOARD_LAYOUT=0407:00000407

# English, United States
KEYBOARD_LAYOUT=0409:00000409

# English, United Kingdom
KEYBOARD_LAYOUT=0809:00000809

# French, France
KEYBOARD_LAYOUT=040C:0000040C

# Spanish, Spain
KEYBOARD_LAYOUT=0C0A:0000040A
```

Only one line should be active. If no layout is configured, the WinPE keyboard menu is displayed and German is selected automatically after its countdown.

## Automatic backup flow

```text
WinPE starts
        ↓
Configured keyboard is applied
        ↓
lazyBackup starts
        ↓
Backup is shown as the timed default
        ↓
R can still select Restore during the countdown
        ↓
Backup source and storage are detected through markers
        ↓
Backup summary is displayed
        ↓
N can still cancel during the final countdown
        ↓
Backup starts automatically
        ↓
Configured post-operation action is executed
```

The two countdowns serve different purposes:

- `OPERATION_MODE_TIMEOUT_SECONDS` selects Backup or Restore
- `BACKUP_CONFIRM_TIMEOUT_SECONDS` starts or cancels the actual Backup

## Network storage workflow

```text
Choose network storage
        ↓
Find a free drive letter from Z: backwards
        ↓
Enter UNC path
        ↓
Enter username
        ↓
Enter password through NET USE
        ↓
Map the share
        ↓
Detect .BACKUPSTORE in the share root
        ↓
Ask for WIM subdirectory
        ↓
Enter selects WIM
```

If the share does not contain `.BACKUPSTORE`, lazyBackup continues with storage selection.

## Backup image naming

```text
COMPUTERNAME_YYYYMMDD_HHMM.wim
```

Example:

```text
OFFICE-PC_20261001_2130.wim
```

With computer-specific subdirectories enabled:

```text
WIM\OFFICE-PC\OFFICE-PC_20261001_2130.wim
```

## Backup workflow

1. Boot into WinPE.
2. Apply or select the keyboard layout.
3. Start lazyBackup.
4. Select Backup manually or wait for the configured default.
5. Detect or enter the computer name.
6. Detect or select the source partition.
7. Optionally map network storage.
8. Detect or select storage.
9. Select the WIM subdirectory when it is not preset.
10. Select the post-operation action when it is not preset.
11. Review the summary.
12. Start immediately, cancel, or wait for automatic confirmation.
13. Capture the partition with DISM.
14. Run the configured post-operation action after its delay.

## Restore workflow

Restore is intentionally not made unattended by the Backup confirmation timeout.

1. Boot into WinPE.
2. Start lazyBackup.
3. Press `R` during the operation-mode countdown or select Restore manually.
4. Detect or select the restore target.
5. Detect or select storage.
6. Select a WIM or ESD image.
7. Review the restore summary.
8. Select the post-operation action when it is not preset.
9. Optionally format the target partition.
10. Confirm the restore explicitly.
11. Apply the image with DISM.

## Building the dedicated lazyBackup WinPE ISO

Start:

```text
ISO builder\build_lazyBackup_WinPE.bat
```

The builder:

1. checks administrator rights and requests UAC elevation when necessary
2. determines the project root relative to the builder location
3. verifies Windows ADK and the WinPE add-on
4. creates a temporary WinPE working directory below `%TEMP%\lazyBackup_Build\WinPE`
5. mounts `boot.wim`
6. copies `choice.exe`, `findstr.exe`, lazyBackup, README, license, and marker examples
7. installs `Builder files\startnet.cmd`
8. configures WinPE scratch space
9. commits and optimizes `boot.wim`
10. derives the WIM image name and ISO label from `SCRIPT_VERSION`
11. removes the BIOS boot prompt file
12. creates a BIOS and UEFI bootable ISO

Default output:

```text
ISO output\lazyBackup_WinPE.iso
```

Example metadata for lazyBackup v0.9.1:

```text
WIM image name: lazyBackup WinPE v0.9.1
ISO label:      LAZYBACKUP_WINPE_0_9_1
```

The ISO uses:

```text
Legacy BIOS: etfsboot.com
UEFI:        efisys_noprompt.bin
```

## Building the combined Windows 11 and lazyBackup ISO

Start:

```text
ISO builder\build_Windows11_with_lazyBackup_in_ISO-boot-menu.bat
```

Preparation:

1. Place exactly one Windows ISO in `Windows ISO here`.
2. Build or provide `ISO output\lazyBackup_WinPE.iso`.
3. Start the combined builder.

The builder:

- checks administrator rights and requests UAC elevation when required
- automatically selects the single Windows ISO in `Windows ISO here`
- uses `ISO output\lazyBackup_WinPE.iso` as the lazyBackup source
- uses `%TEMP%\lazyBackup_Build\Combined ISO` as the temporary working directory
- mounts both source ISOs and copies the Windows installation media
- adds lazyBackup `boot.wim` and `boot.sdi`
- creates and verifies BIOS and UEFI BCD entries
- keeps Windows Setup as the default boot entry
- adds `lazyBackup Recovery` as the second boot entry
- uses `efisys_noprompt.bin` when available
- creates and verifies the combined ISO

The Windows-source volume label and filename are used to generate the combined metadata. Generated labels and names end in `LAZY` or `lazy`.

The ISO label is shortened when necessary and always ends in:

```text
_LAZY
```

The final ISO label is limited to 32 characters for Oscdimg compatibility.

The output filename retains the Windows ISO source name and ends in:

```text
_lazy.iso
```

Example successful build:

```text
Windows source ISO:
Win11_25H2_German_x64_OOBE_NTLite14_unattended.iso

Combined ISO:
Win11_25H2_German_x64_OOBE_NTLite14_unattended_lazy.iso

ISO label:
W11_25H2_OOBE_14_NTL_unatt_LAZY

Boot menu entries:
W11 25H2 OOBE 14 NTL unatt lazy
lazyBackup Recovery
```

The combined ISO supports:

```text
Legacy BIOS
UEFI
```

## Updating lazyBackup in an existing combined ISO

If only the lazyBackup WinPE image has changed, the combined Windows 11 and lazyBackup ISO does not need to be rebuilt from the original Windows source ISO.

Start:

```text
ISO builder\update_lazyBackup_in_existing_Windows11_ISO.bat
```

The update builder uses:

- an existing combined Windows 11 and lazyBackup ISO
- the current `ISO output\lazyBackup_WinPE.iso`
- Windows ADK Deployment Tools with `Oscdimg.exe`

By default, the update builder expects exactly one existing combined ISO matching:

```text
ISO output\*_lazy.iso
```

It creates a new ISO beside the source using this default name:

```text
<existing-name>_updated.iso
```

The source ISO is never modified or overwritten.

### Files replaced by the update mode

The update builder copies these files from the new dedicated lazyBackup WinPE ISO:

```text
New lazyBackup ISO                       Existing combined ISO working copy
\sources\boot.wim                       -> \sources\lazyBackup.wim
\boot\boot.sdi                          -> \boot\lazyBackup.sdi
```

All Windows Setup files remain unchanged. The existing BIOS and UEFI BCD stores are also preserved because their lazyBackup entries already reference the fixed paths:

```text
\sources\lazyBackup.wim
\boot\lazyBackup.sdi
```

### Update process

The update builder:

1. requests administrator elevation when required
2. checks PowerShell, Robocopy, DISM, Bcdedit, and Oscdimg
3. locates the existing combined ISO and the new `lazyBackup_WinPE.iso`
4. mounts both source ISOs
5. copies the existing combined ISO into a temporary working directory
6. validates the new lazyBackup `boot.wim` with DISM
7. replaces `lazyBackup.wim` and `lazyBackup.sdi`
8. validates the copied `lazyBackup.wim` again
9. verifies that both BIOS and UEFI BCD stores reference the expected WIM and SDI paths
10. preserves the source ISO volume label
11. creates a new BIOS and UEFI bootable ISO
12. verifies that the output ISO exists and is not empty

The working directory defaults to:

```text
%TEMP%\lazyBackup_Build\Update Combined ISO
```

### Optional absolute update paths

The update builder supports these optional overrides:

```bat
set "CONFIG_COMBINED_ISO="
set "CONFIG_LAZYBACKUP_ISO="
set "CONFIG_OUTPUT_ISO="
set "CONFIG_WORKDIR="
```

Example:

```bat
set "CONFIG_COMBINED_ISO=E:\Programme\git\lazyBackup\ISO output\Windows11_lazy.iso"
set "CONFIG_LAZYBACKUP_ISO=E:\Programme\git\lazyBackup\ISO output\lazyBackup_WinPE.iso"
set "CONFIG_OUTPUT_ISO=E:\Programme\git\lazyBackup\ISO output\Windows11_lazy_updated.iso"
set "CONFIG_WORKDIR="
```

Configure `CONFIG_COMBINED_ISO` explicitly when more than one `*_lazy.iso` exists in `ISO output\` or when the source uses another filename.

### When to use the update mode

Use the update mode when changes are limited to the lazyBackup WinPE image, for example:

- updated `lazybackup.bat`
- updated `.lazybackup.conf`
- updated `startnet.cmd`
- added or updated WinPE drivers
- other files contained inside the lazyBackup `boot.wim`

Rebuild the complete combined ISO from the original Windows source ISO when changing:

- the Windows source ISO or Windows Setup files
- BIOS or UEFI BCD structure
- boot-menu descriptions or timeout
- the lazyBackup WIM or SDI paths
- ISO metadata that should be regenerated from a different Windows source

## Optional absolute builder overrides

Both builders use portable relative paths by default. Their configuration sections can still define absolute path overrides when required.

Typical override variables include:

```batch
set "CONFIG_SOURCE_ROOT="
set "CONFIG_WORKDIR="
set "CONFIG_OUTPUT_ISO="
```

The combined builder additionally supports:

```batch
set "CONFIG_WINDOWS11_ISO="
set "CONFIG_LAZYBACKUP_ISO="
```

The update builder additionally supports:

```bat
set "CONFIG_COMBINED_ISO="
set "CONFIG_LAZYBACKUP_ISO="
set "CONFIG_OUTPUT_ISO="
set "CONFIG_WORKDIR="
```

Leave these values empty to use the portable project structure.

## Windows Boot Manager integration

Start:

```text
install lazyBackup to Boot Menu BCD\lazyBackup_BootIntegration.bat
```

Run the script as Administrator under full Windows. Stable boot files are stored outside the synchronized portable-program directory:

```text
C:\ProgramData\lazyBackup_WinPE_Boot\
```

The repository source files for Windows result reporting must be located here:

```text
ResultNotification\
├── lazyBackup_Result.hta
└── lazyBackup_ResultNotifier.ps1
```

The Boot Manager integration copies them to:

```text
C:\ProgramData\lazyBackup_WinPE_Boot\ResultNotification\
├── lazyBackup_Result.hta
└── lazyBackup_ResultNotifier.ps1
```

It registers `lazyBackup_ResultNotifier.ps1` for user logon and creates the `lazyBackup` Event Log source when possible. The integration can install, repair, update, display status, boot once into lazyBackup Recovery, or remove the integration. Windows remains the normal default boot entry.

### Persistent result files

During Backup or Restore, lazyBackup writes the result to the selected offline Windows partition. Under normal Windows the files are available as:

```text
C:\ProgramData\lazyBackup\LastOperation.ini
C:\ProgramData\lazyBackup\LastOperation.dism.log
```

After logon:

- success displays a message box and removes the successful status file
- failure displays the high-visibility HTA dialog
- failure can also create `lazyBackup FAILED.txt` on the desktop
- the HTA can open the local log copy and the image folder
- a displayed failure is marked with `DISPLAYED=1` so it is not repeatedly shown at every later logon

## Recommended tests before deployment

Verify in a virtual machine:

- dedicated WinPE ISO in Legacy BIOS mode
- dedicated WinPE ISO in UEFI mode
- combined ISO in Legacy BIOS mode
- combined ISO in UEFI mode
- updated combined ISO in Legacy BIOS mode
- updated combined ISO in UEFI mode
- Windows Setup entry after update
- lazyBackup Recovery entry after update
- updated lazyBackup drivers and files inside the combined ISO
- confirmation that the original combined ISO remains unchanged
- Windows Setup boot entry
- lazyBackup Recovery boot entry
- keyboard preset and keyboard menu
- WinPE startup menu
- operation-mode countdown
- Restore override with `R`
- source marker detection
- storage marker detection
- network drive-letter selection
- `.BACKUPSTORE` detection on a network share
- WIM-subdirectory default
- automatic Backup confirmation
- cancellation with `N`
- post-operation action and delay
- Backup success notification after Windows logon
- Backup failure HTA after Windows logon
- HTA readability on a 4K display
- desktop failure notice
- Windows Application log entry
- local DISM log opening from the HTA
- additional WIM validation
- failed Backup with `BACKUP_FAILURE_ACTION=R`
- failed Restore with `RESTORE_FAILURE_ACTION=N`

## Troubleshooting

### Network share maps but is not selected

Create an empty marker in the share root:

```batch
type nul > "Z:\.BACKUPSTORE"
```

### WIM subdirectory prompt does not appear

A configured value skips the prompt:

```ini
WIM_SUBDIR=WIM
```

Use an empty value to show it:

```ini
WIM_SUBDIR=
```

### Backup does not start unattended

Verify at minimum:

```ini
WIM_SUBDIR=WIM
OPERATION_MODE=B
OPERATION_MODE_TIMEOUT_SECONDS=15
BACKUP_CONFIRM_TIMEOUT_SECONDS=15
POST_OPERATION_ACTION=R
MAP_NETWORK=N
KEYBOARD_LAYOUT=0407:00000407
```

Also verify that `.pcname`, `.DRIVETOBACKUP`, and the appropriate storage marker are available.

### Restore starts automatically

For an unattended Backup configuration, verify:

```ini
OPERATION_MODE=B
```

`BACKUP_CONFIRM_TIMEOUT_SECONDS` affects Backup only and does not confirm Restore.

### Network letter is already occupied

Use:

```ini
DRIVE_LETTER=
```

lazyBackup then searches backwards from `Z:` and skips occupied letters and `X:`.

### Keyboard menu appears unexpectedly

Set one layout explicitly:

```ini
KEYBOARD_LAYOUT=0407:00000407
```

### Update builder finds no combined ISO

By default, exactly one file matching `*_lazy.iso` must exist in `ISO output\`. If no matching file is present, set `CONFIG_COMBINED_ISO` to the complete source ISO path.

### Update builder finds more than one combined ISO

Set `CONFIG_COMBINED_ISO` explicitly or temporarily keep only the intended source `*_lazy.iso` in `ISO output\`. The updater does not guess which ISO should be modified.

### Update builder reports invalid BCD references

The existing combined ISO must contain BIOS and UEFI BCD entries referencing:

```text
\sources\lazyBackup.wim
\boot\lazyBackup.sdi
```

If either reference is missing, rebuild the combined ISO with the full combined builder instead of using update mode.

### Updated ISO does not contain the expected lazyBackup changes

First rebuild `ISO output\lazyBackup_WinPE.iso` with the dedicated WinPE builder. The update mode copies `boot.wim` and `boot.sdi` from that ISO and does not rebuild the WinPE image itself.

### Combined builder finds no Windows ISO

Place exactly one `*.iso` file in:

```text
Windows ISO here
```

Alternatively, configure `CONFIG_WINDOWS11_ISO` with an absolute path.

### Combined builder finds more than one Windows ISO

Keep exactly one Windows ISO in `Windows ISO here`, or configure `CONFIG_WINDOWS11_ISO` explicitly.

### Oscdimg reports that the volume label is too long

The current builder shortens the generated label immediately before calling Oscdimg. The final label keeps `_LAZY` and is limited to 32 characters.

### No result notification appears after Windows logon

Verify that both notification files exist below:

```text
C:\ProgramData\lazyBackup_WinPE_Boot\ResultNotification\
```

Verify the `lazyBackupResultNotifier` value below:

```text
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
```

Also check whether this result file exists:

```text
C:\ProgramData\lazyBackup\LastOperation.ini
```

### Failure dialog appears only once

This is intentional. After displaying a failure, the notifier writes `DISPLAYED=1` to `LastOperation.ini`. The status and local log copy remain available, but the dialog is not shown repeatedly at every logon.

### Failure dialog is too small on a high-resolution display

The supplied HTA uses enlarged text and a larger window for high-resolution displays. Replace the files in `ResultNotification\` and run **Install or repair integration** again so the updated files are copied to the stable local directory.

## License

lazyBackup is licensed under the GNU General Public License v3.0. See `LICENSE` for details.
