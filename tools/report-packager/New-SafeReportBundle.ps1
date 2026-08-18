[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$SourceDirectory,

    [string]$OutputDirectory,

    [ValidateSet('Standard', 'Strict')]
    [string]$Profile = 'Standard',

    [string[]]$CustomPattern = @(),

    [switch]$KeepStaging,

    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ToolVersion = '0.3.0'
$allowedExtensions = @('.txt', '.log', '.json', '.csv')

function Get-RedactionRules {
    param(
        [Parameter(Mandatory)][string]$SelectedProfile,
        [string[]]$AdditionalPatterns
    )

    $rules = [System.Collections.Generic.List[object]]::new()
    $rules.Add([pscustomobject]@{
        Name = 'windows_user_path'
        Pattern = '(?i)(?<=\\Users\\)[^\\\r\n,"]+'
        Replacement = '[REDACTED-USER]'
    })
    $rules.Add([pscustomobject]@{
        Name = 'account_field'
        Pattern = '(?im)(\b(?:current user|user(?:name)?|account)\s*[:=]\s*)[^\r\n,]+'
        Replacement = '$1[REDACTED-ACCOUNT]'
    })
    $rules.Add([pscustomobject]@{
        Name = 'domain_account'
        Pattern = '(?i)\b[A-Z0-9._-]+\\[A-Z0-9._ -]+\b'
        Replacement = '[REDACTED-ACCOUNT]'
    })
    $rules.Add([pscustomobject]@{
        Name = 'json_account_value'
        Pattern = '(?i)("(?:CurrentUser|current_user|username|user|account)"\s*:\s*")[^"]*'
        Replacement = '$1[REDACTED-ACCOUNT]'
    })
    $rules.Add([pscustomobject]@{
        Name = 'computer_name_field'
        Pattern = '(?im)(\b(?:computer(?: name)?|hostname|host name)\s*[:=]\s*)[^\r\n,|]+'
        Replacement = '$1[REDACTED-HOST]'
    })
    $rules.Add([pscustomobject]@{
        Name = 'json_computer_name_value'
        Pattern = '(?i)("(?:ComputerName|computer_name|hostname|host_name)"\s*:\s*")[^"]*'
        Replacement = '$1[REDACTED-HOST]'
    })
    $rules.Add([pscustomobject]@{
        Name = 'serial_field'
        Pattern = '(?im)(\b(?:serial(?: number)?|service tag|uniqueid)\s*[:=]\s*)[^\r\n,|]+'
        Replacement = '$1[REDACTED-SERIAL]'
    })
    $rules.Add([pscustomobject]@{
        Name = 'json_serial_value'
        Pattern = '(?i)("(?:SerialNumber|serial_number|serial|ServiceTag|service_tag|UniqueId|unique_id)"\s*:\s*")[^"]*'
        Replacement = '$1[REDACTED-SERIAL]'
    })
    $rules.Add([pscustomobject]@{
        Name = 'email_address'
        Pattern = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'
        Replacement = '[REDACTED-EMAIL]'
    })
    $rules.Add([pscustomobject]@{
        Name = 'mac_address'
        Pattern = '(?i)\b(?:[0-9A-F]{2}[:-]){5}[0-9A-F]{2}\b'
        Replacement = '[REDACTED-MAC]'
    })
    $rules.Add([pscustomobject]@{
        Name = 'ipv4_address'
        Pattern = '\b(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)\b'
        Replacement = '[REDACTED-IPV4]'
    })
    $rules.Add([pscustomobject]@{
        Name = 'compressed_ipv6_address'
        Pattern = '(?i)(?<![0-9A-F:])(?:[0-9A-F]{1,4}:){1,7}:(?:[0-9A-F]{1,4})?(?![0-9A-F:])'
        Replacement = '[REDACTED-IPV6]'
    })
    $rules.Add([pscustomobject]@{
        Name = 'ipv6_address'
        Pattern = '(?i)(?<![0-9A-F:])(?:[0-9A-F]{1,4}:){2,7}[0-9A-F]{0,4}(?![0-9A-F:])'
        Replacement = '[REDACTED-IPV6]'
    })

    if ($SelectedProfile -eq 'Strict') {
        $rules.Add([pscustomobject]@{
            Name = 'network_identity_field'
            Pattern = '(?im)(\b(?:dns suffix|domain|fqdn|ssid)\s*[:=]\s*)[^\r\n,|]+'
            Replacement = '$1[REDACTED-NETWORK-ID]'
        })
        $rules.Add([pscustomobject]@{
            Name = 'json_network_identity_value'
            Pattern = '(?i)("(?:DnsSuffix|dns_suffix|domain|fqdn|ssid)"\s*:\s*")[^"]*'
            Replacement = '$1[REDACTED-NETWORK-ID]'
        })
        $rules.Add([pscustomobject]@{
            Name = 'web_url'
            Pattern = '(?i)https?://[^\s,"'']+'
            Replacement = '[REDACTED-URL]'
        })
        $rules.Add([pscustomobject]@{
            Name = 'unc_path'
            Pattern = '(?i)\\\\[^\\\s]+\\[^\r\n,"]+'
            Replacement = '[REDACTED-UNC-PATH]'
        })
        $rules.Add([pscustomobject]@{
            Name = 'guid_identifier'
            Pattern = '(?i)\b[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\b'
            Replacement = '[REDACTED-GUID]'
        })
    }

    $customIndex = 0
    foreach ($pattern in $AdditionalPatterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
        $customIndex++
        # Compile now so invalid custom expressions fail before any output is created.
        [void][regex]::new($pattern)
        $rules.Add([pscustomobject]@{
            Name = "custom_$customIndex"
            Pattern = $pattern
            Replacement = "[REDACTED-CUSTOM-$customIndex]"
        })
    }

    return $rules.ToArray()
}

function Protect-CsvSensitiveFields {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory)][string]$SelectedProfile
    )

    $rows = @($Content | ConvertFrom-Csv)
    if ($rows.Count -eq 0) {
        return [pscustomobject][ordered]@{
            Content = $Content
            Counts = [pscustomobject][ordered]@{}
            Total = 0
        }
    }

    $counts = [ordered]@{
        csv_account_field = 0
        csv_computer_name_field = 0
        csv_serial_field = 0
        csv_network_identity_field = 0
    }

    foreach ($row in $rows) {
        foreach ($property in $row.PSObject.Properties) {
            $value = [string]$property.Value
            if ([string]::IsNullOrWhiteSpace($value) -or $value -in @('Unavailable', 'N/A', 'None')) {
                continue
            }

            switch -Regex ($property.Name) {
                '^(CurrentUser|UserName|User|Account)$' {
                    $property.Value = '[REDACTED-ACCOUNT]'
                    $counts.csv_account_field++
                    continue
                }
                '^(ComputerName|HostName|Computer|Host)$' {
                    $property.Value = '[REDACTED-HOST]'
                    $counts.csv_computer_name_field++
                    continue
                }
                '^(SerialNumber|Serial|ServiceTag|UniqueId)$' {
                    $property.Value = '[REDACTED-SERIAL]'
                    $counts.csv_serial_field++
                    continue
                }
                '^(Domain|DnsSuffix|FQDN|SSID)$' {
                    if ($SelectedProfile -eq 'Strict') {
                        $property.Value = '[REDACTED-NETWORK-ID]'
                        $counts.csv_network_identity_field++
                    }
                }
            }
        }
    }

    $csvLines = @($rows | ConvertTo-Csv -NoTypeInformation)
    return [pscustomobject][ordered]@{
        Content = ($csvLines -join [Environment]::NewLine)
        Counts = [pscustomobject]$counts
        Total = [int](($counts.Values | Measure-Object -Sum).Sum)
    }
}

