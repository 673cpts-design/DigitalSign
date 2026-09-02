$imagesFolder = 'C:\www\images\Who'
$outputHtml   = 'C:\www\who.html'

if (-not (Test-Path $imagesFolder)) {
    throw "Folder not found: $imagesFolder"
}

$pngFiles = Get-ChildItem -Path $imagesFolder -Filter *.png -File | Sort-Object Name

if (-not $pngFiles -or $pngFiles.Count -eq 0) {
    throw "No PNG files found in: $imagesFolder"
}

# Build one Swiper slide for every PNG found in C:\www\images\Who
$slides = foreach ($file in $pngFiles) {
    $relativeSrc = "./images/Who/$($file.Name)"

@"
        <div class="swiper-slide swiper-slide-5215">
          <img
            class="swiper-slide-bg-image swiper-slide-bg-image-bdb6 swiper-gl-image"
            src="$relativeSrc"
          />

          <div class="swiper-slide-content swiper-slide-content-94be"></div>
        </div>
"@
}

$slidesHtml = ($slides -join "`r`n`r`n")

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

    <link rel="stylesheet" href="./swiper-gl.min.css" />

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
        background: #000;
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
        overflow: hidden;
        width: 100%;
        height: 100%;
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

      .swiper-slide-content {
        width: 100%;
        height: 100%;
        display: flex;
        position: relative;
        z-index: 1;
        box-sizing: border-box;
      }

      .swiper-slide-bg-image-bdb6 {
        object-fit: cover;
        border-radius: inherit;
        opacity: 1;
      }

      .swiper-slide-content-94be {
        padding: 32px 16px;
        flex-direction: column;
        gap: 0px;
        align-items: flex-start;
        justify-content: flex-end;
      }

      .swiper-slide-text-66a3 {
        color: rgba(255, 255, 255, 1);
        text-align: left;
        font-size: 48px;
        line-height: 1.5;
        font-weight: bold;
      }
    </style>
  </head>

  <body>
    <div class="swiper swiper-salmon-brigit-356">
      <div class="swiper-wrapper">
$slidesHtml
      </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/swiper@11/swiper-bundle.min.js"></script>
    <script src="./swiper-gl.min.js"></script>

    <script>
      var swiper = new Swiper(".swiper", {
        modules: [SwiperGL],
        effect: "gl",
        creativeEffect: {
          limitProgress: 5,
          prev: { shadow: true },
          next: { shadow: true },
        },
        speed: 1200,
        autoplay: { enabled: true },
        watchSlidesProgress: true,
      });
    </script>
  </body>
</html>
"@

Set-Content -Path $outputHtml -Value $html -Encoding UTF8

Write-Host "Created: $outputHtml"
Write-Host "Slides added: $($pngFiles.Count)"
