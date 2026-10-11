@echo off
setlocal EnableExtensions DisableDelayedExpansion
REM ==================================================
REM lazyBackup
REM GPL-3.0 License
REM https://github.com/Textator/lazyBackup
REM ==================================================

REM script version
set "SCRIPT_VERSION=0.9.0"

title lazyBackup v%SCRIPT_VERSION%
cls

REM **************************************************
REM Configuration BEGIN - modify from here
REM **************************************************

REM Store backups in WIM_SUBDIR\COMPUTER_NAME\
REM Y = use COMPUTER_NAME subfolder
REM N = store all WIMs directly in WIM_SUBDIR\
set "USE_COMPUTER_NAME_SUBFOLDER=Y"

REM Backup directory below BACKUPSTORE/USBBACKUPSTORE
REM Empty = ask user
REM Examples:
REM set "WIM_SUBDIR=WIM"
REM set "WIM_SUBDIR=Images"
REM set "WIM_SUBDIR=Backups\Windows"
set "WIM_SUBDIR="

REM Fixed backup storage location
REM Empty = automatic detection or user selection
REM Local example: E
REM Network example: \\server\share
set "STORAGE_PATH="

REM configure operation mode
REM valid preset:
REM
REM B = Backup
REM R = Restore
REM
REM Example:
REM set "OPERATION_MODE=B"
set "OPERATION_MODE="

REM Delay before a configured operation starts automatically.
REM
REM This timeout is used only when OPERATION_MODE contains
REM a valid preset:
REM
REM B = Backup
REM R = Restore
REM
REM During the countdown, another mode can still be selected.
REM
REM Empty or 0 = no automatic operation start.
REM
REM Examples:
REM   10 = wait 10 seconds
REM   15 = wait 15 seconds
REM   30 = wait 30 seconds

set "OPERATION_MODE_TIMEOUT_SECONDS=15"


REM Delay before the backup starts automatically
REM from the backup summary.
REM
REM This provides a final opportunity to cancel the
REM scheduled backup after all paths have been shown.
REM
REM Empty or 0 = wait indefinitely for Y or N.
REM
REM Examples:
REM   5  = start after 5 seconds
REM   10 = start after 10 seconds
REM   15 = start after 15 seconds
REM   30 = start after 30 seconds

set "BACKUP_CONFIRM_TIMEOUT_SECONDS=15"


REM set "POST_OPERATION_ACTION=n"
REM R = Reboot
REM N = No action
REM S = Shutdown
set "POST_OPERATION_ACTION="

REM Delay before reboot, shutdown or final exit.
REM Value is specified in seconds.
REM Examples:
REM   0   = execute immediately
REM   10  = wait 10 seconds
REM   120 = wait 2 minutes
set "POST_OPERATION_DELAY_SECONDS=120"

REM set "MAP_NETWORK=N"
REM N = skip all network prompts
REM any other value (including empty) enables network configuration
REM using network will given as optional storage choice
set "MAP_NETWORK="

REM Network drive letter.
REM
REM Empty = automatically select a free drive letter,
REM         searching backwards from Z:
REM
REM X: is always skipped because X: is the WinPE
REM RAM drive.
REM
REM Optional fixed examples:
REM set "DRIVE_LETTER=Z:"
REM set "DRIVE_LETTER=Y:"
set "DRIVE_LETTER="

set "NETWORK_PATH="
set "NETWORK_USERNAME="
set "PASSWORD="

REM DISM scratch directory
REM Empty = automatic selection
set "DISM_SCRATCH="

REM **************************************************
REM Configuration END - don't modify below
REM **************************************************

REM ==================================================
REM Load external configuration
REM ==================================================

set "SCRIPT_DIR_CONFIG=%~dp0.lazybackup.conf"
set "ROOT_CONFIG="
set "USB_CONFIG="
set "EFFECTIVE_CONFIG=Built-in defaults"

REM --------------------------------------------------
REM Priority 4:
REM Built-in defaults from lazyBackup.bat
REM --------------------------------------------------

REM The settings from the configuration section above
REM are already active.

REM --------------------------------------------------
REM Priority 3:
REM Configuration beside lazyBackup.bat
REM --------------------------------------------------

if exist "%SCRIPT_DIR_CONFIG%" (
    echo.
    echo Loading script-directory configuration:
    echo   %SCRIPT_DIR_CONFIG%

    call :LOAD_CONFIG_FILE "%SCRIPT_DIR_CONFIG%"

    set "EFFECTIVE_CONFIG=%SCRIPT_DIR_CONFIG%"
)

REM --------------------------------------------------
REM Priority 2:
REM First configuration found in a drive root
REM --------------------------------------------------

for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined ROOT_CONFIG (
        if exist "%%D:\.lazybackup.conf" (
            set "ROOT_CONFIG=%%D:\.lazybackup.conf"
        )
    )
)

if defined ROOT_CONFIG (
    echo.
    echo Loading drive-root configuration:
    echo   %ROOT_CONFIG%

    call :LOAD_CONFIG_FILE "%ROOT_CONFIG%"

    set "EFFECTIVE_CONFIG=%ROOT_CONFIG%"
)

REM --------------------------------------------------
REM Priority 1:
REM Configuration on preferred USB backup storage
REM --------------------------------------------------

for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined USB_CONFIG (
        if exist "%%D:\.USBBACKUPSTORE" (
            if exist "%%D:\.lazybackup.conf" (
                set "USB_CONFIG=%%D:\.lazybackup.conf"
            )
        )
    )
)

if defined USB_CONFIG (
    echo.
    echo Loading preferred USB storage configuration:
    echo   %USB_CONFIG%

    call :LOAD_CONFIG_FILE "%USB_CONFIG%"

    set "EFFECTIVE_CONFIG=%USB_CONFIG%"
)

REM --------------------------------------------------
REM External configuration has been loaded
REM --------------------------------------------------

setlocal EnableDelayedExpansion

echo.
echo ==========================================
echo       Effective Configuration
echo ==========================================
echo.
echo Highest priority configuration:
echo   !EFFECTIVE_CONFIG!
echo.
echo WIM subdirectory            : !WIM_SUBDIR!
echo Storage path                : !STORAGE_PATH!
echo Operation mode              : !OPERATION_MODE!
echo Operation timeout           : !OPERATION_MODE_TIMEOUT_SECONDS! seconds
echo Backup confirmation timeout : !BACKUP_CONFIRM_TIMEOUT_SECONDS! seconds
echo Post action                 : !POST_OPERATION_ACTION!
echo Post delay                  : !POST_OPERATION_DELAY_SECONDS! seconds
echo Network mapping             : !MAP_NETWORK!
echo Scratch preset              : !DISM_SCRATCH!
echo.

REM ==================================================
REM Administrator Rights Check
REM ==================================================

net session >nul 2>&1

