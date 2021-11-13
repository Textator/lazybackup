@ECHO off
REM #####################################################################
REM set date format to save with filename
REM #####################################################################
set YYYY=%date:~-4%
set MM=%date:~-7,2%
set DD=%date:~-10,2%
set hr=%time:~0,2%
if "%hr:~0,1%" == " " SET hr=0%hr:~1,1%
set min=%time:~3,2%
REM set sek=%time:~6,2%

SETLOCAL ENABLEDELAYEDEXPANSION

ECHO.
ECHO +-----------------+
ECHO + [1mBackup with DISM[0m +
ECHO +-----------------+
ECHO.

REM #####################################################################
REM ask for computername to save with filename
REM #####################################################################
SET /P computername=[95m[computer name][0m: 

REM #####################################################################
REM set partition letter to backup (clear first),
REM ask, if file .DRIVETOBACKUP not found in root of partition
REM #####################################################################
set "winpart="
FOR %%i in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) DO if exist %%i:\.DRIVETOBACKUP (SET winpart=%%i
	ECHO.
	ECHO file %%i:\.DRIVETOBACKUP found
	ECHO setting drive to backup to %%i:
	)	
IF [%winpart%]==[] (ECHO.
	ECHO file .DRIVETOBACKUP not found
	SET /P winpart=[95m[drive letter to backup][0m: )

REM #####################################################################
REM set path for backup storage (clear first),
REM ask if file .USBBACKUPSTORE (external drive)
REM or .BACKUPSTORE (internal drive) not found in root of partition
REM #####################################################################
set "storagepath="
for %%k in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) DO if exist %%k:\.USBBACKUPSTORE (SET storagepath=%%k
	ECHO.
	ECHO file .USBBACKUPSTORE found
	ECHO setting USB / external backup storage drive to %%k
	GOTO CONT)

for %%n in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) DO if exist %%n:\.BACKUPSTORE (SET storagepath=%%n
	ECHO.
	ECHO file .BACKUPSTORE found
	ECHO setting USB / external backup storage drive to %%n
	)	
IF [%storagepath%]==[] (ECHO.
	ECHO file .BACKUPSTORE not found
	SET /P storagepath=[95m[full storage path (no[0m without closing [95m'\'][0m: )

REM #####################################################################
REM CONTinue backup with DISM
REM #####################################################################
:CONT
ECHO.
SET /p conf=Backup with DISM [1mpartition %winpart%:[0m to [1m%storagepath%:\%computername%_%YYYY%%MM%%DD%_%hr%%min%.wim[0m [95m[Y/N][0m: 
FOR %%A in (Y N V) Do if /i '%conf%'=='%%A' goto :conf%%A 
ECHO.
ECHO invalid answer, enter Y, N or V
GOTO CONT
ECHO.
ECHO starting Backup with DISM
REM IF NOT EXIST %storagepath%\HDD\ mkdir %storagepath%\HDD
REM if exist "%storagepath%\HDD" if not exist "%storagepath%\HDD\" (echo "it's a file") else (echo "it's a dir")
if exist %storagepath%\HDD\NUL echo "%storagepath%\HDD\ already exists"
ECHO [1m%computername% partition %winpart%: in %storagepath%:\%computername%_%YYYY%%MM%%DD%_%hr%%min%.wim[0m
ECHO.
:confN 
ECHO.
ECHO Backup with DISM was canceled
ECHO.
GOTO Ende 
:confY 
ECHO * Backup with DISM
ECHO * computer name: %computername%
ECHO * partition to backup: %winpart%:
ECHO * backup to WIM file: [1m%storagepath%:\%computername%_%YYYY%%MM%%DD%_%hr%%min%.wim[0m
DISM /capture-image /capturedir:%winpart%:\ /ImageFile:%storagepath%:\%computername%_%YYYY%%MM%%DD%_%hr%%min%.wim /name:%computername%_%YYYY%%MM%%DD%_%hr%%min% /Description:"Lazybackup" /Compress:max


REM /Verify
:Ende 
ECHO.
