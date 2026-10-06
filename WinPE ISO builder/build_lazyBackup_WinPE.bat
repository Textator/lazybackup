@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ==================================================
REM lazyBackup WinPE Builder
REM Run from the Deployment and Imaging Tools
REM Environment as Administrator
REM ==================================================

set "WORKDIR=E:\WinPE"
set "OUTPUT_ISO=E:\Programme\Sicherheit\lazybackup\WinPE ISO\lazyBackup_WinPE.iso"

set "SOURCE_ROOT=E:\Programme\Sicherheit\lazybackup"
set "SOURCE_SCRIPT=%SOURCE_ROOT%\lazybackup.bat"
set "SOURCE_STARTNET=%SOURCE_ROOT%\WinPE files\startnet.cmd"
set "SOURCE_MARKERS=%SOURCE_ROOT%\marker files"

set "MOUNTDIR=%WORKDIR%\mount"
set "MEDIA=%WORKDIR%\media"

REM ADK Deployment Tools path
set "ADKTOOLS=%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools"

REM Windows PE Add-on path
set "WINPEROOT=%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"

REM ADK environment initialization script
set "ADK_ENV=%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\DandISetEnv.bat"

echo.
echo ==================================================
echo          lazyBackup WinPE Builder
echo ==================================================
echo.

REM --------------------------------------------------
REM Administrator check
REM --------------------------------------------------

net session >nul 2>&1

if errorlevel 1 (
    echo ERROR: Administrator privileges are required.
    goto FAILED
)

REM --------------------------------------------------
REM Verify ADK Deployment Tools and WinPE Add-on
REM --------------------------------------------------

echo Checking Windows ADK and WinPE installation...

if not exist "!ADK_ENV!" goto ADK_MISSING

if not exist "!WINPEROOT!\amd64\en-us\winpe.wim" (
    echo.
    echo ERROR: The Windows PE Add-on or the amd64 WinPE image
    echo was not found.
    echo.
    echo Expected file:
    echo   !WINPEROOT!\amd64\en-us\winpe.wim
    echo.
    goto ADK_MISSING
)

REM Load the ADK environment if copype is not already available.

where copype.cmd >nul 2>&1

if errorlevel 1 (
    echo Loading the Deployment and Imaging Tools environment...

    call "!ADK_ENV!" amd64

    if errorlevel 1 (
        echo.
        echo ERROR: Failed to initialize the ADK environment.
        goto ADK_MISSING
    )
)

where copype.cmd >nul 2>&1

if errorlevel 1 (
    echo.
    echo ERROR: copype.cmd is not available.
    goto ADK_MISSING
)

where oscdimg.exe >nul 2>&1

if errorlevel 1 (
    echo.
    echo ERROR: oscdimg.exe is not available.
    goto ADK_MISSING
)

echo Windows ADK Deployment Tools found.
echo Windows PE Add-on found.
echo Required build commands are available.
echo.
REM --------------------------------------------------
REM Verify required files
REM --------------------------------------------------

if not exist "%SOURCE_SCRIPT%" (
    echo ERROR: lazyBackup was not found:
    echo %SOURCE_SCRIPT%
    goto FAILED
)

if not exist "%SOURCE_STARTNET%" (
    echo ERROR: startnet.cmd was not found:
    echo %SOURCE_STARTNET%
    goto FAILED
)

if not exist "%SystemRoot%\System32\choice.exe" (
    echo ERROR: choice.exe was not found.
    goto FAILED
)

REM --------------------------------------------------
REM Remove previous working directory
REM --------------------------------------------------

echo Removing previous WinPE working directory...

if exist "%MOUNTDIR%\Windows" (
    echo Cleaning up previous mounted image...
    Dism /Unmount-Image /MountDir:"%MOUNTDIR%" /Discard >nul 2>&1
)

REM This would clean up ALL stale mount points on the system
REM and is therefore intentionally disabled.
REM Dism /Cleanup-Mountpoints >nul 2>&1

if exist "%WORKDIR%" (
    rmdir /s /q "%WORKDIR%"
)

if exist "%WORKDIR%" (
    echo ERROR: Failed to remove:
    echo %WORKDIR%
    goto FAILED
)

REM --------------------------------------------------
REM Create fresh WinPE working directory
REM --------------------------------------------------

echo Creating Windows PE working directory...

call copype amd64 "%WORKDIR%"

if errorlevel 1 (
    echo ERROR: copype failed.
    goto FAILED
)

REM --------------------------------------------------
REM Mount boot.wim
REM --------------------------------------------------

echo Mounting boot.wim...

Dism /Mount-Image /ImageFile:"%MEDIA%\sources\boot.wim" /Index:1 /MountDir:"%MOUNTDIR%"

if errorlevel 1 (
    echo ERROR: Failed to mount boot.wim.
    goto FAILED
)

REM --------------------------------------------------
REM Add choice.exe
REM --------------------------------------------------

echo Copying choice.exe...

copy /y "%SystemRoot%\System32\choice.exe" "%MOUNTDIR%\Windows\System32\choice.exe" >nul

if errorlevel 1 (
    echo ERROR: Failed to copy choice.exe.
    goto DISCARD_IMAGE
)

REM --------------------------------------------------
REM Add lazyBackup
REM --------------------------------------------------

echo Copying lazyBackup...

if not exist "%MOUNTDIR%\lazyBackup" (
    mkdir "%MOUNTDIR%\lazyBackup"
)

copy /y "%SOURCE_SCRIPT%" "%MOUNTDIR%\lazyBackup\lazyBackup.bat" >nul

if errorlevel 1 (
    echo ERROR: Failed to copy lazyBackup.bat.
    goto DISCARD_IMAGE
)

