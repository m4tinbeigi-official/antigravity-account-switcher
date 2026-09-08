@echo off
title Antigravity Account Switcher Installer
color 0b

echo ========================================================
echo   Antigravity Account Switcher - Windows Setup
echo ========================================================
echo.

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%switcher_windows.ps1"
set "DESKTOP_DIR=%USERPROFILE%\Desktop"
set "SHORTCUT_BAT=%DESKTOP_DIR%\AntigravitySwitcher.bat"

echo Creating 1-click launcher on Desktop: %SHORTCUT_BAT%
(
echo @echo off
echo powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
) > "%SHORTCUT_BAT%"

echo.
echo [SUCCESS] Launcher created on your Desktop!
echo You can now double-click 'AntigravitySwitcher.bat' anytime to switch accounts.
echo.
pause
