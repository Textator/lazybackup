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
REM Windows 11 + lazyBackup Combined ISO Builder
REM
REM Creates one BIOS/UEFI bootable ISO with this menu:
REM   Windows 11 Setup
REM   lazyBackup Recovery
REM
REM Run as Administrator.
REM Windows ADK Deployment Tools are required.
REM ==================================================

REM --------------------------------------------------
REM Configuration - edit these values when required
REM --------------------------------------------------

REM ==================================================
REM Portable project paths
REM ==================================================

for %%I in ("%~dp0.") do set "SCRIPT_DIR=%%~fI"
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"

set "WINDOWS_ISO_DIRECTORY=%PROJECT_ROOT%\Windows ISO here"
set "ISO_OUTPUT_DIRECTORY=%PROJECT_ROOT%\ISO output"


REM ==================================================
REM Optional absolute path overrides
REM ==================================================
REM
REM Leave empty to use the portable project paths.
REM
REM CONFIG_WINDOWS11_ISO may point directly to a
REM specific Windows ISO. When empty, the builder
REM expects exactly one ISO in Windows ISO here.
REM ==================================================

set "CONFIG_WINDOWS11_ISO="
set "CONFIG_LAZYBACKUP_ISO="
set "CONFIG_WORKDIR="
set "CONFIG_OUTPUT_ISO="


REM ==================================================
REM Resolve effective paths
REM ==================================================

set "WINDOWS11_ISO="

if defined CONFIG_WINDOWS11_ISO (
    set "WINDOWS11_ISO=%CONFIG_WINDOWS11_ISO%"
)

if defined CONFIG_LAZYBACKUP_ISO (
    set "LAZYBACKUP_ISO=%CONFIG_LAZYBACKUP_ISO%"
) else (
    set "LAZYBACKUP_ISO=%ISO_OUTPUT_DIRECTORY%\lazyBackup_WinPE.iso"
)

if defined CONFIG_WORKDIR (
    set "WORKDIR=%CONFIG_WORKDIR%"
) else (
    set "WORKDIR=%TEMP%\lazyBackup_Build\Combined ISO"
)

if defined CONFIG_OUTPUT_ISO (
    set "OUTPUT_ISO=%CONFIG_OUTPUT_ISO%"
) else (
    REM The output filename will be generated after
    REM the Windows source ISO has been resolved.
    set "OUTPUT_ISO="
)

set "MEDIA=%WORKDIR%\Media"

REM ISO and boot-menu settings
REM
REM These fallback values are used only when source
REM metadata cannot be determined.

set "ISO_LABEL=W11_LAZY"
set "WINDOWS_SETUP_DESCRIPTION=Windows 11 Setup lazy"
set "LAZYBACKUP_DESCRIPTION=lazyBackup Recovery"
set "BOOT_MENU_TIMEOUT=15"

REM Source and generated metadata
set "WINDOWS_SOURCE_LABEL="
set "WINDOWS_SOURCE_NAME="
set "GENERATED_OUTPUT_NAME="

REM Paths inside the combined ISO
set "LAZYBACKUP_WIM_PATH=\sources\lazyBackup.wim"
set "LAZYBACKUP_SDI_PATH=\boot\lazyBackup.sdi"

REM Windows ADK Deployment Tools
set "OSCDIMG_EXE=C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"

REM --------------------------------------------------
REM Runtime variables - do not edit
REM --------------------------------------------------

set "WINDOWS_ISO_DRIVE="
set "LAZY_ISO_DRIVE="
set "ISO_TO_MOUNT="
set "ISO_TO_DISMOUNT="

set "BIOS_BCD=%MEDIA%\boot\bcd"
set "UEFI_BCD=%MEDIA%\efi\microsoft\boot\bcd"
set "BIOS_BOOT_IMAGE=%MEDIA%\boot\etfsboot.com"
set "UEFI_BOOT_IMAGE="

set "BIOS_LOADER_GUID="
set "BIOS_RAMDISK_GUID="
set "UEFI_LOADER_GUID="
set "UEFI_RAMDISK_GUID="

REM --------------------------------------------------
REM Header
REM --------------------------------------------------

cls
echo.
echo ==================================================
echo   Windows 11 and lazyBackup Combined ISO Builder
echo ==================================================
echo.
echo Windows ISO input directory:
echo   %WINDOWS_ISO_DIRECTORY%
echo.

if defined WINDOWS11_ISO (
    echo Configured Windows 11 source ISO:
    echo   %WINDOWS11_ISO%
) else (
    echo Windows 11 source ISO:
    echo   Will be detected automatically during validation.
)

echo.
echo.
echo lazyBackup WinPE source ISO:
echo   %LAZYBACKUP_ISO%
echo.
echo Temporary working directory:
echo   %WORKDIR%
echo.
echo Output ISO:
if defined CONFIG_OUTPUT_ISO (
    echo   %CONFIG_OUTPUT_ISO%
) else (
    echo   Will be generated from the Windows ISO name.
)

echo.
echo ISO volume label:
echo   Will be generated from the Windows ISO label.
echo.
echo Generated values will end in lazy or LAZY.
echo.
echo.
echo Boot menu timeout:
echo   %BOOT_MENU_TIMEOUT% seconds
echo.

REM --------------------------------------------------
REM Main build process
REM --------------------------------------------------

