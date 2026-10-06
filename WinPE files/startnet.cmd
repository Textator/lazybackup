@echo off

title lazyBackup WinPE

set "KEYBOARD_LAYOUT="
REM Default keyboard layout
REM Un-/Comment the this line to show the keyboard selection menu
REM set "KEYBOARD_LAYOUT=0407:00000407"

wpeinit >nul 2>&1


if defined KEYBOARD_LAYOUT (
    wpeutil SetKeyboardLayout %KEYBOARD_LAYOUT%
    echo Using %KEYBOARD_LAYOUT%
    echo Language, date and local settings remain English (US).
) else (
    goto KEYBOARD_MENU
)
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
if errorlevel 5 set "KEYBOARD_LAYOUT=0C0A:0000040A"
if errorlevel 4 set "KEYBOARD_LAYOUT=040C:0000040C"
if errorlevel 3 set "KEYBOARD_LAYOUT=0809:00000809"
if errorlevel 2 set "KEYBOARD_LAYOUT=0409:00000409"
if errorlevel 1 set "KEYBOARD_LAYOUT=0407:00000407"

wpeutil SetKeyboardLayout %KEYBOARD_LAYOUT%

goto AFTER_KEYBOARD


:LIST_KEYBOARDS

echo.
echo Available keyboard layouts:
echo.

wpeutil ListKeyboardLayouts

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
echo automatically in 60 seconds.
echo.
echo Press L to start immediately.
echo Press C to open a command prompt.
echo.

choice /C LC /N /T 60 /D L

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
echo Starting lazyBackup...
echo.

cd \lazyBackup
call lazyBackup.bat
goto MENU