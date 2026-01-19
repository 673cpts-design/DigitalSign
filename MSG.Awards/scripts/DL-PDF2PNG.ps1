# ================== CONFIGURATION ==================

$baseOutputPath = "C:\www\images"

$presentations = @(
    @{
        Name = 'Leadership'
        Url  = 'https://docs.google.com/presentation/d/1oR0K3nHUMKLrM5H6vjlXo4WXLnjDlQh5NFumJO564LM/edit?'
    },
    @{
        Name = 'Quarter1'
        Url  = 'https://docs.google.com/presentation/d/1jCFz3F6sW9dQal7sFOc3B_SDp7xqV1rrDAK2M4E25sc/edit?'
    },
    @{
        Name = 'Quarter2'
        Url  = 'https://docs.google.com/presentation/d/1JHFfUtRZpVK45EEe5agyRMiWRf7f_ZKWIbseQR9i-bE/edit?'
    },
    @{
        Name = 'Quarter3'
        Url  = 'https://docs.google.com/presentation/d/1_divCdzgPbeLa0g78mFODvDk2NFj7fPqFtU3-L46ZU8/edit?'
    },
    @{
        Name = 'Quarter4'
        Url  = 'https://docs.google.com/presentation/d/1owPg1QHBMnokEVZXIMEQ87Mu4il2KrNFdCevMQTedbU/edit?'
    },
    @{
        Name = 'Year'
        Url  = 'https://docs.google.com/presentation/d/1h5_bwQnd6ylEPqhNv7VgwqfaVBOvZ9WKKz1Evp6njIU/edit?'
    },
    @{
        Name = 'YearSideBar'
        Url  = 'https://docs.google.com/presentation/d/1m2AZd-puQ2c_yDZk9g2QhZ2xVBENC7fy3i5_Cl8bw5k/edit?'
    }
     @{
        Name = 'Who'
        Url  = 'https://docs.google.com/presentation/d/1jCFz3F6sW9dQal7sFOc3B_SDp7xqV1rrDAK2M4E25sc/edit?'
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

