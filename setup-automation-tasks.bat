@echo off
rem 주의: 반드시 "관리자 권한으로 실행"할 것 (작업 재등록에 필요)
REM Setup automation tasks for ANA vocab automation
REM This script creates the two new scheduled tasks using schtasks.exe
REM IMPORTANT: Must be run as Administrator

setlocal enabledelayedexpansion

echo.
echo ======================================================================
echo  ANA Automation Task Setup
echo ======================================================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: This script must be run as Administrator!
    echo.
    echo Please right-click this .bat file and select "Run as administrator"
    pause
    exit /b 1
)

set "ANADIR=%~dp0"
cd /d "%ANADIR%"

echo [Step 1/2] Creating "ANA Server Autostart" task...
echo   Trigger: At system startup
echo   Action: autostart-server.bat
echo.

schtasks /delete /tn "ANA Server Autostart" /f >nul 2>&1

schtasks /create /tn "ANA Server Autostart" ^
  /tr "%ANADIR%autostart-server.bat" ^
  /sc ONSTART ^
  /ru %USERNAME% ^
  /rl HIGHEST ^
  /f

if %ERRORLEVEL% equ 0 (
    echo [✓] "ANA Server Autostart" created successfully
) else (
    echo [✗] Failed to create "ANA Server Autostart" (error: %ERRORLEVEL%)
)

echo.
echo [Step 2/2] Creating "ANA Vocab Git Sync" task...
echo   Trigger: Daily at 05:50
echo   Action: powershell sync-deploy.ps1
echo.

schtasks /delete /tn "ANA Vocab Git Sync" /f >nul 2>&1

schtasks /create /tn "ANA Vocab Git Sync" ^
  /tr "powershell -NoProfile -ExecutionPolicy Bypass -File \"%ANADIR%sync-deploy.ps1\"" ^
  /sc DAILY /st 05:50 ^
  /ru %USERNAME% ^
  /rl HIGHEST ^
  /f

if %ERRORLEVEL% equ 0 (
    echo [✓] "ANA Vocab Git Sync" created successfully
) else (
    echo [✗] Failed to create "ANA Vocab Git Sync" (error: %ERRORLEVEL%)
)

echo.
echo ======================================================================
echo  Verifying Tasks...
echo ======================================================================
echo.

schtasks /query /tn "ANA Server Autostart" /v | find "TaskName"
if %ERRORLEVEL% equ 0 (
    echo [✓] "ANA Server Autostart" task exists
) else (
    echo [✗] "ANA Server Autostart" task NOT found
)

echo.

schtasks /query /tn "ANA Vocab Git Sync" /v | find "TaskName"
if %ERRORLEVEL% equ 0 (
    echo [✓] "ANA Vocab Git Sync" task exists
) else (
    echo [✗] "ANA Vocab Git Sync" task NOT found
)

echo.
echo ======================================================================
echo  Summary of All ANA Tasks
echo ======================================================================
echo.

echo Existing ANA tasks:
schtasks /query | find "ANA"

echo.
echo Setup complete! Press any key to close...
pause >nul
endlocal
