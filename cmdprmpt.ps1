
# ==========================================
# CONSOLE INITIALIZATION
# ==========================================

# Save original console state
$script:OriginalOutputEncoding = [Console]::OutputEncoding
$script:OriginalInputEncoding = [Console]::InputEncoding
$script:OriginalPSOutputEncoding = $OutputEncoding

# Set console encoding to UTF-8 for proper character rendering
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# Set PowerShell output encoding
$OutputEncoding = [System.Text.Encoding]::UTF8

# Don't modify PSStyle.OutputRendering - let it stay as ANSI for Oh-My-Posh compatibility

# Function to restore console state on exit
function Restore-ConsoleState {
    # Restore original encoding settings
    [Console]::OutputEncoding = $script:OriginalOutputEncoding
    [Console]::InputEncoding = $script:OriginalInputEncoding
    $global:OutputEncoding = $script:OriginalPSOutputEncoding

    # Clear any lingering keyboard buffer
    while ([Console]::KeyAvailable) {
        [Console]::ReadKey($true) | Out-Null
    }

    # Reset console cursor visibility
    [Console]::CursorVisible = $true

    # Write a newline to ensure clean prompt rendering
    Write-Host ""
}

# ==========================================
# CONFIGURATION LOADING
# ==========================================

function Import-Configuration {
    $configPath = Join-Path $PSScriptRoot "config.json"
    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        return $config
    }
    catch {
        throw "Error loading configuration: $($_.Exception.Message)"
    }
}

function Update-ScriptConfiguration {
    Write-Host "Reloading configuration..." -ForegroundColor Gray
    $script:Config = Import-Configuration
    Write-Host "✓ Configuration reloaded" -ForegroundColor Green
}

function Save-Menu {
    param(
        [string]$MenuTitle,
        [array]$MenuItems
    )

    $configPath = Join-Path $PSScriptRoot "config.json"
    $config = Get-Content $configPath -Raw | ConvertFrom-Json

    # Initialize menus section if it doesn't exist
    if (-not $config.PSObject.Properties['menus']) {
        $config | Add-Member -NotePropertyName 'menus' -NotePropertyValue @{} -Force
    }

    # Convert menu items to saveable format
    $menuData = @()
    foreach ($item in $MenuItems) {
        $text = if ($item -is [string]) { $item } else { $item.Text }
        $action = if ($item -is [hashtable] -and $item.Action) {
            # Store the action as a string representation
            $item.Action.ToString()
        } else {
            ""
        }

        $menuData += @{
            text = $text
            action = $action
        }
    }

    # Save menu to config
    if ($config.menus.PSObject.Properties[$MenuTitle]) {
        $config.menus.$MenuTitle = $menuData
    } else {
        $config.menus | Add-Member -NotePropertyName $MenuTitle -NotePropertyValue $menuData -Force
    }

    # Save back to file
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
}

function Get-MenuFromConfig {
    param(
        [string]$MenuTitle,
        [array]$DefaultMenuItems
    )

    # Check if menu exists in config
    if ($script:Config.PSObject.Properties['menus'] -and
        $script:Config.menus.PSObject.Properties[$MenuTitle]) {

        # Load menu from config
        $savedMenu = $script:Config.menus.$MenuTitle
        $menuItems = @()

        foreach ($item in $savedMenu) {
            # Reconstruct menu item with action
            if ($item.action -and $item.action -ne "") {
                $menuItems += New-MenuAction $item.text ([scriptblock]::Create($item.action))
            } else {
                $menuItems += $item.text
            }
        }

        return $menuItems
    }

    # Return default menu if not in config
    return $DefaultMenuItems
}

function Get-AwsAccountMenuOrder {
    <#
    .SYNOPSIS
    Gets the saved menu order for AWS accounts, or returns null if not saved
    #>
    if ($script:Config.PSObject.Properties['awsAccountMenuOrder']) {
        return $script:Config.awsAccountMenuOrder
    }
    return $null
}

function Save-AwsAccountMenuOrder {
    <#
    .SYNOPSIS
    Saves the AWS account menu order to config.json
    .PARAMETER MenuItems
    Array of menu item hashtables with Environment and Role properties
    #>
    param(
        [array]$MenuItems
    )

    $configPath = Join-Path $PSScriptRoot "config.json"
    $config = Get-Content $configPath -Raw | ConvertFrom-Json

    # Build order array from menu items
    # Format: "envKey" or "envKey:Role" for role-specific items
    $orderArray = @()
    foreach ($item in $MenuItems) {
        if ($item.Environment -eq "sync" -or $item.Environment -eq "manual") {
            # Skip special items - they're always added at the end
            continue
        }

        if ($item.Role) {
            $orderArray += "$($item.Environment):$($item.Role)"
        } else {
            $orderArray += $item.Environment
        }
    }

    # Save to config
    if ($config.PSObject.Properties['awsAccountMenuOrder']) {
        $config.awsAccountMenuOrder = $orderArray
    } else {
        $config | Add-Member -NotePropertyName 'awsAccountMenuOrder' -NotePropertyValue $orderArray -Force
    }

    # Save back to file
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8

    # Reload config
    $script:Config = Import-Configuration
}

function Save-AwsAccountCustomName {
    <#
    .SYNOPSIS
    Saves a custom display name for an AWS account menu item
    .PARAMETER Environment
    The environment key
    .PARAMETER Role
    The role (optional)
    .PARAMETER CustomName
    The custom display text
    #>
    param(
        [string]$Environment,
        [string]$Role,
        [string]$CustomName
    )

    $configPath = Join-Path $PSScriptRoot "config.json"
    $config = Get-Content $configPath -Raw | ConvertFrom-Json

    # Find the environment
    if (-not $config.environments.PSObject.Properties[$Environment]) {
        Write-Warning "Environment '$Environment' not found in config"
        return
    }

    # Initialize customMenuNames if it doesn't exist
    if (-not $config.environments.$Environment.PSObject.Properties['customMenuNames']) {
        $config.environments.$Environment | Add-Member -NotePropertyName 'customMenuNames' -NotePropertyValue @{} -Force
    }

    # Save the custom name
    $key = if ($Role) { $Role } else { "default" }

    if ($config.environments.$Environment.customMenuNames.PSObject.Properties[$key]) {
        $config.environments.$Environment.customMenuNames.$key = $CustomName
    } else {
        $config.environments.$Environment.customMenuNames | Add-Member -NotePropertyName $key -NotePropertyValue $CustomName -Force
    }

    # Save back to file
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8

    # Reload config
    $script:Config = Import-Configuration
}

function Get-AwsAccountCustomName {
    <#
    .SYNOPSIS
    Gets the custom display name for an AWS account menu item if it exists
    .PARAMETER Environment
    The environment key
    .PARAMETER Role
    The role (optional)
    .RETURNS
    Custom name if exists, otherwise $null
    #>
    param(
        [string]$Environment,
        [string]$Role
    )

    if (-not $script:Config.environments.PSObject.Properties[$Environment]) {
        return $null
    }

    $env = $script:Config.environments.$Environment

    if (-not $env.PSObject.Properties['customMenuNames']) {
        return $null
    }

    $key = if ($Role) { $Role } else { "default" }

    if ($env.customMenuNames.PSObject.Properties[$key]) {
        return $env.customMenuNames.$key
    }

    return $null
}

$script:Config = Import-Configuration

# Global variables for connection state
$global:awsInstance = ""
$global:remoteIP = ""
$global:localPort = ""
$global:remotePort = ""
$global:currentAwsEnvironment = ""
$global:currentAwsRegion = ""
# Hashtable to store per-account default instance IDs
$global:accountDefaultInstances = @{}
# Hashtable to store menu position memory (remembers last selected item per menu)
$global:MenuPositionMemory = @{}

# ==========================================
# PACKAGE MANAGER UPDATE AUTOMATION
# ==========================================

