# AWS Prompt Indicator Module

An optional PowerShell module for [powershell-console](../../README.md) that displays visual indicators in your prompt when your current directory's expected AWS account doesn't match your active AWS session.

## Features

- Automatically detects active AWS account from `~/.aws/credentials`
- Maps directories to expected AWS accounts via configuration
- Provides oh-my-posh custom segment for visual indicators
- Shows warning when working in a directory while logged into the wrong AWS account
- Zero impact when disabled (default state)

## Requirements

### Required
- **PowerShell 5.1+** (Windows PowerShell or PowerShell Core)
- **okta-aws-cli** - For AWS authentication via Okta
- **AWS CLI v2** - For AWS operations

### Recommended for Full Functionality
- **oh-my-posh** - For custom prompt theming with AWS account indicators
  - Install: `winget install JanDeDobbeleer.OhMyPosh` or `scoop install oh-my-posh`
  - Docs: https://ohmyposh.dev/
- **posh-git** - For enhanced git integration in prompts
  - Install: `Install-Module posh-git -Scope CurrentUser`
  - Docs: https://github.com/dahlbyk/posh-git

## Installation

This module is included with powershell-console. No separate installation required.

## Configuration

### 1. Enable the Feature

Edit `config.json` in the powershell-console root directory:

```json
{
  "awsPromptIndicator": {
    "enabled": true,
    "directoryMappings": {
      "C:\\AppInstall\\dev\\entity-network-hub": "054427526671",
      "C:\\AppInstall\\dev\\ets-nettools": "041457850300",
      "C:\\AppInstall\\dev\\terraform": "041457850300"
    }
  }
}
```

### 2. Directory Mappings

Map your working directories to their expected AWS account IDs:

- **Key**: Full path to directory (use double backslashes on Windows)
- **Value**: 12-digit AWS account ID

The module will match the current directory or any parent directory in the tree.

**Example**: If you're in `C:\AppInstall\dev\ets-nettools\terraform\modules\vpc`, the module will match the `C:\AppInstall\dev\ets-nettools` mapping.

### 3. Finding AWS Account IDs

Account IDs are available in your `config.json` under the `environments` section:

```json
"etsnettoolsprod": {
  "accountId": "041457850300"
}
```

Or run this from the powershell-console menu:
```powershell
aws sts get-caller-identity
```

## Usage

### Option 1: oh-my-posh Custom Segment (Recommended)

The module includes an example oh-my-posh theme configuration. See [aws-prompt-theme.omp.json](./aws-prompt-theme.omp.json).

1. **Copy the custom segment** from the example theme to your existing oh-my-posh config
2. **Customize colors and icons** to match your preference
3. **Reload your prompt**: `exec pwsh` or restart PowerShell

The AWS indicator will automatically appear in your prompt when there's a mismatch.

### Option 2: Manual Check

Use the module functions directly in your PowerShell profile or scripts:

```powershell
# Import the module
Import-Module "C:\AppInstall\dev\powershell-console\modules\aws-prompt-indicator\AwsPromptIndicator.psm1"

# Initialize with config path
Initialize-AwsPromptIndicator -ConfigPath "C:\AppInstall\dev\powershell-console\config.json"

# Get current AWS account
$currentAccount = Get-CurrentAwsAccountId
Write-Host "Current AWS Account: $currentAccount"

# Check for mismatch
$status = Test-AwsAccountMismatch
if ($status.HasMismatch) {
    Write-Host "⚠️  WARNING: AWS account mismatch!" -ForegroundColor Yellow
    Write-Host "  Current:  $($status.CurrentAccount)" -ForegroundColor Red
    Write-Host "  Expected: $($status.ExpectedAccount)" -ForegroundColor Green
}

# Get simple indicator for custom prompt
$indicator = Get-AwsPromptIndicator
if ($indicator) {
    Write-Host $indicator -ForegroundColor Yellow
}
```

### Option 3: Simple Prompt Function

Add this to your PowerShell profile for a basic implementation:

