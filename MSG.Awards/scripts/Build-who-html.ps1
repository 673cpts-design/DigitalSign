$imagesFolder = 'C:\www\images\who'
$outputHtml   = 'C:\www\who.html'

if (-not (Test-Path $imagesFolder)) {
    throw "Folder not found: $imagesFolder"
}

$pngFiles = Get-ChildItem -Path $imagesFolder -Filter *.png -File | Sort-Object Name

if (-not $pngFiles -or $pngFiles.Count -eq 0) {
    throw "No PNG files found in: $imagesFolder"
}

# Build slide HTML
$slides = foreach ($file in $pngFiles) {
    # Since the HTML is being saved to C:\www\who.html
    # and images are in C:\www\images\who\,
    # use a relative path from the HTML file.
    $relativeSrc = "images/who/$($file.Name)"

@"
        <div class="swiper-slide swiper-slide-a8bc">
          <img
            class="swiper-slide-bg-image swiper-slide-bg-image-bdb6"
            data-swiper-parallax="33%"
            src="$relativeSrc"
          />
          <div class="swiper-slide-content swiper-slide-content-2f5e"></div>
        </div>
"@
}

$slidesHtml = ($slides -join "`r`n")

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
  html,
  body {
    padding: 0;
    margin: 0;
    width: 100%;
    height: 100%;
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

  .swiper {
    user-select: none;
    box-sizing: border-box;
    overflow: hidden;
    width: 100%;
    height: 100%;
    padding: 0;
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
    background: #000;
  }

  .swiper-slide-bg-image {
    position: absolute;
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    max-width: none;
    z-index: 0;
  }

  .swiper-slide-a8bc {
    background-color: #000;
    border-radius: 0;
  }

  .swiper-slide-bg-image-bdb6 {
    object-fit: contain;
    border-radius: inherit;
    opacity: 1;
  }
</style>
  </head>
  <body>
    <div class="swiper swiper-white-tiglon-685">
      <div class="swiper-wrapper">
$slidesHtml
      </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/swiper@11/swiper-bundle.min.js"></script>

    <script>
      var swiper = new Swiper(".swiper", {
        effect: "creative",
        creativeEffect: {
          prev: { translate: ["-150%", "0%", -800], rotate: [0, 0, -90] },
          next: { translate: ["150%", "0%", -800], rotate: [0, 0, 90] },
        },
        speed: 3000,
        autoplay: {
          delay: 3000,
          disableOnInteraction: false
        },
        parallax: true,
        a11y: false,
        loop: true
      });
    </script>
  </body>
</html>
"@

Set-Content -Path $outputHtml -Value $html -Encoding UTF8

Write-Host "Created: $outputHtml"
Write-Host "Slides added: $($pngFiles.Count)"
