@echo off
REM Visible web-UI mode for troubleshooting. The window stays open so you can read
REM the server log + any errors. Runs with -KeepAlive so it won't auto-close while
REM you're poking at it. If the UI works here but not from Start.bat, the auto-close
REM was the culprit (background-tab throttling).
title No Sleep - debug (web UI)
echo Starting No Sleep web UI in VISIBLE mode for troubleshooting...
echo If the browser doesn't open, go to http://localhost:8787/ manually.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1" -KeepAlive
echo.
echo --- the server stopped (read any messages above) ---
pause
