Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:CaseSchemaVersion = 1
$script:AllowedStatuses = @('Open', 'In Progress', 'Resolved', 'Closed')

function Resolve-LazarusStorageRoot {
    [CmdletBinding()]
    param([string]$StorageRoot)

    if (-not [string]::IsNullOrWhiteSpace($StorageRoot)) {
        if (-not (Test-Path -LiteralPath $StorageRoot -PathType Container)) {
            New-Item -ItemType Directory -Path $StorageRoot -Force | Out-Null
        }
        return (Resolve-Path -LiteralPath $StorageRoot).Path
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LAZARUS_STORAGE_ROOT)) {
        return (Resolve-LazarusStorageRoot -StorageRoot $env:LAZARUS_STORAGE_ROOT)
    }

    $supportedLabels = @('LAZARUSDATA', 'LAZARUS_DATA')
    try {
        $volume = Get-Volume -ErrorAction Stop |
            Where-Object { $_.DriveLetter -and ($supportedLabels -contains $_.FileSystemLabel) } |
            Select-Object -First 1
        if ($volume) { return "$($volume.DriveLetter):\" }
    }
    catch {
        # Try the CIM fallback below.
    }

    try {
        $volume = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop |
            Where-Object { $_.DeviceID -and ($supportedLabels -contains $_.VolumeName) } |
            Select-Object -First 1
        if ($volume) { return "$($volume.DeviceID)\" }
    }
    catch {
        # Use the project-local fallback below.
    }

    $scriptsRoot = Split-Path -Parent $PSScriptRoot
    return (Split-Path -Parent $scriptsRoot)
}

function Get-LazarusCasesRoot {
    [CmdletBinding()]
    param([string]$StorageRoot)

    $root = Join-Path (Resolve-LazarusStorageRoot -StorageRoot $StorageRoot) 'Cases'
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
    return (Resolve-Path -LiteralPath $root).Path
}

function Assert-LazarusCaseId {
    param([Parameter(Mandatory)][string]$CaseId)
    if ($CaseId -notmatch '^LK-[0-9]{8}-[0-9]{6}-[0-9A-F]{4}$') {
        throw "Invalid Lazarus case id: $CaseId"
    }
}

function Write-LazarusJsonAtomic {
    param(
        [Parameter(Mandatory)][object]$InputObject,
        [Parameter(Mandatory)][string]$Path
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $temporary = "$Path.tmp-$([guid]::NewGuid().ToString('N'))"
    try {
        $InputObject | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $temporary -Encoding UTF8
        Get-Content -LiteralPath $temporary -Raw | ConvertFrom-Json | Out-Null
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function Get-LazarusCase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CaseId,
        [string]$CasesRoot,
        [string]$StorageRoot
    )

    Assert-LazarusCaseId -CaseId $CaseId
    if ([string]::IsNullOrWhiteSpace($CasesRoot)) {
        $CasesRoot = Get-LazarusCasesRoot -StorageRoot $StorageRoot
    }
    $casePath = Join-Path $CasesRoot $CaseId
    $metadataPath = Join-Path $casePath 'case.json'
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        throw "Lazarus case not found: $CaseId"
    }
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    if ([int]$metadata.schema_version -ne $script:CaseSchemaVersion -or [string]$metadata.case_id -ne $CaseId) {
        throw "Unsupported or inconsistent case metadata: $metadataPath"
    }
    return [pscustomobject][ordered]@{
        CaseId = $CaseId
        Path = $casePath
        MetadataPath = $metadataPath
        ReportsPath = Join-Path $casePath 'Reports'
        AttachmentsPath = Join-Path $casePath 'Attachments'
        BundlesPath = Join-Path $casePath 'Safe-Bundles'
        NotesPath = Join-Path $casePath 'technician-notes.md'
        SummaryPath = Join-Path $casePath 'case-summary.html'
        Metadata = $metadata
    }
}

function Get-LazarusCases {
    [CmdletBinding()]
    param([string]$CasesRoot, [string]$StorageRoot)

    if ([string]::IsNullOrWhiteSpace($CasesRoot)) {
        $CasesRoot = Get-LazarusCasesRoot -StorageRoot $StorageRoot
    }
    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($directory in @(Get-ChildItem -LiteralPath $CasesRoot -Directory | Sort-Object Name -Descending)) {
        if ($directory.Name -notmatch '^LK-[0-9]{8}-[0-9]{6}-[0-9A-F]{4}$') { continue }
        try { $results.Add((Get-LazarusCase -CaseId $directory.Name -CasesRoot $CasesRoot)) }
        catch { continue }
    }
    return $results.ToArray()
}

function Add-LazarusCaseActivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CaseId,
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$Details,
        [string]$CasesRoot,
        [string]$StorageRoot
    )

    $case = Get-LazarusCase -CaseId $CaseId -CasesRoot $CasesRoot -StorageRoot $StorageRoot
    $metadata = $case.Metadata
    $activities = @($metadata.activities)
    $activities += [pscustomobject][ordered]@{
        at = (Get-Date).ToString('o')
        action = $Action
        details = $Details
    }
    $metadata.activities = @($activities)
    $metadata.updated_at = (Get-Date).ToString('o')
    Write-LazarusJsonAtomic -InputObject $metadata -Path $case.MetadataPath
    return (Get-LazarusCase -CaseId $CaseId -CasesRoot (Split-Path -Parent $case.Path))
}

