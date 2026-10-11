@echo off
setlocal EnableExtensions DisableDelayedExpansion

title lazyBackup WinPE
mode con cols=150 lines=40

REM Default keyboard layout
REM Leave empty to show the keyboard selection menu.
REM German: 0407:00000407

REM ==================================================
REM Default keyboard layout
REM ==================================================
REM
REM Leave KEYBOARD_LAYOUT empty to show the keyboard
REM selection menu when no configuration file defines
REM a layout.
REM
REM A layout can be predefined in .lazybackup.conf.
REM Only one KEYBOARD_LAYOUT entry should be active.
REM
REM Available presets:
REM
REM German - Germany:
REM KEYBOARD_LAYOUT=0407:00000407
REM
REM English - United States:
REM KEYBOARD_LAYOUT=0409:00000409
REM
REM English - United Kingdom:
REM KEYBOARD_LAYOUT=0809:00000809
REM
REM French - France:
REM KEYBOARD_LAYOUT=040C:0000040C
REM
REM Spanish - Spain:
REM KEYBOARD_LAYOUT=0C0A:0000040A
REM
REM The actual built-in default remains empty:
REM ==================================================

set "KEYBOARD_LAYOUT="

REM ==================================================
REM Built-in and external lazyBackup locations
REM External paths are relative to a detected drive root.
REM Do not include a drive letter.
REM ==================================================

set "BUILTIN_LAZYBACKUP=X:\lazyBackup\lazyBackup.bat"
set "SCRIPT_DIR_CONFIG=X:\lazyBackup\.lazybackup.conf"

set "EXTERNAL_LAZYBACKUP_PATH=\ProgramData\Programme_portable\Sicherheit\lazybackup\lazybackup.bat"
set "EXTERNAL_WINPE_ISO_PATH=\ProgramData\Programme_portable\Sicherheit\lazybackup\WinPE ISO\lazyBackup_WinPE.iso"

set "BOOTSTRAP_ROOT_CONFIG="
set "BOOTSTRAP_USB_CONFIG="
set "BOOTSTRAP_EFFECTIVE_CONFIG=Built-in startnet.cmd defaults"

wpeinit >nul 2>&1

call :LOAD_BOOTSTRAP_CONFIGS

if not defined KEYBOARD_LAYOUT goto KEYBOARD_MENU

wpeutil SetKeyboardLayout %KEYBOARD_LAYOUT%
echo Using %KEYBOARD_LAYOUT%
echo Language, date and local settings remain English (US).

goto AFTER_KEYBOARD

:KEYBOARD_MENU

cls
echo.
echo ==========================================
echo        Keyboard Layout Selection
echo ==========================================
echo.
echo [1] German (Germany)
echo [2] English (US)
echo [3] English (UK)
echo [4] French
echo [5] Spanish
echo [L] List available layouts
echo.
echo German keyboard will be selected
echo automatically in 15 seconds.
echo.


choice /C 12345L /N /T 15 /D 1

if errorlevel 6 goto LIST_KEYBOARDS
if errorlevel 5 goto SET_KEYBOARD_ES
if errorlevel 4 goto SET_KEYBOARD_FR
if errorlevel 3 goto SET_KEYBOARD_EN_GB
if errorlevel 2 goto SET_KEYBOARD_EN_US
if errorlevel 1 goto SET_KEYBOARD_DE

goto KEYBOARD_MENU


:SET_KEYBOARD_DE

set "KEYBOARD_LAYOUT=0407:00000407"
goto APPLY_KEYBOARD_LAYOUT


:SET_KEYBOARD_EN_US

set "KEYBOARD_LAYOUT=0409:00000409"
goto APPLY_KEYBOARD_LAYOUT


:SET_KEYBOARD_EN_GB

set "KEYBOARD_LAYOUT=0809:00000809"
goto APPLY_KEYBOARD_LAYOUT


:SET_KEYBOARD_FR

set "KEYBOARD_LAYOUT=040C:0000040C"
goto APPLY_KEYBOARD_LAYOUT


:SET_KEYBOARD_ES

set "KEYBOARD_LAYOUT=0C0A:0000040A"
goto APPLY_KEYBOARD_LAYOUT


:APPLY_KEYBOARD_LAYOUT

echo.
echo Activating keyboard layout:
echo   %KEYBOARD_LAYOUT%
echo.

