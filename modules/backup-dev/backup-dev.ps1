
# DevBackup Script
# Backs up dev folder to configured backup destination

# Parameters - Parse GNU-style arguments
$testMode = $false
$listOnly = $false
$countOnly = $false
$testModeLimit = 100  # Default limit for test mode

# Parse arguments with support for values
for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = $args[$i]

    switch ($arg) {
        "--test-mode" {
            $testMode = $true
            $listOnly = $true  # Test mode automatically enables list-only

            # Check if next argument is a number
            if (($i + 1) -lt $args.Count) {
                $nextArg = $args[$i + 1]
                if ($nextArg -match '^\d+$') {
                    $providedLimit = [int]$nextArg
                    $i++  # Consume the numeric argument
                    if ($providedLimit -ge 100) {
                        $testModeLimit = $providedLimit
                    } else {
                        # If less than 100, use default but warn the user
                        Write-Host "Warning: Test mode limit must be >= 100. Using default: 100" -ForegroundColor Yellow
                        $testModeLimit = 100
                    }
                }
            }
        }
        "--list-only" { $listOnly = $true }
        "--count" { $countOnly = $true }
        "--help" {
            Write-Host "Usage: backup-dev.ps1 [OPTIONS]"
            Write-Host ""
            Write-Host "Options:"
            Write-Host "  --test-mode [N]   Quick test: list-only mode limited to N operations"
            Write-Host "                    N must be >= 100 (default: 100 if not specified)"
            Write-Host "  --list-only       Preview changes without actually copying/deleting files"
            Write-Host "  --count           Only count files and directories, then exit"
            Write-Host "  --help            Show this help message"
            Write-Host ""
            Write-Host "Examples:"
            Write-Host "  backup-dev.ps1 --test-mode       # Test with 100 items"
            Write-Host "  backup-dev.ps1 --test-mode 250   # Test with 250 items"
            Write-Host "  backup-dev.ps1 --test-mode 1000  # Test with 1000 items"
            Write-Host "  backup-dev.ps1 --list-only       # Preview all changes"
            Write-Host ""
            Write-Host "Note: --test-mode automatically enables --list-only"
            Write-Host "      --count runs alone and ignores other switches"
            exit 0
        }
        default {
            Write-Host ""
            Write-Error "Unknown option: $arg"
            Write-Host ""
            Write-Host "Usage: backup-dev.ps1 [OPTIONS]"
            Write-Host ""
            Write-Host "Options:"
            Write-Host "  --test-mode [N]   Quick test: list-only mode limited to N operations"
            Write-Host "                    N must be >= 100 (default: 100 if not specified)"
            Write-Host "  --list-only       Preview changes without actually copying/deleting files"
            Write-Host "  --count           Only count files and directories, then exit"
            Write-Host "  --help            Show this help message"
            Write-Host ""
            Write-Host "Examples:"
            Write-Host "  backup-dev.ps1 --test-mode       # Test with 100 items"
            Write-Host "  backup-dev.ps1 --test-mode 250   # Test with 250 items"
            Write-Host "  backup-dev.ps1 --test-mode 1000  # Test with 1000 items"
            Write-Host "  backup-dev.ps1 --list-only       # Preview all changes"
            Write-Host ""
            exit 1
        }
    }
}

# Helper function to draw separator lines
function Write-Separator {
    Write-Host "==============================================" -ForegroundColor Cyan
}

# Load configuration
# $scriptDir is modules/backup-dev/
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# Go up one level from scriptDir: modules/backup-dev/ -> modules/
$modulesDir = Split-Path -Parent $scriptDir
# Go up one more level: modules/ -> powershell-console/
$rootDir = Split-Path -Parent $modulesDir
$configPath = Join-Path $rootDir "config.json"

