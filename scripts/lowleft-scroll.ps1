# Variables
$url = "https://docs.google.com/spreadsheets/d/e/2PACX-1vTeGA9mhaIGzKltMaNol_ZpGSTWb3zn9aflqht7rgQ8GULU9pGVxMN7vfand7fUoHscMkdm3WzM372h/pub?output=csv"
$htmlPath = "C:\www\lowleft.html"
$topPx = 0
$leftPx = 0

# Download and parse CSV
$csvText = Invoke-WebRequest -Uri $url | Select-Object -ExpandProperty Content
$allLines = $csvText -split "`r?`n" | Where-Object { $_.Trim() -ne "" }
$lines = $allLines | Select-Object -Skip 1  # Skip header

$rows = @()

foreach ($line in $lines) {
    $fields = [regex]::Matches($line, '(?<=^|,)(?:"((?:[^"]|"")*)"|([^",]*))') | ForEach-Object {
        if ($_.Groups[1].Success) { $_.Groups[1].Value.Replace('""','"') } else { $_.Groups[2].Value }
    }

    if ($fields.Count -lt 4 -or $fields[0] -eq "") { continue }

    # Extract last 3 fields: alpha, bgColor, textColor
    $textColor = $fields[-1]
    $bgColor   = $fields[-2]
    $alpha     = $fields[-3]

    # Remove last 3 fields
    $dataOnly = $fields[0..($fields.Count - 4)]

    # Convert hex to rgba
    if ($bgColor -match '^#([0-9a-fA-F]{6})$') {
        $r = [convert]::ToInt32($bgColor.Substring(1,2), 16)
        $g = [convert]::ToInt32($bgColor.Substring(3,2), 16)
        $b = [convert]::ToInt32($bgColor.Substring(5,2), 16)
        $bgColorRgba = "rgba($r, $g, $b, $alpha)"
    } else {
        $bgColorRgba = $bgColor  # fallback if not hex
    }

    # Escape and format row data
    $dataFields = @()
    foreach ($field in $dataOnly) {
        if ($field -eq "") { break }
        $escapedField = '"' + ($field -replace '"','\"') + '"'
        $dataFields += $escapedField
    }

    if ($dataFields.Count -gt 0) {
        $jsonRow = "{ `"data`": [" + ($dataFields -join ", ") + "], `"color`": `"$textColor`", `"background`": `"$bgColorRgba`" }"
        $rows += $jsonRow
    }
}

# HTML Template
$htmlContent = @'
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
      height: calc(1.2em * 8); /* show 8 lines */
      overflow: hidden;
      background: transparent;
    }
    #marquee {
      font-size: 1.7em;
      font-weight: bold;
      line-height: 0.9em;  /* reduced line spacing */
      display: block;
      white-space: nowrap;
    }
    @keyframes scrollUp {
      0% { transform: translateY(0); }
      100% { transform: translateY(-50%); }
    }
    span.email {
      color: blue;
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

function highlightEmails(text) {
  return text.replace(
    /([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/g,
    '<span class="email">$&</span>'
  );
}

function startMarquee() {
  const marquee = document.getElementById('marquee');
  if (rows.length === 0) {
    marquee.innerText = "No data.";
    return;
  }

  const htmlLines = rows.map(row => {
    const content = row.data.join('   ');
    const color = row.color?.trim() || "black";
    const bg = row.background?.trim() || "transparent";
    const line = highlightEmails(content);
    return `<div style="color: ${color}; background-color: ${bg}">${line}</div>`;
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

# Insert the row data into the HTML
$htmlContent = $htmlContent -replace "ROWS_PLACEHOLDER", ($rows -join ",`n")

# Save to output.html
$htmlContent | Out-File -FilePath $htmlPath -Encoding utf8

Write-Host "✅ Compact marquee with reduced line spacing written to $htmlPath"
