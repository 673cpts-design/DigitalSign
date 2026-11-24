# ============================================================
# Build-index-html.ps1
# Left quadrants: existing slideshows. Top right: yearly winners. Bottom right: quarterly winners.
# Run Update-Winners-Csv.ps1 first. Both winner displays are embedded directly in index.html; no separate winner HTML files.
#
# Builds a 3840x2160 HTML page from PNG files in 4 folders.
#
# Slideshow timing is downloaded from Google Sheets:
#
# B2 = Top Left
# B3 = Bottom Left
# C2 = Top Right
# C3 = Bottom Right
#
# Spreadsheet values are in SECONDS.
#
# 0 PNG files = blank quadrant
# 1 PNG file  = static image
# 2+ PNGs     = slideshow + progress bar
#
# Image changes are INSTANT - no fade or transition.
# ============================================================


# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

$TopLeftFolder     = "C:\www\images\TopLeft"
$TopRightFolder    = "C:\www\images\TopRight"
$BottomLeftFolder  = "C:\www\images\BottomLeft"
$BottomRightFolder = "C:\www\images\BottomRight"

$OutputFile = "C:\www\index.html"


# ------------------------------------------------------------
# GOOGLE SHEETS CONFIGURATION
# ------------------------------------------------------------

$SheetId = "1w5-EreROT-A7kaAmCkHgKQWA6r8JlrZ6Ot1tyOCagx8"
$Gid     = "0"

# Cells containing slideshow delay in SECONDS

$TopLeftCell     = "B2"
$BottomLeftCell  = "B3"
$TopRightCell    = "C2"
$BottomRightCell = "C3"

# Download only the left-side timings; the right side uses winner grids.
# Last successful values are cached beside index.html.
$TimingCachePath = Join-Path (Split-Path $OutputFile -Parent) 'slideshow-timing-cache.json'
$Timing = $null
$TimingSources = @(
    @{
        Name = 'CSV export'
        Url = ('https://docs.google.com/spreadsheets/d/{0}/export?format=csv&gid={1}' -f $SheetId, $Gid)
        RangeOnly = $false
    },
    @{
        Name = 'alternate CSV download'
        Url = ('https://docs.google.com/spreadsheets/d/{0}/gviz/tq?tqx=out%3Acsv&gid={1}&range=B2%3AB3&headers=0' -f $SheetId, $Gid)
        RangeOnly = $true
    }
)

function Convert-TimingSeconds {
    param([string]$Value)
    $seconds = 0.0
    $valid = [double]::TryParse(
        $Value.Trim(),
        [Globalization.NumberStyles]::Float,
        [Globalization.CultureInfo]::InvariantCulture,
        [ref]$seconds
    )
    if (-not $valid -or [double]::IsNaN($seconds) -or
        [double]::IsInfinity($seconds) -or $seconds -le 0 -or
        $seconds -gt ([int]::MaxValue / 1000.0)) {
        throw "Invalid slideshow duration: '$Value'. Expected a positive number of seconds."
    }
    return $seconds
}

Write-Host ''
Write-Host 'Downloading slideshow timing from Google Sheets...'

foreach ($source in $TimingSources) {
    try {
        Write-Host ('Trying {0}...' -f $source.Name)
        $request = @{
            Uri = $source.Url
            UseBasicParsing = $true
            TimeoutSec = 45
            ErrorAction = 'Stop'
            UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36'
            Headers = @{ Accept = 'text/csv,text/plain;q=0.9,*/*;q=0.8' }
        }
        # PowerShell 7 supports this parameter; Windows PowerShell 5.1 does not.
        if ((Get-Command Invoke-WebRequest).Parameters.ContainsKey('HttpVersion')) {
            $request.HttpVersion = [Version]'1.1'
        }
        $response = Invoke-WebRequest @request
        $text = if ($response.Content -is [byte[]]) {
            [Text.Encoding]::UTF8.GetString($response.Content)
        } else { [string]$response.Content }
        $text = $text.TrimStart([char]0xFEFF)
        if ([string]::IsNullOrWhiteSpace($text) -or $text -match '(?is)^\s*<(?:!doctype|html)') {
            throw 'Google returned an empty response or HTML instead of CSV.'
        }
        if ($source.RangeOnly) {
            # The requested B2:B3 range contains exactly the two numeric cells.
            $parsed = @($text | ConvertFrom-Csv -Header 'Value' -ErrorAction Stop)
            if ($parsed.Count -ne 2) { throw 'Expected two timing cells in B2:B3.' }
            $top = Convert-TimingSeconds ([string]$parsed[0].Value)
            $bottom = Convert-TimingSeconds ([string]$parsed[1].Value)
        } else {
            $parsed = @($text | ConvertFrom-Csv -Header 'Col1','Col2','Col3' -ErrorAction Stop)
            if ($parsed.Count -lt 3) { throw 'Expected at least three rows in the timing sheet.' }
            $top = Convert-TimingSeconds ([string]$parsed[1].Col2)
            $bottom = Convert-TimingSeconds ([string]$parsed[2].Col2)
        }
        $Timing = [pscustomobject]@{
            SheetId = $SheetId
            Gid = $Gid
            TopLeftSeconds = $top
            BottomLeftSeconds = $bottom
        }
        break
    } catch {
        Write-Warning ('{0} failed: {1}' -f $source.Name, $_.Exception.Message)
    }
}

if ($null -ne $Timing) {
    try {
        [IO.Directory]::CreateDirectory((Split-Path $TimingCachePath -Parent)) | Out-Null
        [IO.File]::WriteAllText(
            $TimingCachePath,
            ($Timing | ConvertTo-Json),
            [Text.UTF8Encoding]::new($false)
        )
    } catch {
        Write-Warning ('Timing download succeeded, but caching failed: ' + $_.Exception.Message)
    }
} elseif (Test-Path -LiteralPath $TimingCachePath) {
    try {
        $cached = Get-Content -LiteralPath $TimingCachePath -Raw | ConvertFrom-Json
        if ($cached.SheetId -ne $SheetId -or [string]$cached.Gid -ne $Gid) {
            throw 'The timing cache belongs to a different spreadsheet or tab.'
        }
        $top = Convert-TimingSeconds ([Convert]::ToString($cached.TopLeftSeconds, [Globalization.CultureInfo]::InvariantCulture))
        $bottom = Convert-TimingSeconds ([Convert]::ToString($cached.BottomLeftSeconds, [Globalization.CultureInfo]::InvariantCulture))
        $Timing = [pscustomobject]@{ TopLeftSeconds=$top; BottomLeftSeconds=$bottom }
        Write-Warning 'Both downloads failed. Using the last successfully downloaded slideshow timings.'
    } catch {
        throw ('Timing downloads and cached timing validation failed. Existing index.html was not changed. ' + $_.Exception.Message)
    }
}

if ($null -eq $Timing) {
    throw 'Both timing downloads failed and no valid timing cache is available. Existing index.html was not changed.'
}

$TopLeftDurationSeconds = [double]$Timing.TopLeftSeconds
$BottomLeftDurationSeconds = [double]$Timing.BottomLeftSeconds

# ------------------------------------------------------------
# DISPLAY GOOGLE SHEET VALUES
# ------------------------------------------------------------

Write-Host ""
Write-Host "Slideshow timing:"
Write-Host "-----------------"

Write-Host "Top Left:     $TopLeftDurationSeconds seconds"
Write-Host "Top Right:    yearly winner grid (static)"
Write-Host "Bottom Left:  $BottomLeftDurationSeconds seconds"
Write-Host "Bottom Right: quarterly winner grid (static)"

Write-Host ""


# ------------------------------------------------------------
# FUNCTION: CONVERT WINDOWS PATH TO FILE:/// URL
# ------------------------------------------------------------

function Convert-ToFileUrl {

    param (
        [string]$Path
    )

    $FullPath = [System.IO.Path]::GetFullPath($Path)

    $FullPath = $FullPath -replace '\\', '/'

    $Uri = New-Object System.Uri($FullPath)

    return $Uri.AbsoluteUri
}


