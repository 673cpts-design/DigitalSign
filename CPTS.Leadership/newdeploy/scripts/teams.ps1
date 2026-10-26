$CsvUrl = "https://docs.google.com/spreadsheets/d/1xl5a2p9u0cX3V1xsNGAKGfO_ySy2y23klVs9O3NgJ4o/export?format=csv&gid=0"
$OutputFolder = "C:\www"

try {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

    # Download into memory without saving the CSV.
    $Response = Invoke-WebRequest -Uri $CsvUrl -UseBasicParsing -ErrorAction Stop

    # Supply column names so the spreadsheet's first row remains a data row.
    $Headers = @(
        65..76 | ForEach-Object { ([char]$_).ToString() }
    )
    $Rows = @(
        $Response.Content | ConvertFrom-Csv -Header $Headers |
            Select-Object -Skip 1
    )

    $Utf8 = [System.Text.UTF8Encoding]::new($false)

    foreach ($Column in $Headers) {
        $Values = [System.Collections.Generic.List[string]]::new()

        foreach ($Row in $Rows) {
            $Value = [string]$Row.$Column

            if ([string]::IsNullOrWhiteSpace($Value)) {
                break
            }

            $Values.Add($Value)
        }

        $OutputFile = Join-Path $OutputFolder "$Column.txt"

        # Overwrite each file, including clearing it if row 2 is empty.
        [System.IO.File]::WriteAllLines($OutputFile, $Values, $Utf8)
    }

    Write-Host "Created A.txt through L.txt in $OutputFolder"
}
catch {
    Write-Error "Export failed: $($_.Exception.Message)"
    exit 1
}
