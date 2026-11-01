# Build one C:\www\index.html with all six slider regions inline.
# Preserves the supplied 3840 x 2160 index layout and original slider effects.
# Put this script and all six bundled JS/CSS files in C:\www\scripts.
# Required existing assets: images and videos/1hour.webm beneath RootPath.
# Build and playback are fully offline; no automatic downloads.
[CmdletBinding()]
param([string]$RootPath = 'C:\www')
$ErrorActionPreference = 'Stop'
$RootPath = [System.IO.Path]::GetFullPath($RootPath)
if (-not (Test-Path -LiteralPath $RootPath)) {
    New-Item -ItemType Directory -Path $RootPath -Force | Out-Null
}

# Fail before overwriting index.html if a required dependency is missing.
$scriptsPath = Join-Path $RootPath 'scripts'
foreach ($dependency in @(
    'swiper-11-bundle.min.css', 'swiper-11-bundle.min.js',
    'swiper-6-bundle.min.css', 'swiper-6-bundle.min.js',
    'swiper-gl.min.css', 'swiper-gl.min.js'
)) {
    $dependencyPath = Join-Path $scriptsPath $dependency
    if (-not (Test-Path -LiteralPath $dependencyPath -PathType Leaf)) {
        throw "Required offline file missing: $dependencyPath. Extract all bundled files into $scriptsPath."
    }
}

function Get-SlidesMarkup {
    param([string]$FolderName, [string]$SlideTemplate)
    $folder = Join-Path (Join-Path $RootPath 'images') $FolderName
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        Write-Warning "Image folder not found: $folder"
        return ''
    }
    $files = @(Get-ChildItem -LiteralPath $folder -Filter '*.png' -File | Sort-Object Name)
    if ($files.Count -eq 0) { Write-Warning "No PNG images found: $folder" }
    $slides = foreach ($file in $files) {
        $src = './images/' + [System.Uri]::EscapeDataString($FolderName) + '/' + [System.Uri]::EscapeDataString($file.Name)
        $SlideTemplate.Replace('@@SRC@@', [System.Net.WebUtility]::HtmlEncode($src))
    }
    return ($slides -join "`r`n")
}

$quarterSlide = @'
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

                    src="@@SRC@@"

                    alt=""

                    draggable="false"

                    decoding="async"
                />

            </div>

        </div>
'@

$whoSlide = @'
        <div class="swiper-slide swiper-slide-5215">
          <img
            class="swiper-slide-bg-image swiper-slide-bg-image-bdb6 swiper-gl-image"
            src="@@SRC@@"
          />

          <div class="swiper-slide-content swiper-slide-content-94be"></div>
        </div>
'@

$yearSlide = @'
    <div class="swiper-slide">
      <figure class="slide-bgimg" style="background-image:url('@@SRC@@')" data-swiper-parallax-x="80%">
        <img src="@@SRC@@" class="entity-img" />
      </figure>
    </div>
'@

$sidebarSlide = @'
    <div class="swiper-slide">
      <figure class="slide-bgimg" style="background-image:url('@@SRC@@')">
        <img src="@@SRC@@" class="entity-img" />
      </figure>
    </div>
'@