if (-not (Test-Path $configPath)) {
    Write-Error "Config file not found at: $configPath"
    Write-Error "Please create config.json from config.example.json"
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Read paths from config
$source = $config.paths.backupSource
$destination = Join-Path $env:USERPROFILE $config.paths.backupDestination

# Define log files (in module directory)
$detailedLog = Join-Path $scriptDir "backup-dev.log"
$summaryLog = Join-Path $scriptDir "backup-history.log"

# Create destination if it doesn't exist
New-Item -ItemType Directory -Path $destination -Force -ErrorAction SilentlyContinue | Out-Null

# Timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$scriptStartTime = Get-Date

# Clear previous detailed log and start new one
Set-Content -Path $detailedLog -Value "=== Backup started: $timestamp ==="

Write-Host ""
Write-Separator
if ($countOnly) {
    Write-Host "  COUNT MODE - Only scanning source files" -ForegroundColor Yellow
} else {
    if ($testMode) {
        Write-Host "  TEST MODE - Limited to $testModeLimit operations" -ForegroundColor Yellow
    }
    if ($listOnly) {
        Write-Host "  LIST-ONLY MODE - No files will be modified" -ForegroundColor Yellow
    }
    Write-Host "  Backup Started: $timestamp" -ForegroundColor Cyan
}
Write-Separator
Write-Host ""

# Progress tracking variables
$script:dirCount = 0
$script:fileCount = 0
$script:copiedCount = 0
$script:extraCount = 0
$script:lastUpdateTime = Get-Date
$script:totalFiles = 0
$script:totalDirs = 0

# Function to draw progress bar
function Show-Progress {
    param(
        [int]$Dirs,
        [int]$Files,
        [int]$Copied,
        [int]$Extra,
        [string]$CurrentFile = "",
        [int]$TotalFiles = 0,
        [int]$TotalDirs = 0,
        [switch]$Force
    )

    $elapsed = (Get-Date) - $script:lastUpdateTime
    if (-not $Force -and $elapsed.TotalMilliseconds -lt 500 -and $CurrentFile -eq "") { return }
    $script:lastUpdateTime = Get-Date

    $width = 40
    $spinnerChars = @('|', '/', '-', '\')
    $spinnerIndex = [math]::Floor((Get-Date).Millisecond / 250) % 4
    $spinner = $spinnerChars[$spinnerIndex]

    # Create progress bar based on actual progress
    if ($TotalFiles -gt 0 -and $TotalDirs -gt 0) {
        $totalItems = $TotalFiles + $TotalDirs
        $currentItems = $Files + $Dirs
        $percentage = [math]::Min([math]::Floor(($currentItems / $totalItems) * 100), 100)
        $filled = [math]::Min([math]::Floor(($currentItems / $totalItems) * $width), $width)
        $bar = ('#' * $filled).PadRight($width, '-')

        Write-Host "`r[$bar] $spinner $percentage% " -NoNewline -ForegroundColor Green
    } else {
        # Fallback for counting phase
        $filled = [math]::Min([math]::Floor(($Files % 100) * $width / 100), $width)
        $bar = ('#' * $filled).PadRight($width, '-')
        Write-Host "`r[$bar] $spinner " -NoNewline -ForegroundColor Green
    }

    Write-Host "Dirs: $Dirs | Files: $Files | Copied: $Copied | Extra: $Extra" -NoNewline -ForegroundColor Yellow

    if ($CurrentFile -ne "") {
        Write-Host "`n  $CurrentFile" -ForegroundColor Gray
    }
}

# PASS 1: Count total files and directories
if ($testMode) {
    Write-Host "Pass 1: Quick scan (limited to $testModeLimit items for test mode)..." -ForegroundColor Cyan
} else {
    Write-Host "Pass 1: Scanning source directory to count files..." -ForegroundColor Cyan
}

$countLog = Join-Path $scriptDir "temp_count_log.txt"

# Run robocopy in list-only mode to count files
$countJob = Start-Job -ScriptBlock {
    param($src, $dst, $log)
    robocopy $src $dst /L /MIR /R:0 /W:0 /LOG:$log /NP /NDL 2>&1
} -ArgumentList $source, $destination, $countLog

$countStartTime = Get-Date
$countLimitReached = $false

# Monitor counting progress
while ($countJob.State -eq 'Running') {
    Start-Sleep -Milliseconds 200

    if (Test-Path $countLog) {
        try {
            # Count lines in the log file as a proxy for progress
            $lineCount = (Get-Content $countLog -ErrorAction SilentlyContinue).Count

            # In test mode, stop counting after we have enough lines
            # Robocopy outputs multiple lines per file/dir, so use 1.5x the limit
            if ($testMode -and $lineCount -ge ($testModeLimit * 1.5)) {
                Stop-Job $countJob
                $countLimitReached = $true
                # Don't clear the line - leave the scanning progress visible
                break
            }

            $elapsed = (Get-Date) - $countStartTime
            Write-Host "`rScanning... Time: $($elapsed.ToString('mm\:ss')) | Lines: $lineCount" -NoNewline -ForegroundColor Yellow
        }
        catch {
            # File might be locked, skip this iteration
        }
    }
}

# Get final counts
$null = Receive-Job $countJob -Wait -AutoRemoveJob

if (Test-Path $countLog) {
    $logContent = Get-Content $countLog -Raw

    # In test mode with limit reached, use half the limit as estimate
    if ($testMode -and $countLimitReached) {
        # The scanning progress used -NoNewline, so output a newline to preserve it
        Write-Host ""
        # Set approximate values for test mode (split evenly between dirs and files)
        $script:totalDirs = [int]($testModeLimit / 2)
        $script:totalFiles = [int]($testModeLimit / 2)
    } else {
        # The scanning progress used -NoNewline, so output a newline
        Write-Host ""
        # Parse the summary section for accurate counts
        # Robocopy summary format: Total Copied Skipped Mismatch FAIL EXTRAS
        # We want Copied + EXTRAS as these are the operations that will occur in Pass 2
        if ($logContent -match '(?m)^\s+Dirs\s*:\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)') {
            # Dirs: Total=1, Copied=2, Skipped=3, Mismatch=4, FAIL=5, EXTRAS=6
            $script:totalDirsInSource = [int]$matches[1]
            $dirsCopied = [int]$matches[2]
            $dirsExtras = [int]$matches[6]
            $script:totalDirs = $dirsCopied + $dirsExtras
        }

        if ($logContent -match '(?m)^\s+Files\s*:\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)') {
            # Files: Total=1, Copied=2, Skipped=3, Mismatch=4, FAIL=5, EXTRAS=6
            $script:totalFilesInSource = [int]$matches[1]
            $filesCopied = [int]$matches[2]
            $filesExtras = [int]$matches[6]
            $script:totalFiles = $filesCopied + $filesExtras
        }
    }

    Remove-Item $countLog -Force -ErrorAction SilentlyContinue
}

if ($testMode -and $countLimitReached) {
    Write-Host "Quick scan complete! Found ~$script:totalDirs directories and ~$script:totalFiles files (test mode limit)" -ForegroundColor Green
} else {
    Write-Host "Scan complete! Found $script:totalDirs directories and $script:totalFiles files" -ForegroundColor Green
}

# If count-only mode, display summary and exit
if ($countOnly) {
    $changedItems = $script:totalDirs + $script:totalFiles
    $inventoryItems = $script:totalDirsInSource + $script:totalFilesInSource
    $scriptEndTime = Get-Date
    $totalRuntime = $scriptEndTime - $scriptStartTime
    $runtimeFormatted = "{0:mm\:ss}" -f $totalRuntime

    Write-Host ""
    Write-Separator
    Write-Host "  COUNT SUMMARY" -ForegroundColor Cyan
    Write-Separator
    Write-Host ""
    Write-Host "                         Inventory    Need to Copy" -ForegroundColor Gray
    Write-Host "                         ---------    ------------" -ForegroundColor DarkGray

    # Format numbers with commas and right-alignment
    $dirsInventory = "{0,15:N0}" -f $script:totalDirsInSource
    $dirsChanged = "{0,16:N0}" -f $script:totalDirs
    $filesInventory = "{0,15:N0}" -f $script:totalFilesInSource
    $filesChanged = "{0,16:N0}" -f $script:totalFiles
    $totalInventory = "{0,15:N0}" -f $inventoryItems
    $totalChanged = "{0,16:N0}" -f $changedItems

    Write-Host "  " -NoNewline
    Write-Host "Directories:" -NoNewline -ForegroundColor Cyan
    Write-Host $dirsInventory -NoNewline -ForegroundColor White
    Write-Host $dirsChanged -ForegroundColor Yellow

    Write-Host "  " -NoNewline
    Write-Host "Files:      " -NoNewline -ForegroundColor Cyan
    Write-Host $filesInventory -NoNewline -ForegroundColor White
    Write-Host $filesChanged -ForegroundColor Yellow

    Write-Host "  " -NoNewline
    Write-Host ("─" * 47) -ForegroundColor DarkGray

    Write-Host "  " -NoNewline
    Write-Host "Total:      " -NoNewline -ForegroundColor Cyan
    Write-Host $totalInventory -NoNewline -ForegroundColor White
    Write-Host $totalChanged -ForegroundColor Yellow

    Write-Host ""
    Write-Host "  Runtime: $runtimeFormatted" -ForegroundColor Gray
    Write-Separator
    exit 0
}

Write-Host ""
Write-Host "Pass 2: Starting backup with progress tracking..." -ForegroundColor Cyan

# Start robocopy process in background
$robocopyJob = Start-Job -ScriptBlock {
    param($src, $dst, $log, $testMode, $listOnly)

    # Build robocopy command with appropriate flags
    $robocopyFlags = "/MIR /R:3 /W:5 /LOG+:$log /NP /NDL /ETA"
    if ($listOnly) {
        $robocopyFlags = "/L $robocopyFlags"  # Add list-only flag
    }

    # Execute robocopy with the constructed flags
    $cmd = "robocopy `"$src`" `"$dst`" $robocopyFlags 2>&1"
    Invoke-Expression $cmd
} -ArgumentList $source, $destination, $detailedLog, $testMode, $listOnly

$lastProgress = Get-Date

# Monitor job progress by checking log file
while ($robocopyJob.State -eq 'Running') {
    Start-Sleep -Milliseconds 200

    # Read current log file content
    if (Test-Path $detailedLog) {
        try {
            $logContent = Get-Content $detailedLog -ErrorAction SilentlyContinue

            # Count different types of operations
            $newDirs = ($logContent | Where-Object { $_ -match 'New Dir' }).Count
            $extraDirs = ($logContent | Where-Object { $_ -match '\*EXTRA Dir' }).Count
            $script:dirCount = $newDirs + $extraDirs

            $newFiles = ($logContent | Where-Object { $_ -match 'New File' }).Count
            $newerFiles = ($logContent | Where-Object { $_ -match 'Newer' }).Count
            $extraFiles = ($logContent | Where-Object { $_ -match '\*EXTRA File' }).Count
            $script:copiedCount = $newFiles + $newerFiles
            $script:extraCount = $extraFiles
            $script:fileCount = $script:copiedCount + $script:extraCount

            # In test mode, stop after reaching the limit (dirs + files)
            if ($testMode -and (($script:dirCount + $script:fileCount) -ge $testModeLimit)) {
                Stop-Job $robocopyJob
                break
            }

            # Update progress every 500ms
            $now = Get-Date
            if (($now - $lastProgress).TotalMilliseconds -ge 500) {
                Show-Progress -Dirs $script:dirCount -Files $script:fileCount -Copied $script:copiedCount -Extra $script:extraCount -TotalFiles $script:totalFiles -TotalDirs $script:totalDirs
                $lastProgress = $now
            }
        }
        catch {
            # File might be locked, skip this iteration
        }
    }
}

# Wait for job to complete
$null = Receive-Job $robocopyJob -Wait -AutoRemoveJob

# Parse log one final time to get complete counts
if (Test-Path $detailedLog) {
    try {
        $logContent = Get-Content $detailedLog -ErrorAction SilentlyContinue

        # Count different types of operations
        $newDirs = ($logContent | Where-Object { $_ -match 'New Dir' }).Count
        $extraDirs = ($logContent | Where-Object { $_ -match '\*EXTRA Dir' }).Count
        $script:dirCount = $newDirs + $extraDirs

        $newFiles = ($logContent | Where-Object { $_ -match 'New File' }).Count
        $newerFiles = ($logContent | Where-Object { $_ -match 'Newer' }).Count
        $extraFiles = ($logContent | Where-Object { $_ -match '\*EXTRA File' }).Count
        $script:copiedCount = $newFiles + $newerFiles
        $script:extraCount = $extraFiles
        $script:fileCount = $script:copiedCount + $script:extraCount
    }
    catch { }
}

# Final progress update - clear line and show final state
if ($script:fileCount -gt 0 -or $script:dirCount -gt 0) {
    # Only show progress if there were operations
    Write-Host "`r                                                                                                    " -NoNewline
    Write-Host "`r" -NoNewline
    Show-Progress -Dirs $script:dirCount -Files $script:fileCount -Copied $script:copiedCount -Extra $script:extraCount -TotalFiles $script:totalFiles -TotalDirs $script:totalDirs -Force
    Write-Host ""
}

# Show completion message
Write-Host ""
if ($testMode) {
    Write-Host "Test mode limit reached ($testModeLimit operations). Stopping backup..." -ForegroundColor Yellow
}
if ($listOnly) {
    Write-Host "List-only scan complete! (No files were modified)" -ForegroundColor Green
} else {
    Write-Host "Backup complete!" -ForegroundColor Green
}
Write-Host ""

$endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $detailedLog -Value "`n=== Backup completed: $endTime ==="

# Extract summary from detailed log and append to history
$detailedContent = Get-Content $detailedLog -Raw

# Extract summary section (Total, Dirs, Files, Bytes, Times, Speed, Ended)
$summarySection = ""
if ($detailedContent -match '(?s)([-]+\s*Total.*?Ended\s*:.*?)(\s*===|$)') {
    $summarySection = $matches[1].Trim()
}

# Append to summary history
Add-Content -Path $summaryLog -Value "`n=== Backup: $timestamp ==="
if ($summarySection) {
    Add-Content -Path $summaryLog -Value $summarySection
}
Add-Content -Path $summaryLog -Value "=== Backup completed: $endTime ==="

# Rotate summary log: keep only last 7 backups
$summaryContent = Get-Content $summaryLog -Raw
$backupSessions = $summaryContent -split '(?m)^=== Backup: ' | Where-Object { $_.Trim() -ne "" }

$logRotated = $false
if ($backupSessions.Count -gt 7) {
    # Keep only the last 7 sessions
    $recentSessions = $backupSessions | Select-Object -Last 7
    $rotatedContent = ($recentSessions | ForEach-Object { "=== Backup: $_" }) -join "`n"
    Set-Content -Path $summaryLog -Value $rotatedContent
    $logRotated = $true
}

Write-Host "  Detailed log: $detailedLog" -ForegroundColor Cyan
Write-Host "  Summary history: $summaryLog" -ForegroundColor Cyan
if ($logRotated) {
    Write-Host "    (Rotated summary log to keep last 7 backups)" -ForegroundColor Cyan
}

# Display total runtime
$scriptEndTime = Get-Date
$totalRuntime = $scriptEndTime - $scriptStartTime
$runtimeFormatted = "{0:mm\:ss}" -f $totalRuntime
Write-Host ""
Write-Host "  Total runtime: $runtimeFormatted" -ForegroundColor Cyan
