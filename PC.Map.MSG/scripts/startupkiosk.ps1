# Generate 6 HTML files for google sheets data.
# ====== Google Sheet URLs ======
$pages = @{
    lowleft   = "https://docs.google.com/spreadsheets/d/e/2PACX-1vTeGA9mhaIGzKltMaNol_ZpGSTWb3zn9aflqht7rgQ8GULU9pGVxMN7vfand7fUoHscMkdm3WzM372h/pub?output=csv"
    lowmiddle = "https://docs.google.com/spreadsheets/d/e/2PACX-1vTo3GfdBaLSQbsIiBO1puMBdbB9PgXPNmNed-6v1Faj4WjXVIw_ywW0HndsuOE7JN8GRKzP7pPQyAiW/pub?output=csv"
    lowright  = "https://docs.google.com/spreadsheets/d/e/2PACX-1vTu7xnxAh8ihmwQcIiBDyMzTMKcQDgBhP5KRsZrkaySsJ-Jp0m4r1xP5VCeszesz_yaZY2fTOoNY367/pub?output=csv"
    topleft   = "https://docs.google.com/spreadsheets/d/e/2PACX-1vSQ0q0UCaSZEsh1EO2jkzlJv1aRBaBILYwwo00nt8cm1bTkbgr_rwZWk0f6plQlEEkgCTsfDZLyLA5W/pub?output=csv"
    topmiddle = "https://docs.google.com/spreadsheets/d/e/2PACX-1vRPZ7oPrZdyPccQi2KqtRHpb3Qr_-_m1hJvFLU-6ROIHbw_hc1F_dMp7OSsfXWH-yT81LwCPgzONF-s/pub?output=csv"
    topright  = "https://docs.google.com/spreadsheets/d/e/2PACX-1vSoEB9y3EqxH4Ikjpi7ccjyraTEhcAil_7m4rT0WTpNxp5hwxh0RcyLhVXCdUkBG1FRntzApHM_VO_S/pub?output=csv"
}

foreach ($entry in $pages.GetEnumerator()) {
    $name = $entry.Key
    $url = $entry.Value
    $htmlPath = "C:\www\$name.html"

    # Download and parse CSV
    $csvText  = Invoke-WebRequest -Uri $url -UseBasicParsing | Select-Object -ExpandProperty Content
    $allLines = $csvText -split "`r?`n" | Where-Object { $_.Trim() -ne "" }
    $lines    = $allLines | Select-Object -Skip 1  # Skip header

    $rows = @()

    foreach ($line in $lines) {
        $fields = [regex]::Matches($line, '(?<=^|,)(?:"((?:[^"]|"")*)"|([^",]*))') | ForEach-Object {
            if ($_.Groups[1].Success) { $_.Groups[1].Value.Replace('""','"') } else { $_.Groups[2].Value }
        }

        if ($fields.Count -lt 4 -or $fields[0].Trim() -eq "") { continue }

        $textColor = $fields[-1]
        $bgColor   = $fields[-2]
        $alpha     = $fields[-3]
        $dataOnly  = $fields[0..($fields.Count - 4)]

        # Dynamic number of columns
        $dataFields = @()
        foreach ($field in $dataOnly) {
            if ($null -eq $field -or $field -eq "") { break }
            $escapedField = '"' + ($field -replace '"','\"') + '"'
            $dataFields += $escapedField
        }
        if ($dataFields.Count -eq 0) { continue }

        # Hex → RGBA conversion
        if ($bgColor -match '^#([0-9a-fA-F]{6})$') {
            $r = [convert]::ToInt32($bgColor.Substring(1,2), 16)
            $g = [convert]::ToInt32($bgColor.Substring(3,2), 16)
            $b = [convert]::ToInt32($bgColor.Substring(5,2), 16)
            $bgColorRgba = "rgba($r, $g, $b, $alpha)"
        } else {
            $bgColorRgba = $bgColor
        }

        $jsonRow = "{ `"data`": [" + ($dataFields -join ", ") + "], `"color`": `"$textColor`", `"background`": `"$bgColorRgba`" }"
        $rows += $jsonRow
    }

    # --- HTML Templates ---
    $htmlMarqueeTemplate = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>CSV Vertical Marquee</title>
  <style>
    body {
      background: transparent;
      color: black;
      font-family: Arial, sans-serif;
      margin: 0;
      padding: 0;
      overflow: hidden;
      position: relative;
      height: 100vh;
    }
    #marquee-container {
      position: absolute;
      top: 0px;
      left: 0px;
      width: 690;
      height: calc(1.2em * 8);
      overflow: hidden;
      background: transparent;
    }
    #marquee {
      font-size: 1.7em;
      font-weight: bold;
      line-height: 0.9em;
      display: block;
      white-space: nowrap;
    }
    @keyframes scrollUp {
      0% { transform: translateY(0); }
      100% { transform: translateY(-50%); }
    }
  </style>
