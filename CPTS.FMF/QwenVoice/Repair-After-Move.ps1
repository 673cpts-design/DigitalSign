# Run once from C:\www\QwenVoice after moving the full folder and applying updates.
param([string]$PythonExe = '')
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
try {
    $settings = Join-Path $PSScriptRoot 'settings.json'
    if (-not (Test-Path -LiteralPath $settings)) { throw 'Move your full QwenVoice folder first; settings.json is missing.' }
    $cfg = Get-Content -LiteralPath $settings -Raw -Encoding UTF8 | ConvertFrom-Json
    $changed = $false
    foreach ($key in @('reference', 'reference_transcript', 'script', 'output')) {
        $property = $cfg.PSObject.Properties[$key]
        if ($null -ne $property -and $property.Value -is [string]) {
            $value = $property.Value.Replace('/', '\')
            $prefix = 'C:\QwenVoice\'
            if ($value.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
                $property.Value = $value.Substring($prefix.Length)
                $changed = $true
            }
        }
    }
    if ($changed) {
        $backup = $settings + '.before-move-' + [Guid]::NewGuid().ToString('N') + '.bak'
        $pending = $settings + '.moving'
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($pending, ($cfg | ConvertTo-Json -Depth 100), $utf8)
        [IO.File]::Replace($pending, $settings, $backup)
        Write-Host 'Saved paths migrated; original settings backed up.'
    }
    # Virtual environments are not portable. Rebuild once at the new location.
    # A marker allows a failed setup to be retried without renaming it repeatedly.
    $marker = Join-Path $PSScriptRoot '.environment-relocation.json'
    $completed = $false
    if (Test-Path -LiteralPath $marker) {
        $state = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
        if ($state.location -eq $PSScriptRoot) { $completed = [bool]$state.complete }
        else { throw 'Relocation marker belongs to another location. Review it before another move.' }
    } else {
        $oldEnv = Join-Path $PSScriptRoot '.venv'
        if (Test-Path -LiteralPath $oldEnv) {
            Rename-Item -LiteralPath $oldEnv -NewName ('.venv-before-move-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        }
        @{location=$PSScriptRoot; complete=$false} | ConvertTo-Json | Set-Content -LiteralPath $marker -Encoding UTF8
    }
    if (-not $completed) {
        $hostExe = (Get-Process -Id $PID).Path
        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'Setup.ps1'), '-KeepModels')
        if ($PythonExe) { $arguments += @('-PythonExe', $PythonExe) }
        & $hostExe @arguments
        if ($LASTEXITCODE -ne 0) { throw 'Environment setup failed. Correct the error and run this repair again.' }
        @{location=$PSScriptRoot; complete=$true} | ConvertTo-Json | Set-Content -LiteralPath $marker -Encoding UTF8
    }
    Write-Host 'MOVE REPAIR COMPLETE. Run Update-Announcement.cmd to test.' -ForegroundColor Green
} catch {
    Write-Host $_ -ForegroundColor Red
    exit 1
}