if errorlevel 1 (
    echo.
    echo ==========================================
    echo                   ERROR
    echo ==========================================
    echo.
    echo Administrator privileges are required.
    echo.
    echo Please run lazyBackup from an elevated
    echo command prompt or from WinPE.
    echo.
    pause
    goto EXITONLY
)

REM runtime variables
set "COMPUTER_NAME="
set "WINDOWS_PARTITION="
set "DETECTED_STORAGE_PATH="
set "ACTIVE_STORAGE_PATH="
set "DISM_SCRATCH_PATH="
set "SCRATCH_CREATED="
set "STORAGE_IS_NETWORK="
set "BACKUP_ROOT="
set "BACKUP_IMAGE_DIR="
set "BACKUP_IMAGE_FILE="
set "RESTORE_IMAGE_FILE="
set "RESTORE_PARTITION="
set "IMAGE_COUNT="
set "FORMAT_PARTITION="
set "RESTORE_IMAGE_INDEX=1"

REM ==================================================
REM Console Colours
REM ==================================================

for /F %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"

set "RESET=%ESC%[0m"
set "BOLD=%ESC%[1m"

set "MAGENTA=%ESC%[95m"
set "CYAN=%ESC%[96m"
set "YELLOW=%ESC%[93m"
set "GREEN=%ESC%[92m"
set "RED=%ESC%[91m"
set "BLUE=%ESC%[94m"

REM ==================================================
REM Date Configuration
REM ==================================================

REM possible to DE / EN / ISO
set "DATE_LOCALE=DE"
REM DE = DD.MM.YYYY
REM EN = MM/DD/YYYY
REM ISO = YYYY-MM-DD
REM WinPE default: DE

if /I "%DATE_LOCALE%"=="DE" (
    set YYYY=%date:~-4%
    set MM=%date:~-7,2%
    set DD=%date:~-10,2%
)

if /I "%DATE_LOCALE%"=="EN" (
    set MM=%date:~0,2%
    set DD=%date:~3,2%
    set YYYY=%date:~6,4%
)

if /I "%DATE_LOCALE%"=="ISO" (
    set YYYY=%date:~0,4%
    set MM=%date:~5,2%
    set DD=%date:~8,2%
)

set HOUR=%time:~0,2%
if "%HOUR:~0,1%"==" " set HOUR=0%HOUR:~1,1%
set MINUTE=%time:~3,2%

set "TIMESTAMP=%YYYY%%MM%%DD%_%HOUR%%MINUTE%"
REM ----------------------------------------------------
REM end Date Configuration
REM ----------------------------------------------------

:INITIALIZE
echo.
echo ==================================================
echo   * %BOLD%%MAGENTA%lazyBackup%RESET% v%SCRIPT_VERSION%
echo   Fast Windows Image Backup using DISM
echo ==================================================
echo. Project: https://github.com/Textator/lazyBackup
echo --------------------------------------------------
echo.

::check if HELP triggered	
if /I "%~1"=="help" goto SHOWHELP
if "%~1"=="/?" goto SHOWHELP
if /I "%~1"=="-h" goto SHOWHELP
goto MAINMENU

:MAINMENU

cls
echo.
echo ==========================================
echo              Main Menu
echo ==========================================
echo.
echo [B] Backup Windows Partition
echo [R] Restore Windows Partition
echo [E] Exit
echo.

REM --------------------------------------------------
REM Validate the configured default operation.
REM --------------------------------------------------

set "DEFAULT_OPERATION="

if /I "%OPERATION_MODE%"=="B" (
    set "DEFAULT_OPERATION=B"
)

if /I "%OPERATION_MODE%"=="BACKUP" (
    set "DEFAULT_OPERATION=B"
)

if /I "%OPERATION_MODE%"=="R" (
    set "DEFAULT_OPERATION=R"
)

if /I "%OPERATION_MODE%"=="RESTORE" (
    set "DEFAULT_OPERATION=R"
)

REM --------------------------------------------------
REM Validate the timeout.
REM --------------------------------------------------

set "OPERATION_TIMEOUT_INVALID="

if defined OPERATION_MODE_TIMEOUT_SECONDS (
    for /F "delims=0123456789" %%A in ("%OPERATION_MODE_TIMEOUT_SECONDS%") do (
        set "OPERATION_TIMEOUT_INVALID=%%A"
    )
)

if defined OPERATION_TIMEOUT_INVALID (
    echo %YELLOW%WARNING%RESET% Invalid operation timeout:
    echo   %OPERATION_MODE_TIMEOUT_SECONDS%
    echo.
    echo Automatic operation start is disabled.
    echo.

    set "OPERATION_MODE_TIMEOUT_SECONDS="
)

REM --------------------------------------------------
REM Timed menu when a valid default is configured.
REM --------------------------------------------------

if defined DEFAULT_OPERATION (
    if defined OPERATION_MODE_TIMEOUT_SECONDS (
        if not "%OPERATION_MODE_TIMEOUT_SECONDS%"=="0" (
            echo Configured default:
            echo   %DEFAULT_OPERATION%
            echo.
            echo The configured operation will start
            echo automatically in %OPERATION_MODE_TIMEOUT_SECONDS% seconds.
            echo.
            echo Select another option to override it.
            echo.

            choice /C BRE /N /T %OPERATION_MODE_TIMEOUT_SECONDS% /D %DEFAULT_OPERATION% /M "Selection [B/R/E]: "

            if errorlevel 3 goto EXITONLY
            if errorlevel 2 goto SELECT_RESTORE_MODE
            if errorlevel 1 goto SELECT_BACKUP_MODE

            goto MAINMENU
        )
    )
)

REM --------------------------------------------------
REM Untimed menu when no automatic start is configured.
REM --------------------------------------------------

choice /C BRE /N /M "Selection [B/R/E]: "

if errorlevel 3 goto EXITONLY
if errorlevel 2 goto SELECT_RESTORE_MODE
if errorlevel 1 goto SELECT_BACKUP_MODE

goto MAINMENU


:SELECT_BACKUP_MODE

set "OPERATION_MODE=B"
goto DETECT_BACKUP_SOURCE_INIT


:SELECT_RESTORE_MODE

set "OPERATION_MODE=R"
goto DETECT_RESTORE_SOURCE_INIT

:DETECT_BACKUP_SOURCE_INIT
set "OPERATION_MODE=BACKUP"
set "DETECTED_STORAGE_PATH="
set "ACTIVE_STORAGE_PATH="
set "SCRATCH_CREATED="
wpeinit >nul 2>&1

::Computer Name Detection
echo Searching for file %CYAN%.pcname%RESET%...
echo.

for %%g in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined COMPUTER_NAME (
    if exist %%g:\.pcname (
        echo Found: %CYAN%%%g:\.pcname%RESET%
        set /p COMPUTER_NAME=<%%g:\.pcname
        echo Using computer name: %CYAN%!COMPUTER_NAME!%RESET%
    )
   )
)

