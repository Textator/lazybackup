@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ==================================================
REM Automatic administrator elevation
REM ==================================================
REM
REM The ISO builders require administrator privileges
REM for DISM, ISO mounting and BCD modification.
REM
REM If this script is not elevated, it restarts itself
REM through PowerShell with the RunAs verb. Windows then
REM displays the normal UAC confirmation dialog.
REM
REM The elevated process uses the directory containing
REM this batch file as its working directory.
REM ==================================================

powershell.exe -NoProfile -Command ^
    "if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 0 } else { exit 1 }" >nul 2>&1

if errorlevel 1 (
    echo.
    echo ==================================================
    echo       Administrator privileges required
    echo ==================================================
    echo.
    echo Requesting elevation through Windows UAC...
    echo.

    set "__ELEVATE_SCRIPT=%~f0"
    set "__ELEVATE_DIRECTORY=%~dp0"

    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
        "$script = $env:__ELEVATE_SCRIPT; " ^
        "$directory = $env:__ELEVATE_DIRECTORY; " ^
        "try { " ^
        "    Start-Process -FilePath $env:ComSpec " ^
        "        -ArgumentList @('/d', '/c', ('\"' + $script + '\"')) " ^
        "        -WorkingDirectory $directory " ^
        "        -Verb RunAs; " ^
        "    exit 0 " ^
        "} catch { " ^
        "    Write-Host ''; " ^
        "    Write-Host 'Elevation was canceled or failed.'; " ^
        "    exit 1 " ^
        "}"

    if errorlevel 1 (
        echo.
        echo ERROR: Administrator elevation was not completed.
        echo.
        pause
        exit /b 1
    )

    exit /b 0
)

REM Ensure that relative paths use the builder location.
pushd "%~dp0"

REM ==================================================
REM lazyBackup WinPE Builder
REM Run from the Deployment and Imaging Tools
REM Environment as Administrator
REM ==================================================

REM ==================================================
REM Portable project paths
REM ==================================================
REM
REM SCRIPT_DIR is the directory containing this builder.
REM PROJECT_ROOT is the parent lazyBackup directory.
REM
REM Example:
REM SCRIPT_DIR:
REM   E:\Programme\Sicherheit\lazybackup\ISO builder
REM
REM PROJECT_ROOT:
REM   E:\Programme\Sicherheit\lazybackup
REM ==================================================

for %%I in ("%~dp0.") do set "SCRIPT_DIR=%%~fI"
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"

set "BUILDER_FILES=%SCRIPT_DIR%\Builder files"
set "DRIVER_ROOT=%SCRIPT_DIR%\Drivers"
set "ISO_OUTPUT_DIRECTORY=%PROJECT_ROOT%\ISO output"
set "MARKER_EXAMPLES=%PROJECT_ROOT%\marker files examples"


REM ==================================================
REM Optional absolute path overrides
REM ==================================================
REM
REM Leave empty to use the portable project paths.
REM
REM A configured absolute path takes priority over the
REM portable default.
REM ==================================================

set "CONFIG_SOURCE_ROOT="
set "CONFIG_WORKDIR="
set "CONFIG_OUTPUT_ISO="


REM ==================================================
REM Resolve effective paths
REM ==================================================

if defined CONFIG_SOURCE_ROOT (
    set "SOURCE_ROOT=%CONFIG_SOURCE_ROOT%"
) else (
    set "SOURCE_ROOT=%PROJECT_ROOT%"
)

if defined CONFIG_WORKDIR (
    set "WORKDIR=%CONFIG_WORKDIR%"
) else (
    set "WORKDIR=%TEMP%\lazyBackup_Build\WinPE"
)

if defined CONFIG_OUTPUT_ISO (
    set "OUTPUT_ISO=%CONFIG_OUTPUT_ISO%"
) else (
    set "OUTPUT_ISO=%ISO_OUTPUT_DIRECTORY%\lazyBackup_WinPE.iso"
)

set "SOURCE_SCRIPT=%SOURCE_ROOT%\lazybackup.bat"
set "SOURCE_STARTNET=%BUILDER_FILES%\startnet.cmd"
set "SOURCE_MARKERS=%MARKER_EXAMPLES%"

