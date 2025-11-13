# Migration Guide: v1.6.0 → v1.7.0

## Overview

Version 1.7.0 adds config versioning and environment indicators. **No directory structure changes** for regular users - the `_dev/_prod` structure is only for repository maintainers.

## ⚠️ Action Required After Upgrade

### 1. Update PowerShell Profile Path (Repository Maintainers Only)

> **Note:** This section **only applies to repository maintainers** who work with the `_dev/_prod` structure. Regular users should skip to section 2.

If you're a repository maintainer and using the `aws-prompt-indicator` module in your PowerShell profile, update the path from the old flat structure to the new `_dev` location:

**Location:** `Microsoft.PowerShell_profile.ps1`

**Change from:**
```powershell
Import-Module "C:\AppInstall\dev\powershell-console\modules\aws-prompt-indicator\AwsPromptIndicator.psm1"
Enable-AwsPromptIndicator -ConfigPath "C:\AppInstall\dev\powershell-console\config.json"
```

**Change to:**
```powershell
Import-Module "C:\AppInstall\dev\powershell-console\_dev\modules\aws-prompt-indicator\AwsPromptIndicator.psm1"
Enable-AwsPromptIndicator -ConfigPath "C:\AppInstall\dev\powershell-console\_dev\config.json"
```

### 1b. Regular Users (No Path Change Needed)

> **For regular users:** Your PowerShell profile paths remain unchanged. Just update to match wherever you installed the console:

**Example** (adjust to your installation location):
```powershell
Import-Module "C:\Tools\powershell-console\modules\aws-prompt-indicator\AwsPromptIndicator.psm1"
Enable-AwsPromptIndicator -ConfigPath "C:\Tools\powershell-console\config.json"
```

**No change needed** - the paths stay the same as before, pointing to your installation directory.

### 2. Update config.json (Automatic via upgrade-prod.ps1)

The upgrade script automatically adds these new fields:

```json
{
  "configVersion": "1.7.0",
  "paths": {
    "devRoot": "C:\\AppInstall\\dev"
  }
}
```

**If manually editing:**
1. Add `"configVersion": "1.7.0"` at the root level
2. Add `"devRoot": "C:\\AppInstall\\dev"` to the `paths` section

### 3. Update Any Custom Scripts or Shortcuts

If you have custom scripts or shortcuts that reference the console, update paths:

**Old:**
```powershell
cd C:\AppInstall\dev\powershell-console
.\console.ps1
```

**New (for DEV):**
```powershell
cd C:\AppInstall\dev\powershell-console\_dev
.\console.ps1
```

**New (for PROD):**
```powershell
cd C:\AppInstall\dev\powershell-console\_prod
.\console.ps1
```

## New Directory Structure

```
C:\AppInstall\dev\powershell-console\
├── _dev\                           # Development environment
│   ├── .git\                       # Git repository
│   ├── console.ps1                 # v1.7.0+ DEV version
│   ├── config.json                 # DEV config (your settings)
│   ├── modules\, scripts\, resources\
│   └── ...
├── _prod\                          # Production environment
│   ├── console.ps1                 # Stable PROD version
│   ├── config.json                 # PROD config (your settings)
│   └── ...
└── upgrade-prod.ps1                # Upgrade script
```

## Visual Indicators

Starting in v1.7.0, the console shows which environment you're in:

**DEV:**
```
[DEV] PowerShell Console v1.7.0
Window Title: PowerShell Console [DEV] v1.7.0
```

**PROD:**
```
[PROD] PowerShell Console v1.7.0
Window Title: PowerShell Console [PROD] v1.7.0
```

- `[DEV]` = Yellow
- `[PROD]` = Green

## Upgrading PROD Environment

After merging v1.7.0, upgrade your PROD environment:

```powershell
cd C:\AppInstall\dev\powershell-console
.\upgrade-prod.ps1
```

This will:
1. Download v1.7.0 from GitHub
2. Backup your PROD config.json
3. Smart merge new config fields (adds configVersion and paths.devRoot)
4. Update PROD to v1.7.0
5. Preserve all your settings

## Rollback (If Needed)

If something goes wrong, your config backup is saved:

```
C:\AppInstall\dev\powershell-console\_prod\config.json.backup
```

To rollback:
1. Copy `config.json.backup` → `config.json`
2. Download v1.6.0 release from GitHub
3. Extract to `_prod` folder

## Verification Checklist

After upgrade, verify:

- [ ] PowerShell profile loads without errors (restart PowerShell)
- [ ] AWS Prompt Indicator works (if using it)
- [ ] DEV console shows `[DEV]` indicator
- [ ] PROD console shows `[PROD]` indicator
- [ ] Code Count feature works (`Code Count` menu option)
- [ ] Git operations work from `_dev` directory

## Need Help?

If you encounter issues:

1. Check PowerShell profile path is updated to `\_dev`
2. Verify config.json has `configVersion` and `paths.devRoot`
3. Ensure you're in correct directory for Git operations (`_dev`)
4. Review PR #18 for full changes: https://github.com/Gronsten/powershell-console/pull/18

## Summary of Path Changes

| Component | Old Path | New Path |
|-----------|----------|----------|
| **Git Operations** | `powershell-console\` | `powershell-console\_dev\` |
| **PowerShell Profile Module** | `powershell-console\modules\...` | `powershell-console\_dev\modules\...` |
| **PowerShell Profile Config** | `powershell-console\config.json` | `powershell-console\_dev\config.json` |
| **Production Console** | `powershell-console\console.ps1` | `powershell-console\_prod\console.ps1` |
| **Development Console** | `powershell-console\console.ps1` | `powershell-console\_dev\console.ps1` |

---

**Questions?** Open an issue on GitHub or review the full documentation in CLAUDE.md and REPOS.md.
