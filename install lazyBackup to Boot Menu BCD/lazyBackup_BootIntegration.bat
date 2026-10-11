@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ==================================================
REM lazyBackup Boot Integration
REM Installs, updates, checks, boots, or removes the
REM permanent Windows Boot Manager entry.
REM Run as Administrator under full Windows.
REM ==================================================

REM --------------------------------------------------
REM Configuration
REM --------------------------------------------------

set "SYNC_ROOT=%SystemDrive%\ProgramData\Programme_portable\Sicherheit\lazybackup"
set "SOURCE_ISO=%SYNC_ROOT%\ISO output\lazyBackup_WinPE.iso"

set "BOOT_DIR=%SystemDrive%\ProgramData\lazyBackup_WinPE_Boot"
set "BCD_BOOT_PATH=\ProgramData\lazyBackup_WinPE_Boot"

set "BOOT_WIM=%BOOT_DIR%\boot.wim"
set "BOOT_SDI=%BOOT_DIR%\boot.sdi"
set "STATE_FILE=%BOOT_DIR%\bcd-state.conf"
set "SOURCE_STATE=%BOOT_DIR%\source-iso.conf"
set "BCD_BACKUP=%BOOT_DIR%\bcd-backup"
set "LOG_DIR=%BOOT_DIR%\Logs"
set "LOG_FILE=%LOG_DIR%\BootIntegration.log"
set "BOOT_HELPER=%BOOT_DIR%\boot-into-lazybackup.cmd"

set "BOOT_DESCRIPTION=lazyBackup Recovery"
set "RAMDISK_DESCRIPTION=lazyBackup Recovery Ramdisk"
set "BOOT_TIMEOUT=3"

set "LOADER_GUID="
set "RAMDISK_GUID="
set "ISO_DRIVE="
set "BOOT_LOADER_PATH="
set "SOURCE_HASH="
set "INSTALLED_HASH="
set "TEMP_WIM=%BOOT_WIM%.new"
set "TEMP_SDI=%BOOT_SDI%.new"

REM --------------------------------------------------
REM Initial checks
REM --------------------------------------------------

call :REQUIRE_ADMIN
if errorlevel 1 exit /b 1

call :REQUIRE_TOOLS
if errorlevel 1 exit /b 1

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1

call :LOG "Started lazyBackup Boot Integration."

:MENU
cls
echo.
echo ==================================================
echo       lazyBackup Boot Manager Integration
echo ==================================================
echo.
echo Source ISO:
echo   %SOURCE_ISO%
echo.
echo Local boot directory:
echo   %BOOT_DIR%
echo.
echo [I] Install or repair integration
echo [U] Update local WinPE files from ISO
echo [S] Show status
echo [B] Boot once into lazyBackup Recovery
echo [R] Remove integration
echo [E] Exit
echo.

set "MENU_CHOICE="
choice /C IUSBRE /N /M "Selection: "

if errorlevel 6 goto END
if errorlevel 5 goto REMOVE
if errorlevel 4 goto BOOT_ONCE
if errorlevel 3 goto STATUS
if errorlevel 2 goto UPDATE
if errorlevel 1 goto INSTALL

goto MENU

REM ==================================================
REM Install or repair
REM ==================================================

:INSTALL
cls
echo.
echo ==================================================
echo       Install lazyBackup Recovery Integration
echo ==================================================
echo.

call :VERIFY_SOURCE_ISO
if errorlevel 1 goto ACTION_FAILED

call :ENSURE_BOOT_DIR
if errorlevel 1 goto ACTION_FAILED

call :BACKUP_BCD
if errorlevel 1 goto ACTION_FAILED

call :STAGE_BOOT_FILES
if errorlevel 1 goto ACTION_FAILED

call :LOAD_STATE

if defined LOADER_GUID (
    call :BCD_ENTRY_EXISTS "!LOADER_GUID!"
    if errorlevel 1 (
        echo Stored loader entry no longer exists. A new entry will be created.
        set "LOADER_GUID="
    )
)

if defined RAMDISK_GUID (
    call :BCD_ENTRY_EXISTS "!RAMDISK_GUID!"
    if errorlevel 1 (
        echo Stored ramdisk entry no longer exists. A new entry will be created.
        set "RAMDISK_GUID="
    )
)

