@echo off
REM Visible console mode: no web server, just the jiggler with a live log you can see.
REM Use this if Start.bat seems to "open and close" - here you'll see any error.
title No Sleep - console
echo Starting No Sleep in console mode... press Ctrl+C to stop.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1" -Console
echo.
echo --- the helper stopped (read any messages above) ---
pause
