@echo off
setlocal EnableDelayedExpansion
REM ==================================================
REM lazyBackup
REM GPL-3.0 License
REM https://github.com/Textator/lazyBackup
REM ==================================================

REM script version
set "script_version=0.7"
title lazyBackup v%script_version%

REM **************************************************
REM Configuration BEGIN - modify from here
REM **************************************************

REM Backup directory below BACKUPSTORE/USBBACKUPSTORE
REM Backup directory below BACKUPSTORE/USBBACKUPSTORE
REM Empty = ask user
REM Examples:
REM set "WIM_SUBDIR=WIM"
REM set "WIM_SUBDIR=Images"
REM set "WIM_SUBDIR=Backups\Windows"
set "WIM_SUBDIR="

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

REM set "POST_BACKUP_ACTION=n"
REM R = Reboot
REM N = No action
REM S = Shutdown
set "POST_BACKUP_ACTION="

REM set "MAP_NETWORK=N" N skips network anything else, including empty, does not 
set "MAP_NETWORK="
set "DRIVE_LETTER=Z:"
set "NETWORK_PATH="
set "NETWORK_USERNAME="
set "PASSWORD="

REM **************************************************
REM Configuration END - don't modify below
REM **************************************************

REM runtime variables
set "COMPUTER_NAME="
set "WINDOWS_PARTITION="
set "STORAGE_PATH="
set "BACKUP_ROOT="
set "BACKUP_IMAGE_DIR="
set "BACKUP_IMAGE_FILE="
set "RESTORE_IMAGE_FILE="
set "RESTORE_PARTITION="
set "COUNT="
set "FORMAT_PARTITION="

REM ==================================================
REM Colours etc. configuration
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

set hr=%time:~0,2%
if "%hr:~0,1%"==" " set hr=0%hr:~1,1%
set min=%time:~3,2%

set "TIMESTAMP=%YYYY%%MM%%DD%_%hr%%min%"
REM ----------------------------------------------------
REM end Date Configuration
REM ----------------------------------------------------

:STARTING
echo.
echo ==================================================
echo   * %BOLD%%MAGENTA%lazyBackup%RESET% v%script_version%
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
echo [B] Backup Windows Partition
echo [R] Restore Windows Partition
echo [E] Exit
echo.

set /p OPERATION_MODE=Selection [b / r / e]:

if "%OPERATION_MODE%"=="b" goto BACKUP_INIT
if "%OPERATION_MODE%"=="r" goto RESTORE_INIT
if "%OPERATION_MODE%"=="e" goto EXITONLY

echo.
echo Invalid selection.
goto MAINMENU

:BACKUP_INIT
::Computer Name Detection
set "OPERATION_MODE=BACKUP"
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
    set /P COMPUTER_NAME=Enter computer name:
)

::Backup Source Detection
:BACKUP
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
    set /P WINDOWS_PARTITION=Enter drive letter to back up:
)

::Network Initialization
REM Initialize networking in WinPE

wpeinit >nul 2>&1

::Network Mapping Menu
:PROMPT_NETWORK

if /I "%MAP_NETWORK%"=="N" goto STORAGE

echo.
echo ==========================================
echo      Network Storage Configuration
echo ==========================================
echo.

set /p "choice=Map a network storage location for WIM storage? [Y/N]: "

if /I "%choice%"=="Y" goto MAPDRIVE
if /I "%choice%"=="J" goto MAPDRIVE
if /I "%choice%"=="N" goto STORAGE

echo.
echo %RED%Invalid selection.%RESET%
echo Please enter Y or N.

timeout /t 2 >nul
goto PROMPT_NETWORK

::Map Network Drive
:MAPDRIVE

:: Ask for missing network settings

if not defined DRIVE_LETTER (
set /P DRIVE_LETTER=Enter drive letter :
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
    set /P NETWORK_USERNAME=Enter network username :
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

:STORAGE
::Backup Storage Detection
::.USBBACKUPSTORE has priority over .BACKUPSTORE so local wimdir ist not used if USB-storage is present
if not defined STORAGE_PATH (
for %%k in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined STORAGE_PATH (
    if exist %%k:\.USBBACKUPSTORE (
        set "STORAGE_PATH=%%k"
        echo.
        echo Found USB backup storage:
        echo %CYAN%!STORAGE_PATH!:\.USBBACKUPSTORE%RESET%
        echo Backup destination:
		echo %CYAN%!STORAGE_PATH!:\WIM%RESET%
     )
    )
)
)

