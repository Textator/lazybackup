@echo off
setlocal EnableDelayedExpansion

REM ==================================================
REM lazyBackup v0.6.4
REM GPL-3.0 License
REM https://github.com/Textator/lazybackup
REM ==================================================


REM ==================================================
REM Configuration BEGIN - you can modify this

set "BACKUP_ROOT="
set "STORAGEPATH="

set "POST_BACKUP_ACTION="
REM R = Reboot
REM N = No action
REM S = Shutdown

set "MAP_NETWORK="
REM set "MAP_NETWORK=N" N skips network anything else, including empty, does not 
set "DRIVE_LETTER="
set "NETWORK_PATH="
set "NETWORK_USERNAME="
set "PASSWORD="

REM Configuration END - don't modify below
REM ==================================================


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

set "LBversion=0.6.4"

title lazyBackup v%LBversion%


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

:STARTING

echo.
echo ==================================================
echo   * %BOLD%%MAGENTA%lazyBackup%RESET% v%LBversion%
echo   Fast Windows Image Backup using DISM
echo ==================================================
echo. Project: https://github.com/Textator/lazybackup
echo --------------------------------------------------
echo.

::check if HELP triggered	
if /I "%~1"=="help" goto SHOWHELP
if "%~1"=="/?" goto SHOWHELP
if /I "%~1"=="-h" goto SHOWHELP
goto BEGINING

:BEGINING

::Computer Name Detection
echo Searching for file %CYAN%.pcname%RESET%...
echo.

for %%g in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined machinename (
    if exist %%g:\.pcname (
        echo Found: %CYAN%%%g:\.pcname%RESET%
        set /p machinename=<%%g:\.pcname
        echo Using computer name: %CYAN%!machinename!%RESET%
    )
   )
)

if not defined machinename (
    echo.
    echo No valid %CYAN%.pcname%RESET% file found.
    set /P machinename=Enter computer name:
)

::Backup Source Detection
set "winpart="

for %%i in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined winpart (
    if exist %%i:\.DRIVETOBACKUP (
        set "winpart=%%i"
        echo.
        echo Found: %CYAN%%%i:\.DRIVETOBACKUP%RESET%
        echo Backup source drive: %CYAN%%%i:%RESET%
    )
   )
)

if not defined winpart (
    echo.
    echo No .DRIVETOBACKUP marker file found.
    set /P winpart=Enter drive letter to back up:
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

set /p "choice=Map a network storage location for storing the backup? [Y/N]: "

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
if not defined STORAGEPATH (
for %%k in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined STORAGEPATH (
    if exist %%k:\.USBBACKUPSTORE (
        set "STORAGEPATH=%%k"
        echo.
        echo Found USB backup storage:
        echo %CYAN%!STORAGEPATH!:\.USBBACKUPSTORE%RESET%
        echo Backup destination:
		echo %CYAN%!STORAGEPATH!:\WIM%RESET%
     )
    )
)
)

if not defined STORAGEPATH (
for %%n in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined STORAGEPATH (
    if exist %%n:\.BACKUPSTORE (
        set "STORAGEPATH=%%n"
        echo.
        echo Backup storage:
        echo %CYAN%!STORAGEPATH!:\.BACKUPSTORE%RESET%
        echo Backup destination:
        echo %CYAN%!STORAGEPATH!:\WIM%RESET%
    )
   )
)
)


if not defined STORAGEPATH goto ASK_STORAGE
goto STORAGE_OK

:ASK_STORAGE
echo.
echo No backup storage marker file found (.BACKUPSTORE or .USBBACKUPSTORE).
set /P STORAGEPATH=Enter backup path (without trailing backslash)

:STORAGE_OK

REM support UNC-path in path
if "!STORAGEPATH:~0,2!"=="\\" (
set "BACKUP_ROOT=!STORAGEPATH!\WIM"
) else (
set "BACKUP_ROOT=!STORAGEPATH!:\WIM"
)

::Backup Summary
:CONT
:ASK_POST_ACTION

if not defined POST_BACKUP_ACTION (
	echo.
	echo What to do after exiting LazyBackup?
	echo.
	set /P POST_BACKUP_ACTION= R = Reboot / S = Shutdown / N = Nothing? [R/S/N]:
)

if /I "%POST_BACKUP_ACTION%"=="R" goto POST_ACTION_OK
if /I "%POST_BACKUP_ACTION%"=="S" goto POST_ACTION_OK
if /I "%POST_BACKUP_ACTION%"=="N" goto POST_ACTION_OK

echo.
echo %RED%Invalid selection.%RESET%
echo Please enter R, S or N.
set "POST_BACKUP_ACTION="
goto ASK_POST_ACTION

:POST_ACTION_OK

echo.
echo ==========================================
echo               Backup Summary
echo ==========================================
echo.
echo Computer Name : %CYAN%%machinename%%RESET%
echo Source Drive  : %CYAN%%winpart%:%RESET%
echo Destination   : %CYAN%%BACKUP_ROOT%\%machinename%_%TIMESTAMP%.wim%RESET%
echo.


set /P conf=Start backup? [Y/N]:

if /I "%conf%"=="Y" goto confY
if /I "%conf%"=="N" goto confN

echo.
echo %RED%Invalid selection.%RESET%
echo Please enter Y or N.

timeout /t 2 >nul
goto CONT

::Cancel Backup
:confN

echo.
echo %YELLOW%Backup canceled by user.%RESET%
goto ExitOnly

::Start Backup
:confY

echo.
echo %YELLOW%Starting Windows image capture...%RESET%
echo This process may take some time.
echo.

if not exist "%BACKUP_ROOT%" (
    mkdir "%BACKUP_ROOT%" 2>nul

	if errorlevel 1 (
		echo %RED%ERROR%RESET% Failed to create backup directory.
		goto ExitOnly
	)
)

echo Computer   : %CYAN%%machinename%%RESET%
echo Source     : %CYAN%%winpart%:%RESET%
echo Destination: %CYAN%%BACKUP_ROOT%\%machinename%_%TIMESTAMP%.wim%RESET%
echo.

dir "%BACKUP_ROOT%" >nul 2>&1

if errorlevel 1 (
    echo.
    echo %RED%ERROR%RESET% Backup destination is not accessible.
    goto ExitOnly
)

DISM ^
 /capture-image ^
 /capturedir:%winpart%:\ ^
 /ImageFile:"%BACKUP_ROOT%\%machinename%_%TIMESTAMP%.wim" ^
 /name:%machinename%_%TIMESTAMP% ^
 /Description:"lazyBackup with DISM" ^
 /LogPath:"%BACKUP_ROOT%\%machinename%_%TIMESTAMP%.log" ^
 /Compress:max ^
 /Verify

echo.
if errorlevel 1 (
echo %RED%Backup failed.%RESET%
Goto ExitOnly
)

echo %GREEN%Backup completed successfully.%RESET%
echo.
echo Log file: %CYAN%%BACKUP_ROOT%\%machinename%_%TIMESTAMP%.log%RESET%
echo.

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

::Exit EndLazyBackup
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
