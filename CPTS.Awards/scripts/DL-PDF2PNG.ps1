# ================== CONFIGURATION ==================

$baseOutputPath = "C:\www\images"

$presentations = @(
    @{
        Name = 'Leadership'
        Url  = 'https://docs.google.com/presentation/d/1_bZLH2Zl4eYf8yGnEUyjgkHUJrmMs9kgNxes24tpY0E/edit?'
    },
    @{
        Name = 'Quarter1'
        Url  = 'https://docs.google.com/presentation/d/1EY6EOeD7cyvaEyL2X5P1SdzFBop29q6vpEu3nG4qCpQ/edit?'
    },
    @{
        Name = 'Quarter2'
        Url  = 'https://docs.google.com/presentation/d/1fwFDb59l5lzGgbqNLmhIy11WykN9Z35fWgb0vFWj2rs/edit?'
    },
    @{
        Name = 'Quarter3'
        Url  = 'https://docs.google.com/presentation/d/1rJIGLcvryB8hg3E3VoVfHzXwz0VgeQXFgswUGujVaNE/edit?'
    },
    @{
        Name = 'Quarter4'
        Url  = 'https://docs.google.com/presentation/d/16KSbkc76muL0oR1MVWuOWBL-25Z2IajLZLL2_6RLc_g/edit?'
    },
    @{
        Name = 'Year'
        Url  = 'https://docs.google.com/presentation/d/1o9JSK93OGBsLte6HQei69oLClterIoN43mU9GkohJAA/edit?'
    },
    @{
        Name = 'YearSideBar'
        Url  = 'https://docs.google.com/presentation/d/1s5fK-gRDrT9C-Xnn2KJeCtKlaBYOnvTxdCJfKI7OscM/edit?'
    },
    @{
        Name = 'Who'
        Url  = 'https://docs.google.com/presentation/d/1uyvgSv2c1evHjVMBxg9L6oudS4neHCxEejk6bKvTPrg/edit?'
    }
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