call :REQUIRE_ADMIN
if errorlevel 1 goto FAILED

call :REQUIRE_TOOLS
if errorlevel 1 goto FAILED

call :RESOLVE_WINDOWS11_ISO
if errorlevel 1 goto FAILED

call :BUILD_WINDOWS_ISO_METADATA
if errorlevel 1 (
    echo WARNING: Windows source metadata could not be
    echo fully determined.
    echo.
    echo Using fallback values where required.
    echo.
)

call :VERIFY_INPUTS
if errorlevel 1 goto FAILED

call :PREPARE_WORKDIR
if errorlevel 1 goto FAILED

call :MOUNT_SOURCE_ISOS
if errorlevel 1 goto FAILED

call :COPY_WINDOWS_MEDIA
if errorlevel 1 goto FAILED

call :ADD_LAZYBACKUP_FILES
if errorlevel 1 goto FAILED

call :DISMOUNT_SOURCE_ISOS

call :PREPARE_BCD_STORES
if errorlevel 1 goto FAILED

call :ADD_BIOS_BCD_ENTRY
if errorlevel 1 goto FAILED

call :ADD_UEFI_BCD_ENTRY
if errorlevel 1 goto FAILED

call :VERIFY_BCD_STORES
if errorlevel 1 goto FAILED

call :SELECT_BOOT_IMAGES
if errorlevel 1 goto FAILED

call :CREATE_COMBINED_ISO
if errorlevel 1 goto FAILED

call :VERIFY_OUTPUT
if errorlevel 1 goto FAILED

echo.
echo ==================================================
echo                    SUCCESS
echo ==================================================
echo.
echo Combined ISO created:
echo   %OUTPUT_ISO%
echo.
echo ISO volume label:
echo   %ISO_LABEL%
echo.
echo ISO boot menu entries:
echo   !WINDOWS_SETUP_DESCRIPTION!
echo   !LAZYBACKUP_DESCRIPTION!
echo.
echo Supported boot modes:
echo   Legacy BIOS
echo   UEFI
echo.
echo Test both menu entries in a new VM before using
echo the combined ISO on physical hardware.
echo.
pause
popd
exit /b 0

REM ==================================================
REM Checks
REM ==================================================

:REQUIRE_ADMIN
net session >nul 2>&1
if errorlevel 1 (
    echo ERROR: Administrator privileges are required.
    echo Run this builder as Administrator.
    exit /b 1
)
exit /b 0

:REQUIRE_TOOLS

where powershell.exe >nul 2>&1
if errorlevel 1 goto POWERSHELL_NOT_FOUND

where bcdedit.exe >nul 2>&1
if errorlevel 1 goto BCDEDIT_NOT_FOUND

where robocopy.exe >nul 2>&1
if errorlevel 1 goto ROBOCOPY_NOT_FOUND

where dism.exe >nul 2>&1
if errorlevel 1 goto DISM_NOT_FOUND

REM --------------------------------------------------
REM Do not expand a "Program Files (x86)" path inside
REM a parenthesized CMD block.
REM --------------------------------------------------

if not defined OSCDIMG_EXE goto OSCDIMG_VARIABLE_EMPTY

if not exist "!OSCDIMG_EXE!" goto OSCDIMG_NOT_FOUND

echo Required Windows tools found.
echo.
echo Oscdimg:
echo   !OSCDIMG_EXE!
echo.

exit /b 0


:POWERSHELL_NOT_FOUND

echo ERROR: Windows PowerShell was not found.
exit /b 1


:BCDEDIT_NOT_FOUND

echo ERROR: bcdedit.exe was not found.
exit /b 1


:ROBOCOPY_NOT_FOUND

echo ERROR: robocopy.exe was not found.
exit /b 1


:DISM_NOT_FOUND

echo ERROR: dism.exe was not found.
exit /b 1


:OSCDIMG_VARIABLE_EMPTY

echo ERROR: The OSCDIMG_EXE variable is empty.
echo.

exit /b 1


:OSCDIMG_NOT_FOUND

echo ERROR: oscdimg.exe was not found.
echo.
echo Expected:
echo   !OSCDIMG_EXE!
echo.
echo Install the Windows ADK Deployment Tools.
echo.

exit /b 1


:VERIFY_INPUTS

if not exist "%ISO_OUTPUT_DIRECTORY%\" (
    mkdir "%ISO_OUTPUT_DIRECTORY%" >nul 2>&1
)

if not exist "%ISO_OUTPUT_DIRECTORY%\" (
    echo ERROR: Failed to create the ISO output directory:
    echo   %ISO_OUTPUT_DIRECTORY%
    exit /b 1
)

if not exist "%WINDOWS11_ISO%" (
    echo ERROR: Windows 11 source ISO was not found:
    echo   %WINDOWS11_ISO%
    exit /b 1
)

if not exist "%LAZYBACKUP_ISO%" (
    echo ERROR: lazyBackup WinPE ISO was not found:
    echo   %LAZYBACKUP_ISO%
    exit /b 1
)

if /I "%WINDOWS11_ISO%"=="%OUTPUT_ISO%" (
    echo ERROR: Source and output ISO paths must be different.
    exit /b 1
)
exit /b 0

REM ==================================================
REM Resolve Windows source ISO
REM ==================================================

:RESOLVE_WINDOWS11_ISO

