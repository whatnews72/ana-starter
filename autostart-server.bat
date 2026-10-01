@echo off
rem 로그온 시 작업 스케줄러가 실행: ANA 대시보드 서버가 꺼져 있으면 기동한다.
rem 이미 실행 중이면(포트 8777 응답) 아무것도 하지 않는다.
setlocal
cd /d "%~dp0"
if not exist logs mkdir logs
curl -s -f http://127.0.0.1:8777/api/state >nul 2>&1
if %ERRORLEVEL% equ 0 exit /b 0
node server.js >> logs\server.out.log 2>&1
endlocal
