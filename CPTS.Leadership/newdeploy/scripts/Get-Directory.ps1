#Requires -Version 5.1
[CmdletBinding()]
param([string]$OutputFolder = 'C:\www')
$ErrorActionPreference = 'Stop'
$CsvUrl = 'https://docs.google.com/spreadsheets/d/1qFdU-b7u05s-7KrP9b4B8genOWg1j45I8pv-Tx1gQK8/export?format=csv'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$response = $null
for ($attempt=1; $attempt -le 3; $attempt++) {
    try {
        $response = Invoke-WebRequest -Uri $CsvUrl -UseBasicParsing -TimeoutSec 60
        break
    } catch {
        if ($attempt -eq 3) { throw }
        Start-Sleep -Seconds (2 * $attempt)
    }
}
$rows = @(([string]$response.Content) | ConvertFrom-Csv)
if (!$rows.Count -or $null -eq $rows[0].PSObject.Properties['Title'] -or $null -eq $rows[0].PSObject.Properties['Room']) {
    throw 'Expected Title and Room columns were not found. Existing directory was kept.'
}
function Clean-Text([string]$Text) { [regex]::Replace($Text,'\s+',' ').Trim() }
$entries = @(foreach ($row in $rows) {
    if ([string]::IsNullOrWhiteSpace([string]$row.Title)) { break }
    $people = @(foreach ($column in @('Person 1','Person 2','Person 3')) {
        $person = Clean-Text ([string]$row.$column)
        if ($person) { $person }
    })
    [pscustomobject][ordered]@{
        Title = Clean-Text ([string]$row.Title)
        Room = Clean-Text ([string]$row.Room)
        People = $people
    }
})
$data = [ordered]@{ Updated=[datetimeoffset]::UtcNow.ToString('o'); Entries=$entries }
$json = ConvertTo-Json -InputObject $data -Depth 5
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$path = Join-Path $OutputFolder 'Directory.json'
$temp = Join-Path $OutputFolder ('Directory.' + [guid]::NewGuid().ToString('N') + '.tmp')
try {
    [IO.File]::WriteAllText($temp,$json,[Text.UTF8Encoding]::new($false))
    if ([IO.File]::Exists($path)) { [IO.File]::Replace($temp,$path,$null) }
    else { [IO.File]::Move($temp,$path) }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
}
Write-Host ('Saved {0} directory entries to {1}' -f $entries.Count,$path)
