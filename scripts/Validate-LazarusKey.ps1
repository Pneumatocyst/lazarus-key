[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rootPath = (Resolve-Path -LiteralPath $Root).Path
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Test-RequiredFile {
    param([Parameter(Mandatory)][string]$RelativePath)
    $path = Join-Path $rootPath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("Missing required project file: $RelativePath")
        return $false
    }
    return $true
}

Write-Host "Validating Lazarus Key at $rootPath" -ForegroundColor Cyan

$projectFiles = @(
    'ventoy\ventoy.json',
    'ventoy\theme\lazarus\theme.txt',
    'ventoy\theme\lazarus\background.png',
    'Launcher\LazarusKey.ps1',
    'Launcher\Launch-LazarusKey.cmd',
    'Scripts\System-Info-Collector\Get-SystemReport.ps1',
    'Scripts\System-Info-Collector\system-info.ps1',
    'Scripts\System-Info-Collector\system-report.sh',
    'Scripts\Network-Troubleshooter\Test-NetworkConnection.ps1',
    'Scripts\Network-Troubleshooter\network-troubleshooter.ps1',
    'Scripts\Network-Troubleshooter\network-test.sh',
    'Documentation\images.json'
)

foreach ($file in $projectFiles) {
    [void](Test-RequiredFile -RelativePath $file)
}

$ventoyJsonPath = Join-Path $rootPath 'ventoy\ventoy.json'
if (Test-Path -LiteralPath $ventoyJsonPath) {
    try {
        $ventoy = Get-Content -LiteralPath $ventoyJsonPath -Raw | ConvertFrom-Json
        if (-not $ventoy.theme.file) {
            $errors.Add('Ventoy theme.file is not configured.')
        }
        else {
            $themeRelative = $ventoy.theme.file.TrimStart('/') -replace '/', '\'
            if (-not (Test-Path -LiteralPath (Join-Path $rootPath $themeRelative))) {
                $errors.Add("Ventoy theme target is missing: $($ventoy.theme.file)")
            }
        }
    }
    catch {
        $errors.Add("ventoy.json is invalid: $($_.Exception.Message)")
    }
}

$manifestPath = Join-Path $rootPath 'Documentation\images.json'
if (Test-Path -LiteralPath $manifestPath) {
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        foreach ($image in $manifest.images) {
            $relativePath = $image.destination -replace '/', '\'
            $imagePath = Join-Path $rootPath $relativePath
            if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) {
                $warnings.Add("ISO not installed: $($image.name) -> $relativePath")
                continue
            }

            Write-Host "Hashing $($image.name)..." -ForegroundColor DarkCyan
            $actual = (Get-FileHash -LiteralPath $imagePath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actual -ne $image.sha256.ToLowerInvariant()) {
                $errors.Add("SHA-256 mismatch: $relativePath")
            }
            else {
                Write-Host "  PASS  $relativePath" -ForegroundColor Green
            }
        }
    }
    catch {
        $errors.Add("Image manifest is invalid: $($_.Exception.Message)")
    }
}

foreach ($warning in $warnings) {
    Write-Warning $warning
}

if ($errors.Count -gt 0) {
    foreach ($validationError in $errors) {
        Write-Host "ERROR: $validationError" -ForegroundColor Red
    }
    Write-Host "Validation failed with $($errors.Count) error(s) and $($warnings.Count) warning(s)." -ForegroundColor Red
    exit 1
}

Write-Host "Validation passed with $($warnings.Count) warning(s)." -ForegroundColor Green
if ($warnings.Count -gt 0) {
    Write-Host 'The project structure is valid, but the warned ISO images must be added before physical boot testing.' -ForegroundColor Yellow
}