if not defined STORAGE_PATH (
for %%n in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined STORAGE_PATH (
    if exist %%n:\.BACKUPSTORE (
        set "STORAGE_PATH=%%n"
        echo.
        echo Backup storage:
        echo %CYAN%!STORAGE_PATH!:\.BACKUPSTORE%RESET%
        echo Backup destination:
        echo %CYAN%!STORAGE_PATH!:\WIM%RESET%
    )
   )
)
)

if not defined STORAGE_PATH goto ASK_STORAGE
goto STORAGE_OK

:ASK_STORAGE
echo.
echo No backup storage marker file found (.BACKUPSTORE or .USBBACKUPSTORE).
set /P STORAGE_PATH=Enter backup path (without trailing backslash)

if not defined WIM_SUBDIR (
    echo.
    set /P WIM_SUBDIR=Backup subfolder in storage root [default "WIM\"]:
)

:STORAGE_OK
REM support UNC-path in path
if "!STORAGE_PATH:~0,2!"=="\\" (
    set "BACKUP_ROOT=!STORAGE_PATH!\%WIM_SUBDIR%"
) else (
    set "BACKUP_ROOT=!STORAGE_PATH!:\%WIM_SUBDIR%"
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
if /I "%OPERATION_MODE%"=="BACKUP" goto ASK_POST_ACTION

:ASK_POST_ACTION

if not defined POST_BACKUP_ACTION (
	echo.
	echo What to do after exiting lazyBackup?
	echo.
	set /P POST_BACKUP_ACTION= R = Reboot / S = Shutdown / N = Nothing? [R/S/N]:
)

if /I "%POST_BACKUP_ACTION%"=="R" goto BACKUP_SUMMARY
if /I "%POST_BACKUP_ACTION%"=="S" goto BACKUP_SUMMARY
if /I "%POST_BACKUP_ACTION%"=="N" goto BACKUP_SUMMARY

echo.
echo %RED%Invalid selection.%RESET%
echo Please enter R, S or N.
set "POST_BACKUP_ACTION="
goto ASK_POST_ACTION

:BACKUP_SUMMARY
::Backup Summary
echo.
echo ==========================================
echo               Backup Summary
echo ==========================================
echo.
echo Computer Name : %CYAN%%COMPUTER_NAME%%RESET%
echo Source Drive  : %CYAN%%WINDOWS_PARTITION%:%RESET%
echo Destination   : %CYAN%%BACKUP_IMAGE_FILE%%RESET%
echo.

set /P conf=Start backup? [Y/N]:

if /I "%conf%"=="Y" goto BACKUP_SUMMARY
if /I "%conf%"=="N" goto CANCEL_BACKUP

echo.
echo %RED%Invalid selection.%RESET%
echo Please enter Y or N.

timeout /t 2 >nul
goto EXECUTE_BACKUP

::Cancel Backup
:CANCEL_BACKUP

echo.
echo %YELLOW%Backup canceled by user.%RESET%
goto ExitOnly

::Start Backup
:EXECUTE_BACKUP

if not exist "%BACKUP_ROOT%" (
    mkdir "%BACKUP_ROOT%" 2>nul

	if errorlevel 1 (
		echo %RED%ERROR%RESET% Failed to create backup directory.
		goto ExitOnly
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
    goto ExitOnly
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
 /Description:"lazyBackup with DISM" ^
 /LogPath:"%BACKUP_IMAGE_FILE:.wim=.log%" ^
 /Compress:max ^
 /Verify

echo.
if errorlevel 1 (
echo %RED%Backup failed.%RESET%
Goto ExitOnly
)

echo %GREEN%Backup completed successfully.%RESET%
echo.
echo Log file: %BACKUP_IMAGE_FILE:.wim=.log%
echo.

goto EndLB

:RESTORE_INIT
set "COMPUTER_NAME="

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
set COUNT=0

if /I "%USE_COMPUTER_NAME_SUBFOLDER%"=="Y" (
	for /R "%BACKUP_ROOT%" %%F in (*.wim) do (
		set /a COUNT+=1
		set FILE!COUNT!=%%~fF
		echo !COUNT!^) %%~nxF
	)
) else ( 
	for %%F in ("%BACKUP_ROOT%\*.wim") do (
		set /a COUNT+=1
		set FILE!COUNT!=%%~fF
		echo !COUNT!^) %%~nxF
	)
)

::Handle no images found
if %COUNT% EQU 0 (
echo.
echo No backup images found.
goto MAINMENU
)

REM Handle one image
if %COUNT% EQU 1 (
    set "RESTORE_IMAGE_FILE=!FILE1!"

    echo.
    echo Automatically selected:
    echo %RESTORE_IMAGE_FILE%

    goto RESTORE_SUMMARY
)

REM Handle multiple images
echo.
set /p SELECTION=Select image:

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
        
        set /P OTHERPC=Continue anyway? [Y/N\]:

        if /I not "%OTHERPC%"=="Y" goto RESTORE_SELECT_IMAGE
    )
)

