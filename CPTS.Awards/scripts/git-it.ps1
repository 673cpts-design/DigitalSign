$RepoUrl = "https://github.com/673cpts-design/DigitalSign.git"  # Public repo URL
$Branch  = "main"                                               # main or master
$SubPath = "CPTS.Awards"                                        # "" = whole repo; contents copied into C:\www

$Destination = "C:\www"
$TempRepo    = Join-Path $env:TEMP "DigitalSign-Download"

# Remove previous temporary copy if it exists
if (Test-Path $TempRepo) {
    Remove-Item $TempRepo -Recurse -Force
}

# Make sure destination exists
if (-not (Test-Path $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

# Download repository
git clone --depth 1 --branch $Branch $RepoUrl $TempRepo

if ($LASTEXITCODE -ne 0) {
    Write-Error "Git clone failed."
    exit 1
}

# Determine which folder to copy
if ([string]::IsNullOrWhiteSpace($SubPath)) {
    $Source = $TempRepo
}
else {
    $Source = Join-Path $TempRepo $SubPath
}

if (-not (Test-Path $Source)) {
    Write-Error "Repository path does not exist: $SubPath"
    Remove-Item $TempRepo -Recurse -Force
    exit 1
}

# Copy files and folders into C:\www
# Existing matching files are replaced.
# Files already in C:\www that are NOT in the repository are left alone.
robocopy $Source $Destination /E /COPY:DAT /DCOPY:DAT /R:2 /W:1

# Robocopy exit codes 0-7 are successful
if ($LASTEXITCODE -ge 8) {
    Write-Error "Robocopy failed with exit code $LASTEXITCODE."
    Remove-Item $TempRepo -Recurse -Force
    exit 1
}

# Clean up temporary repository
Remove-Item $TempRepo -Recurse -Force

Write-Host "Repository files successfully updated in $Destination"
