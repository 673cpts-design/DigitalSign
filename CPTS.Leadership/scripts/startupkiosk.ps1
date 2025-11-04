# Install the qrcodegenerator module if not already installed
if (-not (Get-Module -Name qrcodegenerator -ListAvailable)) {
    Install-Module -Name qrcodegenerator -Scope CurrentUser -Force
}

# Import the qrcodegenerator module
Import-Module -Name qrcodegenerator

# Define the URL of the RSS feed
$feedUrl = 'https://www.airforcetimes.com/arc/outboundfeeds/rss/?outputType=xml'

# Define the output CSV file path
$outputCsvPath = 'C:\www\RSS.csv'

# Define the output HTML slideshow file path
$outputHtmlPath = 'C:\www\RSS.html'

# Create an empty array to store the feed items
$feedItems = @()

# Create an empty array to store the QR code elements
$qrCodeElements = @()

# Load the XML content from the RSS feed
$xml = [xml](Invoke-WebRequest -Uri $feedUrl).Content

# Iterate over the XML elements and extract the desired information
foreach ($item in $xml.SelectNodes('//item')) {
    $title = $item.SelectSingleNode('title').InnerText
    $link = $item.SelectSingleNode('link').InnerText
    $pubDate = Get-Date ($item.SelectSingleNode('pubDate').InnerText) -Format "ddd, dd MMM yyyy"

    # Create the HTML element for the QR code
$qrCodeElement = @"
<div class="slide">
    <h1 class="slide-heading">$title <br> Published: $pubDate</h1>
    <img src="$qrCodeImagePath" alt="QR Code for $title">
</div>
"@

   
   
    # Create a custom object for the feed item
    $feedItem = [PSCustomObject]@{
        Title = $title
        Link = $link
        PubDate = $pubDate
    }

    # Add the feed item to the array
    $feedItems += $feedItem

    # Generate QR code for the link
    $qrCodeImagePath = "C:\www\QRCode$($feedItems.Count).png"
    $qrCode = New-PSOneQRCodeURI -URI $link -LightColorRgba @(0, 0, 0, 0) -DarkColorRgba @(255, 255, 255) -width 10 -OutPath $qrCodeImagePath
       

    # Create the HTML element for the QR code
$qrCodeElement = @"
<div class="slide">
    <h2 class="slide-heading">$title<br>Published $pubDate</h2>
    <img class="slide-image" src="$qrCodeImagePath" alt="QR Code for $title">
</div>
"@

    # Add the QR code element to the array
    $qrCodeElements += $qrCodeElement
}

# Export the feed items to a CSV file
$feedItems | Export-Csv -Path $outputCsvPath -NoTypeInformation

# Create the HTML slideshow content
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>QR Code Slideshow</title>
     <script>
        // Function to reload the page
        function refreshPage() {
            location.reload();
        }

        // Set the interval to refresh the page
        setInterval(refreshPage, 30 * 60 * 1000); // 30 minutes * 60 seconds * 1000 milliseconds
    </script>
<style>
    .slideshow-container {
        position: absolute;
        max-width: 2000px;

    }

    .slide-image {
width: 200px;
height: 200px;
left: 200px;
margin-top: 1px;
margin-bottom: 1px;
 
    }
   
   
    .slide {
        display: none;
        position: absolute;
        top: 0;
        left: 0;
        height: auto;
font-weight: bold;
font-size: 50px;
margin-top: 1px;
margin-bottom: 1px;
width: 1500px;
    }

    .slide-heading {
        position: relative; /* Changed to relative positioning */
        top: 0px;
        left: 0px;
        color: white;
        font-size: 50px;
font-weight: bold;
        white-space: normal;
margin-bottom: 1px;
width: 1500px;
    }

}
</style>
</head>
<body>
    <div class="slideshow-container">
        $qrCodeElements
    </div>

    <script>
        var slides = document.getElementsByClassName("slide");
        var currentSlide = 0;

        function showSlide() {
            // Hide all slides
            for (var i = 0; i < slides.length; i++) {
                slides[i].style.display = "none";
            }

            // Display the current slide
            slides[currentSlide].style.display = "block";

            // Increment the slide index
            currentSlide++;

            // Reset to the first slide if reached the end
            if (currentSlide >= slides.length) {
                currentSlide = 0;
            }

            // Change slide every 10 seconds
            setTimeout(showSlide, 10000);
        }

        // Start the slideshow
        showSlide();
    </script>
</body>
</html>
"@


# Save the HTML slideshow file
$htmlContent | Out-File -FilePath $outputHtmlPath

Write-Host "CSV file and HTML slideshow have been generated successfully."
Write-Host "CSV file path: $outputCsvPath"
Write-Host "HTML slideshow path: $outputHtmlPath"

Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  -ArgumentList "--kiosk c:\www\index.html --edge-kiosk-type=fullscreen --disable-pinch --touch-events=disabled --overscroll-history-navigation=0 --disable-touch-drag-drop --disable-gesture-requirement-for-media-playback --disable-features=TouchpadOverscrollHistoryNavigation,TouchDragAndDrop"