set "LOCAL_CHOICE=%BUILDER_FILES%\choice.exe"
set "LOCAL_FINDSTR=%BUILDER_FILES%\findstr.exe"

set "MOUNTDIR=%WORKDIR%\mount"
set "MEDIA=%WORKDIR%\media"

REM --------------------------------------------------
REM Image and ISO metadata defaults
REM --------------------------------------------------

set "LAZYBACKUP_VERSION="
set "ISO_VERSION="
set "ISO_LABEL=LAZYBACKUP_WINPE"
set "WIM_IMAGE_NAME=lazyBackup WinPE"
set "DRIVER_INF_COUNT=0"
set "THIRD_PARTY_DRIVER_COUNT=0"

REM ADK Deployment Tools path
set "ADKTOOLS=%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools"

REM Windows PE Add-on path
set "WINPEROOT=%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"

REM ADK environment initialization script
set "ADK_ENV=%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\DandISetEnv.bat"

REM --------------------------------------------------
REM Prepare output directory
REM --------------------------------------------------

if not exist "%ISO_OUTPUT_DIRECTORY%\" (
    mkdir "%ISO_OUTPUT_DIRECTORY%" >nul 2>&1
)

if not exist "%ISO_OUTPUT_DIRECTORY%\" (
    echo ERROR: Failed to create the ISO output directory:
    echo   %ISO_OUTPUT_DIRECTORY%
    goto FAILED
)

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

REM --------------------------------------------------
REM Read lazyBackup version for image metadata
REM --------------------------------------------------
REM
REM Expected source line:
REM
REM set "SCRIPT_VERSION=0.8.8"
REM --------------------------------------------------

set "LAZYBACKUP_VERSION="

for /F "usebackq tokens=1,* delims==" %%A in ("%SOURCE_SCRIPT%") do (
    set "VERSION_KEY=%%A"

    REM Remove quotation marks and spaces from the key.
    set "VERSION_KEY=!VERSION_KEY:"=!"
    set "VERSION_KEY=!VERSION_KEY: =!"

    if /I "!VERSION_KEY!"=="setSCRIPT_VERSION" (
        if not defined LAZYBACKUP_VERSION (
            set "LAZYBACKUP_VERSION=%%B"
        )
    )
)

REM Remove quotation marks and spaces from the value.

if defined LAZYBACKUP_VERSION (
    set "LAZYBACKUP_VERSION=!LAZYBACKUP_VERSION:"=!"
    set "LAZYBACKUP_VERSION=!LAZYBACKUP_VERSION: =!"
)

REM --------------------------------------------------
REM Validate the detected version.
REM
REM Only numbers, dots and hyphens are accepted.
REM --------------------------------------------------

set "LAZYBACKUP_VERSION_INVALID="

if defined LAZYBACKUP_VERSION (
    for /F "delims=0123456789.-" %%V in ("!LAZYBACKUP_VERSION!") do (
        set "LAZYBACKUP_VERSION_INVALID=%%V"
    )
)

if defined LAZYBACKUP_VERSION_INVALID (
    echo WARNING: The detected lazyBackup version is invalid:
    echo   !LAZYBACKUP_VERSION!
    echo.

    set "LAZYBACKUP_VERSION="
    set "LAZYBACKUP_VERSION_INVALID="
)

REM --------------------------------------------------
REM Generate WIM name and ISO volume label.
REM --------------------------------------------------

if defined LAZYBACKUP_VERSION (
    set "WIM_IMAGE_NAME=lazyBackup WinPE v!LAZYBACKUP_VERSION!"

    set "ISO_VERSION=!LAZYBACKUP_VERSION:.=_!"
    set "ISO_VERSION=!ISO_VERSION:-=_!"

    set "ISO_LABEL=LAZYBACKUP_WINPE_!ISO_VERSION!"
) else (
    set "WIM_IMAGE_NAME=lazyBackup WinPE"
    set "ISO_LABEL=LAZYBACKUP_WINPE"
)

echo Detected lazyBackup version:

