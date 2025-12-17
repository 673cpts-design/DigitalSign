# Builds a Swiper "cards" HTML page from all .png files in C:\www\images\Who
# Output: C:\www\who.html

$ImageDir = "C:\www\images\Who"
$OutFile  = "C:\www\who.html"

# Get PNGs (sorted by name)
$pngs = Get-ChildItem -Path $ImageDir -Filter *.png -File -ErrorAction SilentlyContinue |
        Sort-Object Name

if (-not $pngs -or $pngs.Count -eq 0) {
    # Still write a valid page (empty swiper)
    $slideHtml = ""
} else {
    # Build slides (use file:/// so Edge can load local files)
    $slideHtml = ($pngs | ForEach-Object {
        $full = $_.FullName
        $fileUri = "file:///" + ($full -replace '\\','/')  # file:///C:/www/images/Who/x.png

@"
        <div class="swiper-slide swiper-slide-828e">
          <img
            class="swiper-slide-bg-image swiper-slide-bg-image-bdb6"
            src="$fileUri"
          />
          <div class="swiper-slide-content swiper-slide-content-2f5e"></div>
        </div>
"@
    }) -join "`r`n"
}

$html = @"
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
      /** Demo styles **/
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
        width: 320px;
        height: 480px;
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
      }

      .swiper-slide-bg-image {
        position: absolute;
        left: 0%;
        top: 0%;
        width: 100%;
        height: 100%;
        max-width: none;
        z-index: 0;
      }

      .swiper-slide-828e {
        background-color: rgba(51, 51, 51, 1);
        border-radius: 8px;
      }
      .swiper-slide-bg-image-bdb6 {
        object-fit: cover;
        border-radius: inherit;
        opacity: 1;
      }
    </style>
  </head>
  <body>
    <div class="swiper swiper-harlequin-aeriela-870">
      <div class="swiper-wrapper">
$slideHtml
      </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/swiper@11/swiper-bundle.min.js"></script>

    <script>
      var swiper = new Swiper(".swiper", {
        centeredSlides: true,
        grabCursor: true,
        loop: true,
        effect: "cards",
        speed: 1300,
        autoplay: { enabled: true, delay: 5200 },
        a11y: { enabled: false },
        watchSlidesProgress: true,
        observer: true,
        observeParents: true,
      });
    </script>
  </body>
</html>
"@

# Ensure output folder exists
$null = New-Item -ItemType Directory -Path (Split-Path $OutFile) -Force -ErrorAction SilentlyContinue

# Write file as UTF-8
Set-Content -Path $OutFile -Value $html -Encoding UTF8

Write-Host "Wrote $OutFile with $($pngs.Count) slide(s) from $ImageDir"