$page = @'
<!doctype html>
<html lang="en"><head><meta charset="UTF-8"><title>Awards</title>
<link rel="stylesheet" href="./scripts/swiper-6-bundle.min.css">
<link rel="stylesheet" href="./scripts/swiper-11-bundle.min.css">
<link rel="stylesheet" href="./scripts/swiper-gl.min.css">
<style>
    html,
    body {
        margin: 0;
        padding: 0;
        width: 3840px;
        height: 2160px;
        overflow: hidden;
    }

    .vid-bg {
        position: absolute;
        top: 0px;
        left: 0px;
        z-index: -1;
        border: none;
    }

    .iframe-who-is {
        position: absolute;
        top: 1235px;
        left: 50px;
        width: 980px;
        height: 800px;
        border: none;
    }

    .iframe-top-right {
        position: absolute;
        top: 0px;
        left: 1920px;
        width: 1920px;
        height: 1080px;
        border: none;
    }

    .iframe-bottom-right {
        position: absolute;
        top: 1080px;
        left: 3140px;
        width: 700px;
        height: 1080px;
        border: none;
    }

    .iframe-bottom-middle-right {
        position: absolute;
        top: 1080px;
        left: 2440px;
        width: 700px;
        height: 1080px;
        border: none;
    }

    .iframe-bottom-middle-left {
        position: absolute;
        top: 1080px;
        left: 1740px;
        width: 700px;
        height: 1080px;
        border: none;
    }

    .iframe-bottom-left {
        position: absolute;
        top: 1080px;
        left: 1040px;
        width: 700px;
        height: 1080px;
        border: none;
    }

    .img-L1 {
        position: absolute;
        top: 0px;
        left: 0px;
        width: 448px;
        height: 560px;
        z-index: 10;
        border: none;
    }

    .img-L2 {
        position: absolute;
        top: 0px;
        left: 1480px;
        width: 448px;
        height: 560px;
        z-index: 10;
        border: none;
    }

    .img-L3 {
        position: absolute;
        top: 560px;
        left: 0px;
        width: 448px;
        height: 560px;
        z-index: 10;
        border: none;
    }

    .img-L4 {
        position: absolute;
        top: 560px;
        left: 1480px;
        width: 448px;
        height: 560px;
        z-index: 10;
        border: none;
    }

    .img-Leadertxt {
        position: absolute;
        top: 0px;
        left: 510px;
        z-index: 110;
        border: none;
    }

    .img-presents {
        position: absolute;
        top: 720px;
        left: 900px;
        z-index: 111;
        border: none;
    }

    .img-whois {
        position: absolute;
        top: 1030px;
        left: 0px;
        z-index: 112;
        border: none;
    }

	.img-weare {
        position: absolute;
        top: 1920px;    
        left: 0px;   
        border: none;
		z-index: 113;
        }	

    .img-Q1 {
        position: absolute;
        top: 1070px;
        left: 1150px;
        width: 490px;
        height: 210px;
        z-index: 10;
        border: none;
    }

    .img-Q2 {
        position: absolute;
        top: 1070px;
        left: 1850px;
        width: 490px;
        height: 210px;
        z-index: 10;
        border: none;
    }

    .img-Q3 {
        position: absolute;
        top: 1070px;
        left: 2550px;
        width: 490px;
        height: 210px;
        z-index: 10;
        border: none;
    }

    .img-Q4 {
        position: absolute;
        top: 1070px;
        left: 3250px;
        width: 490px;
        height: 210px;
        z-index: 10;
        border: none;
    }

    .img-Logo {
        position: absolute;
        top: 110px;
        left: 400px;
        width: 900px;
        height: 888px;
        z-index: 10;
        border: none;
    }
	.img-chant {
        position: absolute;
        top: 1990px;    
        left: 1150px;   
        border: none;
		z-index: 114;
        }

.quarter-panel {
    
    
    
    
}.quarter-panel {
    overflow: hidden;
}.quarter-panel {
    

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
}.quarter-panel .swiper {
    width: 600px;
    height: auto;

    padding: 0;

    box-sizing: border-box;

    overflow: visible;

    user-select: none;

    
    will-change: transform;
}.quarter-panel .swiper-wrapper {
    
    will-change: transform;
}.quarter-panel .swiper-slide {
    position: relative;

    display: flex;
    align-items: center;
    justify-content: center;

    width: 100%;
    height: 100%;

    box-sizing: border-box;

    overflow: hidden;

    
    will-change: transform;
}.quarter-panel .swiper-slide-4ffe {
    background-color: rgba(51, 51, 51, 1);
}.quarter-panel .swiper-slide-bg-image {
    position: absolute;

    left: -39%;
    top: -39%;

    width: 178%;
    height: 178%;

    max-width: none;

    z-index: 0;

    
    will-change: transform;

    pointer-events: none;

    user-select: none;
}.quarter-panel .swiper-slide-bg-image-bdb6 {
    object-fit: cover;

    border-radius: inherit;

    opacity: 1;
}.quarter-panel .swiper-slide-content {
    position: relative;

    display: flex;

    width: 100%;
    height: 100%;

    z-index: 1;

    box-sizing: border-box;
}.quarter-panel .swiper-slide-content-2f5e {
    padding: 48px;

    flex-direction: column;

    gap: 0;

    align-items: center;
    justify-content: center;
}.quarter-panel .swiper-slide-image-9428 {
    max-width: 100%;
    max-height: 100%;

    min-width: 0;
    min-height: 0;

    object-fit: contain;

    opacity: 1;

    
    will-change: transform, opacity;

    pointer-events: none;

    user-select: none;

    
}


