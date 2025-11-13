<#
.SYNOPSIS
    Upgrades the PROD version of powershell-console from GitHub releases
.DESCRIPTION
    This script downloads the latest (or specified) release from GitHub and updates
    the _prod folder with the new version. Config.json is intelligently merged to
    preserve user values while adding new schema fields.
.PARAMETER Version
    Optional version to upgrade to (e.g., "v1.6.0"). If not specified, uses latest release.
.EXAMPLE
    .\upgrade-prod.ps1
    Upgrades to the latest release
.EXAMPLE
    .\upgrade-prod.ps1 -Version v1.5.0
    Upgrades to specific version v1.5.0
#>

param(
    [string]$Version = "latest"
)

$ErrorActionPreference = "Stop"

# Paths
$scriptRoot = $PSScriptRoot
$devPath = Join-Path $scriptRoot "_dev"
$prodPath = Join-Path $scriptRoot "_prod"
$tempPath = Join-Path $env:TEMP "powershell-console-upgrade"

# Verify we're in the right directory
if (-not (Test-Path $devPath) -or -not (Test-Path $prodPath)) {
    Write-Host "Error: This script must be run from the powershell-console directory containing _dev and _prod folders" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "PowerShell Console - PROD Upgrade Script" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Get the version to upgrade to
Push-Location $devPath
try {
    if ($Version -eq "latest") {
        Write-Host "Fetching latest release from GitHub..." -ForegroundColor Yellow
        $releaseInfo = gh release view --json tagName,name | ConvertFrom-Json
        $Version = $releaseInfo.tagName
        Write-Host "Latest release: $Version - $($releaseInfo.name)" -ForegroundColor Green
    } else {
        Write-Host "Fetching release $Version from GitHub..." -ForegroundColor Yellow
        $releaseInfo = gh release view $Version --json tagName,name | ConvertFrom-Json
        Write-Host "Release: $Version - $($releaseInfo.name)" -ForegroundColor Green
    }
} catch {
    Write-Host "Error fetching release information: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

# Confirm upgrade
Write-Host ""
Write-Host "This will upgrade PROD to version $Version" -ForegroundColor Yellow
Write-Host "Your config.json will be intelligently merged with the new schema." -ForegroundColor Yellow
$confirm = Read-Host "Continue? (y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "Upgrade cancelled." -ForegroundColor Gray
    exit 0
}

# Clone/checkout the specific version from GitHub
Write-Host ""
Write-Host "Downloading version $Version from GitHub..." -ForegroundColor Yellow

# Clean temp directory if it exists
if (Test-Path $tempPath) {
    Remove-Item $tempPath -Recurse -Force
}

Push-Location $devPath
try {
    # Use git to fetch and checkout the tag in a temporary worktree
    Write-Host "Fetching tags..." -ForegroundColor Gray
    git fetch --tags --quiet

    # Create temporary directory and checkout tag
    New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
    git --work-tree=$tempPath checkout $Version -- console.ps1 modules scripts resources CHANGELOG.md README.md SETUP.md LICENSE config.example.json

    Write-Host "Downloaded successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error downloading release: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

# Smart Config Merge
Write-Host ""
Write-Host "Performing smart config merge..." -ForegroundColor Yellow

$currentConfigPath = Join-Path $prodPath "config.json"
$newExampleConfigPath = Join-Path $tempPath "config.example.json"
$backupConfigPath = Join-Path $prodPath "config.json.backup"

if (Test-Path $currentConfigPath) {
    # Load current and new configs
    $currentConfig = Get-Content $currentConfigPath -Raw | ConvertFrom-Json
    $newExampleConfig = Get-Content $newExampleConfigPath -Raw | ConvertFrom-Json

    # Check version changes
    $currentVersion = if ($currentConfig.PSObject.Properties.Name -contains "configVersion") {
        $currentConfig.configVersion
    } else {
        "unknown"
    }

    $newVersion = if ($newExampleConfig.PSObject.Properties.Name -contains "configVersion") {
        $newExampleConfig.configVersion
    } else {
        $Version
    }

    Write-Host "  Current config version: $currentVersion" -ForegroundColor Gray
    Write-Host "  New config version: $newVersion" -ForegroundColor Gray

    # Backup current config
    Copy-Item $currentConfigPath $backupConfigPath -Force
    Write-Host "  Config backed up to config.json.backup" -ForegroundColor Green

    # Perform deep merge
    function Merge-ConfigObjects {
        param(
            [PSCustomObject]$Target,
            [PSCustomObject]$Source,
            [string]$Path = ""
        )

        $merged = $Target.PSObject.Copy()

        foreach ($property in $Source.PSObject.Properties) {
            $propName = $property.Name
            $currentPath = if ($Path) { "$Path.$propName" } else { $propName }

            if ($Target.PSObject.Properties.Name -contains $propName) {
                # Property exists in both - check if we need to recurse
                $targetValue = $Target.$propName
                $sourceValue = $Source.$propName

                if ($targetValue -is [PSCustomObject] -and $sourceValue -is [PSCustomObject]) {
                    # Both are objects - recurse
                    $merged.$propName = Merge-ConfigObjects -Target $targetValue -Source $sourceValue -Path $currentPath
                } else {
                    # Keep user's value (don't overwrite)
                    $merged.$propName = $targetValue
                }
            } else {
                # New property - add it from example
                Write-Host "  [+] Added new field: $currentPath" -ForegroundColor Cyan
                $merged | Add-Member -NotePropertyName $propName -NotePropertyValue $property.Value -Force
            }
        }

        # Check for removed properties
        foreach ($property in $Target.PSObject.Properties) {
            $propName = $property.Name
            $currentPath = if ($Path) { "$Path.$propName" } else { $propName }

            if ($Source.PSObject.Properties.Name -notcontains $propName) {
                Write-Host "  [!] Deprecated field (kept): $currentPath" -ForegroundColor Yellow
            }
        }

        return $merged
    }

    # Merge configs
    $mergedConfig = Merge-ConfigObjects -Target $currentConfig -Source $newExampleConfig

    # Update configVersion to new version
    if ($mergedConfig.PSObject.Properties.Name -notcontains "configVersion") {
        $mergedConfig | Add-Member -NotePropertyName "configVersion" -NotePropertyValue $newVersion -Force
        Write-Host "  [+] Added new field: configVersion" -ForegroundColor Cyan
    } else {
        $mergedConfig.configVersion = $newVersion
    }

    # Save merged config
    $mergedConfig | ConvertTo-Json -Depth 20 | Set-Content $currentConfigPath
    Write-Host "  Config merged successfully!" -ForegroundColor Green

    # Check CHANGELOG for config notes
    $changelogPath = Join-Path $tempPath "CHANGELOG.md"
    if (Test-Path $changelogPath) {
        $changelog = Get-Content $changelogPath -Raw
        if ($changelog -match "(?s)###\s+$Version.*?Config Changes") {
            Write-Host ""
            Write-Host "  NOTE: This release has config changes documented in CHANGELOG.md" -ForegroundColor Yellow
            Write-Host "        Review $changelogPath for details" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  No existing config.json found - copying config.example.json" -ForegroundColor Yellow
    Copy-Item $newExampleConfigPath $currentConfigPath
}

# Update PROD files
Write-Host ""
Write-Host "Updating PROD files..." -ForegroundColor Yellow

# Remove old files (except config files)
Get-ChildItem $prodPath | Where-Object {
    $_.Name -ne "config.json" -and $_.Name -ne "config.json.backup"
} | Remove-Item -Recurse -Force

# Copy new files
Copy-Item -Path (Join-Path $tempPath "console.ps1") -Destination $prodPath -Force
Copy-Item -Path (Join-Path $tempPath "modules") -Destination $prodPath -Recurse -Force
Copy-Item -Path (Join-Path $tempPath "scripts") -Destination $prodPath -Recurse -Force
Copy-Item -Path (Join-Path $tempPath "resources") -Destination $prodPath -Recurse -Force
Copy-Item -Path (Join-Path $tempPath "CHANGELOG.md") -Destination $prodPath -Force
Copy-Item -Path (Join-Path $tempPath "README.md") -Destination $prodPath -Force
Copy-Item -Path (Join-Path $tempPath "SETUP.md") -Destination $prodPath -Force
Copy-Item -Path (Join-Path $tempPath "LICENSE") -Destination $prodPath -Force
Copy-Item -Path (Join-Path $tempPath "config.example.json") -Destination $prodPath -Force

# Clean up temp directory
Remove-Item $tempPath -Recurse -Force

Write-Host "PROD updated successfully!" -ForegroundColor Green

# Show current version
Write-Host ""
Write-Host "Current PROD version:" -ForegroundColor Cyan
Push-Location $prodPath
& .\console.ps1 --version
Pop-Location

Write-Host ""
Write-Host "Upgrade complete!" -ForegroundColor Green
Write-Host "  Backup config saved at: $backupConfigPath" -ForegroundColor Gray
Write-Host ""
