#Requires -Version 5.1
<#
Downloads JBERLife events for 28 calendar days, including today.
Run once per refresh; no browser, login, modules, or server required.
Works with Windows PowerShell 5.1 and PowerShell 7.
Example: pwsh.exe -NoProfile -File C:\www\Get-JBEREvents.ps1
#>
[CmdletBinding()]
param(
    [string]$OutputFolder = 'C:\www',
    [ValidateRange(1,52)][int]$Weeks = 4
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$culture = [Globalization.CultureInfo]::InvariantCulture
try { $zone = [TimeZoneInfo]::FindSystemTimeZoneById('Alaskan Standard Time') }
catch { $zone = [TimeZoneInfo]::FindSystemTimeZoneById('America/Anchorage') }
$today = [TimeZoneInfo]::ConvertTimeFromUtc([datetime]::UtcNow, $zone).Date
$until = $today.AddDays(7 * $Weeks) # Exclusive boundary
$first = [uri]::EscapeDataString($today.ToString('yyyy-MM-dd HH:mm:ss', $culture))
$last = [uri]::EscapeDataString($until.AddSeconds(-1).ToString('yyyy-MM-dd HH:mm:ss', $culture))
$endpoint = 'https://jberlife.com/wp-json/tribe/events/v1/events'
$next = "${endpoint}?start_date=$first&end_date=$last&per_page=50&page=1"

function ConvertTo-PlainText([string]$Value) {
    $Value = [regex]::Replace($Value, '(?is)<(script|style)\b[^>]*>.*?</\1>', '')
    $Value = [regex]::Replace($Value, '<[^>]+>', ' ')
    [regex]::Replace([Net.WebUtility]::HtmlDecode($Value), '\s+', ' ').Trim()
}
function Read-EventDate([string]$Value) {
    [datetime]::ParseExact($Value, 'yyyy-MM-dd HH:mm:ss', $culture)
}

# Complete the download before replacing any existing output.
$raw = [Collections.Generic.List[object]]::new()
$visited = @{}
while ($next) {
    $u = [uri]$next
    if ($u.Scheme -ne 'https' -or $u.Host -ne 'jberlife.com') {
        throw "Unexpected pagination address: $next"
    }
    if ($visited.ContainsKey($next)) { throw 'The event feed repeated a page.' }
    $visited[$next] = $true
    $response = $null
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $response = Invoke-RestMethod -Uri $next -Method Get -TimeoutSec 60 -Headers @{
                Accept = 'application/json'
                'User-Agent' = 'JBER-Events-List/1.0'
            }
            break
        }
        catch {
            if ($attempt -eq 3) { throw }
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
    if ($null -eq $response.PSObject.Properties['events']) {
        throw 'The website returned an unexpected response; existing output was kept.'
    }
    foreach ($event in @($response.events)) { $raw.Add($event) }
    $next = [string]$response.next_rest_url
}

$seen = @{}
$events = @(foreach ($event in $raw) {
    $start = Read-EventDate $event.start_date
    $end = Read-EventDate $event.end_date
    # Include ongoing events that overlap the window; exclude the upper boundary.
    if ($start -ge $until -or $end -lt $today) { continue }
    $key = '{0}|{1}' -f $event.id, $event.start_date
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true
    $venue = ''
    $address = ''
    if ($event.venue -and $event.venue.venue) {
        $venue = ConvertTo-PlainText $event.venue.venue
        $address = ConvertTo-PlainText ((@($event.venue.address, $event.venue.city, $event.venue.state, $event.venue.zip) | Where-Object { $_ }) -join ', ')
    }
    [pscustomobject][ordered]@{
        Start = $start.ToString('yyyy-MM-dd HH:mm', $culture)
        End = $end.ToString('yyyy-MM-dd HH:mm', $culture)
        AllDay = [bool]$event.all_day
        Event = ConvertTo-PlainText $event.title
        Location = $venue
        Address = $address
        TimeZone = [string]$event.timezone
        Cost = ConvertTo-PlainText $event.cost
        Description = ConvertTo-PlainText $event.description
        URL = [string]$event.url
    }
} )
$events = @($events | Sort-Object Start, Event)
$lines = [Collections.Generic.List[string]]::new()
$lines.Add('JBERLife Events')
$lines.Add(('{0} through {1} (Alaska time)' -f $today.ToString('MMMM d, yyyy', $culture), $until.AddDays(-1).ToString('MMMM d, yyyy', $culture)))
$lines.Add(('Events: {0}' -f $events.Count))
$lines.Add('')
if (!$events.Count) { $lines.Add('No events were listed for this period.') }
foreach ($event in $events) {
    $lines.Add($event.Event)
    if ($event.AllDay) {
        $lines.Add(('  {0} through {1} | All day' -f $event.Start.Substring(0,10), $event.End.Substring(0,10)))
    } else {
        $lines.Add(('  {0} to {1} | {2}' -f $event.Start, $event.End, $event.TimeZone))
    }
    if ($event.Location) { $lines.Add(('  Location: {0}' -f $event.Location)) }
    if ($event.Address) { $lines.Add(('  Address: {0}' -f $event.Address)) }
    if ($event.Cost) { $lines.Add(('  Cost: {0}' -f $event.Cost)) }
    if ($event.Description) { $lines.Add(('  {0}' -f $event.Description)) }
    $lines.Add(('  {0}' -f $event.URL))
    $lines.Add('')
}
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$txtPath = Join-Path $OutputFolder 'JBER-Events.txt'
$csvPath = Join-Path $OutputFolder 'JBER-Events.csv'
$utf8 = [Text.UTF8Encoding]::new($true)
[IO.File]::WriteAllLines($txtPath, $lines, $utf8)
if ($events.Count) {
    $events | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
} else {
    [IO.File]::WriteAllText($csvPath, '"Start","End","AllDay","Event","Location","Address","TimeZone","Cost","Description","URL"' + [Environment]::NewLine, $utf8)
}
Write-Host ('Saved {0} events to {1} and {2}' -f $events.Count, $txtPath, $csvPath)