wpeutil SetKeyboardLayout %KEYBOARD_LAYOUT%

if errorlevel 1 (
    echo ERROR: The selected keyboard layout could not be activated.
    echo.
    pause
    goto KEYBOARD_MENU
)

goto AFTER_KEYBOARD


:LIST_KEYBOARDS

cls
echo.
echo ==========================================
echo        Available Keyboard Layouts
echo ==========================================
echo.
echo Wpeutil requires a language identifier
echo when listing supported keyboard layouts.
echo.

echo ------------------------------------------
echo German - LCID 0407
echo ------------------------------------------

wpeutil ListKeyboardLayouts 0407

echo.
echo ------------------------------------------
echo English US - LCID 0409
echo ------------------------------------------

wpeutil ListKeyboardLayouts 0409

echo.
echo ------------------------------------------
echo English UK - LCID 0809
echo ------------------------------------------

wpeutil ListKeyboardLayouts 0809

echo.
echo ------------------------------------------
echo French - LCID 040C
echo ------------------------------------------

wpeutil ListKeyboardLayouts 040C

echo.
echo ------------------------------------------
echo Spanish - LCID 0C0A
echo ------------------------------------------

wpeutil ListKeyboardLayouts 0C0A

echo.
pause
goto KEYBOARD_MENU

:AFTER_KEYBOARD

:MENU

cls
echo.
echo ==================================================
echo              lazyBackup WinPE
echo ==================================================
echo.
echo   [L] Start lazyBackup
echo   [C] Open Command Prompt
echo.
echo --------------------------------------------------
echo.
echo If no choice is made, lazyBackup will start
echo automatically in 20 seconds.
echo.
echo Press L to start immediately.
echo Press C to open a command prompt.
echo.

choice /C LC /N /T 20 /D L

if errorlevel 2 goto COMMANDPROMPT
if errorlevel 1 goto STARTBACKUP

:COMMANDPROMPT

cls
echo.
echo ==================================================
echo                Command Prompt
echo ==================================================
echo.
echo Useful commands:
echo.
echo   diskpart    - Disk management
echo   dism        - Imaging tools
echo   net use     - Network drives
echo.
echo Type EXIT to return to the WinPE menu.
echo.
cmd
goto MENU


:STARTBACKUP

cls
echo.
echo ==================================================
echo          Selecting lazyBackup Version
echo ==================================================
echo.

call :SELECT_LAZYBACKUP

if errorlevel 1 (
    echo.
    echo No usable lazyBackup version was found.
    echo.
    pause
    goto MENU
)

echo.
echo Selected lazyBackup:
echo   %LAZYBACKUP_TO_RUN%
echo.
echo Selected version:
echo   %LAZYBACKUP_SELECTED_VERSION%
echo.
echo Starting lazyBackup...
echo.

for %%I in ("%LAZYBACKUP_TO_RUN%") do (
    set "LAZYBACKUP_RUN_DIR=%%~dpI"
)

pushd "%LAZYBACKUP_RUN_DIR%"
call "%LAZYBACKUP_TO_RUN%"
popd

goto MENU


REM ==================================================
REM Helper routines below this point
REM Do not allow normal execution to fall through.
REM ==================================================

goto :eof

REM ==================================================
REM Load bootstrap configuration
REM ==================================================

:LOAD_BOOTSTRAP_CONFIGS

setlocal EnableExtensions DisableDelayedExpansion

set "LOCAL_SCRIPT_CONFIG=%SCRIPT_DIR_CONFIG%"
set "FOUND_ROOT_CONFIG="
set "FOUND_USB_CONFIG="
set "EFFECTIVE_CONFIG=Built-in startnet.cmd defaults"

REM Keep local copies so changed path settings can be returned
REM after ENDLOCAL.

set "RETURN_EXTERNAL_LAZYBACKUP_PATH=%EXTERNAL_LAZYBACKUP_PATH%"
set "RETURN_EXTERNAL_WINPE_ISO_PATH=%EXTERNAL_WINPE_ISO_PATH%"
set "RETURN_KEYBOARD_LAYOUT=%KEYBOARD_LAYOUT%"

REM --------------------------------------------------
REM Priority 3:
REM Configuration beside the built-in lazyBackup
REM --------------------------------------------------