function Update-Check {
    [CmdletBinding()]
    param()

    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  CHECKING FOR PACKAGE UPDATES              ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    # Check Scoop
    Write-Host "📦 Scoop packages:" -ForegroundColor Yellow
    try {
        # First, refresh bucket metadata (this is required for accurate status)
        Write-Host "  → Refreshing bucket metadata..." -ForegroundColor Gray
        $null = scoop update 2>&1

        # Now check status with fresh data
        $scoopStatus = scoop status 2>&1 | Out-String

        # Check if everything is up to date
        if ($scoopStatus -match "Latest versions for all apps are installed") {
            Write-Host "  ✅ All Scoop packages up to date" -ForegroundColor Green
        } else {
            # Parse status output and filter out "Install failed" entries
            $lines = $scoopStatus -split "`n"
            $hasUpdates = $false

            foreach ($line in $lines) {
                # Skip lines with "Install failed" as these need manual intervention
                if ($line -match "Install failed") {
                    Write-Host "  ⚠️  $($line.Trim())" -ForegroundColor Yellow
                    Write-Host "      Run 'scoop uninstall <app>' and 'scoop install <app>' to fix" -ForegroundColor DarkYellow
                } elseif ($line.Trim() -and $line -notmatch "^Scoop is up to date") {
                    Write-Host "  $line" -ForegroundColor White
                    $hasUpdates = $true
                }
            }

            if (-not $hasUpdates -and $scoopStatus -notmatch "Install failed") {
                Write-Host "  ✅ All Scoop packages up to date" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "  ⚠️  Scoop not found or error checking status" -ForegroundColor Red
    }

    # Check npm global packages
    Write-Host "`n📦 npm global packages:" -ForegroundColor Yellow
    try {
        $npmOutdated = npm outdated -g 2>&1
        if ([string]::IsNullOrWhiteSpace($npmOutdated)) {
            Write-Host "  ✅ All npm global packages up to date" -ForegroundColor Green
        } else {
            $npmOutdated
        }
    } catch {
        Write-Host "  ⚠️  npm not found or error checking status" -ForegroundColor Red
    }

    # Check winget packages
    Write-Host "`n📦 winget packages:" -ForegroundColor Yellow
    try {
        # Capture winget output properly, filtering out progress bars
        $wingetUpgrades = winget upgrade 2>&1 | Out-String
        if ($wingetUpgrades -match "No installed package found" -or $wingetUpgrades -match "No applicable updates found") {
            Write-Host "  ✅ All winget packages up to date" -ForegroundColor Green
        } else {
            # Filter out ANSI escape sequences and progress indicators
            $wingetUpgrades -split "`n" | ForEach-Object {
                $line = $_
                # Skip empty lines and progress indicators
                if ($line.Trim() -and $line -notmatch '^\s*[\-\\/\|]\s*$') {
                    Write-Host $line -ForegroundColor White
                }
            }
        }
    } catch {
        Write-Host "  ⚠️  winget not found or error checking status" -ForegroundColor Red
    }

    Write-Host "`n💡 Use 'Update All Packages' menu option to install updates" -ForegroundColor Cyan
    Write-Host "💡 Or use 'Select Updates to Install' to choose specific packages`n" -ForegroundColor Cyan
}

function Update-All {
    [CmdletBinding()]
    param(
        [switch]$SkipCleanup
    )

    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║  UPDATING ALL PACKAGES                     ║" -ForegroundColor Magenta
    Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Magenta

    $startTime = Get-Date

    # Update Scoop
    Update-Scoop -SkipCleanup:$SkipCleanup

    # Update npm
    Update-npm

    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  ✅ ALL UPDATES COMPLETE                   ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host "⏱️  Total time: $($duration.TotalSeconds) seconds`n" -ForegroundColor Cyan
}

function Update-Scoop {
    [CmdletBinding()]
    param(
        [switch]$SkipCleanup
    )

    Write-Host "`n🔄 Updating Scoop packages..." -ForegroundColor Cyan

    try {
        # Update Scoop itself first
        Write-Host "  → Updating Scoop..." -ForegroundColor Gray
        scoop update

        # Update all apps
        Write-Host "  → Updating all apps..." -ForegroundColor Gray
        scoop update *

        # Cleanup old versions (unless skipped)
        if (-not $SkipCleanup) {
            Write-Host "  → Cleaning up old versions..." -ForegroundColor Gray
            scoop cleanup * -k

            Write-Host "  → Clearing cache..." -ForegroundColor Gray
            scoop cache rm *
        }

        Write-Host "✅ Scoop packages updated" -ForegroundColor Green
    } catch {
        Write-Host "❌ Error updating Scoop: $_" -ForegroundColor Red
    }
}

function Update-npm {
    [CmdletBinding()]
    param()

    Write-Host "`n🔄 Updating npm global packages..." -ForegroundColor Cyan

    try {
        # Check what's outdated first
        Write-Host "  → Checking for updates..." -ForegroundColor Gray
        $outdated = npm outdated -g 2>&1

        if ([string]::IsNullOrWhiteSpace($outdated)) {
            Write-Host "  ✅ All npm packages already up to date" -ForegroundColor Green
        } else {
            Write-Host "  → Updating packages..." -ForegroundColor Gray
            npm update -g

            Write-Host "  → Clearing cache..." -ForegroundColor Gray
            npm cache clean --force

            Write-Host "✅ npm packages updated" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ Error updating npm: $_" -ForegroundColor Red
    }
}

function Update-Winget {
    [CmdletBinding()]
    param()

    Write-Host "`n🔄 Checking winget packages..." -ForegroundColor Cyan

    try {
        Write-Host "  → Checking for updates..." -ForegroundColor Gray
        winget upgrade

        Write-Host "`n💡 Use 'winget upgrade --all' to install updates" -ForegroundColor Yellow
        Write-Host "💡 Or 'winget upgrade <package>' for specific package`n" -ForegroundColor Yellow
    } catch {
        Write-Host "❌ Error checking winget: $_" -ForegroundColor Red
    }
}

function Get-InstalledPackages {
    [CmdletBinding()]
    param()

    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  INSTALLED PACKAGES                        ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    # Scoop packages
    Write-Host "📦 Scoop packages:" -ForegroundColor Yellow
    Write-Host ""
    try {
        $scoopApps = scoop list
        if ($scoopApps) {
            $scoopApps | Format-Table Name, Version, Source, Updated -AutoSize | Out-String | Write-Host
        } else {
            Write-Host "  No Scoop packages installed" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  ⚠️  Scoop not found" -ForegroundColor Red
    }

    # npm global packages
    Write-Host "`n📦 npm global packages:" -ForegroundColor Yellow
    Write-Host ""
    try {
        $npmList = & npm list -g --depth=0 2>&1
        $npmList | ForEach-Object { Write-Host $_ }
    } catch {
        Write-Host "  ⚠️  npm not found" -ForegroundColor Red
    }

    # Prompt before showing winget packages
    Write-Host ""
    $showWinget = Read-Host "Display winget packages? (Y/n)"
    if ($showWinget.ToLower() -eq "n") {
        Write-Host "Skipping winget packages." -ForegroundColor Gray
        return
    }

    # winget packages
    Write-Host "`n📦 winget packages:" -ForegroundColor Yellow
    Write-Host ""
    try {
        # Capture winget list output and filter out progress indicators
        $wingetOutput = winget list 2>&1 | Out-String

        # Filter out progress bars and spinner characters
        $cleanedLines = $wingetOutput -split "`n" | Where-Object {
            $line = $_
            # Skip empty lines
            if (-not $line.Trim()) { return $false }
            # Skip lines that are just spinner characters
            if ($line -match '^\s*[\-\\/\|]\s*$') { return $false }
            # Skip lines with only progress indicators
            if ($line.Trim() -match '^[\-\\/\|]$') { return $false }
            return $true
        }

        # Parse and sort winget output
        $headerLine = $null
        $separatorLine = $null
        $dataLines = @()
        $footerLines = @()
        $inData = $false

        foreach ($line in $cleanedLines) {
            # Detect header line (contains "Name" and "Id" and "Version")
            if ($line -match 'Name.*Id.*Version' -and -not $headerLine) {
                $headerLine = $line
                continue
            }
            # Detect separator line (dashes)
            elseif ($line -match '^-+' -and $headerLine -and -not $separatorLine) {
                $separatorLine = $line
                $inData = $true
                continue
            }
            # Detect footer (upgrade count or other summary)
            elseif ($line -match '^\d+\s+(package|upgrade|installed)' -or $line -match 'The following packages') {
                $inData = $false
                $footerLines += $line
            }
            # Data lines
            elseif ($inData) {
                $dataLines += $line
            }
            # Other lines (pre-header or post-footer)
            else {
                $footerLines += $line
            }
        }

        # Display header
        if ($headerLine) {
            Write-Host $headerLine
        }
        if ($separatorLine) {
            Write-Host $separatorLine
        }

        # Sort data lines alphabetically by package name (first column)
        $sortedDataLines = $dataLines | Sort-Object

        # Display sorted data
        foreach ($line in $sortedDataLines) {
            Write-Host $line
        }

        # Display footer
        foreach ($line in $footerLines) {
            Write-Host $line
        }
    } catch {
        Write-Host "  ⚠️  winget not found" -ForegroundColor Red
    }
}

function Select-PackagesToUpdate {
    [CmdletBinding()]
    param()

    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  MANAGE PACKAGE UPDATES                    ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    # Collect available updates
    $availableUpdates = @()

    # Check Scoop
    Write-Host "Checking Scoop for updates..." -ForegroundColor Gray
    try {
        # First, refresh bucket metadata (this is required for accurate status)
        Write-Host "  → Refreshing bucket metadata..." -ForegroundColor Gray
        scoop update

        Write-Host "  → Checking package status..." -ForegroundColor Gray
        $scoopStatus = scoop status *>&1 | Out-String
        Write-Host $scoopStatus

        if ($scoopStatus -notmatch "Latest versions for all apps are installed") {
            # Parse scoop status output for outdated packages
            # Format: Name Installed Version Latest Version Missing Dependencies Info
            #         ---- ----------------- -------------- -------------------- ----
            #         aws  2.31.16           2.31.18
            $scoopLines = $scoopStatus -split "`n"
            $inTable = $false

            foreach ($line in $scoopLines) {
                # Find the header line
                if ($line -match 'Name\s+Installed Version\s+Latest Version') {
                    $inTable = $true
                    continue
                }

                # Skip separator line
                if ($line -match '^-+') {
                    continue
                }

                # Parse table rows - only lines that have package data
                if ($inTable -and $line.Trim().Length -gt 0) {
                    # Split by whitespace, filtering empty entries
                    $parts = $line -split '\s+' | Where-Object { $_.Trim() -ne '' }

                    # Need at least 3 parts: Name, InstalledVersion, LatestVersion
                    if ($parts.Count -ge 3) {
                        $name = $parts[0]
                        $currentVer = $parts[1]
                        $newVer = $parts[2]

                        $availableUpdates += @{
                            Manager = "Scoop"
                            Name = $name
                            CurrentVersion = $currentVer
                            NewVersion = $newVer
                            DisplayText = "[$name] Scoop: $currentVer -> $newVer"
                        }
                    }
                }
            }
        }
    } catch {
        Write-Host "  ⚠️  Error checking Scoop" -ForegroundColor Red
    }

    # Check npm
    Write-Host "Checking npm for updates..." -ForegroundColor Gray
    try {
        $npmOutdated = npm outdated -g --json 2>&1 | ConvertFrom-Json
        if ($npmOutdated) {
            foreach ($pkg in $npmOutdated.PSObject.Properties) {
                $availableUpdates += @{
                    Manager = "npm"
                    Name = $pkg.Name
                    CurrentVersion = $pkg.Value.current
                    NewVersion = $pkg.Value.latest
                    DisplayText = "[$($pkg.Name)] npm: $($pkg.Value.current) -> $($pkg.Value.latest)"
                }
            }
        }
    } catch {
        Write-Host "  ⚠️  Error checking npm" -ForegroundColor Red
    }

    # Check winget
    Write-Host "Checking winget for updates..." -ForegroundColor Gray
    try {
        $wingetOutput = winget upgrade 2>&1 | Out-String
        $wingetLines = $wingetOutput -split "`n"

        $inTable = $false

        foreach ($line in $wingetLines) {
            # Find the header line (contains "Name" and "Id" and "Version" and "Available")
            if ($line -match 'Name.*Id.*Version.*Available') {
                $inTable = $true
                continue
            }

            # Skip the separator line (dashes)
            if ($line -match '^-+$') {
                continue
            }

            # Stop parsing when we hit the summary line
            if ($line -match '^\d+\s+upgrade') {
                break
            }

            # Parse table rows - only lines that are in the table and not empty
            if ($inTable -and $line.Trim().Length -gt 0) {
                # winget uses fixed-width columns with single spaces
                # Split by single or multiple spaces
                $parts = $line -split '\s+' | Where-Object { $_.Trim() -ne '' }

                # We need at least 4 parts: Name, Id, Version, Available (Source is optional 5th)
                if ($parts.Count -ge 4) {
                    # Name might be multiple words, so we need to be smart about this
                    # The last part is Source (if present), before that is Available, before that is Version, before that is Id
                    # Everything before Id is the Name

                    if ($parts.Count -eq 5) {
                        # Has Source column: Name Id Version Available Source
                        # But Name might be multiple words, so check if last item looks like a source
                        # $parts[-1] is source (not used)
                        $newVer = $parts[-2]
                        $currentVer = $parts[-3]
                        $id = $parts[-4]
                        # Everything else is the name
                        $name = ($parts[0..($parts.Count - 5)] -join ' ').Trim()
                    } elseif ($parts.Count -eq 4) {
                        # No Source or Name is single word: Name Id Version Available
                        $newVer = $parts[-1]
                        $currentVer = $parts[-2]
                        $id = $parts[-3]
                        $name = $parts[0]
                    } else {
                        # More than 5 parts means Name has multiple words
                        # Assume format: Name(multi-word) Id Version Available Source
                        # $parts[-1] is source (not used)
                        $newVer = $parts[-2]
                        $currentVer = $parts[-3]
                        $id = $parts[-4]
                        $name = ($parts[0..($parts.Count - 5)] -join ' ').Trim()
                    }

                    # Validate this is actually a data row (not a header or separator)
                    # Check that ID looks like a real package ID (contains a dot usually)
                    if ($id -and $id -match '\.' -and
                        $currentVer -notmatch '^(Version|-+)$' -and
                        $newVer -notmatch '^(Available|Source|-+)$' -and
                        $newVer -ne $currentVer) {

                        $availableUpdates += @{
                            Manager = "winget"
                            Name = $id
                            DisplayName = $name
                            CurrentVersion = $currentVer
                            NewVersion = $newVer
                            DisplayText = "[$name] winget: $currentVer -> $newVer"
                        }
                    }
                }
            }
        }
    } catch {
        Write-Host "  ⚠️  Error checking winget" -ForegroundColor Red
    }

    if ($availableUpdates.Count -eq 0) {
        Write-Host "`n✅ All packages are up to date!" -ForegroundColor Green
        return
    }

    # Display available updates with checkboxes
    Write-Host "`nAvailable updates:" -ForegroundColor Yellow
    Write-Host ""

    $selectedIndexes = @()
    for ($i = 0; $i -lt $availableUpdates.Count; $i++) {
        $selectedIndexes += $false
    }

    $currentIndex = 0
    $done = $false

    while (-not $done) {
        Clear-Host
        Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║  MANAGE PACKAGE UPDATES                    ║" -ForegroundColor Cyan
        Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Cyan

        Write-Host "Use Up/Down arrows to navigate, Space to select/deselect, Enter to install" -ForegroundColor Gray
        Write-Host "Press A to select all, N to deselect all, Q to cancel`n" -ForegroundColor Gray

        for ($i = 0; $i -lt $availableUpdates.Count; $i++) {
            $update = $availableUpdates[$i]
            $checkbox = if ($selectedIndexes[$i]) { "[X]" } else { "[ ]" }
            $arrow = if ($i -eq $currentIndex) { ">" } else { " " }
            $color = if ($i -eq $currentIndex) { "Green" } else { "White" }

            Write-Host "$arrow $checkbox $($update.DisplayText)" -ForegroundColor $color
        }

        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            'UpArrow' {
                $currentIndex = ($currentIndex - 1 + $availableUpdates.Count) % $availableUpdates.Count
            }
            'DownArrow' {
                $currentIndex = ($currentIndex + 1) % $availableUpdates.Count
            }
            'Spacebar' {
                $selectedIndexes[$currentIndex] = -not $selectedIndexes[$currentIndex]
            }
            'A' {
                for ($i = 0; $i -lt $selectedIndexes.Count; $i++) {
                    $selectedIndexes[$i] = $true
                }
            }
            'N' {
                for ($i = 0; $i -lt $selectedIndexes.Count; $i++) {
                    $selectedIndexes[$i] = $false
                }
            }
            'Enter' {
                $done = $true
            }
            'Q' {
                Write-Host "`nCancelled." -ForegroundColor Yellow
                return
            }
        }
    }

    # Install selected packages
    $selectedPackages = @()
    for ($i = 0; $i -lt $availableUpdates.Count; $i++) {
        if ($selectedIndexes[$i]) {
            $selectedPackages += $availableUpdates[$i]
        }
    }

    if ($selectedPackages.Count -eq 0) {
        Write-Host "`nNo packages selected." -ForegroundColor Yellow
        return
    }

    Clear-Host
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║  INSTALLING SELECTED UPDATES               ║" -ForegroundColor Magenta
    Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Magenta

    Write-Host "Installing $($selectedPackages.Count) package(s)...`n" -ForegroundColor Cyan

    foreach ($pkg in $selectedPackages) {
        Write-Host "→ Updating $($pkg.Name) ($($pkg.Manager))..." -ForegroundColor Yellow

        try {
            if ($pkg.Manager -eq "Scoop") {
                scoop update $pkg.Name
                Write-Host "  ✅ $($pkg.Name) updated successfully" -ForegroundColor Green
            } elseif ($pkg.Manager -eq "npm") {
                npm install -g "$($pkg.Name)@$($pkg.NewVersion)"
                Write-Host "  ✅ $($pkg.Name) updated successfully" -ForegroundColor Green
            } elseif ($pkg.Manager -eq "winget") {
                winget upgrade --id $pkg.Name --accept-package-agreements --accept-source-agreements
                Write-Host "  ✅ $($pkg.Name) updated successfully" -ForegroundColor Green
            }
        } catch {
            Write-Host "  ❌ Error updating $($pkg.Name): $_" -ForegroundColor Red
        }
        Write-Host ""
    }

    Write-Host "✅ Update process complete!" -ForegroundColor Green
}

function Search-Packages {
    [CmdletBinding()]
    param()

    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  SEARCH PACKAGES                           ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    $searchTerm = Read-Host "Enter search term"

    if ([string]::IsNullOrWhiteSpace($searchTerm)) {
        Write-Host "Search cancelled - no search term provided." -ForegroundColor Yellow
        return
    }

    $searchScope = Read-Host "Search (I)nstalled or (G)lobally available packages? (I/g)"
    $searchInstalled = $true
    if ($searchScope.ToLower() -eq "g") {
        $searchInstalled = $false
        Write-Host "`nSearching globally for '$searchTerm' (installed packages highlighted in green)...`n" -ForegroundColor Cyan
    } else {
        Write-Host "`nSearching installed packages for '$searchTerm'...`n" -ForegroundColor Cyan
    }

    # Get list of installed packages for highlighting when searching globally
    $installedScoop = @()
    $installedWinget = @()

    if (-not $searchInstalled) {
        # Get installed Scoop packages
        try {
            $scoopList = scoop list 2>&1 | Out-String
            $installedScoop = ($scoopList -split "`n" | Where-Object { $_ -match '\S' } | ForEach-Object {
                if ($_ -match '^\s*(\S+)') { $matches[1] }
            })
        } catch { }

        # Get installed winget packages
        try {
            $wingetListOutput = winget list 2>&1 | Out-String
            $wingetListLines = $wingetListOutput -split "`n"
            $inTable = $false
            foreach ($line in $wingetListLines) {
                if ($line -match 'Name.*Id.*Version') {
                    $inTable = $true
                    continue
                }
                if ($inTable -and $line.Trim().Length -gt 0 -and $line -notmatch '^-+$') {
                    # Extract package ID (second column typically)
                    $parts = $line -split '\s{2,}' | Where-Object { $_.Trim() -ne '' }
                    if ($parts.Count -ge 2) {
                        $installedWinget += $parts[1].Trim()
                    }
                }
            }
        } catch { }
    }

    # Search Scoop
    Write-Host "📦 Scoop results:" -ForegroundColor Yellow
    Write-Host ""
    try {
        if ($searchInstalled) {
            # Search installed packages only
            $scoopList = scoop list 2>&1 | Out-String
            $allLines = $scoopList -split "`n"

            # Separate header/footer from data
            $headerLines = @()
            $dataLines = @()
            $inData = $false

            foreach ($line in $allLines) {
                if ($line -match 'Name.*Version.*Source') {
                    $headerLines += $line
                    $inData = $true
                } elseif ($line -match '^-+') {
                    $headerLines += $line
                } elseif ($inData -and $line.Trim().Length -gt 0 -and $line -match $searchTerm) {
                    $dataLines += $line
                }
            }

            if ($dataLines.Count -eq 0) {
                Write-Host "  No matches found" -ForegroundColor Gray
            } else {
                # Display header
                $headerLines | ForEach-Object { Write-Host $_ }
                # Display sorted data
                $dataLines | Sort-Object | ForEach-Object { Write-Host $_ }
            }
        } else {
            # Search globally available packages
            $scoopResults = scoop search $searchTerm 2>&1 | Out-String
            if ($scoopResults -match "No matches found" -or [string]::IsNullOrWhiteSpace($scoopResults)) {
                Write-Host "  No matches found" -ForegroundColor Gray
            } else {
                # Parse and sort scoop search output
                $scoopLines = $scoopResults -split "`n"
                $headerLines = @()
                $dataLines = @()

                foreach ($line in $scoopLines) {
                    # Detect header lines (bucket names, section headers, column headers, separator lines)
                    if ($line -match "^'.*'.*bucket" -or
                        $line -match "^Results from" -or
                        $line -match "^Name\s+Version\s+Source" -or
                        $line -match "^\*Name\s+Version\s+Source" -or
                        $line -match "^-+\s+-+\s+-+") {
                        $headerLines += $line
                    } elseif ($line.Trim().Length -gt 0) {
                        # Only add non-empty lines to data
                        $dataLines += $line
                    }
                }

                # Display headers first
                $headerLines | ForEach-Object { Write-Host $_ }

                # Sort and display data with highlighting (already filtered for non-empty)
                $sortedData = $dataLines | Sort-Object
                foreach ($line in $sortedData) {
                    $isInstalled = $false
                    foreach ($pkg in $installedScoop) {
                        if ($line -match "^\s*$pkg\s" -or $line -match "/$pkg\s") {
                            $isInstalled = $true
                            break
                        }
                    }
                    if ($isInstalled) {
                        Write-Host $line -ForegroundColor Green
                    } else {
                        Write-Host $line
                    }
                }
            }
        }
    } catch {
        Write-Host "  ⚠️  Scoop not found or error searching" -ForegroundColor Red
    }

    # Search winget
    Write-Host "`n📦 winget results:" -ForegroundColor Yellow
    Write-Host ""
    try {
        if ($searchInstalled) {
            # Search installed packages only
            $wingetListOutput = winget list $searchTerm 2>&1 | Out-String
        } else {
            # Search globally available packages
            $wingetListOutput = winget search $searchTerm 2>&1 | Out-String
        }

        # Filter out progress indicators
        $cleanedLines = $wingetListOutput -split "`n" | Where-Object {
            $line = $_
            if (-not $line.Trim()) { return $false }
            if ($line -match '^\s*[\-\\/\|]\s*$') { return $false }
            if ($line.Trim() -match '^[\-\\/\|]$') { return $false }
            return $true
        }

        if ($wingetListOutput -match "No package found" -or $cleanedLines.Count -eq 0) {
            Write-Host "  No matches found" -ForegroundColor Gray
        } else {
            # Parse and sort winget output
            $headerLine = $null
            $separatorLine = $null
            $dataLines = @()
            $footerLines = @()
            $inData = $false

            foreach ($line in $cleanedLines) {
                # Detect header line (contains "Name" and "Id" and "Version")
                if ($line -match 'Name.*Id.*Version' -and -not $headerLine) {
                    $headerLine = $line
                    continue
                }
                # Detect separator line (dashes)
                elseif ($line -match '^-+' -and $headerLine -and -not $separatorLine) {
                    $separatorLine = $line
                    $inData = $true
                    continue
                }
                # Detect footer (upgrade count or other summary)
                elseif ($line -match '^\d+\s+(package|upgrade|installed|available)' -or $line -match 'The following packages') {
                    $inData = $false
                    $footerLines += $line
                }
                # Data lines
                elseif ($inData) {
                    $dataLines += $line
                }
                # Other lines (pre-header or post-footer)
                else {
                    $footerLines += $line
                }
            }

            # Display header
            if ($headerLine) {
                Write-Host $headerLine
            }
            if ($separatorLine) {
                Write-Host $separatorLine
            }

            # Sort data lines alphabetically
            $sortedDataLines = $dataLines | Sort-Object

            if ($searchInstalled) {
                # Just display sorted results for installed search
                foreach ($line in $sortedDataLines) {
                    Write-Host $line
                }
            } else {
                # Highlight installed packages in global search
                foreach ($line in $sortedDataLines) {
                    $isInstalled = $false
                    # Extract package ID from the line
                    $parts = $line -split '\s{2,}' | Where-Object { $_.Trim() -ne '' }
                    if ($parts.Count -ge 2) {
                        $packageId = $parts[1].Trim()
                        if ($installedWinget -contains $packageId) {
                            $isInstalled = $true
                        }
                    }

                    if ($isInstalled) {
                        Write-Host $line -ForegroundColor Green
                    } else {
                        Write-Host $line
                    }
                }
            }

            # Display footer
            foreach ($line in $footerLines) {
                Write-Host $line
            }
        }
    } catch {
        Write-Host "  ⚠️  winget not found or error searching" -ForegroundColor Red
    }

    Write-Host ""
}

function Show-PackageManagerMenu {
    # Define default menu
    $defaultMenu = @(
        (New-MenuAction "Manage Updates" {
            Select-PackagesToUpdate
            pause
        }),
        (New-MenuAction "List Installed Packages" {
            Get-InstalledPackages
            pause
        }),
        (New-MenuAction "Search Packages" {
            Search-Packages
            pause
        })
    )

    # Load menu from config (or use default if not customized)
    $packageMenuItems = Get-MenuFromConfig -MenuTitle "Package Manager" -DefaultMenuItems $defaultMenu

    do {
        $choice = Show-ArrowMenu -MenuItems $packageMenuItems -Title "Package Manager"

        if ($choice -eq -1) {
            Write-Host "Returning to Main Menu..." -ForegroundColor Cyan
            return
        }

        # Execute the selected action
        $selectedAction = $packageMenuItems[$choice]
        & $selectedAction.Action

    } while ($true)
}

# ==========================================
# MENU HELPER FUNCTIONS
# ==========================================

function New-MenuAction {
    param(
        [string]$Text,
        [scriptblock]$Action
    )
    return @{
        Text = $Text
        Action = $Action
    }
}


function Start-InteractivePing {
    param(
        [string]$Target = "google.com"
    )

    Write-Host "Starting continuous ping to $Target..." -ForegroundColor Green
    Write-Host "Press 'Q' to quit and return to menu" -ForegroundColor DarkYellow
    Write-Host ""

    $pingCount = 0

    while ($true) {
        # Check if Q key was pressed
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q') {
                Write-Host ""
                Write-Host "Ping stopped by user." -ForegroundColor Cyan
                break
            }
        }

        try {
            $pingResult = Test-Connection -ComputerName $Target -Count 1 -ErrorAction Stop
            $pingCount++

            $timestamp = Get-Date -Format "HH:mm:ss"
            $ipAddress = $pingResult.Address
            $responseTime = $pingResult.Latency
            $ttl = $pingResult.Reply.Options.Ttl
            Write-Host "[$timestamp] Reply from ${ipAddress}: bytes=32 time=${responseTime}ms TTL=$ttl" -ForegroundColor Green
        }
        catch {
            $timestamp = Get-Date -Format "HH:mm:ss"
            Write-Host "[$timestamp] Request timed out or failed: $($_.Exception.Message)" -ForegroundColor Red
        }

        Start-Sleep -Seconds 1
    }

    Write-Host ""
    Write-Host "Ping completed. Total pings sent: $pingCount" -ForegroundColor Cyan
}

function Show-NetworkConfiguration {
    [CmdletBinding()]
    param()

    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  NETWORK CONFIGURATION                     ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    try {
        # Get all network adapters (including hidden ones)
        # Only get adapters that are physical or virtual (exclude WAN Miniport, etc.)
        $allAdapters = Get-NetAdapter -IncludeHidden | Where-Object {
            $_.InterfaceDescription -notmatch 'WAN Miniport|Kernel Debug|Microsoft Kernel Debug'
        }

        if (-not $allAdapters) {
            Write-Host "No network adapters found." -ForegroundColor Yellow
            return
        }

        # Build table data
        $tableData = @()

        foreach ($netAdapter in $allAdapters) {
            # Try to get IP configuration for this adapter
            # Use a scriptblock with redirection to suppress all output streams
            $ipConfig = $null
            $ipConfig = & {
                $ErrorActionPreference = 'SilentlyContinue'
                Get-NetIPConfiguration -InterfaceIndex $netAdapter.InterfaceIndex
            } 2>&1 | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }

            # Get IP information
            $ipv4 = if ($ipConfig -and $ipConfig.IPv4Address) {
                $ipConfig.IPv4Address[0].IPAddress
            } else {
                "N/A"
            }

            $subnet = if ($ipConfig -and $ipConfig.IPv4Address) {
                $prefixLength = $ipConfig.IPv4Address[0].PrefixLength
                "$(Convert-PrefixToSubnetMask -PrefixLength $prefixLength) (/$prefixLength)"
            } else {
                "N/A"
            }

            $gateway = if ($ipConfig -and $ipConfig.IPv4DefaultGateway) {
                $ipConfig.IPv4DefaultGateway[0].NextHop
            } else {
                "N/A"
            }

            $dns = if ($ipConfig -and $ipConfig.DNSServer) {
                ($ipConfig.DNSServer.ServerAddresses | Select-Object -First 2) -join ", "
            } else {
                "N/A"
            }

            $dhcp = if ($ipConfig -and $ipConfig.NetIPv4Interface.Dhcp -eq "Enabled") {
                "Yes"
            } else {
                "No"
            }

            # Determine IP type for sorting (routable, link-local, or none)
            $ipType = if ($ipv4 -eq "N/A") {
                3  # No IP - lowest priority
            } elseif ($ipv4 -like "169.254.*") {
                2  # Link-local (APIPA) - medium priority
            } else {
                1  # Routable IP - highest priority
            }

            # Status priority (Up = 1, anything else = 2)
            $statusPriority = if ($netAdapter.Status -eq "Up") { 1 } else { 2 }

            $tableData += [PSCustomObject]@{
                Adapter         = $netAdapter.InterfaceAlias
                Status          = $netAdapter.Status
                IPAddress       = $ipv4
                SubnetMask      = $subnet
                Gateway         = $gateway
                DNS             = $dns
                DHCP            = $dhcp
                MAC             = $netAdapter.MacAddress
                LinkSpeed       = $netAdapter.LinkSpeed
                StatusPriority  = $statusPriority
                IPTypePriority  = $ipType
            }
        }

        # Sort by status (Up first), then by IP type (routable first), then by adapter name
        $tableData = $tableData | Sort-Object StatusPriority, IPTypePriority, Adapter

        # Display table with colors
        Write-Host "Network Adapters:" -ForegroundColor Yellow
        Write-Host ""

        # Custom table rendering with colors
        $headers = @("Adapter", "Status", "IP Address", "Subnet Mask", "Gateway", "DNS Servers", "DHCP", "MAC", "Speed")

        # Calculate column widths dynamically based on content
        $colWidths = @{
            Adapter    = [Math]::Max(($tableData.Adapter | Measure-Object -Maximum -Property Length).Maximum, $headers[0].Length)
            Status     = [Math]::Max(($tableData.Status | Measure-Object -Maximum -Property Length).Maximum, $headers[1].Length)
            IPAddress  = [Math]::Max(($tableData.IPAddress | Measure-Object -Maximum -Property Length).Maximum, $headers[2].Length)
            SubnetMask = [Math]::Max(($tableData.SubnetMask | Measure-Object -Maximum -Property Length).Maximum, $headers[3].Length)
            Gateway    = [Math]::Max(($tableData.Gateway | Measure-Object -Maximum -Property Length).Maximum, $headers[4].Length)
            DNS        = [Math]::Max([Math]::Min(($tableData.DNS | Measure-Object -Maximum -Property Length).Maximum, 35), $headers[5].Length)
            DHCP       = [Math]::Max(($tableData.DHCP | Measure-Object -Maximum -Property Length).Maximum, $headers[6].Length)
            MAC        = [Math]::Max(($tableData.MAC | Measure-Object -Maximum -Property Length).Maximum, $headers[7].Length)
            LinkSpeed  = [Math]::Max(($tableData.LinkSpeed | Measure-Object -Maximum -Property Length).Maximum, $headers[8].Length)
        }

        # Calculate total table width
        $totalWidth = $colWidths.Values | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        $totalWidth += ($colWidths.Count - 1) * 1  # Add spaces between columns

        # Header row
        Write-Host ("─" * $totalWidth) -ForegroundColor Cyan
        Write-Host ("{0,-$($colWidths.Adapter)} {1,-$($colWidths.Status)} {2,-$($colWidths.IPAddress)} {3,-$($colWidths.SubnetMask)} {4,-$($colWidths.Gateway)} {5,-$($colWidths.DNS)} {6,-$($colWidths.DHCP)} {7,-$($colWidths.MAC)} {8,-$($colWidths.LinkSpeed)}" -f `
            $headers[0], $headers[1], $headers[2], $headers[3], $headers[4], $headers[5], $headers[6], $headers[7], $headers[8]) -ForegroundColor Yellow
        Write-Host ("─" * $totalWidth) -ForegroundColor Cyan

        # Data rows
        foreach ($row in $tableData) {
            # Adapter name
            Write-Host ("{0,-$($colWidths.Adapter)} " -f $row.Adapter) -NoNewline -ForegroundColor White

            # Status with color
            if ($row.Status -eq "Up") {
                Write-Host ("{0,-$($colWidths.Status)} " -f $row.Status) -NoNewline -ForegroundColor Green
            } else {
                Write-Host ("{0,-$($colWidths.Status)} " -f $row.Status) -NoNewline -ForegroundColor Red
            }

            # IP Address
            Write-Host ("{0,-$($colWidths.IPAddress)} " -f $row.IPAddress) -NoNewline -ForegroundColor Cyan

            # Subnet Mask
            Write-Host ("{0,-$($colWidths.SubnetMask)} " -f $row.SubnetMask) -NoNewline -ForegroundColor White

            # Gateway
            Write-Host ("{0,-$($colWidths.Gateway)} " -f $row.Gateway) -NoNewline -ForegroundColor Cyan

            # DNS (truncate if too long)
            $dnsDisplay = if ($row.DNS.Length -gt $colWidths.DNS) { $row.DNS.Substring(0, $colWidths.DNS - 3) + "..." } else { $row.DNS }
            Write-Host ("{0,-$($colWidths.DNS)} " -f $dnsDisplay) -NoNewline -ForegroundColor Cyan

            # DHCP with color
            if ($row.DHCP -eq "Yes") {
                Write-Host ("{0,-$($colWidths.DHCP)} " -f $row.DHCP) -NoNewline -ForegroundColor Green
            } else {
                Write-Host ("{0,-$($colWidths.DHCP)} " -f $row.DHCP) -NoNewline -ForegroundColor Yellow
            }

            # MAC Address
            Write-Host ("{0,-$($colWidths.MAC)} " -f $row.MAC) -NoNewline -ForegroundColor Gray

            # Link Speed
            Write-Host ("{0,-$($colWidths.LinkSpeed)}" -f $row.LinkSpeed) -ForegroundColor White
        }

        Write-Host ("─" * $totalWidth) -ForegroundColor Cyan
        Write-Host ""

        # System Information
        Write-Host "System Information:" -ForegroundColor Yellow
        Write-Host "  Computer Name: " -NoNewline -ForegroundColor Gray
        Write-Host "$env:COMPUTERNAME" -ForegroundColor White
        Write-Host "  DNS Domain:    " -NoNewline -ForegroundColor Gray
        $dnsDomain = (Get-WmiObject Win32_ComputerSystem).Domain
        Write-Host "$dnsDomain" -ForegroundColor White
        Write-Host ""
    }
    catch {
        Write-Host "Error retrieving network configuration: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Convert-PrefixToSubnetMask {
    param([int]$PrefixLength)

    $mask = ([Math]::Pow(2, 32) - [Math]::Pow(2, (32 - $PrefixLength)))
    $bytes = [BitConverter]::GetBytes([UInt32]$mask)
    [Array]::Reverse($bytes)
    return ($bytes -join '.')
}

function Invoke-TimedPause {
    <#
    .SYNOPSIS
        Pauses execution with an auto-continue timer and option to press Enter to continue immediately.

    .PARAMETER TimeoutSeconds
        Number of seconds to wait before auto-continuing (default: 30)

    .PARAMETER Message
        Custom message to display (default: "Returning to menu")

    .EXAMPLE
        Invoke-TimedPause -TimeoutSeconds 30 -Message "Returning to menu"
    #>
    param(
        [int]$TimeoutSeconds = 30,
        [string]$Message = "Returning to menu"
    )

    Write-Host ""
    $elapsed = 0
    $lastRemaining = $TimeoutSeconds

    # Display initial countdown
    Write-Host "$Message in $TimeoutSeconds seconds (or press Enter to continue now)..." -NoNewline -ForegroundColor Yellow

    while ($elapsed -lt $TimeoutSeconds) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq 'Enter') {
                Write-Host "`r$(' ' * 100)`r$Message..." -ForegroundColor Green
                return
            }
        }
        Start-Sleep -Milliseconds 100
        $elapsed += 0.1

        # Update countdown every second
        $remaining = [Math]::Ceiling($TimeoutSeconds - $elapsed)
        if ($remaining -ne $lastRemaining) {
            $lastRemaining = $remaining
            # Clear line and rewrite
            Write-Host "`r$(' ' * 100)`r$Message in $remaining seconds (or press Enter to continue now)..." -NoNewline -ForegroundColor Yellow
        }
    }

    Write-Host "`r$(' ' * 100)`r$Message..." -ForegroundColor Cyan
}

# ==========================================
# MENU POSITION MEMORY FUNCTIONS
# ==========================================

function Get-SavedMenuPosition {
    <#
    .SYNOPSIS
        Retrieves the last saved menu position for a given menu title.

    .DESCRIPTION
        Returns the last selected index for the specified menu, or 0 if no position is saved.
        This function is designed to be easily expandable to Option 3 (timeout-based memory).

    .PARAMETER Title
        The menu title used as the key for position storage.

    .EXAMPLE
        $position = Get-SavedMenuPosition -Title "Main Menu"
    #>
    param([string]$Title)

    if ($global:MenuPositionMemory.ContainsKey($Title)) {
        return $global:MenuPositionMemory[$Title]
    }
    return 0
}

function Save-MenuPosition {
    <#
    .SYNOPSIS
        Saves the current menu position for a given menu title.

    .DESCRIPTION
        Stores the selected index for the specified menu to remember user's position.
        This function is designed to be easily expandable to Option 3 (timeout-based memory).

    .PARAMETER Title
        The menu title used as the key for position storage.

    .PARAMETER Position
        The index position to save.

    .EXAMPLE
        Save-MenuPosition -Title "Main Menu" -Position 2
    #>
    param(
        [string]$Title,
        [int]$Position
    )

    $global:MenuPositionMemory[$Title] = $Position
}

function Show-ArrowMenu {
    param(
        $MenuItems,  # Can be string[] or object[] with Text property
        [string]$Title = "Please select an option",
        [string[]]$HeaderLines = @()  # Optional header lines to display above menu
    )

    # Restore last position for this menu, or default to 0
    $selectedIndex = Get-SavedMenuPosition -Title $Title
    $key = $null

    do {
        Clear-Host

        # Display optional header lines before the menu
        if ($HeaderLines.Count -gt 0) {
            foreach ($line in $HeaderLines) {
                Write-Host $line
            }
            Write-Host ""
        }

        Write-Host $Title -ForegroundColor Yellow
        Write-Host ('=' * $Title.Length) -ForegroundColor Yellow
        Write-Host ""

        for ($i = 0; $i -lt $MenuItems.Length; $i++) {
            $menuItem = $MenuItems[$i]

            # Handle both string and object menu items
            if ($menuItem -is [string]) {
                $text = $menuItem
            } else {
                $text = $menuItem.Text
            }

            if ($i -eq $selectedIndex) {
                Write-Host "> $text" -ForegroundColor Green
            } else {
                Write-Host "  $text" -ForegroundColor White
            }
        }

        Write-Host ""
        Write-Host "↑↓ navigate | ⏎ select | ⎋ back | ⌃x exit | ⌃␣ move | ⌃r rename" -ForegroundColor Gray

        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            'UpArrow' {
                $selectedIndex = ($selectedIndex - 1 + $MenuItems.Length) % $MenuItems.Length
            }
            'DownArrow' {
                $selectedIndex = ($selectedIndex + 1) % $MenuItems.Length
            }
            'Enter' {
                # Save position before returning
                Save-MenuPosition -Title $Title -Position $selectedIndex
                return $selectedIndex
            }
            'Escape' {
                # Don't save position when going back
                return -1
            }
            'Q' {
                # Don't save position when going back
                return -1
            }
            'X' {
                # Check if Ctrl is pressed
                if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                    Write-Host "`nExiting script. Goodbye!" -ForegroundColor Cyan
                    Start-Sleep -Seconds 1
                    Restore-ConsoleState
                    exit
                }
            }
            'Spacebar' {
                # Check if Ctrl is pressed for move mode
                if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                    # Enter move mode
                    $moveMode = $true
                    $moveIndex = $selectedIndex

                    while ($moveMode) {
                        Clear-Host

                        # Display optional header lines
                        if ($HeaderLines.Count -gt 0) {
                            foreach ($line in $HeaderLines) {
                                Write-Host $line
                            }
                            Write-Host ""
                        }

                        Write-Host "$Title - MOVE MODE" -ForegroundColor Magenta
                        Write-Host ('=' * "$Title - MOVE MODE".Length) -ForegroundColor Magenta
                        Write-Host ""

                        for ($i = 0; $i -lt $MenuItems.Length; $i++) {
                            $menuItem = $MenuItems[$i]
                            $text = if ($menuItem -is [string]) { $menuItem } else { $menuItem.Text }

                            if ($i -eq $moveIndex) {
                                Write-Host "→ $text ←" -ForegroundColor Magenta
                            } else {
                                Write-Host "  $text" -ForegroundColor DarkGray
                            }
                        }

                        Write-Host ""
                        Write-Host "⬆️⬇️move position | ⏎ confirm | ⎋ cancel" -ForegroundColor Yellow

                        $moveKey = [Console]::ReadKey($true)

                        switch ($moveKey.Key) {
                            'UpArrow' {
                                if ($moveIndex -gt 0) {
                                    # Swap items
                                    $temp = $MenuItems[$moveIndex]
                                    $MenuItems[$moveIndex] = $MenuItems[$moveIndex - 1]
                                    $MenuItems[$moveIndex - 1] = $temp
                                    $moveIndex--
                                    $selectedIndex = $moveIndex
                                }
                            }
                            'DownArrow' {
                                if ($moveIndex -lt ($MenuItems.Length - 1)) {
                                    # Swap items
                                    $temp = $MenuItems[$moveIndex]
                                    $MenuItems[$moveIndex] = $MenuItems[$moveIndex + 1]
                                    $MenuItems[$moveIndex + 1] = $temp
                                    $moveIndex++
                                    $selectedIndex = $moveIndex
                                }
                            }
                            'Enter' {
                                $moveMode = $false
                                # Save menu after move
                                if ($Title -eq "Select AWS Account/Environment") {
                                    Save-AwsAccountMenuOrder -MenuItems $MenuItems
                                } else {
                                    Save-Menu -MenuTitle $Title -MenuItems $MenuItems
                                }
                            }
                            'Escape' {
                                $moveMode = $false
                            }
                        }
                    }
                }
            }
            'R' {
                # Check if Ctrl is pressed for rename
                if ($key.Modifiers -band [ConsoleModifiers]::Control) {
                    Clear-Host

                    $currentText = if ($MenuItems[$selectedIndex] -is [string]) {
                        $MenuItems[$selectedIndex]
                    } else {
                        $MenuItems[$selectedIndex].Text
                    }

                    Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Cyan
                    Write-Host "║  RENAME MENU ITEM                          ║" -ForegroundColor Cyan
                    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "Current name: $currentText" -ForegroundColor Yellow
                    Write-Host ""
                    $newName = Read-Host "Enter new name (or press Enter to cancel)"

                    if (-not [string]::IsNullOrWhiteSpace($newName)) {
                        if ($MenuItems[$selectedIndex] -is [string]) {
                            $MenuItems[$selectedIndex] = $newName
                        } else {
                            $MenuItems[$selectedIndex].Text = $newName
                        }

                        # Save menu after rename
                        if ($Title -eq "Select AWS Account/Environment") {
                            # For AWS Account menu, save custom name to environment
                            $item = $MenuItems[$selectedIndex]
                            Save-AwsAccountCustomName -Environment $item.Environment -Role $item.Role -CustomName $newName
                        } else {
                            Save-Menu -MenuTitle $Title -MenuItems $MenuItems
                        }
                    }
                }
            }
        }
    } while ($true)
}