if not defined COMPUTER_NAME (
    echo.
    echo No valid %CYAN%.pcname%RESET% file found.
    set /P COMPUTER_NAME=Enter computer name [computer name]:
)

::Backup Source Detection
:DETECT_BACKUP_SOURCE
set "WINDOWS_PARTITION="

for %%i in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined WINDOWS_PARTITION (
    if exist %%i:\.DRIVETOBACKUP (
        set "WINDOWS_PARTITION=%%i"
        echo.
        echo Found: %CYAN%%%i:\.DRIVETOBACKUP%RESET%
        echo Backup source drive: %CYAN%%%i:%RESET%
    )
   )
)

if not defined WINDOWS_PARTITION (
    goto SELECT_BACKUP_DRIVE
)

goto PROMPT_NETWORK

:SELECT_BACKUP_DRIVE

echo.
echo ==========================================
echo      Select Backup Source Drive
echo ==========================================
echo.

set "DRIVECOUNT=0"

for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist %%D:\ (
        set /a DRIVECOUNT+=1
        set "DRIVE!DRIVECOUNT!=%%D"
        echo [!DRIVECOUNT!^] %%D:
        vol %%D: 2>nul
        echo.
    )
)

echo [M] Manual Drive Letter Entry
echo.

set "SEL="
set /P SEL=Selection:

if /I "!SEL!"=="M" (
    set "WINDOWS_PARTITION="
    set /P "WINDOWS_PARTITION=Drive letter to back up: "

    if "!WINDOWS_PARTITION:~1,1!"==":" (
        set "WINDOWS_PARTITION=!WINDOWS_PARTITION:~0,1!"
    )

    if not exist "!WINDOWS_PARTITION!:\" (
        echo.
        echo %RED%Invalid or unavailable drive.%RESET%
        choice /C X /N /T 2 /D X >nul
        goto SELECT_BACKUP_DRIVE
    )

    goto PROMPT_NETWORK
)

set "WINDOWS_PARTITION=!DRIVE%SEL%!"

if not defined WINDOWS_PARTITION (
    echo.
    echo Invalid selection.
    goto SELECT_BACKUP_DRIVE
)

echo.
echo Selected backup source:
echo %CYAN%!WINDOWS_PARTITION!:%RESET%

goto PROMPT_NETWORK

::Network Initialization
REM Initialize networking in WinPE


:PROMPT_NETWORK
REM Network Mapping Menu
if /I "%MAP_NETWORK%"=="N" goto DETECT_WIM_STORAGE

echo.
echo ==========================================
echo      Network Storage Configuration
echo ==========================================
echo.

set /p "NETWORK_CHOICE=Map network storage for Image files? [Y/N]: "

if /I "%NETWORK_CHOICE%"=="Y" goto MAP_NETWORK_DRIVE
if /I "%NETWORK_CHOICE%"=="J" goto MAP_NETWORK_DRIVE
if /I "%NETWORK_CHOICE%"=="N" goto DETECT_WIM_STORAGE

echo.
echo %RED%Invalid selection.%RESET%
echo Please enter Y or N.

choice /C X /N /T 2 /D X >nul
goto PROMPT_NETWORK


:MAP_NETWORK_DRIVE

REM --------------------------------------------------
REM Select the network drive letter
REM --------------------------------------------------

if not defined DRIVE_LETTER (
    call :FIND_FREE_NETWORK_DRIVE_LETTER

    if errorlevel 1 (
        echo.
        echo %RED%ERROR%RESET% No free network drive letter was found.
        echo.
        echo Checked drive letters:
        echo   Z: through D:
        echo.
        echo X: was skipped because it is the WinPE RAM drive.
        echo.
        pause
        goto PROMPT_NETWORK
    )
) else (
    REM Normalize a configured value such as Z to Z:.
    if not "!DRIVE_LETTER:~-1!"==":" (
        set "DRIVE_LETTER=!DRIVE_LETTER!:"
    )

    echo.
    echo Using configured network drive letter:
    echo   !DRIVE_LETTER!
    echo.
)


if not defined NETWORK_PATH (
    echo.
    set /P NETWORK_PATH=Enter network path (e.g. \\server\share^) :
)

if not defined NETWORK_USERNAME (
    echo.
    set /P NETWORK_USERNAME=Enter network username [DOMAIN\USER or USER]:
)

echo.
echo Mapping %DRIVE_LETTER% to %NETWORK_PATH% for user %NETWORK_USERNAME%...
echo.

if defined PASSWORD (
net use "%DRIVE_LETTER%" "%NETWORK_PATH%" /persistent:no /user:%NETWORK_USERNAME% "%PASSWORD%"
) else (
net use "%DRIVE_LETTER%" "%NETWORK_PATH%" /persistent:no /user:%NETWORK_USERNAME% *
)

if errorlevel 1 (
    echo.
    echo %RED%ERROR%RESET% Failed to map network drive.
    echo Verify network connectivity and credentials.
) else (
    echo.
    echo %GREEN%SUCCESS%RESET% Network drive mapped successfully.
    echo Drive : %DRIVE_LETTER%
    echo Target: %NETWORK_PATH%
)

echo.

::WIM Storage Detection
:DETECT_WIM_STORAGE
::.USBBACKUPSTORE has priority over .BACKUPSTORE so local imagedir is not used if USB-storage is present
if not defined STORAGE_PATH (
for %%k in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined STORAGE_PATH if not defined DETECTED_STORAGE_PATH (
      if exist %%k:\.USBBACKUPSTORE (
        set "DETECTED_STORAGE_PATH=%%k"
        echo.
        echo Found USB backup storage via marker file .USBBACKUPSTORE:
        echo %CYAN%!DETECTED_STORAGE_PATH!:\.USBBACKUPSTORE%RESET%
        echo Storage root:
        echo %CYAN%!DETECTED_STORAGE_PATH!:\%RESET%
     )
    )
)
)

if not defined STORAGE_PATH (
for %%n in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
     if not defined STORAGE_PATH if not defined DETECTED_STORAGE_PATH (
    if exist %%n:\.BACKUPSTORE (
        set "DETECTED_STORAGE_PATH=%%n"
        echo.
        echo Found backup storage via marker file .BACKUPSTORE:
        echo %CYAN%!DETECTED_STORAGE_PATH!:\.BACKUPSTORE%RESET%
        echo Storage root:
        echo %CYAN%!DETECTED_STORAGE_PATH!:\%RESET%
    )
   )
 )
)

if not defined STORAGE_PATH if not defined DETECTED_STORAGE_PATH goto ASK_STORAGE
goto ASK_WIM_SUBDIR

:ASK_STORAGE

echo.
echo ==========================================
echo       Select Backup Storage Drive
echo ==========================================
echo.
echo No backup storage marker file was found.
echo.

