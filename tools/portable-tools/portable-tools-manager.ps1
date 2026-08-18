[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$baseRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$catalogPath = Join-Path $baseRoot 'Documentation\portable-tools.json'
if (-not (Test-Path -LiteralPath $catalogPath)) {
    $catalogPath = Join-Path $baseRoot 'manifests\portable-tools.json'
}
$destinationRoot = Join-Path $baseRoot 'PortableTools'
$installer = Join-Path $PSScriptRoot 'Install-PortableTool.ps1'
$verifier = Join-Path $PSScriptRoot 'Test-InstalledPortableTools.ps1'

try {
    $catalogCheck = & (Join-Path $PSScriptRoot 'Test-PortableToolsCatalog.ps1') -CatalogPath $catalogPath -PassThru
    if (-not $catalogCheck.Valid) { throw "Catalog validation failed: $($catalogCheck.Errors -join '; ')" }
    $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        $_.Exception.Message, 'Lazarus Key - Portable Tools',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    return
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Lazarus Key - Portable Tools Manager'
$form.Size = New-Object System.Drawing.Size(920, 650)
$form.MinimumSize = New-Object System.Drawing.Size(820, 560)
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::FromArgb(9, 11, 18)
$form.ForeColor = [System.Drawing.Color]::FromArgb(242, 244, 247)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'LAZARUS KEY - PORTABLE TOOLS'
$title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 20)
$title.ForeColor = [System.Drawing.Color]::White
$title.Location = New-Object System.Drawing.Point(24, 18)
$title.AutoSize = $true
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'Official-source downloads with pinned SHA-256 verification'
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(139, 124, 255)
$subtitle.Location = New-Object System.Drawing.Point(28, 58)
$subtitle.AutoSize = $true
$form.Controls.Add($subtitle)

$toolList = New-Object System.Windows.Forms.CheckedListBox
$toolList.CheckOnClick = $true
$toolList.Location = New-Object System.Drawing.Point(28, 94)
$toolList.Size = New-Object System.Drawing.Size(390, 390)
$toolList.Anchor = 'Top,Bottom,Left'
$toolList.BackColor = [System.Drawing.Color]::FromArgb(29, 32, 51)
$toolList.ForeColor = [System.Drawing.Color]::White
$toolList.BorderStyle = 'FixedSingle'

foreach ($tool in @($catalog.tools)) {
    $sizeMiB = [math]::Round([long]$tool.archive_size_bytes / 1MB, 1)
    $index = $toolList.Items.Add("$($tool.name)  v$($tool.version)  [$sizeMiB MiB]")
    if ($tool.default_selected) { $toolList.SetItemChecked($index, $true) }
}
$form.Controls.Add($toolList)

$details = New-Object System.Windows.Forms.TextBox
$details.Location = New-Object System.Drawing.Point(440, 94)
$details.Size = New-Object System.Drawing.Size(440, 390)
$details.Anchor = 'Top,Bottom,Left,Right'
$details.Multiline = $true
$details.ReadOnly = $true
$details.ScrollBars = 'Vertical'
$details.BackColor = [System.Drawing.Color]::FromArgb(19, 22, 36)
$details.ForeColor = [System.Drawing.Color]::FromArgb(220, 223, 232)
$details.BorderStyle = 'FixedSingle'
$form.Controls.Add($details)

$status = New-Object System.Windows.Forms.Label
$status.Text = 'Ready. Select tools, review their licenses, then install.'
$status.Location = New-Object System.Drawing.Point(28, 496)
$status.Size = New-Object System.Drawing.Size(852, 24)
$status.Anchor = 'Bottom,Left,Right'
$status.ForeColor = [System.Drawing.Color]::FromArgb(152, 162, 179)
$form.Controls.Add($status)

function New-ActionButton {
    param([string]$Text, [int]$X, [int]$Width)
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, 532)
    $button.Size = New-Object System.Drawing.Size($Width, 42)
    $button.Anchor = 'Bottom,Left'
    $button.FlatStyle = 'Flat'
    $button.BackColor = [System.Drawing.Color]::FromArgb(29, 32, 51)
    $button.ForeColor = [System.Drawing.Color]::White
    $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(52, 56, 79)
    $form.Controls.Add($button)
    return $button
}

$installButton = New-ActionButton -Text 'Install / Update Selected' -X 28 -Width 210
$verifyButton = New-ActionButton -Text 'Verify Installed' -X 250 -Width 150
$launchButton = New-ActionButton -Text 'Launch Primary' -X 412 -Width 145
$openButton = New-ActionButton -Text 'Open Tool Folder' -X 569 -Width 145
$closeButton = New-ActionButton -Text 'Close' -X 726 -Width 154
$closeButton.Anchor = 'Bottom,Right'

function Get-SelectedTool {
    if ($toolList.SelectedIndex -lt 0) { return $null }
    return @($catalog.tools)[$toolList.SelectedIndex]
}

