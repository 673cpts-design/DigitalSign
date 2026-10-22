@echo off
"%~dp0.venv\Scripts\python.exe" "%~dp0generate.py" --test
set "result=%errorlevel%"
echo.
if not "%result%"=="0" echo FAILED. Read the error above.
echo This window is now waiting for a key to close.
pause
exit /b %result%
