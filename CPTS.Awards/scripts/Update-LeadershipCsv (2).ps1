#Requires -Version 5.1
<#
.SYNOPSIS
Creates C:\www\Leadership.csv for CPTS.Awards from the shared leadership Google Sheet.
.DESCRIPTION
Runs once. No Excel, Google API key, sign-in, or administrator rights required.
The Google Sheet must remain readable by anyone with its link.
The task account needs write permission to the output directory.

Exact worksheet coordinates (first tab, gid=0):
Plaque  Line1/name  Line2/title
L1      B18         B19
L2      D18         D19
L3      B20         B21
L4      D20         D21

Blank names become VACANT; blank titles stay blank. Quotes, commas and Unicode
are preserved using real CSV
serialization. The old output is retained if downloading or validation fails.
Writes a complete temporary file before atomically replacing Leadership.csv.
Output columns: Plaque,Line1,Line2. The Awards HTML must include a CSV plaque
reader to display the generated text; this script only creates the CSV file.
.EXAMPLE
pwsh.exe -NoProfile -File C:\www\scripts\Update-LeadershipCsv.ps1
.EXAMPLE
.\Update-LeadershipCsv.ps1 -OutputPath 'D:\Sign\Leadership.csv'
#>
[CmdletBinding()]
param(
    [string]$SpreadsheetId = '1HLxT8OoIQbSEGk1OWwCKJu4FLHjgws-d9Tfm9hdvjUw',
    [ValidatePattern('^\d+$')]
    [string]$SheetGid = '0',
    [string]$OutputPath = 'C:\www\Leadership.csv'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$temporaryPath = $null

try {
    if ($SpreadsheetId -notmatch '^[A-Za-z0-9_-]+$') {
        throw 'SpreadsheetId must be a Google spreadsheet ID, not a full URL.'
    }
    # Windows PowerShell 5.1 may otherwise negotiate an older TLS protocol.
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }

    $uri = 'https://docs.google.com/spreadsheets/d/{0}/export?format=csv&gid={1}&_update={2}' -f $SpreadsheetId, $SheetGid, [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    Write-Host 'Reading Awards leadership names and titles from Google Sheets...'
    $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
    if ($response.Content -is [byte[]]) {
        $sourceCsv = [Text.Encoding]::UTF8.GetString($response.Content)
    }
    else {
        $sourceCsv = [string]$response.Content
    }
    $sourceCsv = $sourceCsv.TrimStart([char]0xFEFF)
    if ([string]::IsNullOrWhiteSpace($sourceCsv) -or $sourceCsv -match '(?is)^\s*<(?:!doctype|html)\b') {
        throw 'Google did not return CSV. Check the sheet sharing permissions.'
    }

    # Supply our own headers so worksheet row 1 remains data, not CSV headers.
    # Column A and all blank spacer rows must be retained for exact coordinates.
    $sheetRows = @($sourceCsv | ConvertFrom-Csv -Header A,B,C,D,E)
    if ($sheetRows.Count -lt 21) {
        throw 'The worksheet has fewer than 21 rows. Existing Leadership.csv was not changed.'
    }
    # The Awards autofill section is on the same first tab, below Names/Titles.
    if (([string]$sheetRows[0].B).Trim() -ne 'Names' -or
        ([string]$sheetRows[8].B).Trim() -ne 'Titles' -or
        ([string]$sheetRows[16].C).Trim() -ne 'Awards') {
        throw 'Expected Names in B1, Titles in B9 and Awards in C17. Check the worksheet tab and layout.'
    }

    $cellMap = @(
        @{ Plaque = 'L1'; NameCell = 'B18'; TitleCell = 'B19' }
        @{ Plaque = 'L2'; NameCell = 'D18'; TitleCell = 'D19' }
        @{ Plaque = 'L3'; NameCell = 'B20'; TitleCell = 'B21' }
        @{ Plaque = 'L4'; NameCell = 'D20'; TitleCell = 'D21' }
    )

    function Get-WorksheetCell {
        param([Parameter(Mandatory)][string]$Address)
        if ($Address -notmatch '^([A-E])([1-9][0-9]*)$') {
            throw "Invalid worksheet cell: $Address"
        }
        $column = $Matches[1]
        $rowIndex = [int]$Matches[2] - 1
        if ($rowIndex -ge $sheetRows.Count) {
            throw "Worksheet cell is missing: $Address"
        }
        return ([string]$sheetRows[$rowIndex].PSObject.Properties[$column].Value).Trim()
    }

    $plaques = @(
        foreach ($entry in $cellMap) {
            $name = Get-WorksheetCell -Address $entry.NameCell
            if ([string]::IsNullOrWhiteSpace($name)) {
                $name = 'VACANT'
            }
            [pscustomobject][ordered]@{
                Plaque = $entry.Plaque
                Line1  = $name
                Line2  = Get-WorksheetCell -Address $entry.TitleCell
            }
        }
    )
    # Avoid erasing the sign if a transient response contains no plaque data.
    $populated = @($cellMap | Where-Object {
        (Get-WorksheetCell -Address $_.NameCell) -or (Get-WorksheetCell -Address $_.TitleCell)
    })
    if ($populated.Count -eq 0) {
        throw 'All mapped names and titles are empty. Existing Leadership.csv was not changed.'
    }

    $csvLines = @($plaques | ConvertTo-Csv -NoTypeInformation)
    $csvText = ($csvLines -join "`r`n") + "`r`n"
    $destination = [IO.Path]::GetFullPath($OutputPath)
    $directory = [IO.Path]::GetDirectoryName($destination)
    [void][IO.Directory]::CreateDirectory($directory)
    if ([IO.File]::Exists($destination) -and [IO.File]::ReadAllText($destination) -ceq $csvText) {
        Write-Host "Leadership.csv is already current: $destination"
        return
    }

    # Same-directory staging keeps the replacement on the same filesystem.
    $temporaryPath = Join-Path $directory ('.Leadership-{0}.tmp' -f [Guid]::NewGuid().ToString('N'))
    [IO.File]::WriteAllText($temporaryPath, $csvText, [Text.UTF8Encoding]::new($false))
    if ([IO.File]::Exists($destination)) {
        # PowerShell can bind $null as an empty string for this .NET overload.
        # Supply a real backup path instead; remove it only after success.
        $backupPath = $temporaryPath + '.bak'
        [IO.File]::Replace($temporaryPath, $destination, $backupPath)
        Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
    }
    else {
        [IO.File]::Move($temporaryPath, $destination)
    }
    $temporaryPath = $null
    Write-Host "Updated all four Awards plaques: $destination"
}
catch {
    Write-Error ("Leadership CSV update failed: {0}" -f $_.Exception.Message) -ErrorAction Continue
    exit 1
}
finally {
    if ($temporaryPath -and [IO.File]::Exists($temporaryPath)) {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    }
}
