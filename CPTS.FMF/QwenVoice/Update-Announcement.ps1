#Requires -Version 5.1
<#
B4 selects the voice. A10 downward contains ZIP links; B10 downward contains names.
Cached voices are stored in C:\www\QwenVoice\Voice\<name>.
Requires voice-cache.py beside this script. All existing Qwen settings are preserved
except reference/reference_transcript, which are updated to the selected voice.
Do not run manual generation simultaneously; both use the same settings and script.
#>
[CmdletBinding()]
param(
    [string]$SpreadsheetUrl = 'https://docs.google.com/spreadsheets/d/1ge4tshahkIFMDR3Og9cm76dtwfJq_jam_SpVYqfNxwA/edit?gid=0',
    [string]$QwenFolder = $PSScriptRoot,
    [string]$WebFolder = 'C:\www'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$lock = $null
$stageWav = $null
$stageHtml = $null
$log = $null
$selectionFile = $null
$settingsTemp = $null
function Publish-File([string]$Source, [string]$Target) {
    # Both paths are on the same volume. Replacement is atomic for each file.
    if ([IO.File]::Exists($Target)) {
        # Windows PowerShell 5.1 can convert $null to an empty string for this
        # .NET string argument. Supply a real, unique backup path instead.
        $backup = $Target + '.' + [Guid]::NewGuid().ToString('N') + '.bak'
        [IO.File]::Replace($Source, $Target, $backup)
        # Only remove the backup after Replace succeeds.
        Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
    }
    else { [IO.File]::Move($Source, $Target) }
}
function Write-Status([string]$Message) {
    $line = ('{0:u} {1}' -f [DateTime]::Now, $Message)
    Write-Host $line
    if ($log) { [IO.File]::AppendAllText($log, $line + [Environment]::NewLine, $utf8) }
}
try {
    if ($SpreadsheetUrl -notmatch '^https://docs\.google\.com/spreadsheets/d/([A-Za-z0-9_-]+)(?:/|$|[?#])') {
        throw 'Set SpreadsheetUrl at the top of this file to your Google spreadsheet URL.'
    }
    $sheetId = $Matches[1]
    $gid = '0'
    if ($SpreadsheetUrl -match '[#?&]gid=(\d+)') { $gid = $Matches[1] }
    $python = Join-Path $QwenFolder '.venv\Scripts\python.exe'
    $generator = Join-Path $QwenFolder 'generate.py'
    $settingsPath = Join-Path $QwenFolder 'settings.json'
    foreach ($file in @($python, $generator, $settingsPath)) {
        if (-not [IO.File]::Exists($file)) { throw "Required file missing: $file" }
    }
    # File sharing lock also works across interactive and scheduled Windows sessions.
    $lock = [IO.File]::Open((Join-Path $QwenFolder 'sheet-update.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    [IO.Directory]::CreateDirectory($WebFolder) | Out-Null
    $logs = Join-Path $QwenFolder 'logs'
    [IO.Directory]::CreateDirectory($logs) | Out-Null
    $log = Join-Path $logs ('sheet-update-{0}.log' -f (Get-Date -Format 'yyyy-MM-dd'))
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $nonce = [Guid]::NewGuid().ToString('N')
    $helper = Join-Path $PSScriptRoot 'voice-cache.py'
    if (-not [IO.File]::Exists($helper)) { throw "Required file missing: $helper" }
    $selectionFile = Join-Path $QwenFolder ('.selection-' + $nonce + '.json')
    Write-Status 'Reading message, playback switch, and selected voice from Google Sheets.'
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $python $helper --sheet-url $SpreadsheetUrl --voice-root (Join-Path $QwenFolder 'Voice') --result $selectionFile 2>&1 | ForEach-Object {
            Write-Status $_.ToString()
        }
        $selectionCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $savedPreference }
    if ($selectionCode -ne 0 -or -not [IO.File]::Exists($selectionFile)) {
        throw 'Could not prepare the selected voice. Previous HTML and WAV retained. See the error above.'
    }
    $selection = Get-Content -LiteralPath $selectionFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $message = [string]$selection.message
    $play = [string]$selection.play
    Write-Status ("Selected voice: " + $selection.voice)
    $cfg = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $settingsBackup = Join-Path $QwenFolder 'settings.before-voice-selection.json'
    if (-not [IO.File]::Exists($settingsBackup)) {
        [IO.File]::Copy($settingsPath, $settingsBackup, $false)
    }
    $cfg | Add-Member -NotePropertyName reference -NotePropertyValue ([IO.Path]::Combine('Voice', [string]$selection.voice, [IO.Path]::GetFileName([string]$selection.reference))) -Force
    $cfg | Add-Member -NotePropertyName reference_transcript -NotePropertyValue ([IO.Path]::Combine('Voice', [string]$selection.voice, 'reference.txt')) -Force
    $settingsTemp = Join-Path $QwenFolder ('.settings-' + $nonce + '.json')
    [IO.File]::WriteAllText($settingsTemp, ($cfg | ConvertTo-Json -Depth 100), $utf8)
    Publish-File $settingsTemp $settingsPath
    $scriptName = [string]$cfg.script
    if ([string]::IsNullOrWhiteSpace($scriptName)) { throw 'settings.json has no script path.' }
    $scriptPath = if ([IO.Path]::IsPathRooted($scriptName)) { $scriptName } else { Join-Path $QwenFolder $scriptName }
    [IO.File]::WriteAllText($scriptPath, $message, $utf8)
    $stageWav = Join-Path $WebFolder ('.message-' + $nonce + '.wav')
    $stageHtml = Join-Path $WebFolder ('.closed-' + $nonce + '.html')
    Write-Status "Generating speech. Playback selection: $play."
    # No shell evaluation of spreadsheet content: text is only written to a file.
    # Native program stderr can be normal progress on Windows PowerShell 5.1.
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $python $generator --output $stageWav 2>&1 | ForEach-Object {
            $line = $_.ToString()
            Write-Host $line
            [IO.File]::AppendAllText($log, $line + [Environment]::NewLine, $utf8)
        }
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $savedPreference }
    if ($code -ne 0) { throw "Voice generation failed (exit $code). Previous output retained; see $log" }
    if (-not [IO.File]::Exists($stageWav)) { throw 'Generator did not produce an audio file.' }
    if ((Get-Item -LiteralPath $stageWav).Length -le 44) { throw 'Generated WAV is empty.' }
    $html = @'
<!DOCTYPE html>
<html>
<head>
	<style>
	.google1-container {
		position: absolute;
		top: 0px;
   		left: 8px;
		overflow: hidden;
		background: none;
		border: none;
		outline: none;
		scrolling: no;
		z-index: 1;
		}

	.google1-container iframe {
		overflow: hidden;
		scrolling: no;
		}
	.google2-container {
		position: absolute;
		top: 1897px;
   		left: 8px;
		overflow: hidden;
		background: none;
		border: none;
		outline: none;
		scrolling: no;
		z-index: 2;
		}

	.google2-container iframe {
		overflow: hidden;
		scrolling: no;
		}

    #Template-image {
      position: fixed;
      top: 0px;
      left: 0px;
      z-index: 9;
	}

	</style>
</head>
<body>
<img id="Template-image" src="New-FMF-Template-I.png" alt="Overlay Image">

<div class="google1-container">
<iframe src="https://docs.google.com/presentation/d/e/2PACX-1vShJvOZzGHTx0IRPp2jt0Z6JaGw2wj9ZPMgLEPESMdRs3Ccc1pbjtE7GdTuHqcO0A8MQzGezC65kKMS/pubembed?start=true&loop=true&delayms=60000" frameborder="0" width="2144" height="1939" allowfullscreen="true" mozallowfullscreen="true" webkitallowfullscreen="true"></iframe>
</div>



<div class="google2-container">
<iframe src="https://docs.google.com/presentation/d/e/2PACX-1vSDUkh-c96gxA5UyOMLeE0dwVhZEeDNAjhK5MHX0_jY0El0y7wZxzowl_N-c2JRV4F0yuDWIzaE4Fs_/pubembed?start=true&loop=true&delayms=60000" frameborder="0" width="2144" height="1939" allowfullscreen="true" mozallowfullscreen="true" webkitallowfullscreen="true"></iframe>
</div>

</body>
</html>
'@
    if ($play -in @('yes', 'on')) {
        $version = (Get-FileHash -LiteralPath $stageWav -Algorithm SHA256).Hash.Substring(0,16)
        $player = @"
<audio id="announcement" src="message.wav?v=$version" autoplay loop preload="auto" style="display:none" aria-hidden="true"></audio>
<script>
(function () {
    const player = document.getElementById('announcement');
    function start() {
        player.play().catch(function (error) {
            console.warn('Announcement autoplay blocked; allow autoplay or interact with this page.', error);
        });
    }
    start();
    document.addEventListener('click', start, {once: true});
    document.addEventListener('keydown', start, {once: true});
})();
</script>
"@
        $html = $html.Replace('</body>', $player + "`r`n</body>")
    }
    [IO.File]::WriteAllText($stageHtml, $html, $utf8)
    # Publish only after generation completes. Two file replacements are not a
    # single transaction; audio goes first so the HTML never points at unfinished audio.
    Publish-File $stageWav (Join-Path $WebFolder 'message.wav')
    Publish-File $stageHtml (Join-Path $WebFolder 'closed.html')
    Write-Status 'Done: C:\www output updated. Reload the display page to apply it.'
    exit 0
} catch {
    Write-Host ('FAILED: ' + $_.Exception.Message) -ForegroundColor Red
    if ($log) { try { [IO.File]::AppendAllText($log, "FAILED: $_`r`n", $utf8) } catch {} }
    exit 1
} finally {
    foreach ($temporary in @($stageWav, $stageHtml, $selectionFile, $settingsTemp)) {
        if ($temporary -and [IO.File]::Exists($temporary)) {
            Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
        }
    }
    if ($lock) { $lock.Dispose() }
}
