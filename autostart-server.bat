@echo off
rem Run by Task Scheduler at logon: start the ANA dashboard server if it is not running.
rem Keep this file ASCII-only (cmd reads it as CP949).
setlocal
cd /d "%~dp0"
if not exist logs mkdir logs
curl -s -f http://127.0.0.1:8777/api/state >nul 2>&1
if %ERRORLEVEL% equ 0 exit /b 0
node server.js >> logs\server.out.log 2>&1
endlocal