if defined LAZYBACKUP_VERSION (
    echo   !LAZYBACKUP_VERSION!
) else (
    echo   Unknown
)

echo WinPE image name:
echo   !WIM_IMAGE_NAME!

echo ISO volume label:
echo   !ISO_LABEL!
echo.

if not exist "%SOURCE_STARTNET%" (
    echo ERROR: startnet.cmd was not found:
    echo %SOURCE_STARTNET%
    goto FAILED
)

REM --------------------------------------------------
REM Verify choice.exe
REM
REM Prefer the portable copy under Builder files.
REM Fall back to Windows System32.
REM --------------------------------------------------

if not exist "%LOCAL_CHOICE%" (
    if not exist "%SystemRoot%\System32\choice.exe" (
        echo ERROR: choice.exe was not found.
        echo.
        echo Checked:
        echo   %LOCAL_CHOICE%
        echo   %SystemRoot%\System32\choice.exe
        goto FAILED
    )
)

REM --------------------------------------------------
REM Verify findstr.exe
REM
REM Prefer the portable copy under Builder files.
REM Fall back to Windows System32.
REM --------------------------------------------------

if not exist "%LOCAL_FINDSTR%" (
    if not exist "%SystemRoot%\System32\findstr.exe" (
        echo ERROR: findstr.exe was not found.
        echo.
        echo Checked:
        echo   %LOCAL_FINDSTR%
        echo   %SystemRoot%\System32\findstr.exe
        goto FAILED
    )
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
REM Add optional WinPE drivers recursively
REM --------------------------------------------------
REM All signed driver packages below ISO builder\Drivers
REM are added recursively to the mounted WinPE image.
REM Missing or empty means no additional drivers.
REM --------------------------------------------------
set "DRIVER_INF_COUNT=0"
if exist "%DRIVER_ROOT%\" (
    for /R "%DRIVER_ROOT%" %%F in (*.inf) do set /a DRIVER_INF_COUNT+=1
)
if "!DRIVER_INF_COUNT!"=="0" (
    echo No optional WinPE driver packages were found.
    echo Checked: %DRIVER_ROOT%
    echo.
) else (
    echo Adding optional WinPE drivers recursively...
    echo Driver directory: %DRIVER_ROOT%
    echo INF files found: !DRIVER_INF_COUNT!
    echo.
    Dism /English /Image:"%MOUNTDIR%" /Add-Driver /Driver:"%DRIVER_ROOT%" /Recurse
    if errorlevel 1 (
        echo ERROR: Failed to add one or more WinPE drivers.
        goto DISCARD_IMAGE
    )
    echo.
    echo Verifying the driver store in the mounted image...
    Dism /English /Image:"%MOUNTDIR%" /Get-Drivers /Format:Table >nul
    if errorlevel 1 (
        echo ERROR: DISM could not read back the WinPE driver store.
        goto DISCARD_IMAGE
    )
    echo Optional WinPE drivers added successfully.
    echo.
)

REM --------------------------------------------------
REM Add choice.exe
REM --------------------------------------------------

echo Copying choice.exe...

if exist "%LOCAL_CHOICE%" (
    echo Using portable builder copy:
    echo   %LOCAL_CHOICE%

    copy /y "%LOCAL_CHOICE%" "%MOUNTDIR%\Windows\System32\choice.exe" >nul
) else (
    echo Using Windows System32 copy:
    echo   %SystemRoot%\System32\choice.exe

    copy /y "%SystemRoot%\System32\choice.exe" "%MOUNTDIR%\Windows\System32\choice.exe" >nul
)

if errorlevel 1 (
    echo ERROR: Failed to copy choice.exe.
    goto DISCARD_IMAGE
)

REM --------------------------------------------------
REM Add findstr.exe
REM --------------------------------------------------

echo Copying findstr.exe...

if exist "%LOCAL_FINDSTR%" (
    echo Using portable builder copy:
    echo   %LOCAL_FINDSTR%

    copy /y "%LOCAL_FINDSTR%" "%MOUNTDIR%\Windows\System32\findstr.exe" >nul
) else (
    echo Using Windows System32 copy:
    echo   %SystemRoot%\System32\findstr.exe

    copy /y "%SystemRoot%\System32\findstr.exe" "%MOUNTDIR%\Windows\System32\findstr.exe" >nul
)

