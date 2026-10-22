@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Generate.ps1"
set "result=%errorlevel%"
echo.
if not "%result%"=="0" echo FAILED. Read the error above.
echo This window is now waiting for a key to close.
pause
exit /b %result%