function Set-LazarusActiveCase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CaseId,
        [string]$CasesRoot,
        [string]$StorageRoot
    )

    if ([string]::IsNullOrWhiteSpace($CasesRoot)) {
        $CasesRoot = Get-LazarusCasesRoot -StorageRoot $StorageRoot
    }
    $case = Get-LazarusCase -CaseId $CaseId -CasesRoot $CasesRoot
    $pointer = [pscustomobject][ordered]@{
        schema_version = 1
        case_id = $CaseId
        activated_at = (Get-Date).ToString('o')
    }
    Write-LazarusJsonAtomic -InputObject $pointer -Path (Join-Path $CasesRoot '.active-case.json')
    Add-LazarusCaseActivity -CaseId $CaseId -CasesRoot $CasesRoot -Action 'case_activated' -Details 'Case selected as the active workspace.' | Out-Null
    return $case
}

function Clear-LazarusActiveCase {
    [CmdletBinding()]
    param([string]$CasesRoot, [string]$StorageRoot)

    if ([string]::IsNullOrWhiteSpace($CasesRoot)) {
        $CasesRoot = Get-LazarusCasesRoot -StorageRoot $StorageRoot
    }
    $pointerPath = Join-Path $CasesRoot '.active-case.json'
    if (Test-Path -LiteralPath $pointerPath) { Remove-Item -LiteralPath $pointerPath -Force }
}

function Get-LazarusActiveCase {
    [CmdletBinding()]
    param([string]$CasesRoot, [string]$StorageRoot)

    if ([string]::IsNullOrWhiteSpace($CasesRoot)) {
        $CasesRoot = Get-LazarusCasesRoot -StorageRoot $StorageRoot
    }
    $pointerPath = Join-Path $CasesRoot '.active-case.json'
    if (-not (Test-Path -LiteralPath $pointerPath -PathType Leaf)) { return $null }
    try {
        $pointer = Get-Content -LiteralPath $pointerPath -Raw | ConvertFrom-Json
        return (Get-LazarusCase -CaseId ([string]$pointer.case_id) -CasesRoot $CasesRoot)
    }
    catch {
        return $null
    }
}