#who-panel {
        
        
        
        
        display: flex;
        justify-content: center;
        align-items: center;
        
      }#who-panel {
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
      }#who-panel .swiper {
        user-select: none;
        box-sizing: border-box;
        overflow: hidden;
        width: 100%;
        height: 100%;
        padding: 0px 0px;
      }#who-panel .swiper-slide {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 100%;
        height: 100%;
        position: relative;
        box-sizing: border-box;
      }#who-panel .swiper-slide-bg-image {
        position: absolute;
        left: 0%;
        top: 0%;
        width: 100%;
        height: 100%;
        max-width: none;
        z-index: 0;
      }#who-panel .swiper-slide-content {
        width: 100%;
        height: 100%;
        display: flex;
        position: relative;
        z-index: 1;
        box-sizing: border-box;
      }#who-panel .swiper-slide-bg-image-bdb6 {
        object-fit: cover;
        border-radius: inherit;
        opacity: 1;
      }#who-panel .swiper-slide-content-94be {
        padding: 32px 16px;
        flex-direction: column;
        gap: 0px;
        align-items: flex-start;
        justify-content: flex-end;
      }#who-panel .swiper-slide-text-66a3 {
        color: rgba(255, 255, 255, 1);
        text-align: left;
        font-size: 48px;
        line-height: 1.5;
        font-weight: bold;
      }
    
#year-panel {
      
      
      
    }#year-panel {
      background: #000;
      color: #fff;
      overflow: hidden;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      cursor: none;
      user-select: none;
    }#year-panel [class^=swiper-button-] {
      transition: all 0.3s ease;
    }#year-panel .swiper-slide {
      backface-visibility: hidden;
      -webkit-backface-visibility: hidden;
    }#year-panel *,
#year-panel *:before,
#year-panel *:after {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }#year-panel .swiper-container {
      height: 100%;
      transition: opacity 0.6s ease, transform 0.3s ease;
      position: relative;
    }#year-panel .main-slider {
      width: 80%;
      float: left;
    }#year-panel .nav-slider {
      width: 20%;
      float: left;
      padding-left: 5px;
    }#year-panel .nav-slider .swiper-slide {
      cursor: default;
      opacity: 0.4;
      transition: opacity 0.3s ease;
    }#year-panel .nav-slider .swiper-slide.swiper-slide-active {
      opacity: 1;
    }#year-panel .nav-slider .swiper-slide .content {
      width: 100%;
    }#year-panel .nav-slider .swiper-slide .content .title {
      font-size: 20px;
    }#year-panel .swiper-button-prev,
#year-panel .swiper-button-next {
      width: 44px;
      opacity: 0 !important;
      visibility: hidden !important;
      pointer-events: none !important;
    }#year-panel .swiper-slide {
      overflow: hidden;
    }#year-panel .swiper-slide .slide-bgimg {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background-position: center;
      background-size: cover;
    }#year-panel .swiper-slide .entity-img {
      display: none;
    }#year-panel .swiper-slide .content {
      position: absolute;
      top: 40%;
      left: 0;
      width: 50%;
      padding-left: 5%;
      color: #fff;
      text-shadow: 0 0 8px rgba(0,0,0,0.6);
    }#year-panel .swiper-container.loading {
      opacity: 1;
      visibility: visible;
    }#year-panel .swiper-container,
#year-panel .swiper-wrapper,
#year-panel .swiper-slide {
      pointer-events: none;
    }
  
.slider-panel { overflow:hidden; }
.quarter-panel { position:absolute; }
#who-panel { position:absolute; }
#year-panel { position:absolute; }
</style></head><body> 
	
	<video class=vid-bg src="videos/1hour.webm" type="video/webm" autoplay loop muted playsinline></video>
	
	<section id="who-panel" class="slider-panel iframe-who-is">
    <div class="swiper swiper-salmon-brigit-356">
      <div class="swiper-wrapper">
@@WHO@@
      </div>
    </div>

    </section>
	<section id="year-panel" class="slider-panel iframe-top-right">

<!-- Main slider -->
<div class="swiper-container main-slider loading">
  <div class="swiper-wrapper">
@@YEAR@@
  </div>

  <div class="swiper-button-prev swiper-button-white"></div>
  <div class="swiper-button-next swiper-button-white"></div>
</div>