set "DRIVECOUNT=0"
set "SEL="

for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (

    if exist %%D:\ (

        REM X: (WinPE RAM Drive) ausblenden

        if /I not "%%D"=="X" (

            REM ISO-/DVD-Medien ausblenden

            set "SKIP_DRIVE="

            if exist "%%D:\bootmgr" (
                if exist "%%D:\bootmgr.efi" (
                    if exist "%%D:\sources\boot.wim" (
                        set "SKIP_DRIVE=Y"
                    )
                )
            )

            if not defined SKIP_DRIVE (

                REM Beschreibbarkeit testen

                echo test>"%%D:\lazybackup_write_test.tmp" 2>nul

                if not errorlevel 1 (

                    del /q "%%D:\lazybackup_write_test.tmp" >nul 2>&1

                    set /a DRIVECOUNT+=1
                    set "DRIVE!DRIVECOUNT!=%%D"

                    echo [!DRIVECOUNT!^] %%D:
                    vol %%D: 2>nul
                    echo.
                )
            )
        )
    )
)

echo [M] Enter path manually
echo.
set /P "SEL=Selection: "

if /I "!SEL!"=="M" goto ASK_STORAGE_PATH

set "DETECTED_STORAGE_PATH=!DRIVE%SEL%!"

if not defined DETECTED_STORAGE_PATH (
    echo.
    echo %RED%Invalid selection.%RESET%
    choice /C X /N /T 2 /D X >nul
    goto ASK_STORAGE
)

echo.
echo Selected backup storage:
echo %CYAN%!DETECTED_STORAGE_PATH!:%RESET%
echo.

goto ASK_WIM_SUBDIR


:ASK_STORAGE_PATH

echo.
echo Enter either:
echo.
echo   - A local drive, for example E, E: or E:\
echo   - A UNC path, for example \\server\share
echo.

set "DETECTED_STORAGE_PATH="
set /P "DETECTED_STORAGE_PATH=Backup storage path: "

if not defined DETECTED_STORAGE_PATH (
    echo.
    echo %RED%No storage path was entered.%RESET%
    choice /C X /N /T 2 /D X >nul
    goto ASK_STORAGE
)

REM Normalize a local drive entry:
REM E, E: and E:\ all become E
if not "!DETECTED_STORAGE_PATH:~0,2!"=="\\" (
    if "!DETECTED_STORAGE_PATH:~1,1!"==":" (
        set "DETECTED_STORAGE_PATH=!DETECTED_STORAGE_PATH:~0,1!"
    )
)

goto ASK_WIM_SUBDIR


:ASK_WIM_SUBDIR

if defined WIM_SUBDIR goto BUILD_STORAGE_PATHS

echo.
echo ==========================================
echo       Select Backup Subdirectory
echo ==========================================
echo.
echo Storage root:
echo   !DETECTED_STORAGE_PATH!
echo.
echo Enter the subdirectory below the selected
echo storage root.
echo.
echo Examples:
echo   WIM
echo   Images
echo   Backups\Windows
echo.
echo Press ENTER to use:
echo   WIM
echo.

set "WIM_SUBDIR="
set /P "WIM_SUBDIR=Backup subfolder [ENTER = WIM\]: "

if not defined WIM_SUBDIR (
    set "WIM_SUBDIR=WIM"
)

REM Remove a leading backslash.
if "!WIM_SUBDIR:~0,1!"=="\" (
    set "WIM_SUBDIR=!WIM_SUBDIR:~1!"
)

REM Remove a trailing backslash.
if "!WIM_SUBDIR:~-1!"=="\" (
    set "WIM_SUBDIR=!WIM_SUBDIR:~0,-1!"
)

if not defined WIM_SUBDIR (
    set "WIM_SUBDIR=WIM"
)

echo.
echo Selected backup subdirectory:
echo   !WIM_SUBDIR!
echo.

goto BUILD_STORAGE_PATHS


:BUILD_STORAGE_PATHS

if not defined WIM_SUBDIR set "WIM_SUBDIR=WIM"

if defined STORAGE_PATH (
    set "ACTIVE_STORAGE_PATH=%STORAGE_PATH%"
    echo.
    echo Using configured storage location:
    echo %CYAN%!ACTIVE_STORAGE_PATH!%RESET%
    echo.
) else (
    set "ACTIVE_STORAGE_PATH=%DETECTED_STORAGE_PATH%"
)

REM ==================================================
REM Determine DISM Scratch Directory
REM ==================================================

if defined DISM_SCRATCH (
    set "DISM_SCRATCH_PATH=%DISM_SCRATCH%"
    goto SCRATCH_READY
)
REM preset to "N"
set "STORAGE_IS_NETWORK=N"

REM UNC path?
if "!ACTIVE_STORAGE_PATH:~0,2!"=="\\" (
    set "STORAGE_IS_NETWORK=Y"
)

REM mapped network drive?
if /I "!STORAGE_IS_NETWORK!"=="N" (
    net use | find /I "!ACTIVE_STORAGE_PATH!:" >nul

    if not errorlevel 1 (
        set "STORAGE_IS_NETWORK=Y"
    )
)

REM --------------------------------------------------
REM Local storage -> use storage volume
REM --------------------------------------------------

if /I "!STORAGE_IS_NETWORK!"=="N" (

    set "DISM_SCRATCH_PATH=!ACTIVE_STORAGE_PATH!:\lazyBackupTemp"

) else (

REM --------------------------------------------------
REM Network storage -> find local drive
REM --------------------------------------------------

if /I "%OPERATION_MODE%"=="BACKUP" (
    set "EXCLUDE_DRIVE=!WINDOWS_PARTITION!"
) else (
    set "EXCLUDE_DRIVE=!RESTORE_PARTITION!"
)

for %%D in (
    C D E F G H I J K L M N O P Q R S T U V W Y Z
) do (

    if exist %%D:\ (

        if /I not "%%D"=="X" (

            if /I not "%%D"=="!EXCLUDE_DRIVE!" (

                if not defined DISM_SCRATCH_PATH (
                    set "DISM_SCRATCH_PATH=%%D:\lazyBackupTemp"
                )

            )

        )

    )

)
)


REM last fallback
if not defined DISM_SCRATCH_PATH (
    set "DISM_SCRATCH_PATH=X:\Temp"
)

:SCRATCH_READY

if not exist "!DISM_SCRATCH_PATH!" (
    mkdir "!DISM_SCRATCH_PATH!" 2>nul

    if exist "!DISM_SCRATCH_PATH!" (
        set "SCRATCH_CREATED=Y"
    )
)

REM support UNC-path in path
if "!ACTIVE_STORAGE_PATH:~0,2!"=="\\" (
    set "BACKUP_ROOT=!ACTIVE_STORAGE_PATH!\%WIM_SUBDIR%"
) else (
    set "BACKUP_ROOT=!ACTIVE_STORAGE_PATH!:\%WIM_SUBDIR%"
)

