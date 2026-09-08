# ============================================================
# Build-4CornerSlideshow.ps1
#
# Builds a 3840x2160 HTML page from PNG files in 4 folders.
#
# 0 PNG files = blank quadrant
# 1 PNG file  = static image
# 2+ PNGs     = fading slideshow + progress bar
# ============================================================


# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

$TopLeftFolder     = "C:\www\images\TopLeft"
$TopRightFolder    = "C:\www\images\TopRight"
$BottomLeftFolder  = "C:\www\images\BottomLeft"
$BottomRightFolder = "C:\www\images\BottomRight"

$OutputFile = "C:\www\index.html"

# How long each slide stays visible
$SlideDurationSeconds = 10

# Fade transition duration
$FadeDurationSeconds = 1


# ------------------------------------------------------------
# FUNCTION: Convert Windows path to file:/// URL
# ------------------------------------------------------------

function Convert-ToFileUrl {
    param (
        [string]$Path
    )

    $FullPath = [System.IO.Path]::GetFullPath($Path)
    $FullPath = $FullPath -replace '\\', '/'

    # Encode spaces, #, etc.
    $Uri = New-Object System.Uri($FullPath)

    return $Uri.AbsoluteUri
}


# ------------------------------------------------------------
# FUNCTION: Read PNG files from folder
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

$TopLeftImages = Get-PngFiles $TopLeftFolder
$TopRightImages = Get-PngFiles $TopRightFolder
$BottomLeftImages = Get-PngFiles $BottomLeftFolder
$BottomRightImages = Get-PngFiles $BottomRightFolder


Write-Host ""
Write-Host "Images found:"
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
        [array]$Images
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

        $ImageUrl = Convert-ToFileUrl $Images[0].FullName

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

        $ImageUrl = Convert-ToFileUrl $Images[$i].FullName

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


    return @"
<div id="$Id" class="quadrant slideshow">

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
    -Images $TopLeftImages

$TopRightHtml = New-QuadrantHtml `
    -Id "top-right" `
    -Images $TopRightImages

$BottomLeftHtml = New-QuadrantHtml `
    -Id "bottom-left" `
    -Images $BottomLeftImages

$BottomRightHtml = New-QuadrantHtml `
    -Id "bottom-right" `
    -Images $BottomRightImages


# Convert seconds to milliseconds for JavaScript

$SlideDurationMs = $SlideDurationSeconds * 1000
$FadeDurationMs = $FadeDurationSeconds * 1000


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

    transition: opacity ${FadeDurationSeconds}s linear;

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

const slideDuration = $SlideDurationMs;


/* ==========================================================
   START ONE SLIDESHOW
   ========================================================== */

function startSlideshow(container) {

    const slides =
        container.querySelectorAll(".slide");

    const progress =
        container.querySelector(".progress-bar");


    if (slides.length <= 1) {

        return;

    }


    let currentSlide = 0;


    /* ------------------------------------------------------
       Start progress animation
       ------------------------------------------------------ */

    function startProgress() {

        /*
          Remove transition temporarily so the bar can snap
          back to zero.
        */

        progress.style.transition = "none";

        progress.style.width = "0%";


        /*
          Force the browser to apply width: 0 before starting
          the next transition.
        */

        void progress.offsetWidth;


        /*
          Fill the bar over the entire slide duration.
        */

        progress.style.transition =
            "width " +
            slideDuration +
            "ms linear";

        progress.style.width = "100%";

    }


    /* ------------------------------------------------------
       Change slide
       ------------------------------------------------------ */

    function nextSlide() {

        slides[currentSlide]
            .classList.remove("active");


        currentSlide++;

        if (currentSlide >= slides.length) {

            currentSlide = 0;

        }


        slides[currentSlide]
            .classList.add("active");


        startProgress();

    }


    /*
       Start first progress bar immediately.
    */

    startProgress();


    /*
       Advance slideshow.
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
# WRITE FILE
# ------------------------------------------------------------

$OutputDirectory = Split-Path $OutputFile

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


Write-Host "HTML created:"
Write-Host $OutputFile
Write-Host ""