REM --------------------------------------------------
REM An explicitly configured path has priority.
REM --------------------------------------------------

if defined WINDOWS11_ISO (
    if exist "%WINDOWS11_ISO%" (
        echo Using configured Windows ISO:
        echo   %WINDOWS11_ISO%
        echo.

        exit /b 0
    )

    echo ERROR: The configured Windows ISO was not found:
    echo   %WINDOWS11_ISO%
    echo.

    exit /b 1
)

REM --------------------------------------------------
REM Create the portable Windows ISO input directory
REM when it does not exist.
REM --------------------------------------------------

if not exist "%WINDOWS_ISO_DIRECTORY%\" (
    echo Creating Windows ISO input directory:
    echo   %WINDOWS_ISO_DIRECTORY%
    echo.

    mkdir "%WINDOWS_ISO_DIRECTORY%" >nul 2>&1

    if not exist "%WINDOWS_ISO_DIRECTORY%\" (
        echo ERROR: Failed to create the Windows ISO input directory.
        echo.

        exit /b 1
    )
)

REM --------------------------------------------------
REM Find exactly one ISO in the input directory.
REM --------------------------------------------------

set "WINDOWS_ISO_COUNT=0"
set "WINDOWS11_ISO="

for %%F in ("%WINDOWS_ISO_DIRECTORY%\*.iso") do (
    if exist "%%~fF" (
        set /a WINDOWS_ISO_COUNT+=1
        set "WINDOWS11_ISO=%%~fF"
    )
)

if "%WINDOWS_ISO_COUNT%"=="0" (
    echo ERROR: No Windows ISO was found.
    echo.
    echo Place exactly one Windows ISO in:
    echo   %WINDOWS_ISO_DIRECTORY%
    echo.

    exit /b 1
)

if not "%WINDOWS_ISO_COUNT%"=="1" (
    echo ERROR: More than one Windows ISO was found.
    echo.
    echo Keep exactly one ISO in:
    echo   %WINDOWS_ISO_DIRECTORY%
    echo.
    echo Found files:

    for %%F in ("%WINDOWS_ISO_DIRECTORY%\*.iso") do (
        if exist "%%~fF" (
            echo   %%~nxF
        )
    )

    echo.
    echo Alternatively, configure CONFIG_WINDOWS11_ISO
    echo with the complete path to the desired ISO.
    echo.

    exit /b 1
)

echo Automatically selected Windows ISO:
echo   %WINDOWS11_ISO%
echo.

exit /b 0

REM ==================================================
REM Build Windows and combined ISO metadata
REM ==================================================
REM
REM The generated ISO label, output filename and
REM Windows Setup boot-menu description are based on
REM the source Windows ISO.
REM
REM All generated values end in LAZY or lazy.
REM
REM ISO volume label:
REM   Maximum generated length: 32 characters
REM   Reserved suffix:          _LAZY
REM   Maximum source part:      27 characters
REM ==================================================

:BUILD_WINDOWS_ISO_METADATA

set "WINDOWS_SOURCE_LABEL="
set "WINDOWS_SOURCE_NAME="
set "METADATA_SOURCE="
set "GENERATED_ISO_BASE="
set "GENERATED_DESCRIPTION_BASE="
set "GENERATED_OUTPUT_NAME="
set "METADATA_LABEL_FILE=%TEMP%\lazyBackup_source_label_%RANDOM%_%RANDOM%.txt"

REM --------------------------------------------------
REM Obtain the source ISO filename without extension.
REM --------------------------------------------------

for %%F in ("%WINDOWS11_ISO%") do (
    set "WINDOWS_SOURCE_NAME=%%~nF"
)

REM --------------------------------------------------
REM Mount the Windows ISO temporarily.
REM --------------------------------------------------

set "ISO_TO_MOUNT=%WINDOWS11_ISO%"

call :MOUNT_ISO METADATA_ISO_DRIVE

if errorlevel 1 (
    echo WARNING: The Windows ISO could not be mounted
    echo for reading its volume label.
    echo.
) else (
    REM ------------------------------------------------
    REM Read the source volume label into a temporary
    REM file without a PowerShell pipeline.
    REM ------------------------------------------------

    if exist "%METADATA_LABEL_FILE%" (
        del /f /q "%METADATA_LABEL_FILE%" >nul 2>&1
    )

    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
        "$drive = $env:METADATA_ISO_DRIVE.TrimEnd(':'); " ^
        "$volume = Get-Volume -DriveLetter $drive -ErrorAction SilentlyContinue; " ^
        "if (($null -ne $volume) -and ($null -ne $volume.FileSystemLabel)) { " ^
        "    Set-Content -LiteralPath $env:METADATA_LABEL_FILE -Value $volume.FileSystemLabel -Encoding ASCII " ^
        "}"

    if exist "%METADATA_LABEL_FILE%" (
        set /P "WINDOWS_SOURCE_LABEL="<"%METADATA_LABEL_FILE%"
        del /f /q "%METADATA_LABEL_FILE%" >nul 2>&1
    )

    set "ISO_TO_DISMOUNT=%WINDOWS11_ISO%"
    call :DISMOUNT_ISO
)

REM --------------------------------------------------
REM Prefer the source volume label.
REM Fall back to the ISO filename.
REM --------------------------------------------------

