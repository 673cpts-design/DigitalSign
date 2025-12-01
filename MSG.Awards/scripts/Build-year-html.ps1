# ================== CONFIG ==================

$yearFolder        = "C:\www\images\Year"
$yearSidebarFolder = "C:\www\images\YearSideBar"
$outputHtmlPath    = "C:\www\y.html"

# Base file URL prefix (for Edge loading local files)
$yearUrlBase        = "file:///C:/www/images/Year"
$yearSidebarUrlBase = "file:///C:/www/images/YearSideBar"

# ================== GATHER IMAGES ==================

if (-not (Test-Path $yearFolder)) {
    Write-Error "Year folder not found: $yearFolder"
    exit 1
}
if (-not (Test-Path $yearSidebarFolder)) {
    Write-Error "YearSideBar folder not found: $yearSidebarFolder"
    exit 1
}

$yearImages        = Get-ChildItem $yearFolder -Filter "*.png" | Sort-Object Name
$yearSidebarImages = Get-ChildItem $yearSidebarFolder -Filter "*.png" | Sort-Object Name

if (-not $yearImages) {
    Write-Warning "No PNG files found in $yearFolder"
}
if (-not $yearSidebarImages) {
    Write-Warning "No PNG files found in $yearSidebarFolder"
}

# ================== BUILD MAIN SLIDER HTML (NO TEXT) ==================

$mainSlidesHtml = $yearImages | ForEach-Object {
    $imgName = $_.Name
    $imgUrl  = "$yearUrlBase/$imgName"

@"
    <div class="swiper-slide">
      <figure class="slide-bgimg" style="background-image:url('$imgUrl')" data-swiper-parallax-x="50%">
        <img src="$imgUrl" class="entity-img" />
      </figure>
    </div>
"@
} | Out-String

# ================== BUILD NAV SLIDER HTML (NO TEXT) ==================

$navSlidesHtml = $yearSidebarImages | ForEach-Object {
    $imgName = $_.Name
    $imgUrl  = "$yearSidebarUrlBase/$imgName"

@"
    <div class="swiper-slide">
      <figure class="slide-bgimg" style="background-image:url('$imgUrl')">
        <img src="$imgUrl" class="entity-img" />
      </figure>
    </div>
"@
} | Out-String

# ================== PAGE TEMPLATE ==================

$head = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Kiosk Parallax Slider with Sidebar</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <!-- Swiper CSS -->
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/Swiper/6.7.0/swiper-bundle.min.css">

  <style>
    html, body {
      margin: 0;
      padding: 0;
      height: 100%;
    }

    body {
      background: #000;
      color: #fff;
      overflow: hidden;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      cursor: none;
      user-select: none;
    }

    [class^=swiper-button-] {
      transition: all 0.3s ease;
    }

    .swiper-slide {
      backface-visibility: hidden;
      -webkit-backface-visibility: hidden;
    }

    *, *:before, *:after {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    .swiper-container {
      height: 100vh;
      transition: opacity 0.6s ease, transform 0.3s ease;
      position: relative;
    }

    .main-slider {
      width: 80%;
      float: left;
    }

    .nav-slider {
      width: 20%;
      float: left;
      padding-left: 5px;
    }

    .nav-slider .swiper-slide {
      cursor: default;
      opacity: 0.4;
      transition: opacity 0.3s ease;
    }

    .nav-slider .swiper-slide.swiper-slide-active {
      opacity: 1;
    }

    .nav-slider .swiper-slide .content {
      width: 100%;
    }

    .nav-slider .swiper-slide .content .title {
      font-size: 20px;
    }

    .swiper-button-prev,
    .swiper-button-next {
      width: 44px;
      opacity: 0 !important;
      visibility: hidden !important;
      pointer-events: none !important;
    }

    .swiper-slide {
      overflow: hidden;
    }

    .swiper-slide .slide-bgimg {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background-position: center;
      background-size: cover;
    }

    .swiper-slide .entity-img {
      display: none;
    }

    /* .content styles are kept but no .content is rendered, so no text appears */
    .swiper-slide .content {
      position: absolute;
      top: 40%;
      left: 0;
      width: 50%;
      padding-left: 5%;
      color: #fff;
      text-shadow: 0 0 8px rgba(0,0,0,0.6);
    }

    .swiper-container.loading {
      opacity: 1;
      visibility: visible;
    }

    .swiper-container,
    .swiper-wrapper,
    .swiper-slide {
      pointer-events: none;
    }
  </style>
</head>
<body>

<!-- Main slider -->
<div class="swiper-container main-slider loading">
  <div class="swiper-wrapper">
"@

$between = @"
  </div>

  <div class="swiper-button-prev swiper-button-white"></div>
  <div class="swiper-button-next swiper-button-white"></div>
</div>

<!-- Sidebar nav slider -->
<div class="swiper-container nav-slider">
  <div class="swiper-wrapper" role="navigation">
"@

$afterNav = @"
  </div>
</div>

<!-- Swiper JS -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/Swiper/6.7.0/swiper-bundle.min.js"></script>
<script>
  const mainSlider = new Swiper('.main-slider', {
    loop: true,
    speed: 1000,
    parallax: true,
    autoplay: {
      delay: 8000,
      disableOnInteraction: false
    },
    loopAdditionalSlides: 10,
    grabCursor: false,
    allowTouchMove: false,
    simulateTouch: false,
    keyboard: { enabled: false },
    mousewheel: false
  });

  const navSlider = new Swiper('.nav-slider', {
    loop: true,
    loopAdditionalSlides: 10,
    speed: 1000,
    spaceBetween: 5,
    slidesPerView: 5,
    centeredSlides: true,
    direction: 'vertical',
    allowTouchMove: false,
    simulateTouch: false,
    slideToClickedSlide: false
  });

  mainSlider.controller.control = navSlider;
  navSlider.controller.control = mainSlider;
</script>

</body>
</html>
"@

# ================== WRITE FILE ==================

$fullHtml = $head + $mainSlidesHtml + $between + $navSlidesHtml + $afterNav

Set-Content -Path $outputHtmlPath -Value $fullHtml -Encoding UTF8

Write-Host "Generated $outputHtmlPath"
