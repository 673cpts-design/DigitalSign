@echo off
pwsh.exe -NoLogo -NoProfile -File "%~dp0scripts\Build-Media-Slideshow.ps1" -RootPath "%~dp0."
pause
