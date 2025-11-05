# === NO EDIT BELOW THIS LINE ===
$TargetPath = "C:\www"
$CacheRoot  = "C:\ProgramData\GitCache"
$LogPath    = "C:\Logs\GitToWWW.log"
$ErrorActionPreference = "Stop"
# === EDIT ME (public repo only) ===
$RepoUrl  = "https://github.com/673cpts-design/DigitalSign.git"  # repo URL (public)
$Branch   = "main"                                               # main or master
$SubPath  = "HQ.Map.Cyber"                                                   # "" = whole repo; e.g. "deploy/kiosk" for subfolder

# === NO EDIT BELOW THIS LINE ===
$TargetPath = "C:\www"                          # destination (never purged)
$CacheRoot  = "C:\ProgramData\GitCache"         # local git working copy
$LogPath    = "C:\Logs\GitToWWW.log"
$ErrorActionPreference = "Stop"

# ---------- Logging ----------
$logDir = Split-Path -Parent $LogPath
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
function Write-Log([string]$Msg) { Add-Content -Path $LogPath -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Msg" }

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
    $ErrorActionPreference = 'Continue'  # avoid NativeCommandError on stderr
    if ($WorkDir) { Push-Location $WorkDir; try { $output = & $Exe @Args 2>&1 } finally { Pop-Location } }
    else { $output = & $Exe @Args 2>&1 }
    $code = $LASTEXITCODE
  } finally { $ErrorActionPreference = $oldEAP }

  if ($output) { Write-Log ($output -join "`n") }
  if ($code -ne 0) { throw "External failed ($code): $cmdForLog`n$($output -join "`n")" }
  return ($output -join "`n")
}

# Git with -C
function GitC { param([string]$WorkDir,[string[]]$GitArgs) Run-External -Exe $gitExe -Args (@("-C",$WorkDir)+$GitArgs) -LogCmd }

# ---------- Paths ----------
$RepoName = (($RepoUrl -replace '^https?://github\.com/','') -replace '\.git$','') -replace '[^A-Za-z0-9._-]','_'
$RepoRoot = Join-Path $CacheRoot $RepoName
foreach ($p in @($CacheRoot, $RepoRoot, $TargetPath)) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }

# normalize SubPath for later
$SubPath = [string]$SubPath
if ($SubPath) { $SubPath = ($SubPath -replace '\\','/').Trim('/') }

# ---------- Clone or configure (cache only; never touches C:\www directly) ----------
if (-not (Test-Path (Join-Path $RepoRoot ".git"))) {
  Write-Log ("Fresh clone -> {0}" -f $RepoUrl)
  $parent = Split-Path -Parent $RepoRoot
  if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  Run-External -Exe $gitExe -Args @("clone","--depth=1","--branch",$Branch,"--single-branch",$RepoUrl,$RepoRoot) -WorkDir $parent -LogCmd
} else {
  Write-Log "Existing repo detected."
  GitC $RepoRoot @("remote","set-url","origin",$RepoUrl)
  $cur = (GitC $RepoRoot @("rev-parse","--abbrev-ref","HEAD")).Trim()
  if ($cur -ne $Branch) {
    GitC $RepoRoot @("fetch","origin",$Branch)
    Run-External -Exe $gitExe -Args @("-C",$RepoRoot,"checkout","-B",$Branch,"--track","origin/$Branch") -LogCmd
  }
}

# ---------- Fetch & update cache (remote wins) ----------
GitC $RepoRoot @("fetch","--depth=1","origin",$Branch)
$localHash  = (GitC $RepoRoot @("rev-parse","HEAD")).Trim()
$remoteHash = (GitC $RepoRoot @("rev-parse","origin/$Branch")).Trim()
if ($localHash -ne $remoteHash) {
  Write-Log ("Update detected. Local: {0} Remote: {1}" -f $localHash,$remoteHash)
  GitC $RepoRoot @("reset","--hard","origin/$Branch")
  GitC $RepoRoot @("clean","-fdx")   # cleans ONLY the cache under ProgramData, never C:\www
} else {
  Write-Log ("Already up-to-date at commit: {0}" -f $localHash)
}

# ---------- NON-DESTRUCTIVE copy into C:\www (never purge) ----------
if ($SubPath) {
  $source = Join-Path $RepoRoot $SubPath
  if (-not (Test-Path $source)) { throw ("SubPath does not exist on branch '{0}': {1}" -f $Branch, $SubPath) }
  Write-Log ("Copying SUBFOLDER {0} -> {1} (no deletions)..." -f $source, $TargetPath)
  $null = robocopy $source $TargetPath *.* /E /XO /XN /XC /R:1 /W:1 /NFL /NDL /NP /NJH /NJS
  # /E  = include subdirs
  # /XO /XN /XC = skip older, newer, or same files (copies when different)
} else {
  $source = $RepoRoot
  $excludeGit = Join-Path $RepoRoot ".git"
  Write-Log ("Copying WHOLE REPO {0} -> {1} (no deletions)..." -f $source, $TargetPath)
  $null = robocopy $source $TargetPath *.* /E /XO /XN /XC /R:1 /W:1 /NFL /NDL /NP /NJH /NJS /XD $excludeGit
}
$rc = $LASTEXITCODE
Write-Log ("Robocopy exit code: {0}" -f $rc)
if ($rc -ge 8) { throw ("Robocopy failed with code {0}" -f $rc) }

# ---------- Done ----------
$newHash = (GitC $RepoRoot @("rev-parse","HEAD")).Trim()
Write-Log ("Safe sync complete - now at commit {0}" -f $newHash)
exit 0
