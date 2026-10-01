@echo off
rem Called daily by Windows Task Scheduler. Sends a push notification if the
rem ANA dashboard server is running and words are due for review today.
setlocal
set "ANADIR=%~dp0"
cd /d "%ANADIR%"

rem Ensure the server is running before attempting the POST
call "%ANADIR%ensure-server.bat"
if %ERRORLEVEL% neq 0 (
    echo [%date% %time%] Server failed to start. Push skipped. >> "%ANADIR%logs\daily-vocab-push.log"
    endlocal
    exit /b 1
)

rem Attempt the POST and log the result
echo [%date% %time%] Attempting vocab push... >> "%ANADIR%logs\daily-vocab-push.log"
curl -s -w "\n[HTTP Status: %%{http_code}]\n" -X POST http://127.0.0.1:8777/api/vocab/push-today >> "%ANADIR%logs\daily-vocab-push.log" 2>&1
if %ERRORLEVEL% equ 0 (
    echo [%date% %time%] Push attempt completed. >> "%ANADIR%logs\daily-vocab-push.log"
) else (
    echo [%date% %time%] FAIL: curl exited with code %ERRORLEVEL%. >> "%ANADIR%logs\daily-vocab-push.log"
)
endlocal