if defined WINDOWS_SOURCE_LABEL (
    set "METADATA_SOURCE=!WINDOWS_SOURCE_LABEL!"
) else (
    set "METADATA_SOURCE=!WINDOWS_SOURCE_NAME!"
)

if not defined METADATA_SOURCE (
    set "METADATA_SOURCE=W11"
)

REM --------------------------------------------------
REM Generate the ISO volume label.
REM
REM Only basic CMD substitutions are used here.
REM The final enforcement is performed again directly
REM before Oscdimg is called.
REM --------------------------------------------------

set "GENERATED_ISO_BASE=!METADATA_SOURCE!"

set "GENERATED_ISO_BASE=!GENERATED_ISO_BASE: =_!"
set "GENERATED_ISO_BASE=!GENERATED_ISO_BASE:-=_!"
set "GENERATED_ISO_BASE=!GENERATED_ISO_BASE:.=_!"

REM Reserve five characters for _LAZY.

set "GENERATED_ISO_BASE=!GENERATED_ISO_BASE:~0,27!"

if not defined GENERATED_ISO_BASE (
    set "GENERATED_ISO_BASE=W11"
)

set "ISO_LABEL=!GENERATED_ISO_BASE!_LAZY"

REM --------------------------------------------------
REM Generate the Windows Setup boot-menu description.
REM
REM The description is limited to 43 characters before
REM the suffix " lazy" is appended.
REM --------------------------------------------------

set "GENERATED_DESCRIPTION_BASE=!METADATA_SOURCE!"
set "GENERATED_DESCRIPTION_BASE=!GENERATED_DESCRIPTION_BASE:_= !"
set "GENERATED_DESCRIPTION_BASE=!GENERATED_DESCRIPTION_BASE:~0,43!"

if not defined GENERATED_DESCRIPTION_BASE (
    set "GENERATED_DESCRIPTION_BASE=Windows 11 Setup"
)

set "WINDOWS_SETUP_DESCRIPTION=!GENERATED_DESCRIPTION_BASE! lazy"

REM --------------------------------------------------
REM Generate the output filename.
REM
REM The source name already originates from a valid
REM Windows filename.
REM --------------------------------------------------

if defined CONFIG_OUTPUT_ISO (
    set "OUTPUT_ISO=%CONFIG_OUTPUT_ISO%"
) else (
    set "GENERATED_OUTPUT_NAME=!WINDOWS_SOURCE_NAME:~0,100!"

    if not defined GENERATED_OUTPUT_NAME (
        set "GENERATED_OUTPUT_NAME=Windows11"
    )

    set "OUTPUT_ISO=%ISO_OUTPUT_DIRECTORY%\!GENERATED_OUTPUT_NAME!_lazy.iso"
)

echo.
echo ==========================================
echo       Generated ISO Metadata
echo ==========================================
echo.

echo Windows source ISO:
echo   !WINDOWS11_ISO!
echo.

echo Source volume label:

if defined WINDOWS_SOURCE_LABEL (
    echo   !WINDOWS_SOURCE_LABEL!
) else (
    echo   Not available
)

echo.
echo Source ISO name:
echo   !WINDOWS_SOURCE_NAME!
echo.

echo Combined ISO volume label:
echo   !ISO_LABEL!
echo.

echo Combined ISO filename:
echo   !OUTPUT_ISO!
echo.

echo Windows boot-menu description:
echo   !WINDOWS_SETUP_DESCRIPTION!
echo.

echo lazyBackup boot-menu description:
echo   !LAZYBACKUP_DESCRIPTION!
echo.

exit /b 0

REM ==================================================
REM Prepare and mount source media
REM ==================================================

:PREPARE_WORKDIR
echo Preparing build directory...

if exist "%WORKDIR%" rmdir /s /q "%WORKDIR%"

if exist "%WORKDIR%" (
    echo ERROR: Failed to remove the previous work directory:
    echo   %WORKDIR%
    exit /b 1
)

mkdir "%MEDIA%" >nul 2>&1

if not exist "%MEDIA%" (
    echo ERROR: Failed to create:
    echo   %MEDIA%
    exit /b 1
)
exit /b 0

:MOUNT_SOURCE_ISOS
echo Mounting Windows 11 source ISO...
set "ISO_TO_MOUNT=%WINDOWS11_ISO%"
call :MOUNT_ISO WINDOWS_ISO_DRIVE
if errorlevel 1 exit /b 1

echo Windows 11 ISO mounted as:
echo   !WINDOWS_ISO_DRIVE!
echo.

echo Mounting lazyBackup WinPE ISO...
set "ISO_TO_MOUNT=%LAZYBACKUP_ISO%"
call :MOUNT_ISO LAZY_ISO_DRIVE
if errorlevel 1 exit /b 1

echo lazyBackup ISO mounted as:
echo   !LAZY_ISO_DRIVE!
echo.
exit /b 0

:MOUNT_ISO

set "MOUNT_RESULT="
set "MOUNT_RESULT_FILE=%TEMP%\lazyBackup_mount_result_%RANDOM%_%RANDOM%.txt"

if exist "%MOUNT_RESULT_FILE%" (
    del /f /q "%MOUNT_RESULT_FILE%" >nul 2>&1
)

