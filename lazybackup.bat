@echo off
setlocal EnableDelayedExpansion
REM ==================================================
REM lazyBackup
REM GPL-3.0 License
REM https://github.com/Textator/lazyBackup
REM ==================================================

REM script version
set "SCRIPT_VERSION=0.8.2"

title lazyBackup v%SCRIPT_VERSION%
cls

REM **************************************************
REM Configuration BEGIN - modify from here
REM **************************************************

REM Store backups in WIM_SUBDIR\COMPUTER_NAME\
REM Y = use COMPUTER_NAME subfolder
REM N = store all WIMs directly in WIM_SUBDIR\
set "USE_COMPUTER_NAME_SUBFOLDER=N"

REM Backup directory below BACKUPSTORE/USBBACKUPSTORE
REM Empty = ask user
REM Examples:
REM set "WIM_SUBDIR=WIM"
REM set "WIM_SUBDIR=Images"
REM set "WIM_SUBDIR=Backups\Windows"
set "WIM_SUBDIR="

REM set "OPERATION_MODE=b"
set "OPERATION_MODE="
REM eg. set "OPERATION_MODE=b"
REM [B] Backup Windows Partition
REM [R] Restore Windows Partition - !!! careful !!!
REM [E] Exit

REM set "POST_OPERATION_ACTION=n"
REM R = Reboot
REM N = No action
REM S = Shutdown
set "POST_OPERATION_ACTION="

REM set "MAP_NETWORK=N"
REM N = skip all network prompts
REM any other value (including empty) enables network configuration
set "MAP_NETWORK=n"

set "DRIVE_LETTER=Z:"
set "NETWORK_PATH=\\server\share"
set "NETWORK_USERNAME=domain\user"
set "PASSWORD=xxx"

REM DISM scratch directory
REM Empty = automatic selection
set "DISM_SCRATCH="



REM **************************************************
REM Configuration END - don't modify below
REM **************************************************

REM ==================================================
REM Administrator Rights Check
REM ==================================================

net session >nul 2>&1

if errorlevel 1 (
    echo.
    echo ==========================================
    echo ERROR
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
echo.
echo ==========================================
echo              Main Menu
echo ==========================================
echo.
echo [B] Backup Windows Partition
echo [R] Restore Windows Partition
echo [E] Exit
echo.
set /P OPERATION_MODE=Selection [B/R/E]:

if /I "%OPERATION_MODE%"=="b" goto DETECT_BACKUP_SOURCE_INIT
if /I "%OPERATION_MODE%"=="r" goto DETECT_RESTORE_SOURCE_INIT
if /I "%OPERATION_MODE%"=="e" goto EXITONLY

echo.
echo Invalid selection.
goto MAINMENU

:DETECT_BACKUP_SOURCE_INIT
set "OPERATION_MODE=BACKUP"
set "DETECTED_STORAGE_PATH="
set "ACTIVE_STORAGE_PATH="
set "SCRATCH_CREATED="

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
    echo.
    echo No .DRIVETOBACKUP marker file found.
    set /P WINDOWS_PARTITION=Enter drive letter to back up [drive letter]:
)

::Network Initialization
REM Initialize networking in WinPE

wpeinit >nul 2>&1

::Network Mapping Menu
:PROMPT_NETWORK

if /I "%MAP_NETWORK%"=="N" goto DETECT_WIM_STORAGE

echo.
echo ==========================================
echo      Network Storage Configuration
echo ==========================================
echo.

set /p "NETWORK_CHOICE=Map network storage for WIM files? [Y/N]: "

if /I "%NETWORK_CHOICE%"=="Y" goto MAP_NETWORK_DRIVE
if /I "%NETWORK_CHOICE%"=="J" goto MAP_NETWORK_DRIVE
if /I "%NETWORK_CHOICE%"=="N" goto DETECT_WIM_STORAGE

echo.
echo %RED%Invalid selection.%RESET%
echo Please enter Y or N.

timeout /t 2 >nul
goto PROMPT_NETWORK

::Map Network Drive
:MAP_NETWORK_DRIVE

:: Ask for missing network settings

if not defined DRIVE_LETTER (
set /P DRIVE_LETTER=Enter drive letter [drive letter]:
)

