@echo off
rem The review push is now sent by daily-vocab-run.ps1 after words are added and synced.
rem This task does nothing so notifications are not duplicated or sent before new words exist.
rem Keep this file ASCII-only: cmd.exe misparses UTF-8 Korean text in batch files.
setlocal
set "ANADIR=%~dp0"
echo [%date% %time%] Skipped: push is handled by daily-vocab-run.ps1. >> "%ANADIR%logs\daily-vocab-push.log"
endlocal
exit /b 0