function Start-MerakiBackup {
    Write-Host "Starting Meraki Backup..." -ForegroundColor Green
    Write-Host ""

    # Check if we're in the right directory or if meraki-api folder exists
    $merakiPath = Join-Path $script:Config.paths.workingDirectory "meraki-api"

    if (Test-Path $merakiPath) {
        try {
            Push-Location $merakiPath

            # Check if Python is available
            $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
            if (-not $pythonCmd) {
                Write-Host "Python not found in PATH. Please ensure Python is installed." -ForegroundColor Red
                pause
                return
            }

            # Check if backup.py exists
            if (-not (Test-Path "backup.py")) {
                Write-Host "backup.py not found in meraki-api directory." -ForegroundColor Red
                pause
                return
            }

            # Check if .env file exists
            if (-not (Test-Path ".env")) {
                Write-Host "Warning: .env file not found. Make sure MERAKI_API_KEY is set in environment." -ForegroundColor Yellow
            }

            Write-Host "Executing: python backup.py" -ForegroundColor Cyan
            Write-Host ""

            # Run the backup script
            python backup.py

            Write-Host ""
            Write-Host "Meraki backup completed." -ForegroundColor Green
        }
        catch {
            Write-Host "Error running Meraki backup: $($_.Exception.Message)" -ForegroundColor Red
        }
        finally {
            Pop-Location
        }
    }
    else {
        Write-Host "Meraki API directory not found at: $merakiPath" -ForegroundColor Red
        Write-Host "Please ensure the meraki-api folder exists in the working directory." -ForegroundColor Yellow
    }

    pause
}

