@echo off
rem Double-click to install or update Cadence for WoW Forever.
rem Add -Force after the .ps1 path to reinstall even if you're up to date.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-Cadence.ps1" %*
echo.
pause
