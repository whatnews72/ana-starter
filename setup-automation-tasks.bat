@echo off
rem Registers the ANA scheduled tasks by calling the PowerShell scripts.
rem The ps1 scripts set WorkingDirectory (schtasks.exe cannot).
rem IMPORTANT: Run as Administrator. Keep this file ASCII-only (cmd reads it as CP949).
setlocal
cd /d "%~dp0"

net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Run this file as Administrator.
    pause
    exit /b 1
)

echo [1/2] ANA Vocab Git Sync
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0create-vocab-sync-task.ps1"
echo.
echo [2/2] ANA Server Autostart
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0create-server-autostart-task.ps1"
echo.
echo Registered ANA tasks:
schtasks /query | find "ANA"
echo.
pause
endlocal
