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

$CsvUrl = "https://docs.google.com/spreadsheets/d/$SheetId/export?format=csv&gid=$Gid"


# ------------------------------------------------------------
# DOWNLOAD GOOGLE SHEET
# ------------------------------------------------------------

Write-Host ""
Write-Host "Downloading slideshow timing from Google Sheets..."

try {

    $Response = Invoke-WebRequest `
        -Uri $CsvUrl `
        -UseBasicParsing

    $CsvText = $Response.Content

}
catch {

    Write-Host ""
    Write-Host "ERROR: Could not download Google Sheet."
    Write-Host $_.Exception.Message
    exit 1

}


# ------------------------------------------------------------
# PARSE GOOGLE SHEET
# ------------------------------------------------------------

$Rows = $CsvText | ConvertFrom-Csv -Header (
    1..100 | ForEach-Object { "Col$_" }
)


# ------------------------------------------------------------
# FUNCTION: GET GOOGLE SHEET CELL
# ------------------------------------------------------------

function Get-SheetCell {

    param (
        [string]$Cell
    )

    if ($Cell -notmatch '^([A-Za-z]+)(\d+)$') {

        throw "Invalid cell address: $Cell"

    }

    $ColumnLetters = $Matches[1].ToUpper()
    $RowNumber     = [int]$Matches[2]

    $ColumnNumber = 0

    foreach ($Character in $ColumnLetters.ToCharArray()) {

        $ColumnNumber =
            ($ColumnNumber * 26) +
            ([int][char]$Character - [int][char]'A' + 1)

    }

    $RowIndex = $RowNumber - 1

    return $Rows[$RowIndex].("Col$ColumnNumber")
}


# ------------------------------------------------------------
# READ SLIDESHOW DURATIONS
# ------------------------------------------------------------

$TopLeftDurationSeconds =
    [double](Get-SheetCell $TopLeftCell)

