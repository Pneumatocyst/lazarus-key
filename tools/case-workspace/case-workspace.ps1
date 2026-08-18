[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$modulePath = Join-Path $PSScriptRoot 'LazarusCase.psm1'
$handoffScript = Join-Path $PSScriptRoot 'New-LazarusCaseHandoff.ps1'
Import-Module $modulePath -Force
$casesRoot = Get-LazarusCasesRoot

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Lazarus Key - Case Workspace'
$form.Size = New-Object System.Drawing.Size(1050, 720)
$form.MinimumSize = New-Object System.Drawing.Size(960, 650)
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::FromArgb(9, 11, 18)
$form.ForeColor = [System.Drawing.Color]::FromArgb(242, 244, 247)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'LAZARUS KEY - CASE WORKSPACE'
$title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 20)
$title.ForeColor = [System.Drawing.Color]::White
$title.Location = New-Object System.Drawing.Point(24, 18)
$title.AutoSize = $true
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'Organize reports, technician notes, activity, and sanitized handoffs'
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(139, 124, 255)
$subtitle.Location = New-Object System.Drawing.Point(28, 58)
$subtitle.AutoSize = $true
$form.Controls.Add($subtitle)

$activeLabel = New-Object System.Windows.Forms.Label
$activeLabel.Location = New-Object System.Drawing.Point(28, 87)
$activeLabel.Size = New-Object System.Drawing.Size(980, 24)
$activeLabel.ForeColor = [System.Drawing.Color]::FromArgb(152, 162, 179)
$form.Controls.Add($activeLabel)

$caseList = New-Object System.Windows.Forms.ListView
$caseList.Location = New-Object System.Drawing.Point(28, 118)
$caseList.Size = New-Object System.Drawing.Size(980, 330)
$caseList.Anchor = 'Top,Bottom,Left,Right'
$caseList.View = 'Details'
$caseList.FullRowSelect = $true
$caseList.MultiSelect = $false
$caseList.HideSelection = $false
$caseList.BackColor = [System.Drawing.Color]::FromArgb(19, 22, 36)
$caseList.ForeColor = [System.Drawing.Color]::White
$caseList.BorderStyle = 'FixedSingle'
[void]$caseList.Columns.Add('Case ID', 205)
[void]$caseList.Columns.Add('Title', 235)
[void]$caseList.Columns.Add('Ticket', 120)
[void]$caseList.Columns.Add('Device', 125)
[void]$caseList.Columns.Add('Status', 105)
[void]$caseList.Columns.Add('Updated', 160)
$form.Controls.Add($caseList)

function New-Button {
    param([string]$Text, [int]$X, [int]$Y, [int]$Width = 145)
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, 38)
    $button.Anchor = 'Bottom,Left'
    $button.FlatStyle = 'Flat'
    $button.BackColor = [System.Drawing.Color]::FromArgb(29, 32, 51)
    $button.ForeColor = [System.Drawing.Color]::White
    $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(52, 56, 79)
    $form.Controls.Add($button)
    return $button
}

$newButton = New-Button -Text 'New Case' -X 28 -Y 465 -Width 130
$activateButton = New-Button -Text 'Set Active' -X 168 -Y 465 -Width 130
$clearButton = New-Button -Text 'Clear Active' -X 308 -Y 465 -Width 130
$noteButton = New-Button -Text 'Add Note' -X 448 -Y 465 -Width 130
$statusButton = New-Button -Text 'Update Status' -X 588 -Y 465 -Width 140
$summaryButton = New-Button -Text 'Open Summary' -X 738 -Y 465 -Width 140
$folderButton = New-Button -Text 'Open Folder' -X 888 -Y 465 -Width 120

$packageButton = New-Button -Text 'Package Strict Handoff' -X 28 -Y 518 -Width 220
$refreshButton = New-Button -Text 'Refresh' -X 258 -Y 518 -Width 120
$closeButton = New-Button -Text 'Close' -X 888 -Y 518 -Width 120
$closeButton.Anchor = 'Bottom,Right'

$statusText = New-Object System.Windows.Forms.Label
$statusText.Location = New-Object System.Drawing.Point(28, 580)
$statusText.Size = New-Object System.Drawing.Size(980, 55)
$statusText.Anchor = 'Bottom,Left,Right'
$statusText.ForeColor = [System.Drawing.Color]::FromArgb(152, 162, 179)
$statusText.Text = "Cases: $casesRoot"
$form.Controls.Add($statusText)

