# Download one-slide Google Slides decks (7 hardcoded links) as PNGs
# Each presentation is assumed to have ONLY ONE SLIDE (pageid=p1)

# ================== CONFIG: EDIT THESE 7 ENTRIES ==================

$presentations = @(
    @{
        Name     = 'Presentation1'
        Url      = 'https://docs.google.com/presentation/d/1VQNl4Om1hihQ8GnwHCZZh0rNbnC9KfamPA0KA4bLkdw/edit'
        OutFile  = 'C:\temp\Presentation1.png'
    },
    @{
        Name     = 'Presentation2'
        Url      = 'https://docs.google.com/presentation/d/REPLACE_ME_2/edit'
        OutFile  = 'C:\temp\Presentation2.png'
    },
    @{
        Name     = 'Presentation3'
        Url      = 'https://docs.google.com/presentation/d/REPLACE_ME_3/edit'
        OutFile  = 'C:\temp\Presentation3.png'
    },
    @{
        Name     = 'Presentation4'
        Url      = 'https://docs.google.com/presentation/d/REPLACE_ME_4/edit'
        OutFile  = 'C:\temp\Presentation4.png'
    },
    @{
        Name     = 'Presentation5'
        Url      = 'https://docs.google.com/presentation/d/REPLACE_ME_5/edit'
        OutFile  = 'C:\temp\Presentation5.png'
    },
    @{
        Name     = 'Presentation6'
        Url      = 'https://docs.google.com/presentation/d/REPLACE_ME_6/edit'
        OutFile  = 'C:\temp\Presentation6.png'
    },
    @{
        Name     = 'Presentation7'
        Url      = 'https://docs.google.com/presentation/d/REPLACE_ME_7/edit'
        OutFile  = 'C:\temp\Presentation7.png'
    }
)

# ================== DO NOT EDIT BELOW THIS LINE ===================

function Download-GSlideSingleSlidePng {
    param(
        [string]$Url,
        [string]$OutFile
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

    # Since each deck has ONE slide, we always use p1
    $exportUrl = "https://docs.google.com/presentation/d/$fileId/export/png?pageid=p1"

    try {
        Invoke-WebRequest -Uri $exportUrl -OutFile $OutFile -ErrorAction Stop
    }
    catch {
        # Silent failure; remove this block or add logging if you want
    }
}

foreach ($p in $presentations) {
    Download-GSlideSingleSlidePng -Url $p.Url -OutFile $p.OutFile
}
