#requires -Version 7.2
<# One-time WhatsApp USB import. Regular folders are kept; Private folders are discarded. #>
[CmdletBinding()]
param(
    [string]$AdbPath = 'C:\platform-tools\adb.exe',
    [string]$Destination = 'C:\www\pictures'
)
$ErrorActionPreference = 'Stop'
$folders = @(
    '/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
    '/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images',
    '/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents'
)
$extensions = @('.jpg','.jpeg','.png','.gif','.webp','.heic','.heif','.bmp','.tif','.tiff','.dng','.mp4','.mov','.m4v','.3gp','.mkv','.webm','.avi','.mpeg','.mpg')
function Log([string]$message) { Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $message" }
function QuotePhone([string]$s) { "'" + $s.Replace("'", "'\''") + "'" }
function Adb([string[]]$arguments) {
    $output = & $AdbPath @arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "ADB error: $($output -join ' ')" }
    return ($output -join "`n")
}
function PhoneStamp([string]$path) {
    $raw = (Adb @('-s',$script:serial,'shell',('stat -c ''%s:%Y'' -- ' + (QuotePhone $path)))).Trim()
    if ($raw -notmatch '^(\d+):(\d+)$') { throw "Cannot read phone metadata: $path ($raw)" }
    [pscustomobject]@{ Size = [long]$Matches[1]; Raw = $raw }
}
function RemovePhoneFile([string]$path, [string]$expectedStamp) {
    if ((PhoneStamp $path).Raw -ne $expectedStamp) { throw "Phone file changed; retaining: $path" }
    $null = Adb @('-s',$script:serial,'shell',('rm -- ' + (QuotePhone $path)))
    Log "REMOVED FROM PHONE: $path"
}
function TargetPath([string]$path, [string]$hash) {
    $leaf = ($path -split '/')[-1] -replace '[\x00-\x1f<>:"/\\|?*]','_'
    $target = Join-Path $Destination $leaf
    if (Test-Path -LiteralPath $target) {
        $target = Join-Path $Destination ([IO.Path]::GetFileNameWithoutExtension($leaf) + '_' + $hash.Substring(0,12) + [IO.Path]::GetExtension($leaf))
    }
    if (Test-Path -LiteralPath $target) {
        $target = Join-Path $Destination ([guid]::NewGuid().ToString('N') + [IO.Path]::GetExtension($leaf))
    }
    return $target
}
if (!(Test-Path -LiteralPath $AdbPath)) { throw "ADB not found: $AdbPath" }
$Destination = [IO.Path]::GetFullPath($Destination)
$stage = Join-Path $Destination '.phone-import'
New-Item -ItemType Directory -Force -Path $Destination,$stage | Out-Null
$hashes = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
Log 'Indexing existing local media SHA-256 hashes...'
foreach ($file in Get-ChildItem -LiteralPath $Destination -File -Recurse) {
    if ($file.FullName.StartsWith($stage + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { continue }
    if ($file.Extension.ToLowerInvariant() -notin $extensions) { continue }
    $null = $hashes.Add((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash)
}
Log "Local index ready: $($hashes.Count) unique hashes."
$script:serial = (Adb @('-d','get-serialno')).Trim()
if ((Adb @('-s',$script:serial,'get-state')).Trim() -ne 'device') { throw 'Phone not authorized' }
Log "Connected to $script:serial"
$paths = [Collections.Generic.List[string]]::new()
foreach ($folder in $folders) {
    Log "Scanning $folder"
    $encoded = (Adb @('-s',$script:serial,'shell',('find ' + (QuotePhone $folder) + ' -type f -print0 | base64'))) -replace '\s',''
    if (!$encoded) { continue }
    $decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
    foreach ($path in $decoded.Split([char]0,[StringSplitOptions]::RemoveEmptyEntries)) {
        if ([IO.Path]::GetExtension($path).ToLowerInvariant() -in $extensions) { $paths.Add($path) }
    }
}
Log "Found $($paths.Count) media files."
foreach ($path in $paths) {
    $tmp = $null
    try {
        $stamp = PhoneStamp $path
        if ($path -match '/Private/') {
            # By design, every supported media file in a WhatsApp Private subfolder is disposable.
            RemovePhoneFile $path $stamp.Raw
            Log "DISCARDED PRIVATE: $path"
            continue
        }
        if ($stamp.Size -le 0) { Log "SKIPPED EMPTY: $path"; continue }
        $tmp = Join-Path $stage ([guid]::NewGuid().ToString('N') + [IO.Path]::GetExtension($path))
        Log "PULL: $path"
        $null = Adb @('-s',$script:serial,'pull',$path,$tmp)
        if (!(Test-Path -LiteralPath $tmp)) { throw 'ADB pull produced no file' }
        if ((Get-Item -LiteralPath $tmp).Length -ne $stamp.Size) { throw 'Transferred file size differs from phone' }
        if ((PhoneStamp $path).Raw -ne $stamp.Raw) { throw 'Phone file changed during transfer' }
        $hash = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash
        if ($hashes.Contains($hash)) {
            Log "EXACT DUPLICATE: $path"
        } else {
            $target = TargetPath $path $hash
            [IO.File]::Move($tmp,$target)
            $null = $hashes.Add($hash)
            Log "SAVED: $target"
        }
        RemovePhoneFile $path $stamp.Raw
    } catch {
        Log "ERROR (phone file may be retained): $path : $($_.Exception.Message)"
    } finally {
        if ($tmp -and (Test-Path -LiteralPath $tmp)) { Remove-Item -LiteralPath $tmp -Force }
    }
}
Log 'Finished one-time import. Exiting.'
