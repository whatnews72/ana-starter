@echo off
setlocal
set "ANADIR=%~dp0"
cd /d "%ANADIR%"
if not exist "%ANADIR%logs" mkdir "%ANADIR%logs"

rem Dedicated fakechat channel port for THIS project only, so it never
rem fights another Claude session (e.g. a normal interactive terminal)
rem for the shared default port 8787.
set "FAKECHAT_PORT=8798"
set "FAKECHAT_WS=ws://127.0.0.1:8798/ws"

rem Require login for traffic arriving through the external tunnel (local
rem LAN access stays gate-free; see server.js viaProxy()).
set "ANA_REQUIRE_AUTH=1"

rem Clear any node/cloudflared left running from a previous start-ana.bat
rem that was never cleanly closed (otherwise their open log files block
rem this run's log files with "in use by another process" errors).
echo Clearing any leftover server/tunnel processes from a previous run...
taskkill /IM node.exe /F >nul 2>&1
taskkill /IM cloudflared.exe /F >nul 2>&1
timeout /t 1 /nobreak >nul

echo Starting server.js...
start "ANA Server" /D "%ANADIR%" powershell -NoExit -Command "chcp 65001 > $null; $OutputEncoding = [System.Text.Encoding]::UTF8; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; node server.js 2>&1 | Tee-Object -FilePath '%ANADIR%logs\server.log'"
timeout /t 2 /nobreak >nul

echo Starting fakechat-bridge.js (channel port %FAKECHAT_PORT%)...
start "ANA Bridge" /D "%ANADIR%" powershell -NoExit -Command "chcp 65001 > $null; $OutputEncoding = [System.Text.Encoding]::UTF8; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $env:FAKECHAT_WS='%FAKECHAT_WS%'; node fakechat-bridge.js 2>&1 | Tee-Object -FilePath '%ANADIR%logs\bridge.log'"
timeout /t 2 /nobreak >nul

echo Starting Claude Code with fakechat channel (bypass permissions, retries on failure)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ANADIR%ensure-channel.ps1"
timeout /t 1 /nobreak >nul

echo Starting external tunnel (cloudflared)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ANADIR%start-tunnel.ps1"

echo.
echo --- Status check ---
tasklist /FI "IMAGENAME eq node.exe" 2>nul | find /I "node.exe" >nul
if errorlevel 1 (
  echo [FAIL] No node.exe process found. Server/Bridge did not start.
  echo        Check logs in: %ANADIR%logs\
) else (
  echo [OK] node.exe process(es) running.
)
echo Logs folder: %ANADIR%logs\
echo   - server.log        (dashboard server, port 8777)
echo   - bridge.log        (fakechat bridge)
echo   - claude_start.log  (Claude background session)
echo.
echo === External access (changes each time this script restarts) ===
echo URL:
type "%ANADIR%logs\tunnel-url.txt" 2>nul
echo.
echo Access key (same every time):
powershell -NoProfile -Command "try { (Get-Content '%ANADIR%data\auth.json' -Raw | ConvertFrom-Json).password } catch { 'unavailable' }"
echo ==================================================================
echo.
echo If the ANA Server / ANA Bridge windows closed by themselves, open the
echo matching .log file above to see why.
echo.
pause
endlocal
