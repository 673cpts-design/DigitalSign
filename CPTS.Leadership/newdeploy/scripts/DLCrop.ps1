
$ErrorActionPreference = "Stop"

# Configuration
$PresentationID = "1mD_ivL2qRvdjMdTPU3PX-NMztCLrYcz5WK4fu3kAP0I"
$OutputFolder   = "C:\www\images\Slides"
$PdfFile        = Join-Path $OutputFolder "slides.pdf"

$BorderColor = "#00308F"
$Fuzz        = "3%"
$Density     = 200

# Set to $true to skip the first PDF page
$SkipFirstPage = $false

# Prepare output directory
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

# Verify ImageMagick
if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    throw "ImageMagick is not installed or is missing from PATH."
}

# Download Google Slides PDF
$Url = "https://docs.google.com/presentation/d/$PresentationID/export/pdf"

Write-Host "Downloading Google Slides PDF..."
Invoke-WebRequest -Uri $Url -OutFile $PdfFile

# Verify PDF signature
$Stream = [System.IO.File]::OpenRead($PdfFile)
try {
    $Header = [byte[]]::new(4)
    $Read = $Stream.Read($Header, 0, 4)
}
finally {
    $Stream.Dispose()
}

if ($Read -ne 4 -or
    [System.Text.Encoding]::ASCII.GetString($Header) -ne "%PDF") {
    throw "Download was not a valid PDF. Check Google Slides sharing permissions."
}

# Remove previous PNG files
Get-ChildItem $OutputFolder -Filter "slide-*.png" -File |
    Remove-Item -Force

# Convert PDF to PNG
Write-Host "Converting PDF pages..."

$PdfInput = if ($SkipFirstPage) {
    "$PdfFile" + "[1--1]"
}
else {
    $PdfFile
}

$TempPattern = Join-Path $OutputFolder "temp-%03d.png"

& magick -density $Density $PdfInput `
    -background white -alpha remove -alpha off `
    $TempPattern

if ($LASTEXITCODE -ne 0) {
    throw "ImageMagick PDF conversion failed."
}

# Crop border from each image
Write-Host "Cropping border color $BorderColor..."

$Images = @(Get-ChildItem $OutputFolder -Filter "temp-*.png" |
    Sort-Object Name)

if ($Images.Count -eq 0) {
    throw "No PNG images were generated."
}

$Index = 0

foreach ($Image in $Images) {

    $OutputName = "slide-{0:D3}.png" -f $Index
    $OutputPath = Join-Path $OutputFolder $OutputName

    & magick $Image.FullName `
        -bordercolor $BorderColor -border 1 `
        -fuzz $Fuzz `
        -trim +repage `
        $OutputPath

    if ($LASTEXITCODE -ne 0) {
        throw "Cropping failed for $($Image.Name)"
    }

    Remove-Item $Image.FullName -Force

    Write-Host "Created $OutputName"
    $Index++
}

Write-Host "Completed: $Index slides"
Write-Host "Output: $OutputFolder"
