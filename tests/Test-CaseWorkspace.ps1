[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$caseToolRoot = Join-Path $projectRoot 'tools\case-workspace'
$module = Join-Path $caseToolRoot 'LazarusCase.psm1'
$handoff = Join-Path $caseToolRoot 'New-LazarusCaseHandoff.ps1'
$verifier = Join-Path $projectRoot 'tools\report-packager\Test-SafeReportBundle.ps1'
# Keep the synthetic workspace representative of the compact drive paths used
# in production and below the legacy Windows PowerShell 5.1 MAX_PATH boundary.
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "LKCT-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$storageRoot = Join-Path $temporaryRoot 'storage'

try {
    New-Item -ItemType Directory -Path $storageRoot -Force | Out-Null
    Import-Module $module -Force
    $casesRoot = Get-LazarusCasesRoot -StorageRoot $storageRoot

    $first = New-LazarusCaseWorkspace -Title 'Printer <Lab> incident' -TicketNumber 'INC-424242' `
        -Customer 'Casey Example' -DeviceName 'SECRET-HOST-77' -Technician 'DOMAIN\Tech Person' `
        -CasesRoot $casesRoot -Activate
    Assert-True ($first.CaseId -match '^LK-[0-9]{8}-[0-9]{6}-[0-9A-F]{4}$') 'Case id format is invalid.'
    Assert-True ((Get-LazarusActiveCase -CasesRoot $casesRoot).CaseId -eq $first.CaseId) 'New case was not activated.'

    $reportDirectory = New-LazarusCaseReportDirectory -ToolName 'Synthetic-Test' -CasesRoot $casesRoot
    Assert-True $reportDirectory.StartsWith($first.ReportsPath, [System.StringComparison]::OrdinalIgnoreCase) 'Report did not route into the active case.'
    @'
Computer name : SECRET-HOST-77
Current user  : DOMAIN\Tech Person
Serial number : 11111111-2222-3333-4444-555555555555
Customer      : Casey Example
Ticket        : INC-424242
'@ | Set-Content -LiteralPath (Join-Path $reportDirectory 'system.txt') -Encoding UTF8
    [pscustomobject][ordered]@{
        ComputerName = 'SECRET-HOST-77'
        CurrentUser = 'DOMAIN\Tech Person'
        Customer = 'Casey Example'
        Ticket = 'INC-424242'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $reportDirectory 'system.json') -Encoding UTF8

    $sensitivePath = Join-Path $reportDirectory 'Collector-SECRET-HOST-77-DOMAIN-Tech-Person'
    New-Item -ItemType Directory -Path $sensitivePath -Force | Out-Null
    'Computer name : SECRET-HOST-77' |
        Set-Content -LiteralPath (Join-Path $sensitivePath 'network-SECRET-HOST-77.txt') -Encoding UTF8

    Add-LazarusCaseNote -CaseId $first.CaseId -CasesRoot $casesRoot `
        -Note 'Casey Example approved diagnostics for INC-424242 on SECRET-HOST-77.' | Out-Null
    Set-LazarusCaseStatus -CaseId $first.CaseId -CasesRoot $casesRoot -Status 'In Progress' | Out-Null

    $summaryPath = New-LazarusCaseSummary -CaseId $first.CaseId -CasesRoot $casesRoot
    $summary = Get-Content -LiteralPath $summaryPath -Raw
    Assert-True $summary.Contains('Printer &lt;Lab&gt; incident') 'HTML summary did not encode the case title safely.'
    Assert-True (-not $summary.Contains('Printer <Lab> incident')) 'HTML summary contains an unencoded case title.'
    Assert-True $summary.Contains('system.txt') 'HTML summary did not index the report files.'

    $workspaceCheck = Test-LazarusCaseWorkspace -CaseId $first.CaseId -CasesRoot $casesRoot -PassThru
    Assert-True $workspaceCheck.Valid ('Case validation failed: ' + ($workspaceCheck.Errors -join '; '))

    $second = New-LazarusCaseWorkspace -Title 'Second test case' -CasesRoot $casesRoot
    Assert-True ((Get-LazarusActiveCase -CasesRoot $casesRoot).CaseId -eq $first.CaseId) 'Creating an inactive case replaced the active case.'
    Set-LazarusActiveCase -CaseId $second.CaseId -CasesRoot $casesRoot | Out-Null
    Assert-True ((Get-LazarusActiveCase -CasesRoot $casesRoot).CaseId -eq $second.CaseId) 'Case activation did not switch workspaces.'
    Clear-LazarusActiveCase -CasesRoot $casesRoot
    Assert-True ($null -eq (Get-LazarusActiveCase -CasesRoot $casesRoot)) 'Active case pointer was not cleared.'

    Set-LazarusActiveCase -CaseId $first.CaseId -CasesRoot $casesRoot | Out-Null
    $sourceReport = Join-Path $reportDirectory 'system.txt'
    $expectedReportCount = @(Get-ChildItem -LiteralPath $first.ReportsPath -File -Recurse).Count
    $sourceHashBefore = (Get-FileHash -LiteralPath $sourceReport -Algorithm SHA256).Hash
    $bundle = & $handoff -CaseId $first.CaseId -CasesRoot $casesRoot -Profile Strict -PassThru
    $sourceHashAfter = (Get-FileHash -LiteralPath $sourceReport -Algorithm SHA256).Hash
    Assert-True ($sourceHashBefore -eq $sourceHashAfter) 'Case packaging modified a source report.'
    Assert-True (Test-Path -LiteralPath $bundle.BundlePath -PathType Leaf) 'Case handoff ZIP was not created.'
    Assert-True (Test-Path -LiteralPath $bundle.BundleHashPath -PathType Leaf) 'Case handoff companion hash was not created.'

    $verification = & $verifier -BundlePath $bundle.BundlePath -PassThru
    Assert-True $verification.Valid ('Case handoff verification failed: ' + ($verification.Errors -join '; '))

    $expanded = Join-Path $temporaryRoot 'expanded'
    Expand-Archive -LiteralPath $bundle.BundlePath -DestinationPath $expanded -Force
    $packagedPaths = (Get-ChildItem -LiteralPath $expanded -Recurse |
        ForEach-Object { $_.FullName.Substring($expanded.Length) }) -join "`n"
    $packagedText = (Get-ChildItem -LiteralPath $expanded -File -Recurse |
        ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
    foreach ($forbidden in @('Printer <Lab> incident', 'INC-424242', 'Casey Example', 'SECRET-HOST-77', 'DOMAIN\Tech Person')) {
        Assert-True (-not $packagedText.Contains($forbidden)) "Strict handoff retained sensitive case value: $forbidden"
        Assert-True (-not $packagedPaths.Contains($forbidden)) "Strict handoff retained a sensitive value in a path: $forbidden"
    }
    $strictReportFiles = @(Get-ChildItem -LiteralPath (Join-Path $expanded 'Reports') -File -Recurse)
    Assert-True ($strictReportFiles.Count -eq $expectedReportCount) 'Strict handoff did not retain every source report.'
    foreach ($strictReportFile in $strictReportFiles) {
        Assert-True ($strictReportFile.Name -match '^report-[0-9]{3}\.(?:txt|log|json|csv)$') `
            "Strict handoff used a non-neutral report name: $($strictReportFile.Name)"
    }
    Get-Content -LiteralPath (Join-Path $expanded 'case-details.json') -Raw | ConvertFrom-Json | Out-Null

    $unsafeRejected = $false
    try { Get-LazarusCase -CaseId '..\escape' -CasesRoot $casesRoot | Out-Null }
    catch { $unsafeRejected = $true }
    Assert-True $unsafeRejected 'Unsafe case id was not rejected.'

    Write-Host 'Case Workspace tests passed.' -ForegroundColor Green
}
finally {
    Remove-Module LazarusCase -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $temporaryRoot) { Remove-Item -LiteralPath $temporaryRoot -Recurse -Force }
}
