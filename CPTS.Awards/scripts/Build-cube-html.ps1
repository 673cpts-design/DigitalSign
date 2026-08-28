# Auto-generate optimized Swiper cube HTML files for Quarter1-Quarter4
#
# Outputs:
#   C:\www\1.html
#   C:\www\2.html
#   C:\www\3.html
#   C:\www\4.html
#
# PERFORMANCE GOAL:
# Preserve all visible effects:
#   - Cube transition
#   - Cube shadows
#   - Parallax background
#   - Foreground parallax
#   - Foreground scaling
#   - Foreground opacity effect
#
# Remove only unnecessary kiosk/browser overhead.

$baseOutputPath = "C:\www"
$baseImagePath  = "C:\www\images"

# Map quarter names to output HTML files
$presentations = @(
    @{
        Name       = 'Quarter1'
        OutputHtml = (Join-Path $baseOutputPath '1.html')
    },
    @{
        Name       = 'Quarter2'
        OutputHtml = (Join-Path $baseOutputPath '2.html')
    },
    @{
        Name       = 'Quarter3'
        OutputHtml = (Join-Path $baseOutputPath '3.html')
    },
    @{
        Name       = 'Quarter4'
        OutputHtml = (Join-Path $baseOutputPath '4.html')
    }
)

# Ensure output directory exists before processing
if (-not (Test-Path -LiteralPath $baseOutputPath)) {
    New-Item `
        -ItemType Directory `
        -Path $baseOutputPath `
        -Force | Out-Null
}

$templateTop = @'
<!doctype html>
<html lang="en">

<head>

<meta charset="UTF-8" />

<meta
    name="viewport"
    content="width=device-width, initial-scale=1.0"
/>

<title>Awards</title>

<link
    rel="stylesheet"
    href="https://cdn.jsdelivr.net/npm/swiper@11/swiper-bundle.min.css"
/>

<style>

html,
body {
    width: 100%;
    height: 100%;
    margin: 0;
    padding: 0;
}

html {
    overflow: hidden;
}

body {
    position: relative;

    display: flex;
    align-items: center;
    justify-content: center;

    overflow: hidden;

    background: transparent;

    font-family:
        system-ui,
        -apple-system,
        BlinkMacSystemFont,
        "Segoe UI",
        Roboto,
        "Helvetica Neue",
        Arial,
        "Noto Sans",
        sans-serif;
}


/* ============================================================
   SWIPER
   ============================================================ */

.swiper {
    width: 600px;
    height: auto;

    padding: 0;

    box-sizing: border-box;

    overflow: visible;

    user-select: none;

    /*
        Swiper continuously transforms the wrapper during the cube
        transition. This tells Chromium/Edge to keep it ready for
        compositing without overriding Swiper's own transform.
    */
    will-change: transform;
}


.swiper-wrapper {
    /*
        The wrapper is one of the main continuously transformed
        elements in Swiper.
    */
    will-change: transform;
}


/* ============================================================
   SLIDES
   ============================================================ */

.swiper-slide {
    position: relative;

    display: flex;
    align-items: center;
    justify-content: center;

    width: 100%;
    height: 100%;

    box-sizing: border-box;

    overflow: hidden;

    /*
        Cube mode continuously changes transforms on the slides.
        Do not specify our own transform here.
    */
    will-change: transform;
}


.swiper-slide-4ffe {
    background-color: rgba(51, 51, 51, 1);
}


/* ============================================================
   PARALLAX BACKGROUND
   ============================================================ */

.swiper-slide-bg-image {
    position: absolute;

    left: -39%;
    top: -39%;

    width: 178%;
    height: 178%;

    max-width: none;

    z-index: 0;

    /*
        The background is moved by Swiper's parallax engine.

        "will-change" prepares the compositor for that movement
        without replacing Swiper's transform.
    */
    will-change: transform;

    pointer-events: none;

    user-select: none;
}


.swiper-slide-bg-image-bdb6 {
    object-fit: cover;

    border-radius: inherit;

    opacity: 1;
}


/* ============================================================
   FOREGROUND CONTENT
   ============================================================ */

.swiper-slide-content {
    position: relative;

    display: flex;

    width: 100%;
    height: 100%;

    z-index: 1;

    box-sizing: border-box;
}


.swiper-slide-content-2f5e {
    padding: 48px;

    flex-direction: column;

    gap: 0;

    align-items: center;
    justify-content: center;
}


/* ============================================================
   FOREGROUND AWARD IMAGE
   ============================================================ */

.swiper-slide-image-9428 {
    max-width: 100%;
    max-height: 100%;

    min-width: 0;
    min-height: 0;

    object-fit: contain;

    opacity: 1;

    /*
        Swiper changes BOTH transform and opacity because of:

        data-swiper-parallax
        data-swiper-parallax-scale
        data-swiper-parallax-opacity

        This prepares those properties for compositor animation.
    */
    will-change: transform, opacity;

    pointer-events: none;

    user-select: none;

    /*
        Deliberately NO:
            filter: blur(0px)

        A zero-value filter has no visible effect but can create an
        unnecessary effects/compositing context.
    */
}

</style>

</head>


<body>

<div class="swiper swiper-crimson-wildcat-700">

    <div class="swiper-wrapper">
'@


$templateBottom = @'
    </div>

</div>


<script src="https://cdn.jsdelivr.net/npm/swiper@11/swiper-bundle.min.js"></script>


<script>

const swiper = new Swiper(".swiper", {

    /*
        Keep the existing automatic-height behavior so this remains
        visually compatible with the current implementation.
    */
    autoHeight: true,


    /*
        Continuous looping is required for kiosk operation.
    */
    loop: true,


    /*
        Main visual transition.
    */
    effect: "cube",


    /*
        Explicitly retain cube shadows.

        These are part of the desired visual presentation.
    */
    cubeEffect: {
        shadow: true,
        slideShadows: true
    },


    /*
        Original transition duration.
    */
    speed: 800,


    /*
        Explicit autoplay configuration.

        Swiper's normal autoplay delay is 3000ms, so specifying it
        keeps the current timing predictable.
    */
    autoplay: {
        delay: 3000,
        disableOnInteraction: false,
        pauseOnMouseEnter: false
    },


    /*
        Required for the visual parallax effects.
    */
    parallax: {
        enabled: true
    },


    /*
        Required by Swiper for accurate progress-dependent effects.
    */
    watchSlidesProgress: true,


    /*
        Kiosk geometry is static.

        Prevent continuous ResizeObserver bookkeeping. The page is
        loaded at its final kiosk dimensions and does not need to
        respond to DOM resizing.
    */
    resizeObserver: false,


    /*
        Do not repeatedly update Swiper for window resize events.

        This avoids unnecessary measurements/recalculation on a
        fixed-size kiosk display.
    */
    updateOnWindowResize: false,


    /*
        Touch interaction is unnecessary on an unattended display.
        Disabling it avoids installing/processing gesture work while
        autoplay continues normally.
    */
    allowTouchMove: false

});


/*
    Avoid browser-native image dragging if the page is ever opened
    interactively outside kiosk mode.
*/
document.addEventListener(
    "dragstart",
    function (event) {
        event.preventDefault();
    },
    { passive: false }
);

</script>


</body>

</html>
'@


foreach ($p in $presentations) {

    $quarterName = $p.Name
    $outputHtml  = $p.OutputHtml

    $imageFolder = Join-Path $baseImagePath $quarterName


    # ------------------------------------------------------------
    # Verify source directory
    # ------------------------------------------------------------

    if (-not (Test-Path -LiteralPath $imageFolder)) {

        Write-Warning "Image folder does not exist: $imageFolder"

        continue
    }


    # ------------------------------------------------------------
    # Get slide images
    # ------------------------------------------------------------

    $images = @(
        Get-ChildItem `
            -LiteralPath $imageFolder `
            -Filter *.png `
            -File |
        Sort-Object Name
    )


    if ($images.Count -eq 0) {

        Write-Warning "No PNG images found in: $imageFolder"

        continue
    }


    # ------------------------------------------------------------
    # Build slide markup
    # ------------------------------------------------------------

    $slidesMarkupList = [System.Collections.Generic.List[string]]::new()


    foreach ($img in $images) {

        # Example:
        # images/Quarter1/slide01.png

        $relativeSrc = "images/$quarterName/$($img.Name)"


        $slideMarkup = @"
        <div class="swiper-slide swiper-slide-4ffe">

            <img
                class="swiper-slide-bg-image swiper-slide-bg-image-bdb6"

                data-swiper-parallax="39%"

                src="images/american-flag-840.png"

                alt=""

                draggable="false"

                decoding="async"
            />


            <div class="swiper-slide-content swiper-slide-content-2f5e">

                <img
                    class="swiper-slide-image swiper-slide-image-9428"

                    data-swiper-parallax="-390"

                    data-swiper-parallax-scale="1.15"

                    data-swiper-parallax-opacity="0.6"

                    src="$relativeSrc"

                    alt=""

                    draggable="false"

                    decoding="async"
                />

            </div>

        </div>
"@

        $slidesMarkupList.Add($slideMarkup)
    }


    # ------------------------------------------------------------
    # Combine HTML
    # ------------------------------------------------------------

    $slidesSection = $slidesMarkupList -join "`r`n"

    $fullHtml =
        $templateTop +
        "`r`n" +
        $slidesSection +
        "`r`n" +
        $templateBottom


    # ------------------------------------------------------------
    # Write output file
    # ------------------------------------------------------------

    Set-Content `
        -LiteralPath $outputHtml `
        -Value $fullHtml `
        -Encoding UTF8


    Write-Host "Built: $outputHtml"
}

Write-Host ""
Write-Host "Cube HTML build complete."
