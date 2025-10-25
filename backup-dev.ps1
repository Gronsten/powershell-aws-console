
# DevBackup Script
# Backs up dev folder to OneDrive

# Load configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir "config.json"

if (-not (Test-Path $configPath)) {
    Write-Error "Config file not found at: $configPath"
    Write-Error "Please create config.json from config.example.json"
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Read paths from config
$source = $config.paths.backupSource
$destination = Join-Path $env:USERPROFILE $config.paths.backupDestination
$logFile = Join-Path $scriptDir $config.paths.backupLogFile

# Create destination if it doesn't exist
New-Item -ItemType Directory -Path $destination -Force -ErrorAction SilentlyContinue | Out-Null

# Timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $logFile -Value "`n=== Backup started: $timestamp ==="

# Backup everything
# /MIR = Mirror (delete files in destination that don't exist in source)
# /R:3 = Retry 3 times on failure
# /W:5 = Wait 5 seconds between retries
robocopy $source $destination /MIR /R:3 /W:5 /LOG+:"$logFile" /NP /NFL /ETA /TEE

$endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $logFile -Value "=== Backup completed: $endTime ==="

Write-Host "`nBackup complete! Log file: $logFile" -ForegroundColor Green