function Start-CodeCount {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  CODE LINE COUNTER                         ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    $workingDir = $script:Config.paths.workingDirectory
    $countScriptPath = Join-Path $workingDir "count-lines.py"

    # Check if Python is available
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCmd) {
        Write-Host "Python not found in PATH. Please ensure Python is installed." -ForegroundColor Red
        pause
        return
    }

    # Check if count-lines.py exists
    if (-not (Test-Path $countScriptPath)) {
        Write-Host "count-lines.py not found at: $countScriptPath" -ForegroundColor Red
        pause
        return
    }

    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  1. Count all projects (default)" -ForegroundColor White
    Write-Host "  2. Count specific folder" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "Select option (1-2) or press Enter for default"

    if ($choice -eq "2") {
        Write-Host ""
        Write-Host "Available projects:" -ForegroundColor Yellow
        $devRoot = Split-Path $workingDir -Parent
        Get-ChildItem $devRoot -Directory | Where-Object { $_.Name -notlike ".*" } | ForEach-Object {
            Write-Host "  - $($_.Name)" -ForegroundColor Cyan
        }
        Write-Host ""

        $targetFolder = Read-Host "Enter folder name (or press Enter to cancel)"

        if ([string]::IsNullOrWhiteSpace($targetFolder)) {
            Write-Host "Cancelled." -ForegroundColor Yellow
            pause
            return
        }

        Write-Host ""
        Write-Host "Executing: python $countScriptPath $targetFolder" -ForegroundColor Gray
        Write-Host ""

        python $countScriptPath $targetFolder
    }
    else {
        Write-Host ""
        Write-Host "Executing: python $countScriptPath" -ForegroundColor Gray
        Write-Host ""

        python $countScriptPath
    }

    Write-Host ""
    pause
}