if not defined RAMDISK_GUID (
    call :CREATE_RAMDISK_ENTRY
    if errorlevel 1 goto BCD_INSTALL_FAILED
)

if not defined LOADER_GUID (
    call :FIND_EXISTING_LAZYBACKUP_ENTRY

    if errorlevel 1 (
        call :CREATE_LOADER_ENTRY

        if errorlevel 1 (
            goto BCD_INSTALL_FAILED
        )
    )
)

call :CONFIGURE_BCD
if errorlevel 1 goto BCD_INSTALL_FAILED

call :SAVE_STATE
if errorlevel 1 goto BCD_INSTALL_FAILED

call :WRITE_SOURCE_STATE
call :CREATE_BOOT_HELPER

call :LOG "Install or repair completed. Loader=!LOADER_GUID! Ramdisk=!RAMDISK_GUID!"

echo.
echo ==================================================
echo                    SUCCESS
echo ==================================================
echo.
echo lazyBackup Recovery is installed.
echo.
echo Boot menu entry:
echo   %BOOT_DESCRIPTION%
echo.
echo Loader identifier:
echo   !LOADER_GUID!
echo.
echo Ramdisk identifier:
echo   !RAMDISK_GUID!
echo.
echo Boot files:
echo   %BOOT_WIM%
echo   %BOOT_SDI%
echo.
echo One-time boot helper:
echo   %BOOT_HELPER%
echo.
echo The normal Windows default entry was not changed.
echo.
pause
goto MENU

:BCD_INSTALL_FAILED
call :LOG "BCD installation failed."
echo.
echo ERROR: BCD configuration failed.
echo The incomplete entries will be removed when possible.

if defined LOADER_GUID bcdedit /delete !LOADER_GUID! /cleanup >nul 2>&1
if defined RAMDISK_GUID bcdedit /delete !RAMDISK_GUID! /cleanup >nul 2>&1

del /q "%STATE_FILE%" >nul 2>&1
goto ACTION_FAILED

REM ==================================================
REM Update
REM ==================================================

:UPDATE
cls
echo.
echo ==================================================
echo          Update local lazyBackup WinPE
echo ==================================================
echo.

call :VERIFY_SOURCE_ISO
if errorlevel 1 goto ACTION_FAILED

call :LOAD_STATE
if not defined LOADER_GUID (
    echo ERROR: No stored lazyBackup loader identifier was found.
    echo Run Install first.
    goto ACTION_FAILED
)

call :BCD_ENTRY_EXISTS "!LOADER_GUID!"
if errorlevel 1 (
    echo ERROR: The stored lazyBackup loader entry no longer exists.
    echo Run Install to repair the integration.
    goto ACTION_FAILED
)

call :GET_SOURCE_HASH
call :LOAD_SOURCE_STATE

if defined SOURCE_HASH if /I "!SOURCE_HASH!"=="!INSTALLED_HASH!" (
    echo The synchronized ISO is already installed.
    echo.
    echo SHA256:
    echo   !SOURCE_HASH!
    echo.
    choice /C YN /N /M "Copy the boot files again anyway? [Y/N]: "
    if errorlevel 2 goto MENU
)

call :STAGE_BOOT_FILES
if errorlevel 1 goto ACTION_FAILED

call :WRITE_SOURCE_STATE
call :CREATE_BOOT_HELPER
call :LOG "Update completed from %SOURCE_ISO%."

echo.
echo ==================================================
echo                    SUCCESS
echo ==================================================
echo.
echo The local lazyBackup WinPE files were updated.
echo The existing BCD entries were not recreated.
echo.
echo Source:
echo   %SOURCE_ISO%
echo.
echo Destination:
echo   %BOOT_DIR%
echo.
pause
goto MENU

REM ==================================================
REM Status
REM ==================================================

:STATUS
cls
echo.
echo ==================================================
echo          lazyBackup Recovery Status
echo ==================================================
echo.

call :LOAD_STATE
call :GET_SOURCE_HASH
call :LOAD_SOURCE_STATE

if exist "%SOURCE_ISO%" (
    echo Source ISO       : Found
) else (
    echo Source ISO       : Missing
)
echo   %SOURCE_ISO%
echo.

if exist "%BOOT_DIR%" (
    echo Boot directory   : Found
) else (
    echo Boot directory   : Missing
)
echo   %BOOT_DIR%
echo.