:RESTORE_SUMMARY
echo.
echo ==========================================
echo              Restore Summary
echo ==========================================
echo.
echo Image File   : %RESTORE_IMAGE_FILE%
echo Target Drive : %RESTORE_PARTITION%:
echo.

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
echo WARNING:
echo ! POSSIBLE DATA LOSS ! :: make it very colorful and bold and blinkiung warning!
echo Formatting will erase all existing files
echo on %RESTORE_PARTITION%:
echo.

set /p FORMAT_PARTITION=Format target partition before restore? [Y/N\]:

if /I "%FORMAT_PARTITION%"=="Y" goto FORMAT_TARGET
if /I "%FORMAT_PARTITION%"=="N" goto RESTORE_START

echo Invalid selection.
goto ASK_FORMAT

:FORMAT_TARGET

echo.
echo Formatting %RESTORE_PARTITION%: as NTFS...
echo.
echo.
echo WARNING!
echo This will format %RESTORE_PARTITION%:
echo.

set /P FORMATCONFIRM=Type "FORMAT" to continue:

if /I not "%FORMATCONFIRM%"=="FORMAT" goto ASK_FORMAT

REM /Y intentionally omitted
format %RESTORE_PARTITION%: /FS:NTFS /Q

if errorlevel 1 (
echo.
echo Format failed.
goto ExitOnly
)

echo.
echo Format completed successfully.
echo.

goto RESTORE_START


:RESTORE_START
REM Confirmation
echo WARNING!
echo.
echo All data on %RESTORE_PARTITION%: will be overwritten.
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
 /Verify

if errorlevel 1 (
echo.
echo Restore failed.
goto ExitOnly
)
::Restore success
echo.
echo Restore completed successfully.
goto EndLB

:SHOWHELP
echo.
echo lazyBackup Help:
echo ----------------
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
echo %MAGENTA% * %RESET%Only first found files are used.%MAGENTA% *%RESET%
Goto END_NOTHING

::Exit EndlazyBackup
:EndLB
if /I "%POST_BACKUP_ACTION%"=="R" goto POST_BACKUP_ACTION_R
if /I "%POST_BACKUP_ACTION%"=="S" goto POST_BACKUP_ACTION_S
if /I "%POST_BACKUP_ACTION%"=="N" goto ExitOnly

:POST_BACKUP_ACTION_R
	echo %MAGENTA%lazyBackup%RESET% will exit in 120 seconds.
	echo System will %RED%reboot%RESET%...
	echo Press CTRL+C to cancel the countdown.
	timeout /t 120
	wpeutil reboot
:POST_BACKUP_ACTION_S
	echo %MAGENTA%lazyBackup%RESET% will exit in 120 seconds.
	echo System will %RED%shut down%RESET%...
	echo Press CTRL+C to cancel the countdown.
	timeout /t 120
	wpeutil shutdown
:ExitOnly
	echo %MAGENTA%lazyBackup%RESET% will exit in 120 seconds.
	echo No reboot or shutdown scheduled...
	echo Press CTRL+C to cancel the countdown.
	timeout /t 120
	::exit /b ::not used so cmd windows doesnt close
:END_NOTHING
