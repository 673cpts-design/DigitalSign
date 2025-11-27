# Download multiple Google Slides decks as PNGs
# Each deck can have multiple slides
# Each deck gets its own folder: C:\www\images\<PresentationName>

# ================== CONFIG: EDIT THESE ==================

$baseOutputPath = "C:\www\images"

$presentations = @(
    @{
        Name      = 'Leadership'
        Url       = 'https://docs.google.com/presentation/d/REPLACE_LEADERSHIP_ID/edit'
        MaxSlides = 4   # upper bound; script stops early when slides run out
    },
    @{
        Name      = 'Quarter1'
        Url       = 'https://docs.google.com/presentation/d/REPLACE_Q1_ID/edit'
        MaxSlides = 20
    },
    @{
        Name      = 'Quarter2'
        Url       = 'https://docs.google.com/presentation/d/REPLACE_Q2_ID/edit'
        MaxSlides = 20
    },
    @{
        Name      = 'Quarter3'
        Url       = 'https://docs.google.com/presentation/d/REPLACE_Q3_ID/edit'
        MaxSlides = 20
    },
    @{
        Name      = 'Quarter4'
        Url       = 'https://docs.google.com/presentation/d/REPLACE_Q4_ID/edit'
        MaxSlides = 20
    },
    @{
        Name      = 'Year'
        Url       = 'https://docs.google.com/presentation/d/REPLACE_YEAR_ID/edit'
        MaxSlides = 20
    }
)

# ================== DO NOT EDIT BELOW THIS LINE ===================

function Download-GSlideDeckPngs {
    param(
        [string]$Url,
        [string]$OutputFolder,
        [int]$MaxSlides = 20
    )

    # Parse URL
    try {
        $uri = [Uri]$Url
    }
    catch {
        return
    }

    # Extract FILE_ID from /presentation/d/FILE_ID/
    $match = [regex]::Match($uri.AbsolutePath, '/presentation/d/([^/]+)/')
    if (-not $match.Success) {
        return
    }

    $fileId = $match.Groups[1].Value

    # Ensure output folder exists
    if (-not (Test-Path -LiteralPath $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    }

    # Try slides p1, p2, ... up to MaxSlides; stop when one fails
    for ($i = 1; $i -le $MaxSlides; $i++) {
        $pageId   = "p$($i)"
        $exportUrl = "https://docs.google.com/presentation/d/$fileId/export/png?pageid=$pageId"
        $outFile   = Join-Path $OutputFolder ("slide{0:D2}.png" -f $i)

        try {
            Invoke-WebRequest -Uri $exportUrl -OutFile $outFile -ErrorAction Stop
        }
        catch {
            # Assume no more slides or no access → stop trying further slides
            break
        }
    }
}

foreach ($p in $presentations) {
    $folder = Join-Path $baseOutputPath $p.Name
    Download-GSlideDeckPngs -Url $p.Url -OutputFolder $folder -MaxSlides $p.MaxSlides
}
