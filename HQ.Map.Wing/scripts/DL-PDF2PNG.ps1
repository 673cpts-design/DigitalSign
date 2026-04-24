# ================== CONFIGURATION ==================

$baseOutputPath = "C:\www\images"

$presentations = @(
    @{
        Name = 'floor3'
        Url  = 'https://docs.google.com/presentation/d/18tYZxpWPqLwVKIMbV7HaVFJoH3oXHnyCCH3l_UDvg2M/edit?'
    },
    @{
        Name = 'floor2'
        Url  = 'https://docs.google.com/presentation/d/1BxjwlmH1H5yCGosD9WZs0AxU96QbDPElHQf4KBSWWf0/edit?'
    },
        @{
        Name = 'floor1'
        Url  = 'https://docs.google.com/presentation/d/14UB8D8aLf2tBk7GCgvEBvSI25qXAshxbfIE6dhccUtA/edit?'
    },
    @{
        Name = 'floorb'
        Url  = 'https://docs.google.com/presentation/d/1a8uoe1iU8-KQkvWXOJ9cVSL1DyZkYD7Yl8AE5Hdsv2o/edit?'
    },
)

# ================== FUNCTIONS ==================

function Get-GSlidesFileId {
    param([string]$Url)

    try { $uri = [Uri]$Url } catch { return $null }

    $match = [regex]::Match($uri.AbsolutePath, '/presentation/d/([^/]+)/')
    if ($match.Success) { return $match.Groups[1].Value }

    return $null
}

function Download-GSlidesPdf {
    param(
        [string]$FileId,
        [string]$OutputFolder
    )

    $pdfUrl = "https://docs.google.com/presentation/d/$FileId/export/pdf"
    $pdfOut = Join-Path $OutputFolder "slides.pdf"

    Write-Host "  -> Downloading PDF to $pdfOut"

    try {
        Invoke-WebRequest -UseBasicParsing -Uri $pdfUrl -OutFile $pdfOut -ErrorAction Stop
        return $pdfOut
    }
    catch {
        Write-Warning "  !! Failed to download PDF for fileId $FileId. Error: $($_.Exception.Message)"
        return $null
    }
}

function Convert-PdfToPng {
    param(
        [string]$PdfPath,
        [string]$OutputFolder,
        [int]$Density = 288
    )

    if (-not (Test-Path $PdfPath)) {
        Write-Warning "  PDF not found: $PdfPath"
        return
    }

    if (-not (Test-Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    }

    $baseName = "slide"
    $outPattern = Join-Path $OutputFolder "$baseName-%03d.png"

    Write-Host "  -> Converting PDF to PNGs in $OutputFolder"

    & magick -density $Density $PdfPath -background white -alpha remove -alpha off $outPattern

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "  !! ImageMagick conversion failed (exit $LASTEXITCODE)"
    } else {
        Write-Host "  -> PNG conversion complete."
    }
}

# ================== MAIN LOOP ==================

foreach ($p in $presentations) {

    Write-Host "`n=== Processing '$($p.Name)' ==="

    $fileId = Get-GSlidesFileId -Url $p.Url
    if (-not $fileId) {
        Write-Warning "Could not extract fileId from URL: $($p.Url)"
        continue
    }

    # MAIN folder (PNGs go here)
    $mainFolder = Join-Path $baseOutputPath $p.Name

    # PDF subfolder
    $pdfFolder  = Join-Path $mainFolder "pdf"

    # Ensure folders exist
    if (-not (Test-Path $mainFolder)) { New-Item -ItemType Directory -Path $mainFolder | Out-Null }
    if (-not (Test-Path $pdfFolder))  { New-Item -ItemType Directory -Path $pdfFolder  | Out-Null }

    # CLEAN PDF folder (slides.pdf only)
    Get-ChildItem $pdfFolder -Recurse -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

    # CLEAN OLD PNG FILES IN MAIN FOLDER
    Write-Host "  -> Removing old PNG files in $mainFolder"
    Get-ChildItem $mainFolder -Filter "slide-*.png" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

    # 1) Download the PDF
    $pdfPath = Download-GSlidesPdf -FileId $fileId -OutputFolder $pdfFolder
    if (-not $pdfPath) { continue }

    # 2) Convert PDF → PNG in main folder
    Convert-PdfToPng -PdfPath $pdfPath -OutputFolder $mainFolder -Density 288
}

Write-Host "`nDone."