REM Build image filename
if /I "%USE_COMPUTER_NAME_SUBFOLDER%"=="Y" (
    set "BACKUP_IMAGE_DIR=!BACKUP_ROOT!\%COMPUTER_NAME%"
    set "BACKUP_IMAGE_FILE=!BACKUP_IMAGE_DIR!\%COMPUTER_NAME%_%TIMESTAMP%.wim"
) else (
    set "BACKUP_IMAGE_DIR=!BACKUP_ROOT!"
    set "BACKUP_IMAGE_FILE=!BACKUP_ROOT!\%COMPUTER_NAME%_%TIMESTAMP%.wim"
)

if /I "%OPERATION_MODE%"=="RESTORE" goto RESTORE_SELECT_IMAGE
if /I "%OPERATION_MODE%"=="BACKUP" goto CONFIGURE_POST_OPERATION_ACTION

:CONFIGURE_POST_OPERATION_ACTION

if not defined POST_OPERATION_ACTION (
    echo.
    echo ==========================================
    echo     Select action after completion:
    echo ==========================================
    echo.
    echo [R] Reboot
    echo [S] Shutdown
    echo [N] Nothing
    echo.
    set /P POST_OPERATION_ACTION=Selection [R/S/N]:
)

if /I "%POST_OPERATION_ACTION%"=="R" goto BACKUP_SUMMARY
if /I "%POST_OPERATION_ACTION%"=="S" goto BACKUP_SUMMARY
if /I "%POST_OPERATION_ACTION%"=="N" goto BACKUP_SUMMARY

echo.
echo %RED%Invalid selection.%RESET%
echo Please enter R, S or N.
set "POST_OPERATION_ACTION="
goto CONFIGURE_POST_OPERATION_ACTION

:BACKUP_SUMMARY
echo.
echo ==========================================
echo               Backup Summary
echo ==========================================
echo.
echo Computer Name : %CYAN%%COMPUTER_NAME%%RESET%
echo Source Drive  : %CYAN%%WINDOWS_PARTITION%:%RESET%
echo Storage       : %CYAN%!ACTIVE_STORAGE_PATH!%RESET%
echo Scratch Dir   : !DISM_SCRATCH_PATH!
echo Image file    : %CYAN%%BACKUP_IMAGE_FILE%%RESET%
echo.

REM --------------------------------------------------
REM Validate the automatic backup confirmation timeout.
REM --------------------------------------------------

set "BACKUP_CONFIRM_TIMEOUT_INVALID="

if defined BACKUP_CONFIRM_TIMEOUT_SECONDS (
    for /F "delims=0123456789" %%A in ("%BACKUP_CONFIRM_TIMEOUT_SECONDS%") do (
        set "BACKUP_CONFIRM_TIMEOUT_INVALID=%%A"
    )
)

if defined BACKUP_CONFIRM_TIMEOUT_INVALID (
    echo.
    echo %YELLOW%WARNING%RESET% Invalid backup confirmation timeout:
    echo   %BACKUP_CONFIRM_TIMEOUT_SECONDS%
    echo.
    echo Automatic backup confirmation is disabled.
    echo.

    set "BACKUP_CONFIRM_TIMEOUT_SECONDS="
)

REM --------------------------------------------------
REM Timed confirmation.
REM
REM Y starts the backup immediately.
REM N cancels the backup.
REM No input starts the backup after the countdown.
REM --------------------------------------------------

if defined BACKUP_CONFIRM_TIMEOUT_SECONDS (
    if not "%BACKUP_CONFIRM_TIMEOUT_SECONDS%"=="0" (
        echo.
        echo The backup will start automatically in
        echo %BACKUP_CONFIRM_TIMEOUT_SECONDS% seconds.
        echo.
        echo Press Y to start immediately.
        echo Press N to cancel.
        echo.

        choice /C YN /N /T %BACKUP_CONFIRM_TIMEOUT_SECONDS% /D Y /M "Start backup? [Y/N\]: "

        if errorlevel 2 goto CANCEL_BACKUP
        if errorlevel 1 goto EXECUTE_BACKUP

        goto BACKUP_SUMMARY
    )
)

REM --------------------------------------------------
REM Untimed confirmation when the timeout is empty or 0.
REM --------------------------------------------------

echo.
choice /C YN /N /M "Start backup? [Y/N\]: "

if errorlevel 2 goto CANCEL_BACKUP
if errorlevel 1 goto EXECUTE_BACKUP

goto BACKUP_SUMMARY

::Cancel Backup
:CANCEL_BACKUP

echo.
echo %YELLOW%Backup canceled by user.%RESET%
goto EXITONLY

::Start Backup
:EXECUTE_BACKUP

if not exist "%BACKUP_ROOT%" (
    mkdir "%BACKUP_ROOT%" 2>nul

	if errorlevel 1 (
		echo %RED%ERROR%RESET% Failed to create backup directory.
		goto EXITONLY
	)
)

if not exist "%BACKUP_IMAGE_DIR%" mkdir "%BACKUP_IMAGE_DIR%"

echo Computer   : %CYAN%%COMPUTER_NAME%%RESET%
echo Source     : %CYAN%%WINDOWS_PARTITION%:%RESET%
echo Destination: %CYAN%%BACKUP_IMAGE_FILE%%RESET%
echo.

dir "%BACKUP_ROOT%" >nul 2>&1

if errorlevel 1 (
    echo.
    echo %RED%ERROR%RESET% Backup destination is not accessible.
    goto EXITONLY
)

echo.
echo %YELLOW%Starting Windows image capture...%RESET%
echo This process may take some time.
echo.


DISM ^
 /capture-image ^
 /capturedir:%WINDOWS_PARTITION%:\ ^
 /ImageFile:"%BACKUP_IMAGE_FILE%" ^
 /name:%COMPUTER_NAME%_%TIMESTAMP% ^
 /Description:"%COMPUTER_NAME%_%TIMESTAMP% partition %WINDOWS_PARTITION% lazyBackup v%SCRIPT_VERSION%" ^
 /LogPath:"%BACKUP_IMAGE_FILE:.wim=.log%" ^
 /Compress:max ^
 /Verify ^
 /ScratchDir:"%DISM_SCRATCH_PATH%"

echo.
if errorlevel 1 (
echo %RED%Backup failed.%RESET%
Goto EXITONLY
)

echo.
echo ==========================================
echo                SUCCESS
echo ==========================================
echo.
echo %GREEN%Backup completed successfully.%RESET%
echo.
echo Image:    %BACKUP_IMAGE_FILE%
echo Log file: %BACKUP_IMAGE_FILE:.wim=.log%
echo.

if defined SCRATCH_CREATED (
    rd /s /q "%DISM_SCRATCH_PATH%" 2>nul
)

