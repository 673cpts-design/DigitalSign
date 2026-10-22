@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Repair-After-Move.ps1"
set "result=%errorlevel%"
pause
exit /b %result%