if not "%DRIVE_LETTER:~-1%"==":" (
set "DRIVE_LETTER=%DRIVE_LETTER%:"
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
::.USBBACKUPSTORE has priority over .BACKUPSTORE so local wimdir is not used if USB-storage is present
if not defined STORAGE_PATH (
for %%k in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined STORAGE_PATH if not defined DETECTED_STORAGE_PATH (
      if exist %%k:\.USBBACKUPSTORE (
        set "DETECTED_STORAGE_PATH=%%k"
        echo.
        echo Found USB backup storage via marker file .USBBACKUPSTORE:
        echo %CYAN%!DETECTED_STORAGE_PATH!:\.USBBACKUPSTORE%RESET%
        echo Backup destination:
		echo %CYAN%!DETECTED_STORAGE_PATH!:\WIM%RESET%
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
        echo Backup destination:
        echo %CYAN%!DETECTED_STORAGE_PATH!:\WIM%RESET%
    )
   )
 )
)

if not defined STORAGE_PATH if not defined DETECTED_STORAGE_PATH goto ASK_STORAGE
goto BUILD_STORAGE_PATHS

:ASK_STORAGE
echo.
echo No backup storage marker file found (.BACKUPSTORE or .USBBACKUPSTORE).
set /P DETECTED_STORAGE_PATH=Enter backup path (without trailing backslash)

if not defined WIM_SUBDIR (
    echo.
    set /P WIM_SUBDIR=Backup subfolder in storage root [FOLDER or ENTER for (default) "WIM\"\]:
)


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

    for %%D in (
        C D E F G H I J K L M N O P Q R S T U V W Y Z
    ) do (

        if exist %%D:\ (

            if /I not "%%D"=="X" (

                if /I not "%%D"=="!WINDOWS_PARTITION!" (

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
echo WIM-file      : %CYAN%%BACKUP_IMAGE_FILE%%RESET%
echo.

set /P BACKUP_CONFIRM=Start backup? [Y/N]:

if /I "%BACKUP_CONFIRM%"=="Y" goto EXECUTE_BACKUP
if /I "%BACKUP_CONFIRM%"=="N" goto CANCEL_BACKUP

echo.
echo %RED%Invalid selection.%RESET%
echo Please enter Y or N.

timeout /t 2 >nul
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
    set /p RESTORE_PARTITION=Drive letter to restore:
)
goto PROMPT_NETWORK

:RESTORE_SELECT_IMAGE
REM WIM selection menu
set IMAGE_COUNT=0

echo.
echo ==========================================
echo            Available Images
echo ==========================================
echo.

if /I "%USE_COMPUTER_NAME_SUBFOLDER%"=="Y" (
	for /R "%BACKUP_ROOT%" %%F in (*.wim) do (
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
)

::Handle no images found
if %IMAGE_COUNT% EQU 0 (
echo.
echo No WIM backup images found in %BACKUP_ROOT%.
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
echo WIM-file      : %CYAN%%RESTORE_IMAGE_FILE%%RESET%
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
 /Index:1 ^
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
if /I "%POST_OPERATION_ACTION%"=="R" goto POST_OPERATION_ACTION_R
if /I "%POST_OPERATION_ACTION%"=="S" goto POST_OPERATION_ACTION_S
if /I "%POST_OPERATION_ACTION%"=="N" goto EXITONLY

:POST_OPERATION_ACTION_R
	echo %MAGENTA%lazyBackup%RESET% will exit in 120 seconds.
	echo System will %RED%reboot%RESET%...
	echo Press CTRL+C to cancel the countdown.
	timeout /t 120
	wpeutil reboot
:POST_OPERATION_ACTION_S
	echo %MAGENTA%lazyBackup%RESET% will exit in 120 seconds.
	echo System will %RED%shut down%RESET%...
	echo Press CTRL+C to cancel the countdown.
	timeout /t 120
	wpeutil shutdown
:EXITONLY
	echo %MAGENTA%lazyBackup%RESET% will exit in 120 seconds.
	echo No reboot or shutdown scheduled...
	echo Press CTRL+C to cancel the countdown.
	timeout /t 120
	::exit /b ::not used so cmd windows doesnt close
:END_NOTHING