goto EndLB

:DETECT_RESTORE_SOURCE_INIT
wpeinit >nul 2>&1
set "COMPUTER_NAME="
set "DETECTED_STORAGE_PATH="
set "ACTIVE_STORAGE_PATH="
set "SCRATCH_CREATED="

for %%g in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined COMPUTER_NAME (
        if exist %%g:\.pcname (
            set /p COMPUTER_NAME=<%%g:\.pcname
        )
    )
)

:RESTORE_TARGET

set "OPERATION_MODE=RESTORE"

set "RESTORE_PARTITION="

for %%i in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined RESTORE_PARTITION (
        if exist %%i:\.DRIVETORESTORE (
            set "RESTORE_PARTITION=%%i"
        )
    )
)

if not defined RESTORE_PARTITION (
    goto SELECT_RESTORE_DRIVE
)

goto PROMPT_NETWORK

:SELECT_RESTORE_DRIVE

echo.
echo ==========================================
echo      Select Restore Target Drive
echo ==========================================
echo.

set "DRIVECOUNT=0"

for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if /I not "%%D"=="X" (
        if exist %%D:\ (
            set /a DRIVECOUNT+=1
            set "DRIVE!DRIVECOUNT!=%%D"

            echo [!DRIVECOUNT!^] %%D:
            vol %%D: 2>nul
            echo.
        )
    )
)

echo [M] Manual Drive Letter Entry
echo.

set "SEL="
set /P SEL=Selection:

if /I "!SEL!"=="M" (
    set "RESTORE_PARTITION="
    set /P "RESTORE_PARTITION=Drive letter to restore: "

    if "!RESTORE_PARTITION:~1,1!"==":" (
        set "RESTORE_PARTITION=!RESTORE_PARTITION:~0,1!"
    )

    if not exist "!RESTORE_PARTITION!:\" (
        echo.
        echo %RED%Invalid or unavailable drive.%RESET%
        choice /C X /N /T 2 /D X >nul
        goto SELECT_RESTORE_DRIVE
    )

    goto PROMPT_NETWORK
)

set "RESTORE_PARTITION=!DRIVE%SEL%!"

if not defined RESTORE_PARTITION (
    echo.
    echo Invalid selection.
    goto SELECT_RESTORE_DRIVE
)

echo.
echo Selected restore target:
echo %CYAN%!RESTORE_PARTITION!:%RESET%

goto PROMPT_NETWORK

:RESTORE_SELECT_IMAGE

REM Image selection menu
set IMAGE_COUNT=0

echo.
echo ==========================================
echo            Available Images
echo ==========================================
echo.

if /I "%USE_COMPUTER_NAME_SUBFOLDER%"=="Y" (

    for /R "%BACKUP_ROOT%" %%F in (*.wim *.esd) do (
        set /a IMAGE_COUNT+=1
        set FILE!IMAGE_COUNT!=%%~fF
        echo !IMAGE_COUNT!^) %%~nxF
    )

) else (

    for %%F in ("%BACKUP_ROOT%\*.wim") do (
        set /a IMAGE_COUNT+=1
        set FILE!IMAGE_COUNT!=%%~fF
        echo !IMAGE_COUNT!^) %%~nxF
    )

    for %%F in ("%BACKUP_ROOT%\*.esd") do (
        set /a IMAGE_COUNT+=1
        set FILE!IMAGE_COUNT!=%%~fF
        echo !IMAGE_COUNT!^) %%~nxF
    )

)

REM Scan mounted Windows installation media

for %%D in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (

    if exist "%%D:\sources\install.wim" (
        set /a IMAGE_COUNT+=1
        set FILE!IMAGE_COUNT!=%%D:\sources\install.wim
        echo !IMAGE_COUNT!^) %%D:\sources\install.wim
    )

    if exist "%%D:\sources\install.esd" (
        set /a IMAGE_COUNT+=1
        set FILE!IMAGE_COUNT!=%%D:\sources\install.esd
        echo !IMAGE_COUNT!^) %%D:\sources\install.esd
    )

)

::Handle no images found
if %IMAGE_COUNT% EQU 0 (
    echo.
    echo No restore images found.
    echo.
    echo Checked:
    echo   %BACKUP_ROOT%
    echo.
    echo Supported image types:
    echo   *.wim
    echo   *.esd
    goto MAINMENU
)

REM Handle one image
if %IMAGE_COUNT% EQU 1 (
    set "RESTORE_IMAGE_FILE=!FILE1!"

    echo.
    echo Automatically selected:
    echo %RESTORE_IMAGE_FILE%

    goto RESTORE_SUMMARY
)

REM Handle multiple images
:: image list
echo.
set /P SELECTION=Image number:

set "RESTORE_IMAGE_FILE=!FILE%SELECTION%!"

if not defined RESTORE_IMAGE_FILE (
echo Invalid selection.
goto RESTORE_SELECT_IMAGE
)

for %%F in ("%RESTORE_IMAGE_FILE%") do (
    set "RESTORE_FILENAME=%%~nxF"
)

if /I "!RESTORE_FILENAME!"=="install.wim" goto RESTORE_SUMMARY
if /I "!RESTORE_FILENAME!"=="install.esd" goto RESTORE_SUMMARY

if defined COMPUTER_NAME (

    echo %RESTORE_IMAGE_FILE% | find /I "%COMPUTER_NAME%" >nul
    
    if errorlevel 1 (
        echo.
        echo ==========================================
        echo WARNING
        echo ==========================================
        echo.
        echo Selected image:
        echo %RESTORE_IMAGE_FILE%
        echo.
        echo does NOT contain the current computer name:
        echo %COMPUTER_NAME%
        echo.
        echo Current computer : %COMPUTER_NAME%
        echo Selected backup : %RESTORE_IMAGE_FILE%
        echo.
        echo This may be a backup from a different computer.
        echo.
        
        set /P DIFFERENT_PC_IMAGE_CONFIRM=Continue anyway? [Y/N]:

        if /I not "%DIFFERENT_PC_IMAGE_CONFIRM%"=="Y" goto RESTORE_SELECT_IMAGE
    )
)

:RESTORE_SUMMARY
echo.
echo ==========================================
echo              Restore Summary
echo ==========================================
echo.
echo Computer Name : %CYAN%%COMPUTER_NAME%%RESET%
echo Image file    : %CYAN%%RESTORE_IMAGE_FILE%%RESET%
echo Storage       : %CYAN%!ACTIVE_STORAGE_PATH!%RESET%
echo Scratch Dir   : !DISM_SCRATCH_PATH!
echo Target Drive  : %CYAN%%RESTORE_PARTITION%:%RESET%
echo.

:ASK_POST_ACTION_RESTORE

