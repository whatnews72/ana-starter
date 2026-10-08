@echo off
rem Ensure the ANA dashboard server (http://127.0.0.1:8777) is running.
rem If not responsive, start it in the background and wait for it to be ready.
rem Called by: daily-paper-vocab.bat, daily-vocab-push.bat

setlocal enabledelayedexpansion

set "TIMEOUT_SECS=10"
set "ANADIR=%~dp0"

rem Check if server is already responding
echo [%date% %time%] Checking if server is running...
curl -s -f http://127.0.0.1:8777/api/state >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [%date% %time%] Server is already running.
    exit /b 0
)

echo [%date% %time%] Server is not responding. Starting node server.js in the background...
cd /d "%ANADIR%"
set "ANA_REQUIRE_AUTH=1"
rem Use Start-Process (not "start /B"): a /B child inherits the caller's stdout pipe, so a caller doing
rem "ensure-server.bat | Out-Null" would hang for as long as the server lives (2026-10-09 incident).
powershell -NoProfile -Command "Start-Process -FilePath node -ArgumentList 'server.js' -WorkingDirectory '%ANADIR%' -WindowStyle Hidden -RedirectStandardOutput 'logs\server.log' -RedirectStandardError 'logs\server.err.log'"

rem Wait for the server to become responsive (with timeout)
echo [%date% %time%] Waiting for server to start (max %TIMEOUT_SECS% seconds)...
set /a "ELAPSED=0"
:wait_loop
if %ELAPSED% gtr %TIMEOUT_SECS% (
    echo [%date% %time%] ERROR: Server did not start in time. Check logs\server.log.
    exit /b 1
)
curl -s -f http://127.0.0.1:8777/api/state >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [%date% %time%] Server started successfully.
    exit /b 0
)
timeout /t 1 /nobreak >nul
set /a "ELAPSED+=1"
goto wait_loop
