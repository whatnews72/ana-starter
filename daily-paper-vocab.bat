@echo off
rem Called daily by Windows Task Scheduler (before the 06:00 push task).
rem Runs a one-shot headless Claude Code session that fetches today's
rem Hugging Face daily papers, picks AI/robotics ones, and adds 10 new
rem vocab words (with Korean meaning + quoted example) to the vocab list.
setlocal
set "ANADIR=%~dp0"
cd /d "%ANADIR%"

rem Ensure the server is running before invoking Claude
call "%ANADIR%ensure-server.bat"
if %ERRORLEVEL% neq 0 (
    echo [%date% %time%] Server failed to start. Aborting. >> "%ANADIR%logs\daily-paper-vocab.log"
    endlocal
    exit /b 1
)

"%APPDATA%\npm\claude.cmd" -p --permission-mode bypassPermissions --effort high < "%ANADIR%daily-paper-vocab-prompt.txt" >> "%ANADIR%logs\daily-paper-vocab.log" 2>&1
endlocal