# ------------------------------------------------------------
# FUNCTION: READ PNG FILES FROM FOLDER
# ------------------------------------------------------------

function Get-PngFiles {

    param (
        [string]$Folder
    )

    if (-not (Test-Path $Folder)) {

        Write-Warning "Folder does not exist: $Folder"

        return @()

    }

    return @(

        Get-ChildItem `
            -Path $Folder `
            -Filter "*.png" `
            -File |
        Sort-Object Name

    )
}


# ------------------------------------------------------------
# READ IMAGE LISTS
# ------------------------------------------------------------

$TopLeftImages =
    Get-PngFiles $TopLeftFolder



$BottomLeftImages =
    Get-PngFiles $BottomLeftFolder




Write-Host "Images found:"
Write-Host "-------------"

Write-Host "Top Left:     $($TopLeftImages.Count)"
Write-Host "Top Right:    yearly framed winner grid"
Write-Host "Bottom Left:  $($BottomLeftImages.Count)"
Write-Host "Bottom Right: quarterly framed winner grid"

Write-Host ""


# ------------------------------------------------------------
# FUNCTION: BUILD HTML FOR ONE QUADRANT
# ------------------------------------------------------------

function New-QuadrantHtml {

    param (
        [string]$Id,
        [array]$Images,
        [double]$DurationSeconds
    )


    # --------------------------------------------------------
    # No images
    # --------------------------------------------------------

    if ($Images.Count -eq 0) {

        return @"
<div id="$Id" class="quadrant empty">
</div>
"@

    }


    # --------------------------------------------------------
    # One image - static
    # --------------------------------------------------------

    if ($Images.Count -eq 1) {

        $ImageUrl =
            Convert-ToFileUrl $Images[0].FullName

        return @"
<div id="$Id" class="quadrant">

    <img class="static-image"
         src="$ImageUrl"
         alt="">

</div>
"@

    }


    # --------------------------------------------------------
    # Multiple images - slideshow
    # --------------------------------------------------------

    $ImageHtml = ""

    for ($i = 0; $i -lt $Images.Count; $i++) {

        $ImageUrl =
            Convert-ToFileUrl $Images[$i].FullName

        if ($i -eq 0) {

            $Class = "slide active"

        }
        else {

            $Class = "slide"

        }

        $ImageHtml += @"
        <img class="$Class"
             src="$ImageUrl"
             alt="">
"@

    }


    # Convert seconds to milliseconds for JavaScript

    $DurationMs = [int]($DurationSeconds * 1000)


    return @"
<div id="$Id"
     class="quadrant slideshow"
     data-duration="$DurationMs">

    <div class="slides">

$ImageHtml

    </div>

    <div class="progress-background">

        <div class="progress-bar"></div>

    </div>

</div>
"@

}



# INLINE WINNER TEMPLATE (original SVG frames, isolated styles and IDs per quadrant)
$WinnerTemplate = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('PHRlbXBsYXRlIGNsYXNzPSJ3aW5uZXItY29udGVudCI+PHN0eWxlPiNfX1dJTk5FUl9IT1NUX18gKntib3gtc2l6aW5nOmJvcmRlci1ib3h9CiNfX1dJTk5FUl9IT1NUX18gW2RhdGEtcGFydD0ic3RhZ2UiXXtwb3NpdGlvbjphYnNvbHV0ZTt3aWR0aDoxOTIwcHg7aGVpZ2h0OjEwODBweDt0cmFuc2Zvcm0tb3JpZ2luOnRvcCBsZWZ0fSNfX1dJTk5FUl9IT1NUX18gLnJvd3twb3NpdGlvbjphYnNvbHV0ZTtsZWZ0OjA7d2lkdGg6MTkyMHB4O2Rpc3BsYXk6YmxvY2t9I19fV0lOTkVSX0hPU1RfXyBbZGF0YS1wYXJ0PSJ0b3AiXXt0b3A6MH0jX19XSU5ORVJfSE9TVF9fIFtkYXRhLXBhcnQ9ImJvdHRvbSJde3RvcDowfSNfX1dJTk5FUl9IT1NUX18gLnBvcnRyYWl0e3Bvc2l0aW9uOmFic29sdXRlO3dpZHRoOjMwNHB4O2hlaWdodDozODRweDt0cmFuc2Zvcm0tb3JpZ2luOnRvcCBsZWZ0O21hcmdpbjowfSNfX1dJTk5FUl9IT1NUX18gLnBob3Rve3Bvc2l0aW9uOmFic29sdXRlO3otaW5kZXg6MDtsZWZ0OmNhbGMoNC4xODEyJSAtIDNweCk7dG9wOmNhbGMoMy41ODEzJSAtIDNweCk7d2lkdGg6Y2FsYyg5MS45ODYxJSArIDZweCk7aGVpZ2h0OmNhbGMoODMuMTk1NiUgKyA2cHgpO29iamVjdC1maXQ6Y292ZXI7b2JqZWN0LXBvc2l0aW9uOmNlbnRlciB0b3A7ZGlzcGxheTpibG9ja30jX19XSU5ORVJfSE9TVF9fIC5mcmFtZXtwb3NpdGlvbjphYnNvbHV0ZTt6LWluZGV4OjE7aW5zZXQ6MDtwb2ludGVyLWV2ZW50czpub25lfSNfX1dJTk5FUl9IT1NUX18gLmZyYW1lIHN2Z3t3aWR0aDoxMDAlO2hlaWdodDoxMDAlO2Rpc3BsYXk6YmxvY2s7b3ZlcmZsb3c6dmlzaWJsZX0jX19XSU5ORVJfSE9TVF9fIC5jYXB0aW9ue3Bvc2l0aW9uOmFic29sdXRlO3otaW5kZXg6MjtsZWZ0OjklO3JpZ2h0OjklO3RvcDo4OC4xNTQyNyU7aGVpZ2h0OjExLjAxOTI4JTtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVudDpjZW50ZXI7ZmxleC1kaXJlY3Rpb246Y29sdW1uO2dhcDo2cHg7Y29sb3I6I2ZmZmZmZjt0ZXh0LWFsaWduOmNlbnRlcjtmb250LWZhbWlseTpBcmlhbCxzYW5zLXNlcmlmO3RleHQtc2hhZG93OjAgMXB4IDJweCAjMDAwO2xpbmUtaGVpZ2h0OjEuMDg7b3ZlcmZsb3c6aGlkZGVufSNfX1dJTk5FUl9IT1NUX18gLmNhcHRpb24gLm5hbWUsI19fV0lOTkVSX0hPU1RfXyAuY2FwdGlvbiAudGl0bGV7Zm9udC13ZWlnaHQ6NzAwO2ZsZXg6bm9uZTt3aWR0aDoxMDAlO2hlaWdodDpjYWxjKCgxMDAlIC0gNnB4KS8yKTtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVudDpjZW50ZXI7bWF4LXdpZHRoOjEwMCU7d2hpdGUtc3BhY2U6bm93cmFwO2xpbmUtaGVpZ2h0OjEuMDh9I19fV0lOTkVSX0hPU1RfXyAuaW1nLWJnewogICAgICAgIHBvc2l0aW9uOiBhYnNvbHV0ZTsKICAgICAgICB0b3A6IDBweDsKICAgICAgICBsZWZ0OjBweDsKICAgICAgICB3aWR0aDogMTkyMHB4OwogICAgICAgIGhlaWdodDogMTA4MHB4OwogICAgICAgIHotaW5kZXg6IC0xOwogICAgICAgIGJvcmRlcjogbm9uZTsKICAgIH0KCiNfX1dJTk5FUl9IT1NUX18gW2RhdGEtcGFydD0ic3RhZ2UiXXtpc29sYXRpb246aXNvbGF0ZX0KCiNfX1dJTk5FUl9IT1NUX18gLndpbm5lci1oZWFkaW5ne3Bvc2l0aW9uOmFic29sdXRlO3otaW5kZXg6MztsZWZ0OjQ0NXB4O3RvcDo2NXB4O3dpZHRoOjEwMzBweDtoZWlnaHQ6ODZweDttYXJnaW46MDtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVudDpjZW50ZXI7dGV4dC1hbGlnbjpjZW50ZXI7Zm9udC1mYW1pbHk6R2VvcmdpYSwnVGltZXMgTmV3IFJvbWFuJyxzZXJpZjtmb250LXdlaWdodDo3MDA7Zm9udC1zaXplOjY0cHg7bGluZS1oZWlnaHQ6MS4xO2NvbG9yOiNmZmY0ZDU7dGV4dC1zaGFkb3c6MTJweCAxNXB4IDEuNXB4ICMwMDAsMTVweCAxOS41cHggNy41cHggcmdiYSgwLDAsMCwuOTUpO3doaXRlLXNwYWNlOm5vd3JhcDtvdmVyZmxvdzp2aXNpYmxlfQo8L3N0eWxlPgo8ZGl2IGRhdGEtcGFydD0ic3RhZ2UiPjxpbWcgZGF0YS1zbm93IGNsYXNzPSJpbWctYmciIHNyYz0iaW1hZ2VzL2JnLnBuZyIvPjxoMSBjbGFzcz0id2lubmVyLWhlYWRpbmciIGRhdGEtcGFydD0iaGVhZGluZyIgYXJpYS1saXZlPSJwb2xpdGUiPjwvaDE+PGRpdiBkYXRhLXBhcnQ9InRvcCIgY2xhc3M9InJvdyI+PC9kaXY+PGRpdiBkYXRhLXBhcnQ9ImJvdHRvbSIgY2xhc3M9InJvdyI+PC9kaXY+PC9kaXY+CjwhLS0gRXhhY3QtY2VsbCBDU1YgaXMgZW1iZWRkZWQgYnkgdGhlIGJ1aWxkZXIuIC0tPgo8c2NyaXB0IGRhdGEtcGFydD0icG9ydHJhaXQtY3N2IiB0eXBlPSJ0ZXh0L3BsYWluIj4KX19XSU5ORVJfQ1NWX18KPC9zY3JpcHQ+CjwhLS0gR2VuZXJhdGVkIGJ5IFVwZGF0ZS1XaW5uZXJzLUNzdi5wczE7IHdvcmtzIHdpdGggbG9jYWwgZmlsZSBwbGF5YmFjay4gLS0+Cgo8dGVtcGxhdGUgZGF0YS1wYXJ0PSJmcmFtZS10ZW1wbGF0ZSI+PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjEzIDIyIDI4NyAzNjMiIHByZXNlcnZlQXNwZWN0UmF0aW89Im5vbmUiIGZpbGw9Im5vbmUiIHJvbGU9ImltZyIgYXJpYS1sYWJlbD0iU2hpbmluZyBnb2xkIHBpY3R1cmUgZnJhbWUgd2l0aCBibGFjayBkZWNvcmF0aXZlIG5hbWVwbGF0ZSI+CjxkZWZzPgogIDxsaW5lYXJHcmFkaWVudCBpZD0iZ2YtZ29sZCIgeDE9IjAiIHkxPSIwIiB4Mj0iMSIgeTI9IjEiPgogICAgPHN0b3Agc3RvcC1jb2xvcj0iIzY5NDAwYiIvPjxzdG9wIG9mZnNldD0iLjEyIiBzdG9wLWNvbG9yPSIjZmZmNGI0Ii8+PHN0b3Agb2Zmc2V0PSIuMjQiIHN0b3AtY29sb3I9IiNjNThiMjAiLz48c3RvcCBvZmZzZXQ9Ii40IiBzdG9wLWNvbG9yPSIjZmZlYWEwIi8+PHN0b3Agb2Zmc2V0PSIuNSIgc3RvcC1jb2xvcj0iI2ZmZmRlMSIvPjxzdG9wIG9mZnNldD0iLjYiIHN0b3AtY29sb3I9IiNhODY5MGQiLz48c3RvcCBvZmZzZXQ9Ii43OCIgc3RvcC1jb2xvcj0iI2Y0Y2E2MSIvPjxzdG9wIG9mZnNldD0iLjkiIHN0b3AtY29sb3I9IiM4MDUwMGMiLz48c3RvcCBvZmZzZXQ9IjEiIHN0b3AtY29sb3I9IiNmZmYwYTAiLz4KICA8L2xpbmVhckdyYWRpZW50PgogIDxsaW5lYXJHcmFkaWVudCBpZD0iZ2YtdmVydGljYWwiIHgxPSIwIiB5MT0iMCIgeDI9IjAiIHkyPSIxIj4KICAgIDxzdG9wIHN0b3AtY29sb3I9IiNmZmY4Y2IiLz48c3RvcCBvZmZzZXQ9Ii4wNiIgc3RvcC1jb2xvcj0iI2ZmZTU5NSIvPjxzdG9wIG9mZnNldD0iLjE4IiBzdG9wLWNvbG9yPSIjYjU3NTExIi8+PHN0b3Agb2Zmc2V0PSIuMzIiIHN0b3AtY29sb3I9IiNmNGM0NTciLz48c3RvcCBvZmZzZXQ9Ii4zOSIgc3RvcC1jb2xvcj0iI2ZmZmJkNiIvPjxzdG9wIG9mZnNldD0iLjQ2IiBzdG9wLWNvbG9yPSIjZTZiMzQzIi8+PHN0b3Agb2Zmc2V0PSIuNjciIHN0b3AtY29sb3I9IiM4ZjU2MDkiLz48c3RvcCBvZmZzZXQ9Ii44OCIgc3RvcC1jb2xvcj0iI2Y5ZGI3OCIvPjxzdG9wIG9mZnNldD0iMSIgc3RvcC1jb2xvcj0iI2FiNzQxYSIvPgogIDwvbGluZWFyR3JhZGllbnQ+CiAgPGxpbmVhckdyYWRpZW50IGlkPSJnZi10b3AiIHgxPSIwIiB5MT0iMCIgeDI9IjEiIHkyPSIwIj4KICAgIDxzdG9wIHN0b3AtY29sb3I9IiNmZmYyYWUiLz48c3RvcCBvZmZzZXQ9Ii4xIiBzdG9wLWNvbG9yPSIjZmZmZGU4Ii8+PHN0b3Agb2Zmc2V0PSIuMjIiIHN0b3AtY29sb3I9IiNiYjdhMTciLz48c3RvcCBvZmZzZXQ9Ii40MiIgc3RvcC1jb2xvcj0iI2ZmZGE3ZCIvPjxzdG9wIG9mZnNldD0iLjUzIiBzdG9wLWNvbG9yPSIjZmZmIi8+PHN0b3Agb2Zmc2V0PSIuNjMiIHN0b3AtY29sb3I9IiNlYWE2M2UiLz48c3RvcCBvZmZzZXQ9Ii44MyIgc3RvcC1jb2xvcj0iI2E5NmIwYyIvPjxzdG9wIG9mZnNldD0iMSIgc3RvcC1jb2xvcj0iI2ZmZjRiOCIvPgogIDwvbGluZWFyR3JhZGllbnQ+CiAgPGxpbmVhckdyYWRpZW50IGlkPSJnZi1ibGFjayIgeDE9IjAiIHkxPSIwIiB4Mj0iMCIgeTI9IjEiPgogICAgPHN0b3Agc3RvcC1jb2xvcj0iIzA4MDgwNyIvPjxzdG9wIG9mZnNldD0iLjQ4IiBzdG9wLWNvbG9yPSIjMWQxZDFhIi8+PHN0b3Agb2Zmc2V0PSIuNTUiIHN0b3AtY29sb3I9IiMwYjBiMDkiLz48c3RvcCBvZmZzZXQ9IjEiIHN0b3AtY29sb3I9IiMxNDE0MTAiLz4KICA8L2xpbmVhckdyYWRpZW50PgogIDxyYWRpYWxHcmFkaWVudCBpZD0iZ2Ytc2hpbmUiPjxzdG9wIHN0b3AtY29sb3I9IiNmZmYiLz48c3RvcCBvZmZzZXQ9Ii4xNiIgc3RvcC1jb2xvcj0iI2ZmZmRlMiIgc3RvcC1vcGFjaXR5PSIuOTgiLz48c3RvcCBvZmZzZXQ9Ii40IiBzdG9wLWNvbG9yPSIjZmZjZjcwIiBzdG9wLW9wYWNpdHk9Ii42NSIvPjxzdG9wIG9mZnNldD0iMSIgc3RvcC1jb2xvcj0iI2ZmYTUyYiIgc3RvcC1vcGFjaXR5PSIwIi8+PC9yYWRpYWxHcmFkaWVudD4KICA8cGF0dGVybiBpZD0iZ2YtYnJ1c2giIHdpZHRoPSIxOSIgaGVpZ2h0PSIzIiBwYXR0ZXJuVW5pdHM9InVzZXJTcGFjZU9uVXNlIj48cGF0aCBkPSJNMCAuNUgxOU00IDJIMTYiIHN0cm9rZT0iI2QyYmU3ZSIgc3Ryb2tlLW9wYWNpdHk9Ii4wNjUiIHN0cm9rZS13aWR0aD0iLjQiLz48L3BhdHRlcm4+CiAgPGcgaWQ9ImdmLXJvc2V0dGUiPjxjaXJjbGUgcj0iNC41IiBmaWxsPSJ1cmwoI2dmLWdvbGQpIiBzdHJva2U9IiNmZmVkOWMiIHN0cm9rZS13aWR0aD0iLjUiLz48cGF0aCBkPSJNLTMgMEgzTTAtM1YzTS0yLTIgMiAyTS0yIDIgMi0yIiBzdHJva2U9IiM4MDUzMTUiIHN0cm9rZS13aWR0aD0iLjYiLz48Y2lyY2xlIHI9IjEuMiIgZmlsbD0iI2ZmZjFiMCIvPjwvZz4KPC9kZWZzPgo8IS0tIFRoZSBvdXRzaWRlIGFuZCB0aGUgcGljdHVyZSBvcGVuaW5nIGFyZSB0cmFuc3BhcmVudC4gLS0+CjxwYXRoIGQ9Ik0xMyAyMkgzMDFWMzg2SDEzWk0yNSAzNVYzMzdIMjg5VjM1WiIgZmlsbD0iIzEyMGUwNyIgZmlsbC1ydWxlPSJldmVub2RkIi8+CjxwYXRoIGQ9Ik0xNCAyM0gzMDBWMzg1SDE0Wk0yMCAyOVYzNzlIMjk0VjI5WiIgZmlsbD0idXJsKCNnZi12ZXJ0aWNhbCkiIGZpbGwtcnVsZT0iZXZlbm9kZCIvPgo8cGF0aCBkPSJNMTQgMjNIMzAwTDI5NCAyOUgyMFoiIGZpbGw9InVybCgjZ2YtdG9wKSIvPgo8cGF0aCBkPSJNMjAgMjlIMjk0VjMzOUgyODlWMzVIMjVWMzM5SDIwWiIgZmlsbD0iIzA3MDcwNSIvPgo8cGF0aCBkPSJNMTQuNSAzMzdWMjMuNUgyOTkuNVYzMzdNMTkuNSAzMzdWMjkuNUgyOTQuNVYzMzciIHN0cm9rZT0iI2ZmZjNiMCIgc3Ryb2tlLXdpZHRoPSIuNjUiLz4KPHBhdGggZD0iTTIyIDMzN1YzMkgyOTJWMzM3IiBzdHJva2U9IiNhZDc1MjEiIHN0cm9rZS13aWR0aD0iLjciLz4KPCEtLSBCcnVzaGVkIGJsYWNrIG5hbWVwbGF0ZSB3aXRoIGRvdWJsZSBnb2xkIHRyaW0uIC0tPgo8cGF0aCBkPSJNMTMgMzM3SDMwMFYzODVIMTNaIiBmaWxsPSJ1cmwoI2dmLWJsYWNrKSIgc3Ryb2tlPSJ1cmwoI2dmLWdvbGQpIiBzdHJva2Utd2lkdGg9IjEuOCIvPgo8cGF0aCBkPSJNMTUgMzM5SDI5OFYzODNIMTVaIiBmaWxsPSJ1cmwoI2dmLWJydXNoKSIgc3Ryb2tlPSIjZTVjNjZkIiBzdHJva2Utd2lkdGg9Ii42NSIvPgo8cGF0aCBkPSJNMjUgMzQwSDI4OFEyODkgMzQ4IDI5NyAzNDlWMzc0UTI4OSAzNzUgMjg4IDM4MkgyNVEyNCAzNzUgMTYgMzc0VjM0OVEyNCAzNDggMjUgMzQwWiIgc3Ryb2tlPSJ1cmwoI2dmLWdvbGQpIiBzdHJva2Utd2lkdGg9IjEuMiIvPgo8cGF0aCBkPSJNMTcgMzQxSDIzUTIyIDM0NiAxNyAzNDdaTTI5MCAzNDFIMjk2VjM0N1EyOTEgMzQ2IDI5MCAzNDFaTTE3IDM3NlEyMiAzNzcgMjMgMzgxSDE3Wk0yOTAgMzgxUTI5MSAzNzcgMjk2IDM3NlYzODFaIiBmaWxsPSJ1cmwoI2dmLWdvbGQpIi8+CjxnIGNsYXNzPSJwbGFxdWUtb3JuYW1lbnQiPgo8cGF0aCBkPSJNMzUgMzYySDI3OSIgc3Ryb2tlPSIjZGRiYjUzIiBzdHJva2Utd2lkdGg9Ii44NSIvPgo8Y2lyY2xlIGN4PSIzNSIgY3k9IjM2MiIgcj0iMS4yIiBmaWxsPSIjZmZmMGEyIi8+PGNpcmNsZSBjeD0iMjc5IiBjeT0iMzYyIiByPSIxLjIiIGZpbGw9IiNmZmYwYTIiLz4KPHVzZSBocmVmPSIjZ2Ytcm9zZXR0ZSIgeD0iMjUiIHk9IjM2MiIvPjx1c2UgaHJlZj0iI2dmLXJvc2V0dGUiIHg9IjI4NyIgeT0iMzYyIi8+CjwvZz4KPCEtLSBIaWdobGlnaHQgZmxhcmUgcmVtYWlucyBnb2xkIGFuZCB3aGl0ZSwgd2l0aCBubyBibHVlIGJhY2tkcm9wLiAtLT4KPGVsbGlwc2UgY3g9IjE2OCIgY3k9IjI1IiByeD0iNjIiIHJ5PSIxNCIgZmlsbD0idXJsKCNnZi1zaGluZSkiLz4KPGVsbGlwc2UgY3g9IjE2OCIgY3k9IjI1IiByeD0iMzQiIHJ5PSIzLjgiIGZpbGw9InVybCgjZ2Ytc2hpbmUpIi8+CjxwYXRoIGQ9Im0xMzAgMjUgMzAtMS4zIDgtMyA4IDMgMzAgMS4zLTMwIDEuMy04IDIuNy04LTIuN1oiIGZpbGw9InVybCgjZ2YtdG9wKSIvPgo8ZWxsaXBzZSBjeD0iMTY4IiBjeT0iMjQuOCIgcng9IjExIiByeT0iMi4zIiBmaWxsPSIjZmZmZWYyIi8+Cjwvc3ZnPgo8L3RlbXBsYXRlPgoKPC90ZW1wbGF0ZT4KPHNjcmlwdD4KKCgpPT57Y29uc3QgaG9zdD1kb2N1bWVudC5jdXJyZW50U2NyaXB0LnBhcmVudEVsZW1lbnQ7Cmhvc3QucHJlcGVuZChob3N0LnF1ZXJ5U2VsZWN0b3IoIi53aW5uZXItY29udGVudCIpLmNvbnRlbnQuY2xvbmVOb2RlKHRydWUpKTsKCid1c2Ugc3RyaWN0JzsKY29uc3QgU0VUVElOR1MgPSB7CiAgcGhvdG9Gb2xkZXI6IF9fV0lOTkVSX1BIT1RPX0ZPTERFUl9fLCAgICAgLy8gUmVsYXRpdmUgdG8gaW5kZXguaHRtbCwgZS5nLiAnaW1hZ2VzL2xlYWRlcnNoaXAnLgogIGZpcnN0TnVtYmVyOiAwLCAgICAgICAgICAgIC8vIEF1dG9tYXRpYyBtb2RlIGNoZWNrcyBzbGlkZS0wMDAucG5nIHRocm91Z2ggc2xpZGUtMDEwLnBuZy4KICBtYXhpbXVtUGhvdG9zOiAxMQp9Owpjb25zdCByb290PWhvc3Q7CmNvbnN0IHBhcnQ9aWQ9PnJvb3QucXVlcnlTZWxlY3RvcihgW2RhdGEtcGFydD0iJHtpZH0iXWApOwpsZXQgbGFiZWxDU1Y9cGFydCgncG9ydHJhaXQtY3N2JykudGV4dENvbnRlbnQudHJpbSgpLnJlcGxhY2VBbGwoJyZsdDsnLCBTdHJpbmcuZnJvbUNoYXJDb2RlKDYwKSk7CmNvbnN0IHN0YWdlID0gcGFydCgnc3RhZ2UnKTsKZnVuY3Rpb24gcmVzaXplKCl7CiAgY29uc3Qgc2NhbGU9TWF0aC5taW4oaG9zdC5jbGllbnRXaWR0aC8xOTIwLGhvc3QuY2xpZW50SGVpZ2h0LzEwODApOwogIHN0YWdlLnN0eWxlLnRyYW5zZm9ybT1gc2NhbGUoJHtzY2FsZX0pYDsKICBzdGFnZS5zdHlsZS5sZWZ0PWAkeyhob3N0LmNsaWVudFdpZHRoLTE5MjAqc2NhbGUpLzJ9cHhgOwogIHN0YWdlLnN0eWxlLnRvcD1gJHsoaG9zdC5jbGllbnRIZWlnaHQtMTA4MCpzY2FsZSkvMn1weGA7Cn0KYWRkRXZlbnRMaXN0ZW5lcigncmVzaXplJyxyZXNpemUpO3Jlc2l6ZSgpOwovLyBGaXQgY29tcGxldGUgcG9ydHJhaXQgYXNzZW1ibGllcyBpbnRvIHRoZSAyMDBweC4uMTA3MHB4IGFyZWEuCi8vIEZyYW1lLCBwaG90bywgcGxhcXVlIHRleHQsIGxpbmUgc3BhY2luZyBhbmQgc2hpbmUgc2hhcmUgb25lIHVuaWZvcm0gc2NhbGUuCmZ1bmN0aW9uIHdpbm5lckdyaWRHZW9tZXRyeShjb3VudCl7CiAgY29uc3Qgd2lkdGg9MTkyMCwgYXJlYVRvcD0yMDAsIGFyZWFCb3R0b209MTA3MDsKICBjb25zdCBjYXJkV2lkdGg9MzA0LCBjYXJkSGVpZ2h0PTM4NCwgY29sdW1uR2FwPTE5LjIsIHJvd0dhcD0xNDsKICBjb25zdCBmbGFyZVRvcD0xMiwgZnJhbWVCb3R0b209MiwgZWRnZUFsbG93YW5jZT00OwogIGNvbnN0IHRvcENvdW50PU1hdGgubWluKDUsY291bnQpLCBib3R0b21Db3VudD1NYXRoLm1heCgwLGNvdW50LTUpOwogIGlmKCF0b3BDb3VudClyZXR1cm4ge3NjYWxlOjEscm93czpbXX07CiAgY29uc3Qgcm93Q291bnQ9Ym90dG9tQ291bnQ/MjoxOwogIGNvbnN0IGNvbHVtbnM9TWF0aC5tYXgodG9wQ291bnQsYm90dG9tQ291bnQpOwogIGNvbnN0IG5hdHVyYWxXaWR0aD1jb2x1bW5zKmNhcmRXaWR0aCsoY29sdW1ucy0xKSpjb2x1bW5HYXArZWRnZUFsbG93YW5jZTsKICBjb25zdCBuYXR1cmFsSGVpZ2h0PXJvd0NvdW50KmNhcmRIZWlnaHQrKHJvd0NvdW50LTEpKnJvd0dhcCtmbGFyZVRvcCtmcmFtZUJvdHRvbTsKICBjb25zdCBzY2FsZT1NYXRoLm1pbih3aWR0aC9uYXR1cmFsV2lkdGgsKGFyZWFCb3R0b20tYXJlYVRvcCkvbmF0dXJhbEhlaWdodCk7CiAgY29uc3QgZmlyc3RUb3A9YXJlYVRvcCsoYXJlYUJvdHRvbS1hcmVhVG9wLW5hdHVyYWxIZWlnaHQqc2NhbGUpLzIrZmxhcmVUb3Aqc2NhbGU7CiAgY29uc3QgY291bnRzPWJvdHRvbUNvdW50P1t0b3BDb3VudCxib3R0b21Db3VudF06W3RvcENvdW50XTsKICByZXR1cm4ge3NjYWxlLHJvd3M6Y291bnRzLm1hcCgobixpKT0+KHsKICAgIGNvdW50Om4sCiAgICBsZWZ0Oih3aWR0aC0obipjYXJkV2lkdGgrKG4tMSkqY29sdW1uR2FwKSpzY2FsZSkvMiwKICAgIHRvcDpmaXJzdFRvcCtpKihjYXJkSGVpZ2h0K3Jvd0dhcCkqc2NhbGUsCiAgICBzdGVwOihjYXJkV2lkdGgrY29sdW1uR2FwKSpzY2FsZQogIH0pKX07Cn0KZnVuY3Rpb24gbGF5b3V0UG9ydHJhaXRzKCl7CiAgY29uc3Qgcm93cz1bcGFydCgndG9wJykscGFydCgnYm90dG9tJyldOwogIGNvbnN0IGNvdW50PXJvd3MucmVkdWNlKChzdW0scm93KT0+c3VtK3Jvdy5jaGlsZHJlbi5sZW5ndGgsMCk7CiAgY29uc3QgbGF5b3V0PXdpbm5lckdyaWRHZW9tZXRyeShjb3VudCk7CiAgcm93cy5mb3JFYWNoKChyb3csaSk9PnsKICAgIGNvbnN0IGdlb21ldHJ5PWxheW91dC5yb3dzW2ldOwogICAgcm93LnN0eWxlLmRpc3BsYXk9Z2VvbWV0cnk/J2Jsb2NrJzonbm9uZSc7CiAgICBpZighZ2VvbWV0cnkpcmV0dXJuOwogICAgcm93LnN0eWxlLnRvcD1nZW9tZXRyeS50b3ArJ3B4JzsKICAgIFsuLi5yb3cuY2hpbGRyZW5dLmZvckVhY2goKGNhcmQsaik9PnsKICAgICAgY2FyZC5zdHlsZS5sZWZ0PShnZW9tZXRyeS5sZWZ0K2oqZ2VvbWV0cnkuc3RlcCkrJ3B4JzsKICAgICAgY2FyZC5zdHlsZS50b3A9JzBweCc7CiAgICAgIGNhcmQuc3R5bGUudHJhbnNmb3JtPWBzY2FsZSgke2xheW91dC5zY2FsZX0pYDsKICAgIH0pOwogIH0pOwp9CmZ1bmN0aW9uIHBhcnNlQ1NWKHRleHQpewogIGNvbnN0IHJvd3M9W107bGV0IHJvdz1bXSxmaWVsZD0nJyxxdW90ZWQ9ZmFsc2U7CiAgdGV4dD10ZXh0LnJlcGxhY2UoL15cdUZFRkYvLCcnKTsKICBmb3IobGV0IGk9MDtpPHRleHQubGVuZ3RoO2krKyl7CiAgICBjb25zdCBjPXRleHRbaV07CiAgICBpZihjPT09JyInKXsKICAgICAgaWYocXVvdGVkICYmIHRleHRbaSsxXT09PSciJyl7ZmllbGQrPSciJztpKys7fWVsc2UgcXVvdGVkPSFxdW90ZWQ7CiAgICB9ZWxzZSBpZihjPT09JywnICYmICFxdW90ZWQpe3Jvdy5wdXNoKGZpZWxkKTtmaWVsZD0nJzt9CiAgICBlbHNlIGlmKChjPT09J1xuJ3x8Yz09PSdccicpJiYhcXVvdGVkKXsKICAgICAgaWYoYz09PSdccicmJnRleHRbaSsxXT09PSdcbicpaSsrOwogICAgICByb3cucHVzaChmaWVsZCk7aWYocm93LnNvbWUodj0+di50cmltKCkpKXJvd3MucHVzaChyb3cpO3Jvdz1bXTtmaWVsZD0nJzsKICAgIH1lbHNlIGZpZWxkKz1jOwogIH0KICByb3cucHVzaChmaWVsZCk7aWYocm93LnNvbWUodj0+di50cmltKCkpKXJvd3MucHVzaChyb3cpOwogIHJldHVybiByb3dzOwp9CmZ1bmN0aW9uIHBob3RvVVJMKGZpbGUpewogIHJldHVybiBTRVRUSU5HUy5waG90b0ZvbGRlci5yZXBsYWNlKC9cLyQvLCcnKSsnLycrZmlsZS5zcGxpdCgnLycpLm1hcChlbmNvZGVVUklDb21wb25lbnQpLmpvaW4oJy8nKTsKfQpmdW5jdGlvbiBsb2FkUGhvdG8oaXRlbSl7CiAgcmV0dXJuIG5ldyBQcm9taXNlKHJlc29sdmU9PnsKICAgIGNvbnN0IGltZz1uZXcgSW1hZ2UoKTtpbWcuY2xhc3NOYW1lPSdwaG90byc7aW1nLmFsdD1pdGVtLm5hbWV8fCcnOwogICAgaW1nLm9ubG9hZD0oKT0+cmVzb2x2ZSh7Li4uaXRlbSxpbWd9KTsKICAgIGltZy5vbmVycm9yPSgpPT57Y29uc29sZS53YXJuKCdNaXNzaW5nIHBvcnRyYWl0OicsaXRlbS5maWxlKTtyZXNvbHZlKG51bGwpO307CiAgICBpbWcuc3JjPXBob3RvVVJMKGl0ZW0uZmlsZSk7CiAgfSk7Cn0KZnVuY3Rpb24gdW5pcXVlRnJhbWUoaW5kZXgpewogIGNvbnN0IGZyYWdtZW50PXBhcnQoJ2ZyYW1lLXRlbXBsYXRlJykuY29udGVudC5jbG9uZU5vZGUodHJ1ZSk7CiAgLy8gRXZlcnkgaW5saW5lIFNWRyBnZXRzIGl0cyBvd24gZ3JhZGllbnQgSURzLCBpbmNsdWRpbmcgcmVwZWF0ZWQgY29waWVzIG9mIHRoaXMgcGFnZS4KICBjb25zdCBwcmVmaXg9YCR7aG9zdC5pZH0tcG9ydHJhaXQtJHtpbmRleH0tYDsKICBjb25zdCBpZHM9Wy4uLmZyYWdtZW50LnF1ZXJ5U2VsZWN0b3JBbGwoJ1tpZF0nKV0ubWFwKGU9PmUuaWQpOwogIGZvcihjb25zdCBlIG9mIGZyYWdtZW50LnF1ZXJ5U2VsZWN0b3JBbGwoJyonKSl7CiAgICBmb3IoY29uc3QgYSBvZiBbLi4uZS5hdHRyaWJ1dGVzXSl7CiAgICAgIGxldCB2YWx1ZT1hLnZhbHVlOwogICAgICBpZihhLm5hbWU9PT0naWQnKXZhbHVlPXByZWZpeCt2YWx1ZTsKICAgICAgZWxzZSBmb3IoY29uc3QgaWQgb2YgaWRzKXZhbHVlPXZhbHVlLnJlcGxhY2VBbGwoYHVybCgjJHtpZH0pYCxgdXJsKCMke3ByZWZpeH0ke2lkfSlgKS5yZXBsYWNlQWxsKGAjJHtpZH1gLGAjJHtwcmVmaXh9JHtpZH1gKTsKICAgICAgZS5zZXRBdHRyaWJ1dGUoYS5uYW1lLHZhbHVlKTsKICAgIH0KICB9CiAgcmV0dXJuIGZyYWdtZW50Owp9CmZ1bmN0aW9uIGZpdFRleHQoKXsKICBjb25zdCBjYXB0aW9ucz1bLi4ucm9vdC5xdWVyeVNlbGVjdG9yQWxsKCcuY2FwdGlvbicpXTsKICBjb25zdCBsaW5lcz1bLi4ucm9vdC5xdWVyeVNlbGVjdG9yQWxsKCcuY2FwdGlvbiAubmFtZSwuY2FwdGlvbiAudGl0bGUnKV07CiAgaWYoIWxpbmVzLmxlbmd0aClyZXR1cm47CiAgLy8gT25lIHNoYXJlZCBmb250IHNpemUgZm9yIEJPVEggbGluZXMgb24gRVZFUlkgdmlzaWJsZSBwbGFxdWUuCiAgY29uc3QgZml0cz1zaXplPT57CiAgICBsaW5lcy5mb3JFYWNoKGVsPT5lbC5zdHlsZS5mb250U2l6ZT1zaXplKydweCcpOwogICAgcmV0dXJuIGNhcHRpb25zLmV2ZXJ5KGVsPT5lbC5zY3JvbGxIZWlnaHQ8PWVsLmNsaWVudEhlaWdodCAmJgogICAgICBbLi4uZWwuY2hpbGRyZW5dLmV2ZXJ5KGxpbmU9PmxpbmUuc2Nyb2xsV2lkdGg8PWVsLmNsaWVudFdpZHRoICYmIGxpbmUuc2Nyb2xsSGVpZ2h0PD1saW5lLmNsaWVudEhlaWdodCkpOwogIH07CiAgbGV0IGxvdz0wLGhpZ2g9TWF0aC5taW4oLi4uY2FwdGlvbnMubWFwKGVsPT4oZWwuY2xpZW50SGVpZ2h0LTYpLygyKjEuMDgpKSk7CiAgZm9yKGxldCBpPTA7aTwxNjtpKyspe2NvbnN0IG1pZD0obG93K2hpZ2gpLzI7aWYoZml0cyhtaWQpKWxvdz1taWQ7ZWxzZSBoaWdoPW1pZDt9CiAgZml0cyhNYXRoLmZsb29yKGxvdyoxMDApLzEwMCk7Cn0KZnVuY3Rpb24gbGFiZWxJdGVtcygpewogIGNvbnN0IGNzdj1wYXJzZUNTVihsYWJlbENTVik7CiAgY29uc3QgaGVhZGVyPShjc3Yuc2hpZnQoKXx8W10pLm1hcCh2PT52LnRyaW0oKS50b0xvd2VyQ2FzZSgpKTsKICByZXR1cm4gY3N2Lm1hcChyb3c9Pk9iamVjdC5mcm9tRW50cmllcyhoZWFkZXIubWFwKChrZXksaSk9PltrZXksKHJvd1tpXXx8JycpLnRyaW0oKV0pKSkKICAgIC5maWx0ZXIoaXRlbT0+aXRlbS5maWxlICYmIC9cLnBuZyQvaS50ZXN0KGl0ZW0uZmlsZSkpOwp9CmZ1bmN0aW9uIGhlYWRpbmdUZXh0KGl0ZW1zLGdyb3VwKXsKICBjb25zdCBtZXRhZGF0YT1pdGVtc1swXXx8e307CiAgLy8gRWFjaCBxdWFkcmFudCByZWFkcyBvbmx5IHRoZSBtZXRhZGF0YSBzdG9yZWQgaW4gaXRzIG93biBDU1YuCiAgY29uc3QgeWVhcj1TdHJpbmcobWV0YWRhdGEueWVhcnx8JycpLnRyaW0oKTsKICBjb25zdCBxdWFydGVyPVN0cmluZyhtZXRhZGF0YS5xdWFydGVyfHwnJykudHJpbSgpOwogIGlmKCEvXlxkezR9JC8udGVzdCh5ZWFyKSlyZXR1cm4gJyc7CiAgaWYoZ3JvdXA9PT0ncXVhcnRlcmx5JylyZXR1cm4gL15bMS00XSQvLnRlc3QocXVhcnRlcik/YE1TRyBRdWFydGVyICR7cXVhcnRlcn0gQXdhcmQgV2lubmVycyAke3llYXJ9YDonJzsKICByZXR1cm4gYE1TRyBBbm51YWwgQXdhcmQgV2lubmVycyAke3llYXJ9YDsKfQpmdW5jdGlvbiB1cGRhdGVIZWFkaW5nKGl0ZW1zKXsKICBjb25zdCBoZWFkaW5nPXBhcnQoJ2hlYWRpbmcnKTsKICBoZWFkaW5nLnRleHRDb250ZW50PWhlYWRpbmdUZXh0KGl0ZW1zLCdfX1dJTk5FUl9HUk9VUF9fJyk7CiAgbGV0IHNpemU9NjQ7aGVhZGluZy5zdHlsZS5mb250U2l6ZT1zaXplKydweCc7CiAgd2hpbGUoc2l6ZT44ICYmIChoZWFkaW5nLnNjcm9sbFdpZHRoPmhlYWRpbmcuY2xpZW50V2lkdGggfHwgaGVhZGluZy5zY3JvbGxIZWlnaHQ+aGVhZGluZy5jbGllbnRIZWlnaHQpKXsKICAgIHNpemUtPTAuMjU7aGVhZGluZy5zdHlsZS5mb250U2l6ZT1zaXplKydweCc7CiAgfQp9CmZ1bmN0aW9uIHNldENhcHRpb24oY2FyZCxpdGVtKXsKICBjYXJkLnF1ZXJ5U2VsZWN0b3IoJy5jYXB0aW9uJyk/LnJlbW92ZSgpOwogIGNhcmQuY2xhc3NMaXN0LnRvZ2dsZSgnaGFzLWNhcHRpb24nLCEhKGl0ZW0ubmFtZXx8aXRlbS50aXRsZSkpOwogIGlmKCFpdGVtLm5hbWUmJiFpdGVtLnRpdGxlKXJldHVybjsKICBjb25zdCBjYXB0aW9uPWRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ2ZpZ2NhcHRpb24nKTtjYXB0aW9uLmNsYXNzTmFtZT0nY2FwdGlvbic7CiAgZm9yKGNvbnN0IGtleSBvZiBbJ25hbWUnLCd0aXRsZSddKXsKICAgIGNvbnN0IGxpbmU9ZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnZGl2Jyk7bGluZS5jbGFzc05hbWU9a2V5O2xpbmUudGV4dENvbnRlbnQ9aXRlbVtrZXldfHwnXHUwMGEwJztjYXB0aW9uLmFwcGVuZChsaW5lKTsKICB9CiAgY2FyZC5hcHBlbmQoY2FwdGlvbik7CiAgY2FyZC5xdWVyeVNlbGVjdG9yKCcucGhvdG8nKS5hbHQ9aXRlbS5uYW1lfHwnJzsKfQpmdW5jdGlvbiByZWZyZXNoTGFiZWxzKCl7CiAgY29uc3Qgc2NyaXB0PWRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ3NjcmlwdCcpOwogIHNjcmlwdC5zcmM9J19fV0lOTkVSX0RBVEFfSlNfXz90PScrRGF0ZS5ub3coKTsKICBzY3JpcHQub25sb2FkPSgpPT57CiAgICBpZih0eXBlb2Ygd2luZG93Lndpbm5lck5hbWVwbGF0ZUNTViE9PSdzdHJpbmcnKXtzY3JpcHQucmVtb3ZlKCk7cmV0dXJuO30KICAgIGxhYmVsQ1NWPXdpbmRvdy53aW5uZXJOYW1lcGxhdGVDU1Y7CiAgICBjb25zdCBsYWJlbHM9bGFiZWxJdGVtcygpOwogICAgdXBkYXRlSGVhZGluZyhsYWJlbHMpOwogICAgY29uc3QgaXRlbXM9bmV3IE1hcChsYWJlbHMubWFwKGl0ZW09PltpdGVtLmZpbGUsaXRlbV0pKTsKICAgIHJvb3QucXVlcnlTZWxlY3RvckFsbCgnLnBvcnRyYWl0JykuZm9yRWFjaChjYXJkPT5zZXRDYXB0aW9uKGNhcmQsaXRlbXMuZ2V0KGNhcmQuZGF0YXNldC5maWxlKXx8e30pKTsKICAgIGZpdFRleHQoKTtzY3JpcHQucmVtb3ZlKCk7CiAgfTsKICBzY3JpcHQub25lcnJvcj0oKT0+c2NyaXB0LnJlbW92ZSgpO2RvY3VtZW50LmhlYWQuYXBwZW5kKHNjcmlwdCk7Cn0KYXN5bmMgZnVuY3Rpb24gc3RhcnQoKXsKICBjb25zdCBpdGVtcz1sYWJlbEl0ZW1zKCk7CiAgYXdhaXQgZG9jdW1lbnQuZm9udHMucmVhZHk7CiAgdXBkYXRlSGVhZGluZyhpdGVtcyk7CiAgY29uc3Qgc2VsZWN0ZWQ9aXRlbXMubGVuZ3RoP2l0ZW1zOkFycmF5LmZyb20oe2xlbmd0aDpTRVRUSU5HUy5tYXhpbXVtUGhvdG9zfSwoXyxpKT0+KHtmaWxlOmBzbGlkZS0ke1N0cmluZyhTRVRUSU5HUy5maXJzdE51bWJlcitpKS5wYWRTdGFydCgzLCcwJyl9LnBuZ2AsbmFtZTonJyx0aXRsZTonJ30pKTsKICBjb25zdCBsb2FkZWQ9KGF3YWl0IFByb21pc2UuYWxsKHNlbGVjdGVkLm1hcChsb2FkUGhvdG8pKSkuZmlsdGVyKEJvb2xlYW4pLnNsaWNlKDAsMTEpOwogIGxvYWRlZC5mb3JFYWNoKChpdGVtLGluZGV4KT0+ewogICAgY29uc3QgY2FyZD1kb2N1bWVudC5jcmVhdGVFbGVtZW50KCdmaWd1cmUnKTtjYXJkLmNsYXNzTmFtZT0ncG9ydHJhaXQnO2NhcmQuZGF0YXNldC5maWxlPWl0ZW0uZmlsZTsKICAgIGNhcmQuYXBwZW5kKGl0ZW0uaW1nKTsKICAgIGNvbnN0IGZyYW1lPWRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ2RpdicpO2ZyYW1lLmNsYXNzTmFtZT0nZnJhbWUnO2ZyYW1lLmFwcGVuZCh1bmlxdWVGcmFtZShpbmRleCkpO2NhcmQuYXBwZW5kKGZyYW1lKTsKICAgIHNldENhcHRpb24oY2FyZCxpdGVtKTsKICAgIHBhcnQoaW5kZXg8NT8ndG9wJzonYm90dG9tJykuYXBwZW5kKGNhcmQpOwogIH0pOwogIGxheW91dFBvcnRyYWl0cygpOwogIGF3YWl0IGRvY3VtZW50LmZvbnRzLnJlYWR5OwogIGZpdFRleHQoKTsKICBzZXRJbnRlcnZhbChyZWZyZXNoTGFiZWxzLDYwMDAwKTsKfQpzdGFydCgpLmNhdGNoKGNvbnNvbGUuZXJyb3IpOwoKfSkoKTsKPC9zY3JpcHQ+'))
function New-WinnerQuadrantHtml {
    param([string]$Id, [string]$Group, [string]$Folder)
    $root = Split-Path $OutputFile -Parent
    $csvPath = Join-Path $root ($Group + '-winners.csv')
    if (-not (Test-Path -LiteralPath $csvPath)) {
        throw "Missing $csvPath. Run Update-Winners-Csv.ps1 before building the index."
    }
    $records = @(Import-Csv -LiteralPath $csvPath)
    if ($records.Count -eq 0 -or $null -eq $records[0].PSObject.Properties['file'] -or
        $null -eq $records[0].PSObject.Properties['name'] -or $null -eq $records[0].PSObject.Properties['title']) {
        throw "Invalid winners CSV: $csvPath. Expected file,name,title columns."
    }
    if ($null -eq $records[0].PSObject.Properties['year'] -or
        ($Group -eq 'quarterly' -and $null -eq $records[0].PSObject.Properties['quarter'])) {
        throw "Missing winner year/quarter metadata in $csvPath. Run the updated Update-Winners-Csv.ps1 first."
    }
    $csv = [IO.File]::ReadAllText($csvPath)
    # Protect the inline script container even if a cell contains HTML-like text.
    $csv = $csv.Replace('<', '&lt;')
    $folderJson = ConvertTo-Json -InputObject (Convert-ToFileUrl $Folder) -Compress
    $page = $WinnerTemplate.Replace('__WINNER_CSV__', $csv).Replace('__WINNER_DATA_JS__', ($Group + '-winners.js')).Replace('__WINNER_PHOTO_FOLDER__', $folderJson).Replace('__WINNER_TITLE__', ($Group + ' Winners')).Replace('__WINNER_HOST__', $Id).Replace('__WINNER_GROUP__', $Group)
    # Inline CSV uses raw script text: restore escaped less-than signs through a JS-safe decoding step.
    $page = $page.Replace("document.getElementById('portrait-csv').textContent.trim()", "document.getElementById('portrait-csv').textContent.trim().replaceAll('&lt;', String.fromCharCode(60))")
    return '<div id="' + $Id + '" class="quadrant winner-quadrant">' + $page + '</div>'
}

# ------------------------------------------------------------
# BUILD QUADRANTS
# ------------------------------------------------------------

$TopLeftHtml = New-QuadrantHtml `
    -Id "top-left" `
    -Images $TopLeftImages `
    -DurationSeconds $TopLeftDurationSeconds


$TopRightHtml = New-WinnerQuadrantHtml -Id "top-right" -Group "yearly" -Folder $TopRightFolder


$BottomLeftHtml = New-QuadrantHtml `
    -Id "bottom-left" `
    -Images $BottomLeftImages `
    -DurationSeconds $BottomLeftDurationSeconds


$BottomRightHtml = New-WinnerQuadrantHtml -Id "bottom-right" -Group "quarterly" -Folder $BottomRightFolder


# ------------------------------------------------------------
# BUILD COMPLETE HTML FILE
# ------------------------------------------------------------

$Html = @"
<!DOCTYPE html>

<html>

<head>

<meta charset="UTF-8">

<title>Four Corner Display</title>


<style>


/* ==========================================================
   PAGE
   ========================================================== */

html,
body {

    width: 100%;
    height: 100%;

    margin: 0;
    padding: 0;

    overflow: hidden;

    background: black;

}


/* ==========================================================
   4K DISPLAY AREA
   ========================================================== */

#display {

    position: relative;

    width: 3840px;
    height: 2160px;

    background: black;

    overflow: hidden;

}


/* ==========================================================
   QUADRANTS
   ========================================================== */

.quadrant {

    position: absolute;

    width: 1920px;
    height: 1080px;

    overflow: hidden;

    background: black;

}


/* Top Left */

#top-left {

    left: 0;
    top: 0;

}


/* Top Right */

#top-right {

    left: 1920px;
    top: 0;

}


/* Bottom Left */

#bottom-left {

    left: 0;
    top: 1080px;

}


/* Bottom Right */

#bottom-right {

    left: 1920px;
    top: 1080px;

}


/* ==========================================================
   IMAGES
   ========================================================== */

.quadrant img {

    position: absolute;

    left: 0;
    top: 0;

    width: 100%;
    height: 100%;

    object-fit: contain;

}


/* ==========================================================
   STATIC IMAGE
   ========================================================== */

.static-image {

    opacity: 1;

}


/* ==========================================================
   SLIDESHOW
   ========================================================== */

.slide {

    opacity: 0;

}


.slide.active {

    opacity: 1;

}


/* ==========================================================
   PROGRESS BAR
   ========================================================== */

.progress-background {

    position: absolute;

    left: 0;
    bottom: 0;

    width: 100%;
    height: 10px;

    background: rgba(255,255,255,0.20);

    z-index: 100;

}


.progress-bar {

    position: absolute;

    left: 0;
    top: 0;

    width: 0%;
    height: 100%;

    background: rgba(255,255,255,0.90);

}


/* ==========================================================
   EMPTY QUADRANTS
   ========================================================== */

.empty {

    background: black;

}


</style>

</head>


<body>


<div id="display">

$TopLeftHtml

$TopRightHtml

$BottomLeftHtml

$BottomRightHtml

</div>


<script>


/* ==========================================================
   START ONE SLIDESHOW
   ========================================================== */

function startSlideshow(container) {

    const slides =
        container.querySelectorAll(".slide");

    const progress =
        container.querySelector(".progress-bar");

    /*
       Read this quadrant's slideshow duration.
    */

    const slideDuration =
        Number(container.dataset.duration);


    if (slides.length <= 1) {

        return;

    }


    let currentSlide = 0;


    /* ------------------------------------------------------
       START PROGRESS BAR
       ------------------------------------------------------ */

    function startProgress() {

        /*
           Snap progress bar back to zero.
        */

        progress.style.transition = "none";

        progress.style.width = "0%";


        /*
           Force browser to apply width: 0.
        */

        void progress.offsetWidth;


        /*
           Fill progress bar over the slide duration.
        */

        progress.style.transition =
            "width " +
            slideDuration +
            "ms linear";

        progress.style.width = "100%";

    }


    /* ------------------------------------------------------
       CHANGE SLIDE
       ------------------------------------------------------ */

    function nextSlide() {

        /*
           Hide current image instantly.
        */

        slides[currentSlide]
            .classList.remove("active");


        /*
           Move to next image.
        */

        currentSlide++;


        /*
           Return to first image after last image.
        */

        if (currentSlide >= slides.length) {

            currentSlide = 0;

        }


        /*
           Show new image instantly.
        */

        slides[currentSlide]
            .classList.add("active");


        /*
           Restart progress bar.
        */

        startProgress();

    }


    /*
       Start first progress bar immediately.
    */

    startProgress();


    /*
       Advance slideshow using this quadrant's
       Google Sheets duration.
    */

    setInterval(
        nextSlide,
        slideDuration
    );

}


/* ==========================================================
   START ALL FOUR INDEPENDENT SLIDESHOWS
   ========================================================== */

document
    .querySelectorAll(".slideshow")
    .forEach(startSlideshow);


</script>


</body>

</html>
"@


# ------------------------------------------------------------
# WRITE HTML FILE
# ------------------------------------------------------------

$OutputDirectory =
    Split-Path $OutputFile


if (-not (Test-Path $OutputDirectory)) {

    New-Item `
        -ItemType Directory `
        -Path $OutputDirectory `
        -Force |
    Out-Null

}


Set-Content `
    -Path $OutputFile `
    -Value $Html `
    -Encoding UTF8


# ------------------------------------------------------------
# FINISHED
# ------------------------------------------------------------

Write-Host ""
Write-Host "HTML created:"
Write-Host $OutputFile

Write-Host ""
Write-Host "Slideshow delays:"
Write-Host "Top Left:     $TopLeftDurationSeconds seconds"
Write-Host "Top Right:    yearly winner grid (static)"
Write-Host "Bottom Left:  $BottomLeftDurationSeconds seconds"
Write-Host "Bottom Right: quarterly winner grid (static)"

Write-Host ""
