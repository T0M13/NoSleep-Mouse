@echo off
REM Launches the No Sleep helper hidden in the background and opens the UI in your browser.
start "" /min powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0server.ps1"