if exist "%LOCAL_SCRIPT_CONFIG%" (
    echo.
    echo Loading WinPE script-directory configuration:
    echo   %LOCAL_SCRIPT_CONFIG%

    call :LOAD_BOOTSTRAP_CONFIG_FILE "%LOCAL_SCRIPT_CONFIG%"

    set "EFFECTIVE_CONFIG=%LOCAL_SCRIPT_CONFIG%"
)

REM --------------------------------------------------
REM Priority 2:
REM First non-USB configuration in a drive root
REM --------------------------------------------------

for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined FOUND_ROOT_CONFIG (
        if not exist "%%D:\.USBBACKUPSTORE" (
            if exist "%%D:\.lazybackup.conf" (
                set "FOUND_ROOT_CONFIG=%%D:\.lazybackup.conf"
            )
        )
    )
)

if defined FOUND_ROOT_CONFIG (
    echo.
    echo Loading drive-root configuration:
    echo   %FOUND_ROOT_CONFIG%

    call :LOAD_BOOTSTRAP_CONFIG_FILE "%FOUND_ROOT_CONFIG%"

    set "EFFECTIVE_CONFIG=%FOUND_ROOT_CONFIG%"
)

REM --------------------------------------------------
REM Priority 1:
REM Configuration on preferred USB backup storage
REM --------------------------------------------------

for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if not defined FOUND_USB_CONFIG (
        if exist "%%D:\.USBBACKUPSTORE" (
            if exist "%%D:\.lazybackup.conf" (
                set "FOUND_USB_CONFIG=%%D:\.lazybackup.conf"
            )
        )
    )
)

if defined FOUND_USB_CONFIG (
    echo.
    echo Loading preferred USB storage configuration:
    echo   %FOUND_USB_CONFIG%

    call :LOAD_BOOTSTRAP_CONFIG_FILE "%FOUND_USB_CONFIG%"

    set "EFFECTIVE_CONFIG=%FOUND_USB_CONFIG%"
)

REM Preserve settings changed by the configuration parser.

set "RETURN_EXTERNAL_LAZYBACKUP_PATH=%EXTERNAL_LAZYBACKUP_PATH%"
set "RETURN_EXTERNAL_WINPE_ISO_PATH=%EXTERNAL_WINPE_ISO_PATH%"
set "RETURN_KEYBOARD_LAYOUT=%KEYBOARD_LAYOUT%"

endlocal & (
    set "BOOTSTRAP_ROOT_CONFIG=%FOUND_ROOT_CONFIG%"
    set "BOOTSTRAP_USB_CONFIG=%FOUND_USB_CONFIG%"
    set "BOOTSTRAP_EFFECTIVE_CONFIG=%EFFECTIVE_CONFIG%"
    set "EXTERNAL_LAZYBACKUP_PATH=%RETURN_EXTERNAL_LAZYBACKUP_PATH%"
    set "EXTERNAL_WINPE_ISO_PATH=%RETURN_EXTERNAL_WINPE_ISO_PATH%"
    set "KEYBOARD_LAYOUT=%RETURN_KEYBOARD_LAYOUT%"
)

echo.
echo Bootstrap configuration:
echo   %BOOTSTRAP_EFFECTIVE_CONFIG%
echo.
echo External lazyBackup path:
echo   %EXTERNAL_LAZYBACKUP_PATH%
echo.
echo External WinPE ISO path:
echo   %EXTERNAL_WINPE_ISO_PATH%
echo.

exit /b 0


REM ==================================================
REM Read allowed bootstrap values from configuration
REM ==================================================

:LOAD_BOOTSTRAP_CONFIG_FILE

if not exist "%~1" exit /b 0

for /F "usebackq eol=# tokens=1,* delims==" %%A in ("%~1") do (
    if /I "%%A"=="EXTERNAL_LAZYBACKUP_PATH" (
        if not "%%B"=="" set "EXTERNAL_LAZYBACKUP_PATH=%%B"
    )

    if /I "%%A"=="EXTERNAL_WINPE_ISO_PATH" (
        if not "%%B"=="" set "EXTERNAL_WINPE_ISO_PATH=%%B"
    )
    if /I "%%A"=="KEYBOARD_LAYOUT" (
    if not "%%B"=="" set "KEYBOARD_LAYOUT=%%B"
    )
)

exit /b 0


REM ==================================================
REM Select newest available lazyBackup version
REM ==================================================

