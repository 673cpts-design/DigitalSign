#Requires -Version 5.1
<#
Run every five minutes with your existing automation or Task Scheduler.
Scans C:\www\pictures and writes media-playlist.json beside index.html.
Does not modify index.html or open/refresh Edge. No watch loop.
Use PowerShell 7 or Windows PowerShell 5.1.
#>
[CmdletBinding()]
param([string]$Root = 'C:\www')
$ErrorActionPreference = 'Stop'
$playlistPath = Join-Path $Root 'media-playlist.json'
$mediaFolder = Join-Path $Root 'pictures'
if (!(Test-Path -LiteralPath $mediaFolder -PathType Container)) { throw "Pictures folder not found: $mediaFolder" }
$imageTypes = @('.jpg','.jpeg','.png','.webp','.gif','.bmp','.avif')
$videoTypes = @('.mp4','.webm','.m4v','.mov','.ogv')
# Only files directly in pictures, matching the existing playlist layout.
$items = @(foreach ($file in (Get-ChildItem -LiteralPath $mediaFolder -File | Sort-Object Name)) {
    $extension = $file.Extension.ToLowerInvariant()
    if ($imageTypes -contains $extension) { $kind = 'image' }
    elseif ($videoTypes -contains $extension) { $kind = 'video' }
    else { continue }
    if ($file.Length -eq 0) { continue }
    # Avoid adding a file while another process is still writing it.
    $handle = $null
    try { $handle = [IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read) }
    catch { throw ('Media is busy; existing playlist was kept. Try again after copying finishes: ' + $file.Name) }
    finally { if ($handle) { $handle.Dispose() } }
    [pscustomobject][ordered]@{
        src = 'pictures/' + [uri]::EscapeDataString($file.Name) + '?v=' + $file.LastWriteTimeUtc.Ticks + '-' + $file.Length
        kind = $kind
    }
})
$json = ConvertTo-Json -InputObject ([ordered]@{items=$items}) -Depth 4 -Compress
if ([IO.File]::Exists($playlistPath) -and [IO.File]::ReadAllText($playlistPath) -ceq $json) {
    Write-Host 'Media playlist is already current.'
    return
}
$temp = Join-Path $Root ('media-playlist-' + [guid]::NewGuid().ToString('N') + '.tmp')
try {
    [IO.File]::WriteAllText($temp,$json,[Text.UTF8Encoding]::new($false))
    if ([IO.File]::Exists($playlistPath)) { [IO.File]::Replace($temp,$playlistPath,$null) }
    else { [IO.File]::Move($temp,$playlistPath) }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
}
Write-Host ('Saved {0} pictures and videos to {1}' -f $items.Count,$playlistPath)