REM --------------------------------------------------
REM Mount the requested ISO and write the mounted
REM volume drive letter to a temporary result file.
REM
REM PowerShell handles the pipeline inside one quoted
REM command. CMD does not parse the pipeline itself.
REM --------------------------------------------------

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop'; " ^
    "$path = $env:ISO_TO_MOUNT; " ^
    "$image = Get-DiskImage -ImagePath $path -ErrorAction SilentlyContinue; " ^
    "if (($null -eq $image) -or (-not $image.Attached)) { " ^
    "    [void](Mount-DiskImage -ImagePath $path -ErrorAction Stop); " ^
    "}; " ^
    "$volume = Get-DiskImage -ImagePath $path -ErrorAction Stop | Get-Volume | Where-Object { $_.DriveLetter } | Select-Object -First 1; " ^
    "if ($null -eq $volume) { " ^
    "    throw 'The mounted ISO has no accessible drive letter.'; " ^
    "}; " ^
    "Set-Content -LiteralPath $env:MOUNT_RESULT_FILE -Value ($volume.DriveLetter + ':') -Encoding ASCII"

set "MOUNT_RESULT_CODE=%errorlevel%"

if not "%MOUNT_RESULT_CODE%"=="0" (
    echo ERROR: Failed to mount the ISO or determine its drive letter:
    echo   %ISO_TO_MOUNT%
    echo.

    if exist "%MOUNT_RESULT_FILE%" (
        del /f /q "%MOUNT_RESULT_FILE%" >nul 2>&1
    )

    set "ISO_TO_DISMOUNT=%ISO_TO_MOUNT%"
    call :DISMOUNT_ISO

    exit /b 1
)

if not exist "%MOUNT_RESULT_FILE%" (
    echo ERROR: The ISO mount result file was not created:
    echo   %MOUNT_RESULT_FILE%
    echo.

    set "ISO_TO_DISMOUNT=%ISO_TO_MOUNT%"
    call :DISMOUNT_ISO

    exit /b 1
)

set /P "MOUNT_RESULT="<"%MOUNT_RESULT_FILE%"

del /f /q "%MOUNT_RESULT_FILE%" >nul 2>&1

if not defined MOUNT_RESULT (
    echo ERROR: The ISO was mounted, but no drive letter was returned:
    echo   %ISO_TO_MOUNT%
    echo.

    set "ISO_TO_DISMOUNT=%ISO_TO_MOUNT%"
    call :DISMOUNT_ISO

    exit /b 1
)

if not exist "!MOUNT_RESULT!\" (
    echo ERROR: The detected ISO drive is inaccessible:
    echo   !MOUNT_RESULT!
    echo.

    set "ISO_TO_DISMOUNT=%ISO_TO_MOUNT%"
    call :DISMOUNT_ISO

    exit /b 1
)

echo Mounted ISO drive:
echo   !MOUNT_RESULT!
echo.

set "%~1=!MOUNT_RESULT!"

exit /b 0


:COPY_WINDOWS_MEDIA

echo Copying Windows 11 installation media...
echo.

REM --------------------------------------------------
REM Use "\." for the root of the mounted ISO.
REM This avoids a trailing backslash directly before
REM the closing quotation mark in the Robocopy source.
REM --------------------------------------------------

set "WINDOWS_COPY_SOURCE=!WINDOWS_ISO_DRIVE!\."
set "WINDOWS_COPY_TARGET=%MEDIA%"

echo Robocopy source:
echo   !WINDOWS_COPY_SOURCE!
echo.

echo Robocopy destination:
echo   !WINDOWS_COPY_TARGET!
echo.

robocopy "!WINDOWS_COPY_SOURCE!" "!WINDOWS_COPY_TARGET!" /E /COPY:DAT /DCOPY:T /R:2 /W:2

set "ROBOCOPY_RESULT=!errorlevel!"

if !ROBOCOPY_RESULT! GEQ 8 (
    echo ERROR: Robocopy failed with exit code !ROBOCOPY_RESULT!.
    exit /b 1
)

REM --------------------------------------------------
REM Verify important Windows Setup files
REM --------------------------------------------------

if not exist "%MEDIA%\sources\boot.wim" (
    echo ERROR: Windows Setup boot.wim was not copied.
    echo.
    echo Expected:
    echo   %MEDIA%\sources\boot.wim
    echo.
    exit /b 1
)

if not exist "%MEDIA%\boot\bcd" (
    echo ERROR: Windows Setup BIOS BCD was not copied.
    echo.
    echo Expected:
    echo   %MEDIA%\boot\bcd
    echo.
    exit /b 1
)

if not exist "%MEDIA%\efi\microsoft\boot\bcd" (
    echo ERROR: Windows Setup UEFI BCD was not copied.
    echo.
    echo Expected:
    echo   %MEDIA%\efi\microsoft\boot\bcd
    echo.
    exit /b 1
)

if not exist "%MEDIA%\boot\etfsboot.com" (
    echo ERROR: The BIOS ISO boot image was not copied.
    echo.
    echo Expected:
    echo   %MEDIA%\boot\etfsboot.com
    echo.
    exit /b 1
)

echo Windows 11 installation media copied successfully.
echo.

exit /b 0


:ADD_LAZYBACKUP_FILES
if not exist "!LAZY_ISO_DRIVE!\sources\boot.wim" (
    echo ERROR: lazyBackup boot.wim was not found:
    echo   !LAZY_ISO_DRIVE!\sources\boot.wim
    exit /b 1
)