if exist "%BOOT_WIM%" (echo boot.wim        : Present) else (echo boot.wim        : Missing)
if exist "%BOOT_SDI%" (echo boot.sdi        : Present) else (echo boot.sdi        : Missing)
echo.

if defined LOADER_GUID (
    call :BCD_ENTRY_EXISTS "!LOADER_GUID!"
    if errorlevel 1 (
        echo Loader entry     : Missing
    ) else (
        echo Loader entry     : Installed
    )
    echo   !LOADER_GUID!
) else (
    echo Loader entry     : No stored identifier
)
echo.

if defined RAMDISK_GUID (
    call :BCD_ENTRY_EXISTS "!RAMDISK_GUID!"
    if errorlevel 1 (
        echo Ramdisk entry    : Missing
    ) else (
        echo Ramdisk entry    : Installed
    )
    echo   !RAMDISK_GUID!
) else (
    echo Ramdisk entry    : No stored identifier
)
echo.

if defined SOURCE_HASH (
    echo Current ISO hash : !SOURCE_HASH!
) else (
    echo Current ISO hash : Unavailable
)

if defined INSTALLED_HASH (
    echo Installed hash   : !INSTALLED_HASH!
) else (
    echo Installed hash   : Unavailable
)

echo.
if defined SOURCE_HASH if defined INSTALLED_HASH (
    if /I "!SOURCE_HASH!"=="!INSTALLED_HASH!" (
        echo Update status    : Current
    ) else (
        echo Update status    : Update available or source changed
    )
)
echo.

if defined LOADER_GUID (
    echo BCD details:
    bcdedit /enum !LOADER_GUID!
    echo.
)

pause
goto MENU

REM ==================================================
REM One-time boot
REM ==================================================

:BOOT_ONCE
cls
echo.
echo ==================================================
echo       Boot once into lazyBackup Recovery
echo ==================================================
echo.

call :LOAD_STATE

if not defined LOADER_GUID (
    echo ERROR: No stored lazyBackup loader identifier was found.
    echo Run Install first.
    goto ACTION_FAILED
)

call :BCD_ENTRY_EXISTS "!LOADER_GUID!"
if errorlevel 1 (
    echo ERROR: The lazyBackup Recovery BCD entry is missing.
    echo Run Install to repair the integration.
    goto ACTION_FAILED
)

if not exist "%BOOT_WIM%" (
    echo ERROR: boot.wim is missing.
    goto ACTION_FAILED
)

if not exist "%BOOT_SDI%" (
    echo ERROR: boot.sdi is missing.
    goto ACTION_FAILED
)

echo The next restart will boot into:
echo   %BOOT_DESCRIPTION%
echo.
echo After the following restart, Windows remains the normal default.
echo.
choice /C YN /N /M "Set one-time boot and restart now? [Y/N]: "
if errorlevel 2 goto MENU

bcdedit /bootsequence !LOADER_GUID!
if errorlevel 1 (
    echo ERROR: Failed to set the one-time boot sequence.
    goto ACTION_FAILED
)

call :LOG "One-time boot requested for !LOADER_GUID!."
shutdown /r /f /t 0
exit /b 0

REM ==================================================
REM Remove
REM ==================================================

:REMOVE
cls
echo.
echo ==================================================
echo       Remove lazyBackup Recovery Integration
echo ==================================================
echo.

call :LOAD_STATE

if not defined LOADER_GUID if not defined RAMDISK_GUID (
    echo No stored lazyBackup BCD identifiers were found.
    echo.
) else (
    echo The following entries will be removed:
    if defined LOADER_GUID echo   Loader  : !LOADER_GUID!
    if defined RAMDISK_GUID echo   Ramdisk : !RAMDISK_GUID!
    echo.
    choice /C YN /N /M "Remove these BCD entries? [Y/N]: "
    if errorlevel 2 goto MENU

    if defined LOADER_GUID (
        bcdedit /delete !LOADER_GUID! /cleanup
        if errorlevel 1 echo WARNING: The loader entry could not be removed.
    )

    if defined RAMDISK_GUID (
        bcdedit /delete !RAMDISK_GUID! /cleanup
        if errorlevel 1 echo WARNING: The ramdisk entry could not be removed.
    )
)

del /q "%STATE_FILE%" >nul 2>&1

