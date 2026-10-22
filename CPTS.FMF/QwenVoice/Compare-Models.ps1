$ErrorActionPreference = 'Stop'
$Python = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $Python)) { Write-Error 'Run Setup.cmd first.'; exit 1 }
$Failed = $false
foreach ($Size in @('0.6B', '1.7B')) {
    Write-Host "Generating comparison with $Size..."
    # Separate processes release the first model's GPU allocation before loading the next.
    & $Python (Join-Path $PSScriptRoot 'generate.py') --model $Size --output "compare-$Size.wav"
    if ($LASTEXITCODE -ne 0) { $Failed = $true; Write-Host "$Size FAILED. Any existing comparison file for it is from a previous run." -ForegroundColor Red }
}
if ($Failed) { exit 1 }
Write-Host 'COMPARISON COMPLETE: listen to compare-0.6B.wav and compare-1.7B.wav.' -ForegroundColor Green
exit 0