if not exist "!LAZY_ISO_DRIVE!\boot\boot.sdi" (
    echo ERROR: lazyBackup boot.sdi was not found:
    echo   !LAZY_ISO_DRIVE!\boot\boot.sdi
    exit /b 1
)

echo Adding lazyBackup WinPE image...
copy /y "!LAZY_ISO_DRIVE!\sources\boot.wim" "%MEDIA%\sources\lazyBackup.wim" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy lazyBackup.wim.
    exit /b 1
)

echo Adding lazyBackup ramdisk SDI...
copy /y "!LAZY_ISO_DRIVE!\boot\boot.sdi" "%MEDIA%\boot\lazyBackup.sdi" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy lazyBackup.sdi.
    exit /b 1
)

echo Validating copied lazyBackup WIM...
dism /English /Get-WimInfo /WimFile:"%MEDIA%\sources\lazyBackup.wim" >nul
if errorlevel 1 (
    echo ERROR: DISM could not validate lazyBackup.wim.
    exit /b 1
)

echo lazyBackup boot files added successfully.
echo.
exit /b 0

:DISMOUNT_SOURCE_ISOS
if defined WINDOWS_ISO_DRIVE (
    set "ISO_TO_DISMOUNT=%WINDOWS11_ISO%"
    call :DISMOUNT_ISO
)

if defined LAZY_ISO_DRIVE (
    set "ISO_TO_DISMOUNT=%LAZYBACKUP_ISO%"
    call :DISMOUNT_ISO
)

set "WINDOWS_ISO_DRIVE="
set "LAZY_ISO_DRIVE="
exit /b 0

:DISMOUNT_ISO

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'SilentlyContinue'; " ^
    "$path = $env:ISO_TO_DISMOUNT; " ^
    "$image = Get-DiskImage -ImagePath $path -ErrorAction SilentlyContinue; " ^
    "if (($null -ne $image) -and $image.Attached) { " ^
    "    Dismount-DiskImage -ImagePath $path -ErrorAction SilentlyContinue; " ^
    "}"

exit /b 0

REM ==================================================
REM Modify BIOS and UEFI BCD stores
REM ==================================================

:PREPARE_BCD_STORES

if not exist "%BIOS_BCD%" (
    echo ERROR: BIOS BCD store was not found:
    echo   %BIOS_BCD%
    exit /b 1
)

if not exist "%UEFI_BCD%" (
    echo ERROR: UEFI BCD store was not found:
    echo   %UEFI_BCD%
    exit /b 1
)

attrib -r -s -h "%BIOS_BCD%" >nul 2>&1
attrib -r -s -h "%UEFI_BCD%" >nul 2>&1

copy /y "%BIOS_BCD%" "%BIOS_BCD%.before-lazyBackup" >nul

if errorlevel 1 (
    echo ERROR: Failed to back up the BIOS BCD store.
    exit /b 1
)

copy /y "%UEFI_BCD%" "%UEFI_BCD%.before-lazyBackup" >nul

if errorlevel 1 (
    echo ERROR: Failed to back up the UEFI BCD store.
    exit /b 1
)

exit /b 0


:ADD_BIOS_BCD_ENTRY
echo Adding lazyBackup to the BIOS BCD store...
call :CREATE_MEDIA_BCD_ENTRY "%BIOS_BCD%" "\Windows\System32\winload.exe" BIOS_LOADER_GUID BIOS_RAMDISK_GUID
if errorlevel 1 (
    echo ERROR: Failed to modify the BIOS BCD store.
    exit /b 1
)

echo BIOS loader GUID:
echo   !BIOS_LOADER_GUID!
echo BIOS ramdisk GUID:
echo   !BIOS_RAMDISK_GUID!
echo.
exit /b 0

:ADD_UEFI_BCD_ENTRY
echo Adding lazyBackup to the UEFI BCD store...
call :CREATE_MEDIA_BCD_ENTRY "%UEFI_BCD%" "\Windows\System32\winload.efi" UEFI_LOADER_GUID UEFI_RAMDISK_GUID
if errorlevel 1 (
    echo ERROR: Failed to modify the UEFI BCD store.
    exit /b 1
)

echo UEFI loader GUID:
echo   !UEFI_LOADER_GUID!
echo UEFI ramdisk GUID:
echo   !UEFI_RAMDISK_GUID!
echo.
exit /b 0

:CREATE_MEDIA_BCD_ENTRY
set "TARGET_BCD=%~1"
set "TARGET_LOADER_PATH=%~2"
set "NEW_LOADER_GUID="
set "NEW_RAMDISK_GUID="

for /F "tokens=2 delims={}" %%G in ('bcdedit /store "%TARGET_BCD%" /create /d "%LAZYBACKUP_DESCRIPTION% Ramdisk" /device') do (
    if not defined NEW_RAMDISK_GUID set "NEW_RAMDISK_GUID={%%G}"
)

if not defined NEW_RAMDISK_GUID (
    echo ERROR: Failed to create ramdisk entry in:
    echo   %TARGET_BCD%
    exit /b 1
)

for /F "tokens=2 delims={}" %%G in ('bcdedit /store "%TARGET_BCD%" /create /d "%LAZYBACKUP_DESCRIPTION%" /application osloader') do (
    if not defined NEW_LOADER_GUID set "NEW_LOADER_GUID={%%G}"
)