echo.
choice /C YN /N /M "Delete local boot files and logs too? [Y/N]: "
if errorlevel 2 (
    echo Local files were kept in:
    echo   %BOOT_DIR%
    call :LOG "BCD integration removed; local files kept."
    echo.
    pause
    goto MENU
)

call :LOG "BCD integration removed; deleting local boot directory."
cd /d "%SystemDrive%\"
rmdir /s /q "%BOOT_DIR%"

if exist "%BOOT_DIR%" (
    echo WARNING: The local boot directory could not be removed completely.
) else (
    echo Local boot directory removed.
)

echo.
pause
goto MENU

REM ==================================================
REM Helper routines
REM ==================================================

:REQUIRE_ADMIN
net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: Administrator privileges are required.
    echo Run this script as Administrator.
    echo.
    pause
    exit /b 1
)
exit /b 0

:REQUIRE_TOOLS
where bcdedit.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: bcdedit.exe was not found.
    pause
    exit /b 1
)

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: Windows PowerShell was not found.
    pause
    exit /b 1
)

where dism.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: dism.exe was not found.
    pause
    exit /b 1
)

where choice.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: choice.exe was not found.
    pause
    exit /b 1
)
exit /b 0

:VERIFY_SOURCE_ISO
if not exist "%SOURCE_ISO%" (
    echo ERROR: The synchronized lazyBackup WinPE ISO was not found:
    echo.
    echo   %SOURCE_ISO%
    echo.
    exit /b 1
)
exit /b 0

:ENSURE_BOOT_DIR
if not exist "%BOOT_DIR%" mkdir "%BOOT_DIR%" >nul 2>&1
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1

if not exist "%BOOT_DIR%" (
    echo ERROR: Failed to create:
    echo   %BOOT_DIR%
    exit /b 1
)
exit /b 0

:BACKUP_BCD
echo Backing up the current system BCD...
bcdedit /export "%BCD_BACKUP%"
if errorlevel 1 (
    echo ERROR: Failed to export the system BCD.
    exit /b 1
)
echo BCD backup:
echo   %BCD_BACKUP%
echo.
exit /b 0

:MOUNT_ISO

set "ISO_DRIVE="
set "POWERSHELL_ISO_DRIVE="

echo Mounting source ISO...

REM --------------------------------------------------
REM Mount the ISO if it is not already attached
REM --------------------------------------------------

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop'; $imagePath = $env:SOURCE_ISO; $image = Get-DiskImage -ImagePath $imagePath -ErrorAction SilentlyContinue; if (($null -eq $image) -or (-not $image.Attached)) { Mount-DiskImage -ImagePath $imagePath -ErrorAction Stop | Out-Null }" >nul 2>&1

if errorlevel 1 (
    echo ERROR: The source ISO could not be mounted.
    echo.
    echo Source ISO:
    echo   %SOURCE_ISO%
    echo.
    exit /b 1
)

REM --------------------------------------------------
REM Determine the assigned drive letter
REM --------------------------------------------------

for /F "usebackq delims=" %%D in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$volume = Get-DiskImage -ImagePath $env:SOURCE_ISO -ErrorAction Stop | Get-Volume | Where-Object { $_.DriveLetter } | Select-Object -First 1; if ($null -ne $volume) { $volume.DriveLetter }" 2^>nul`) do (
    if not defined POWERSHELL_ISO_DRIVE (
        set "POWERSHELL_ISO_DRIVE=%%D"
    )
)

if defined POWERSHELL_ISO_DRIVE (
    set "ISO_DRIVE=!POWERSHELL_ISO_DRIVE!:"
)

if not defined ISO_DRIVE (
    echo ERROR: The ISO is mounted, but no drive letter was found.
    echo.
    echo Source ISO:
    echo   %SOURCE_ISO%
    echo.
    call :DISMOUNT_ISO
    exit /b 1
)

REM --------------------------------------------------
REM Validate the detected drive
REM --------------------------------------------------

if not exist "!ISO_DRIVE!\" (
    echo ERROR: The detected ISO drive is not accessible.
    echo.
    echo Detected value:
    echo   !ISO_DRIVE!
    echo.
    call :DISMOUNT_ISO
    exit /b 1
)

echo Mounted as:
echo   !ISO_DRIVE!
echo.

exit /b 0

:DISMOUNT_ISO