function New-LazarusCaseWorkspace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Title,
        [string]$TicketNumber,
        [string]$Customer,
        [string]$DeviceName = $env:COMPUTERNAME,
        [string]$Technician,
        [string]$CasesRoot,
        [string]$StorageRoot,
        [switch]$Activate
    )

    if ($Title.Trim().Length -gt 160) { throw 'Case title must be 160 characters or fewer.' }
    if ([string]::IsNullOrWhiteSpace($CasesRoot)) {
        $CasesRoot = Get-LazarusCasesRoot -StorageRoot $StorageRoot
    }
    if ([string]::IsNullOrWhiteSpace($Technician)) {
        try { $Technician = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name }
        catch { $Technician = $env:USERNAME }
    }
    if ([string]::IsNullOrWhiteSpace($Technician)) { $Technician = 'Unknown technician' }

    do {
        $caseId = 'LK-{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N').Substring(0, 4).ToUpperInvariant())
        $casePath = Join-Path $CasesRoot $caseId
    } while (Test-Path -LiteralPath $casePath)

    try {
        foreach ($relative in @('', 'Reports', 'Attachments', 'Safe-Bundles')) {
            $path = if ($relative) { Join-Path $casePath $relative } else { $casePath }
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
        $now = (Get-Date).ToString('o')
        $metadata = [pscustomobject][ordered]@{
            schema_version = $script:CaseSchemaVersion
            case_id = $caseId
            title = $Title.Trim()
            ticket_number = ([string]$TicketNumber).Trim()
            customer = ([string]$Customer).Trim()
            device_name = ([string]$DeviceName).Trim()
            technician = ([string]$Technician).Trim()
            status = 'Open'
            created_at = $now
            updated_at = $now
            activities = @([pscustomobject][ordered]@{
                at = $now
                action = 'case_created'
                details = 'Case workspace created.'
            })
        }
        Write-LazarusJsonAtomic -InputObject $metadata -Path (Join-Path $casePath 'case.json')
        @(
            "# Technician notes - $caseId"
            ''
            'Record observations, approved actions, results, and the final resolution here.'
            ''
        ) | Set-Content -LiteralPath (Join-Path $casePath 'technician-notes.md') -Encoding UTF8
    }
    catch {
        if (Test-Path -LiteralPath $casePath) { Remove-Item -LiteralPath $casePath -Recurse -Force }
        throw
    }

    $case = Get-LazarusCase -CaseId $caseId -CasesRoot $CasesRoot
    if ($Activate) { Set-LazarusActiveCase -CaseId $caseId -CasesRoot $CasesRoot | Out-Null }
    New-LazarusCaseSummary -CaseId $caseId -CasesRoot $CasesRoot | Out-Null
    return (Get-LazarusCase -CaseId $caseId -CasesRoot $CasesRoot)
}

function Set-LazarusCaseStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CaseId,
        [Parameter(Mandatory)][ValidateSet('Open', 'In Progress', 'Resolved', 'Closed')][string]$Status,
        [string]$CasesRoot,
        [string]$StorageRoot
    )

    $case = Get-LazarusCase -CaseId $CaseId -CasesRoot $CasesRoot -StorageRoot $StorageRoot
    $previous = [string]$case.Metadata.status
    $case.Metadata.status = $Status
    $case.Metadata.updated_at = (Get-Date).ToString('o')
    Write-LazarusJsonAtomic -InputObject $case.Metadata -Path $case.MetadataPath
    Add-LazarusCaseActivity -CaseId $CaseId -CasesRoot (Split-Path -Parent $case.Path) `
        -Action 'status_changed' -Details "$previous -> $Status" | Out-Null
    New-LazarusCaseSummary -CaseId $CaseId -CasesRoot (Split-Path -Parent $case.Path) | Out-Null
    return (Get-LazarusCase -CaseId $CaseId -CasesRoot (Split-Path -Parent $case.Path))
}

function Add-LazarusCaseNote {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CaseId,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Note,
        [string]$CasesRoot,
        [string]$StorageRoot
    )

    if ($Note.Trim().Length -gt 8000) { throw 'A single note must be 8,000 characters or fewer.' }
    $case = Get-LazarusCase -CaseId $CaseId -CasesRoot $CasesRoot -StorageRoot $StorageRoot
    @(
        "## $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        ''
        $Note.Trim()
        ''
    ) | Add-Content -LiteralPath $case.NotesPath -Encoding UTF8
    Add-LazarusCaseActivity -CaseId $CaseId -CasesRoot (Split-Path -Parent $case.Path) `
        -Action 'note_added' -Details 'Technician note added.' | Out-Null
    New-LazarusCaseSummary -CaseId $CaseId -CasesRoot (Split-Path -Parent $case.Path) | Out-Null
    return (Get-LazarusCase -CaseId $CaseId -CasesRoot (Split-Path -Parent $case.Path))
}

