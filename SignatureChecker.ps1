# ============================================================
#  SignatureChecker.ps1
#  By SeniorHere
#  Checks file existence + digital signature (Authenticode).
#  Usage: irm <raw-url> | iex
# ============================================================

Clear-Host
Write-Host ""
Write-Host "  ███████╗██╗ ██████╗ ███╗   ██╗ █████╗ ████████╗██╗   ██╗██████╗ ███████╗" -ForegroundColor Cyan
Write-Host "  ██╔════╝██║██╔════╝ ████╗  ██║██╔══██╗╚══██╔══╝██║   ██║██╔══██╗██╔════╝" -ForegroundColor Cyan
Write-Host "  ███████╗██║██║  ███╗██╔██╗ ██║███████║   ██║   ██║   ██║██████╔╝█████╗  " -ForegroundColor Cyan
Write-Host "  ╚════██║██║██║   ██║██║╚██╗██║██╔══██║   ██║   ██║   ██║██╔══██╗██╔══╝  " -ForegroundColor Cyan
Write-Host "  ███████║██║╚██████╔╝██║ ╚████║██║  ██║   ██║   ╚██████╔╝██║  ██║███████╗" -ForegroundColor Cyan
Write-Host "  ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "                              By SeniorHere" -ForegroundColor Green
Write-Host "                       Signature Checker v1.0" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  ===================================================================" -ForegroundColor DarkGray
Write-Host ""

$InputFile = Read-Host "  Path to .txt file (one path per line)"

if ([string]::IsNullOrWhiteSpace($InputFile)) {
    Write-Host "  No input file given. Exiting." -ForegroundColor Red
    Start-Sleep -Seconds 2
    return
}

$InputFile = $InputFile.Trim('"').Trim("'")

if (-not (Test-Path -LiteralPath $InputFile)) {
    Write-Host "  File not found: $InputFile" -ForegroundColor Red
    Start-Sleep -Seconds 2
    return
}

$OutputDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "ScreenShare Tool\Reports"
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$txtReport = Join-Path $OutputDir "SignatureCheck-$stamp.txt"
$csvReport = Join-Path $OutputDir "SignatureCheck-$stamp.csv"

$paths = Get-Content -LiteralPath $InputFile -Encoding UTF8 -ErrorAction SilentlyContinue |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne "" -and -not $_.StartsWith("#") } |
    Select-Object -Unique

Write-Host ""
Write-Host "  Paths to check: $($paths.Count)" -ForegroundColor Yellow
Write-Host ""

if ($paths.Count -eq 0) {
    Write-Host "  No valid paths found." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    return
}

$results = New-Object System.Collections.Generic.List[PSObject]
$index = 0
$total = $paths.Count

foreach ($path in $paths) {
    $index++
    Write-Progress -Activity "Checking signatures" -Status "$index / $total" -PercentComplete (($index / $total) * 100)

    $entry = [PSCustomObject]@{
        Path     = $path
        Exists   = $false
        Size     = $null
        Modified = $null
        Signed   = $false
        Signer   = ""
        Status   = ""
        Note     = ""
    }

    try {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $entry.Exists = $true
            try {
                $fi = Get-Item -LiteralPath $path -ErrorAction Stop
                $entry.Size = $fi.Length
                $entry.Modified = $fi.LastWriteTime
            } catch { $entry.Note = "Cannot read file info." }

            try {
                $sig = Get-AuthenticodeSignature -LiteralPath $path -ErrorAction Stop
                if ($sig -and $sig.Status -eq "Valid" -and $sig.SignerCertificate) {
                    $entry.Signed = $true
                    $entry.Signer = $sig.SignerCertificate.Subject
                    $entry.Status = "SIGNED"
                } else {
                    $entry.Signed = $false
                    $entry.Status = "UNSIGNED"
                    if ($sig -and $sig.Status) { $entry.Note = "Signature status: $($sig.Status)" }
                }
            } catch {
                $entry.Signed = $false
                $entry.Status = "UNSIGNED"
                $entry.Note = "Signature check failed."
            }
        } else {
            $entry.Exists = $false
            $entry.Status = "MISSING"
        }
    } catch {
        $entry.Status = "ERROR"
        $entry.Note = $_.Exception.Message
    }

    $results.Add($entry)
}

Write-Progress -Activity "Checking signatures" -Completed

$unsigned = $results | Where-Object { $_.Status -eq "UNSIGNED" }
$missing  = $results | Where-Object { $_.Status -eq "MISSING" }
$signed   = $results | Where-Object { $_.Status -eq "SIGNED" }
$errors   = $results | Where-Object { $_.Status -eq "ERROR" }

