#requires -Version 7.2
<#
USB-only Quick Share media importer. No downloads, network shares or phone app.
Defaults: C:\www\pictures; phone /sdcard/Download/Quick Share.
Copy-only by default. Use -DeleteAfterImport after validating real transfers.
SHA-256 detects byte-identical files, not visually similar/re-encoded media.
#>
[CmdletBinding()]
param(
    [string]$Destination = 'C:\www\pictures',
    [string]$PhoneFolder = '/sdcard/Download/Quick Share',
    [string]$AdbPath = (Join-Path $PSScriptRoot 'platform-tools\adb.exe'),
    [string]$Serial = '',
    [ValidateRange(1,3600)][int]$PollSeconds = 5,
    [ValidateRange(10,86400)][int]$StableSeconds = 60,
    [switch]$DeleteAfterImport,
    [switch]$Once
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$extensions = @('.jpg','.jpeg','.jpe','.png','.gif','.webp','.heic','.heif',
    '.avif','.bmp','.tif','.tiff','.dng','.mp4','.mov','.m4v','.3gp','.3g2',
    '.mkv','.webm','.avi','.mpg','.mpeg','.mts','.m2ts','.ts')
if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
    throw "ADB not found: $AdbPath. Extract Google's Platform-Tools alongside this script or supply -AdbPath."
}
$AdbPath = (Resolve-Path -LiteralPath $AdbPath).Path
$Destination = [IO.Path]::GetFullPath($Destination)
if ($PhoneFolder -notmatch '^/(sdcard|storage/emulated/0)/.+') {
    throw 'PhoneFolder must be a specific folder inside shared phone storage.'
}
$PhoneFolder = $PhoneFolder.TrimEnd('/')
$work = Join-Path $Destination '.phone-import'
$null = New-Item -ItemType Directory -Force -Path $Destination,$work
$lock = $null
try {
    $lock = [IO.File]::Open((Join-Path $work 'running.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
} catch { throw 'Another importer is using this destination, or the folder is not writable.' }

function Write-Log([string]$Message) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Write-Host $line
    Add-Content -LiteralPath (Join-Path $work ((Get-Date -Format 'yyyy-MM-dd') + '.log')) -Value $line -Encoding utf8
}

function Invoke-Adb([string[]]$Arguments, [int]$TimeoutSeconds = 120) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $AdbPath
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $info.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill($true)
            throw 'ADB timed out. Phone originals have not been removed by this operation.'
        }
        $output = $stdout.GetAwaiter().GetResult()
        $errors = $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw "ADB failed ($($process.ExitCode)): $errors $output" }
        return $output.TrimEnd("`r", "`n")
    } finally { $process.Dispose() }
}

