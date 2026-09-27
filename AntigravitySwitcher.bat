@echo off
chcp 65001 >nul
set "SCRIPT_DIR=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; & '%SCRIPT_DIR%switcher_windows.ps1'"