function New-LazarusCaseReportDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9._-]+$')][string]$ToolName,
        [string]$CaseId,
        [string]$CasesRoot,
        [string]$StorageRoot
    )

    if ([string]::IsNullOrWhiteSpace($CasesRoot)) {
        $CasesRoot = Get-LazarusCasesRoot -StorageRoot $StorageRoot
    }
    $case = if ([string]::IsNullOrWhiteSpace($CaseId)) {
        Get-LazarusActiveCase -CasesRoot $CasesRoot
    }
    else {
        Get-LazarusCase -CaseId $CaseId -CasesRoot $CasesRoot
    }
    if ($null -eq $case) { return $null }

    $safeComputer = if ([string]::IsNullOrWhiteSpace($env:COMPUTERNAME)) { 'UnknownHost' } else { $env:COMPUTERNAME -replace '[^A-Za-z0-9._-]', '_' }
    $runName = '{0}-{1}-{2}' -f $ToolName, $safeComputer, (Get-Date -Format 'yyyyMMdd-HHmmssfff')
    $path = Join-Path $case.ReportsPath $runName
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Add-LazarusCaseActivity -CaseId $case.CaseId -CasesRoot $CasesRoot `
        -Action 'report_started' -Details "$ToolName -> Reports/$runName" | Out-Null
    return $path
}

function New-LazarusCaseSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CaseId,
        [string]$CasesRoot,
        [string]$StorageRoot
    )

    $case = Get-LazarusCase -CaseId $CaseId -CasesRoot $CasesRoot -StorageRoot $StorageRoot
    $encode = { param($Value) [System.Net.WebUtility]::HtmlEncode([string]$Value) }
    $metadata = $case.Metadata
    $reportRows = [System.Collections.Generic.List[string]]::new()
    $reports = @(Get-ChildItem -LiteralPath $case.ReportsPath -File -Recurse | Sort-Object LastWriteTimeUtc -Descending)
    foreach ($file in $reports) {
        $relative = $file.FullName.Substring($case.ReportsPath.Length).TrimStart([char[]]@('\', '/')) -replace '\\', '/'
        $reportRows.Add(('<tr><td>{0}</td><td>{1:N1} KiB</td><td>{2}</td></tr>' -f `
            (& $encode $relative), ($file.Length / 1KB), (& $encode $file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))))
    }
    if ($reportRows.Count -eq 0) { $reportRows.Add('<tr><td colspan="3">No reports collected yet.</td></tr>') }

    $activityRows = [System.Collections.Generic.List[string]]::new()
    foreach ($activity in (@($metadata.activities) | Sort-Object at -Descending)) {
        $activityRows.Add(('<tr><td>{0}</td><td>{1}</td><td>{2}</td></tr>' -f `
            (& $encode ([string]$activity.at)), (& $encode ([string]$activity.action)), (& $encode ([string]$activity.details))))
    }

    $notes = if (Test-Path -LiteralPath $case.NotesPath) { Get-Content -LiteralPath $case.NotesPath -Raw } else { '' }
    $encodedNotes = (& $encode $notes) -replace "(`r`n|`n|`r)", '<br>'
    $html = @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Lazarus Key Case $(& $encode $CaseId)</title>
<style>body{font-family:Segoe UI,Arial,sans-serif;margin:0;background:#090b12;color:#f2f4f7}main{max-width:1100px;margin:auto;padding:32px}.accent{color:#8b7cff}.card{background:#131624;border:1px solid #34384f;border-radius:10px;padding:18px;margin:16px 0}table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:10px;border-bottom:1px solid #34384f;vertical-align:top}th{color:#b7bbc8}.badge{display:inline-block;background:#2a2450;border:1px solid #8b7cff;border-radius:999px;padding:5px 10px}pre{white-space:pre-wrap}.muted{color:#98a2b3}</style></head>
<body><main><h1>LAZARUS KEY <span class="accent">CASE WORKSPACE</span></h1>
<p class="muted">Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
<section class="card"><h2>$(& $encode $metadata.title)</h2><p><span class="badge">$(& $encode $metadata.status)</span></p>
<table><tr><th>Case ID</th><td>$(& $encode $metadata.case_id)</td><th>Ticket</th><td>$(& $encode $metadata.ticket_number)</td></tr>
<tr><th>Customer</th><td>$(& $encode $metadata.customer)</td><th>Device</th><td>$(& $encode $metadata.device_name)</td></tr>
<tr><th>Technician</th><td>$(& $encode $metadata.technician)</td><th>Updated</th><td>$(& $encode $metadata.updated_at)</td></tr></table></section>
<section class="card"><h2>Reports ($($reports.Count))</h2><table><tr><th>Path</th><th>Size</th><th>Modified</th></tr>$($reportRows -join '')</table></section>
<section class="card"><h2>Technician Notes</h2><div>$encodedNotes</div></section>
<section class="card"><h2>Activity</h2><table><tr><th>Time</th><th>Action</th><th>Details</th></tr>$($activityRows -join '')</table></section>
<p class="muted">This local summary may contain sensitive support information. Use Package Handoff before external sharing.</p></main></body></html>
"@
    Set-Content -LiteralPath $case.SummaryPath -Value $html -Encoding UTF8
    return $case.SummaryPath
}

function Test-LazarusCaseWorkspace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CaseId,
        [string]$CasesRoot,
        [string]$StorageRoot,
        [switch]$PassThru
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    try {
        $case = Get-LazarusCase -CaseId $CaseId -CasesRoot $CasesRoot -StorageRoot $StorageRoot
        foreach ($path in @($case.Path, $case.ReportsPath, $case.AttachmentsPath, $case.BundlesPath)) {
            if (-not (Test-Path -LiteralPath $path -PathType Container)) { $errors.Add("Missing directory: $path") }
        }
        foreach ($path in @($case.MetadataPath, $case.NotesPath)) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $errors.Add("Missing file: $path") }
        }
        if (([string]$case.Metadata.status) -notin $script:AllowedStatuses) { $errors.Add('Unsupported case status.') }
        if (@($case.Metadata.activities).Count -lt 1) { $errors.Add('Case activity history is empty.') }
    }
    catch { $errors.Add($_.Exception.Message) }

    $result = [pscustomobject][ordered]@{
        Valid = ($errors.Count -eq 0)
        CaseId = $CaseId
        Errors = $errors.ToArray()
    }
    if ($PassThru) { return $result }
    if (-not $result.Valid) { throw ($result.Errors -join '; ') }
    Write-Host "Case workspace validation passed: $CaseId" -ForegroundColor Green
}

Export-ModuleMember -Function Resolve-LazarusStorageRoot, Get-LazarusCasesRoot, Get-LazarusCase, `
    Get-LazarusCases, New-LazarusCaseWorkspace, Get-LazarusActiveCase, Set-LazarusActiveCase, `
    Clear-LazarusActiveCase, Add-LazarusCaseActivity, Add-LazarusCaseNote, Set-LazarusCaseStatus, `
    New-LazarusCaseReportDirectory, New-LazarusCaseSummary, Test-LazarusCaseWorkspace