:SELECT_LAZYBACKUP

setlocal EnableExtensions EnableDelayedExpansion

set "BEST_SCRIPT="
set "BEST_VERSION="
set "BEST_SCORE=-1"

REM --------------------------------------------------
REM Check built-in ISO version
REM --------------------------------------------------


if exist "%BUILTIN_LAZYBACKUP%" (
    set "CANDIDATE_VERSION="
    set "CANDIDATE_SCORE="

    call :READ_LAZYBACKUP_VERSION "%BUILTIN_LAZYBACKUP%" CANDIDATE_VERSION CANDIDATE_SCORE

    if defined CANDIDATE_VERSION (
        set "BEST_SCRIPT=%BUILTIN_LAZYBACKUP%"
        set "BEST_VERSION=!CANDIDATE_VERSION!"
        set "BEST_SCORE=!CANDIDATE_SCORE!"

        echo Built-in ISO version:
        echo   !CANDIDATE_VERSION!
        echo   %BUILTIN_LAZYBACKUP%
        echo.
    )
)

REM --------------------------------------------------
REM Search synchronized lazyBackup on all drives
REM --------------------------------------------------

for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    set "CANDIDATE_SCRIPT=%%D:!EXTERNAL_LAZYBACKUP_PATH!"

    if exist "!CANDIDATE_SCRIPT!" (
        set "CANDIDATE_VERSION="
        set "CANDIDATE_SCORE="

        call :READ_LAZYBACKUP_VERSION "!CANDIDATE_SCRIPT!" CANDIDATE_VERSION CANDIDATE_SCORE

        if defined CANDIDATE_VERSION (
            echo Found synchronized lazyBackup:
            echo   Version !CANDIDATE_VERSION!
            echo   !CANDIDATE_SCRIPT!
            echo.

            if !CANDIDATE_SCORE! GTR !BEST_SCORE! (
                set "BEST_SCRIPT=!CANDIDATE_SCRIPT!"
                set "BEST_VERSION=!CANDIDATE_VERSION!"
                set "BEST_SCORE=!CANDIDATE_SCORE!"
            )
        )
    )
)

if not defined BEST_SCRIPT (
    endlocal
    exit /b 1
)

for %%I in ("!BEST_SCRIPT!") do set "RETURN_SCRIPT=%%~fI"
set "RETURN_VERSION=!BEST_VERSION!"

endlocal & (
    set "LAZYBACKUP_TO_RUN=%RETURN_SCRIPT%"
    set "LAZYBACKUP_SELECTED_VERSION=%RETURN_VERSION%"
)

exit /b 0


REM ==================================================
REM Read and convert lazyBackup version
REM ==================================================

:READ_LAZYBACKUP_VERSION

setlocal EnableExtensions DisableDelayedExpansion

set "VERSION_FILE=%~1"
set "VERSION_VALUE="

REM Find a line such as:
REM set "SCRIPT_VERSION=0.8.4"

for /F "usebackq tokens=2 delims==" %%V in (
    `findstr /I /C:"SCRIPT_VERSION=" "%VERSION_FILE%" 2^>nul`
) do (
    if not defined VERSION_VALUE (
        set "VERSION_VALUE=%%V"
    )
)

if not defined VERSION_VALUE (
    endlocal & (
        set "%~2="
        set "%~3="
    )
    exit /b 1
)

REM Remove quotation marks and spaces.

set "VERSION_VALUE=%VERSION_VALUE:"=%"
set "VERSION_VALUE=%VERSION_VALUE: =%"

set "VERSION_MAJOR=0"
set "VERSION_MINOR=0"
set "VERSION_PATCH=0"

for /F "tokens=1-3 delims=." %%A in ("%VERSION_VALUE%") do (
    set "VERSION_MAJOR=%%A"
    set "VERSION_MINOR=%%B"
    set "VERSION_PATCH=%%C"
)

REM Convert MAJOR.MINOR.PATCH into a comparable number.
REM 0.8.4 -> 8004
REM 0.9.0 -> 9000
REM 1.0.0 -> 1000000

set /A VERSION_SCORE=VERSION_MAJOR*1000000 + VERSION_MINOR*1000 + VERSION_PATCH

endlocal & (
    set "%~2=%VERSION_VALUE%"
    set "%~3=%VERSION_SCORE%"
)

exit /b 0