function Update-Details {
    $tool = Get-SelectedTool
    if (-not $tool) {
        $details.Text = 'Select a tool to view its purpose, source, license, launchers, and installation status.'
        return
    }
    $directory = Join-Path $destinationRoot ([string]$tool.install_directory)
    $installed = if (Test-Path -LiteralPath $directory) { 'Installed (verify before use)' } else { 'Not installed' }
    $launcherNames = @($tool.launchers | ForEach-Object { $_.name }) -join ', '
    $details.Text = @"
$($tool.name)  v$($tool.version)

Category: $($tool.category)
Architecture: $($tool.architecture)
Status: $installed

$($tool.description)

Launchers: $launcherNames

License: $($tool.license.name)
License ID: $($tool.license.spdx)
$($tool.license.redistribution)
License URL: $($tool.license.url)

Official page:
$($tool.download_page)

Pinned SHA-256:
$($tool.sha256)

Downloads are never executed automatically. Tools that alter disks or system state require deliberate technician action and authorization.
"@
}

$toolList.Add_SelectedIndexChanged({ Update-Details })
$closeButton.Add_Click({ $form.Close() })
$openButton.Add_Click({
    if (-not (Test-Path -LiteralPath $destinationRoot)) { New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null }
    Start-Process explorer.exe -ArgumentList $destinationRoot
})

$verifyButton.Add_Click({
    try {
        $status.Text = 'Verifying installed tools...'
        [System.Windows.Forms.Application]::DoEvents()
        $results = @(& $verifier -CatalogPath $catalogPath -DestinationRoot $destinationRoot -PassThru)
        $valid = @($results | Where-Object Status -eq 'Valid').Count
        $invalid = @($results | Where-Object Status -eq 'Invalid').Count
        $missing = @($results | Where-Object Status -eq 'NotInstalled').Count
        $status.Text = "Verification complete: $valid valid, $invalid invalid, $missing not installed."
        $icon = if ($invalid -eq 0) { [System.Windows.Forms.MessageBoxIcon]::Information } else { [System.Windows.Forms.MessageBoxIcon]::Warning }
        [System.Windows.Forms.MessageBox]::Show($status.Text, 'Lazarus Key', 'OK', $icon) | Out-Null
        Update-Details
    }
    catch {
        $status.Text = "Verification failed: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($status.Text, 'Lazarus Key', 'OK', 'Error') | Out-Null
    }
})

$launchButton.Add_Click({
    try {
        $tool = Get-SelectedTool
        if (-not $tool) { throw 'Select one tool first.' }
        $primary = @($tool.launchers)[0]
        $path = Join-Path (Join-Path $destinationRoot ([string]$tool.install_directory)) ([string]$primary.path)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'The selected tool is not installed or its primary launcher is missing.' }
        if ($primary.requires_admin) { Start-Process -FilePath $path -Verb RunAs } else { Start-Process -FilePath $path }
        $status.Text = "Launched $($primary.name)."
    }
    catch {
        $status.Text = $_.Exception.Message
        [System.Windows.Forms.MessageBox]::Show($status.Text, 'Lazarus Key', 'OK', 'Warning') | Out-Null
    }
})

$installButton.Add_Click({
    $selectedIndices = @($toolList.CheckedIndices)
    if ($selectedIndices.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Select at least one tool.', 'Lazarus Key', 'OK', 'Information') | Out-Null
        return
    }
    $selectedTools = @($selectedIndices | ForEach-Object { @($catalog.tools)[$_] })
    $downloadMiB = [math]::Round((($selectedTools | Measure-Object archive_size_bytes -Sum).Sum / 1MB), 1)
    $names = ($selectedTools | ForEach-Object { "- $($_.name) $($_.version): $($_.license.name)" }) -join "`r`n"
    $confirmation = "Download approximately $downloadMiB MiB from official upstream sources?`r`n`r`n$names`r`n`r`nSelecting YES confirms that you reviewed and accept the listed upstream licenses. Existing installations will require a separate replacement confirmation."
    if ([System.Windows.Forms.MessageBox]::Show($confirmation, 'Lazarus Key - License confirmation', 'YesNo', 'Warning') -ne 'Yes') { return }

    $installButton.Enabled = $false
    $failures = [System.Collections.Generic.List[string]]::new()
    try {
        foreach ($tool in $selectedTools) {
            $forceTool = $false
            $existing = Join-Path $destinationRoot ([string]$tool.install_directory)
            if (Test-Path -LiteralPath $existing) {
                $replace = [System.Windows.Forms.MessageBox]::Show(
                    "$($tool.name) is already installed. Replace its entire managed folder?",
                    'Lazarus Key', 'YesNo', 'Question'
                )
                if ($replace -ne 'Yes') { continue }
                $forceTool = $true
            }
            try {
                $status.Text = "Downloading and verifying $($tool.name)..."
                [System.Windows.Forms.Application]::DoEvents()
                & $installer -ToolId $tool.id -CatalogPath $catalogPath -DestinationRoot $destinationRoot `
                    -AcceptLicense -Force:$forceTool | Out-Null
                $status.Text = "Installed $($tool.name)."
            }
            catch { $failures.Add("$($tool.name): $($_.Exception.Message)") }
        }
        Update-Details
        if ($failures.Count -eq 0) {
            $status.Text = 'Selected tools completed successfully.'
            [System.Windows.Forms.MessageBox]::Show($status.Text, 'Lazarus Key', 'OK', 'Information') | Out-Null
        }
        else {
            $status.Text = "Completed with $($failures.Count) failure(s)."
            [System.Windows.Forms.MessageBox]::Show(($failures -join "`r`n`r`n"), 'Lazarus Key', 'OK', 'Error') | Out-Null
        }
    }
    finally { $installButton.Enabled = $true }
})

$toolList.SelectedIndex = 0
[void]$form.ShowDialog()
