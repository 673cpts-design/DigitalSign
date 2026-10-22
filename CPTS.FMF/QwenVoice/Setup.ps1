param([string]$PythonExe = '', [switch]$KeepModels)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
function Run-Checked {
    param([string]$Exe, [string[]]$Arguments)
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed ($LASTEXITCODE): $Exe $Arguments" }
}
try {
    if (-not (Test-Path '.venv\Scripts\python.exe')) {
        if ($PythonExe) {
            Run-Checked $PythonExe @('-c', 'import sys; assert sys.version_info[:2] in [(3,11),(3,12)], "Use Python 3.11 or 3.12"')
            Run-Checked $PythonExe @('-m', 'venv', '.venv')
        } else {
            if (-not (Get-Command py.exe -ErrorAction SilentlyContinue)) { throw 'Python launcher missing. See README.txt for -PythonExe usage.' }
            # Reuse the installed Python 3.11 interpreter, but create an isolated environment.
            Run-Checked 'py.exe' @('-3.11', '-m', 'venv', '.venv')
        }
    }
    $Python = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
    Run-Checked $Python @('-c', 'import sys; assert sys.version_info[:2] in [(3,11),(3,12)]')
    Run-Checked $Python @('-m', 'pip', 'install', '--upgrade', 'pip')
    Run-Checked $Python @('-m', 'pip', 'install', 'torch==2.8.0', 'torchaudio==2.8.0', '--index-url', 'https://download.pytorch.org/whl/cu126')
    Run-Checked $Python @('-m', 'pip', 'install', '-r', 'requirements.txt')
    Run-Checked $Python @('-m', 'pip', 'check')
    Run-Checked $Python @('-c', 'import torch; assert torch.cuda.is_available(), "CUDA unavailable: check NVIDIA driver"; print("GPU:", torch.cuda.get_device_name(0)); print("VRAM GiB:", round(torch.cuda.get_device_properties(0).total_memory / 2**30, 1))')
    if (-not $KeepModels) { Run-Checked $Python @('download_models.py') }
    foreach ($size in @('0.6B', '1.7B')) {
        if ((-not $KeepModels) -or (Test-Path (Join-Path $PSScriptRoot "models\$size\download-complete.json"))) {
            Run-Checked $Python @('generate.py', '--check', '--model', $size)
        }
    }
    & $Python -m pip freeze | Set-Content -Encoding UTF8 'installed-versions.txt'
    if ($LASTEXITCODE -ne 0) { throw 'Could not record installed versions.' }
    Write-Host "`nINSTALLATION COMPLETE: available models checked offline on your GPU." -ForegroundColor Green
    Write-Host 'VOICE TEST NOT RUN: add reference audio and fill reference.txt, then run Test-Voice.cmd.'
    Write-Host 'For your full script, run Generate.cmd. To compare both models, run Compare-Models.cmd.'
} catch {
    Write-Host $_ -ForegroundColor Red
    exit 1
}
