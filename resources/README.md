# Resources Directory

This directory contains data files used by the PowerShell AWS Console.

## npm-packages.json

**Purpose:** Complete list of all npm package names for global package search functionality.

**Source:** https://raw.githubusercontent.com/nice-registry/all-the-package-names/master/names.json

**Size:** ~90MB (3.6M+ package names)

**Update Frequency:** Automatically checked every 24 hours during npm package searches with optional user-prompted update

### Automatic Updates

The package search feature automatically checks the file age when performing npm searches. If the file is older than 24 hours, you'll see:

```
Package list is X day(s) old.
Update now? (y/N):
```

Simply press `y` to download the latest version, or `N` to continue with the existing list.

### Manual Update

You can also manually update the package list at any time. Run this command from the project root:

```powershell
curl -s "https://raw.githubusercontent.com/nice-registry/all-the-package-names/master/names.json" -o resources/npm-packages.json
```

Or on Windows without curl:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/nice-registry/all-the-package-names/master/names.json" -OutFile "resources/npm-packages.json"
```

### Initial Setup

If you've just cloned this repository, you need to download the package list:

```powershell
# Create resources directory if it doesn't exist
New-Item -ItemType Directory -Path "resources" -Force

# Download package list
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/nice-registry/all-the-package-names/master/names.json" -OutFile "resources/npm-packages.json"
```

**Note:** This file is excluded from git (.gitignore) due to its size.
