@echo off
set "QWEN_UPDATE_ROOT=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath $env:QWEN_UPDATE_ROOT -File -Recurse | Where-Object { $_.Name -match '\.(ps1|py|cmd)\.txt$' } | ForEach-Object { $target = $_.FullName.Substring(0, $_.FullName.Length - 4); if (Test-Path -LiteralPath $target) { Copy-Item -LiteralPath $target -Destination ($target + '.before-path-update') -Force }; Move-Item -LiteralPath $_.FullName -Destination $target -Force -ErrorAction Stop }"
if errorlevel 1 (
    echo Rename failed. Read the error above.
    pause
    exit /b 1
)
echo Filenames restored. Now run Repair-After-Move.cmd.
pause
