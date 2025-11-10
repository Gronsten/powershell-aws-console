# AwsPromptIndicator.psm1
# PowerShell module for AWS account mismatch detection in oh-my-posh prompts
# Part of powershell-console project

<#
.SYNOPSIS
    Detects AWS account mismatches between current directory and logged-in AWS account.

.DESCRIPTION
    This module provides functions to:
    - Read AWS credentials from ~/.aws/credentials
    - Extract current AWS account ID from IAM role ARN
    - Map current directory to expected AWS account
    - Provide oh-my-posh custom segment data for visual indicators

.NOTES
    Requirements:
    - oh-my-posh (for custom prompt segments)
    - posh-git (optional, for git integration)
    - okta-aws-cli (for AWS authentication)
    - AWS CLI v2
#>

# Module variables
$script:AwsCredentialsPath = "$env:USERPROFILE\.aws\credentials"
$script:ConfigPath = $null
$script:DirectoryMappings = @{}

<#
.SYNOPSIS
    Initializes the AWS Prompt Indicator module with configuration.

.PARAMETER ConfigPath
    Path to the powershell-console config.json file.

.EXAMPLE
    Initialize-AwsPromptIndicator -ConfigPath "C:\AppInstall\dev\powershell-console\config.json"
#>
function Initialize-AwsPromptIndicator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        Write-Warning "Config file not found: $ConfigPath"
        return $false
    }

    try {
        $script:ConfigPath = $ConfigPath
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

        # Load directory mappings if they exist
        if ($config.awsPromptIndicator -and $config.awsPromptIndicator.directoryMappings) {
            $script:DirectoryMappings = @{}
            $config.awsPromptIndicator.directoryMappings.PSObject.Properties | ForEach-Object {
                $script:DirectoryMappings[$_.Name] = $_.Value
            }
            Write-Verbose "Loaded $($script:DirectoryMappings.Count) directory mappings"
        }

        return $true
    }
    catch {
        Write-Warning "Failed to load config: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Reads the current AWS account ID from credentials file.

.DESCRIPTION
    Parses ~/.aws/credentials to find the [default] profile and extracts
    the account ID from the IAM role ARN set by okta-aws-cli.

.OUTPUTS
    String - The 12-digit AWS account ID, or $null if not found.

.EXAMPLE
    $accountId = Get-CurrentAwsAccountId
    # Returns: "041457850300"
#>
function Get-CurrentAwsAccountId {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if (-not (Test-Path $script:AwsCredentialsPath)) {
        Write-Verbose "AWS credentials file not found: $script:AwsCredentialsPath"
        return $null
    }

    try {
        $credContent = Get-Content $script:AwsCredentialsPath -Raw

        # Find the [default] profile section
        if ($credContent -match '\[default\][\s\S]*?aws_session_token\s*=') {
            $defaultSection = $Matches[0]

            # Look for role ARN pattern: arn:aws:iam::123456789012:role/RoleName
            if ($defaultSection -match 'arn:aws:iam::(\d{12}):') {
                $accountId = $Matches[1]
                Write-Verbose "Found AWS account ID: $accountId"
                return $accountId
            }
        }

        Write-Verbose "No AWS account ID found in credentials file"
        return $null
    }
    catch {
        Write-Warning "Error reading AWS credentials: $_"
        return $null
    }
}

<#
.SYNOPSIS
    Gets the expected AWS account ID for the current directory.

.DESCRIPTION
    Checks if the current working directory (or any parent directory)
    is mapped to an AWS account in the configuration.

.OUTPUTS
    String - The expected 12-digit AWS account ID, or $null if no mapping found.

.EXAMPLE
    $expectedAccount = Get-ExpectedAwsAccountId
#>
function Get-ExpectedAwsAccountId {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $currentPath = Get-Location | Select-Object -ExpandProperty Path

    # Check exact match first
    if ($script:DirectoryMappings.ContainsKey($currentPath)) {
        Write-Verbose "Exact directory mapping found for: $currentPath"
        return $script:DirectoryMappings[$currentPath]
    }

    # Check if current path is under any mapped directory
    foreach ($mappedDir in $script:DirectoryMappings.Keys) {
        if ($currentPath -like "$mappedDir*") {
            Write-Verbose "Parent directory mapping found: $mappedDir"
            return $script:DirectoryMappings[$mappedDir]
        }
    }

    Write-Verbose "No directory mapping found for: $currentPath"
    return $null
}

<#
.SYNOPSIS
    Checks if there's an AWS account mismatch for the current directory.

.DESCRIPTION
    Compares the current AWS account (from credentials) with the expected
    account for the current directory. Returns detailed status information.

.OUTPUTS
    PSCustomObject with properties:
    - HasMismatch (bool): True if accounts don't match
    - CurrentAccount (string): Current AWS account ID
    - ExpectedAccount (string): Expected AWS account ID
    - CurrentDirectory (string): Current working directory
    - Message (string): Human-readable status message

.EXAMPLE
    $status = Test-AwsAccountMismatch
    if ($status.HasMismatch) {
        Write-Host "Warning: AWS account mismatch!" -ForegroundColor Yellow
    }
#>
function Test-AwsAccountMismatch {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $currentAccount = Get-CurrentAwsAccountId
    $expectedAccount = Get-ExpectedAwsAccountId
    $currentDir = Get-Location | Select-Object -ExpandProperty Path

    # Determine if there's a mismatch
    $hasMismatch = $false
    $message = "No AWS session active"

    if ($null -ne $currentAccount -and $null -ne $expectedAccount) {
        if ($currentAccount -ne $expectedAccount) {
            $hasMismatch = $true
            $message = "AWS account mismatch: logged into $currentAccount, expected $expectedAccount"
        }
        else {
            $message = "AWS account matches: $currentAccount"
        }
    }
    elseif ($null -ne $currentAccount -and $null -eq $expectedAccount) {
        $message = "AWS session active ($currentAccount), but no mapping for current directory"
    }
    elseif ($null -eq $currentAccount -and $null -ne $expectedAccount) {
        $message = "No AWS session, but directory expects account $expectedAccount"
    }

    return [PSCustomObject]@{
        HasMismatch      = $hasMismatch
        CurrentAccount   = $currentAccount
        ExpectedAccount  = $expectedAccount
        CurrentDirectory = $currentDir
        Message          = $message
    }
}

<#
.SYNOPSIS
    Gets AWS account mismatch data formatted for oh-my-posh custom segment.

.DESCRIPTION
    Returns a JSON string that can be used by oh-my-posh's custom segment
    type to display AWS account status in the prompt.

.OUTPUTS
    String - JSON formatted data for oh-my-posh

.EXAMPLE
    Get-AwsPromptSegmentData | Out-File -FilePath $env:TEMP\aws-prompt-data.json -Encoding UTF8
#>
function Get-AwsPromptSegmentData {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $status = Test-AwsAccountMismatch

    $data = @{
        hasMismatch     = $status.HasMismatch
        currentAccount  = $status.CurrentAccount
        expectedAccount = $status.ExpectedAccount
        message         = $status.Message
        icon            = if ($status.HasMismatch) { "⚠" } else { "✓" }
        color           = if ($status.HasMismatch) { "red" } else { "green" }
    }

    return $data | ConvertTo-Json -Compress
}

<#
.SYNOPSIS
    Gets a simple text indicator for AWS account status.

.DESCRIPTION
    Returns a formatted string that can be added to any prompt.
    Only shows output when there's a mismatch.

.PARAMETER AlwaysShow
    If specified, shows status even when accounts match.

.OUTPUTS
    String - Formatted status text

.EXAMPLE
    $indicator = Get-AwsPromptIndicator
    if ($indicator) { Write-Host $indicator -ForegroundColor Yellow }
#>
function Get-AwsPromptIndicator {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [switch]$AlwaysShow
    )

    $status = Test-AwsAccountMismatch

    if ($status.HasMismatch) {
        return "⚠️  AWS: $($status.CurrentAccount) (expected: $($status.ExpectedAccount))"
    }
    elseif ($AlwaysShow -and $null -ne $status.CurrentAccount) {
        return "✓ AWS: $($status.CurrentAccount)"
    }

    return ""
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-AwsPromptIndicator',
    'Get-CurrentAwsAccountId',
    'Get-ExpectedAwsAccountId',
    'Test-AwsAccountMismatch',
    'Get-AwsPromptSegmentData',
    'Get-AwsPromptIndicator'
)
