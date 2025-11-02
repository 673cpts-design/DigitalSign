# === EDIT ME (public repo only) ===
$RepoUrl  = "https://github.com/673cpts-design/DigitalSign.git"  # repo URL
$Branch   = "main"                                               # main or master
$SubPath  = "HQ.Map.Cyber"                                                   # "" = whole repo; or e.g. "deploy/kiosk"

# === NO EDIT BELOW THIS LINE ===
$TargetPath = "C:\www"
$CacheRoot  = "C:\ProgramData\GitCache"
$LogPath    = "C:\Logs\GitToWWW.log"
$ErrorActionPreference = "Stop"

# ---------- Logging ----------
$logDir = Split-Path -Parent $LogPath
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
function Write-Log([string]$Msg) {
  Add-Content -Path $LogPath -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Msg"
}

# ---------- Validate ----------
if ([string]::IsNullOrWhiteSpace($RepoUrl)) { throw "RepoUrl is empty." }
if ([string]::IsNullOrWhiteSpace($Branch))  { throw "Branch is empty." }

# ---------- Locate git ----------
$gitExe = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
if (-not $gitExe) { throw "Git not found. Install Git for Windows." }

# ---------- Helper: native command runner (PS5-safe) ----------
function Run-External {
  param(
    [Parameter(Mandatory=$true)][string]$Exe,
    [Parameter(Mandatory=$true)][string[]]$Args,
    [string]$WorkDir = $null,
    [switch]$LogCmd
  )
  $Args = @($Args | Where-Object { $_ -and $_.ToString().Trim() -ne "" })
  if ($Args.Count -lt 1) { throw "Run-External: empty argument list." }
  $cmdForLog = if ($WorkDir) { "cd `"$WorkDir`" && `"$Exe`" " + ($Args -join ' ') } else { "`"$Exe`" " + ($Args -join ' ') }
  if ($LogCmd) { Write-Log $cmdForLog }

  $oldEAP = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    if ($WorkDir) {
      Push-Location $WorkDir
      try { $output = & $Exe @Args 2>&1 } finally { Pop-Location }
    } else {
      $output = & $Exe @Args 2>&1
    }
    $code = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $oldEAP
  }

  if ($output) { Write-Log ($output -join "`n") }
  if ($code -ne 0) { throw "External failed ($code): $cmdForLog`n$($output -join "`n")" }
  return ($output -join "`n")
}

function GitC {
  param(
    [Parameter(Mandatory=$true)][string]$WorkDir,
    [Parameter(Mandatory=$true)][string[]]$GitArgs
  )
  $full = @("-C", $WorkDir) + $GitArgs
  Run-External -Exe $gitExe -Args $full -LogCmd
}

# ---------- Paths ----------
$RepoName = (($RepoUrl -replace '^https?://github\.com/','') -replace '\.git$','') -replace '[^A-Za-z0-9._-]','_'
$RepoRoot = Join-Path $CacheRoot $RepoName
foreach ($p in @($CacheRoot, $RepoRoot, $TargetPath)) {
  if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

# normalize SubPath for later
$SubPath = [string]$SubPath
if ($SubPath) {
  $SubPath = ($SubPath -replace '\\','/').Trim('/')
}

# ---------- Clone or configure ----------
if (-not (Test-Path (Join-Path $RepoRoot ".git"))) {
  Write-Log ("Fresh clone -> {0}" -f $RepoUrl)
  $parent = Split-Path -Parent $RepoRoot
  if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  Run-External -Exe $gitExe -Args @("clone","--depth=1","--branch",$Branch,"--single-branch",$RepoUrl,$RepoRoot) -WorkDir $parent -LogCmd
} else {
  Write-Log "Existing repo detected."
  GitC -WorkDir $RepoRoot -GitArgs @("remote","set-url","origin",$RepoUrl)

  $curBranch = (GitC -WorkDir $RepoRoot -GitArgs @("rev-parse","--abbrev-ref","HEAD")).Trim()
  if ($curBranch -ne $Branch) {
    GitC -WorkDir $RepoRoot -GitArgs @("fetch","origin",$Branch)
    Run-External -Exe $gitExe -Args @("-C",$RepoRoot,"checkout","-B",$Branch,"--track","origin/$Branch") -LogCmd
  }
}

# ---------- Fetch & update (remote wins) ----------
GitC -WorkDir $RepoRoot -GitArgs @("fetch","--depth=1","origin",$Branch)

$localHash  = (GitC -WorkDir $RepoRoot -GitArgs @("rev-parse","HEAD")).Trim()
$remoteHash = (GitC -WorkDir $RepoRoot -GitArgs @("rev-parse","origin/$Branch")).Trim()

if ($localHash -ne $remoteHash) {
  Write-Log ("Update detected. Local: {0} Remote: {1}" -f $localHash,$remoteHash)
  GitC -WorkDir $RepoRoot -GitArgs @("reset","--hard","origin/$Branch")
  GitC -WorkDir $RepoRoot -GitArgs @("clean","-fdx")
} else {
  Write-Log ("Already up-to-date at commit: {0}" -f $localHash)
}

# ---------- Mirror selection -> C:\www ----------
$source = $RepoRoot
if ($SubPath) {
  $source = Join-Path $RepoRoot $SubPath
  if (-not (Test-Path $source)) {
    Write-Log ("ERROR: SubPath not found in repo: {0}" -f $source)
    throw ("SubPath does not exist on branch '{0}': {1}" -f $Branch, $SubPath)
  }
  Write-Log ("Mirroring SUBFOLDER {0} -> {1} ..." -f $source, $TargetPath)
  # when copying a subfolder, .git is not inside $source, so no /XD needed
  $null = robocopy $source $TargetPath *.* /MIR /R:1 /W:1 /NFL /NDL /NP /NJH /NJS
} else {
  Write-Log ("Mirroring WHOLE REPO {0} -> {1} ..." -f $RepoRoot, $TargetPath)
  $excludeGit = Join-Path $RepoRoot ".git"
  $null = robocopy $RepoRoot $TargetPath *.* /MIR /R:1 /W:1 /NFL /NDL /NP /NJH /NJS /XD $excludeGit
}
$rc = $LASTEXITCODE
Write-Log ("Robocopy exit code: {0}" -f $rc)
if ($rc -ge 8) { throw ("Robocopy failed with code {0}" -f $rc) }

# ---------- Done ----------
$newHash = (GitC -WorkDir $RepoRoot -GitArgs @("rev-parse","HEAD")).Trim()
Write-Log ("Sync complete - now at commit {0}" -f $newHash)
exit 0