function Start-BackupDevEnvironment {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  BACKUP DEVELOPMENT ENVIRONMENT            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    $workingDir = $script:Config.paths.workingDirectory
    $backupScriptPath = Join-Path $workingDir "backup-dev.ps1"

    # Check if backup-dev.ps1 exists
    if (-not (Test-Path $backupScriptPath)) {
        Write-Host "backup-dev.ps1 not found at: $backupScriptPath" -ForegroundColor Red
        pause
        return
    }

    Write-Host "This will create a timestamped backup of your development environment." -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Continue with backup? (Y/n)"

    if ($confirm.ToLower() -eq "n") {
        Write-Host "Backup cancelled." -ForegroundColor Yellow
        pause
        return
    }

    Write-Host ""
    Write-Host "Executing: $backupScriptPath" -ForegroundColor Gray
    Write-Host ""

    try {
        & $backupScriptPath
        Write-Host ""
        Write-Host "✅ Backup completed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "❌ Error during backup: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    pause
}

function Show-MainMenu {
    # Initialize default connection settings
    $global:awsInstance = $script:Config.defaultConnection.instance
    $global:remoteIP = $script:Config.defaultConnection.remoteIP
    $global:localPort = $script:Config.defaultConnection.localPort
    $global:remotePort = $script:Config.defaultConnection.remotePort

    # Define default menu
    $defaultMenu = @(
        (New-MenuAction "Ping Google" {
            Start-InteractivePing -Target "google.com"
            pause
        }),
        (New-MenuAction "IP Config" {
            Show-NetworkConfiguration
            pause
        }),
        (New-MenuAction "AWS Login" {
            Start-AwsWorkflow
        }),
        (New-MenuAction "PowerShell Profile Edit" {
            Invoke-Expression "code '$($script:Config.paths.profilePath)'"
            pause
        }),
        (New-MenuAction "Okta YAML Edit" {
            Invoke-Expression "code '$($script:Config.paths.oktaYamlPath)'"
            pause
        }),
        (New-MenuAction "Whitelist Links Folder" {
            Invoke-Expression "icacls '$($script:Config.paths.linksPath)' /t /setintegritylevel m"
            pause
        }),
        (New-MenuAction "Meraki Backup" {
            Start-MerakiBackup
        }),
        (New-MenuAction "Code Count" {
            Start-CodeCount
        }),
        (New-MenuAction "Backup Dev Environment" {
            Start-BackupDevEnvironment
        }),
        (New-MenuAction "Package Manager" {
            Show-PackageManagerMenu
        })
    )

    # Load menu from config (or use default if not customized)
    $menuItems = Get-MenuFromConfig -MenuTitle "Main Menu" -DefaultMenuItems $defaultMenu

    do {
        $choice = Show-ArrowMenu -MenuItems $menuItems -Title "Main Menu"

        if ($choice -eq -1) {
            Write-Host "Exiting script. Goodbye!" -ForegroundColor Cyan
            Start-Sleep -Seconds 1
            Restore-ConsoleState
            break
        }

        # Execute the selected action
        $selectedAction = $menuItems[$choice]
        & $selectedAction.Action

    } while ($true)
}

function Start-AwsWorkflow {
    # Step 1: Choose AWS Account/Environment
    Show-AwsAccountMenu
}

function Invoke-AwsAuthentication {
    param(
        [string]$Environment,
        [string]$Region,
        [string]$OktaCommand,
        [string]$ProfileName = $null
    )

    try {
        # Set AWS region for this session
        $env:AWS_DEFAULT_REGION = $Region

        Write-Host "Executing: $OktaCommand" -ForegroundColor Gray

        # Validate command is not empty
        if ([string]::IsNullOrWhiteSpace($OktaCommand)) {
            throw "Okta command is empty or null"
        }

        # Execute directly in current session instead of spawning new process
        Invoke-Expression $OktaCommand

        Write-Host "Authentication completed successfully!" -ForegroundColor Green
        Write-Host "Current AWS Region: $Region" -ForegroundColor Cyan

        # Store current environment context and AWS profile name
        $global:currentAwsEnvironment = $Environment
        $global:currentAwsRegion = $Region
        $global:currentAwsProfile = if ($ProfileName) { $ProfileName } else { $Environment }

        # For manual login, try to get account info
        if ($Environment -eq "manual") {
            try {
                $accountInfo = aws sts get-caller-identity --query "Account" --output text 2>$null
                if ($accountInfo) {
                    Write-Host "Connected to AWS Account: $accountInfo" -ForegroundColor Cyan
                }
            }
            catch {
                # Ignore if we can't get account info
            }
        }

        # Pause to allow user to see any authentication messages/errors
        Write-Host ""
        Write-Host "Continuing to Instance Management (press any key to continue immediately)..." -ForegroundColor Yellow
        Write-Host ""

        # Wait for 5 seconds with spinner and countdown
        $timeout = 5
        $spinnerChars = @('|', '/', '-', '\')
        $spinnerIndex = 0
        $timer = [Diagnostics.Stopwatch]::StartNew()

        while ($timer.Elapsed.TotalSeconds -lt $timeout) {
            if ([Console]::KeyAvailable) {
                $null = [Console]::ReadKey($true)
                break
            }

            # Calculate remaining time
            $remaining = [math]::Ceiling($timeout - $timer.Elapsed.TotalSeconds)

            # Display spinner and countdown
            $spinner = $spinnerChars[$spinnerIndex % 4]
            Write-Host "`r$spinner Continuing in $remaining seconds... " -NoNewline -ForegroundColor Cyan

            $spinnerIndex++
            Start-Sleep -Milliseconds 100
        }
        $timer.Stop()

        # Clear the countdown line
        Write-Host "`r                                        " -NoNewline
        Write-Host "`r" -NoNewline

        # Go directly to Instance Management (AWS Actions menu deprecated)
        Show-InstanceManagementMenu

        # After returning from Instance Management, return to account menu
        return
    }
    catch {
        Write-Host "Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
        pause
        return
    }
}

function Select-AwsRole {
    param(
        [string]$Environment,
        [array]$AvailableRoles,
        [string]$PreferredRole
    )

    Write-Host ""
    Write-Host "Multiple roles available for $Environment" -ForegroundColor Yellow
    Write-Host ""

    # Create menu items for each role
    $roleMenuItems = @()
    foreach ($role in $AvailableRoles) {
        $displayText = if ($role -eq $PreferredRole) {
            "$role (Current Preference)"
        } else {
            $role
        }
        $roleMenuItems += New-MenuAction $displayText { $role }.GetNewClosure()
    }

    $choice = Show-ArrowMenu -MenuItems $roleMenuItems -Title "Select AWS Role"

    if ($choice -eq -1) {
        return $null
    }

    return $AvailableRoles[$choice]
}

function Set-PreferredRole {
    param(
        [string]$Environment,
        [string]$Role
    )

    # Store the selected role preference in config.json
    $configPath = Join-Path $PSScriptRoot "config.json"
    $config = Get-Content $configPath -Raw | ConvertFrom-Json

    if ($config.environments.$Environment.PSObject.Properties['preferredRole']) {
        $config.environments.$Environment.preferredRole = $Role
    } else {
        $config.environments.$Environment | Add-Member -NotePropertyName 'preferredRole' -NotePropertyValue $Role -Force
    }

    # Save back to config.json
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
}

function Start-AwsLoginForAccount {
    param(
        [string]$Environment,
        [string]$Region,
        [string]$PreselectedRole = $null
    )

    Write-Host "Authenticating with AWS Account: $Environment ($Region)" -ForegroundColor Cyan

    # Check if this account has multiple roles configured
    $envConfig = $script:Config.environments.$Environment
    $selectedRole = $PreselectedRole

    # If no role was preselected and account has multiple roles, prompt user
    if (-not $selectedRole -and $envConfig.PSObject.Properties['availableRoles'] -and $envConfig.availableRoles.Count -gt 1) {
        # Multiple roles available - prompt user to select
        $preferredRole = if ($envConfig.PSObject.Properties['preferredRole']) { $envConfig.preferredRole } else { $envConfig.availableRoles[0] }

        $selectedRole = Select-AwsRole -Environment $Environment -AvailableRoles $envConfig.availableRoles -PreferredRole $preferredRole

        if (-not $selectedRole) {
            Write-Host "Role selection cancelled. Returning to menu." -ForegroundColor Yellow
            return
        }

        # If user selected a different role than the current preference, update it
        if ($selectedRole -ne $preferredRole) {
            Set-PreferredRole -Environment $Environment -Role $selectedRole
            Write-Host "✓ Updated preferred role to: $selectedRole" -ForegroundColor Green
        }

        Write-Host "Using role: $selectedRole" -ForegroundColor Cyan
    }
    elseif ($selectedRole) {
        Write-Host "Using role: $selectedRole" -ForegroundColor Cyan
    }

    # Build okta command using the appropriate profile
    $oktaProfile = $null
    if ($selectedRole -and $envConfig.PSObject.Properties['oktaProfileMap']) {
        # Use the role-specific profile from the mapping
        $oktaProfile = $envConfig.oktaProfileMap.$selectedRole
        if ($oktaProfile) {
            Write-Host "Using Okta profile: $oktaProfile" -ForegroundColor Gray
            $oktaCommand = "okta-aws-cli web --profile $oktaProfile"
        } else {
            Write-Host "Warning: No profile mapping found for role $selectedRole, using default profile" -ForegroundColor Yellow
            $oktaCommand = "okta-aws-cli web --profile $Environment"
            $oktaProfile = $Environment
        }
    } else {
        $oktaCommand = "okta-aws-cli web --profile $Environment"
        $oktaProfile = $Environment
    }

    # Add session duration if configured
    if ($envConfig.PSObject.Properties['sessionDuration']) {
        $oktaCommand += " --aws-session-duration $($envConfig.sessionDuration)"
        Write-Host "Using session duration: $($envConfig.sessionDuration)" -ForegroundColor Gray
    }

    Invoke-AwsAuthentication -Environment $Environment -Region $Region -OktaCommand $oktaCommand -ProfileName $oktaProfile
}

function Start-ManualAwsLogin {
    Write-Host "Manual AWS Login - You will select account in browser" -ForegroundColor Cyan

    $oktaCommand = "okta-aws-cli web"
    Invoke-AwsAuthentication -Environment "manual" -Region "unknown" -OktaCommand $oktaCommand
}

function Backup-ConfigFile {
    param([string]$FilePath)

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$FilePath.backup-$timestamp"

    try {
        Copy-Item -Path $FilePath -Destination $backupPath -Force
        return $backupPath
    }
    catch {
        Write-Host "Warning: Could not create backup of $FilePath" -ForegroundColor Yellow
        return $null
    }
}

function Parse-AwsCredentialsFile {
    $credsPath = Join-Path $env:USERPROFILE ".aws\credentials"

    if (-not (Test-Path $credsPath)) {
        Write-Host "AWS credentials file not found at: $credsPath" -ForegroundColor Red
        return @()
    }

    $content = Get-Content $credsPath -Raw
    $profiles = @()

    # Parse profiles from credentials file
    $profileMatches = [regex]::Matches($content, '\[([^\]]+)\]')

    foreach ($match in $profileMatches) {
        $profileName = $match.Groups[1].Value
        $profiles += $profileName
    }

    return $profiles
}

function Get-OktaIdpMapping {
    $oktaYamlPath = $script:Config.paths.oktaYamlPath

    if (-not (Test-Path $oktaYamlPath)) {
        Write-Host "Okta YAML file not found at: $oktaYamlPath" -ForegroundColor Red
        return @{}
    }

    $content = Get-Content $oktaYamlPath -Raw
    $idpMap = @{}

    # Parse IDP mappings: "arn:aws:iam::123456789012:saml-provider/CFA-OKTA-PROD": "friendlyname"
    $idpMatches = [regex]::Matches($content, '"arn:aws:iam::(\d+):saml-provider/[^"]+"\s*:\s*"([^"]+)"')

    foreach ($match in $idpMatches) {
        $accountId = $match.Groups[1].Value
        $friendlyName = $match.Groups[2].Value
        $idpMap[$accountId] = $friendlyName
    }

    return $idpMap
}

function Get-AccountRolesFromProfile {
    param([string]$ProfileName)

    # Try to get account ID and role from the profile by doing a quick STS call
    try {
        $identity = aws sts get-caller-identity --profile $ProfileName --output json 2>$null | ConvertFrom-Json
        if ($identity -and $identity.Arn) {
            # Parse ARN: arn:aws:sts::123456789012:assumed-role/RoleName/session
            if ($identity.Arn -match 'arn:aws:sts::(\d+):assumed-role/([^/]+)/') {
                return @{
                    AccountId = $matches[1]
                    Role = $matches[2]
                    Valid = $true
                }
            }
        }
    }
    catch {
        # Profile might be expired or invalid
    }

    return @{ Valid = $false }
}

function Sync-AwsAccountsFromOkta {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║  SYNC AWS ACCOUNTS FROM OKTA               ║" -ForegroundColor Magenta
    Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Magenta

    Write-Host "This will:" -ForegroundColor Yellow
    Write-Host "  1. Authenticate to Okta and collect all available AWS profiles" -ForegroundColor White
    Write-Host "  2. Parse your AWS credentials to discover accounts and roles" -ForegroundColor White
    Write-Host "  3. Compare with your current config.json" -ForegroundColor White
    Write-Host "  4. Show you what will change" -ForegroundColor White
    Write-Host "  5. Update config.json and okta.yaml (after confirmation)" -ForegroundColor White
    Write-Host ""

    $confirm = Read-Host "Continue with sync? (Y/n)"
    if ($confirm.ToLower() -eq "n") {
        Write-Host "Sync cancelled." -ForegroundColor Yellow
        pause
        return
    }

    # Step 1: Backup current config files
    Write-Host "`n══ Step 1: Backing up configuration files ══" -ForegroundColor Cyan
    $configPath = Join-Path $PSScriptRoot "config.json"
    $oktaYamlPath = $script:Config.paths.oktaYamlPath

    $configBackup = Backup-ConfigFile -FilePath $configPath
    $oktaBackup = Backup-ConfigFile -FilePath $oktaYamlPath

    if ($configBackup) {
        Write-Host "✓ Config backup: $configBackup" -ForegroundColor Green
    }
    if ($oktaBackup) {
        Write-Host "✓ Okta YAML backup: $oktaBackup" -ForegroundColor Green
    }

    # Step 2: Run okta-aws-cli to collect all profiles
    Write-Host "`n══ Step 2: Authenticating to Okta ══" -ForegroundColor Cyan
    Write-Host "Running: okta-aws-cli web --all-profiles --aws-session-duration 3600" -ForegroundColor Gray
    Write-Host "This will open your browser for authentication..." -ForegroundColor Yellow
    Write-Host ""

    # Always use 1-hour session duration to avoid re-authentication
    $oktaOutput = okta-aws-cli web --all-profiles --aws-session-duration 3600 2>&1 | Out-String
    Write-Host $oktaOutput

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: okta-aws-cli failed with exit code $LASTEXITCODE" -ForegroundColor Red
        pause
        return
    }

    # Step 3: Parse okta-aws-cli output to discover accounts
    Write-Host "`n══ Step 3: Parsing Okta output for discovered accounts ══" -ForegroundColor Cyan

    # Get IDP mappings from okta.yaml
    $idpMap = Get-OktaIdpMapping

    # Parse "Updated profile" lines from okta output
    # Example: Updated profile "entitynetworkhubprod-CFA-OKTA-PROD-Admin" in credentials file
    $discoveredAccounts = @{}
    $profileMatches = [regex]::Matches($oktaOutput, 'Updated profile "([^"]+)"')

    Write-Host "Found $($profileMatches.Count) profile(s) from Okta" -ForegroundColor Green
    Write-Host ""

    foreach ($match in $profileMatches) {
        $profileName = $match.Groups[1].Value

        # Parse profile name format: friendlyname-CFA-OKTA-PROD-RoleName
        # or: friendlyname-CFA-OKTA-PROD-RoleName
        if ($profileName -match '^(.+?)-CFA-OKTA-PROD-(.+)$') {
            $friendlyName = $matches[1]
            $roleName = $matches[2]

            # Try to find account ID from okta.yaml idps section (reverse lookup with normalization)
            # $idpMap is @{ accountId => friendlyName }, so we need to find the key by value
            # Normalize both sides by removing hyphens/underscores and lowercasing
            $accountId = $null
            $normalizedFriendly = ($friendlyName -replace '-', '' -replace '_', '').ToLower()

            foreach ($acctId in $idpMap.Keys) {
                $normalizedMapName = ($idpMap[$acctId] -replace '-', '' -replace '_', '').ToLower()
                if ($normalizedMapName -eq $normalizedFriendly) {
                    $accountId = $acctId
                    # Use the friendly name from okta.yaml (preferred naming)
                    $friendlyName = $idpMap[$acctId]
                    break
                }
            }

            if (-not $accountId) {
                # Try to get account ID from AWS credentials file
                try {
                    $identity = aws sts get-caller-identity --profile $profileName --output json 2>$null | ConvertFrom-Json
                    if ($identity -and $identity.Account) {
                        $accountId = $identity.Account
                        Write-Host "  Discovered account ID from credentials: $friendlyName ($accountId) - Role: $roleName" -ForegroundColor Cyan

                        # Add to IDP map for future use
                        $idpMap[$accountId] = $friendlyName
                    } else {
                        Write-Host "  Warning: Could not determine account ID for profile: $profileName" -ForegroundColor Yellow
                        continue
                    }
                } catch {
                    Write-Host "  Warning: Could not determine account ID for profile: $profileName" -ForegroundColor Yellow
                    continue
                }
            }

            if (-not $discoveredAccounts.ContainsKey($accountId)) {
                $discoveredAccounts[$accountId] = @{
                    FriendlyName = $friendlyName
                    Profiles = @()
                    Roles = @()
                }
            }

            $discoveredAccounts[$accountId].Profiles += $profileName
            if ($discoveredAccounts[$accountId].Roles -notcontains $roleName) {
                $discoveredAccounts[$accountId].Roles += $roleName
            }

            Write-Host "  Discovered: $friendlyName ($accountId) - Role: $roleName" -ForegroundColor Green
        }
    }

    # Step 4: Show discovered accounts summary
    Write-Host "`n══ Step 4: Discovered Accounts Summary ══" -ForegroundColor Cyan
    Write-Host ""

    foreach ($accountId in $discoveredAccounts.Keys) {
        $info = $discoveredAccounts[$accountId]
        Write-Host "Account $accountId ($($info.FriendlyName))`:" -ForegroundColor Yellow
        Write-Host "  Roles: $($info.Roles -join ', ')" -ForegroundColor White
        Write-Host "  Profiles: $($info.Profiles -join ', ')" -ForegroundColor Gray
        Write-Host ""
    }

    # Step 5: Compare with existing config and update
    Write-Host "`n══ Step 5: Updating configuration files ══" -ForegroundColor Cyan
    Write-Host ""

    # Load current config (IDP mappings already loaded earlier)
    $config = Get-Content $configPath -Raw | ConvertFrom-Json

    # Track changes
    $newAccounts = @()
    $updatedAccounts = @()

    # Process each discovered account
    foreach ($accountId in $discoveredAccounts.Keys) {
        $info = $discoveredAccounts[$accountId]

        # Use friendly name from discovered accounts
        $friendlyName = $info.FriendlyName

        # Try to find existing environment for this account
        $existingEnv = $null
        $wrongKeyEnv = $null
        $matchByName = $null

        foreach ($envKey in $config.environments.PSObject.Properties.Name) {
            $env = $config.environments.$envKey
            if ($env.PSObject.Properties['accountId'] -and $env.accountId -eq $accountId) {
                $existingEnv = $envKey
                # Check if the key name needs to be updated to match Okta friendly name
                if ($envKey -ne $friendlyName) {
                    $wrongKeyEnv = $envKey
                }
                break
            }
        }

        # If not found by accountId, try to find by matching the friendly name pattern
        # (handles cases where old entry exists without accountId)
        if (-not $existingEnv) {
            foreach ($envKey in $config.environments.PSObject.Properties.Name) {
                # Check if the key is similar to friendly name (case-insensitive, ignore hyphens)
                $normalizedKey = ($envKey -replace '-', '' -replace '_', '').ToLower()
                $normalizedFriendly = ($friendlyName -replace '-', '' -replace '_', '').ToLower()

                if ($normalizedKey -eq $normalizedFriendly) {
                    $matchByName = $envKey
                    break
                }
            }
        }

        # Check for duplicate entries - ALWAYS check for normalized name matches
        $duplicateEntry = $null
        $normalizedFriendly = ($friendlyName -replace '-', '' -replace '_', '').ToLower()

        foreach ($envKey in $config.environments.PSObject.Properties.Name) {
            # Skip the entry we already found (if any)
            if ($existingEnv -and $envKey -eq $existingEnv) {
                continue
            }

            # Check for normalized name match
            $normalizedKey = ($envKey -replace '-', '' -replace '_', '').ToLower()
            if ($normalizedKey -eq $normalizedFriendly) {
                $duplicateEntry = $envKey
                break
            }
        }

        # If we found an account with wrong key name, rename it
        if ($wrongKeyEnv) {
            Write-Host "  Renaming account $accountId from '$wrongKeyEnv' to '$friendlyName'" -ForegroundColor Yellow

            # Check if target name already exists (might be a duplicate without accountId)
            $targetExists = $config.environments.PSObject.Properties[$friendlyName]

            if ($targetExists) {
                # Merge: Keep the one with more data, add accountId and roles to it
                Write-Host "    Merging with existing '$friendlyName' entry" -ForegroundColor Gray

                # Add accountId if missing
                if (-not $config.environments.$friendlyName.PSObject.Properties['accountId']) {
                    $config.environments.$friendlyName | Add-Member -NotePropertyName 'accountId' -NotePropertyValue $accountId -Force
                }

                # Add roles if missing
                if (-not $config.environments.$friendlyName.PSObject.Properties['availableRoles']) {
                    $config.environments.$friendlyName | Add-Member -NotePropertyName 'availableRoles' -NotePropertyValue $info.Roles -Force
                    $config.environments.$friendlyName | Add-Member -NotePropertyName 'preferredRole' -NotePropertyValue $info.Roles[0] -Force
                }

                # Add profile map if missing
                if (-not $config.environments.$friendlyName.PSObject.Properties['oktaProfileMap']) {
                    $config.environments.$friendlyName | Add-Member -NotePropertyName 'oktaProfileMap' -NotePropertyValue @{} -Force
                }

                foreach ($role in $info.Roles) {
                    $profileName = $info.Profiles | Where-Object { $_ -match $role } | Select-Object -First 1
                    if ($profileName) {
                        $config.environments.$friendlyName.oktaProfileMap[$role] = $profileName
                    }
                }

                # Remove the old wrong-key entry
                $config.environments.PSObject.Properties.Remove($wrongKeyEnv)
                $updatedAccounts += $friendlyName
            }
            else {
                # Rename: Just change the key name
                $oldEnv = $config.environments.$wrongKeyEnv
                $config.environments | Add-Member -NotePropertyName $friendlyName -NotePropertyValue $oldEnv -Force
                $config.environments.PSObject.Properties.Remove($wrongKeyEnv)

                # Update display name
                $displayName = $friendlyName -creplace '([a-z])([A-Z])', '$1 $2' `
                    -replace '-', ' ' `
                    -replace '\b\w', { $_.Value.ToUpper() }
                $config.environments.$friendlyName.displayName = $displayName

                $updatedAccounts += $friendlyName
            }

            $existingEnv = $friendlyName
        }
        # If we found a duplicate (same account ID exists with different key), merge them
        elseif ($duplicateEntry) {
            Write-Host "  Merging duplicate entries for account $accountId" -ForegroundColor Yellow

            # Always prefer the entry that matches the Okta friendly name
            $keepEntry = $null
            $removeEntry = $null

            if ($existingEnv -eq $friendlyName) {
                # existingEnv matches Okta name - keep it
                $keepEntry = $existingEnv
                $removeEntry = $duplicateEntry
            }
            elseif ($duplicateEntry -eq $friendlyName) {
                # duplicateEntry matches Okta name - keep it
                $keepEntry = $duplicateEntry
                $removeEntry = $existingEnv
            }
            else {
                # Neither matches exactly, keep the one closer to friendlyName
                $keepEntry = $existingEnv
                $removeEntry = $duplicateEntry
            }

            Write-Host "    Keeping '$keepEntry' (matches Okta name) and removing '$removeEntry'" -ForegroundColor Gray

            # Merge configuration from removeEntry into keepEntry
            $keep = $config.environments.$keepEntry
            $remove = $config.environments.$removeEntry

            # Preserve better display name, boxes, instances from either entry
            if (-not $keep.displayName -or $keep.displayName -like "*$accountId*") {
                if ($remove.displayName -and $remove.displayName -notlike "*$accountId*") {
                    $keep.displayName = $remove.displayName
                }
            }

            # Merge boxes if the one being removed has more
            if ($remove.boxes.Count -gt $keep.boxes.Count) {
                $keep.boxes = $remove.boxes
            }

            # Merge instances - take any that aren't empty
            if ($remove.PSObject.Properties['instances']) {
                foreach ($instKey in $remove.instances.PSObject.Properties.Name) {
                    $removeValue = $remove.instances.$instKey
                    $keepValue = if ($keep.instances.PSObject.Properties[$instKey]) { $keep.instances.$instKey } else { $null }

                    if ($removeValue -and -not $keepValue) {
                        # Add the property if it doesn't exist
                        if (-not $keep.instances.PSObject.Properties[$instKey]) {
                            $keep.instances | Add-Member -NotePropertyName $instKey -NotePropertyValue $removeValue -Force
                        } else {
                            $keep.instances.$instKey = $removeValue
                        }
                    }
                }
            }

            # Merge actions if the one being removed has more
            if ($remove.actions.Count -gt $keep.actions.Count) {
                $keep.actions = $remove.actions
            }

            # Remove the duplicate entry
            $config.environments.PSObject.Properties.Remove($removeEntry)
            $updatedAccounts += $keepEntry
            $existingEnv = $keepEntry
        }
        # If we found a match by name (without accountId), update it
        elseif ($matchByName) {
            Write-Host "  Updating account $accountId - adding accountId to existing '$matchByName' entry" -ForegroundColor Yellow

            # Add accountId
            $config.environments.$matchByName | Add-Member -NotePropertyName 'accountId' -NotePropertyValue $accountId -Force

            # Add roles if missing
            if (-not $config.environments.$matchByName.PSObject.Properties['availableRoles']) {
                $config.environments.$matchByName | Add-Member -NotePropertyName 'availableRoles' -NotePropertyValue $info.Roles -Force
                $config.environments.$matchByName | Add-Member -NotePropertyName 'preferredRole' -NotePropertyValue $info.Roles[0] -Force
            }

            # Set session duration to 1 hour for all synced accounts
            if (-not $config.environments.$matchByName.PSObject.Properties['sessionDuration']) {
                $config.environments.$matchByName | Add-Member -NotePropertyName 'sessionDuration' -NotePropertyValue "3600" -Force
            }

            # Add profile map if missing
            if (-not $config.environments.$matchByName.PSObject.Properties['oktaProfileMap']) {
                $config.environments.$matchByName | Add-Member -NotePropertyName 'oktaProfileMap' -NotePropertyValue @{} -Force
            }

            foreach ($role in $info.Roles) {
                $profileName = $info.Profiles | Where-Object { $_ -match $role } | Select-Object -First 1
                if ($profileName) {
                    $config.environments.$matchByName.oktaProfileMap[$role] = $profileName
                }
            }

            $updatedAccounts += $matchByName
            $existingEnv = $matchByName
        }

        if ($existingEnv -and -not $wrongKeyEnv -and -not $matchByName) {
            # Account exists - check if it needs updating
            $needsUpdate = $false

            # Check for role updates
            $currentRoles = if ($config.environments.$existingEnv.PSObject.Properties['availableRoles']) {
                $config.environments.$existingEnv.availableRoles
            } else {
                @()
            }

            $newRoles = $info.Roles | Where-Object { $_ -notin $currentRoles }

            if ($newRoles.Count -gt 0) {
                Write-Host "  Updating account $accountId ($existingEnv) - adding roles: $($newRoles -join ', ')" -ForegroundColor Yellow
                $needsUpdate = $true

                # Update available roles
                $allRoles = @($currentRoles) + @($newRoles) | Sort-Object -Unique
                $config.environments.$existingEnv.availableRoles = $allRoles
            } else {
                $allRoles = $currentRoles
            }

            # Always ensure oktaProfileMap exists and has entries for ALL roles
            if (-not $config.environments.$existingEnv.PSObject.Properties['oktaProfileMap']) {
                $config.environments.$existingEnv | Add-Member -NotePropertyName 'oktaProfileMap' -NotePropertyValue @{} -Force
            }

            # Check for missing profile mappings
            $missingMappings = @()
            foreach ($role in $allRoles) {
                $hasMapping = $config.environments.$existingEnv.oktaProfileMap.PSObject.Properties[$role]
                if (-not $hasMapping) {
                    $profileName = $info.Profiles | Where-Object { $_ -match $role } | Select-Object -First 1
                    if ($profileName) {
                        $config.environments.$existingEnv.oktaProfileMap | Add-Member -NotePropertyName $role -NotePropertyValue $profileName -Force
                        $missingMappings += $role
                        $needsUpdate = $true
                    }
                }
            }

            if ($missingMappings.Count -gt 0) {
                Write-Host "  Added missing profile mappings for roles: $($missingMappings -join ', ')" -ForegroundColor Yellow
            }

            # Update display name from Okta friendly name if needed
            $oktaDisplayName = $friendlyName -creplace '([a-z])([A-Z])', '$1 $2' `
                -replace '-', ' ' `
                -replace '\b\w', { $_.Value.ToUpper() }

            $currentDisplayName = if ($config.environments.$existingEnv.PSObject.Properties['displayName']) {
                $config.environments.$existingEnv.displayName
            } else {
                ""
            }

            if ($currentDisplayName -ne $oktaDisplayName) {
                Write-Host "  Updating display name for $existingEnv from '$currentDisplayName' to '$oktaDisplayName'" -ForegroundColor Yellow
                $config.environments.$existingEnv.displayName = $oktaDisplayName
                $needsUpdate = $true
            }

            # Set session duration to 1 hour for all synced accounts
            if (-not $config.environments.$existingEnv.PSObject.Properties['sessionDuration'] -or
                $config.environments.$existingEnv.sessionDuration -ne "3600") {
                if (-not $config.environments.$existingEnv.PSObject.Properties['sessionDuration']) {
                    $config.environments.$existingEnv | Add-Member -NotePropertyName 'sessionDuration' -NotePropertyValue "3600" -Force
                } else {
                    $config.environments.$existingEnv.sessionDuration = "3600"
                }
                $needsUpdate = $true
            }

            if ($needsUpdate) {
                $updatedAccounts += $existingEnv
            }
            else {
                Write-Host "  Account $accountId ($existingEnv) - already up to date" -ForegroundColor Green
            }
        }
        else {
            # New account - create entry with friendly name
            $envName = $friendlyName
            Write-Host "  New account discovered: $accountId - '$friendlyName' (creating as $envName)" -ForegroundColor Cyan

            # Convert friendly name to display name (capitalize words, add spaces)
            $displayName = $friendlyName -creplace '([a-z])([A-Z])', '$1 $2' `
                -replace '-', ' ' `
                -replace '\b\w', { $_.Value.ToUpper() }

            # Create basic environment entry
            $newEnv = @{
                displayName = $displayName
                region = "us-east-1"
                accountId = $accountId
                availableRoles = $info.Roles
                preferredRole = $info.Roles[0]
                oktaProfileMap = @{}
                defaultRemoteIP = ""
                defaultRemotePort = ""
                defaultLocalPort = ""
                instances = @{
                    "jump-box" = ""
                }
                boxes = @()
                actions = @("instanceManagement")
            }

            # Set session duration to 1 hour for all synced accounts
            $newEnv.sessionDuration = "3600"

            # Create profile map
            foreach ($role in $info.Roles) {
                $profileName = $info.Profiles | Where-Object { $_ -match $role } | Select-Object -First 1
                if ($profileName) {
                    $newEnv.oktaProfileMap[$role] = $profileName
                }
            }

            # Add to config
            $config.environments | Add-Member -NotePropertyName $envName -NotePropertyValue $newEnv -Force
            $newAccounts += @{
                Name = $envName
                DisplayName = $displayName
            }
        }
    }

    # Update okta.yaml profiles to match discovered accounts
    Write-Host "`n══ Step 6: Updating okta.yaml profiles ══" -ForegroundColor Cyan
    Write-Host ""

    $oktaYamlContent = Get-Content $oktaYamlPath -Raw
    $profilesAdded = @()

    foreach ($accountId in $discoveredAccounts.Keys) {
        $info = $discoveredAccounts[$accountId]
        $friendlyName = $info.FriendlyName

        foreach ($profileName in $info.Profiles) {
            # Check if profile already exists in okta.yaml
            if ($oktaYamlContent -notmatch "^\s+${profileName}:") {
                # Extract role from profile name: friendlyname-CFA-OKTA-PROD-RoleName
                if ($profileName -match '-CFA-OKTA-PROD-(.+)$') {
                    $roleName = $matches[1]

                    # Create profile entry
                    $profileEntry = @"

    ${profileName}:
      aws-iam-idp: "arn:aws:iam::${accountId}:saml-provider/CFA-OKTA-PROD"
      aws-iam-role: "arn:aws:iam::${accountId}:role/${roleName}"
      aws-session-duration: 3600
"@
                    $oktaYamlContent = $oktaYamlContent.TrimEnd() + $profileEntry + "`n"
                    $profilesAdded += $profileName
                    Write-Host "  ✓ Added profile: $profileName" -ForegroundColor Green
                }
            }
        }
    }

    if ($profilesAdded.Count -gt 0) {
        Write-Host ""
        Write-Host "Saving changes to okta.yaml..." -ForegroundColor Yellow
        Set-Content -Path $oktaYamlPath -Value $oktaYamlContent -Encoding UTF8
        Write-Host "✓ Okta.yaml updated with $($profilesAdded.Count) new profile(s)" -ForegroundColor Green
    } else {
        Write-Host "  No new profiles needed in okta.yaml" -ForegroundColor Green
    }

    # Save updated config.json
    if ($newAccounts.Count -gt 0 -or $updatedAccounts.Count -gt 0) {
        Write-Host ""
        Write-Host "Saving changes to config.json..." -ForegroundColor Yellow

        # Remove the old menu-based persistence for AWS accounts (no longer used)
        if ($config.PSObject.Properties['menus'] -and
            $config.menus.PSObject.Properties['Select AWS Account/Environment']) {
            $config.menus.PSObject.Properties.Remove('Select AWS Account/Environment')
            Write-Host "  - Removed deprecated AWS account menu data" -ForegroundColor Gray
        }

        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
        Write-Host "✓ Config.json updated" -ForegroundColor Green

        Write-Host ""
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
        Write-Host "Summary of Changes:" -ForegroundColor Yellow
        if ($newAccounts.Count -gt 0) {
            Write-Host "  New Accounts Added: $($newAccounts.Count)" -ForegroundColor Cyan
            foreach ($acc in $newAccounts) {
                Write-Host "    - $($acc.DisplayName) ($($acc.Name))" -ForegroundColor White
            }
        }
        if ($updatedAccounts.Count -gt 0) {
            Write-Host "  Accounts Updated: $($updatedAccounts.Count)" -ForegroundColor Cyan
            foreach ($acc in $updatedAccounts) {
                Write-Host "    - $acc" -ForegroundColor White
            }
        }
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
        Write-Host ""

        # Reload configuration
        Update-ScriptConfiguration

        Write-Host "✓ Account list has been updated and reloaded!" -ForegroundColor Green
        Write-Host ""
    }
    else {
        Write-Host "No changes needed - all accounts are up to date." -ForegroundColor Green
        Write-Host ""
    }

    pause
}

function Show-AwsAccountMenu {
    # Helper function to create a menu item for an environment+role
    function New-AwsAccountMenuItem {
        param($envKey, $env, $role = $null)

        $friendlyName = $envKey
        $accountId = if ($env.PSObject.Properties['accountId']) { $env.accountId } else { "" }

        # Check for custom display name first
        $customName = Get-AwsAccountCustomName -Environment $envKey -Role $role

        if ($customName) {
            # Use custom name as-is
            $displayText = $customName
        } else {
            # Build default display text
            if ($role) {
                $displayText = if ($accountId) {
                    "$friendlyName ($accountId) - Role: $role"
                } else {
                    "$friendlyName - Role: $role"
                }
            } else {
                $displayText = if ($accountId) {
                    "$friendlyName ($accountId)"
                } else {
                    $env.displayName
                }
            }
        }

        return @{
            Text = $displayText
            HighlightPos = 0
            HighlightChar = $friendlyName[0]
            Environment = $envKey
            Region = $env.region
            Role = $role
        }
    }

    # Build a hashtable for quick lookup of all items by env:role key
    $allItemsLookup = @{}
    $specialItems = @()

    foreach ($envKey in $script:Config.environments.PSObject.Properties.Name) {
        $env = $script:Config.environments.$envKey

        # Skip manual - it will be added at the end
        if ($envKey -eq "manual") {
            $customName = Get-AwsAccountCustomName -Environment $envKey -Role $null
            $specialItems += @{
                Text = if ($customName) { $customName } else { $env.displayName }
                HighlightPos = $env.highlightPos
                HighlightChar = $env.highlightChar
                Environment = $envKey
                Region = $env.region
                Role = $null
            }
            continue
        }

        # Check if account has multiple roles
        if ($env.PSObject.Properties['availableRoles'] -and $env.availableRoles.Count -gt 0) {
            # Create a menu item for each role
            foreach ($role in $env.availableRoles) {
                $item = New-AwsAccountMenuItem -envKey $envKey -env $env -role $role
                $lookupKey = "${envKey}:${role}"
                $allItemsLookup[$lookupKey] = $item
            }
        } else {
            # No roles defined - create single item with account name
            $item = New-AwsAccountMenuItem -envKey $envKey -env $env
            $lookupKey = $envKey
            $allItemsLookup[$lookupKey] = $item
        }
    }

    # Build the final menu in the correct order
    $accountItems = @()
    $savedOrder = Get-AwsAccountMenuOrder

    if ($savedOrder) {
        # Use saved order
        foreach ($key in $savedOrder) {
            if ($allItemsLookup.ContainsKey($key)) {
                $accountItems += $allItemsLookup[$key]
                # Remove from lookup so we can add any new items at the end
                $allItemsLookup.Remove($key)
            }
        }

        # Add any new items that weren't in the saved order (sorted alphabetically)
        if ($allItemsLookup.Count -gt 0) {
            $newItems = $allItemsLookup.Values | Sort-Object -Property { $_['Text'] }
            $accountItems += $newItems
        }
    } else {
        # No saved order - use default alphabetical sort
        $accountItems = $allItemsLookup.Values | Sort-Object -Property { $_['Text'] }
    }

    # Add special items at the end
    $accountItems += $specialItems

    # Add sync option at the very end
    $accountItems += @{
        Text = "═══ Sync AWS Accounts from Okta ═══"
        HighlightPos = 0
        HighlightChar = "S"
        Environment = "sync"
        Region = ""
        Role = $null
    }

    do {
        $choice = Show-ArrowMenu -MenuItems $accountItems -Title "Select AWS Account/Environment"

        if ($choice -eq -1) {
            Write-Host "Returning to Main Menu..." -ForegroundColor Cyan
            return
        }

        $selectedAccount = $accountItems[$choice]

        if ($selectedAccount.Environment -eq "sync") {
            Sync-AwsAccountsFromOkta
            # Continue loop to return to AWS menu after sync
            continue
        }
        elseif ($selectedAccount.Environment -eq "manual") {
            Start-ManualAwsLogin
            # Continue loop to return to AWS menu after manual login
            continue
        }
        else {
            # Pass the role to the login function
            Start-AwsLoginForAccount -Environment $selectedAccount.Environment -Region $selectedAccount.Region -PreselectedRole $selectedAccount.Role
            # Continue loop to return to AWS menu after authentication/actions
            continue
        }
    } while ($true)
}

function Start-CommandPrompt {
    Write-Host "Dropping to command prompt. Type 'exit' to return." -ForegroundColor Yellow
    Invoke-Expression "pwsh -noe -wd '$($script:Config.paths.workingDirectory)'"
}

function Get-CurrentInstanceId {
    param([string]$InstanceType = "jump-box")

    # Check if there's a per-account override set
    if ($global:currentAwsEnvironment -and $global:accountDefaultInstances.ContainsKey($global:currentAwsEnvironment)) {
        $accountDefault = $global:accountDefaultInstances[$global:currentAwsEnvironment]
        if ($accountDefault.ContainsKey($InstanceType)) {
            return $accountDefault[$InstanceType]
        }
    }

    # Otherwise fall back to configuration - build configs inline
    $configs = @{}

    # Build configurations from JSON config
    foreach ($envKey in $script:Config.environments.PSObject.Properties.Name) {
        $env = $script:Config.environments.$envKey
        $configs[$envKey] = @{}

        foreach ($instanceKey in $env.instances.PSObject.Properties.Name) {
            $configs[$envKey][$instanceKey] = $env.instances.$instanceKey
        }
    }

    # Add default fallback
    $configs["default"] = @{
        "jump-box" = $script:Config.defaultConnection.instance
    }

    # Use the built configs
    if ($global:currentAwsEnvironment -and $configs.ContainsKey($global:currentAwsEnvironment)) {
        $envConfig = $configs[$global:currentAwsEnvironment]
        if ($envConfig.ContainsKey($InstanceType)) {
            return $envConfig[$InstanceType]
        } else {
            # Default to first available instance in environment
            return $envConfig.Values | Select-Object -First 1
        }
    } else {
        return $configs["default"]["jump-box"]
    }
}

function Get-CurrentDefaultRemoteIP {
    # Get the default RemoteIP from the current environment's config
    if ($global:currentAwsEnvironment -and $script:Config.environments.PSObject.Properties[$global:currentAwsEnvironment]) {
        $envConfig = $script:Config.environments.$global:currentAwsEnvironment
        if ($envConfig.defaultRemoteIP) {
            return $envConfig.defaultRemoteIP
        }
    }
    return $null
}

function Start-AlohaRemoteAccess {
    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  ALOHA REMOTE ACCESS                       ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    # Display current instance settings using the shared function (without pause)
    Write-Host "Current Instance Settings:" -ForegroundColor Cyan
    Write-Host "  Environment: $global:currentAwsEnvironment" -ForegroundColor White
    Write-Host "  Region: $global:currentAwsRegion" -ForegroundColor White

    # Get default instance ID and name
    $defaultInstanceId = Get-CurrentInstanceId
    if ($defaultInstanceId) {
        $defaultInstanceName = Get-InstanceNameById -InstanceId $defaultInstanceId
        if ($defaultInstanceName) {
            Write-Host "  Instance ID: $defaultInstanceId ($defaultInstanceName)" -ForegroundColor White
        } else {
            Write-Host "  Instance ID: $defaultInstanceId" -ForegroundColor White
        }
    } else {
        Write-Host "  Instance ID: (not configured)" -ForegroundColor DarkGray
    }

    # Get current configuration
    $envConfig = $script:Config.environments.$global:currentAwsEnvironment

    # Display remote host configuration if available
    Write-Host ""
    Write-Host "Default Remote Host Info:" -ForegroundColor Cyan

    # Get remote host instance ID
    $remoteHostInstanceId = ""
    if ($envConfig.instances.PSObject.Properties['remote-host']) {
        $remoteHostInstanceId = $envConfig.instances.'remote-host'
    }

    $hasConfig = $false
    if ($remoteHostInstanceId) {
        $remoteHostInstanceName = Get-InstanceNameById -InstanceId $remoteHostInstanceId
        if ($remoteHostInstanceName) {
            Write-Host "  Remote Host Instance ID: $remoteHostInstanceId ($remoteHostInstanceName)" -ForegroundColor White
        } else {
            Write-Host "  Remote Host Instance ID: $remoteHostInstanceId" -ForegroundColor White
        }
        $hasConfig = $true
    } else {
        Write-Host "  Remote Host Instance ID: (not configured)" -ForegroundColor DarkGray
    }

    $remoteIP = if ($envConfig.PSObject.Properties['defaultRemoteIP']) { $envConfig.defaultRemoteIP } else { "" }
    $remotePort = if ($envConfig.PSObject.Properties['defaultRemotePort']) { $envConfig.defaultRemotePort } else { "" }
    $localPort = if ($envConfig.PSObject.Properties['defaultLocalPort']) { $envConfig.defaultLocalPort } else { "" }

    if ($remoteIP) {
        Write-Host "  Remote IP: $remoteIP" -ForegroundColor White
    } else {
        Write-Host "  Remote IP: (not configured)" -ForegroundColor DarkGray
    }

    if ($remotePort) {
        Write-Host "  Remote Port: $remotePort" -ForegroundColor White
    } else {
        Write-Host "  Remote Port: (not configured)" -ForegroundColor DarkGray
    }

    if ($localPort) {
        Write-Host "  Local Port: $localPort" -ForegroundColor White
    } else {
        Write-Host "  Local Port: (not configured)" -ForegroundColor DarkGray
    }

    Write-Host ""

    # Check if configuration exists
    if (-not $hasConfig -or -not $remoteIP -or -not $remotePort -or -not $localPort) {
        Write-Host "Remote host configuration is incomplete." -ForegroundColor Yellow
        Write-Host "You need to set the default remote host info first." -ForegroundColor Yellow
        Write-Host ""
        $configure = Read-Host "Configure remote host settings now? (Y/n)"
        if ($configure.ToLower() -ne "n") {
            Set-DefaultRemoteHostInfo
            # Restart this function to show updated settings
            Start-AlohaRemoteAccess
            return
        } else {
            Write-Host "Cannot proceed without remote host configuration." -ForegroundColor Red
            pause
            return
        }
    }

    # Prompt to use current settings or modify
    $useSettings = Read-Host "Use these settings? (Y/n/m to modify)"

    if ($useSettings.ToLower() -eq "n") {
        Write-Host "Aloha remote access cancelled." -ForegroundColor Yellow
        pause
        return
    }

    if ($useSettings.ToLower() -eq "m") {
        Write-Host ""
        Set-DefaultRemoteHostInfo
        # Restart this function to show updated settings
        Start-AlohaRemoteAccess
        return
    }

    # Set global variables for aloha connection
    # Use the default instance ID for SSM connection, and remote IP for port forwarding target
    $global:awsInstance = $defaultInstanceId
    $global:remoteIP = $remoteIP
    $global:remotePort = $remotePort
    $global:localPort = $localPort

    # Ask if this is an RDP connection (default to Yes)
    Write-Host ""
    $isRdp = Read-Host "Is this an RDP connection? (Y/n)"
    $isRdpBool = $isRdp.ToLower() -ne "n"

    # Start the Aloha connection
    Start-AlohaConnection -IsRdp $isRdpBool
}

function Show-InstanceManagementMenu {
    # Define default menu
    $defaultMenu = @(
        (New-MenuAction "List Running Instances" { Get-RunningInstances }),
        (New-MenuAction "Set Default Instance ID" { Set-DefaultInstanceId }),
        (New-MenuAction "Set Default Remote Host Info" { Set-DefaultRemoteHostInfo }),
        (New-MenuAction "View Current Instance Settings" { Show-CurrentInstanceSettings }),
        (New-MenuAction "Test Instance Connectivity" { Test-InstanceConnectivity }),
        (New-MenuAction "Get VPN Connections" { Get-VpnConnections }),
        (New-MenuAction "Aloha Remote Access" { Start-AlohaRemoteAccess })
    )

    # Load menu from config (or use default if not customized)
    $instanceItems = Get-MenuFromConfig -MenuTitle "Instance Management" -DefaultMenuItems $defaultMenu

    do {
        # Build AWS context header
        $headerLines = @()
        if ($global:currentAwsEnvironment -and $global:currentAwsRegion) {
            $accountInfo = ""

            # Try to get account ID from config
            if ($script:Config.environments.$global:currentAwsEnvironment.PSObject.Properties['accountId']) {
                $accountId = $script:Config.environments.$global:currentAwsEnvironment.accountId
                $accountInfo = "$global:currentAwsEnvironment (Account: $accountId) - Region: $global:currentAwsRegion"
            } else {
                $accountInfo = "$global:currentAwsEnvironment - Region: $global:currentAwsRegion"
            }

            # Use ANSI color codes for header (yellow text)
            $headerLines += "`e[33mAWS Context: $accountInfo`e[0m"
            $headerLines += ""  # Blank line for spacing
        }

        $choice = Show-ArrowMenu -MenuItems $instanceItems -Title "Instance Management" -HeaderLines $headerLines

        if ($choice -eq -1) {
            return
        }

        # Execute the selected action
        $selectedAction = $instanceItems[$choice]
        & $selectedAction.Action

    } while ($true)
}

function Get-Ec2InstanceInfo {
    param(
        [string]$InstanceId = $null,
        [string]$State = "running",
        [string]$Title = "EC2 Instances"
    )

    Write-Host "Getting $Title..." -ForegroundColor Cyan
    Write-Host ""

    # Build profile parameter using the stored AWS profile name
    $profileParam = if ($global:currentAwsProfile) {
        "--profile $global:currentAwsProfile"
    } else {
        ""
    }

    # Check if credentials are still valid using the correct profile
    try {
        $credCheckCmd = "aws sts get-caller-identity $profileParam 2>&1"
        $null = Invoke-Expression $credCheckCmd
        if ($LASTEXITCODE -ne 0) {
            Write-Host "AWS credentials have expired or are invalid." -ForegroundColor Red
            Write-Host "Please re-authenticate using 'Change AWS Account' option." -ForegroundColor Yellow
            pause
            return
        }
    }
    catch {
        Write-Host "Unable to verify AWS credentials." -ForegroundColor Red
        pause
        return
    }

    try {
        Write-Host "$Title`:" -ForegroundColor Green

        # Display current AWS account context
        if ($global:currentAwsEnvironment -and $global:currentAwsRegion) {
            $accountInfo = ""

            # Try to get account ID from config
            if ($script:Config.environments.$global:currentAwsEnvironment.PSObject.Properties['accountId']) {
                $accountId = $script:Config.environments.$global:currentAwsEnvironment.accountId
                $accountInfo = "$global:currentAwsEnvironment (Account: $accountId) - Region: $global:currentAwsRegion"
            } else {
                $accountInfo = "$global:currentAwsEnvironment - Region: $global:currentAwsRegion"
            }

            Write-Host "AWS Context: $accountInfo" -ForegroundColor Yellow
        }

        # Get the default instance ID for highlighting
        $defaultInstanceId = Get-CurrentInstanceId

        # Capture AWS output
        $awsOutput = if ($InstanceId) {
            # Get specific instance
            Invoke-Expression "aws ec2 describe-instances $profileParam --instance-ids $InstanceId --query 'Reservations[0].Instances[0].[InstanceId,State.Name,Tags[?Key==``Name``].Value|[0],PrivateIpAddress,InstanceType]' --output table" 2>&1 | Out-String
        } else {
            # Get all instances with optional state filter
            if ($State -eq "all") {
                Invoke-Expression "aws ec2 describe-instances $profileParam --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==``Name``].Value|[0],State.Name,PrivateIpAddress,InstanceType]' --output table" 2>&1 | Out-String
            } else {
                Invoke-Expression "aws ec2 describe-instances $profileParam --filters 'Name=instance-state-name,Values=$State' --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==``Name``].Value|[0],State.Name,PrivateIpAddress,InstanceType]' --output table" 2>&1 | Out-String
            }
        }

        if ($LASTEXITCODE -ne 0) {
            # Show the output (likely contains error message)
            Write-Host $awsOutput
            if ($InstanceId) {
                Write-Host "Instance not found or not accessible." -ForegroundColor Red
            } else {
                Write-Host "No instances found or unable to retrieve instances." -ForegroundColor Yellow
            }
        } else {
            # Parse and display the output with highlighting and markers
            $defaultRemoteIP = Get-CurrentDefaultRemoteIP
            $lines = $awsOutput -split "`n"
            foreach ($line in $lines) {
                # Skip empty lines
                if ([string]::IsNullOrWhiteSpace($line)) { continue }

                # Check if this line contains the default instance ID or remote IP
                $hasDefaultInstance = $line -match $defaultInstanceId
                $hasDefaultHost = $defaultRemoteIP -and $line -match [regex]::Escape($defaultRemoteIP)

                # Add markers
                if ($hasDefaultInstance -and $hasDefaultHost) {
                    Write-Host "*+ $line" -ForegroundColor Yellow
                } elseif ($hasDefaultInstance) {
                    Write-Host "*  $line" -ForegroundColor Yellow
                } elseif ($hasDefaultHost) {
                    Write-Host "+  $line" -ForegroundColor Cyan
                } else {
                    Write-Host "   $line"
                }
            }
            # Add legend closer to the table
            Write-Host "   Legend: * = Default Instance | + = Default Host | *+ = Both" -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "Error retrieving instances: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    pause
}

function Get-RunningInstances {
    Get-Ec2InstanceInfo -State "running" -Title "Running EC2 Instances"
}

function Get-Ec2InstancesData {
    param(
        [string]$State = "running"
    )

    # Build profile parameter using the stored AWS profile name
    $profileParam = if ($global:currentAwsProfile) {
        "--profile $global:currentAwsProfile"
    } else {
        ""
    }

    # Check if credentials are still valid using the correct profile
    try {
        $credCheckCmd = "aws sts get-caller-identity $profileParam 2>&1"
        $null = Invoke-Expression $credCheckCmd
        if ($LASTEXITCODE -ne 0) {
            Write-Host "AWS credentials have expired or are invalid." -ForegroundColor Red
            Write-Host "Please re-authenticate using 'Change AWS Account' option." -ForegroundColor Yellow
            return @()
        }
    }
    catch {
        Write-Host "Unable to verify AWS credentials." -ForegroundColor Red
        return @()
    }

    try {
        # Get instances as JSON for parsing
        $jsonOutput = if ($State -eq "all") {
            Invoke-Expression "aws ec2 describe-instances $profileParam --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==``Name``].Value|[0],State.Name,PrivateIpAddress,InstanceType]' --output json" 2>&1
        } else {
            Invoke-Expression "aws ec2 describe-instances $profileParam --filters 'Name=instance-state-name,Values=$State' --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==``Name``].Value|[0],State.Name,PrivateIpAddress,InstanceType]' --output json" 2>&1
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error retrieving instances from AWS." -ForegroundColor Red
            return @()
        }

        # Parse JSON and convert to objects
        $rawData = $jsonOutput | ConvertFrom-Json
        $instances = @()

        # Handle case where there's only one instance (rawData is a single array, not array of arrays)
        if ($rawData -and $rawData[0] -is [string]) {
            # Single instance - $rawData is the instance array itself
            $instances += [PSCustomObject]@{
                InstanceId = $rawData[0]
                Name = if ($rawData[1]) { $rawData[1] } else { "(no name)" }
                State = $rawData[2]
                PrivateIpAddress = $rawData[3]
                InstanceType = $rawData[4]
            }
        } else {
            # Multiple instances - iterate over array of arrays
            foreach ($item in $rawData) {
                $instances += [PSCustomObject]@{
                    InstanceId = $item[0]
                    Name = if ($item[1]) { $item[1] } else { "(no name)" }
                    State = $item[2]
                    PrivateIpAddress = $item[3]
                    InstanceType = $item[4]
                }
            }
        }

        return $instances
    }
    catch {
        Write-Host "Error parsing instance data: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

function Select-Ec2Instance {
    param(
        [string]$State = "running",
        [string]$Title = "Select EC2 Instance"
    )

    Write-Host "Getting instances..." -ForegroundColor Cyan
    $instances = Get-Ec2InstancesData -State $State

    if ($instances.Count -eq 0) {
        Write-Host "No instances found." -ForegroundColor Yellow
        pause
        return $null
    }

    # Build header lines for display in menu
    $headerLines = @()

    # Add AWS account context to header
    if ($global:currentAwsEnvironment -and $global:currentAwsRegion) {
        $accountInfo = ""

        # Try to get account ID from config
        if ($script:Config.environments.$global:currentAwsEnvironment.PSObject.Properties['accountId']) {
            $accountId = $script:Config.environments.$global:currentAwsEnvironment.accountId
            $accountInfo = "$global:currentAwsEnvironment (Account: $accountId) - Region: $global:currentAwsRegion"
        } else {
            $accountInfo = "$global:currentAwsEnvironment - Region: $global:currentAwsRegion"
        }

        # Use ANSI color codes for yellow text
        $yellowCode = "`e[93m"
        $resetCode = "`e[0m"
        $headerLines += "${yellowCode}AWS Context: $accountInfo${resetCode}"
    }

    # Add legend to header
    $grayCode = "`e[90m"
    $resetCode = "`e[0m"
    $headerLines += "${grayCode}   Legend: * = Default Instance | + = Default Host | *+ = Both${resetCode}"

    # Get defaults for highlighting
    $defaultInstanceId = Get-CurrentInstanceId
    $defaultRemoteIP = Get-CurrentDefaultRemoteIP

    # Create menu items from instances - using simple strings for Show-ArrowMenu
    $menuItems = @()
    foreach ($instance in $instances) {
        $displayText = "$($instance.InstanceId) | $($instance.Name) | $($instance.PrivateIpAddress) | $($instance.State) | $($instance.InstanceType)"

        # Determine if this is a default (for visual indicator)
        $isDefaultInstance = $instance.InstanceId -eq $defaultInstanceId
        $isDefaultIP = $defaultRemoteIP -and $instance.PrivateIpAddress -eq $defaultRemoteIP

        if ($isDefaultInstance -and $isDefaultIP) {
            $displayText = "*+ $displayText"
        } elseif ($isDefaultInstance) {
            $displayText = "*  $displayText"
        } elseif ($isDefaultIP) {
            $displayText = "+  $displayText"
        } else {
            $displayText = "   $displayText"
        }

        $menuItems += $displayText
    }

    # Add "None" option at the end
    $menuItems += "<None - No Instance Configured>"

    $choice = Show-ArrowMenu -MenuItems $menuItems -Title $Title -HeaderLines $headerLines

    if ($choice -eq -1) {
        # User pressed Q - return a special marker to indicate cancellation
        return @{ Cancelled = $true }
    }

    # If user selected "None" (last item), return null
    if ($choice -eq $menuItems.Count - 1) {
        return $null
    }

    return $instances[$choice]
}

function Set-DefaultInstanceId {
    $currentDefault = Get-CurrentInstanceId
    Write-Host "Current default instance for $global:currentAwsEnvironment`: $currentDefault" -ForegroundColor Cyan
    Write-Host ""

    # Use interactive selection
    $selectedInstance = Select-Ec2Instance -State "running" -Title "Select Default Instance"

    # Check if user cancelled (pressed Q)
    if ($selectedInstance -is [hashtable] -and $selectedInstance.Cancelled) {
        Write-Host "Selection cancelled - no changes made." -ForegroundColor Yellow
        pause
        return
    }

    if (-not $selectedInstance) {
        Write-Host "Selected: None" -ForegroundColor Yellow
        $newInstanceId = $null
    } else {
        $newInstanceId = $selectedInstance.InstanceId
        Write-Host ""
        Write-Host "Selected: $newInstanceId ($($selectedInstance.Name) - $($selectedInstance.PrivateIpAddress))" -ForegroundColor Cyan
    }

    Write-Host ""

    # Store per-account default instance in config
    $configPath = Join-Path $PSScriptRoot "config.json"
    $config = Get-Content $configPath -Raw | ConvertFrom-Json

    # Ensure the environment exists in config
    if (-not $config.environments.$global:currentAwsEnvironment) {
        Write-Host "Error: Environment '$global:currentAwsEnvironment' not found in config." -ForegroundColor Red
        pause
        return
    }

    # Update the instances.jump-box value (set to null or empty if none selected)
    if ($newInstanceId) {
        $config.environments.$global:currentAwsEnvironment.instances.'jump-box' = $newInstanceId
    } else {
        $config.environments.$global:currentAwsEnvironment.instances.'jump-box' = ""
    }

    # Save back to config.json with proper formatting
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8

    # Reload configuration to pick up changes
    Update-ScriptConfiguration

    # Also update the in-memory cache for immediate effect
    if (-not $global:accountDefaultInstances.ContainsKey($global:currentAwsEnvironment)) {
        $global:accountDefaultInstances[$global:currentAwsEnvironment] = @{}
    }

    if ($newInstanceId) {
        $global:accountDefaultInstances[$global:currentAwsEnvironment]["jump-box"] = $newInstanceId
        Write-Host "✓ Updated default instance for account '$global:currentAwsEnvironment' to: $newInstanceId" -ForegroundColor Green
    } else {
        $global:accountDefaultInstances[$global:currentAwsEnvironment]["jump-box"] = ""
        Write-Host "✓ Cleared default instance for account '$global:currentAwsEnvironment'" -ForegroundColor Green
    }

    Write-Host "✓ Changes saved to config.json" -ForegroundColor Green
    Write-Host ""

    pause
}

function Set-DefaultRemoteHostInfo {
    Write-Host "Set Default Remote Host Information for $global:currentAwsEnvironment" -ForegroundColor Cyan
    Write-Host ""

    # Step 1: Select an EC2 instance
    Write-Host "Step 1: Select the EC2 instance to connect through" -ForegroundColor Yellow
    $selectedInstance = Select-Ec2Instance -State "running" -Title "Select Instance for Remote Connection"

    # Check if user cancelled (pressed Q)
    if ($selectedInstance -is [hashtable] -and $selectedInstance.Cancelled) {
        Write-Host "Selection cancelled - no changes made." -ForegroundColor Yellow
        pause
        return
    }

    if (-not $selectedInstance) {
        Write-Host "Selected: None - Clearing remote host configuration" -ForegroundColor Yellow
        $newInstanceId = ""
        $newRemoteIP = ""
        $newRemotePort = ""
        $newLocalPort = ""

        Write-Host ""
        $confirm = Read-Host "Clear all remote host settings for this account? (y/N)"
        if ($confirm.ToLower() -ne "y") {
            Write-Host "Configuration not changed." -ForegroundColor Yellow
            pause
            return
        }
    } else {
        $newInstanceId = $selectedInstance.InstanceId
        $newRemoteIP = $selectedInstance.PrivateIpAddress

        Write-Host ""
        Write-Host "Selected Instance: $newInstanceId ($($selectedInstance.Name))" -ForegroundColor Green
        Write-Host "Using Instance IP: $newRemoteIP" -ForegroundColor Cyan
        Write-Host ""

        # Step 2: Prompt for Remote Port
        Write-Host "Step 2: Enter Remote Port" -ForegroundColor Yellow

        # Get current remote port from config
        $envConfig = $script:Config.environments.$global:currentAwsEnvironment
        $currentRemotePort = if ($envConfig.PSObject.Properties['defaultRemotePort']) { $envConfig.defaultRemotePort } else { "" }

        if ($currentRemotePort) {
            $newRemotePort = Read-Host "Enter Remote Port [$currentRemotePort]"
        } else {
            $newRemotePort = Read-Host "Enter Remote Port"
        }
        if ([string]::IsNullOrWhiteSpace($newRemotePort)) {
            $newRemotePort = if ($currentRemotePort) { $currentRemotePort } else { "3389" }
        }

        # Step 3: Prompt for Local Port
        Write-Host ""
        Write-Host "Step 3: Enter Local Port" -ForegroundColor Yellow

        # Get current local port from config
        $currentLocalPort = if ($envConfig.PSObject.Properties['defaultLocalPort']) { $envConfig.defaultLocalPort } else { "" }

        if ($currentLocalPort) {
            $newLocalPort = Read-Host "Enter Local Port [$currentLocalPort]"
        } else {
            $newLocalPort = Read-Host "Enter Local Port"
        }
        if ([string]::IsNullOrWhiteSpace($newLocalPort)) {
            $newLocalPort = if ($currentLocalPort) { $currentLocalPort } else { "8388" }
        }

        # Summary
        Write-Host ""
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "Configuration Summary:" -ForegroundColor Yellow
        Write-Host "  Environment: $global:currentAwsEnvironment" -ForegroundColor White
        Write-Host "  Instance ID: $newInstanceId" -ForegroundColor White
        Write-Host "  Instance Name: $($selectedInstance.Name)" -ForegroundColor White
        Write-Host "  Remote IP: $newRemoteIP" -ForegroundColor White
        Write-Host "  Remote Port: $newRemotePort" -ForegroundColor White
        Write-Host "  Local Port: $newLocalPort" -ForegroundColor White
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""

        $confirm = Read-Host "Save this configuration? (Y/n)"
        if ($confirm.ToLower() -eq "n") {
            Write-Host "Configuration not saved." -ForegroundColor Yellow
            pause
            return
        }
    }

    # Store configuration in config.json
    $configPath = Join-Path $PSScriptRoot "config.json"
    $config = Get-Content $configPath -Raw | ConvertFrom-Json

    # Ensure the environment exists in config
    if (-not $config.environments.$global:currentAwsEnvironment) {
        Write-Host "Error: Environment '$global:currentAwsEnvironment' not found in config." -ForegroundColor Red
        pause
        return
    }

    # Update the configuration values - use separate field for remote host instance
    if ($config.environments.$global:currentAwsEnvironment.instances.PSObject.Properties['remote-host']) {
        $config.environments.$global:currentAwsEnvironment.instances.'remote-host' = $newInstanceId
    } else {
        $config.environments.$global:currentAwsEnvironment.instances | Add-Member -NotePropertyName 'remote-host' -NotePropertyValue $newInstanceId -Force
    }
    $config.environments.$global:currentAwsEnvironment.defaultRemoteIP = $newRemoteIP

    # Update default connection settings if they exist
    if ($config.environments.$global:currentAwsEnvironment.PSObject.Properties['defaultRemotePort']) {
        $config.environments.$global:currentAwsEnvironment.defaultRemotePort = $newRemotePort
    } else {
        $config.environments.$global:currentAwsEnvironment | Add-Member -NotePropertyName 'defaultRemotePort' -NotePropertyValue $newRemotePort -Force
    }

    if ($config.environments.$global:currentAwsEnvironment.PSObject.Properties['defaultLocalPort']) {
        $config.environments.$global:currentAwsEnvironment.defaultLocalPort = $newLocalPort
    } else {
        $config.environments.$global:currentAwsEnvironment | Add-Member -NotePropertyName 'defaultLocalPort' -NotePropertyValue $newLocalPort -Force
    }

    # Save back to config.json with proper formatting
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8

    # Reload configuration to pick up changes
    Update-ScriptConfiguration

    # Also update the in-memory cache for immediate effect
    if (-not $global:accountDefaultInstances.ContainsKey($global:currentAwsEnvironment)) {
        $global:accountDefaultInstances[$global:currentAwsEnvironment] = @{}
    }
    $global:accountDefaultInstances[$global:currentAwsEnvironment]["remote-host"] = $newInstanceId

    Write-Host ""
    if ($newInstanceId) {
        Write-Host "✓ Configuration saved successfully!" -ForegroundColor Green
        Write-Host "✓ Instance ID: $newInstanceId" -ForegroundColor Green
        Write-Host "✓ Remote Host: ${newRemoteIP}:${newRemotePort}" -ForegroundColor Green
        Write-Host "✓ Local Port: $newLocalPort" -ForegroundColor Green
    } else {
        Write-Host "✓ Remote host configuration cleared for account '$global:currentAwsEnvironment'" -ForegroundColor Green
    }
    Write-Host "✓ Changes saved to config.json" -ForegroundColor Green
    Write-Host ""

    pause
}

function Get-InstanceNameById {
    param(
        [string]$InstanceId
    )

    if (-not $InstanceId) {
        return $null
    }

    # Build profile parameter using the stored AWS profile name
    $profileParam = if ($global:currentAwsProfile) {
        "--profile $global:currentAwsProfile"
    } else {
        ""
    }

    try {
        # Query AWS for the instance name tag
        $nameTag = Invoke-Expression "aws ec2 describe-instances $profileParam --instance-ids $InstanceId --query 'Reservations[0].Instances[0].Tags[?Key==``Name``].Value' --output text 2>&1"

        if ($LASTEXITCODE -eq 0 -and $nameTag -and $nameTag -ne "None") {
            return $nameTag
        }
    }
    catch {
        # Silently fail if we can't get the name
    }

    return $null
}

function Show-CurrentInstanceSettings {
    Write-Host "Current Instance Settings:" -ForegroundColor Cyan
    Write-Host "  Environment: $global:currentAwsEnvironment" -ForegroundColor White
    Write-Host "  Region: $global:currentAwsRegion" -ForegroundColor White

    # Get default instance ID and name
    $defaultInstanceId = Get-CurrentInstanceId
    if ($defaultInstanceId) {
        $defaultInstanceName = Get-InstanceNameById -InstanceId $defaultInstanceId
        if ($defaultInstanceName) {
            Write-Host "  Instance ID: $defaultInstanceId ($defaultInstanceName)" -ForegroundColor White
        } else {
            Write-Host "  Instance ID: $defaultInstanceId" -ForegroundColor White
        }
    } else {
        Write-Host "  Instance ID: (not configured)" -ForegroundColor DarkGray
    }

    # Display remote host configuration if available
    if ($global:currentAwsEnvironment -and $script:Config.environments.PSObject.Properties[$global:currentAwsEnvironment]) {
        $envConfig = $script:Config.environments.$global:currentAwsEnvironment

        Write-Host ""
        Write-Host "Default Remote Host Info:" -ForegroundColor Cyan

        # Get remote host instance ID
        $remoteHostInstanceId = ""
        if ($envConfig.instances.PSObject.Properties['remote-host']) {
            $remoteHostInstanceId = $envConfig.instances.'remote-host'
        }

        if ($remoteHostInstanceId) {
            $remoteHostInstanceName = Get-InstanceNameById -InstanceId $remoteHostInstanceId
            if ($remoteHostInstanceName) {
                Write-Host "  Remote Host Instance ID: $remoteHostInstanceId ($remoteHostInstanceName)" -ForegroundColor White
            } else {
                Write-Host "  Remote Host Instance ID: $remoteHostInstanceId" -ForegroundColor White
            }
        } else {
            Write-Host "  Remote Host Instance ID: (not configured)" -ForegroundColor DarkGray
        }

        $remoteIP = if ($envConfig.PSObject.Properties['defaultRemoteIP']) { $envConfig.defaultRemoteIP } else { "" }
        $remotePort = if ($envConfig.PSObject.Properties['defaultRemotePort']) { $envConfig.defaultRemotePort } else { "" }
        $localPort = if ($envConfig.PSObject.Properties['defaultLocalPort']) { $envConfig.defaultLocalPort } else { "" }

        if ($remoteIP) {
            Write-Host "  Remote IP: $remoteIP" -ForegroundColor White
        } else {
            Write-Host "  Remote IP: (not configured)" -ForegroundColor DarkGray
        }

        if ($remotePort) {
            Write-Host "  Remote Port: $remotePort" -ForegroundColor White
        } else {
            Write-Host "  Remote Port: (not configured)" -ForegroundColor DarkGray
        }

        if ($localPort) {
            Write-Host "  Local Port: $localPort" -ForegroundColor White
        } else {
            Write-Host "  Local Port: (not configured)" -ForegroundColor DarkGray
        }
    }

    pause
}

function Test-InstanceConnectivity {
    $instanceId = Get-CurrentInstanceId
    Get-Ec2InstanceInfo -InstanceId $instanceId -Title "Instance Connectivity Test"
}

function Start-AlohaConnection {
    param([bool]$IsRdp = $false)

    Write-Host "Connecting to $global:remoteIP via Aloha..." -ForegroundColor Green

    # Build base aloha command with -y flag to auto-answer continue prompt
    # Don't use --rdp flag as Aloha's RDP launcher uses deprecated /console flag
    # Include AWS profile if available
    if ($global:currentAwsProfile -and $global:currentAwsProfile -ne "manual") {
        $Command = "aloha -i $global:awsInstance --localPort $global:localPort -f -r $global:remoteIP --remotePort $global:remotePort -y --profile $global:currentAwsProfile"
    } else {
        $Command = "aloha -i $global:awsInstance --localPort $global:localPort -f -r $global:remoteIP --remotePort $global:remotePort -y"
    }
    Write-Host "Executing: $Command" -ForegroundColor Green

    if ($IsRdp) {
        # Ask about RDP Manager for RDP connections
        $rdpChoice = Read-Host "Launch RDP Manager after connection? (Y/n)"

        # Create a wrapper script that keeps window open on error
        $wrapperScript = @"
`$ErrorActionPreference = 'Continue'
Write-Host ''
Write-Host '═══════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host '  ALOHA CONNECTION - IMPORTANT INSTRUCTIONS' -ForegroundColor Yellow
Write-Host '═══════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''
Write-Host '  When Aloha asks: Would you like to quit? (y/N)' -ForegroundColor White
Write-Host '  → Press ENTER or type N to keep connection alive' -ForegroundColor Green
Write-Host '  → DO NOT type Y or close this window!' -ForegroundColor Red
Write-Host ''
Write-Host '  Command: $Command' -ForegroundColor Gray
Write-Host ''
Write-Host '═══════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''

try {
    # Run Aloha command - run directly to allow interactive prompts
    Invoke-Expression "$Command"
} catch {
    Write-Host ''
    Write-Host 'Error running Aloha: `$(`$_.Exception.Message)' -ForegroundColor Red
}
"@

        # Save wrapper script to temp file
        $tempScript = Join-Path $env:TEMP "aloha_wrapper_$(Get-Date -Format 'yyyyMMddHHmmss').ps1"
        $wrapperScript | Out-File -FilePath $tempScript -Encoding UTF8

        # Launch in new PowerShell window with custom title and no profile to avoid Oh-My-Posh conflicts
        $windowTitle = "Aloha Connection - $global:remoteIP"
        Start-Process -FilePath "pwsh" -ArgumentList "-NoProfile", "-Command", "`$Host.UI.RawUI.WindowTitle = '$windowTitle'; & '$tempScript'" -WindowStyle Normal

        if ($rdpChoice -eq "" -or $rdpChoice.ToLower() -eq "y") {
            # Monitor Aloha output and launch RDP Manager when connection is ready
            Write-Host "Monitoring Aloha connection..." -ForegroundColor Cyan

            # Create a background job to monitor for port availability
            $monitorScript = @"
`$rdcManagerPath = '$($script:Config.paths.rdcManagerPath)'
`$localPort = $global:localPort

# Wait up to 30 seconds for the local port to become available
`$timeout = 30
`$elapsed = 0
`$connected = `$false

Write-Host 'Waiting for Aloha tunnel to establish on port '`$localPort'...' -ForegroundColor Gray

while (`$elapsed -lt `$timeout -and -not `$connected) {
    Start-Sleep -Seconds 1
    `$elapsed++

    # Check if the local port is listening
    try {
        `$listener = Get-NetTCPConnection -LocalPort `$localPort -State Listen -ErrorAction SilentlyContinue
        if (`$listener) {
            `$connected = `$true
            Write-Host 'Connection established! Launching RDP Manager...' -ForegroundColor Green
        }
    } catch {
        # Port not available yet, continue waiting
    }
}

if (`$connected) {
    Start-Sleep -Milliseconds 500
    Start-Process "`$rdcManagerPath"
} else {
    Write-Host 'Timeout waiting for connection. Port '`$localPort' did not become available.' -ForegroundColor Yellow
}
"@

            # Save monitor script
            $monitorScriptPath = Join-Path $env:TEMP "aloha_monitor_$(Get-Date -Format 'yyyyMMddHHmmss').ps1"
            $monitorScript | Out-File -FilePath $monitorScriptPath -Encoding UTF8

            # Start monitoring job in background with minimized window
            Start-Process -FilePath "pwsh" -ArgumentList "-Command", "`$Host.UI.RawUI.WindowTitle = 'RDP Manager Launcher'; & '$monitorScriptPath'" -WindowStyle Minimized
        }
    }
    else {
        # For web interfaces, just run the tunnel
        Write-Host "Tunnel established. Connect via browser to: https://localhost:$global:localPort" -ForegroundColor Cyan
        try {
            Invoke-Expression $Command
            $exitCode = $LASTEXITCODE

            if ($exitCode -ne 0) {
                Write-Host ""
                Write-Host "Aloha exited with error code: $exitCode" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "Error running Aloha: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Auto-continue timer with option to press Enter
    Invoke-TimedPause -TimeoutSeconds 30 -Message "Returning to menu"
}

function Get-VpnConnections {
    Write-Host "Getting VPN connections..." -ForegroundColor Cyan
    Write-Host ""

    # Build profile parameter using the stored AWS profile name
    $profileParam = if ($global:currentAwsProfile) {
        "--profile $global:currentAwsProfile"
    } else {
        ""
    }

    # Check if credentials are still valid using the correct profile
    try {
        $credCheckCmd = "aws sts get-caller-identity $profileParam 2>&1"
        $null = Invoke-Expression $credCheckCmd
        if ($LASTEXITCODE -ne 0) {
            Write-Host "AWS credentials have expired or are invalid." -ForegroundColor Red
            Write-Host "Please re-authenticate using 'Change AWS Account' option." -ForegroundColor Yellow
            pause
            return
        }
    }
    catch {
        Write-Host "Unable to verify AWS credentials." -ForegroundColor Red
        pause
        return
    }

    $searchString = Read-Host "Enter search string for VPN connections"

    if ([string]::IsNullOrWhiteSpace($searchString)) {
        Write-Host "No search string provided. Returning to menu." -ForegroundColor Yellow
        return
    }

    Write-Host "Searching for VPN connections containing: '$searchString'" -ForegroundColor Green
    Write-Host ""

    try {
        # Execute AWS CLI command to get VPN connections with profile parameter
        $vpnCmd = "aws ec2 describe-vpn-connections $profileParam --query 'VpnConnections[].{Name:Tags[?Key==``Name``].Value | [0],VpnConnectionId:VpnConnectionId}' --output text"
        $allVpnOutput = Invoke-Expression $vpnCmd

        # Filter results by search string
        $vpnOutput = $allVpnOutput -split "`n" | Where-Object { $_ -match $searchString }

        if ($vpnOutput) {
            Write-Host "VPN Connection Results:" -ForegroundColor Green
            Write-Host ""

            # Display header
            Write-Host ("{0,-40} {1}" -f "NAME", "VPN CONNECTION ID") -ForegroundColor Cyan
            Write-Host ("{0,-40} {1}" -f "----", "-----------------") -ForegroundColor Cyan

            # Parse and display VPN connections
            $vpnConnections = @()
            foreach ($line in $vpnOutput) {
                if ($line.Trim()) {
                    $parts = $line.Trim() -split "`t"
                    if ($parts.Length -ge 2) {
                        $name = $parts[0]
                        $id = $parts[1]

                        # Display formatted row
                        Write-Host ("{0,-40} {1}" -f $name, $id) -ForegroundColor White

                        # Store for later processing
                        $vpnConnections += @{
                            Name = $name
                            Id = $id
                        }
                    }
                }
            }

            Write-Host ""
            Write-Host "Total VPN connections found: $($vpnConnections.Count)" -ForegroundColor Green
            Write-Host ""

            # Ask about FortiGate configs
            if ($vpnConnections.Count -gt 0) {
                $configChoice = Read-Host "Pull FortiGate configurations for $($vpnConnections.Count) VPN connection(s)? (Y/n)"
                if ($configChoice -eq "" -or $configChoice.ToLower() -eq "y") {
                    Get-FortiGateConfigs -VpnConnections $vpnConnections
                }
            }
        }
        else {
            Write-Host "No VPN connections found matching '$searchString'" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error retrieving VPN connections: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Pause before returning to Instance Management menu
    Write-Host ""
    pause
}

function Get-FortiGateConfigs {
    param([array]$VpnConnections)

    Write-Host "Downloading FortiGate configurations for $($VpnConnections.Count) VPN connection(s)..." -ForegroundColor Cyan
    Write-Host ""

    # Build profile parameter using the stored AWS profile name
    $profileParam = if ($global:currentAwsProfile) {
        "--profile $global:currentAwsProfile"
    } else {
        ""
    }

    # Create output directory for configs
    $configOutputDir = Join-Path $PSScriptRoot "vpn_output"

    if (-not (Test-Path $configOutputDir)) {
        New-Item -ItemType Directory -Path $configOutputDir -Force | Out-Null
    }

    $successCount = 0
    $failCount = 0

    foreach ($vpn in $VpnConnections) {
        $vpnId = $vpn.Id
        $vpnName = $vpn.Name

        Write-Host "Downloading config for: $vpnName ($vpnId)..." -ForegroundColor White

        try {
            # Download FortiGate-specific VPN configuration using AWS CLI
            $configFile = Join-Path $configOutputDir "$vpnName.txt"

            # Get the FortiGate device sample configuration from AWS
            # Device type ID 7125681a is for FortiGate
            $awsCommand = "aws ec2 get-vpn-connection-device-sample-configuration $profileParam --no-paginate --vpn-connection-id `"$vpnId`" --vpn-connection-device-type-id `"7125681a`" --internet-key-exchange-version `"ikev1`" --output text"
            $config = Invoke-Expression $awsCommand

            if ($config -and $config -ne "None" -and $LASTEXITCODE -eq 0) {
                # Save configuration to file
                $config | Out-File -FilePath $configFile -Encoding UTF8
                Write-Host "  Success - Saved to: $configFile" -ForegroundColor Green
                $successCount++
            }
            else {
                Write-Host "  Failed - No configuration available for $vpnName" -ForegroundColor Yellow
                $failCount++
            }
        }
        catch {
            Write-Host "  Failed - Error downloading config: $($_.Exception.Message)" -ForegroundColor Red
            $failCount++
        }

        Write-Host ""
    }

    # Summary
    Write-Host "Download Summary:" -ForegroundColor Cyan
    Write-Host "  Success: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Yellow" } else { "Green" })
    Write-Host "  Output directory: $configOutputDir" -ForegroundColor Cyan
    Write-Host ""
}

# --- Script Execution Start ---
# Only run main menu if script is executed directly (not sourced)
if ($MyInvocation.InvocationName -ne '.') {
    Show-MainMenu
}