if exist "%SOURCE_ROOT%\README.md" (
    copy /y "%SOURCE_ROOT%\README.md" "%MOUNTDIR%\lazyBackup\README.md" >nul
)

if exist "%SOURCE_ROOT%\LICENSE" (
    copy /y "%SOURCE_ROOT%\LICENSE" "%MOUNTDIR%\lazyBackup\LICENSE" >nul
)

REM --------------------------------------------------
REM Add marker-file examples
REM --------------------------------------------------

if exist "%SOURCE_MARKERS%" (
    echo Copying marker-file examples...

    if not exist "%MOUNTDIR%\lazyBackup\marker files" (
        mkdir "%MOUNTDIR%\lazyBackup\marker files"
    )

    xcopy "%SOURCE_MARKERS%\*" "%MOUNTDIR%\lazyBackup\marker files\" /E /I /H /Y >nul

    if errorlevel 1 (
        echo WARNING: Marker-file examples could not be copied.
    )
)

REM --------------------------------------------------
REM Install startnet.cmd
REM --------------------------------------------------

echo Installing startnet.cmd...

copy /y "%SOURCE_STARTNET%" "%MOUNTDIR%\Windows\System32\startnet.cmd" >nul

if errorlevel 1 (
    echo ERROR: Failed to copy startnet.cmd.
    goto DISCARD_IMAGE
)

REM --------------------------------------------------
REM Increase WinPE scratch space
REM --------------------------------------------------

echo Setting WinPE scratch space to 512 MB...

Dism /Image:"%MOUNTDIR%" /Set-ScratchSpace:512

if errorlevel 1 (
    echo ERROR: Failed to configure WinPE scratch space.
    goto DISCARD_IMAGE
)

REM --------------------------------------------------
REM Commit boot.wim
REM --------------------------------------------------

echo Committing boot.wim...

Dism /Unmount-Image /MountDir:"%MOUNTDIR%" /Commit

if errorlevel 1 (
    echo ERROR: Failed to commit boot.wim.
    goto FAILED
)

REM --------------------------------------------------
REM Disable BIOS "Press any key" prompt
REM --------------------------------------------------

if exist "%MEDIA%\boot\bootfix.bin" (
    del /f /q "%MEDIA%\boot\bootfix.bin"
)

REM --------------------------------------------------
REM Verify BIOS and UEFI boot images
REM --------------------------------------------------

set "BIOS_BOOT=!ADKTOOLS!\amd64\Oscdimg\etfsboot.com"
set "UEFI_BOOT=!ADKTOOLS!\amd64\Oscdimg\efisys_noprompt.bin"

if not exist "!BIOS_BOOT!" (
    echo.
    echo ERROR: BIOS boot image was not found:
    echo   !BIOS_BOOT!
    goto FAILED
)

if not exist "!UEFI_BOOT!" (
    echo.
    echo ERROR: UEFI no-prompt boot image was not found:
    echo   !UEFI_BOOT!
    goto FAILED
)

echo BIOS boot image found:
echo   !BIOS_BOOT!
echo.
echo UEFI no-prompt boot image found:
echo   !UEFI_BOOT!
echo.

REM --------------------------------------------------
REM Remove previous ISO
REM --------------------------------------------------

if exist "%OUTPUT_ISO%" (
    del /f /q "%OUTPUT_ISO%"
)

if exist "%OUTPUT_ISO%" (
     echo ERROR: Existing ISO could not be removed:
     echo %OUTPUT_ISO%
     echo The ISO may still be mounted or in use.
     goto FAILED
)

REM --------------------------------------------------
REM Create BIOS + UEFI no-prompt ISO
REM --------------------------------------------------

echo Creating BIOS and UEFI bootable ISO...

oscdimg -m -o -u2 -udfver102 -lLAZYBACKUP -bootdata:2#p0,e,b"!BIOS_BOOT!"#pEF,e,b"!UEFI_BOOT!" "!MEDIA!" "!OUTPUT_ISO!"

if errorlevel 1 (
    echo ERROR: ISO creation failed.
    goto FAILED
)

echo.
echo ==================================================
echo                  SUCCESS
echo ==================================================
echo.
echo ISO created:
echo %OUTPUT_ISO%
echo.
echo Supported boot modes:
echo   - Legacy BIOS
echo   - UEFI
echo.
echo Automatic boot:
echo   - BIOS bootfix prompt removed
echo   - UEFI no-prompt boot image used
echo.
goto END

:DISCARD_IMAGE

echo.
echo Discarding mounted image...

Dism /Unmount-Image /MountDir:"%MOUNTDIR%" /Discard >nul 2>&1
goto FAILED

:FAILED

echo.
echo ==================================================
echo                   FAILED
echo ==================================================
echo.
echo The lazyBackup WinPE image was not created.
echo Review the messages above and the DISM log.
echo.
pause
exit /b 1

:END

pause
exit /b 0


:ADK_MISSING

echo.
echo ==================================================
echo        WINDOWS ADK / WINPE NOT AVAILABLE
echo ==================================================
echo.
echo Install both of the following components:
echo.
echo   1. Windows ADK
echo      Select: Deployment Tools
echo.
echo   2. Windows PE Add-on for the matching ADK
echo.
echo Official download page:
echo   Microsoft Learn - Download and install the Windows ADK
echo   See the project README.md for the official link.
echo.
echo After installation, run this builder again as Administrator.
echo.
echo You may use either:
echo.
echo   - Deployment and Imaging Tools Environment
echo   - A normal elevated command prompt
echo.
echo The builder will initialize the ADK environment automatically
echo when the required components are installed.
echo.
pause
exit /b 1