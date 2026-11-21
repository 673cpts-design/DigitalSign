#requires -Version 5.1
<#
Download quarterly and yearly labels from exact cells in the winners sheet.
Quarter: B1. Quarterly year: B2. Yearly year: E2.
Quarterly: B4/B5, B7/B8 ... B34/B35.
Yearly: E4/E5, E7/E8 ... E34/E35.
Each CSV includes its own year, quarter, and heading from its side of the sheet.
Writes quarterly-winners.csv and yearly-winners.csv plus matching JavaScript
companions for local file playback. Run before Build-index-html.ps1.
Blank yearly labels are valid. Missing trailing cells are blank.
#>
[CmdletBinding()]
param(
    [string]$OutputDirectory = $(if ((Split-Path $PSScriptRoot -Leaf) -ieq 'scripts') { Split-Path $PSScriptRoot -Parent } else { $PSScriptRoot }),
    [string]$SpreadsheetId = '1c2XMweSsxXmC_QvunSiMlA6odfIM0G6s_-DlQhpo9fM',
    [string]$SheetGid = '0'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName Microsoft.VisualBasic
$parser = $null
$reader = $null
$temporaryFiles = [Collections.Generic.List[string]]::new()
try {
    $url = 'https://docs.google.com/spreadsheets/d/{0}/export?format=csv&gid={1}' -f [Uri]::EscapeDataString($SpreadsheetId), [Uri]::EscapeDataString($SheetGid)
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 60
    $text = [string]$response.Content
    if ($text -match '(?is)^\s*(<!doctype\s+html|<html)') { throw 'Google returned HTML instead of CSV. Check sharing and the sheet gid.' }
    $reader = [IO.StringReader]::new($text.TrimStart([char]0xFEFF))
    $parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new($reader)
    $parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
    $parser.SetDelimiters(',')
    $parser.HasFieldsEnclosedInQuotes = $true
    $parser.TrimWhiteSpace = $false
    $rows = [Collections.Generic.List[object]]::new()
    while (-not $parser.EndOfData) { $rows.Add($parser.ReadFields()) }
    function Get-Cell([int]$Row, [int]$Column) {
        if ($Row -gt $rows.Count -or $Column -gt $rows[$Row-1].Length) { return '' }
        return ([regex]::Replace([string]$rows[$Row-1][$Column-1], '\s+', ' ')).Trim()
    }
    if ((Get-Cell 1 1) -ne 'Quarter' -or (Get-Cell 2 1) -ne 'Year' -or
        (Get-Cell 2 4) -ne 'Year' -or (Get-Cell 3 1) -ne 'Slide' -or
        (Get-Cell 3 2) -ne 'Text' -or (Get-Cell 3 4) -ne 'Slide' -or (Get-Cell 3 5) -ne 'Text') {
        throw 'Unexpected layout: expected Quarter in A1, Year in A2/D2, Slide in A3/D3, Text in B3/E3.'
    }
    $quarter = Get-Cell 1 2
    if ($quarter -notmatch '^[1-4]$') { throw 'B1 must contain quarter 1, 2, 3, or 4.' }
    $quarterYear = Get-Cell 2 2
    $yearlyYear = Get-Cell 2 5
    if ($quarterYear -notmatch '^\d{4}$' -or $yearlyYear -notmatch '^\d{4}$') { throw 'B2 and E2 must contain four-digit years.' }
    [IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
    $OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
    $encoding = [Text.UTF8Encoding]::new($false)
    $pending = [Collections.Generic.List[object]]::new()
    foreach ($group in @(
        @{ Key='quarterly'; Column=2; Year=$quarterYear; Quarter=$quarter },
        @{ Key='yearly'; Column=5; Year=$yearlyYear; Quarter='' }
    )) {
        $records = @(for ($i=0; $i -lt 11; $i++) {
            [pscustomobject][ordered]@{
                file = 'slide-{0:D3}.png' -f $i
                name = Get-Cell (4 + 3*$i) $group.Column
                title = Get-Cell (5 + 3*$i) $group.Column
                year = $group.Year
                quarter = $group.Quarter
                heading = $(if ($group.Key -eq 'quarterly') {
                    'MSG Quarter {0} Award Winners {1}' -f $group.Quarter, $group.Year
                } else {
                    'MSG Annual Award Winners {0}' -f $group.Year
                })
            }
        })
        $csv = (($records | ConvertTo-Csv -NoTypeInformation) -join "`r`n") + "`r`n"
        $json = ConvertTo-Json -InputObject $csv -Compress
        $js = 'window.winnerNameplateCSV = ' + $json + ";`r`n"
        foreach ($output in @(
            @{ Name=($group.Key + '-winners.csv'); Content=$csv },
            @{ Name=($group.Key + '-winners.js'); Content=$js }
        )) {
            $temp = Join-Path $OutputDirectory ([IO.Path]::GetRandomFileName())
            $temporaryFiles.Add($temp)
            [IO.File]::WriteAllText($temp, $output.Content, $encoding)
            $pending.Add(@{ Temp=$temp; Target=(Join-Path $OutputDirectory $output.Name) })
        }
        Write-Host ('Prepared {0}, {1}: {2} populated nameplates.' -f $group.Key, $group.Year, @($records | Where-Object {$_.name -or $_.title}).Count)
    }
    # All parsing and staging finishes before any existing output is changed.
    foreach ($output in $pending) {
        if ([IO.File]::Exists($output.Target)) {
            $backup = $output.Target + '.' + [Guid]::NewGuid().ToString('N') + '.previous'
            [IO.File]::Replace($output.Temp, $output.Target, $backup)
            [IO.File]::Delete($backup)
        } else { [IO.File]::Move($output.Temp, $output.Target) }
    }
    Write-Host ('Saved quarterly/yearly CSVs and playback companions to {0}' -f $OutputDirectory)
} catch {
    Write-Error ('Winners label update failed: ' + $_.Exception.Message)
    exit 1
} finally {
    if ($null -ne $parser) { $parser.Dispose() }
    if ($null -ne $reader) { $reader.Dispose() }
    foreach ($path in $temporaryFiles) { if ($path -and [IO.File]::Exists($path)) { [IO.File]::Delete($path) } }
}