if not defined POST_OPERATION_ACTION (
    echo ==========================================
    echo    Select action after completion:
    echo ==========================================
    echo.
    echo [R] Reboot
    echo [S] Shutdown
    echo [N] Nothing
    echo.
    set /P POST_OPERATION_ACTION=Selection [R/S/N]:
)

if /I "%POST_OPERATION_ACTION%"=="R" goto ASK_FORMAT
if /I "%POST_OPERATION_ACTION%"=="S" goto ASK_FORMAT
if /I "%POST_OPERATION_ACTION%"=="N" goto ASK_FORMAT

echo.
echo %RED%Invalid selection.%RESET%
echo Please enter R, S or N.

set "POST_OPERATION_ACTION="
goto ASK_POST_ACTION_RESTORE

:ASK_FORMAT
echo.
echo ==========================================
echo Target Partition Format
echo ==========================================
echo.
echo Formatting is usually recommended before
echo restoring a Windows image to an empty disk.
echo Formatting is NECESSARY before restoring to
echo an EXISTING Windows PARTITION!
echo.

set /p FORMAT_PARTITION=Format target partition before restore? [Y/N\]:

if /I "%FORMAT_PARTITION%"=="Y" goto FORMAT_TARGET
if /I "%FORMAT_PARTITION%"=="N" goto EXECUTE_RESTORE

echo Invalid selection.
goto ASK_FORMAT

:FORMAT_TARGET
echo.
echo ==========================================
echo                %RED%WARNING!%RESET%
echo           ! POSSIBLE DATA LOSS !
echo.
echo                Target: %RESTORE_PARTITION%:
echo ==========================================
echo.
echo The target partition %RESTORE_PARTITION%: will be formatted.
echo.
echo %RED%All existing files and folders will be deleted.%RESET%
echo %RED%This action cannot be undone.%RESET%
echo.
set /P FORMATCONFIRM=Enter FORMAT in uppercase letters to confirm formatting:
if not "%FORMATCONFIRM%"=="FORMAT" goto ASK_FORMAT

REM /Y intentionally omitted
format %RESTORE_PARTITION%: /FS:NTFS /Q

if errorlevel 1 (
echo.
echo Format failed.
goto EXITONLY
)

echo.
echo Format completed successfully.
echo.

goto EXECUTE_RESTORE


:EXECUTE_RESTORE

REM Confirmation

echo.
echo ==========================================
echo                 WARNING
echo ==========================================
echo.

echo The image will be restored to:
echo %RESTORE_PARTITION%:
echo.

echo Existing data WILL be overwritten if files
echo already exist on the target partition.
echo.

REM --------------------------------------------------
REM Special notice for Windows installation images
REM --------------------------------------------------

for %%F in ("%RESTORE_IMAGE_FILE%") do (
    set "RESTORE_FILENAME=%%~nxF"
)

if /I "!RESTORE_FILENAME!"=="install.wim" (
    goto WINDOWS_SETUP_IMAGE_NOTICE
)

if /I "!RESTORE_FILENAME!"=="install.esd" (
    goto WINDOWS_SETUP_IMAGE_NOTICE
)

goto NORMAL_RESTORE_WARNING


:WINDOWS_SETUP_IMAGE_NOTICE

echo ==================================================
echo             Windows Setup Image
echo ==================================================
echo.

echo The selected source appears to be a %MAGENTA%Windows
echo installation medium%RESET%.
echo.

echo Source:
echo   %RESTORE_IMAGE_FILE%
echo.

echo This is %RED%NOT%RESET% a lazyBackup backup image!
echo.

echo The image will be applied directly using DISM,
echo similar to a Windows installation, but without
echo running Windows Setup.
echo.

echo Existing data on the target partition may be
echo overwritten.
echo.

echo.
echo Available Windows editions:
echo.

dism /Get-WimInfo /WimFile:"%RESTORE_IMAGE_FILE%"

echo.
set /P RESTORE_IMAGE_INDEX=Image index to apply:

if not defined RESTORE_IMAGE_INDEX (
    set "RESTORE_IMAGE_INDEX=1"
)

echo.
echo Selected image index: !RESTORE_IMAGE_INDEX!
echo.

:NORMAL_RESTORE_WARNING

REM just to confirm that there is probably no data to be overwritten.
REM but in both cases, ask anyway
if /I "%FORMAT_PARTITION%"=="Y" (
echo %RESTORE_PARTITION%: was just formatted, so it should be ok to continue.
echo.
)

set /p RESTCONFIRM=Start restore [Y/N\]:

if /I not "%RESTCONFIRM%"=="Y" goto MAINMENU

REM DISM apply
DISM ^
 /Apply-Image ^
 /ImageFile:"%RESTORE_IMAGE_FILE%" ^
 /Index:!RESTORE_IMAGE_INDEX! ^
 /ApplyDir:%RESTORE_PARTITION%:\ ^
 /Verify ^
 /ScratchDir:"%DISM_SCRATCH_PATH%"

if errorlevel 1 (
echo.
echo Restore failed.
goto EXITONLY
)
::Restore success
echo.
echo ==========================================
echo                SUCCESS
echo ==========================================
echo.
echo %GREEN%Restore completed successfully.%RESET%
echo.

if defined SCRATCH_CREATED (
    rd /s /q "%DISM_SCRATCH_PATH%" 2>nul
)

goto EndLB

:SHOWHELP
echo.
echo lazyBackup Help:
echo ----------------
echo Version: %SCRIPT_VERSION%
echo.
echo %MAGENTA%lazyBackup%RESET% will use DISM to backup one drive on another drive automatically 
echo if certain files are found on certain drives. 
echo.
echo It's possible to use a network drive for backup or enter arguments manually
echo if files are not found.
echo.
echo Place a file called .pcname containing the desired computer name as text in
echo the root of any drive for automatic computer name detection.
echo.
echo Place (empty) file .DRIVETOBACKUP in root of a drive to be backed up.
echo Backups will be saved in subfolder "WIM".
echo.
echo Place (empty) files .BACKUPSTORE / .USBBACKUPSTORE in root of any drive to
echo store the backup. A drive containing .USBBACKUPSTORE in its root has priority
echo over drives with .BACKUPSTORE. So a local drive is not used for backup if a
echo (USB) drive is present. Drives are searched from A-Z drive letter.
echo Alternatively, STORAGE_PATH can be configured
echo directly inside the script for unattended use.
echo.
echo %MAGENTA% * %RESET%Only first found files are used.%MAGENTA% *%RESET%
Goto END_NOTHING


::Exit EndlazyBackup
:EndLB

REM --------------------------------------------------
REM Validate the configured post-operation delay.
REM --------------------------------------------------

if not defined POST_OPERATION_DELAY_SECONDS (
    set "POST_OPERATION_DELAY_SECONDS=120"
)

for /F "delims=0123456789" %%A in ("%POST_OPERATION_DELAY_SECONDS%") do (
    set "POST_OPERATION_DELAY_INVALID=%%A"
)