Write-Host ""
Write-Host "  ===================================================================" -ForegroundColor DarkGray
Write-Host "    RESULTS" -ForegroundColor Cyan
Write-Host "  ===================================================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host ("    Total paths  : {0}" -f $total) -ForegroundColor White
Write-Host ("    Signed       : {0}" -f $signed.Count) -ForegroundColor Green
Write-Host ("    Unsigned     : {0}" -f $unsigned.Count) -ForegroundColor Yellow
Write-Host ("    Missing      : {0}" -f $missing.Count) -ForegroundColor Red
Write-Host ("    Errors       : {0}" -f $errors.Count) -ForegroundColor Magenta
Write-Host ""

$sb = New-Object System.Text.StringBuilder
function Add-Line { param([string]$T = "") [void]$sb.AppendLine($T) }

$thick = "=" * 60
$thin  = "-" * 60

Add-Line $thick
Add-Line "              SIGNATURE CHECKER REPORT"
Add-Line "                  By SeniorHere"
Add-Line $thick
Add-Line ("Generated  : {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Add-Line ("Input file : {0}" -f $InputFile)
Add-Line ("Total      : {0}" -f $total)
Add-Line ("Signed     : {0}" -f $signed.Count)
Add-Line ("Unsigned   : {0}" -f $unsigned.Count)
Add-Line ("Missing    : {0}" -f $missing.Count)
Add-Line ("Errors     : {0}" -f $errors.Count)
Add-Line ""

Add-Line $thick
Add-Line ("1. UNSIGNED (PRESENT, NO VALID SIGNATURE)  -  Count: {0}" -f $unsigned.Count)
Add-Line $thick
if ($unsigned.Count -eq 0) { Add-Line "None." } else {
    $n = 0
    foreach ($e in $unsigned) {
        $n++
        Add-Line ""
        Add-Line ("[{0:D3}] {1}" -f $n, (Split-Path $e.Path -Leaf))
        Add-Line $thin
        Add-Line ("Path    : {0}" -f $e.Path)
        if ($e.Size -ne $null) { Add-Line ("Size    : {0:N0} bytes" -f $e.Size) }
        if ($e.Modified -ne $null) { Add-Line ("Modified: {0}" -f $e.Modified.ToString("yyyy-MM-dd HH:mm:ss")) }
        if ($e.Note) { Add-Line ("Note    : {0}" -f $e.Note) }
    }
}
Add-Line ""

Add-Line $thick
Add-Line ("2. MISSING (PATH NOT FOUND)  -  Count: {0}" -f $missing.Count)
Add-Line $thick
if ($missing.Count -eq 0) { Add-Line "None." } else {
    $n = 0
    foreach ($e in $missing) { $n++; Add-Line ("[{0:D3}] {1}" -f $n, $e.Path) }
}
Add-Line ""

Add-Line $thick
Add-Line ("3. SIGNED (VALID SIGNATURE)  -  Count: {0}" -f $signed.Count)
Add-Line $thick
if ($signed.Count -eq 0) { Add-Line "None." } else {
    $n = 0
    foreach ($e in $signed) {
        $n++
        Add-Line ""
        Add-Line ("[{0:D3}] {1}" -f $n, (Split-Path $e.Path -Leaf))
        Add-Line $thin
        Add-Line ("Path    : {0}" -f $e.Path)
        if ($e.Size -ne $null) { Add-Line ("Size    : {0:N0} bytes" -f $e.Size) }
        if ($e.Modified -ne $null) { Add-Line ("Modified: {0}" -f $e.Modified.ToString("yyyy-MM-dd HH:mm:ss")) }
        Add-Line ("Signer  : {0}" -f $e.Signer)
    }
}
Add-Line ""

if ($errors.Count -gt 0) {
    Add-Line $thick
    Add-Line ("4. ERRORS  -  Count: {0}" -f $errors.Count)
    Add-Line $thick
    foreach ($e in $errors) { Add-Line ("[{0}] {1}" -f $e.Path, $e.Note) }
    Add-Line ""
}

Add-Line $thick
Add-Line "END OF REPORT"
Add-Line $thick

$sb.ToString() | Out-File -FilePath $txtReport -Encoding UTF8

$results |
    Select-Object `
        Path,
        @{N="Exists";   E={ $_.Exists }},
        @{N="Signed";   E={ $_.Signed }},
        @{N="Signer";   E={ $_.Signer }},
        @{N="Status";   E={ $_.Status }},
        @{N="Size";     E={ $_.Size }},
        @{N="Modified"; E={ if ($_.Modified) { $_.Modified.ToString("yyyy-MM-dd HH:mm:ss") } else { "" } }},
        @{N="Note";     E={ $_.Note }} |
    Export-Csv -Path $csvReport -NoTypeInformation -Encoding UTF8

Write-Host "  ===================================================================" -ForegroundColor DarkGray
Write-Host "    ✅ REPORTS SAVED" -ForegroundColor Green
Write-Host "  ===================================================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "    TXT: $txtReport" -ForegroundColor Yellow
Write-Host "    CSV: $csvReport" -ForegroundColor Yellow
Write-Host ""
Read-Host "  Press Enter to exit"