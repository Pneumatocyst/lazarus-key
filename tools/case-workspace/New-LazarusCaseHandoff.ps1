[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CaseId,
    [string]$CasesRoot,
    [string]$StorageRoot,
    [ValidateSet('Standard', 'Strict')][string]$Profile = 'Strict',
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'LazarusCase.psm1') -Force

$case = Get-LazarusCase -CaseId $CaseId -CasesRoot $CasesRoot -StorageRoot $StorageRoot
$toolsRoot = Split-Path -Parent $PSScriptRoot
$bundler = Join-Path $toolsRoot 'report-packager\New-SafeReportBundle.ps1'
if (-not (Test-Path -LiteralPath $bundler -PathType Leaf)) {
    throw "Safe Report Packager is missing: $bundler"
}

$sourceFiles = @(Get-ChildItem -LiteralPath $case.ReportsPath -File -Recurse | Sort-Object FullName)
$sourceHashes = @{}
foreach ($sourceFile in $sourceFiles) {
    $sourceHashes[$sourceFile.FullName] = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "LKCH-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$handoffSource = Join-Path $temporaryRoot 'handoff-source'
$customPatterns = [System.Collections.Generic.List[string]]::new()

try {
    New-Item -ItemType Directory -Path $handoffSource -Force | Out-Null
    $metadata = $case.Metadata
    $handoffMetadata = [pscustomobject][ordered]@{
        schema_version = 1
        case_id = [string]$metadata.case_id
        title = [string]$metadata.title
        ticket_number = [string]$metadata.ticket_number
        customer = [string]$metadata.customer
        device_name = [string]$metadata.device_name
        status = [string]$metadata.status
        created_at = [string]$metadata.created_at
        updated_at = [string]$metadata.updated_at
        handoff_profile = $Profile.ToLowerInvariant()
        generated_at = (Get-Date).ToString('o')
    }

    if ($Profile -eq 'Strict') {
        foreach ($value in @($metadata.title, $metadata.ticket_number, $metadata.customer, $metadata.device_name, $metadata.technician)) {
            $text = [string]$value
            if (-not [string]::IsNullOrWhiteSpace($text) -and $text.Length -ge 3) {
                $customPatterns.Add([regex]::Escape($text))
            }
        }
        $handoffMetadata.title = '[REDACTED-CASE-TITLE]'
        $handoffMetadata.ticket_number = '[REDACTED-TICKET]'
        $handoffMetadata.customer = '[REDACTED-CUSTOMER]'
        $handoffMetadata.device_name = '[REDACTED-HOST]'
    }

    $handoffMetadata | ConvertTo-Json -Depth 6 |
        Set-Content -LiteralPath (Join-Path $handoffSource 'case-details.json') -Encoding UTF8

    if (Test-Path -LiteralPath $case.NotesPath -PathType Leaf) {
        Copy-Item -LiteralPath $case.NotesPath -Destination (Join-Path $handoffSource 'technician-notes.txt')
    }

    $reportIndex = 0
    foreach ($sourceFile in $sourceFiles) {
        $reportIndex++
        if ($Profile -eq 'Strict') {
            # Report collectors commonly include hostnames, usernames, and
            # timestamps in directory and file names. Content redaction cannot
            # protect those path components, so Strict handoffs use stable,
            # neutral names while retaining each file's original extension.
            $relative = 'report-{0:D3}{1}' -f $reportIndex, $sourceFile.Extension.ToLowerInvariant()
        }
        else {
            $relative = $sourceFile.FullName.Substring($case.ReportsPath.Length).TrimStart([char[]]@('\', '/'))
        }
        $destination = Join-Path (Join-Path $handoffSource 'Reports') $relative
        $parent = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Copy-Item -LiteralPath $sourceFile.FullName -Destination $destination
    }

    $bundle = & $bundler -SourceDirectory $handoffSource -OutputDirectory $case.BundlesPath `
        -Profile $Profile -CustomPattern $customPatterns.ToArray() -PassThru

    foreach ($sourcePath in $sourceHashes.Keys) {
        $afterHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        if ($afterHash -ne $sourceHashes[$sourcePath]) {
            throw "A source report changed during case packaging: $sourcePath"
        }
    }

    Add-LazarusCaseActivity -CaseId $CaseId -CasesRoot (Split-Path -Parent $case.Path) `
        -Action 'handoff_packaged' -Details "$Profile bundle: $([System.IO.Path]::GetFileName($bundle.BundlePath))" | Out-Null
    New-LazarusCaseSummary -CaseId $CaseId -CasesRoot (Split-Path -Parent $case.Path) | Out-Null

    $result = [pscustomobject][ordered]@{
        CaseId = $CaseId
        Profile = $Profile
        BundlePath = $bundle.BundlePath
        BundleHashPath = $bundle.BundleHashPath
        Sha256 = $bundle.Sha256
        FilesPackaged = $bundle.FilesPackaged
        Redactions = $bundle.Redactions
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

if ($PassThru) { return $result }
Write-Host "Case handoff created: $($result.BundlePath)" -ForegroundColor Green
Write-Host "SHA-256: $($result.Sha256)" -ForegroundColor DarkCyan
Write-Host 'Review the sanitized bundle before sharing it.' -ForegroundColor Yellow
