@echo off
rem Called daily by Windows Task Scheduler. Only actually sends a notification
rem if the ANA dashboard server (start-ana.bat) is running and words are due.
curl -s -X POST http://127.0.0.1:8777/api/vocab/push-today -o NUL
