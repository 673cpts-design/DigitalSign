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