$BottomLeftDurationSeconds =
    [double](Get-SheetCell $BottomLeftCell)






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
$WinnerTemplate = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('PHRlbXBsYXRlIGNsYXNzPSJ3aW5uZXItY29udGVudCI+PHN0eWxlPiNfX1dJTk5FUl9IT1NUX18gKntib3gtc2l6aW5nOmJvcmRlci1ib3h9CiNfX1dJTk5FUl9IT1NUX18gW2RhdGEtcGFydD0ic3RhZ2UiXXtwb3NpdGlvbjphYnNvbHV0ZTt3aWR0aDoxOTIwcHg7aGVpZ2h0OjEwODBweDt0cmFuc2Zvcm0tb3JpZ2luOnRvcCBsZWZ0fSNfX1dJTk5FUl9IT1NUX18gLnJvd3twb3NpdGlvbjphYnNvbHV0ZTtsZWZ0OjA7d2lkdGg6MTkyMHB4O2Rpc3BsYXk6ZmxleDtqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyO2dhcDoxOS4ycHh9I19fV0lOTkVSX0hPU1RfXyBbZGF0YS1wYXJ0PSJ0b3AiXXt0b3A6MjQ0cHh9I19fV0lOTkVSX0hPU1RfXyBbZGF0YS1wYXJ0PSJib3R0b20iXXt0b3A6NjQycHh9I19fV0lOTkVSX0hPU1RfXyAucG9ydHJhaXR7cG9zaXRpb246cmVsYXRpdmU7d2lkdGg6MzA0cHg7aGVpZ2h0OjM4NHB4O2ZsZXg6bm9uZTttYXJnaW46MH0jX19XSU5ORVJfSE9TVF9fIC5waG90b3twb3NpdGlvbjphYnNvbHV0ZTt6LWluZGV4OjA7bGVmdDpjYWxjKDQuMTgxMiUgLSAzcHgpO3RvcDpjYWxjKDMuNTgxMyUgLSAzcHgpO3dpZHRoOmNhbGMoOTEuOTg2MSUgKyA2cHgpO2hlaWdodDpjYWxjKDgzLjE5NTYlICsgNnB4KTtvYmplY3QtZml0OmNvdmVyO29iamVjdC1wb3NpdGlvbjpjZW50ZXIgdG9wO2Rpc3BsYXk6YmxvY2t9I19fV0lOTkVSX0hPU1RfXyAuZnJhbWV7cG9zaXRpb246YWJzb2x1dGU7ei1pbmRleDoxO2luc2V0OjA7cG9pbnRlci1ldmVudHM6bm9uZX0jX19XSU5ORVJfSE9TVF9fIC5mcmFtZSBzdmd7d2lkdGg6MTAwJTtoZWlnaHQ6MTAwJTtkaXNwbGF5OmJsb2NrO292ZXJmbG93OnZpc2libGV9I19fV0lOTkVSX0hPU1RfXyAuY2FwdGlvbntwb3NpdGlvbjphYnNvbHV0ZTt6LWluZGV4OjI7bGVmdDo5JTtyaWdodDo5JTt0b3A6ODguMTU0MjclO2hlaWdodDoxMS4wMTkyOCU7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyO2ZsZXgtZGlyZWN0aW9uOmNvbHVtbjtnYXA6NnB4O2NvbG9yOiNmZmZmZmY7dGV4dC1hbGlnbjpjZW50ZXI7Zm9udC1mYW1pbHk6QXJpYWwsc2Fucy1zZXJpZjt0ZXh0LXNoYWRvdzowIDFweCAycHggIzAwMDtsaW5lLWhlaWdodDoxLjA4O292ZXJmbG93OmhpZGRlbn0jX19XSU5ORVJfSE9TVF9fIC5jYXB0aW9uIC5uYW1lLCNfX1dJTk5FUl9IT1NUX18gLmNhcHRpb24gLnRpdGxle2ZvbnQtd2VpZ2h0OjcwMDtmbGV4Om5vbmU7d2lkdGg6MTAwJTtoZWlnaHQ6Y2FsYygoMTAwJSAtIDZweCkvMik7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyO21heC13aWR0aDoxMDAlO3doaXRlLXNwYWNlOm5vd3JhcDtsaW5lLWhlaWdodDoxLjA4fSNfX1dJTk5FUl9IT1NUX18gLmltZy1iZ3sKICAgICAgICBwb3NpdGlvbjogYWJzb2x1dGU7CiAgICAgICAgdG9wOiAwcHg7CiAgICAgICAgbGVmdDowcHg7CiAgICAgICAgd2lkdGg6IDE5MjBweDsKICAgICAgICBoZWlnaHQ6IDEwODBweDsKICAgICAgICB6LWluZGV4OiAtMTsKICAgICAgICBib3JkZXI6IG5vbmU7CiAgICB9CgojX19XSU5ORVJfSE9TVF9fIFtkYXRhLXBhcnQ9InN0YWdlIl17aXNvbGF0aW9uOmlzb2xhdGV9CgojX19XSU5ORVJfSE9TVF9fIC53aW5uZXItaGVhZGluZ3twb3NpdGlvbjphYnNvbHV0ZTt6LWluZGV4OjM7bGVmdDo0NDVweDt0b3A6NjVweDt3aWR0aDoxMDMwcHg7aGVpZ2h0Ojg2cHg7bWFyZ2luOjA7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyO3RleHQtYWxpZ246Y2VudGVyO2ZvbnQtZmFtaWx5Okdlb3JnaWEsJ1RpbWVzIE5ldyBSb21hbicsc2VyaWY7Zm9udC13ZWlnaHQ6NzAwO2ZvbnQtc2l6ZTo2NHB4O2xpbmUtaGVpZ2h0OjEuMTtjb2xvcjojZmZmNGQ1O3RleHQtc2hhZG93OjEycHggMTVweCAxLjVweCAjMDAwLDE1cHggMTkuNXB4IDcuNXB4IHJnYmEoMCwwLDAsLjk1KTt3aGl0ZS1zcGFjZTpub3dyYXA7b3ZlcmZsb3c6dmlzaWJsZX0KPC9zdHlsZT4KPGRpdiBkYXRhLXBhcnQ9InN0YWdlIj48aW1nIGRhdGEtc25vdyBjbGFzcz0iaW1nLWJnIiBzcmM9ImltYWdlcy9iZy5wbmciLz48aDEgY2xhc3M9Indpbm5lci1oZWFkaW5nIiBkYXRhLXBhcnQ9ImhlYWRpbmciIGFyaWEtbGl2ZT0icG9saXRlIj48L2gxPjxkaXYgZGF0YS1wYXJ0PSJ0b3AiIGNsYXNzPSJyb3ciPjwvZGl2PjxkaXYgZGF0YS1wYXJ0PSJib3R0b20iIGNsYXNzPSJyb3ciPjwvZGl2PjwvZGl2Pgo8IS0tIEV4YWN0LWNlbGwgQ1NWIGlzIGVtYmVkZGVkIGJ5IHRoZSBidWlsZGVyLiAtLT4KPHNjcmlwdCBkYXRhLXBhcnQ9InBvcnRyYWl0LWNzdiIgdHlwZT0idGV4dC9wbGFpbiI+Cl9fV0lOTkVSX0NTVl9fCjwvc2NyaXB0Pgo8IS0tIEdlbmVyYXRlZCBieSBVcGRhdGUtV2lubmVycy1Dc3YucHMxOyB3b3JrcyB3aXRoIGxvY2FsIGZpbGUgcGxheWJhY2suIC0tPgoKPHRlbXBsYXRlIGRhdGEtcGFydD0iZnJhbWUtdGVtcGxhdGUiPjxzdmcgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB2aWV3Qm94PSIxMyAyMiAyODcgMzYzIiBwcmVzZXJ2ZUFzcGVjdFJhdGlvPSJub25lIiBmaWxsPSJub25lIiByb2xlPSJpbWciIGFyaWEtbGFiZWw9IlNoaW5pbmcgZ29sZCBwaWN0dXJlIGZyYW1lIHdpdGggYmxhY2sgZGVjb3JhdGl2ZSBuYW1lcGxhdGUiPgo8ZGVmcz4KICA8bGluZWFyR3JhZGllbnQgaWQ9ImdmLWdvbGQiIHgxPSIwIiB5MT0iMCIgeDI9IjEiIHkyPSIxIj4KICAgIDxzdG9wIHN0b3AtY29sb3I9IiM2OTQwMGIiLz48c3RvcCBvZmZzZXQ9Ii4xMiIgc3RvcC1jb2xvcj0iI2ZmZjRiNCIvPjxzdG9wIG9mZnNldD0iLjI0IiBzdG9wLWNvbG9yPSIjYzU4YjIwIi8+PHN0b3Agb2Zmc2V0PSIuNCIgc3RvcC1jb2xvcj0iI2ZmZWFhMCIvPjxzdG9wIG9mZnNldD0iLjUiIHN0b3AtY29sb3I9IiNmZmZkZTEiLz48c3RvcCBvZmZzZXQ9Ii42IiBzdG9wLWNvbG9yPSIjYTg2OTBkIi8+PHN0b3Agb2Zmc2V0PSIuNzgiIHN0b3AtY29sb3I9IiNmNGNhNjEiLz48c3RvcCBvZmZzZXQ9Ii45IiBzdG9wLWNvbG9yPSIjODA1MDBjIi8+PHN0b3Agb2Zmc2V0PSIxIiBzdG9wLWNvbG9yPSIjZmZmMGEwIi8+CiAgPC9saW5lYXJHcmFkaWVudD4KICA8bGluZWFyR3JhZGllbnQgaWQ9ImdmLXZlcnRpY2FsIiB4MT0iMCIgeTE9IjAiIHgyPSIwIiB5Mj0iMSI+CiAgICA8c3RvcCBzdG9wLWNvbG9yPSIjZmZmOGNiIi8+PHN0b3Agb2Zmc2V0PSIuMDYiIHN0b3AtY29sb3I9IiNmZmU1OTUiLz48c3RvcCBvZmZzZXQ9Ii4xOCIgc3RvcC1jb2xvcj0iI2I1NzUxMSIvPjxzdG9wIG9mZnNldD0iLjMyIiBzdG9wLWNvbG9yPSIjZjRjNDU3Ii8+PHN0b3Agb2Zmc2V0PSIuMzkiIHN0b3AtY29sb3I9IiNmZmZiZDYiLz48c3RvcCBvZmZzZXQ9Ii40NiIgc3RvcC1jb2xvcj0iI2U2YjM0MyIvPjxzdG9wIG9mZnNldD0iLjY3IiBzdG9wLWNvbG9yPSIjOGY1NjA5Ii8+PHN0b3Agb2Zmc2V0PSIuODgiIHN0b3AtY29sb3I9IiNmOWRiNzgiLz48c3RvcCBvZmZzZXQ9IjEiIHN0b3AtY29sb3I9IiNhYjc0MWEiLz4KICA8L2xpbmVhckdyYWRpZW50PgogIDxsaW5lYXJHcmFkaWVudCBpZD0iZ2YtdG9wIiB4MT0iMCIgeTE9IjAiIHgyPSIxIiB5Mj0iMCI+CiAgICA8c3RvcCBzdG9wLWNvbG9yPSIjZmZmMmFlIi8+PHN0b3Agb2Zmc2V0PSIuMSIgc3RvcC1jb2xvcj0iI2ZmZmRlOCIvPjxzdG9wIG9mZnNldD0iLjIyIiBzdG9wLWNvbG9yPSIjYmI3YTE3Ii8+PHN0b3Agb2Zmc2V0PSIuNDIiIHN0b3AtY29sb3I9IiNmZmRhN2QiLz48c3RvcCBvZmZzZXQ9Ii41MyIgc3RvcC1jb2xvcj0iI2ZmZiIvPjxzdG9wIG9mZnNldD0iLjYzIiBzdG9wLWNvbG9yPSIjZWFhNjNlIi8+PHN0b3Agb2Zmc2V0PSIuODMiIHN0b3AtY29sb3I9IiNhOTZiMGMiLz48c3RvcCBvZmZzZXQ9IjEiIHN0b3AtY29sb3I9IiNmZmY0YjgiLz4KICA8L2xpbmVhckdyYWRpZW50PgogIDxsaW5lYXJHcmFkaWVudCBpZD0iZ2YtYmxhY2siIHgxPSIwIiB5MT0iMCIgeDI9IjAiIHkyPSIxIj4KICAgIDxzdG9wIHN0b3AtY29sb3I9IiMwODA4MDciLz48c3RvcCBvZmZzZXQ9Ii40OCIgc3RvcC1jb2xvcj0iIzFkMWQxYSIvPjxzdG9wIG9mZnNldD0iLjU1IiBzdG9wLWNvbG9yPSIjMGIwYjA5Ii8+PHN0b3Agb2Zmc2V0PSIxIiBzdG9wLWNvbG9yPSIjMTQxNDEwIi8+CiAgPC9saW5lYXJHcmFkaWVudD4KICA8cmFkaWFsR3JhZGllbnQgaWQ9ImdmLXNoaW5lIj48c3RvcCBzdG9wLWNvbG9yPSIjZmZmIi8+PHN0b3Agb2Zmc2V0PSIuMTYiIHN0b3AtY29sb3I9IiNmZmZkZTIiIHN0b3Atb3BhY2l0eT0iLjk4Ii8+PHN0b3Agb2Zmc2V0PSIuNCIgc3RvcC1jb2xvcj0iI2ZmY2Y3MCIgc3RvcC1vcGFjaXR5PSIuNjUiLz48c3RvcCBvZmZzZXQ9IjEiIHN0b3AtY29sb3I9IiNmZmE1MmIiIHN0b3Atb3BhY2l0eT0iMCIvPjwvcmFkaWFsR3JhZGllbnQ+CiAgPHBhdHRlcm4gaWQ9ImdmLWJydXNoIiB3aWR0aD0iMTkiIGhlaWdodD0iMyIgcGF0dGVyblVuaXRzPSJ1c2VyU3BhY2VPblVzZSI+PHBhdGggZD0iTTAgLjVIMTlNNCAySDE2IiBzdHJva2U9IiNkMmJlN2UiIHN0cm9rZS1vcGFjaXR5PSIuMDY1IiBzdHJva2Utd2lkdGg9Ii40Ii8+PC9wYXR0ZXJuPgogIDxnIGlkPSJnZi1yb3NldHRlIj48Y2lyY2xlIHI9IjQuNSIgZmlsbD0idXJsKCNnZi1nb2xkKSIgc3Ryb2tlPSIjZmZlZDljIiBzdHJva2Utd2lkdGg9Ii41Ii8+PHBhdGggZD0iTS0zIDBIM00wLTNWM00tMi0yIDIgMk0tMiAyIDItMiIgc3Ryb2tlPSIjODA1MzE1IiBzdHJva2Utd2lkdGg9Ii42Ii8+PGNpcmNsZSByPSIxLjIiIGZpbGw9IiNmZmYxYjAiLz48L2c+CjwvZGVmcz4KPCEtLSBUaGUgb3V0c2lkZSBhbmQgdGhlIHBpY3R1cmUgb3BlbmluZyBhcmUgdHJhbnNwYXJlbnQuIC0tPgo8cGF0aCBkPSJNMTMgMjJIMzAxVjM4NkgxM1pNMjUgMzVWMzM3SDI4OVYzNVoiIGZpbGw9IiMxMjBlMDciIGZpbGwtcnVsZT0iZXZlbm9kZCIvPgo8cGF0aCBkPSJNMTQgMjNIMzAwVjM4NUgxNFpNMjAgMjlWMzc5SDI5NFYyOVoiIGZpbGw9InVybCgjZ2YtdmVydGljYWwpIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiLz4KPHBhdGggZD0iTTE0IDIzSDMwMEwyOTQgMjlIMjBaIiBmaWxsPSJ1cmwoI2dmLXRvcCkiLz4KPHBhdGggZD0iTTIwIDI5SDI5NFYzMzlIMjg5VjM1SDI1VjMzOUgyMFoiIGZpbGw9IiMwNzA3MDUiLz4KPHBhdGggZD0iTTE0LjUgMzM3VjIzLjVIMjk5LjVWMzM3TTE5LjUgMzM3VjI5LjVIMjk0LjVWMzM3IiBzdHJva2U9IiNmZmYzYjAiIHN0cm9rZS13aWR0aD0iLjY1Ii8+CjxwYXRoIGQ9Ik0yMiAzMzdWMzJIMjkyVjMzNyIgc3Ryb2tlPSIjYWQ3NTIxIiBzdHJva2Utd2lkdGg9Ii43Ii8+CjwhLS0gQnJ1c2hlZCBibGFjayBuYW1lcGxhdGUgd2l0aCBkb3VibGUgZ29sZCB0cmltLiAtLT4KPHBhdGggZD0iTTEzIDMzN0gzMDBWMzg1SDEzWiIgZmlsbD0idXJsKCNnZi1ibGFjaykiIHN0cm9rZT0idXJsKCNnZi1nb2xkKSIgc3Ryb2tlLXdpZHRoPSIxLjgiLz4KPHBhdGggZD0iTTE1IDMzOUgyOThWMzgzSDE1WiIgZmlsbD0idXJsKCNnZi1icnVzaCkiIHN0cm9rZT0iI2U1YzY2ZCIgc3Ryb2tlLXdpZHRoPSIuNjUiLz4KPHBhdGggZD0iTTI1IDM0MEgyODhRMjg5IDM0OCAyOTcgMzQ5VjM3NFEyODkgMzc1IDI4OCAzODJIMjVRMjQgMzc1IDE2IDM3NFYzNDlRMjQgMzQ4IDI1IDM0MFoiIHN0cm9rZT0idXJsKCNnZi1nb2xkKSIgc3Ryb2tlLXdpZHRoPSIxLjIiLz4KPHBhdGggZD0iTTE3IDM0MUgyM1EyMiAzNDYgMTcgMzQ3Wk0yOTAgMzQxSDI5NlYzNDdRMjkxIDM0NiAyOTAgMzQxWk0xNyAzNzZRMjIgMzc3IDIzIDM4MUgxN1pNMjkwIDM4MVEyOTEgMzc3IDI5NiAzNzZWMzgxWiIgZmlsbD0idXJsKCNnZi1nb2xkKSIvPgo8ZyBjbGFzcz0icGxhcXVlLW9ybmFtZW50Ij4KPHBhdGggZD0iTTM1IDM2MkgyNzkiIHN0cm9rZT0iI2RkYmI1MyIgc3Ryb2tlLXdpZHRoPSIuODUiLz4KPGNpcmNsZSBjeD0iMzUiIGN5PSIzNjIiIHI9IjEuMiIgZmlsbD0iI2ZmZjBhMiIvPjxjaXJjbGUgY3g9IjI3OSIgY3k9IjM2MiIgcj0iMS4yIiBmaWxsPSIjZmZmMGEyIi8+Cjx1c2UgaHJlZj0iI2dmLXJvc2V0dGUiIHg9IjI1IiB5PSIzNjIiLz48dXNlIGhyZWY9IiNnZi1yb3NldHRlIiB4PSIyODciIHk9IjM2MiIvPgo8L2c+CjwhLS0gSGlnaGxpZ2h0IGZsYXJlIHJlbWFpbnMgZ29sZCBhbmQgd2hpdGUsIHdpdGggbm8gYmx1ZSBiYWNrZHJvcC4gLS0+CjxlbGxpcHNlIGN4PSIxNjgiIGN5PSIyNSIgcng9IjYyIiByeT0iMTQiIGZpbGw9InVybCgjZ2Ytc2hpbmUpIi8+CjxlbGxpcHNlIGN4PSIxNjgiIGN5PSIyNSIgcng9IjM0IiByeT0iMy44IiBmaWxsPSJ1cmwoI2dmLXNoaW5lKSIvPgo8cGF0aCBkPSJtMTMwIDI1IDMwLTEuMyA4LTMgOCAzIDMwIDEuMy0zMCAxLjMtOCAyLjctOC0yLjdaIiBmaWxsPSJ1cmwoI2dmLXRvcCkiLz4KPGVsbGlwc2UgY3g9IjE2OCIgY3k9IjI0LjgiIHJ4PSIxMSIgcnk9IjIuMyIgZmlsbD0iI2ZmZmVmMiIvPgo8L3N2Zz4KPC90ZW1wbGF0ZT4KCjwvdGVtcGxhdGU+CjxzY3JpcHQ+CigoKT0+e2NvbnN0IGhvc3Q9ZG9jdW1lbnQuY3VycmVudFNjcmlwdC5wYXJlbnRFbGVtZW50Owpob3N0LnByZXBlbmQoaG9zdC5xdWVyeVNlbGVjdG9yKCIud2lubmVyLWNvbnRlbnQiKS5jb250ZW50LmNsb25lTm9kZSh0cnVlKSk7CgondXNlIHN0cmljdCc7CmNvbnN0IFNFVFRJTkdTID0gewogIHBob3RvRm9sZGVyOiBfX1dJTk5FUl9QSE9UT19GT0xERVJfXywgICAgIC8vIFJlbGF0aXZlIHRvIGluZGV4Lmh0bWwsIGUuZy4gJ2ltYWdlcy9sZWFkZXJzaGlwJy4KICBmaXJzdE51bWJlcjogMCwgICAgICAgICAgICAvLyBBdXRvbWF0aWMgbW9kZSBjaGVja3Mgc2xpZGUtMDAwLnBuZyB0aHJvdWdoIHNsaWRlLTAxMC5wbmcuCiAgbWF4aW11bVBob3RvczogMTEKfTsKY29uc3Qgcm9vdD1ob3N0Owpjb25zdCBwYXJ0PWlkPT5yb290LnF1ZXJ5U2VsZWN0b3IoYFtkYXRhLXBhcnQ9IiR7aWR9Il1gKTsKbGV0IGxhYmVsQ1NWPXBhcnQoJ3BvcnRyYWl0LWNzdicpLnRleHRDb250ZW50LnRyaW0oKS5yZXBsYWNlQWxsKCcmbHQ7JywgU3RyaW5nLmZyb21DaGFyQ29kZSg2MCkpOwpjb25zdCBzdGFnZSA9IHBhcnQoJ3N0YWdlJyk7CmZ1bmN0aW9uIHJlc2l6ZSgpewogIGNvbnN0IHNjYWxlPU1hdGgubWluKGhvc3QuY2xpZW50V2lkdGgvMTkyMCxob3N0LmNsaWVudEhlaWdodC8xMDgwKTsKICBzdGFnZS5zdHlsZS50cmFuc2Zvcm09YHNjYWxlKCR7c2NhbGV9KWA7CiAgc3RhZ2Uuc3R5bGUubGVmdD1gJHsoaG9zdC5jbGllbnRXaWR0aC0xOTIwKnNjYWxlKS8yfXB4YDsKICBzdGFnZS5zdHlsZS50b3A9YCR7KGhvc3QuY2xpZW50SGVpZ2h0LTEwODAqc2NhbGUpLzJ9cHhgOwp9CmFkZEV2ZW50TGlzdGVuZXIoJ3Jlc2l6ZScscmVzaXplKTtyZXNpemUoKTsKZnVuY3Rpb24gcGFyc2VDU1YodGV4dCl7CiAgY29uc3Qgcm93cz1bXTtsZXQgcm93PVtdLGZpZWxkPScnLHF1b3RlZD1mYWxzZTsKICB0ZXh0PXRleHQucmVwbGFjZSgvXlx1RkVGRi8sJycpOwogIGZvcihsZXQgaT0wO2k8dGV4dC5sZW5ndGg7aSsrKXsKICAgIGNvbnN0IGM9dGV4dFtpXTsKICAgIGlmKGM9PT0nIicpewogICAgICBpZihxdW90ZWQgJiYgdGV4dFtpKzFdPT09JyInKXtmaWVsZCs9JyInO2krKzt9ZWxzZSBxdW90ZWQ9IXF1b3RlZDsKICAgIH1lbHNlIGlmKGM9PT0nLCcgJiYgIXF1b3RlZCl7cm93LnB1c2goZmllbGQpO2ZpZWxkPScnO30KICAgIGVsc2UgaWYoKGM9PT0nXG4nfHxjPT09J1xyJykmJiFxdW90ZWQpewogICAgICBpZihjPT09J1xyJyYmdGV4dFtpKzFdPT09J1xuJylpKys7CiAgICAgIHJvdy5wdXNoKGZpZWxkKTtpZihyb3cuc29tZSh2PT52LnRyaW0oKSkpcm93cy5wdXNoKHJvdyk7cm93PVtdO2ZpZWxkPScnOwogICAgfWVsc2UgZmllbGQrPWM7CiAgfQogIHJvdy5wdXNoKGZpZWxkKTtpZihyb3cuc29tZSh2PT52LnRyaW0oKSkpcm93cy5wdXNoKHJvdyk7CiAgcmV0dXJuIHJvd3M7Cn0KZnVuY3Rpb24gcGhvdG9VUkwoZmlsZSl7CiAgcmV0dXJuIFNFVFRJTkdTLnBob3RvRm9sZGVyLnJlcGxhY2UoL1wvJC8sJycpKycvJytmaWxlLnNwbGl0KCcvJykubWFwKGVuY29kZVVSSUNvbXBvbmVudCkuam9pbignLycpOwp9CmZ1bmN0aW9uIGxvYWRQaG90byhpdGVtKXsKICByZXR1cm4gbmV3IFByb21pc2UocmVzb2x2ZT0+ewogICAgY29uc3QgaW1nPW5ldyBJbWFnZSgpO2ltZy5jbGFzc05hbWU9J3Bob3RvJztpbWcuYWx0PWl0ZW0ubmFtZXx8Jyc7CiAgICBpbWcub25sb2FkPSgpPT5yZXNvbHZlKHsuLi5pdGVtLGltZ30pOwogICAgaW1nLm9uZXJyb3I9KCk9Pntjb25zb2xlLndhcm4oJ01pc3NpbmcgcG9ydHJhaXQ6JyxpdGVtLmZpbGUpO3Jlc29sdmUobnVsbCk7fTsKICAgIGltZy5zcmM9cGhvdG9VUkwoaXRlbS5maWxlKTsKICB9KTsKfQpmdW5jdGlvbiB1bmlxdWVGcmFtZShpbmRleCl7CiAgY29uc3QgZnJhZ21lbnQ9cGFydCgnZnJhbWUtdGVtcGxhdGUnKS5jb250ZW50LmNsb25lTm9kZSh0cnVlKTsKICAvLyBFdmVyeSBpbmxpbmUgU1ZHIGdldHMgaXRzIG93biBncmFkaWVudCBJRHMsIGluY2x1ZGluZyByZXBlYXRlZCBjb3BpZXMgb2YgdGhpcyBwYWdlLgogIGNvbnN0IHByZWZpeD1gJHtob3N0LmlkfS1wb3J0cmFpdC0ke2luZGV4fS1gOwogIGNvbnN0IGlkcz1bLi4uZnJhZ21lbnQucXVlcnlTZWxlY3RvckFsbCgnW2lkXScpXS5tYXAoZT0+ZS5pZCk7CiAgZm9yKGNvbnN0IGUgb2YgZnJhZ21lbnQucXVlcnlTZWxlY3RvckFsbCgnKicpKXsKICAgIGZvcihjb25zdCBhIG9mIFsuLi5lLmF0dHJpYnV0ZXNdKXsKICAgICAgbGV0IHZhbHVlPWEudmFsdWU7CiAgICAgIGlmKGEubmFtZT09PSdpZCcpdmFsdWU9cHJlZml4K3ZhbHVlOwogICAgICBlbHNlIGZvcihjb25zdCBpZCBvZiBpZHMpdmFsdWU9dmFsdWUucmVwbGFjZUFsbChgdXJsKCMke2lkfSlgLGB1cmwoIyR7cHJlZml4fSR7aWR9KWApLnJlcGxhY2VBbGwoYCMke2lkfWAsYCMke3ByZWZpeH0ke2lkfWApOwogICAgICBlLnNldEF0dHJpYnV0ZShhLm5hbWUsdmFsdWUpOwogICAgfQogIH0KICByZXR1cm4gZnJhZ21lbnQ7Cn0KZnVuY3Rpb24gZml0VGV4dCgpewogIGNvbnN0IGNhcHRpb25zPVsuLi5yb290LnF1ZXJ5U2VsZWN0b3JBbGwoJy5jYXB0aW9uJyldOwogIGNvbnN0IGxpbmVzPVsuLi5yb290LnF1ZXJ5U2VsZWN0b3JBbGwoJy5jYXB0aW9uIC5uYW1lLC5jYXB0aW9uIC50aXRsZScpXTsKICBpZighbGluZXMubGVuZ3RoKXJldHVybjsKICAvLyBPbmUgc2hhcmVkIGZvbnQgc2l6ZSBmb3IgQk9USCBsaW5lcyBvbiBFVkVSWSB2aXNpYmxlIHBsYXF1ZS4KICBjb25zdCBmaXRzPXNpemU9PnsKICAgIGxpbmVzLmZvckVhY2goZWw9PmVsLnN0eWxlLmZvbnRTaXplPXNpemUrJ3B4Jyk7CiAgICByZXR1cm4gY2FwdGlvbnMuZXZlcnkoZWw9PmVsLnNjcm9sbEhlaWdodDw9ZWwuY2xpZW50SGVpZ2h0ICYmCiAgICAgIFsuLi5lbC5jaGlsZHJlbl0uZXZlcnkobGluZT0+bGluZS5zY3JvbGxXaWR0aDw9ZWwuY2xpZW50V2lkdGggJiYgbGluZS5zY3JvbGxIZWlnaHQ8PWxpbmUuY2xpZW50SGVpZ2h0KSk7CiAgfTsKICBsZXQgbG93PTAsaGlnaD1NYXRoLm1pbiguLi5jYXB0aW9ucy5tYXAoZWw9PihlbC5jbGllbnRIZWlnaHQtNikvKDIqMS4wOCkpKTsKICBmb3IobGV0IGk9MDtpPDE2O2krKyl7Y29uc3QgbWlkPShsb3craGlnaCkvMjtpZihmaXRzKG1pZCkpbG93PW1pZDtlbHNlIGhpZ2g9bWlkO30KICBmaXRzKE1hdGguZmxvb3IobG93KjEwMCkvMTAwKTsKfQpmdW5jdGlvbiBsYWJlbEl0ZW1zKCl7CiAgY29uc3QgY3N2PXBhcnNlQ1NWKGxhYmVsQ1NWKTsKICBjb25zdCBoZWFkZXI9KGNzdi5zaGlmdCgpfHxbXSkubWFwKHY9PnYudHJpbSgpLnRvTG93ZXJDYXNlKCkpOwogIHJldHVybiBjc3YubWFwKHJvdz0+T2JqZWN0LmZyb21FbnRyaWVzKGhlYWRlci5tYXAoKGtleSxpKT0+W2tleSwocm93W2ldfHwnJykudHJpbSgpXSkpKQogICAgLmZpbHRlcihpdGVtPT5pdGVtLmZpbGUgJiYgL1wucG5nJC9pLnRlc3QoaXRlbS5maWxlKSk7Cn0KZnVuY3Rpb24gaGVhZGluZ1RleHQoaXRlbXMsZ3JvdXApewogIGNvbnN0IG1ldGFkYXRhPWl0ZW1zWzBdfHx7fTsKICAvLyBFYWNoIHF1YWRyYW50IHJlYWRzIG9ubHkgdGhlIG1ldGFkYXRhIHN0b3JlZCBpbiBpdHMgb3duIENTVi4KICBjb25zdCB5ZWFyPVN0cmluZyhtZXRhZGF0YS55ZWFyfHwnJykudHJpbSgpOwogIGNvbnN0IHF1YXJ0ZXI9U3RyaW5nKG1ldGFkYXRhLnF1YXJ0ZXJ8fCcnKS50cmltKCk7CiAgaWYoIS9eXGR7NH0kLy50ZXN0KHllYXIpKXJldHVybiAnJzsKICBpZihncm91cD09PSdxdWFydGVybHknKXJldHVybiAvXlsxLTRdJC8udGVzdChxdWFydGVyKT9gTVNHIFF1YXJ0ZXIgJHtxdWFydGVyfSBBd2FyZCBXaW5uZXJzICR7eWVhcn1gOicnOwogIHJldHVybiBgTVNHIEFubnVhbCBBd2FyZCBXaW5uZXJzICR7eWVhcn1gOwp9CmZ1bmN0aW9uIHVwZGF0ZUhlYWRpbmcoaXRlbXMpewogIGNvbnN0IGhlYWRpbmc9cGFydCgnaGVhZGluZycpOwogIGhlYWRpbmcudGV4dENvbnRlbnQ9aGVhZGluZ1RleHQoaXRlbXMsJ19fV0lOTkVSX0dST1VQX18nKTsKICBsZXQgc2l6ZT02NDtoZWFkaW5nLnN0eWxlLmZvbnRTaXplPXNpemUrJ3B4JzsKICB3aGlsZShzaXplPjggJiYgKGhlYWRpbmcuc2Nyb2xsV2lkdGg+aGVhZGluZy5jbGllbnRXaWR0aCB8fCBoZWFkaW5nLnNjcm9sbEhlaWdodD5oZWFkaW5nLmNsaWVudEhlaWdodCkpewogICAgc2l6ZS09MC4yNTtoZWFkaW5nLnN0eWxlLmZvbnRTaXplPXNpemUrJ3B4JzsKICB9Cn0KZnVuY3Rpb24gc2V0Q2FwdGlvbihjYXJkLGl0ZW0pewogIGNhcmQucXVlcnlTZWxlY3RvcignLmNhcHRpb24nKT8ucmVtb3ZlKCk7CiAgY2FyZC5jbGFzc0xpc3QudG9nZ2xlKCdoYXMtY2FwdGlvbicsISEoaXRlbS5uYW1lfHxpdGVtLnRpdGxlKSk7CiAgaWYoIWl0ZW0ubmFtZSYmIWl0ZW0udGl0bGUpcmV0dXJuOwogIGNvbnN0IGNhcHRpb249ZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnZmlnY2FwdGlvbicpO2NhcHRpb24uY2xhc3NOYW1lPSdjYXB0aW9uJzsKICBmb3IoY29uc3Qga2V5IG9mIFsnbmFtZScsJ3RpdGxlJ10pewogICAgY29uc3QgbGluZT1kb2N1bWVudC5jcmVhdGVFbGVtZW50KCdkaXYnKTtsaW5lLmNsYXNzTmFtZT1rZXk7bGluZS50ZXh0Q29udGVudD1pdGVtW2tleV18fCdcdTAwYTAnO2NhcHRpb24uYXBwZW5kKGxpbmUpOwogIH0KICBjYXJkLmFwcGVuZChjYXB0aW9uKTsKICBjYXJkLnF1ZXJ5U2VsZWN0b3IoJy5waG90bycpLmFsdD1pdGVtLm5hbWV8fCcnOwp9CmZ1bmN0aW9uIHJlZnJlc2hMYWJlbHMoKXsKICBjb25zdCBzY3JpcHQ9ZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnc2NyaXB0Jyk7CiAgc2NyaXB0LnNyYz0nX19XSU5ORVJfREFUQV9KU19fP3Q9JytEYXRlLm5vdygpOwogIHNjcmlwdC5vbmxvYWQ9KCk9PnsKICAgIGlmKHR5cGVvZiB3aW5kb3cud2lubmVyTmFtZXBsYXRlQ1NWIT09J3N0cmluZycpe3NjcmlwdC5yZW1vdmUoKTtyZXR1cm47fQogICAgbGFiZWxDU1Y9d2luZG93Lndpbm5lck5hbWVwbGF0ZUNTVjsKICAgIGNvbnN0IGxhYmVscz1sYWJlbEl0ZW1zKCk7CiAgICB1cGRhdGVIZWFkaW5nKGxhYmVscyk7CiAgICBjb25zdCBpdGVtcz1uZXcgTWFwKGxhYmVscy5tYXAoaXRlbT0+W2l0ZW0uZmlsZSxpdGVtXSkpOwogICAgcm9vdC5xdWVyeVNlbGVjdG9yQWxsKCcucG9ydHJhaXQnKS5mb3JFYWNoKGNhcmQ9PnNldENhcHRpb24oY2FyZCxpdGVtcy5nZXQoY2FyZC5kYXRhc2V0LmZpbGUpfHx7fSkpOwogICAgZml0VGV4dCgpO3NjcmlwdC5yZW1vdmUoKTsKICB9OwogIHNjcmlwdC5vbmVycm9yPSgpPT5zY3JpcHQucmVtb3ZlKCk7ZG9jdW1lbnQuaGVhZC5hcHBlbmQoc2NyaXB0KTsKfQphc3luYyBmdW5jdGlvbiBzdGFydCgpewogIGNvbnN0IGl0ZW1zPWxhYmVsSXRlbXMoKTsKICBhd2FpdCBkb2N1bWVudC5mb250cy5yZWFkeTsKICB1cGRhdGVIZWFkaW5nKGl0ZW1zKTsKICBjb25zdCBzZWxlY3RlZD1pdGVtcy5sZW5ndGg/aXRlbXM6QXJyYXkuZnJvbSh7bGVuZ3RoOlNFVFRJTkdTLm1heGltdW1QaG90b3N9LChfLGkpPT4oe2ZpbGU6YHNsaWRlLSR7U3RyaW5nKFNFVFRJTkdTLmZpcnN0TnVtYmVyK2kpLnBhZFN0YXJ0KDMsJzAnKX0ucG5nYCxuYW1lOicnLHRpdGxlOicnfSkpOwogIGNvbnN0IGxvYWRlZD0oYXdhaXQgUHJvbWlzZS5hbGwoc2VsZWN0ZWQubWFwKGxvYWRQaG90bykpKS5maWx0ZXIoQm9vbGVhbikuc2xpY2UoMCwxMSk7CiAgbG9hZGVkLmZvckVhY2goKGl0ZW0saW5kZXgpPT57CiAgICBjb25zdCBjYXJkPWRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ2ZpZ3VyZScpO2NhcmQuY2xhc3NOYW1lPSdwb3J0cmFpdCc7Y2FyZC5kYXRhc2V0LmZpbGU9aXRlbS5maWxlOwogICAgY2FyZC5hcHBlbmQoaXRlbS5pbWcpOwogICAgY29uc3QgZnJhbWU9ZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnZGl2Jyk7ZnJhbWUuY2xhc3NOYW1lPSdmcmFtZSc7ZnJhbWUuYXBwZW5kKHVuaXF1ZUZyYW1lKGluZGV4KSk7Y2FyZC5hcHBlbmQoZnJhbWUpOwogICAgc2V0Q2FwdGlvbihjYXJkLGl0ZW0pOwogICAgcGFydChpbmRleDw1Pyd0b3AnOidib3R0b20nKS5hcHBlbmQoY2FyZCk7CiAgfSk7CiAgYXdhaXQgZG9jdW1lbnQuZm9udHMucmVhZHk7CiAgZml0VGV4dCgpOwogIHNldEludGVydmFsKHJlZnJlc2hMYWJlbHMsNjAwMDApOwp9CnN0YXJ0KCkuY2F0Y2goY29uc29sZS5lcnJvcik7Cgp9KSgpOwo8L3NjcmlwdD4='))
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