if not defined NEW_LOADER_GUID (
    bcdedit /store "%TARGET_BCD%" /delete !NEW_RAMDISK_GUID! /cleanup >nul 2>&1
    echo ERROR: Failed to create loader entry in:
    echo   %TARGET_BCD%
    exit /b 1
)

bcdedit /store "%TARGET_BCD%" /set !NEW_RAMDISK_GUID! ramdisksdidevice boot
if errorlevel 1 goto MEDIA_BCD_ENTRY_FAILED

bcdedit /store "%TARGET_BCD%" /set !NEW_RAMDISK_GUID! ramdisksdipath "%LAZYBACKUP_SDI_PATH%"
if errorlevel 1 goto MEDIA_BCD_ENTRY_FAILED

bcdedit /store "%TARGET_BCD%" /set !NEW_LOADER_GUID! device "ramdisk=[boot]%LAZYBACKUP_WIM_PATH%,!NEW_RAMDISK_GUID!"
if errorlevel 1 goto MEDIA_BCD_ENTRY_FAILED

bcdedit /store "%TARGET_BCD%" /set !NEW_LOADER_GUID! osdevice "ramdisk=[boot]%LAZYBACKUP_WIM_PATH%,!NEW_RAMDISK_GUID!"
if errorlevel 1 goto MEDIA_BCD_ENTRY_FAILED

bcdedit /store "%TARGET_BCD%" /set !NEW_LOADER_GUID! path "%TARGET_LOADER_PATH%"
if errorlevel 1 goto MEDIA_BCD_ENTRY_FAILED

bcdedit /store "%TARGET_BCD%" /set !NEW_LOADER_GUID! systemroot "\Windows"
if errorlevel 1 goto MEDIA_BCD_ENTRY_FAILED

bcdedit /store "%TARGET_BCD%" /set !NEW_LOADER_GUID! winpe yes
if errorlevel 1 goto MEDIA_BCD_ENTRY_FAILED

bcdedit /store "%TARGET_BCD%" /set !NEW_LOADER_GUID! detecthal yes
if errorlevel 1 goto MEDIA_BCD_ENTRY_FAILED

bcdedit /store "%TARGET_BCD%" /set !NEW_LOADER_GUID! nx optin
if errorlevel 1 goto MEDIA_BCD_ENTRY_FAILED

REM --------------------------------------------------
REM Keep Windows Setup as the default ISO boot entry
REM --------------------------------------------------

bcdedit /store "%TARGET_BCD%" /set {default} description "!WINDOWS_SETUP_DESCRIPTION!"
if errorlevel 1 (
    echo ERROR: Failed to name the Windows Setup entry.
    goto MEDIA_BCD_ENTRY_FAILED
)

bcdedit /store "%TARGET_BCD%" /default {default}
if errorlevel 1 (
    echo ERROR: Failed to keep Windows Setup as the default entry.
    goto MEDIA_BCD_ENTRY_FAILED
)

REM --------------------------------------------------
REM Add lazyBackup after Windows Setup
REM --------------------------------------------------

bcdedit /store "%TARGET_BCD%" /displayorder !NEW_LOADER_GUID! /addlast
if errorlevel 1 goto MEDIA_BCD_ENTRY_FAILED

bcdedit /store "%TARGET_BCD%" /set {bootmgr} displaybootmenu yes
if errorlevel 1 goto MEDIA_BCD_ENTRY_FAILED

bcdedit /store "%TARGET_BCD%" /timeout %BOOT_MENU_TIMEOUT%
if errorlevel 1 goto MEDIA_BCD_ENTRY_FAILED

set "%~3=!NEW_LOADER_GUID!"
set "%~4=!NEW_RAMDISK_GUID!"
exit /b 0

:MEDIA_BCD_ENTRY_FAILED
if defined NEW_LOADER_GUID bcdedit /store "%TARGET_BCD%" /delete !NEW_LOADER_GUID! /cleanup >nul 2>&1
if defined NEW_RAMDISK_GUID bcdedit /store "%TARGET_BCD%" /delete !NEW_RAMDISK_GUID! /cleanup >nul 2>&1
exit /b 1

:VERIFY_BCD_STORES
echo Verifying BIOS BCD entries...
bcdedit /store "%BIOS_BCD%" /enum !BIOS_LOADER_GUID! >nul 2>&1
if errorlevel 1 (
    echo ERROR: BIOS lazyBackup loader entry could not be verified.
    exit /b 1
)

bcdedit /store "%BIOS_BCD%" /enum !BIOS_RAMDISK_GUID! >nul 2>&1
if errorlevel 1 (
    echo ERROR: BIOS lazyBackup ramdisk entry could not be verified.
    exit /b 1
)

echo Verifying UEFI BCD entries...
bcdedit /store "%UEFI_BCD%" /enum !UEFI_LOADER_GUID! >nul 2>&1
if errorlevel 1 (
    echo ERROR: UEFI lazyBackup loader entry could not be verified.
    exit /b 1
)

bcdedit /store "%UEFI_BCD%" /enum !UEFI_RAMDISK_GUID! >nul 2>&1
if errorlevel 1 (
    echo ERROR: UEFI lazyBackup ramdisk entry could not be verified.
    exit /b 1
)