function Invoke-ContentRedaction {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory)][object[]]$Rules
    )

    $updated = $Content
    $counts = [ordered]@{}

    foreach ($rule in $Rules) {
        $expression = [regex]::new([string]$rule.Pattern)
        $matchCount = $expression.Matches($updated).Count
        $counts[[string]$rule.Name] = $matchCount
        if ($matchCount -gt 0) {
            $updated = $expression.Replace($updated, [string]$rule.Replacement)
        }
    }

    return [pscustomobject][ordered]@{
        Content = $updated
        Counts = [pscustomobject]$counts
        Total = [int](($counts.Values | Measure-Object -Sum).Sum)
    }
}

$sourceRoot = (Resolve-Path -LiteralPath $SourceDirectory).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path (Split-Path -Parent $sourceRoot) 'Safe-Bundles'
}

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}
$outputRoot = (Resolve-Path -LiteralPath $OutputDirectory).Path

$sourcePrefix = $sourceRoot.TrimEnd([char[]]@('\', '/')) + [System.IO.Path]::DirectorySeparatorChar
$outputPrefix = $outputRoot.TrimEnd([char[]]@('\', '/')) + [System.IO.Path]::DirectorySeparatorChar
if ($outputRoot -eq $sourceRoot -or $outputPrefix.StartsWith($sourcePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputDirectory must be outside SourceDirectory so generated bundles cannot be collected as source reports.'
}

$rules = @(Get-RedactionRules -SelectedProfile $Profile -AdditionalPatterns $CustomPattern)
$sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -File -Recurse |
    Where-Object { $allowedExtensions -contains $_.Extension.ToLowerInvariant() } |
    Sort-Object FullName)

if ($sourceFiles.Count -eq 0) {
    throw "No supported report files were found under '$sourceRoot'. Supported extensions: $($allowedExtensions -join ', ')"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
$bundleName = "Lazarus-SafeReport-$stamp"
# Keep the private staging name deliberately short. Windows PowerShell 5.1 can
# still encounter legacy MAX_PATH behavior even when the final bundle path is
# otherwise valid, especially beneath a case workspace or long user profile.
$stagingName = ".lkstage-$((Get-Date).ToString('HHmmssfff'))-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$stagingRoot = Join-Path $outputRoot $stagingName
$zipPath = Join-Path $outputRoot "$bundleName.zip"
$zipHashPath = "$zipPath.sha256"
$fileRecords = [System.Collections.Generic.List[object]]::new()
$sourceHashes = @{}
$totalRedactions = 0

try {
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

    foreach ($file in $sourceFiles) {
        $relativePath = $file.FullName.Substring($sourceRoot.Length).TrimStart([char[]]@('\', '/'))
        $destination = Join-Path $stagingRoot $relativePath
        $destinationParent = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $destinationParent)) {
            New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
        }

        $sourceHashes[$file.FullName] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $content = Get-Content -LiteralPath $file.FullName -Raw
        $structuredCounts = [ordered]@{}
        $structuredTotal = 0
        if ($file.Extension -ieq '.csv') {
            $csvProtected = Protect-CsvSensitiveFields -Content $content -SelectedProfile $Profile
            $content = $csvProtected.Content
            foreach ($property in $csvProtected.Counts.PSObject.Properties) {
                $structuredCounts[$property.Name] = [int]$property.Value
            }
            $structuredTotal = $csvProtected.Total
        }

        $redacted = Invoke-ContentRedaction -Content $content -Rules $rules
        $combinedCounts = [ordered]@{}
        foreach ($name in $structuredCounts.Keys) {
            $combinedCounts[$name] = $structuredCounts[$name]
        }
        foreach ($property in $redacted.Counts.PSObject.Properties) {
            $combinedCounts[$property.Name] = [int]$property.Value
        }
        $fileRedactions = $structuredTotal + $redacted.Total

        if ($file.Extension -ieq '.json') {
            try {
                $redacted.Content | ConvertFrom-Json | Out-Null
            }
            catch {
                throw "Redaction would make JSON invalid: $relativePath - $($_.Exception.Message)"
            }
        }

        Set-Content -LiteralPath $destination -Value $redacted.Content -Encoding UTF8
        $outputHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        $totalRedactions += $fileRedactions

        $fileRecords.Add([pscustomobject][ordered]@{
            path = ($relativePath -replace '\\', '/')
            size_bytes = (Get-Item -LiteralPath $destination).Length
            sha256 = $outputHash
            redactions_total = $fileRedactions
            redactions = [pscustomobject]$combinedCounts
        })
    }

    foreach ($sourcePath in $sourceHashes.Keys) {
        $afterHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        if ($afterHash -ne $sourceHashes[$sourcePath]) {
            throw "A source report changed during packaging: $sourcePath"
        }
    }

    [object[]]$manifestFiles = $fileRecords.ToArray()
    $manifest = [pscustomobject][ordered]@{
        schema_version = 1
        tool = 'lazarus-safe-report-packager'
        tool_version = $script:ToolVersion
        generated_at = (Get-Date).ToString('o')
        profile = $Profile.ToLowerInvariant()
        source_file_count = $sourceFiles.Count
        packaged_file_count = $manifestFiles.Count
        redactions_total = $totalRedactions
        files = $manifestFiles
    }

    $manifestPath = Join-Path $stagingRoot 'manifest.json'
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json | Out-Null

    $checksumLines = [System.Collections.Generic.List[string]]::new()
    foreach ($record in $manifestFiles) {
        $checksumLines.Add("$($record.sha256)  $($record.path)")
    }
    $manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $checksumLines.Add("$manifestHash  manifest.json")
    $checksumLines | Set-Content -LiteralPath (Join-Path $stagingRoot 'SHA256SUMS.txt') -Encoding ASCII

    Compress-Archive -Path (Join-Path $stagingRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal -Force
    $zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    "$zipHash  $([System.IO.Path]::GetFileName($zipPath))" |
        Set-Content -LiteralPath $zipHashPath -Encoding ASCII

    $result = [pscustomobject][ordered]@{
        BundlePath = $zipPath
        BundleHashPath = $zipHashPath
        Sha256 = $zipHash
        Profile = $Profile
        FilesPackaged = $sourceFiles.Count
        Redactions = $totalRedactions
        StagingPath = $(if ($KeepStaging) { $stagingRoot } else { $null })
    }

    if (-not $PassThru) {
        Write-Host "Safe report bundle created: $zipPath" -ForegroundColor Green
        Write-Host "SHA-256: $zipHash" -ForegroundColor DarkCyan
        Write-Host "Files: $($sourceFiles.Count)  Redactions: $totalRedactions  Profile: $Profile"
    }
}
finally {
    if (-not $KeepStaging -and (Test-Path -LiteralPath $stagingRoot)) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
}

if ($PassThru) {
    return $result
}
