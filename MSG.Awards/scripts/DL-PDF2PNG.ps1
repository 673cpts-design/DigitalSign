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
    },
    @{
        Name = 'Who'
        Url  = 'https://docs.google.com/presentation/d/1DQ5OneNCKlyUdGr7NtC7HdaJMeBsptae9tLlB1tNIo8/edit?'
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


# ================== CONFIGURATION ==================

$baseOutputPath = "C:\www\images"
$maxDownloadRetries = 3   # Max retries to download the PDF
$maxConvertRetries  = 3   # Max retries for ImageMagick to convert
$maxOuterCycles     = 3   # Max full redownload cycles for failed files
$retryDelaySeconds  = 10  # Seconds to wait before retrying

$presentations = @(
    @{ Name = 'Leadership'; Url = 'https://docs.google.com/presentation/d/1_bZLH2Zl4eYf8yGnEUyjgkHUJrmMs9kgNxes24tpY0E/edit?' },
    @{ Name = 'Quarter1';   Url = 'https://docs.google.com/presentation/d/1EY6EOeD7cyvaEyL2X5P1SdzFBop29q6vpEu3nG4qCpQ/edit?' },
    @{ Name = 'Quarter2';   Url = 'https://docs.google.com/presentation/d/1fwFDb59l5lzGgbqNLmhIy11WykN9Z35fWgb0vFWj2rs/edit?' },
    @{ Name = 'Quarter3';   Url = 'https://docs.google.com/presentation/d/1rJIGLcvryB8hg3E3VoVfHzXwz0VgeQXFgswUGujVaNE/edit?' },
    @{ Name = 'Quarter4';   Url = 'https://docs.google.com/presentation/d/16KSbkc76muL0oR1MVWuOWBL-25Z2IajLZLL2_6RLc_g/edit?' },
    @{ Name = 'Year';       Url = 'https://docs.google.com/presentation/d/1o9JSK93OGBsLte6HQei69oLClterIoN43mU9GkohJAA/edit?' },
    @{ Name = 'YearSideBar';Url = 'https://docs.google.com/presentation/d/1s5fK-gRDrT9C-Xnn2KJeCtKlaBYOnvTxdCJfKI7OscM/edit?' },
    @{ Name = 'Who';        Url = 'https://docs.google.com/presentation/d/1uyvgSv2c1evHjVMBxg9L6oudS4neHCxEejk6bKvTPrg/edit?' }
)

# ================== MAIN PROCESSING ==================

$pendingPresentations = $presentations
$outerCycle = 0

while ($outerCycle -lt $maxOuterCycles -and $pendingPresentations.Count -gt 0) {
    $outerCycle++
    Write-Host "`n=== Outer Cycle ($outerCycle/$maxOuterCycles) ===" -ForegroundColor Cyan
    
    $failedThisCycle = @() # Track presentations that need a redownload

    # Step 1: Sequential Download & Dispatch
    foreach ($p in $pendingPresentations) {
        Write-Host "`n-> Processing '$($p.Name)'"
        
        $fileId = $null
        try { 
            $uri = [Uri]$p.Url 
            $match = [regex]::Match($uri.AbsolutePath, '/presentation/d/([^/]+)/')
            if ($match.Success) { $fileId = $match.Groups[1].Value }
        } catch { }

        if (-not $fileId) {
            Write-Warning "   Invalid URL."
            continue
        }

        $mainFolder = Join-Path $baseOutputPath $p.Name
        $pdfFolder  = Join-Path $mainFolder "pdf"
        if (-not (Test-Path $mainFolder)) { New-Item -ItemType Directory -Path $mainFolder | Out-Null }
        if (-not (Test-Path $pdfFolder))  { New-Item -ItemType Directory -Path $pdfFolder  | Out-Null }

        # --- SYNCHRONOUS DOWNLOAD ---
        $pdfPath = $null
        $downloadAttempts = 0
        $pdfOut = Join-Path $pdfFolder "slides.pdf"
        $pdfUrl = "https://docs.google.com/presentation/d/$fileId/export/pdf"

        # Clean old PDF before downloading
        if (Test-Path $pdfOut) { Remove-Item $pdfOut -Force }

        while ($downloadAttempts -lt $maxDownloadRetries -and -not $pdfPath) {
            $downloadAttempts++
            Write-Host "   [Download] Attempt ($downloadAttempts/$maxDownloadRetries)..."
            
            try {
                Invoke-WebRequest -UseBasicParsing -Uri $pdfUrl -OutFile $pdfOut -ErrorAction Stop
                if ((Test-Path $pdfOut) -and ((Get-Item $pdfOut).Length -gt 0)) {
                    $pdfPath = $pdfOut
                } else {
                    if (Test-Path $pdfOut) { Remove-Item $pdfOut -Force }
                }
            } catch { }

            if (-not $pdfPath -and $downloadAttempts -lt $maxDownloadRetries) { Start-Sleep -Seconds $retryDelaySeconds }
        }

        if (-not $pdfPath) {
            Write-Warning "   [Download] Failed all attempts. Tagging for next cycle."
            $failedThisCycle += $p
            continue # Move to next download
        }

        Write-Host "   [Download] Complete. Dispatching ImageMagick to background..."

        # --- ASYNCHRONOUS CONVERSION (BACKGROUND JOB) ---
        Start-Job -Name "Convert_$($p.Name)" -ScriptBlock {
            param($name, $pdf, $outDir, $maxRetries, $delay)
            
            $success = $false
            $attempts = 0
            $outPattern = Join-Path $outDir "slide-%03d.png"

            while ($attempts -lt $maxRetries -and -not $success) {
                $attempts++
                Get-ChildItem $outDir -Filter "slide-*.png" -Force | Remove-Item -Force
                
                & magick -density 288 $pdf -background white -alpha remove -alpha off $outPattern
                
                if ($LASTEXITCODE -eq 0 -and (Get-ChildItem $outDir -Filter "slide-*.png").Count -gt 0) {
                    $success = $true
                } else {
                    if ($attempts -lt $maxRetries) { Start-Sleep -Seconds $delay }
                }
            }
            # Return result to the main script
            return $success 
        } -ArgumentList $p.Name, $pdfPath, $mainFolder, $maxConvertRetries, $retryDelaySeconds | Out-Null
    }

    # Step 2: Wait for background conversions to finish
    $activeJobs = Get-Job -Name "Convert_*"
    if ($activeJobs) {
        Write-Host "`nWaiting for all background conversions to complete..." -ForegroundColor Yellow
        $activeJobs | Wait-Job | Out-Null

        # Check job results
        foreach ($job in $activeJobs) {
            $jobResult = Receive-Job -Job $job
            $presName = ($job.Name -split '_')[1]

            if ($jobResult -contains $true) {
                Write-Host "[$presName] Conversion Successful!" -ForegroundColor Green
            } else {
                Write-Warning "[$presName] Conversion Failed. Likely corrupt PDF. Tagging for redownload."
                $failedObj = $pendingPresentations | Where-Object { $_.Name -eq $presName }
                if ($failedObj -notcontains $failedThisCycle) { $failedThisCycle += $failedObj }
            }
        }
        $activeJobs | Remove-Job # Cleanup memory
    }

    # Prepare for the next cycle with only the failed items
    $pendingPresentations = $failedThisCycle
}

if ($pendingPresentations.Count -gt 0) {
    Write-Error "`nFinished all cycles, but some presentations still failed: $($pendingPresentations.Name -join ', ')"
} else {
    Write-Host "`nAll operations completed successfully!" -ForegroundColor Green
}

