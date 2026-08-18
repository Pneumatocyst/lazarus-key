[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $projectRoot 'tools\portable-tools'
$catalogValidator = Join-Path $toolRoot 'Test-PortableToolsCatalog.ps1'
$installer = Join-Path $toolRoot 'Install-PortableTool.ps1'
$installedValidator = Join-Path $toolRoot 'Test-InstalledPortableTools.ps1'
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "LazarusPortableTest-$([guid]::NewGuid().ToString('N'))"
$payload = Join-Path $temporaryRoot 'payload'
$archive = Join-Path $temporaryRoot 'fixture-tool.zip'
$catalogPath = Join-Path $temporaryRoot 'portable-tools.json'
$destination = Join-Path $temporaryRoot 'PortableTools'

try {
    New-Item -ItemType Directory -Path $payload -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $payload 'fixture-tool.cmd') -Value '@echo fixture' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $payload 'README.txt') -Value 'Synthetic fixture only.' -Encoding ASCII
    Compress-Archive -Path (Join-Path $payload '*') -DestinationPath $archive -Force
    $archiveItem = Get-Item -LiteralPath $archive
    $archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()

    $catalog = [pscustomobject][ordered]@{
        schema_version = 1
        project_version = '0.4.0-test'
        updated = '2026-08-18'
        policy = [pscustomobject][ordered]@{
            redistribute_binaries = $false
            require_https = $true
            require_sha256 = $true
            notes = 'Synthetic offline test.'
        }
        tools = @([pscustomobject][ordered]@{
            id = 'fixture-tool'
            name = 'Fixture Tool'
            version = '1.0.0'
            category = 'Test'
            description = 'Synthetic CI fixture.'
            architecture = 'x64'
            default_selected = $false
            homepage = 'https://example.invalid/'
            download_page = 'https://example.invalid/downloads/'
            download_url = 'https://example.invalid/fixture-tool.zip'
            allowed_hosts = @('example.invalid')
            archive_type = 'zip'
            archive_name = 'fixture-tool.zip'
            archive_size_bytes = $archiveItem.Length
            installed_size_estimate_bytes = 4096
            sha256 = $archiveHash
            install_directory = 'FixtureTool'
            strip_single_root = $false
            license = [pscustomobject][ordered]@{
                spdx = 'MIT'
                name = 'Synthetic MIT fixture'
                url = 'https://example.invalid/license'
                redistribution = 'Synthetic fixture only.'
            }
            verification = [pscustomobject][ordered]@{
                authenticode_required = $false
                publisher_contains = $null
            }
            launchers = @([pscustomobject][ordered]@{
                name = 'Fixture Tool'
                path = 'fixture-tool.cmd'
                requires_admin = $false
            })
        })
    }
    $catalog | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $catalogPath -Encoding UTF8

    $catalogCheck = & $catalogValidator -CatalogPath $catalogPath -PassThru
    Assert-True $catalogCheck.Valid ('Synthetic catalog failed: ' + ($catalogCheck.Errors -join '; '))

    $licenseBlocked = $false
    try {
        & $installer -ToolId fixture-tool -CatalogPath $catalogPath -DestinationRoot $destination `
            -ArchivePath $archive -PassThru | Out-Null
    }
    catch { $licenseBlocked = $_.Exception.Message -like '*AcceptLicense*' }
    Assert-True $licenseBlocked 'Installer did not require explicit license acceptance.'

    $result = @(& $installer -ToolId fixture-tool -CatalogPath $catalogPath -DestinationRoot $destination `
        -ArchivePath $archive -AcceptLicense -PassThru)
    Assert-True ($result.Count -eq 1) 'Installer returned an unexpected result count.'
    Assert-True (Test-Path -LiteralPath (Join-Path $destination 'FixtureTool\fixture-tool.cmd')) 'Fixture launcher was not installed.'
    Assert-True (Test-Path -LiteralPath (Join-Path $destination 'FixtureTool\.lazarus-tool.json')) 'Installation receipt was not created.'

    $installedCheck = @(& $installedValidator -CatalogPath $catalogPath -DestinationRoot $destination -PassThru)
    Assert-True ($installedCheck.Count -eq 1 -and $installedCheck[0].Status -eq 'Valid') 'Installed-tool verification failed.'

    Set-Content -LiteralPath (Join-Path $destination 'FixtureTool\obsolete.txt') -Value 'remove on managed update' -Encoding ASCII
    & $installer -ToolId fixture-tool -CatalogPath $catalogPath -DestinationRoot $destination `
        -ArchivePath $archive -AcceptLicense -Force -PassThru | Out-Null
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $destination 'FixtureTool\obsolete.txt'))) 'Forced update left stale managed files behind.'

    $catalog.tools[0].sha256 = ('0' * 64)
    $catalog | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $catalogPath -Encoding UTF8
    $hashBlocked = $false
    try {
        & $installer -ToolId fixture-tool -CatalogPath $catalogPath -DestinationRoot $destination `
            -ArchivePath $archive -AcceptLicense -Force -PassThru | Out-Null
    }
    catch { $hashBlocked = $_.Exception.Message -like '*SHA-256 mismatch*' }
    Assert-True $hashBlocked 'Installer did not fail closed on a bad archive hash.'

    Write-Host 'Portable Tools tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) { Remove-Item -LiteralPath $temporaryRoot -Recurse -Force }
}