function Show-InputDialog {
    param([string]$Prompt, [string]$Caption, [string]$DefaultValue = '', [switch]$Multiline)
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = $Caption
    $dialog.Size = if ($Multiline) { New-Object System.Drawing.Size(560, 330) } else { New-Object System.Drawing.Size(560, 180) }
    $dialog.StartPosition = 'CenterParent'
    $dialog.BackColor = [System.Drawing.Color]::FromArgb(19, 22, 36)
    $dialog.ForeColor = [System.Drawing.Color]::White
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Prompt
    $label.Location = New-Object System.Drawing.Point(16, 16)
    $label.Size = New-Object System.Drawing.Size(510, 40)
    $dialog.Controls.Add($label)
    $box = New-Object System.Windows.Forms.TextBox
    $box.Text = $DefaultValue
    $box.Location = New-Object System.Drawing.Point(18, 58)
    $box.Size = if ($Multiline) { New-Object System.Drawing.Size(505, 175) } else { New-Object System.Drawing.Size(505, 28) }
    $box.Multiline = [bool]$Multiline
    $box.ScrollBars = if ($Multiline) { 'Vertical' } else { 'None' }
    $dialog.Controls.Add($box)
    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'OK'
    $ok.DialogResult = 'OK'
    $ok.Location = if ($Multiline) { New-Object System.Drawing.Point(350, 245) } else { New-Object System.Drawing.Point(350, 95) }
    $dialog.Controls.Add($ok)
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.DialogResult = 'Cancel'
    $cancel.Location = if ($Multiline) { New-Object System.Drawing.Point(440, 245) } else { New-Object System.Drawing.Point(440, 95) }
    $dialog.Controls.Add($cancel)
    $dialog.AcceptButton = $ok
    $dialog.CancelButton = $cancel
    if ($dialog.ShowDialog($form) -eq 'OK') { return $box.Text }
    return $null
}

function Get-SelectedCase {
    if ($caseList.SelectedItems.Count -ne 1) { return $null }
    return (Get-LazarusCase -CaseId ([string]$caseList.SelectedItems[0].Tag) -CasesRoot $casesRoot)
}

function Refresh-Cases {
    $selectedId = if ($caseList.SelectedItems.Count -eq 1) { [string]$caseList.SelectedItems[0].Tag } else { $null }
    $caseList.Items.Clear()
    $active = Get-LazarusActiveCase -CasesRoot $casesRoot
    $activeLabel.Text = if ($active) { "Active case: $($active.CaseId) - $($active.Metadata.title)" } else { 'Active case: none (reports use the normal Reports folder)' }
    foreach ($case in @(Get-LazarusCases -CasesRoot $casesRoot)) {
        $marker = if ($active -and $active.CaseId -eq $case.CaseId) { '* ' } else { '' }
        $item = New-Object System.Windows.Forms.ListViewItem("$marker$($case.CaseId)")
        [void]$item.SubItems.Add([string]$case.Metadata.title)
        [void]$item.SubItems.Add([string]$case.Metadata.ticket_number)
        [void]$item.SubItems.Add([string]$case.Metadata.device_name)
        [void]$item.SubItems.Add([string]$case.Metadata.status)
        $updated = try { ([datetime]$case.Metadata.updated_at).ToString('yyyy-MM-dd HH:mm') } catch { [string]$case.Metadata.updated_at }
        [void]$item.SubItems.Add($updated)
        $item.Tag = $case.CaseId
        [void]$caseList.Items.Add($item)
        if ($selectedId -eq $case.CaseId) { $item.Selected = $true }
    }
    $statusText.Text = "Cases: $casesRoot  |  $($caseList.Items.Count) workspace(s)"
}