if not exist "%SOURCE_ISO%" (
    set "ISO_DRIVE="
    exit /b 0
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$image = Get-DiskImage -ImagePath $env:SOURCE_ISO -ErrorAction SilentlyContinue; if (($null -ne $image) -and $image.Attached) { Dismount-DiskImage -ImagePath $env:SOURCE_ISO -ErrorAction SilentlyContinue | Out-Null }" >nul 2>&1

set "ISO_DRIVE="

exit /b 0

:STAGE_BOOT_FILES

call :ENSURE_BOOT_DIR

if errorlevel 1 (
    exit /b 1
)

call :MOUNT_ISO

if errorlevel 1 (
    exit /b 1
)

echo Verifying files in mounted ISO...
echo.

echo Expected boot.wim:
echo   !ISO_DRIVE!\sources\boot.wim

echo Expected boot.sdi:
echo   !ISO_DRIVE!\boot\boot.sdi
echo.

REM --------------------------------------------------
REM Verify boot.wim
REM --------------------------------------------------

if not exist "!ISO_DRIVE!\sources\boot.wim" (
    echo ERROR: sources\boot.wim was not found in the ISO.
    echo.
    echo Checked:
    echo   !ISO_DRIVE!\sources\boot.wim
    echo.
    call :DISMOUNT_ISO
    exit /b 1
)

REM --------------------------------------------------
REM Verify boot.sdi
REM --------------------------------------------------

if not exist "!ISO_DRIVE!\boot\boot.sdi" (
    echo ERROR: boot\boot.sdi was not found in the ISO.
    echo.
    echo Checked:
    echo   !ISO_DRIVE!\boot\boot.sdi
    echo.
    call :DISMOUNT_ISO
    exit /b 1
)

REM --------------------------------------------------
REM Remove previous temporary files
REM --------------------------------------------------

del /q "%TEMP_WIM%" >nul 2>&1
del /q "%TEMP_SDI%" >nul 2>&1

REM --------------------------------------------------
REM Copy boot files to temporary destinations
REM --------------------------------------------------

echo Copying boot.wim...

copy /y "!ISO_DRIVE!\sources\boot.wim" "%TEMP_WIM%" >nul

if errorlevel 1 (
    echo ERROR: Failed to copy boot.wim.
    call :DISMOUNT_ISO
    exit /b 1
)

echo Copying boot.sdi...

copy /y "!ISO_DRIVE!\boot\boot.sdi" "%TEMP_SDI%" >nul

if errorlevel 1 (
    echo ERROR: Failed to copy boot.sdi.
    call :DISMOUNT_ISO
    exit /b 1
)

REM --------------------------------------------------
REM Dismount the ISO before activating copied files
REM --------------------------------------------------

call :DISMOUNT_ISO

REM --------------------------------------------------
REM Verify copied file sizes
REM --------------------------------------------------

if not exist "%TEMP_WIM%" (
    echo ERROR: The copied boot.wim was not created.
    exit /b 1
)

if not exist "%TEMP_SDI%" (
    echo ERROR: The copied boot.sdi was not created.
    exit /b 1
)

for %%F in ("%TEMP_WIM%") do (
    if %%~zF LEQ 0 (
        echo ERROR: The copied boot.wim is empty.
        exit /b 1
    )
)

for %%F in ("%TEMP_SDI%") do (
    if %%~zF LEQ 0 (
        echo ERROR: The copied boot.sdi is empty.
        exit /b 1
    )
)

REM --------------------------------------------------
REM Validate boot.wim with DISM
REM --------------------------------------------------

echo Validating boot.wim...

dism /English /Get-WimInfo /WimFile:"%TEMP_WIM%" >nul

if errorlevel 1 (
    echo ERROR: DISM could not validate the copied boot.wim.
    exit /b 1
)

REM --------------------------------------------------
REM Back up currently installed boot files
REM --------------------------------------------------

del /q "%BOOT_WIM%.previous" >nul 2>&1
del /q "%BOOT_SDI%.previous" >nul 2>&1

if exist "%BOOT_WIM%" (
    copy /y "%BOOT_WIM%" "%BOOT_WIM%.previous" >nul

    if errorlevel 1 (
        echo ERROR: Failed to back up the existing boot.wim.
        exit /b 1
    )
)

if exist "%BOOT_SDI%" (
    copy /y "%BOOT_SDI%" "%BOOT_SDI%.previous" >nul

    if errorlevel 1 (
        echo ERROR: Failed to back up the existing boot.sdi.
        exit /b 1
    )
)

REM --------------------------------------------------
REM Activate updated boot files
REM --------------------------------------------------

move /y "%TEMP_WIM%" "%BOOT_WIM%" >nul

if errorlevel 1 (
    goto STAGE_ROLLBACK
)

move /y "%TEMP_SDI%" "%BOOT_SDI%" >nul

if errorlevel 1 (
    goto STAGE_ROLLBACK
)

REM --------------------------------------------------
REM Verify final files
REM --------------------------------------------------

if not exist "%BOOT_WIM%" (
    echo ERROR: The final boot.wim is missing.
    goto STAGE_ROLLBACK
)

if not exist "%BOOT_SDI%" (
    echo ERROR: The final boot.sdi is missing.
    goto STAGE_ROLLBACK
)

del /q "%BOOT_WIM%.previous" >nul 2>&1
del /q "%BOOT_SDI%.previous" >nul 2>&1

echo Boot files installed successfully.
echo.

exit /b 0

:STAGE_ROLLBACK

echo ERROR: Failed to activate the new boot files.
echo Restoring previous files...

if exist "%BOOT_WIM%.previous" (
    move /y "%BOOT_WIM%.previous" "%BOOT_WIM%" >nul
)

if exist "%BOOT_SDI%.previous" (
    move /y "%BOOT_SDI%.previous" "%BOOT_SDI%" >nul
)

del /q "%TEMP_WIM%" >nul 2>&1
del /q "%TEMP_SDI%" >nul 2>&1

exit /b 1

:GET_SOURCE_HASH
set "SOURCE_HASH="
if not exist "%SOURCE_ISO%" exit /b 1

for /F "usebackq delims=" %%H in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "(Get-FileHash -LiteralPath $env:SOURCE_ISO -Algorithm SHA256).Hash"`) do (
    if not defined SOURCE_HASH set "SOURCE_HASH=%%H"
)
exit /b 0

:LOAD_SOURCE_STATE
set "INSTALLED_HASH="
if not exist "%SOURCE_STATE%" exit /b 0

for /F "usebackq tokens=1,* delims==" %%A in ("%SOURCE_STATE%") do (
    if /I "%%A"=="ISO_SHA256" set "INSTALLED_HASH=%%B"
)
exit /b 0

:WRITE_SOURCE_STATE
call :GET_SOURCE_HASH
>"%SOURCE_STATE%" echo ISO_PATH=%SOURCE_ISO%
>>"%SOURCE_STATE%" echo ISO_SHA256=!SOURCE_HASH!
>>"%SOURCE_STATE%" echo UPDATED=%DATE% %TIME%
exit /b 0

:LOAD_STATE
set "LOADER_GUID="
set "RAMDISK_GUID="
if not exist "%STATE_FILE%" exit /b 0

for /F "usebackq tokens=1,* delims==" %%A in ("%STATE_FILE%") do (
    if /I "%%A"=="LOADER_GUID" set "LOADER_GUID=%%B"
    if /I "%%A"=="RAMDISK_GUID" set "RAMDISK_GUID=%%B"
)
exit /b 0

:SAVE_STATE
if not defined LOADER_GUID exit /b 1
if not defined RAMDISK_GUID exit /b 1

>"%STATE_FILE%" echo LOADER_GUID=!LOADER_GUID!
>>"%STATE_FILE%" echo RAMDISK_GUID=!RAMDISK_GUID!
exit /b 0

:BCD_ENTRY_EXISTS
bcdedit /enum %~1 >nul 2>&1
exit /b %errorlevel%

:FIND_EXISTING_LAZYBACKUP_ENTRY

set "FOUND_LOADER_GUID="
set "CURRENT_BCD_GUID="
set "CURRENT_BCD_DESCRIPTION="
set "CURRENT_BCD_DEVICE="

for /F "usebackq delims=" %%L in (`bcdedit /enum osloader /v`) do (
    set "BCD_LINE=%%L"

    echo(!BCD_LINE! | findstr /I /B /C:"identifier" /C:"Bezeichner" >nul

    if not errorlevel 1 (
        for %%G in (!BCD_LINE!) do (
            set "CURRENT_BCD_GUID=%%G"
        )

        set "CURRENT_BCD_DESCRIPTION="
        set "CURRENT_BCD_DEVICE="
    )

    echo(!BCD_LINE! | findstr /I /C:"lazyBackup Recovery" >nul

    if not errorlevel 1 (
        set "CURRENT_BCD_DESCRIPTION=Y"
    )

    echo(!BCD_LINE! | findstr /I /C:"\ProgramData\lazyBackup_WinPE_Boot\boot.wim" >nul

    if not errorlevel 1 (
        set "CURRENT_BCD_DEVICE=Y"
    )

    if defined CURRENT_BCD_GUID (
        if defined CURRENT_BCD_DESCRIPTION (
            if defined CURRENT_BCD_DEVICE (
                if not defined FOUND_LOADER_GUID (
                    set "FOUND_LOADER_GUID=!CURRENT_BCD_GUID!"
                )
            )
        )
    )
)

if defined FOUND_LOADER_GUID (
    set "LOADER_GUID=!FOUND_LOADER_GUID!"

    echo Existing lazyBackup Recovery loader found:
    echo   !LOADER_GUID!
    echo.

    exit /b 0
)

exit /b 1

:CREATE_RAMDISK_ENTRY
set "RAMDISK_GUID="
for /F "tokens=2 delims={}" %%G in ('bcdedit /create /d "%RAMDISK_DESCRIPTION%" /device') do (
    if not defined RAMDISK_GUID set "RAMDISK_GUID={%%G}"
)

if not defined RAMDISK_GUID (
    echo ERROR: Failed to create the ramdisk BCD entry.
    exit /b 1
)
exit /b 0

:CREATE_LOADER_ENTRY
set "LOADER_GUID="
for /F "tokens=2 delims={}" %%G in ('bcdedit /create /d "%BOOT_DESCRIPTION%" /application osloader') do (
    if not defined LOADER_GUID set "LOADER_GUID={%%G}"
)

if not defined LOADER_GUID (
    echo ERROR: Failed to create the WinPE loader BCD entry.
    exit /b 1
)
exit /b 0

:DETECT_LOADER_PATH
set "BOOT_LOADER_PATH=\Windows\System32\winload.exe"

bcdedit /enum {current} | findstr /I /C:"winload.efi" >nul
if not errorlevel 1 set "BOOT_LOADER_PATH=\Windows\System32\winload.efi"

exit /b 0

:CONFIGURE_BCD

call :DETECT_LOADER_PATH

echo Configuring ramdisk entry:
echo   !RAMDISK_GUID!

bcdedit /set !RAMDISK_GUID! ramdisksdidevice partition=%SystemDrive%

if errorlevel 1 (
    echo ERROR: Failed to configure the ramdisk SDI device.
    exit /b 1
)

bcdedit /set !RAMDISK_GUID! ramdisksdipath "%BCD_BOOT_PATH%\boot.sdi"

if errorlevel 1 (
    echo ERROR: Failed to configure the ramdisk SDI path.
    exit /b 1
)

echo Configuring WinPE loader entry:
echo   !LOADER_GUID!
echo.

echo Loader path:
echo   !BOOT_LOADER_PATH!
echo.

bcdedit /set !LOADER_GUID! device "ramdisk=[%SystemDrive%]%BCD_BOOT_PATH%\boot.wim,!RAMDISK_GUID!"

if errorlevel 1 (
    echo ERROR: Failed to configure the lazyBackup boot device.
    exit /b 1
)

bcdedit /set !LOADER_GUID! osdevice "ramdisk=[%SystemDrive%]%BCD_BOOT_PATH%\boot.wim,!RAMDISK_GUID!"

if errorlevel 1 (
    echo ERROR: Failed to configure the lazyBackup operating-system device.
    exit /b 1
)

bcdedit /set !LOADER_GUID! path "!BOOT_LOADER_PATH!"

if errorlevel 1 (
    echo ERROR: Failed to configure the lazyBackup loader path.
    exit /b 1
)

bcdedit /set !LOADER_GUID! systemroot "\Windows"

if errorlevel 1 (
    echo ERROR: Failed to configure the lazyBackup system root.
    exit /b 1
)

bcdedit /set !LOADER_GUID! winpe yes

if errorlevel 1 (
    echo ERROR: Failed to mark the loader as WinPE.
    exit /b 1
)

bcdedit /set !LOADER_GUID! detecthal yes

if errorlevel 1 (
    echo ERROR: Failed to enable hardware detection.
    exit /b 1
)

bcdedit /set !LOADER_GUID! nx optin

if errorlevel 1 (
    echo ERROR: Failed to configure NX for lazyBackup Recovery.
    exit /b 1
)

REM --------------------------------------------------
REM Add lazyBackup Recovery to the boot menu
REM --------------------------------------------------

bcdedit /displayorder !LOADER_GUID! /addlast

if errorlevel 1 (
    echo ERROR: Failed to add lazyBackup Recovery to the boot menu.
    exit /b 1
)

REM --------------------------------------------------
REM Keep the currently running Windows as default
REM --------------------------------------------------

bcdedit /default {current}

if errorlevel 1 (
    echo ERROR: Failed to keep the current Windows entry as default.
    exit /b 1
)

REM --------------------------------------------------
REM Use the modern graphical Windows boot menu
REM --------------------------------------------------

bcdedit /set {default} bootmenupolicy standard

if errorlevel 1 (
    echo ERROR: Failed to enable the standard Windows boot menu policy.
    exit /b 1
)

REM The WinPE loader does not need its own boot-menu policy.
REM Ignore "element not found" because that is the desired state.

bcdedit /deletevalue !LOADER_GUID! bootmenupolicy >nul 2>&1

REM Do not force displaybootmenu.
REM Leaving the value absent allows the modern graphical menu.
REM Ignore "element not found" because that is the desired state.

bcdedit /deletevalue {bootmgr} displaybootmenu >nul 2>&1

REM --------------------------------------------------
REM Configure automatic Windows startup
REM --------------------------------------------------

bcdedit /timeout %BOOT_TIMEOUT%

if errorlevel 1 (
    echo ERROR: Failed to configure the boot menu timeout.
    exit /b 1
)

echo.
echo Windows boot menu configured:
echo   Menu style    : Standard graphical menu
echo   Default entry : Current Windows
echo   Timeout       : %BOOT_TIMEOUT% seconds
echo.

exit /b 0

:CREATE_BOOT_HELPER
>"%BOOT_HELPER%" echo @echo off
>>"%BOOT_HELPER%" echo setlocal EnableExtensions
>>"%BOOT_HELPER%" echo net session ^>nul 2^>^&1
>>"%BOOT_HELPER%" echo if errorlevel 1 ^(
>>"%BOOT_HELPER%" echo     echo Administrator privileges are required.
>>"%BOOT_HELPER%" echo     pause
>>"%BOOT_HELPER%" echo     exit /b 1
>>"%BOOT_HELPER%" echo ^)
>>"%BOOT_HELPER%" echo set "LOADER_GUID=!LOADER_GUID!"
>>"%BOOT_HELPER%" echo bcdedit /enum %%LOADER_GUID%% ^>nul 2^>^&1
>>"%BOOT_HELPER%" echo if errorlevel 1 ^(
>>"%BOOT_HELPER%" echo     echo lazyBackup Recovery BCD entry was not found.
>>"%BOOT_HELPER%" echo     pause
>>"%BOOT_HELPER%" echo     exit /b 1
>>"%BOOT_HELPER%" echo ^)
>>"%BOOT_HELPER%" echo bcdedit /bootsequence %%LOADER_GUID%%
>>"%BOOT_HELPER%" echo if errorlevel 1 ^(
>>"%BOOT_HELPER%" echo     echo Failed to set the one-time boot sequence.
>>"%BOOT_HELPER%" echo     pause
>>"%BOOT_HELPER%" echo     exit /b 1
>>"%BOOT_HELPER%" echo ^)
>>"%BOOT_HELPER%" echo shutdown /r /f /t 0
>>"%BOOT_HELPER%" echo exit /b 0
exit /b 0

:LOG
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
>>"%LOG_FILE%" echo [%DATE% %TIME%] %~1
exit /b 0

:ACTION_FAILED
call :DISMOUNT_ISO
call :LOG "Action failed."
echo.
echo ==================================================
echo                     FAILED
echo ==================================================
echo.
echo The requested operation did not complete.
echo Review the messages above and:
echo   %LOG_FILE%
echo.
pause
goto MENU

:END
call :DISMOUNT_ISO
call :LOG "Exited lazyBackup Boot Integration."
exit /b 0
