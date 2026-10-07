@echo off
rem Called daily by Windows Task Scheduler (05:45).
rem daily-vocab-run.ps1 runs in order: add words (verified, retried) -> sync to GitHub Pages -> review push.
rem Scheduled tasks have no guaranteed order (e.g. catch-up runs after the PC was off), so one script chains them.
rem Keep this file ASCII-only: cmd.exe misparses UTF-8 Korean text in batch files.
setlocal
set "ANADIR=%~dp0"
cd /d "%ANADIR%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ANADIR%daily-vocab-run.ps1"
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