$newButton.Add_Click({
    try {
        $caseTitle = Show-InputDialog -Prompt 'Case title (required):' -Caption 'New Lazarus Case'
        if ([string]::IsNullOrWhiteSpace($caseTitle)) { return }
        $ticket = Show-InputDialog -Prompt 'Ticket number (optional):' -Caption 'New Lazarus Case'
        if ($null -eq $ticket) { return }
        $customer = Show-InputDialog -Prompt 'Customer or owner (optional; stored locally):' -Caption 'New Lazarus Case'
        if ($null -eq $customer) { return }
        $device = Show-InputDialog -Prompt 'Device name (optional):' -Caption 'New Lazarus Case' -DefaultValue $env:COMPUTERNAME
        if ($null -eq $device) { return }
        $case = New-LazarusCaseWorkspace -Title $caseTitle -TicketNumber $ticket -Customer $customer `
            -DeviceName $device -CasesRoot $casesRoot -Activate
        $statusText.Text = "Created and activated $($case.CaseId). New reports will route into this case."
        Refresh-Cases
    }
    catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Lazarus Key', 'OK', 'Error') | Out-Null }
})

$activateButton.Add_Click({
    $case = Get-SelectedCase
    if (-not $case) { [System.Windows.Forms.MessageBox]::Show('Select one case first.', 'Lazarus Key', 'OK', 'Information') | Out-Null; return }
    Set-LazarusActiveCase -CaseId $case.CaseId -CasesRoot $casesRoot | Out-Null
    Refresh-Cases
})

$clearButton.Add_Click({ Clear-LazarusActiveCase -CasesRoot $casesRoot; Refresh-Cases })
$noteButton.Add_Click({
    $case = Get-SelectedCase
    if (-not $case) { [System.Windows.Forms.MessageBox]::Show('Select one case first.', 'Lazarus Key', 'OK', 'Information') | Out-Null; return }
    $note = Show-InputDialog -Prompt 'Technician note:' -Caption "Add Note - $($case.CaseId)" -Multiline
    if (-not [string]::IsNullOrWhiteSpace($note)) { Add-LazarusCaseNote -CaseId $case.CaseId -CasesRoot $casesRoot -Note $note | Out-Null; Refresh-Cases }
})

$statusButton.Add_Click({
    $case = Get-SelectedCase
    if (-not $case) { [System.Windows.Forms.MessageBox]::Show('Select one case first.', 'Lazarus Key', 'OK', 'Information') | Out-Null; return }
    $choice = Show-InputDialog -Prompt 'Enter: Open, In Progress, Resolved, or Closed' -Caption "Update Status - $($case.CaseId)" -DefaultValue ([string]$case.Metadata.status)
    if ($null -eq $choice) { return }
    if ($choice -notin @('Open', 'In Progress', 'Resolved', 'Closed')) { [System.Windows.Forms.MessageBox]::Show('Use one of the four listed statuses.', 'Lazarus Key', 'OK', 'Warning') | Out-Null; return }
    Set-LazarusCaseStatus -CaseId $case.CaseId -CasesRoot $casesRoot -Status $choice | Out-Null
    Refresh-Cases
})

$summaryButton.Add_Click({
    $case = Get-SelectedCase
    if (-not $case) { [System.Windows.Forms.MessageBox]::Show('Select one case first.', 'Lazarus Key', 'OK', 'Information') | Out-Null; return }
    $summary = New-LazarusCaseSummary -CaseId $case.CaseId -CasesRoot $casesRoot
    Start-Process $summary
})

$folderButton.Add_Click({
    $case = Get-SelectedCase
    if (-not $case) { [System.Windows.Forms.MessageBox]::Show('Select one case first.', 'Lazarus Key', 'OK', 'Information') | Out-Null; return }
    Start-Process explorer.exe -ArgumentList $case.Path
})

$packageButton.Add_Click({
    $case = Get-SelectedCase
    if (-not $case) { [System.Windows.Forms.MessageBox]::Show('Select one case first.', 'Lazarus Key', 'OK', 'Information') | Out-Null; return }
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        'Create a Strict sanitized handoff? Case title, ticket, customer, device identity, and normal report identifiers will be redacted. Review the ZIP before sharing.',
        'Lazarus Key - Package Handoff', 'YesNo', 'Warning')
    if ($confirm -ne 'Yes') { return }
    try {
        $packageButton.Enabled = $false
        $statusText.Text = 'Building and verifying sanitized case handoff...'
        [System.Windows.Forms.Application]::DoEvents()
        $bundle = & $handoffScript -CaseId $case.CaseId -CasesRoot $casesRoot -Profile Strict -PassThru
        $statusText.Text = "Handoff created: $($bundle.BundlePath)"
        Start-Process explorer.exe -ArgumentList $case.BundlesPath
        [System.Windows.Forms.MessageBox]::Show("Strict handoff created.`r`n`r`n$($bundle.BundlePath)`r`n`r`nReview it before sharing.", 'Lazarus Key', 'OK', 'Information') | Out-Null
        Refresh-Cases
    }
    catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Lazarus Key', 'OK', 'Error') | Out-Null }
    finally { $packageButton.Enabled = $true }
})

$refreshButton.Add_Click({ Refresh-Cases })
$closeButton.Add_Click({ $form.Close() })
$caseList.Add_DoubleClick({
    $case = Get-SelectedCase
    if ($case) { Set-LazarusActiveCase -CaseId $case.CaseId -CasesRoot $casesRoot | Out-Null; Refresh-Cases }
})

Refresh-Cases
[void]$form.ShowDialog()

