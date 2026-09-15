# ============================================================
# Build-4CornerSlideshow.ps1
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

$TopRightDurationSeconds =
    [double](Get-SheetCell $TopRightCell)

$BottomRightDurationSeconds =
    [double](Get-SheetCell $BottomRightCell)


# ------------------------------------------------------------
# DISPLAY GOOGLE SHEET VALUES
# ------------------------------------------------------------

Write-Host ""
Write-Host "Slideshow timing:"
Write-Host "-----------------"

Write-Host "Top Left:     $TopLeftDurationSeconds seconds"
Write-Host "Top Right:    $TopRightDurationSeconds seconds"
Write-Host "Bottom Left:  $BottomLeftDurationSeconds seconds"
Write-Host "Bottom Right: $BottomRightDurationSeconds seconds"

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

$TopRightImages =
    Get-PngFiles $TopRightFolder

$BottomLeftImages =
    Get-PngFiles $BottomLeftFolder

$BottomRightImages =
    Get-PngFiles $BottomRightFolder


Write-Host "Images found:"
Write-Host "-------------"

Write-Host "Top Left:     $($TopLeftImages.Count)"
Write-Host "Top Right:    $($TopRightImages.Count)"
Write-Host "Bottom Left:  $($BottomLeftImages.Count)"
Write-Host "Bottom Right: $($BottomRightImages.Count)"

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


# ------------------------------------------------------------
# BUILD QUADRANTS
# ------------------------------------------------------------

$TopLeftHtml = New-QuadrantHtml `
    -Id "top-left" `
    -Images $TopLeftImages `
    -DurationSeconds $TopLeftDurationSeconds


$TopRightHtml = New-QuadrantHtml `
    -Id "top-right" `
    -Images $TopRightImages `
    -DurationSeconds $TopRightDurationSeconds


$BottomLeftHtml = New-QuadrantHtml `
    -Id "bottom-left" `
    -Images $BottomLeftImages `
    -DurationSeconds $BottomLeftDurationSeconds


$BottomRightHtml = New-QuadrantHtml `
    -Id "bottom-right" `
    -Images $BottomRightImages `
    -DurationSeconds $BottomRightDurationSeconds


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
Write-Host "Top Right:    $TopRightDurationSeconds seconds"
Write-Host "Bottom Left:  $BottomLeftDurationSeconds seconds"
Write-Host "Bottom Right: $BottomRightDurationSeconds seconds"

Write-Host ""
