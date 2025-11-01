# Changelog

All notable changes to this project have been documented during development.

## Table of Contents

- [Version History](#version-history)
- [Development Utilities](#development-utilities)
- [Menu System Enhancements](#menu-system-enhancements)
- [AWS Account Management](#aws-account-management)
- [Instance Management](#instance-management)
- [Remote Access Features](#remote-access-features)
- [Package Manager Integration](#package-manager-integration)
- [Network Utilities](#network-utilities)
- [User Experience Improvements](#user-experience-improvements)
- [Bug Fixes](#bug-fixes)
- [Code Cleanup](#code-cleanup)

---

## Version History

### v1.2.1 (2025-11-01)

**Code Line Counter - Exclusion Rule Updates**

Updated exclusion rules in count-lines.py for better file filtering:

**Changes:**
- Moved `.vsix` exclusion from vscode-extensions project to global exclusions
- Added `.csv` exclusion for defender project
- Improved code organization with clearer section comments for global exclusions

### v1.2.0 (2025-11-01)

**Backup Dev Environment - Submenu and Improvements**

Added interactive submenu for backup operations with multiple modes and fixed test mode functionality:

**New Features:**
- Added backup submenu with four modes accessible from main menu:
  - List-Only Mode (Preview): Preview all changes without modifying files
  - Test Mode (Limited Preview): Preview limited operations with user-specified limit
  - Count Mode (Quantify Source): Count all files and directories, then exit
  - Full Backup: Create full backup with confirmation warning
- Interactive test mode now prompts for operation limit (default: 100)
- Improved user experience with safer preview options before destructive operations

**Bug Fixes:**
- Fixed Test Mode argument parsing that prevented it from working
- Refactored `Invoke-BackupScript` to accept string array instead of string
- Updated argument passing to use PowerShell splatting (`@Arguments`)
- Test mode now correctly passes `--test-mode` and limit as separate arguments

**Code Improvements:**
- Added `Get-BackupScriptPath` helper function for DRY principle
- Added `Invoke-BackupScript` helper function to centralize backup execution logic
- Created separate functions for each backup mode for better maintainability
- Improved error handling and user feedback

### v1.1.0 (2025-10-31)

**Backup Dev Environment - Major Enhancement**

Enhanced backup-dev.ps1 with advanced features and improved user experience:

**New Features:**
- GNU-style command-line arguments with full help system (`--help`, `--test-mode`, `--list-only`, `--count`)
- Test mode with configurable operation limits (default 100, minimum 100)
- List-only mode for dry-run previews without file modifications
- Count-only mode for quick file/directory statistics
- Two-pass operation: Pass 1 counts files, Pass 2 performs backup with accurate progress
- Visual progress indicators with animated spinner and percentage-based progress bar
- Real-time statistics display (directories, files, copied, extra)
- Dual logging system: detailed operation log + rotating summary history
- Smart log rotation (automatically keeps last 7 backup summaries)
- Runtime statistics and formatted completion reporting

**Improvements:**
- Removed OneDrive shutdown/restart functionality (no longer needed)
- Cleaned up unused variables for better code quality
- Added helper function `Write-Separator` for consistent visual formatting
- Enhanced robocopy integration with intelligent retry logic (/R:3 /W:5)
- Background job processing for responsive progress updates
- Improved error handling and graceful exits

**User Experience:**
- Progress updates every 500ms with spinner animation
- Clear mode indicators (TEST MODE, LIST-ONLY MODE, COUNT MODE)
- Comprehensive command-line help with usage examples
- Formatted output with color-coded messages (Cyan/Yellow/Green)
- Human-readable runtime display (mm:ss format)

**Configuration:**
- Paths configured via config.json (backupSource, backupDestination)
- Log files stored in script directory (backup-dev.log, backup-history.log)

### v1.0.0 (Initial Release)

Initial release with comprehensive AWS management console functionality.

---

## Development Utilities

### Backup Dev Environment Enhancements (v1.1.0)

See [Version History](#version-history) above for complete details of backup-dev.ps1 enhancements.

---

## Menu System Enhancements

### Menu Customization and Persistence

**Implemented Menu Customization Persistence** (Option 5 with Option 1)
- Store complete menu state in config.json, not deltas
- Auto-save changes after move/rename operations
- Menus stored as arrays of {text, action} objects

**Menu Structure**:
```json
{
  "menus": {
    "Main Menu": [
      { "text": "AWS Login", "action": "Start-AwsWorkflow" },
      { "text": "Ping Google", "action": "Start-InteractivePing..." }
    ]
  }
}
```

**Created Functions**:
- `Save-Menu` (lines 64-104): Saves entire menu state to config.json after changes
- `Get-MenuFromConfig` (lines 106-134): Loads menu from config or returns default

**Updated Functions**:
- `Show-ArrowMenu`: Auto-saves after Ctrl+Space move (line 1480) and Ctrl+R rename (line 1515)
- `Show-MainMenu`: Loads from config using Get-MenuFromConfig (line 1619)
- `Show-InstanceManagementMenu`: Loads from config using Get-MenuFromConfig (line 2859)
- `Show-PackageManagerMenu`: Loads from config using Get-MenuFromConfig (line 977)

**Menus with Persistence** (3 total):
1. Main Menu
2. Instance Management
3. Package Manager

**Benefits**:
- Simple - no complex overlay logic
- Complete menu state stored, easy to understand
- Auto-saves - user doesn't have to remember to save
- Backwards compatible - works with existing configs

### AWS Account Menu Persistence

**Implemented AWS Account Menu Persistence** (Option A - menuOrder approach)
- Store menu order as array in `awsAccountMenuOrder`
- Store custom names in `environment.customMenuNames`

**Created Helper Functions** (lines 136-271):
- `Get-AwsAccountMenuOrder`: Retrieves saved menu order array from config.json
- `Save-AwsAccountMenuOrder`: Saves menu order as array of "envKey:Role" strings
- `Save-AwsAccountCustomName`: Saves custom display names to environment.customMenuNames
- `Get-AwsAccountCustomName`: Retrieves custom display names for menu items

**Updated Show-AwsAccountMenu** (lines 2688-2838):
- Builds lookup hashtable of all account+role items from environments
- Checks for saved order and uses it if exists, otherwise alphabetical sort
- New items (not in saved order) are added at end alphabetically
- Custom display names override default "envKey (accountId) - Role: RoleName" format

**Updated Show-ArrowMenu Integration**:
- Ctrl+Space move (line 1641-1645): Detects AWS Account menu and calls Save-AwsAccountMenuOrder
- Ctrl+R rename (line 1681-1684): Detects AWS Account menu and calls Save-AwsAccountCustomName

**Data Structure in config.json**:
```json
{
  "awsAccountMenuOrder": [
    "exampleaccount1:Admin",
    "exampleaccount2:Admin",
    "exampleaccount3:Admin"
  ],
  "environments": {
    "exampleaccount1": {
      "customMenuNames": {
        "Admin": "Production Account - Admin Role",
        "default": "Production Account"
      }
    }
  }
}
```

**Benefits**:
- Menu order persists across script restarts
- Custom names persist across script restarts
- Order preserved during Sync - new accounts added at end
- Uses environment data as source of truth
- No duplicate data between environments and menus

### In-Menu Editing

**Added in-menu editing functionality** (lines 1359-1490)
- Integrated move and rename capabilities directly into Show-ArrowMenu
- Updated footer with emoji key indicators

**Implemented Ctrl+Space for move mode** (lines 1392-1459):
- Enters dedicated "MOVE MODE" with magenta highlighting
- Shows item being moved with "→ text ←" arrows in magenta
- Other items shown in dark gray for visual distinction
- Up/Down arrows swap item positions dynamically
- Enter confirms move, Escape cancels
- Selection cursor follows moved item automatically

**Implemented Ctrl+R for rename** (lines 1461-1487):
- Opens inline rename dialog showing current name
- Prompts for new name with option to cancel
- Updates menu item text immediately
- Works with both string and object menu items

**Changes apply immediately during session**
- All menus automatically support editing without code changes
- Removed standalone menu editor functions

### Menu Position Memory

**Implemented menu position memory** (Option 1 - Session-based)
- Added global hashtable `$global:MenuPositionMemory = @{}` (line 76)
- Created `Get-SavedMenuPosition` helper function (lines 950-971)
- Created `Save-MenuPosition` helper function (lines 973-997)
- Modified `Show-ArrowMenu` to restore last position (line 1007)
- Position saved when user selects with Enter (line 1056)
- Position NOT saved when going back with ESC/Q
- Memory persists for entire script session
- All menus automatically benefit with no changes required

### Menu Legend and Navigation

**Menu Legend Formatting Improvements** (lines 1526, 1593)
- Replaced emoji arrows with ASCII: `↑↓ navigate`
- Removed space between arrows
- Changed Ctrl indicators to lowercase: `⌃x exit`, `⌃r rename`
- Final format: `↑↓ navigate | ⏎ select | ⎋ back | ⌃x exit | ⌃␣ move | ⌃r rename`
- Move mode: `↑↓ move position | ⏎ confirm | ⎋ cancel`

**Enhanced navigation with ESC and Ctrl-X**:
- Added ESC key support to go back one level (line 1001-1003)
- Added Ctrl-X to exit script completely (lines 1007-1015)
- Updated instruction text
- Q key still works for backward compatibility
- Ctrl-X immediately exits with cleanup (Restore-ConsoleState)

**Fixed Q key navigation to go up only one menu level**:
- Removed explicit call to Show-AwsAccountMenu from Show-AwsActionMenu
- Changed to return instead of calling
- Modified Show-AwsAccountMenu to use continue instead of break
- Q properly navigates: AWS Actions → AWS Account Menu → Main Menu

---

## AWS Account Management

### Multi-Role Support

**Added multi-role support for AWS accounts**:
- Fixed role name case sensitivity (Admin with capital A, devops lowercase)
- Created separate Okta profiles for each role combination
- Added oktaProfileMap to config.json
- Added accountId, availableRoles, and preferredRole fields

**Created Functions**:
- `Select-AwsRole`: Present role selection menu when multiple roles available
- `Set-PreferredRole`: Store user's role preference in config.json

**Modified Start-AwsLoginForAccount**:
- Checks for multiple roles and prompts user to select
- Selected role maps to specific Okta profile
- Preferred role automatically pre-selected in menu
- Preference saved when user selects different role

### AWS Account Menu Redesign

**Redesigned AWS Account Menu to show Account+Role combinations**:
- Menu displays each account+role combination as separate item
- Format: "friendlyname (accountId) - Role: RoleName"
- Example: "exampleaccount (123456789012) - Role: Admin"
- Users select specific role from menu instead of prompt after selection
- Modified Start-AwsLoginForAccount to accept PreselectedRole parameter
- Accounts without roles show as: "friendlyname (accountId)"
- Menu items sorted alphabetically by account name
- Manual and Sync options appear at bottom
- Removed redundant "Re-run from Okta" action

### Account Synchronization

**Implemented and Fixed AWS Account Sync feature**:
- Added "Sync AWS Accounts from Okta" option to AWS account menu
- Created `Backup-ConfigFile` to backup config.json and okta.yaml
- Main `Sync-AwsAccountsFromOkta` runs okta-aws-cli with --all-profiles

**Sync Features**:
- ALWAYS uses 1-hour session duration to avoid re-authentication
- Parses okta-aws-cli output from "Updated profile" lines
- Extracts account names and roles from profile names
- Matches profile names to account IDs using okta.yaml IDP mappings
- Discovers all AWS accounts and roles from Okta in single authentication
- Converts friendly names to proper display names
- Renames accounts with wrong keys
- Checks for duplicate entries using normalized matching
- Merges duplicates, prefers entry matching Okta friendly name
- Updates config.json with newly discovered accounts
- Updates existing accounts with new roles
- Updates display names to match Okta during sync
- Creates placeholder entries for new accounts
- Sets sessionDuration="3600" for ALL synced accounts
- Uses sessionDuration from config when authenticating

**Created Functions**:
- `Update-ScriptConfiguration`: Reload config after changes
- `Get-OktaIdpMapping`: Extract friendly names from okta.yaml

**Account list automatically updated after sync**:
- Alphabetically sorted with Manual and Sync at bottom
- Returns to AWS account menu instead of main menu
- Preserves existing custom settings
- Shows summary of changes

**Updated Sync Function** (lines 2654-2665):
- Removes old deprecated menu data from config.json
- Preserves `awsAccountMenuOrder`
- New accounts/roles added at end of list
- User preference: keep custom order through Sync

**Step 6: Automatically creates missing profiles in okta.yaml**:
- Profiles created with correct account ID, role, and session duration
- All discovered profiles from okta-aws-cli added if missing

### AWS Context Display

**Added AWS Context Header to Instance Management Menu**:
- Displays current AWS account information at top
- Shows: `AWS Context: accountname (Account: 123456789012) - Region: us-east-1`
- Uses ANSI color codes (yellow) to match other displays
- Updates dynamically on each menu display
- Provides context awareness
- Implementation: Added HeaderLines parameter to Show-ArrowMenu (line 2832)

**Added account context display to instance tables**:
- Shows AWS account name, account ID, and region at top
- Format: "AWS Context: accountname (Account: 123456789012) - Region: us-east-1"
- Changed color to Yellow for visual consistency
- Removed blank line between context and table
- Shows whenever viewing EC2 instances
- Added to Get-Ec2InstanceInfo (line 2403)
- Added to Select-Ec2Instance (line 2560)

**Fixed instance selection menus to display context inline**:
- Modified Show-ArrowMenu to accept HeaderLines parameter (lines 948, 957-963)
- Header lines redisplayed on each menu redraw
- Updated Select-Ec2Instance to build header with context and legend (lines 2557-2581)
- Uses ANSI color codes for colored display
- Context and legend visible while navigating
- User can see AWS account context during instance selection

### Authentication Improvements

**Deprecated AWS Actions menu**:
- Goes directly to Instance Management after authentication (line 1249)
- Bypasses AWS Actions menu
- Changed prompt from "AWS Actions menu" to "Instance Management" (line 1217)
- Simpler navigation: Okta auth → Instance Management → ESC to select different account
- Functions still exist but not used in main flow

**Added 5 second auto-continue timer**:
- After authentication, automatically continues after 5 seconds (lines 1220-1246)
- Displays animated spinner: | / - \\ rotating every 100ms
- Shows countdown: "| Continuing in 5 seconds..."
- User can press any key to continue immediately
- Uses ANSI escape sequences to update in place
- Clears countdown line before proceeding
- Provides smooth UX with visual feedback

---

## Instance Management

### Instance Display Enhancements

**Enhanced instance display with visual markers**:
- Added markers to DescribeInstances table (lines 2489-2498):
  - `*  ` prefix for Default Instance (yellow)
  - `+  ` prefix for Default Host (cyan)
  - `*+ ` prefix for Both (yellow)
- Added legend: "Legend: * = Default Instance | + = Default Host | *+ = Both" (line 2502)
- Legend appears directly after table with no blank line
- Added blank line before pause (line 2509)

**Updated Legend and "Both" indicator**:
- Changed from "** = Both" to "*+ = Both" (lines 3005, 3134)
- Changed display marker from "** " to "*+ " (lines 2995, 3150)
- Consistent format across Get-RunningInstances and Select-Ec2Instance
- Changed "Default IP" to "Default Host" in legend (line 2621)

### Instance Configuration

**Replaced Set-DefaultRemoteIP with Set-DefaultRemoteHostInfo**:
- Uses Select-Ec2Instance for interactive selection
- Prompts for RemotePort and LocalPort
- Shows configuration summary before saving
- Saves all settings to config.json
- Updated Instance Management menu to call new function

**Added "None" option to EC2 instance selection**:
- Allows clearing instance and remote host configuration
- Both Set-DefaultInstanceId and Set-DefaultRemoteHostInfo support clearing
- Useful for accounts without Aloha

**Simplified Set-DefaultRemoteHostInfo**:
- Removed redundant "Step 2" prompt for Remote IP
- Automatically uses selected instance's Private IP address
- Renumbered steps accordingly
- Step 2 is now Remote Port, Step 3 is Local Port

**Fixed bug where Remote Host Instance ID overwriting Default Instance ID**:
- Created separate field instances.'remote-host' (lines 2782-2786)
- Default Instance ID remains in instances.'jump-box'
- Updated cache key to use "remote-host" (line 2812)
- Updated Show-CurrentInstanceSettings to display separately (lines 2842-2852)
- Shows "Instance ID" for default and "Remote Host Instance ID" under Remote Host Info
- Truly independent settings

**Added instance names/descriptions to Show-CurrentInstanceSettings**:
- Created `Get-InstanceNameById` helper to fetch Name tag (lines 2829-2858)
- Uses aws ec2 describe-instances with correct profile
- Display format: "i-xxxxx (Aloha)" (lines 2835-2845)
- Remote Host format: "i-xxxxx (Jump Box)" (lines 2860-2869)
- Shows only ID if Name tag unavailable

### Instance Selection Improvements

**Fixed Select-Ec2Instance menu display**:
- Removed New-MenuAction wrapper from instance menu items
- Changed to use simple string array for display
- Menu properly displays instance information
- Fixed issue with vertical character fragments

**Fixed single-instance parsing bug** (lines 2502-2523):
- When only one instance exists, JSON returns single array
- Added logic to detect single vs multiple instances
- Prevents foreach from iterating over property values

**Fixed Q key behavior in Set Default menus**:
- Modified Select-Ec2Instance to return @{ Cancelled = $true } (line 2616)
- Previously Q and "None" both returned null
- Updated Set-DefaultInstanceId to detect cancellation (lines 2635-2640)
- Updated Set-DefaultRemoteHostInfo to detect cancellation (lines 2701-2706)
- Pressing Q shows "Selection cancelled - no changes made"
- Settings remain unchanged when Q pressed vs "None"

**Changed default to "No" for clearing remote host settings**:
- Updated prompt from "(Y/n)" to "(y/N)" (line 2709)
- Changed logic to require explicit "y" to proceed (line 2710)
- Pressing Enter or other keys cancels operation
- Safer default prevents accidental deletion

### Configuration Management

**Cleaned up Show-CurrentInstanceSettings output**:
- Removed "Last Used Remote IP" line
- Removed "Last Used Ports" line
- Shows only Environment, Region, and Instance ID (lines 2804-2811)

**Enhanced Show-CurrentInstanceSettings to display Remote Host Info**:
- Added "Default Remote Host Info" section
- Displays Remote Host Instance ID, Remote IP, Remote Port, Local Port
- Shows "(not configured)" in gray if values not set
- Provides complete view of all settings

**Fixed bug where config changes not immediately visible**:
- Added Update-ScriptConfiguration call after saving in Set-DefaultInstanceId (line 2675)
- Added Update-ScriptConfiguration call in Set-DefaultRemoteHostInfo (line 2806)
- Configuration reloaded from file after changes
- Show-CurrentInstanceSettings displays newly saved values correctly

---

## Remote Access Features

### Aloha Remote Access

**Restored and enhanced Aloha Remote Access functionality**:
- Created `Start-AlohaRemoteAccess` function (lines 2753-2874)
- Added "Aloha Remote Access" to Instance Management menu (line 2870)
- Displays current instance settings matching View Current Instance Settings
- Shows Default Instance ID with name (e.g., "i-xxxxx (Aloha)")
- Shows Remote Host configuration
- Prompts to use current settings or modify (Y/n/m)
- Auto-launches Set-DefaultRemoteHostInfo if settings incomplete
- Restarts itself after configuration to show updated settings
- Changed RDP prompt default to "Y" (Y/n instead of y/N)

**Fixed AWS profile parameter in Start-AlohaConnection** (line 3494):
- Changed from $global:currentAwsEnvironment to $global:currentAwsProfile
- Uses correct AWS CLI profile name for authentication

**Fixed Oh-My-Posh initialization error** (line 3536):
- Added -NoProfile flag to PowerShell launch
- Avoids profile conflicts

**Fixed Aloha command execution** (line 3536):
- Changed from single quotes to double quotes
- Proper variable expansion
- Command actually executes instead of literal "$Command"

**Fixed instance ID selection logic** (line 2863):
- Uses $defaultInstanceId for SSM connection (-i parameter)
- Uses $remoteIP from Remote Host config for port forwarding (-r parameter)
- Correct architecture: SSM into Aloha instance, forward to Jump Box IP

**RDP Manager Launcher Window Minimization** (line 3746):
- Changed `-WindowStyle Normal` to `-WindowStyle Minimized`
- Launcher window starts minimized instead of appearing in front
- Window accessible in taskbar for monitoring
- Cleaner user experience

### VPN Management

**Added "Get VPN Connections" to Instance Management menu**:
- Added menu item on line 2773
- Removed deprecated post-search menu flow
- Function pauses after results and returns to menu
- Cleaner flow: Search VPN → View Results → Press key → Back to menu

**Added AWS credential validation and profile support**:
- Validates credentials before executing VPN query
- Uses `$global:currentAwsProfile` for correct profile
- Shows friendly error if credentials expired
- Prevents cryptic AWS API errors

**Improved output formatting**:
- Changed from single-line to formatted table
- Format: NAME (40 chars) | VPN CONNECTION ID
- Shows total count of VPN connections
- Saved file includes header with search term and timestamp
- Example output with proper table formatting

**VPN Connections AWS CLI Command**:
- `aws ec2 describe-vpn-connections --profile {profile} --query 'VpnConnections[].{Name:Tags[?Key==\`Name\`].Value | [0],VpnConnectionId:VpnConnectionId}' --output text`
- Filters by user-provided search string
- Saves to `vpn_output/vpn_connections_{search}_{timestamp}.txt`
- Located in Get-VpnConnections function (around line 3511)

---

## Package Manager Integration

### Package Manager Enhancements

**Enhanced Package Manager functionality**:
- Added pause before winget list with default "Y" prompt (line 302)
- Allows leisurely review of Scoop and npm output
- Sorted winget list alphabetically by package name (lines 327-380)
- Parses output to separate header, data, and footer
- Maintains proper table formatting while displaying sorted results

**Added "Search Packages" menu option** (line 726):
- Created Search-Packages function (lines 639-809)
- Prompts for Installed vs Globally available search (default: Installed)
- Uses different commands for each scope
- Highlights installed packages in green when searching globally
- Excluded npm from all searches as requested
- Sorted all results alphabetically (Scoop and winget)
- Fixed Scoop results to exclude headers and separators
- Removed extra blank lines

### Scoop Status Parsing Fix

**Fixed Package Manager scoop status parsing** (lines 606-661):
- Fixed `scoop status` output parsing
- Root Cause: Parser looked for old format instead of table format
- Solution: Updated parser to recognize table format
- Removed output suppression from scoop update (line 611)
- Removed output suppression from scoop status (line 615)
- Parser correctly identifies packages needing updates
- Handles "Scoop is up to date" message
- Still detects packages below that need updating
- User can see all output on screen

**Fixed Manage Updates**:
- Runs "scoop update" first to update buckets
- Then runs "scoop status"
- Removed redundant bucket update option

---

## Network Utilities

### Network Configuration Display

**Show-NetworkConfiguration functionality**:
- Comprehensive display of network adapters
- Shows IPs, DNS, DHCP settings
- Sorted by status (Up first) and IP type (routable first)
- Color-coded output
- Adapter details include MAC, link speed
- System information with computer name and DNS domain

**Interactive Ping**:
- Continuous ping with real-time latency display
- Press Q to quit and return to menu
- Shows timestamp, IP, response time, TTL
- Error handling for timeouts

---

## User Experience Improvements

### Console Initialization

**Console encoding setup** (lines 7-18):
- Save original console state
- Set console encoding to UTF-8 for proper character rendering
- Set PowerShell output encoding
- Don't modify PSStyle.OutputRendering for Oh-My-Posh compatibility

**Restore-ConsoleState function** (lines 21-37):
- Restore original encoding settings
- Clear keyboard buffer
- Reset console cursor visibility
- Write newline for clean prompt rendering

### Timed Pause Enhancement

**Fixed Invoke-TimedPause countdown display** (lines 1232-1260):
- Eliminated duplicate lines during countdown
- Added $lastRemaining tracking
- Only updates when second changes
- Clears line properly before rewriting
- Prevents text overlap
- Countdown updates cleanly on single line

### Port Prompt Simplification

**Simplified port prompts** (lines 2791-2814):
- Remote Port: "Enter Remote Port [3389]"
- Local Port: "Enter Local Port [8388]"
- Clean, simple display of current value
- Removed verbose text
- Pressing Enter keeps current value
- Falls back to sensible defaults if no current value

---

## Bug Fixes

### AWS Profile Authentication

**Fixed AWS profile authentication issue** (CRITICAL BUG FIX):
- Root Cause: All accounts showed instances from wrong account
- Issue: Previously removed --profile flag incorrectly
- Reality: okta-aws-cli only sets environment variables in "exec" mode
- Solution: Store actual Okta profile name in $global:currentAwsProfile
- Modified Invoke-AwsAuthentication to accept ProfileName (line 1155, 1178)
- Modified Start-AwsLoginForAccount to extract and pass profile (lines 1297-1320)
- Updated Get-Ec2InstanceInfo to build --profile parameter (lines 2364-2386)
- Updated Get-Ec2InstancesData to build --profile parameter (lines 2447-2467)
- Updated credential validation to use correct profile
- Each AWS account now shows its own instances
- All AWS CLI commands use: --profile $global:currentAwsProfile
- Fixes issue where any account showed wrong account's instances

---

## Code Cleanup

### Major Cleanup

**MAJOR CLEANUP - Removed deprecated code and unused functions**:
- Backup Created: `cmdprmpt.ps1.backup-20251018-060208`
- Lines Removed: 222 lines (3,812 → 3,590 lines = 5.8% reduction)
- Functions Removed: 8 functions (51 → 43 functions)

**Category 1 - Deprecated AWS Actions Menu System** (5 functions):
- Removed `New-StandardAwsActions` (lines 933-945)
- Removed `Get-EnvironmentActions` (lines 947-969)
- Removed `Get-ManualAwsActions` (lines 971-978)
- Removed `Show-AwsActionMenu` (lines 2629-2652)
- Removed `Get-AccountSpecificActions` (lines 2654-2656)
- Note: Already deprecated per TODO line 309

**Category 2 - Unused Box Menu System** (3 functions):
- Removed `Show-AlohaBoxMenu` (lines 2663-2688)
- Removed `Get-AccountSpecificBoxes` (lines 2690-2737)
- Removed `Start-CustomAlohaConnection` (lines 2798-2776)
- Note: Replaced by dynamic instance management

**Category 3 - Code Optimization** (1 function):
- Inlined `Get-InstanceConfigurations` into `Get-CurrentInstanceId`
- Function only had one caller
- Inlining improves code readability
- Removed function overhead and indirection

**Removed deprecated key-letter highlighting**:
- Simplified `New-MenuAction` to only accept Text and Action
- Updated all menu creation code throughout script

---

## Summary Statistics

- **Total Features Added**: 50+
- **Bug Fixes**: 15+
- **Code Improvements**: 20+
- **Lines of Code**: ~3,590 (after cleanup)
- **Total Functions**: 43
- **Menus with Persistence**: 4 (Main, Package Manager, Instance Management, AWS Account)
- **Package Managers Supported**: 3 (Scoop, npm, winget)
- **AWS Features**: Multi-account, multi-role, sync, SSM, VPN management