echo Both BCD stores were updated and verified.
echo.

REM BCD backup files are build-time safety copies only.
REM Do not include them in the final ISO.

del /q "%BIOS_BCD%.before-lazyBackup" >nul 2>&1
del /q "%UEFI_BCD%.before-lazyBackup" >nul 2>&1

exit /b 0

REM ==================================================
REM Create BIOS + UEFI ISO
REM ==================================================

:SELECT_BOOT_IMAGES
if not exist "%BIOS_BOOT_IMAGE%" (
    echo ERROR: BIOS boot image was not found:
    echo   %BIOS_BOOT_IMAGE%
    exit /b 1
)

if exist "%MEDIA%\efi\microsoft\boot\efisys_noprompt.bin" (
    set "UEFI_BOOT_IMAGE=%MEDIA%\efi\microsoft\boot\efisys_noprompt.bin"
) else if exist "%MEDIA%\efi\microsoft\boot\efisys.bin" (
    set "UEFI_BOOT_IMAGE=%MEDIA%\efi\microsoft\boot\efisys.bin"
) else (
    echo ERROR: Neither efisys_noprompt.bin nor efisys.bin was found.
    exit /b 1
)

echo BIOS boot image:
echo   %BIOS_BOOT_IMAGE%
echo.
echo UEFI boot image:
echo   !UEFI_BOOT_IMAGE!
echo.
exit /b 0

:CREATE_COMBINED_ISO

REM --------------------------------------------------
REM Enforce the Oscdimg volume-label limit.
REM
REM Maximum total length: 32 characters
REM Reserved suffix:      _LAZY
REM Maximum base length:  27 characters
REM --------------------------------------------------

set "FINAL_ISO_LABEL_BASE=!ISO_LABEL!"

REM Remove an existing _LAZY suffix.

if /I "!FINAL_ISO_LABEL_BASE:~-5!"=="_LAZY" (
    set "FINAL_ISO_LABEL_BASE=!FINAL_ISO_LABEL_BASE:~0,-5!"
)

REM Limit the base to 27 characters.

set "FINAL_ISO_LABEL_BASE=!FINAL_ISO_LABEL_BASE:~0,27!"

REM Remove a trailing underscore.

if "!FINAL_ISO_LABEL_BASE:~-1!"=="_" (
    set "FINAL_ISO_LABEL_BASE=!FINAL_ISO_LABEL_BASE:~0,-1!"
)

if not defined FINAL_ISO_LABEL_BASE (
    set "FINAL_ISO_LABEL_BASE=W11"
)

REM Append the required suffix.

set "ISO_LABEL=!FINAL_ISO_LABEL_BASE!_LAZY"

echo.
echo Final ISO volume label:
echo   !ISO_LABEL!
echo.

REM --------------------------------------------------
REM Prepare the output directory.
REM --------------------------------------------------

for %%F in ("!OUTPUT_ISO!") do (
    if not exist "%%~dpF" (
        mkdir "%%~dpF" >nul 2>&1
    )
)

for %%F in ("!OUTPUT_ISO!") do (
    if not exist "%%~dpF" (
        echo ERROR: Failed to create the output directory:
        echo   %%~dpF
        exit /b 1
    )
)

REM --------------------------------------------------
REM Remove an existing output ISO.
REM --------------------------------------------------

if exist "!OUTPUT_ISO!" (
    del /f /q "!OUTPUT_ISO!"
)

if exist "!OUTPUT_ISO!" (
    echo ERROR: Existing output ISO could not be removed:
    echo   !OUTPUT_ISO!
    exit /b 1
)

REM --------------------------------------------------
REM Create the combined BIOS and UEFI ISO.
REM --------------------------------------------------

echo Creating combined BIOS and UEFI ISO...
echo.

"!OSCDIMG_EXE!" ^
 -m ^
 -o ^
 -u2 ^
 -udfver102 ^
 -l"!ISO_LABEL!" ^
 -bootdata:2#p0,e,b"!BIOS_BOOT_IMAGE!"#pEF,e,b"!UEFI_BOOT_IMAGE!" ^
 "!MEDIA!" ^
 "!OUTPUT_ISO!"

if errorlevel 1 (
    echo ERROR: Oscdimg failed to create the combined ISO.
    exit /b 1
)

exit /b 0


:VERIFY_OUTPUT
if not exist "%OUTPUT_ISO%" (
    echo ERROR: Output ISO was not created.
    exit /b 1
)

for %%F in ("%OUTPUT_ISO%") do (
    if %%~zF LEQ 0 (
        echo ERROR: Output ISO is empty.
        exit /b 1
    )

    echo Output ISO verification:
    echo.
    echo File:
    echo   %%~fF
    echo Size:
    echo   %%~zF bytes
    echo.
)
exit /b 0

REM ==================================================
REM Failure handling
REM ==================================================

:FAILED
call :DISMOUNT_SOURCE_ISOS

echo.
echo ==================================================
echo                     FAILED
echo ==================================================
echo.
echo The combined Windows 11 and lazyBackup ISO was not created.
echo Review the messages above.
echo.
echo If BCD backups were already created, they are here:
echo   %BIOS_BCD%.before-lazyBackup
echo   %UEFI_BCD%.before-lazyBackup
echo.
pause

popd
exit /b 1
