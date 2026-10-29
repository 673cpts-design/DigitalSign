# Signal the running kiosk page before starting the content downloads.
# The five-minute countdown expires automatically; index.html is never modified.
$statusPath = 'C:\www\refresh-status.json'
$statusTemp = 'C:\www\refresh-status-' + [guid]::NewGuid().ToString('N') + '.tmp'
try {
    New-Item -ItemType Directory -Path 'C:\www' -Force -ErrorAction Stop | Out-Null
    $started = [datetimeoffset]::UtcNow
    $statusJson = ConvertTo-Json -InputObject ([ordered]@{
        StartedUtc = $started.ToString('o')
        ExpiresUtc = $started.AddMinutes(5).ToString('o')
    }) -Compress
    [IO.File]::WriteAllText($statusTemp,$statusJson,[Text.UTF8Encoding]::new($false))
    if ([IO.File]::Exists($statusPath)) { [IO.File]::Replace($statusTemp,$statusPath,($statusTemp + '.bak')) }
    else { [IO.File]::Move($statusTemp,$statusPath) }
} catch {
    Write-Warning ('Could not display refresh countdown: ' + $_.Exception.Message)
} finally {
    if (Test-Path -LiteralPath ($statusTemp + '.bak')) { Remove-Item -LiteralPath ($statusTemp + '.bak') -Force }
    if (Test-Path -LiteralPath $statusTemp) { Remove-Item -LiteralPath $statusTemp -Force }
}

& "C:\www\scripts\DL-PDF2PNG.ps1"
& "C:\www\scripts\Get-JBEREvents.ps1"
& "C:\www\scripts\Get-AirForceTimesNews.ps1"
& "C:\www\scripts\Get-Directory.ps1"
& "C:\www\scripts\teams.ps1"
& "C:\www\scripts\Update-MediaPlaylist.ps1"