```powershell
function prompt {
    # Your existing prompt code here...

    # Add AWS indicator
    Import-Module "C:\path\to\modules\aws-prompt-indicator\AwsPromptIndicator.psm1" -Force
    Initialize-AwsPromptIndicator -ConfigPath "C:\path\to\config.json"

    $awsIndicator = Get-AwsPromptIndicator
    if ($awsIndicator) {
        Write-Host $awsIndicator -ForegroundColor Yellow -NoNewline
        Write-Host " " -NoNewline
    }

    # Return prompt string
    return "> "
}
```

## Module Functions

### `Initialize-AwsPromptIndicator`
Loads configuration and directory mappings.

**Parameters:**
- `-ConfigPath` (required): Path to config.json

**Returns:** Boolean - Success/failure

### `Get-CurrentAwsAccountId`
Reads the active AWS account from `~/.aws/credentials`.

**Returns:** String - 12-digit account ID or `$null`

### `Get-ExpectedAwsAccountId`
Gets the expected AWS account for the current directory.

**Returns:** String - 12-digit account ID or `$null`

### `Test-AwsAccountMismatch`
Compares current and expected accounts.

**Returns:** PSCustomObject with:
- `HasMismatch` (bool)
- `CurrentAccount` (string)
- `ExpectedAccount` (string)
- `CurrentDirectory` (string)
- `Message` (string)

### `Get-AwsPromptSegmentData`
Returns JSON data for oh-my-posh custom segments.

**Returns:** String (JSON)

### `Get-AwsPromptIndicator`
Gets a formatted text indicator.

**Parameters:**
- `-AlwaysShow` (switch): Show status even when accounts match

**Returns:** String - Formatted indicator text

## How It Works

### 1. AWS Account Detection

When you run `okta-aws-cli web`, it updates `~/.aws/credentials`:

```ini
[default]
aws_access_key_id = ASIA...
aws_secret_access_key = ...
aws_session_token = ...
```

The module parses this file and extracts the account ID from the IAM role ARN in the session metadata.

### 2. Directory Mapping

The module checks your current working directory against the configured mappings:

1. Exact path match
2. Parent directory match (traverses up the tree)

### 3. Comparison

If both current and expected accounts are found, the module compares them and shows an indicator if they don't match.

## Troubleshooting

### Indicator Not Showing

1. **Check if feature is enabled** in `config.json`:
   ```json
   "awsPromptIndicator": { "enabled": true }
   ```

2. **Verify directory mapping** exists for your current location

3. **Check AWS credentials file** exists:
   ```powershell
   Test-Path "$env:USERPROFILE\.aws\credentials"
   ```

4. **Verify you're logged in** to AWS:
   ```powershell
   aws sts get-caller-identity
   ```

### Wrong Account Detected

The module reads the `[default]` profile from `~/.aws/credentials`. If okta-aws-cli is writing to a different profile, you may need to adjust the module code or update your okta configuration.

### Performance Issues

The module reads from disk on each prompt render. If you experience slowness:

1. Use oh-my-posh's caching mechanisms
2. Add debouncing to only check every N seconds
3. Disable the feature when not needed

## Examples

### Example: Mismatch Warning

```
C:\AppInstall\dev\ets-nettools> # Logged into account 054427526671
⚠️  AWS: 054427526671 (expected: 041457850300)
```

### Example: Matching Accounts

```
C:\AppInstall\dev\ets-nettools> # Logged into account 041457850300
✓ AWS: 041457850300
```

### Example: No Mapping

```
C:\Users\mark> # Logged into account 041457850300
# No indicator shown (directory not mapped)
```

## Contributing

This module is part of the powershell-console project. See the main [CHANGELOG.md](../../CHANGELOG.md) for version history.

To report issues or suggest features:
1. Open an issue on the GitHub repository
2. Include your oh-my-posh version and theme configuration
3. Provide example directory mappings and expected behavior

## License

Same license as powershell-console. See main repository for details.

## Credits

- **okta-aws-cli**: https://github.com/okta/okta-aws-cli
- **oh-my-posh**: https://ohmyposh.dev/
- **posh-git**: https://github.com/dahlbyk/posh-git
