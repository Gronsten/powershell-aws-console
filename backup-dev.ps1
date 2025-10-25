
# DevBackup Script
# Backs up dev folder to OneDrive

$source = "C:\AppInstall\"
$destination = "C:\Users\mark.campbell3\OneDrive - Chick-fil-A, Inc\DevBackups"
$logFile = "C:\AppInstall\dev\powershell-aws-console\backup-log.txt"

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
