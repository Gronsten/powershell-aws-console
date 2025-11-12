# Backup-Dev Module

A PowerShell module for [powershell-console](../../README.md) that provides intelligent backup functionality for the dev directory with multiple operation modes.

## Features

- **Multiple Backup Modes**
  - Full backup (complete mirror with deletions)
  - Test mode (preview limited number of operations)
  - Count mode (count files and directories only)
- **Smart Exclusions** - Respects .gitignore patterns and custom exclusion rules
- **Progress Tracking** - Real-time progress indicators during operations
- **Configurable** - Uses config.json for backup source/destination paths
- **Logging** - Comprehensive logging to backup-dev.log and backup-history.log

## Requirements

- **PowerShell 5.1+** (Windows PowerShell or PowerShell Core)
- **Robocopy** (included with Windows)

## Configuration

Edit `config.json` in the powershell-console root directory:

```json
{
  "paths": {
    "backupSource": "C:\\AppInstall\\dev",
    "backupDestination": "D:\\Backups\\dev"
  }
}
```

## Usage

### From console.ps1 Menu (Recommended)

The easiest way to use backup-dev is through the console.ps1 menu:

1. Run `console.ps1`
2. Select "Backup" from the menu
3. Choose your backup mode:
   - **Count Only** - Count files and directories
   - **Test Mode** - Preview limited operations (configurable limit, minimum 100)
   - **Full Backup** - Complete mirror with deletions

### Direct Script Usage

You can also call the script directly:

```powershell
# Count only
.\modules\backup-dev\backup-dev.ps1 --count

# Test mode with default limit (100 items)
.\modules\backup-dev\backup-dev.ps1 --test-mode

# Test mode with custom limit (minimum 100)
.\modules\backup-dev\backup-dev.ps1 --test-mode 250

# Full backup
.\modules\backup-dev\backup-dev.ps1

# Show help
.\modules\backup-dev\backup-dev.ps1 --help
```

## Command-Line Options

| Option | Description |
|--------|-------------|
| `--count` | Only count files and directories, then exit |
| `--test-mode [N]` | Quick test: preview limited to N operations (N >= 100, default: 100) |
| `--help` | Show help message |

**Note:** The `--count` option runs alone and ignores other switches.

## How It Works

### Backup Process

1. **Load Configuration** - Reads source and destination paths from config.json
2. **Apply Exclusions** - Filters out files/directories based on .gitignore patterns
3. **Execute Robocopy** - Uses robocopy for efficient file mirroring
4. **Log Results** - Records operations to backup-dev.log and backup-history.log

### Exclusion Rules

The backup automatically excludes:
- Git repositories (`.git/`)
- Node modules (`node_modules/`)
- Python virtual environments (`venv/`, `.venv/`)
- Build artifacts (`dist/`, `build/`)
- IDE files (`.vscode/`, `.idea/`)
- System files (`.DS_Store`, `Thumbs.db`)
- And more (see backup-dev.ps1 for complete list)

### Logging

Two log files are maintained:
- **backup-dev.log** - Current session log (detailed)
- **backup-history.log** - Historical log with timestamps (cumulative)

## Integration with console.ps1

The backup-dev module integrates with console.ps1 through helper functions:

- `Get-BackupScriptPath` - Locates the backup script
- `Invoke-BackupScript` - Executes backup with specified arguments
- `Start-BackupCountMode` - Runs count-only mode
- `Start-BackupTestMode` - Runs test mode with user-provided limit
- `Start-BackupDevEnvironment` - Runs full backup with confirmation

## Troubleshooting

### Script Not Found

If you see "backup-dev.ps1 not found", verify:
1. The script exists in `modules/backup-dev/backup-dev.ps1`
2. You're running from the correct directory

### Config File Not Found

If you see "Config file not found", verify:
1. `config.json` exists in the powershell-console root
2. The file contains valid JSON
3. Paths are specified with double backslashes (`\\`) on Windows

### Backup Not Working

1. **Check paths** in config.json are correct
2. **Verify permissions** to read source and write to destination
3. **Check disk space** on destination drive
4. **Review logs** in backup-dev.log for detailed error messages

## Examples

### Example: Count Mode

```powershell
PS C:\AppInstall\dev\powershell-console> .\modules\backup-dev\backup-dev.ps1 --count
COUNT MODE - Only scanning source files

Source Inventory vs. Changes
───────────────────────────────────────────
               Inventory   Need to Copy
───────────────────────────────────────────
  Directories:      1,234            45
  Files:          123,456         1,234
───────────────────────────────────────────
  Total:          124,690         1,279
───────────────────────────────────────────
```

### Example: Test Mode

```powershell
PS C:\AppInstall\dev\powershell-console> .\modules\backup-dev\backup-dev.ps1 --test-mode 250
Test mode will preview a limited number of operations.
Limit: 250 items

Processing first 250 items...
[Preview of operations...]
```

## Contributing

This module is part of the powershell-console project. See the main [CHANGELOG.md](../../CHANGELOG.md) for version history.

To report issues or suggest features:
1. Open an issue on the GitHub repository
2. Include your PowerShell version and OS details
3. Provide relevant log excerpts from backup-dev.log

## License

Same license as powershell-console. See main repository for details.
