# Auto-generate Swiper HTML files for Quarter1–Quarter4
# Outputs: C:\www\1.html, 2.html, 3.html, 4.html

$baseOutputPath = "C:\www"
$baseImagePath  = "C:\www\images"

# Map quarter names to output HTML files
$presentations = @(
    @{ Name = 'Quarter1'; OutputHtml = (Join-Path $baseOutputPath '1.html') },
    @{ Name = 'Quarter2'; OutputHtml = (Join-Path $baseOutputPath '2.html') },
    @{ Name = 'Quarter3'; OutputHtml = (Join-Path $baseOutputPath '3.html') },
    @{ Name = 'Quarter4'; OutputHtml = (Join-Path $baseOutputPath '4.html') }
)

# HTML template pieces (based on your existing 1.html)
$templateTop = @'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />

    <title>Swiper Studio</title>

    <link
      rel="stylesheet"
      href="https://cdn.jsdelivr.net/npm/swiper@11/swiper-bundle.min.css"
    />

    <style>
	  html,
      body {
        padding: 0;
        margin: 0;
        position: relative;
        height: 100vh;
        display: flex;
        justify-content: center;
        align-items: center;
        width: 100%;
      }
      body {
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
        overflow: hidden;
      }

      /** Swiper styles **/

      .swiper {
        user-select: none;
        box-sizing: border-box;
        overflow: visible;
        width: 600px;

        height: auto;

        padding: 0px 0px;
      }

      .swiper-slide {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 100%;
        height: 100%;
        position: relative;
        box-sizing: border-box;

        overflow: hidden;
      }

      .swiper-slide-bg-image {
        position: absolute;
        left: -39%;
        top: -39%;
        width: 178%;
        height: 178%;
        max-width: none;
        z-index: 0;
      }

      .swiper-slide-content {
        width: 100%;
        height: 100%;
        display: flex;
        position: relative;
        z-index: 1;
        box-sizing: border-box;
        transform: translate3d(0, 0, 0);
      }

      .swiper-slide-4ffe {
        background-color: rgba(51, 51, 51, 1);
      }
      .swiper-slide-bg-image-bdb6 {
        object-fit: cover;
        border-radius: inherit;
        opacity: 1;
      }
      .swiper-slide-content-2f5e {
        padding: 48px 48px;
        flex-direction: column;
        gap: 0px;
        align-items: center;
        justify-content: center;
      }
      .swiper-slide-image-9428 {
        max-width: 100%;
        min-width: 0;
        max-height: 100%;
        min-height: 0;
        object-fit: contain;
        opacity: 1;
        filter: blur(0px);
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
      var swiper = new Swiper(".swiper", {
        autoHeight: true,
        grabCursor: true,
        loop: true,
        effect: "cube",
        creativeEffect: {
          limitProgress: 5,
          prev: { shadow: true },
          next: { shadow: true },
        },
        speed: 800,
        autoplay: { enabled: true },
        keyboard: { enabled: true },
        parallax: { enabled: true },
        watchSlidesProgress: true,
        observer: true,
        observeParents: true,
      });
    </script>
  </body>
</html>
'@

foreach ($p in $presentations) {

    $quarterName   = $p.Name
    $outputHtml    = $p.OutputHtml

    $imageFolder   = Join-Path $baseImagePath $quarterName

    if (-not (Test-Path -LiteralPath $imageFolder)) {
        # If folder doesn't exist, skip this one
        continue
    }

    # Get all PNG slides for this quarter, ordered by name
    $images = Get-ChildItem -LiteralPath $imageFolder -Filter *.png -File | Sort-Object Name

    if (-not $images) {
        # No slides → skip making HTML
        continue
    }

    $slidesMarkupList = @()

    foreach ($img in $images) {
        # Build relative src like: images/Quarter1/slide01.png
        $relativeSrc = "images/$quarterName/$($img.Name)"

        $slideMarkup = @"
        <div class="swiper-slide swiper-slide-4ffe">
          <img
            class="swiper-slide-bg-image swiper-slide-bg-image-bdb6"
            data-swiper-parallax="39%"
            src="images/american-flag-840.png"
          />

          <div class="swiper-slide-content swiper-slide-content-2f5e">
            <img
              class="swiper-slide-image swiper-slide-image-9428"
              data-swiper-parallax="-390"
              data-swiper-parallax-scale="1.15"
              data-swiper-parallax-opacity="0.6"
              src="$relativeSrc"
            />
          </div>
        </div>
"@

        $slidesMarkupList += $slideMarkup
    }

    $slidesSection = $slidesMarkupList -join "`r`n"

    $fullHtml = $templateTop + "`r`n" + $slidesSection + $templateBottom

    # Ensure base output directory exists
    if (-not (Test-Path -LiteralPath $baseOutputPath)) {
        New-Item -ItemType Directory -Path $baseOutputPath -Force | Out-Null
    }

    Set-Content -Path $outputHtml -Value $fullHtml -Encoding UTF8
}
