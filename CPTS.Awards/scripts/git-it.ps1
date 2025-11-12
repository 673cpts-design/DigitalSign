$RepoUrl  = "https://github.com/673cpts-design/DigitalSign.git"  # public repo URL
$Branch   = "main"                                               # main or master
$SubPath  = "CPTS.Awards"                                       # "" = whole repo; e.g. "deploy/kiosk" (FLATTEN into C:\www)

# === NO EDIT BELOW THIS LINE ===
$TargetRoot = "C:\www"
$CacheRoot  = "C:\ProgramData\GitCache"
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

# ---------- Helper: run native safely ----------
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
    if ($WorkDir) { Push-Location $WorkDir; try { $output = & $Exe @Args 2>&1 } finally { Pop-Location } }
    else { $output = & $Exe @Args 2>&1 }
    $code = $LASTEXITCODE
  } finally { $ErrorActionPreference = $oldEAP }

  if ($output) { Write-Log ($output -join "`n") }
  if ($code -ne 0) { throw "External failed ($code): $cmdForLog`n$($output -join "`n")" }
  return ($output -join "`n")
}
function GitC { param([string]$WorkDir,[string[]]$GitArgs) Run-External -Exe $gitExe -Args (@("-C",$WorkDir)+$GitArgs) -LogCmd }

# ---------- Paths ----------
$RepoName = (($RepoUrl -replace '^https?://github\.com/','') -replace '\.git$','') -replace '[^A-Za-z0-9._-]','_'
$RepoRoot = Join-Path $CacheRoot $RepoName
foreach ($p in @($CacheRoot,$RepoRoot,$TargetRoot)) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }

# Normalize subpath
$SubPath = [string]$SubPath
$WantSparse = $false
if ($SubPath) { $SubPath = ($SubPath -replace '\\','/').Trim('/'); $WantSparse = $true }

# ---------- Clone (partial) or ensure config ----------
if (-not (Test-Path (Join-Path $RepoRoot ".git"))) {
  Write-Log ("Fresh partial clone -> {0}" -f $RepoUrl)
  $parent = Split-Path -Parent $RepoRoot
  if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

  if ($WantSparse) {
    Run-External -Exe $gitExe -Args @(
      "clone","--filter=blob:none","--no-checkout","--no-tags",
      "--branch",$Branch,"--single-branch",$RepoUrl,$RepoRoot
    ) -WorkDir $parent -LogCmd
    GitC $RepoRoot @("sparse-checkout","init","--cone")
    GitC $RepoRoot @("sparse-checkout","set",$SubPath)
  } else {
    Run-External -Exe $gitExe -Args @(
      "clone","--filter=blob:none","--no-tags",
      "--branch",$Branch,"--single-branch",$RepoUrl,$RepoRoot
    ) -WorkDir $parent -LogCmd
  }
} else {
  Write-Log "Existing repo detected."
  GitC $RepoRoot @("remote","set-url","origin",$RepoUrl)
  if ($WantSparse) {
    $cfg = ""
    try { $cfg = (GitC $RepoRoot @("config","--get","core.sparseCheckout")).Trim() } catch {}
    if ($cfg -ne "true") { GitC $RepoRoot @("sparse-checkout","init","--cone") }
    GitC $RepoRoot @("sparse-checkout","set",$SubPath)
  } else {
    try { GitC $RepoRoot @("sparse-checkout","disable") } catch {}
  }
}

# ---------- Fetch latest (shallow, no tags) & reset ----------
GitC $RepoRoot @("fetch","--depth=1","--no-tags","origin",$Branch)
GitC $RepoRoot @("reset","--hard","origin/$Branch")

# ---------- Define source/destination ----------
if ($WantSparse) {
  # SOURCE = the subpath inside the repo; DESTINATION = C:\www (FLATTEN)
  $src = Join-Path $RepoRoot $SubPath
  if (-not (Test-Path $src)) { throw ("SubPath does not exist on branch '{0}': {1}" -f $Branch,$SubPath) }
  $dst = $TargetRoot      # <— FLATTEN: copy contents of $SubPath into C:\www
} else {
  # Whole repo → C:\www
  $src = $RepoRoot
  $dst = $TargetRoot
}
if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Force -Path $dst | Out-Null }

# ---------- HASH-BASED, NON-DESTRUCTIVE COPY (remote overwrites changed files only) ----------
$srcFiles = Get-ChildItem $src -Recurse -File -ErrorAction Stop
foreach ($f in $srcFiles) {
  # Skip .git metadata if copying whole repo
  if (-not $WantSparse) {
    $gitMeta = Join-Path $RepoRoot ".git"
    if ($f.FullName.StartsWith($gitMeta,[System.StringComparison]::OrdinalIgnoreCase)) { continue }
  }

  $rel = $f.FullName.Substring($src.Length).TrimStart('\','/')
  $destFile = Join-Path $dst $rel
  $destDir  = Split-Path $destFile
  if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }

  $copy = $true
  if (Test-Path $destFile) {
    try {
      $hSrc = (Get-FileHash $f.FullName -Algorithm SHA256).Hash
      $hDst = (Get-FileHash $destFile -Algorithm SHA256).Hash
      if ($hSrc -eq $hDst) { $copy = $false }
    } catch { $copy = $true }
  }
  if ($copy) {
    Write-Log ("Updating {0}" -f $rel)
    Copy-Item $f.FullName $destFile -Force
  }
}

# ---------- Done ----------
$new = (GitC $RepoRoot @("rev-parse","HEAD")).Trim()
Write-Log ("SAFE HASH SYNC (FLATTEN SUBPATH) COMPLETE @ {0}" -f $new)
exit 0
