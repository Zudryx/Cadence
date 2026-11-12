@echo off
rem Installs the newest Tactara TEST build (a GitHub pre-release that hasn't
rem gone to CurseForge yet). Use "Update Tactara.bat" for normal releases.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-Tactara.ps1" -Testing %*
echo.
pause
