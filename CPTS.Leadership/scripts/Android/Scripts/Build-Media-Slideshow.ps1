#requires -Version 7.2
[CmdletBinding()]
param(
    [string]$RootPath = 'C:\www',
    [string]$MediaFolder = '',
    [switch]$Watch,
    [ValidateRange(1,3600)][int]$PollSeconds = 5
)
$ErrorActionPreference = 'Stop'
$RootPath = [IO.Path]::GetFullPath($RootPath)
if (-not $MediaFolder) { $MediaFolder = Join-Path $RootPath 'pictures' }
$MediaFolder = [IO.Path]::GetFullPath($MediaFolder)
$null = New-Item -ItemType Directory -Force -Path $RootPath,$MediaFolder
$scriptsPath = Join-Path $RootPath 'scripts'
foreach ($file in @('swiper-11-bundle.min.css','swiper-11-bundle.min.js','swiper-gl.min.css','swiper-gl.min.js','media-slideshow.js','media-slideshow.template.html')) {
    if (-not (Test-Path -LiteralPath (Join-Path $scriptsPath $file))) { throw "Missing $scriptsPath\$file. Extract the supplied scripts folder into $RootPath." }
}
$imageExtensions = @('.jpg','.jpeg','.jpe','.png','.gif','.webp','.avif','.bmp','.svg','.heic','.heif','.tif','.tiff','.dng')
$videoExtensions = @('.mp4','.mov','.m4v','.webm','.ogv','.mkv','.avi','.mpg','.mpeg','.mts','.m2ts','.ts','.3gp','.3g2')
$utf8 = [Text.UTF8Encoding]::new($false)
function Write-Atomic([string]$Path,[string]$Content) {
    $temporary = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temporary,$Content,$utf8)
        [IO.File]::Move($temporary,$Path,$true)
    } finally { if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Force} }
}
$template = Get-Content -LiteralPath (Join-Path $scriptsPath 'media-slideshow.template.html') -Raw
$lastPlaylist = $null
do {
    try {
        $items = @(foreach ($file in (Get-ChildItem -LiteralPath $MediaFolder -File -Recurse | Sort-Object FullName)) {
            if ($file.FullName -match '[\\/]\.phone-import[\\/]') { continue }
            if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            if ($file.Length -eq 0) { continue }
            $ext = $file.Extension.ToLowerInvariant()
            $kind = if($ext -in $imageExtensions){'image'}elseif($ext -in $videoExtensions){'video'}else{continue}
            $relative = [IO.Path]::GetRelativePath($RootPath,$file.FullName)
            if ([IO.Path]::IsPathRooted($relative)) {
                $src = ([uri]$file.FullName).AbsoluteUri
            } else {
                $src = (($relative -split '[\\/]' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/')
            }
            [ordered]@{src=($src+'?v='+$file.LastWriteTimeUtc.Ticks+'-'+$file.Length); kind=$kind}
        })
        $json = ConvertTo-Json -InputObject @{items=$items} -Depth 4 -Compress
        if ($json -ne $lastPlaylist) {
            Write-Atomic (Join-Path $RootPath 'media-playlist.js') ("window.receiveMediaPlaylist($json);")
            # Do not rewrite the page on each media change; the playlist updates live.
            if ($null -eq $lastPlaylist) { Write-Atomic (Join-Path $RootPath 'media-slideshow.html') $template }
            $lastPlaylist=$json
            Write-Host ('{0} Playlist updated: {1} pictures/videos' -f (Get-Date -Format 'HH:mm:ss'),$items.Count)
        }
    } catch {
        if (-not $Watch) { throw }
        Write-Warning "Keeping previous playlist; retrying: $($_.Exception.Message)"
    }
    if ($Watch) { Start-Sleep -Seconds $PollSeconds }
} while ($Watch)