</head>
<body>
  <div id="marquee-container">
    <div id="marquee">Loading...</div>
  </div>
<script>
const rows = [
ROWS_PLACEHOLDER
];
function startMarquee() {
  const marquee = document.getElementById('marquee');
  if (rows.length === 0) { marquee.innerText = "No data."; return; }
  const htmlLines = rows.map(row => {
    const content = row.data.join('   ');
    const color = row.color?.trim() || "black";
    const bg = row.background?.trim() || "transparent";
    return `<div style="color: ${color}; background-color: ${bg}">${content}</div>`;
  });
  const fullContent = htmlLines.concat(htmlLines).join("<br>");
  marquee.innerHTML = fullContent;
  requestAnimationFrame(() => {
    const scrollHeight = marquee.scrollHeight;
    marquee.style.animationDuration = `${scrollHeight / 20}s`;
    marquee.style.animationName = "scrollUp";
    marquee.style.animationTimingFunction = "linear";
    marquee.style.animationIterationCount = "infinite";
  });
}
window.onload = startMarquee;
</script>
</body>
</html>
'@

    $htmlListTemplate = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>CSV Vertical List</title>
  <style>
    body {
      background: transparent;
      color: black;
      font-family: Arial, sans-serif;
      margin: 0;
      padding: 0;
      overflow: hidden;
      position: relative;
      height: 100vh;
    }
    #marquee-container {
      position: absolute;
      top: 0px;
      left: 0px;
      width: 690;
      height: calc(1.2em * 8);
      overflow: hidden;
      background: transparent;
    }
    #marquee {
      font-size: 1.7em;
      font-weight: bold;
      line-height: 0.9em;
      display: block;
      white-space: nowrap;
    }
  </style>
</head>
<body>
  <div id="marquee-container">
    <div id="marquee">Loading...</div>
  </div>
<script>
const rows = [
ROWS_PLACEHOLDER
];
function renderList() {
  const marquee = document.getElementById('marquee');
  if (rows.length === 0) { marquee.innerText = "No data."; return; }
  const htmlLines = rows.map(row => {
    const content = row.data.join('   ');
    const color = row.color?.trim() || "black";
    const bg = row.background?.trim() || "transparent";
    return `<div style="color: ${color}; background-color: ${bg}">${content}</div>`;
  });
  marquee.innerHTML = htmlLines.join("<br>");
}
window.onload = renderList;
</script>
</body>
</html>
'@

    # Choose template based on row count
    if ($rows.Count -ge 5) {
        $htmlContent = $htmlMarqueeTemplate
    } else {
        $htmlContent = $htmlListTemplate
    }

    $htmlContent = $htmlContent -replace "ROWS_PLACEHOLDER", ($rows -join ",`n")
    $htmlContent | Out-File -FilePath $htmlPath -Encoding utf8

}




$edgeArguments = @(
    "--kiosk" 
    "c:\www\index.html"
    "--edge-kiosk-type=fullscreen"
    "--disable-pinch"
    "--touch-events=disabled"
    "--overscroll-history-navigation=0"
    "--disable-touch-drag-drop"
    "--disable-gesture-requirement-for-media-playback"
    "--disable-features=TouchpadOverscrollHistoryNavigation,TouchDragAndDrop"
) 
Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList $edgeArguments


exit 0
