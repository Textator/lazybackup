REM lazyBackup
REM GPL-3.0 License: https://github.com/Textator/lazybackup
REM
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
REM read / ask for computername to save with filename
REM #####################################################################
ECHO checking for file c.pcname[0m   
ECHO.
FOR %%g in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) DO if exist %%g:\.pcname (
		ECHO found file: [36m%%g:\.pcname[0m
		SET /p computername=<%%g:\.pcname
		ECHO read computer name as: [36m%computername%[0m
	) 
IF [%computername%]==[] (
		ECHO.
		ECHO file [36m.pcname[0m not found or file empty
		ECHO.
		SET /P computername=enter [95m[enter computer name][0m: 
	)
	
REM #####################################################################
REM set partition letter to backup (clear first),
REM ask, if file .DRIVETOBACKUP not found in root of partition
REM #####################################################################
set "winpart="
FOR %%i in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) DO if exist %%i:\.DRIVETOBACKUP (SET winpart=%%i
	ECHO.
	ECHO file [36m%%i:\.DRIVETOBACKUP[0m found
	ECHO setting drive to backup to [36m%%i:[0m
	)	
IF [%winpart%]==[] (ECHO.
	ECHO file [36m.DRIVETOBACKUP not found
	SET /P winpart=[95m[drive letter to backup][0m: )

REM #####################################################################
REM set path for backup storage (clear first),
REM ask if file .USBBACKUPSTORE (external drive)
REM or .BACKUPSTORE (internal drive) not found in root of partition
REM #####################################################################
set "storagepath="
for %%k in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) DO if exist %%k:\.USBBACKUPSTORE (SET storagepath=%%k
	ECHO.
	ECHO file  [36m%%k:\.USBBACKUPSTORE[0m found
	ECHO setting USB / external backup storage drive to [36m%%k:[0m
	GOTO CONT)

for %%n in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) DO if exist %%n:\.BACKUPSTORE (SET storagepath=%%n
	ECHO.
	ECHO file [36m%%n:\.BACKUPSTORE[0m found
	ECHO setting backup storage drive to [36m%%n:[0m and storage path to [36m%%n:\WIM\[0m
	)	
IF [%storagepath%]==[] (ECHO.
	ECHO file .BACKUPSTORE not found
	SET /P storagepath=[95m[full storage path (no[0m without closing [95m'\'][0m: )

REM #####################################################################
REM continue backup with DISM
REM #####################################################################
:CONT
ECHO.
SET /p conf=Backup with DISM partition [36m%winpart%:[0m to [36m%storagepath%:\WIM\%computername%_%YYYY%%MM%%DD%_%hr%%min%.wim[0m [95m[Y/N][0m: 
FOR %%A in (Y N V) Do if /i '%conf%'=='%%A' goto :conf%%A 
ECHO.
ECHO invalid answer, enter Y, N or V
GOTO CONT
ECHO.
ECHO starting Backup with DISM
REM IF NOT EXIST %storagepath%\WIM\ mkdir %storagepath%\WIM
REM if exist "%storagepath%\WIM" if not exist "%storagepath%\WIM\" (echo "it's a file") else (echo "it's a dir")
if exist %storagepath%\WIM\NUL echo "%storagepath%\WIM\ already exists"
if not exist %storagepath%\WIM\ mkdir %storagepath%\WIM
ECHO [1m%computername% partition %winpart%: in %storagepath%:\WIM\%computername%_%YYYY%%MM%%DD%_%hr%%min%.wim[0m
ECHO.
:confN 
ECHO.
ECHO Backup with DISM was canceled
ECHO.
GOTO Ende 
:confY 
ECHO Backup with DISM:
ECHO Computer [36m%computername%[0m
ECHO Partition [36m%winpart%:[0m
ECHO BACKUP-WIM [36m%storagepath%:\WIM\%computername%_%YYYY%%MM%%DD%_%hr%%min%.wim[0m
DISM /capture-image /capturedir:%winpart%:\ /ImageFile:%storagepath%\WIM\%computername%_%YYYY%%MM%%DD%_%hr%%min%.wim /name:%computername%_%YYYY%%MM%%DD%_%hr%%min% /Description:"LazyBackup with DISM" /Compress:max
REM /Verify
:Ende 
ECHO.