<!-- Sidebar nav slider -->
<div class="swiper-container nav-slider">
  <div class="swiper-wrapper" role="navigation">
@@SIDEBAR@@
  </div>
</div>

</section>
    <section id="quarter-4" class="slider-panel quarter-panel iframe-bottom-right">

<div class="swiper swiper-crimson-wildcat-700">

    <div class="swiper-wrapper">
@@Q4@@
    </div>

</div>


</section>
	<section id="quarter-3" class="slider-panel quarter-panel iframe-bottom-middle-right">

<div class="swiper swiper-crimson-wildcat-700">

    <div class="swiper-wrapper">
@@Q3@@
    </div>

</div>


</section>
	<section id="quarter-2" class="slider-panel quarter-panel iframe-bottom-middle-left">

<div class="swiper swiper-crimson-wildcat-700">

    <div class="swiper-wrapper">
@@Q2@@
    </div>

</div>


</section>
	<section id="quarter-1" class="slider-panel quarter-panel iframe-bottom-left">

<div class="swiper swiper-crimson-wildcat-700">

    <div class="swiper-wrapper">
@@Q1@@
    </div>

</div>


</section>
	
	<img class="img-L1" src="images/Leadership/slide-000.png"/>   
	<img class="img-L2" src="images/Leadership/slide-001.png"/>  
	<img class="img-L3" src="images/Leadership/slide-002.png"/>  
	<img class="img-L4" src="images/Leadership/slide-003.png"/>
	<img class="img-Leadertxt" src="images/Leadership.png"/>
	<img class="img-presents" src="images/Presents.png"/>
	<img class="img-whois" src="images/WhoIs.png"/>
	<img class="img-weare" src="images/WeAre.png"/>
	<img class="img-Q1" src="images/Q1.png"/>
	<img class="img-Q2" src="images/Q2.png"/>
	<img class="img-Q3" src="images/Q3.png"/>
	<img class="img-Q4" src="images/Q4.png"/>
	<img class="img-Logo" src="images/Logo.png"/>
	<img class="img-chant" src="images/chant.png"/>
	

<script src="./scripts/swiper-11-bundle.min.js"></script>
<script src="./scripts/swiper-gl.min.js"></script>
<script>const Swiper11 = window.Swiper;</script>
<script src="./scripts/swiper-6-bundle.min.js"></script>
<script>
const Swiper6 = window.Swiper;
window.Swiper = Swiper11;
for (const panel of document.querySelectorAll('.quarter-panel')) {
if (panel.querySelector('.swiper-slide')) {
new Swiper11(panel.querySelector(".swiper"), {

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



}
}
if (document.querySelector('#who-panel .swiper-slide')) {
const whoSwiper = new Swiper11("#who-panel .swiper", {
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
    
}
if (document.querySelector('#year-panel .main-slider .swiper-slide') &&
    document.querySelector('#year-panel .nav-slider .swiper-slide')) {
const mainSlider = new Swiper6('#year-panel .main-slider', {
    loop: true,
    speed: 1000,
    parallax: true,
    autoplay: {
      delay: 14000,
      disableOnInteraction: false
    },
    loopAdditionalSlides: 10,
    grabCursor: false,
    allowTouchMove: false,
    simulateTouch: false,
    keyboard: { enabled: false },
    mousewheel: false
  });

  const navSlider = new Swiper6('#year-panel .nav-slider', {
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

}
document.addEventListener('dragstart', event => event.preventDefault());
</script></body></html>

'@

for ($quarter = 1; $quarter -le 4; $quarter++) {
    $markup = Get-SlidesMarkup -FolderName "Quarter$quarter" -SlideTemplate $quarterSlide
    $page = $page.Replace("@@Q$quarter@@", $markup)
}
$page = $page.Replace('@@WHO@@', (Get-SlidesMarkup -FolderName 'Who' -SlideTemplate $whoSlide))
$page = $page.Replace('@@YEAR@@', (Get-SlidesMarkup -FolderName 'Year' -SlideTemplate $yearSlide))
$page = $page.Replace('@@SIDEBAR@@', (Get-SlidesMarkup -FolderName 'YearSideBar' -SlideTemplate $sidebarSlide))
$outputPath = Join-Path $RootPath 'index.html'
Set-Content -LiteralPath $outputPath -Value $page -Encoding UTF8
Write-Host "Built: $outputPath"
