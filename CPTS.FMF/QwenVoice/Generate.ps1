$ErrorActionPreference = 'Stop'
$Python = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $Python)) { Write-Error 'Run Setup.cmd first.'; exit 1 }
& $Python (Join-Path $PSScriptRoot 'generate.py')
exit $LASTEXITCODE
