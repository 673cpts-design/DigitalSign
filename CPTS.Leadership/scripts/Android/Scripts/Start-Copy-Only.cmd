@echo off
where pwsh.exe >nul 2>&1
if errorlevel 1 (
  echo Install PowerShell 7 before running this importer.
  pause
  exit /b 1
)
pwsh.exe -NoLogo -NoProfile -File "%~dp0Import-PhoneMedia.ps1"
pause
