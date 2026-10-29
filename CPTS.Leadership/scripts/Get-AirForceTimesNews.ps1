#Requires -Version 5.1
<# Run whenever you want to download fresh headlines. No watch loop or browser.
   Save beside your other scripts; output defaults to C:\www.
   pwsh.exe -NoProfile -File "C:\www\Get-AirForceTimesNews.ps1"
#>
[CmdletBinding()]
param([string]$OutputFolder = 'C:\www')
$ErrorActionPreference = 'Stop'
$FeedUrl = 'https://www.airforcetimes.com/arc/outboundfeeds/rss/?outputType=xml'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$response = $null
for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
        $response = Invoke-WebRequest -Uri $FeedUrl -UseBasicParsing -TimeoutSec 60 -Headers @{
            Accept = 'application/rss+xml, application/xml, text/xml'
            'User-Agent' = 'DigitalSign-News/1.0'
        }
        break
    } catch {
        if ($attempt -eq 3) { throw }
        Start-Sleep -Seconds (2 * $attempt)
    }
}
# Disable external XML resources when parsing the RSS feed.
$settings = [Xml.XmlReaderSettings]::new()
$settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
$settings.XmlResolver = $null
$reader = [Xml.XmlReader]::Create([IO.StringReader]::new([string]$response.Content), $settings)
$xml = [Xml.XmlDocument]::new()
$xml.XmlResolver = $null
try { $xml.Load($reader) } finally { $reader.Dispose() }
$seen = @{}
$headlines = @(foreach ($item in $xml.SelectNodes('/rss/channel/item')) {
    $title = [Net.WebUtility]::HtmlDecode([string]$item.title).Trim()
    $link = [string]$item.link
    if (!$title) { continue }
    $key = if ($link) { $link } else { $title }
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true
    $published = ''
    if ($item.pubDate) {
        $published = ([datetimeoffset]::Parse([string]$item.pubDate, [Globalization.CultureInfo]::InvariantCulture)).ToUniversalTime().ToString('o')
    }
    [pscustomobject][ordered]@{Title=$title; Published=$published; URL=$link}
})
if (!$headlines.Count) { throw 'No headlines found. Existing news file was kept.' }
$headlines = @($headlines | Sort-Object Published -Descending)
$data = [ordered]@{
    Source = 'Air Force Times'
    Updated = [datetimeoffset]::UtcNow.ToString('o')
    Headlines = $headlines
}
$json = ConvertTo-Json -InputObject $data -Depth 5
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$destination = Join-Path $OutputFolder 'AirForceTimes-News.json'
$temp = Join-Path $OutputFolder ('AirForceTimes-News.' + [guid]::NewGuid().ToString('N') + '.tmp')
try {
    [IO.File]::WriteAllText($temp,$json,[Text.UTF8Encoding]::new($false))
    if ([IO.File]::Exists($destination)) { [IO.File]::Replace($temp,$destination,($temp + '.bak')) }
    else { [IO.File]::Move($temp,$destination) }
} finally {
    if (Test-Path -LiteralPath ($temp + '.bak')) { Remove-Item -LiteralPath ($temp + '.bak') -Force }
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
}
Write-Host ('Saved {0} headlines to {1}' -f $headlines.Count,$destination)