if errorlevel 1 (
    echo ERROR: Failed to copy findstr.exe.
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
REM
REM The original examples remain in:
REM
REM   PROJECT_ROOT\marker files examples
REM
REM Copies are added to the WinPE image for reference.
REM --------------------------------------------------

if exist "%SOURCE_MARKERS%\" (
    echo Copying marker-file examples...
    echo Source:
    echo   %SOURCE_MARKERS%
    echo.

    if not exist "%MOUNTDIR%\lazyBackup\marker files examples" (
        mkdir "%MOUNTDIR%\lazyBackup\marker files examples"
    )

    xcopy "%SOURCE_MARKERS%\*" ^
          "%MOUNTDIR%\lazyBackup\marker files examples\" ^
          /E /I /H /Y >nul

    if errorlevel 1 (
        echo WARNING: Marker-file examples could not be copied.
    ) else (
        echo Marker-file examples copied successfully.
    )

    echo.
) else (
    echo WARNING: Marker-file example directory was not found:
    echo   %SOURCE_MARKERS%
    echo.
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
REM Set WinPE WIM image name and optimize boot.wim
REM --------------------------------------------------

set "ORIGINAL_BOOT_WIM=%MEDIA%\sources\boot.wim"
set "RENAMED_BOOT_WIM=%MEDIA%\sources\boot-renamed.wim"

if exist "!RENAMED_BOOT_WIM!" (
    del /f /q "!RENAMED_BOOT_WIM!"
)

echo Setting WinPE image name:
echo   !WIM_IMAGE_NAME!
echo.

echo Exporting and optimizing boot.wim...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop'; " ^
    "Export-WindowsImage " ^
    "-SourceImagePath $env:ORIGINAL_BOOT_WIM " ^
    "-SourceIndex 1 " ^
    "-DestinationImagePath $env:RENAMED_BOOT_WIM " ^
    "-DestinationName $env:WIM_IMAGE_NAME " ^
    "-CompressionType Max " ^
    "-CheckIntegrity " ^
    "-Setbootable | Out-Null"

if errorlevel 1 (
    echo ERROR: Failed to export and rename boot.wim.
    goto FAILED
)

if not exist "!RENAMED_BOOT_WIM!" (
    echo ERROR: The renamed boot.wim was not created.
    goto FAILED
)

for %%F in ("!RENAMED_BOOT_WIM!") do (
    if %%~zF LEQ 0 (
        echo ERROR: The renamed boot.wim is empty.
        goto FAILED
    )
)

echo Validating the exported boot.wim...
echo.

Dism /English /Get-WimInfo ^
 /WimFile:"!RENAMED_BOOT_WIM!" ^
 /Index:1 >nul

if errorlevel 1 (
    echo ERROR: The exported boot.wim could not be validated.
    goto FAILED
)

del /f /q "!ORIGINAL_BOOT_WIM!"

if errorlevel 1 (
    echo ERROR: Failed to remove the original boot.wim.
    goto FAILED
)

move /y "!RENAMED_BOOT_WIM!" "!ORIGINAL_BOOT_WIM!" >nul

if errorlevel 1 (
    echo ERROR: Failed to activate the renamed boot.wim.
    goto FAILED
)

echo WinPE image name updated successfully.
echo.

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

oscdimg -m -o -u2 -udfver102 -l"!ISO_LABEL!" -bootdata:2#p0,e,b"!BIOS_BOOT!"#pEF,e,b"!UEFI_BOOT!" "!MEDIA!" "!OUTPUT_ISO!"

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
echo   %OUTPUT_ISO%
echo.

echo ISO volume label:
echo   !ISO_LABEL!
echo.

echo WinPE image name:
echo   !WIM_IMAGE_NAME!
echo.
echo Optional WinPE driver INF files found:
echo   !DRIVER_INF_COUNT!
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

popd
exit /b 1

:END

popd
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

popd
exit /b 1