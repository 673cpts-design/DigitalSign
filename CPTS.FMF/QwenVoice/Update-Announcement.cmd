@echo off
setlocal
set "SCRIPT=%~dp0Update-Announcement.ps1"
if not exist "%SCRIPT%" (
    echo ERROR: Update-Announcement.ps1 was not found beside this launcher.
    pause
    exit /b 1
)
where pwsh.exe >nul 2>&1
if errorlevel 1 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
) else (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
)
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" (
    echo.
    echo Update failed. See the error above.
    pause
)
exit /b %RESULT%