function Quote-Sh([string]$Value) {
    # POSIX single-quote escaping; never interpolate unquoted phone filenames.
    return "'" + $Value.Replace("'", "'\''") + "'"
}
function Invoke-Phone([string]$Command, [int]$TimeoutSeconds = 120) {
    Invoke-Adb -Arguments @('-s',$script:device,'shell',$Command) -TimeoutSeconds $TimeoutSeconds
}
function Get-PhoneStamp([string]$Path) {
    $value = Invoke-Phone ('stat -c ''%s:%Y:%i'' -- ' + (Quote-Sh $Path))
    if ($value -notmatch '^\d+:\d+:\d+$') { throw "Unexpected phone file metadata: $Path" }
    return $value
}
function Get-PhoneHash([string]$Path) {
    # Hash stdin so even names containing newlines/backslashes cannot affect parsing.
    $value = Invoke-Phone ('sha256sum < ' + (Quote-Sh $Path)) 1800
    if ($value -notmatch '^([a-fA-F0-9]{64})\s') { throw "Cannot hash phone file: $Path" }
    return $Matches[1].ToUpperInvariant()
}
function Get-LocalHash([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

# Metadata cache is only an optimization. Before trusting any duplicate, rehash it.
$cache = @{}
$hashIndex = @{}
function Update-Index {
    $script:hashIndex = @{}
    $present = @{}
    foreach ($file in Get-ChildItem -LiteralPath $Destination -File -Recurse -Force) {
        if ($file.FullName.StartsWith($work + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        if ($file.Extension.ToLowerInvariant() -notin $extensions) { continue }
        $key = $file.FullName
        $signature = "$($file.Length):$($file.LastWriteTimeUtc.Ticks)"
        $present[$key] = $true
        if (-not $script:cache.ContainsKey($key) -or $script:cache[$key].Stamp -ne $signature) {
            $script:cache[$key] = @{ Stamp = $signature; Hash = (Get-LocalHash $key) }
        }
        $hash = $script:cache[$key].Hash
        if (-not $script:hashIndex.ContainsKey($hash)) { $script:hashIndex[$hash] = [Collections.Generic.List[string]]::new() }
        $script:hashIndex[$hash].Add($key)
    }
    foreach ($key in @($script:cache.Keys)) {
        if (-not $present.ContainsKey($key)) { $script:cache.Remove($key) }
    }
}

function Find-Duplicate([string]$Hash) {
    if ($script:hashIndex.ContainsKey($Hash)) {
        foreach ($path in $script:hashIndex[$Hash]) {
            if ((Test-Path -LiteralPath $path -PathType Leaf) -and (Get-LocalHash $path) -eq $Hash) { return $path }
        }
    }
    return $null
}

function New-TargetName([string]$PhonePath, [string]$Hash) {
    $leaf = ($PhonePath -split '/')[-1]
    $ext = [IO.Path]::GetExtension($leaf).ToLowerInvariant()
    $stem = [IO.Path]::GetFileNameWithoutExtension($leaf) -replace '[\x00-\x1f<>:"/\\|?*]', '_'
    $stem = $stem.Trim(' ','.')
    if (-not $stem) { $stem = 'media' }
    if ($stem.Length -gt 80) { $stem = $stem.Substring(0,80) }
    if ($stem -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])($|\.)') { $stem = '_' + $stem }
    $name = Join-Path $Destination ($stem + $ext)
    if (Test-Path -LiteralPath $name) { $name = Join-Path $Destination ($stem + '_' + $Hash.Substring(0,12) + $ext) }
    if (Test-Path -LiteralPath $name) { $name = Join-Path $Destination ($stem + '_' + [guid]::NewGuid().ToString('N') + $ext) }
    return $name
}

$observed = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
$script:device = ''
$boundDevice = $Serial
$lastError = ''
$onceWarmup = [bool]$Once
try {
    # A hard stop can leave staging files. They never enter the media index.
    Get-ChildItem -LiteralPath $work -Filter '*.partial' -File | Remove-Item -Force
    Write-Log "Started. Destination: $Destination. DeleteAfterImport: $DeleteAfterImport"
    Write-Log "Waiting for a USB-authorized phone; monitoring $PhoneFolder"
    do {
        try {
            # -d selects only a USB transport, including Windows where devices -l
            # does not always include a usb: field. Multiple USB phones fail closed.
            $usbSerial = Invoke-Adb @('-d','get-serialno')
            if ((Invoke-Adb @('-d','get-state')) -ne 'device') { throw 'USB phone is not authorized.' }
            if ($boundDevice) {
                if ($boundDevice -ne $usbSerial) { throw "Waiting for USB phone $boundDevice; a different phone is connected." }
            } else {
                $boundDevice = $usbSerial
                Write-Log "Bound to USB phone: $boundDevice (will not switch to another phone)."
            }
            $script:device = $boundDevice
            $folder = Quote-Sh $PhoneFolder
            $null = Invoke-Phone "test -d $folder"
            # NUL-delimited listing transported as base64 supports spaces, quotes and Unicode.
            $listing = Invoke-Phone "find $folder -type f -print0 | base64"
            $decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($listing -replace '\s','')))
            $paths = @($decoded.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries))
            Update-Index
            $presentPhone = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            foreach ($path in $paths) {
                $null = $presentPhone.Add($path)
                if (-not $path.StartsWith($PhoneFolder + '/', [StringComparison]::Ordinal)) { continue }
                if ([IO.Path]::GetExtension($path).ToLowerInvariant() -notin $extensions) { continue }
                $temp = $null
                try {
                    $stamp = Get-PhoneStamp $path
                    if ([long]($stamp.Split(':')[0]) -eq 0) { continue }
                    if (-not $observed.ContainsKey($path) -or $observed[$path].Stamp -ne $stamp) {
                        $observed[$path] = @{ Stamp = $stamp; Since = [datetime]::UtcNow }
                        continue
                    }
                    if (([datetime]::UtcNow - $observed[$path].Since).TotalSeconds -lt $StableSeconds) { continue }
                    if (-not $DeleteAfterImport -and $observed[$path].ContainsKey('Local')) {
                        $previous = $observed[$path]
                        if ($script:cache.ContainsKey($previous.Local) -and $script:cache[$previous.Local].Hash -eq $previous.Hash) { continue }
                    }
                    $hash = Get-PhoneHash $path
                    if ((Get-PhoneStamp $path) -ne $stamp) { $observed.Remove($path) | Out-Null; continue }
                    $local = Find-Duplicate $hash
                    $duplicate = [bool]$local
                    if (-not $local) {
                        $temp = Join-Path $work ([guid]::NewGuid().ToString('N') + '.partial')
                        $null = Invoke-Adb @('-s',$script:device,'pull',$path,$temp) 1800
                        if ((Get-PhoneStamp $path) -ne $stamp -or (Get-LocalHash $temp) -ne $hash -or (Get-PhoneHash $path) -ne $hash) {
                            throw 'Source changed or copy verification failed; original retained.'
                        }
                        $local = New-TargetName $path $hash
                        # Same-volume rename publishes the verified file without exposing partial media.
                        [IO.File]::Move($temp,$local)
                        $temp = $null
                        if (-not $script:hashIndex.ContainsKey($hash)) { $script:hashIndex[$hash] = [Collections.Generic.List[string]]::new() }
                        $script:hashIndex[$hash].Add($local)
                        Write-Log "IMPORTED: $path -> $local"
                    }
                    if ($DeleteAfterImport) {
                        # Hold destination open against modification/deletion while validating source.
                        $guard = [IO.File]::Open($local,'Open','Read','Read')
                        try {
                            $sha = [Security.Cryptography.SHA256]::Create()
                            try { $verified = [Convert]::ToHexString($sha.ComputeHash($guard)) } finally { $sha.Dispose() }
                            if ($verified -ne $hash) { throw 'Destination changed; phone original retained.' }
                            $quoted = Quote-Sh $path
                            # Recheck stamp/hash on the phone in the same shell before removal.
                            $command = 's=$(stat -c ''%s:%Y:%i'' -- {0}) && h=$(sha256sum < {0}) && [ "$s" = {1} ] && [ "${{h%% *}}" = {2} ] && rm -- {0}' -f $quoted,(Quote-Sh $stamp),(Quote-Sh $hash.ToLowerInvariant())
                            $null = Invoke-Phone $command 1800
                            Write-Log "PHONE COPY REMOVED (verified; duplicate=$duplicate): $path"
                            $observed.Remove($path) | Out-Null
                        } finally { $guard.Dispose() }
                    } else {
                        Write-Log "RETAINED ON PHONE (duplicate=$duplicate): $path"
                        $observed[$path].Reported = $true
                        $observed[$path].Local = $local
                        $observed[$path].Hash = $hash
                    }
                } catch { Write-Log "RETRY LATER: $path -- $($_.Exception.Message)" }
                finally { if ($temp -and (Test-Path -LiteralPath $temp)) { Remove-Item -LiteralPath $temp -Force } }
            }
            foreach ($path in @($observed.Keys)) { if (-not $presentPhone.Contains($path)) { $observed.Remove($path) | Out-Null } }
            $lastError = ''
        } catch {
            $observed.Clear() # Re-establish stability after disconnection/error.
            $message = $_.Exception.Message
            if ($message -ne $lastError) { Write-Log "WAITING: $message"; $lastError = $message }
            if ($Once) { throw }
        }
        if ($Once) {
            if (-not $onceWarmup) { break }
            $onceWarmup = $false
            Start-Sleep -Seconds $StableSeconds
        } else { Start-Sleep -Seconds $PollSeconds }
    } while ($true)
} finally { if ($lock) { $lock.Dispose() } }
