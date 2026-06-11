@echo off
REM Tells the helper to stop and close itself.
powershell -NoProfile -Command "try { Invoke-RestMethod -Uri 'http://localhost:8787/api/quit' -Method POST -TimeoutSec 2 | Out-Null; Write-Host 'No Sleep helper stopped.' } catch { Write-Host 'Helper was not running.' }"
timeout /t 2 >nul