if defined POST_OPERATION_DELAY_INVALID (
    echo.
    echo %YELLOW%WARNING%RESET% Invalid post-operation delay:
    echo   %POST_OPERATION_DELAY_SECONDS%
    echo.
    echo Falling back to 120 seconds.
    echo.

    set "POST_OPERATION_DELAY_SECONDS=120"
    set "POST_OPERATION_DELAY_INVALID="
)

if /I "%POST_OPERATION_ACTION%"=="R" goto POST_OPERATION_ACTION_R
if /I "%POST_OPERATION_ACTION%"=="S" goto POST_OPERATION_ACTION_S
if /I "%POST_OPERATION_ACTION%"=="N" goto EXITONLY

echo.
echo %YELLOW%WARNING%RESET% Invalid post-operation action:
echo   %POST_OPERATION_ACTION%
echo.
echo No reboot or shutdown will be performed.
echo.

goto EXITONLY


:POST_OPERATION_ACTION_R

echo.
echo %MAGENTA%lazyBackup%RESET% will exit in %POST_OPERATION_DELAY_SECONDS% seconds.
echo System will %RED%reboot%RESET%...
echo Press CTRL+C to cancel the countdown.
echo.

if "%POST_OPERATION_DELAY_SECONDS%"=="0" goto EXECUTE_REBOOT

choice /C X /N /T %POST_OPERATION_DELAY_SECONDS% /D X >nul


:EXECUTE_REBOOT

echo.
echo Rebooting now...
echo.

wpeutil reboot

if errorlevel 1 (
    echo.
    echo %RED%ERROR%RESET% The reboot command failed.
    echo.
    pause
)

goto END_NOTHING


:POST_OPERATION_ACTION_S

echo.
echo %MAGENTA%lazyBackup%RESET% will exit in %POST_OPERATION_DELAY_SECONDS% seconds.
echo System will %RED%shut down%RESET%...
echo Press CTRL+C to cancel the countdown.
echo.

if "%POST_OPERATION_DELAY_SECONDS%"=="0" goto EXECUTE_SHUTDOWN

choice /C X /N /T %POST_OPERATION_DELAY_SECONDS% /D X >nul


:EXECUTE_SHUTDOWN

echo.
echo Shutting down now...
echo.

wpeutil shutdown

if errorlevel 1 (
    echo.
    echo %RED%ERROR%RESET% The shutdown command failed.
    echo.
    pause
)

goto END_NOTHING


:EXITONLY

echo.
echo %MAGENTA%lazyBackup%RESET% will exit in %POST_OPERATION_DELAY_SECONDS% seconds.
echo No reboot or shutdown scheduled...
echo Press CTRL+C to cancel the countdown.
echo.

if "%POST_OPERATION_DELAY_SECONDS%"=="0" goto END_NOTHING

choice /C X /N /T %POST_OPERATION_DELAY_SECONDS% /D X >nul

goto END_NOTHING


:END_NOTHING
goto :eof


REM ==================================================
REM Find a free network drive letter
REM ==================================================

:FIND_FREE_NETWORK_DRIVE_LETTER

set "DRIVE_LETTER="
set "DRIVE_LETTER_IN_USE="

REM Search backwards from Z:.
REM
REM X: is intentionally omitted because X: is the
REM WinPE RAM drive.
REM
REM C: and earlier letters are not used automatically
REM because they commonly belong to local volumes.

for %%D in (Z Y W V U T S R Q P O N M L K J I H G F E D) do (
    if not defined DRIVE_LETTER (
        set "DRIVE_LETTER_IN_USE="

        REM Check local disks, optical drives and other
        REM accessible volumes using this drive letter.

        if exist "%%D:\" (
            set "DRIVE_LETTER_IN_USE=Y"
        )

        REM Also check existing network mappings.
        REM This catches a mapped drive that may currently
        REM be disconnected or otherwise inaccessible.

        net use "%%D:" >nul 2>&1

        if not errorlevel 1 (
            set "DRIVE_LETTER_IN_USE=Y"
        )

        if not defined DRIVE_LETTER_IN_USE (
            set "DRIVE_LETTER=%%D:"
        )
    )
)

if not defined DRIVE_LETTER (
    exit /b 1
)

echo.
echo Automatically selected network drive letter:
echo   !DRIVE_LETTER!
echo.

exit /b 0

REM ==================================================
REM Load whitelisted settings from configuration file
REM ==================================================

:LOAD_CONFIG_FILE

if not exist "%~1" exit /b 0

for /F "usebackq eol=# tokens=1,* delims==" %%A in ("%~1") do (

    REM Only known configuration variables are accepted.
    REM Empty values do not override existing values.

    if /I "%%A"=="USE_COMPUTER_NAME_SUBFOLDER" (
        if not "%%B"=="" set "USE_COMPUTER_NAME_SUBFOLDER=%%B"
    )

    if /I "%%A"=="WIM_SUBDIR" (
        if not "%%B"=="" set "WIM_SUBDIR=%%B"
    )

    if /I "%%A"=="STORAGE_PATH" (
        if not "%%B"=="" set "STORAGE_PATH=%%B"
    )

    if /I "%%A"=="OPERATION_MODE" (
        if not "%%B"=="" set "OPERATION_MODE=%%B"
    )

    if /I "%%A"=="OPERATION_MODE_TIMEOUT_SECONDS" (
        if not "%%B"=="" set "OPERATION_MODE_TIMEOUT_SECONDS=%%B"
    )

    if /I "%%A"=="BACKUP_CONFIRM_TIMEOUT_SECONDS" (
        if not "%%B"=="" set "BACKUP_CONFIRM_TIMEOUT_SECONDS=%%B"
    )

    if /I "%%A"=="POST_OPERATION_ACTION" (
        if not "%%B"=="" set "POST_OPERATION_ACTION=%%B"
    )

    if /I "%%A"=="POST_OPERATION_DELAY_SECONDS" (
        if not "%%B"=="" set "POST_OPERATION_DELAY_SECONDS=%%B"
    )
    if /I "%%A"=="MAP_NETWORK" (
        if not "%%B"=="" set "MAP_NETWORK=%%B"
    )

    if /I "%%A"=="DRIVE_LETTER" (
        if not "%%B"=="" set "DRIVE_LETTER=%%B"
    )

    if /I "%%A"=="NETWORK_PATH" (
        if not "%%B"=="" set "NETWORK_PATH=%%B"
    )

    if /I "%%A"=="NETWORK_USERNAME" (
        if not "%%B"=="" set "NETWORK_USERNAME=%%B"
    )

    if /I "%%A"=="PASSWORD" (
        if not "%%B"=="" set "PASSWORD=%%B"
    )

    if /I "%%A"=="DISM_SCRATCH" (
        if not "%%B"=="" set "DISM_SCRATCH=%%B"
    )
)

exit /b 0
