#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Clears AWS credentials from the [default] profile.

.DESCRIPTION
    This script safely clears the AWS credentials (access key, secret key, and session token)
    from the [default] profile in ~/.aws/credentials without affecting other profiles.

    This provides a "logout" function for okta-aws-cli, which writes credentials to [default]
    but doesn't provide a built-in logout mechanism.

.EXAMPLE
    .\aws-logout.ps1
    Clears credentials from [default] profile

.NOTES
    Part of powershell-console project
    Works with okta-aws-cli authentication workflow
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# AWS credentials file path
$credentialsPath = "$env:USERPROFILE\.aws\credentials"

# Check if credentials file exists
if (-not (Test-Path $credentialsPath)) {
    Write-Host "No AWS credentials file found" -ForegroundColor Yellow
    Write-Host "Nothing to log out from." -ForegroundColor Yellow
    exit 0
}

try {
    # Read the entire credentials file
    $content = Get-Content $credentialsPath -Raw

    # Check if [default] profile exists
    if ($content -notmatch '\[default\]') {
        Write-Host "No [default] profile found in credentials file." -ForegroundColor Yellow
        Write-Host "Nothing to log out from." -ForegroundColor Yellow
        exit 0
    }

    # Pattern to match the [default] section and its credentials
    $pattern = '(?s)(\[default\])\s*(aws_access_key_id\s*=\s*)[^\r\n]*([\r\n]+)(aws_secret_access_key\s*=\s*)[^\r\n]*([\r\n]+)(aws_session_token\s*=\s*)[^\r\n]*'

    # Replace with empty credentials
    # $1=[default] $2=aws_access_key_id = $3=newline $4=aws_secret_access_key = $5=newline $6=aws_session_token =
    $replacement = '$1$3$2$3$4$5$6'

    $newContent = $content -replace $pattern, $replacement

    # Backup the original file
    $backupPath = "$credentialsPath.backup"
    Copy-Item $credentialsPath $backupPath -Force
    Write-Verbose "Created backup at: $backupPath"

    # Write the updated content
    $newContent | Set-Content $credentialsPath -NoNewline

    Write-Host "Successfully logged out of AWS" -ForegroundColor Green
    Write-Host "  Cleared credentials from [default] profile" -ForegroundColor Gray
    Write-Host "  Backup saved to: $backupPath" -ForegroundColor Gray
}
catch {
    Write-Error "Failed to clear AWS credentials: $_"

    # Attempt to restore from backup if it exists
    if (Test-Path "$credentialsPath.backup") {
        Write-Warning "Attempting to restore from backup..."
        Copy-Item "$credentialsPath.backup" $credentialsPath -Force
        Write-Host "Restored original credentials file" -ForegroundColor Yellow
    }

    exit 1
}
