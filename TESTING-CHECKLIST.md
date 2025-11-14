# Testing Checklist for Invoke-StandardPause Refactoring
## PR #19 - Standardize Pause/Break/Return Functions

**Testing Goal:** Verify that all 45 replaced pause instances work correctly with Enter and Esc keys.

---

## Test Instructions

For each test below:
1. Navigate to the menu/feature
2. Trigger the pause (complete the action)
3. **Test Enter key** - Should continue as expected
4. **Test Esc key** - Should also continue (new behavior!)
5. **Test Q key** (where applicable) - Should quit/cancel

**Expected Behavior:**
- ✅ Enter continues
- ✅ Esc continues (NEW - previously didn't work)
- ✅ Q quits (only where `-AllowQuit` is used)

---

## 1. Package Manager Menu (3 tests)

### 1.1 Manage Updates
- [ ] Navigate: Main Menu → Package Manager → Manage Updates
- [ ] Complete the update selection/action
- [ ] **Test:** Press Enter to return to menu
- [ ] **Test:** Repeat and press Esc to return to menu

### 1.2 List Installed Packages
- [ ] Navigate: Main Menu → Package Manager → List Installed Packages
- [ ] View the package list
- [ ] **Test:** Press Enter to return to menu
- [ ] **Test:** Repeat and press Esc to return to menu

### 1.3 Search Packages
- [ ] Navigate: Main Menu → Package Manager → Search Packages
- [ ] Perform a search
- [ ] **Test:** Press Enter to return to menu
- [ ] **Test:** Repeat and press Esc to return to menu

---

## 2. Meraki Backup (3 tests)

### 2.1 Python Not Found Error
- [ ] Temporarily rename python.exe to test error
- [ ] Navigate: Main Menu → Meraki Backup
- [ ] **Test:** Press Enter after error message
- [ ] **Test:** Repeat and press Esc after error message
- [ ] Restore python.exe

### 2.2 Backup Script Not Found Error
- [ ] Navigate to meraki-api directory and temporarily rename backup.py
- [ ] Navigate: Main Menu → Meraki Backup
- [ ] **Test:** Press Enter after error message
- [ ] **Test:** Repeat and press Esc after error message
- [ ] Restore backup.py

### 2.3 Successful Backup
- [ ] Navigate: Main Menu → Meraki Backup
- [ ] Complete backup (or cancel it)
- [ ] **Test:** Press Enter to return to menu
- [ ] **Test:** Repeat and press Esc to return to menu

---

## 3. Code Count (6 tests)

### 3.1 Python Not Found Error
- [ ] Temporarily rename python.exe
- [ ] Navigate: Main Menu → Code Count
- [ ] **Test:** Press Enter after error message
- [ ] **Test:** Repeat and press Esc after error message
- [ ] Restore python.exe

### 3.2 Script Not Found Error
- [ ] Temporarily rename count-lines.py
- [ ] Navigate: Main Menu → Code Count
- [ ] **Test:** Press Enter after error message
- [ ] **Test:** Repeat and press Esc after error message
- [ ] Restore count-lines.py

### 3.3 Empty Directory
- [ ] Navigate: Main Menu → Code Count
- [ ] Browse to an empty directory
- [ ] **Test:** Press Enter to go back
- [ ] **Test:** Repeat and press Esc to go back

### 3.4 No Items Selected
- [ ] Navigate: Main Menu → Code Count
- [ ] Don't select any items, proceed
- [ ] **Test:** Press Enter after "No items selected"
- [ ] **Test:** Repeat and press Esc

### 3.5 All Projects Count
- [ ] Navigate: Main Menu → Code Count
- [ ] Select "All Projects"
- [ ] **Test:** Press Enter to view individual project counts
- [ ] **Test:** Repeat and press Esc

### 3.6 Multi-Project Pagination
- [ ] Navigate: Main Menu → Code Count
- [ ] Select multiple projects (3+)
- [ ] After first project displays:
  - [ ] **Test Enter:** Continue to next project
  - [ ] **Test Q:** Quit viewing remaining projects (should skip)
  - [ ] **Test Esc:** Also quit viewing remaining projects
- [ ] After all projects shown:
  - [ ] **Test:** Press Enter to return to selection
  - [ ] **Test:** Repeat and press Esc

---

## 4. Backup Functions (3 tests)

### 4.1 Get-BackupScriptPath - No Script Found
- [ ] Navigate: Main Menu → Backup Dev Environment
- [ ] If backup script not configured, error will show
- [ ] **Test:** Press Enter after error
- [ ] **Test:** Repeat and press Esc

### 4.2 Invoke-BackupScript - After Execution
- [ ] Navigate: Main Menu → Backup Dev Environment
- [ ] Execute backup (or view script)
- [ ] **Test:** Press Enter after completion
- [ ] **Test:** Repeat and press Esc

### 4.3 Start-BackupDevEnvironment - After Backup
- [ ] Navigate: Main Menu → Backup Dev Environment
- [ ] Complete backup flow
- [ ] **Test:** Press Enter to return to menu
- [ ] **Test:** Repeat and press Esc

---

## 5. Main Menu Actions (5 tests)

### 5.1 IP Config
- [ ] Navigate: Main Menu → IP Config
- [ ] View network configuration
- [ ] **Test:** Press Enter to return to menu
- [ ] **Test:** Repeat and press Esc

### 5.2 PowerShell Profile Edit
- [ ] Navigate: Main Menu → PowerShell Profile Edit
- [ ] VS Code opens (or error if not installed)
- [ ] Close VS Code
- [ ] **Test:** Press Enter to return to menu
- [ ] **Test:** Repeat and press Esc

### 5.3 Okta YAML Edit
- [ ] Navigate: Main Menu → Okta YAML Edit
- [ ] VS Code opens (or error if file not found)
- [ ] Close VS Code
- [ ] **Test:** Press Enter to return to menu
- [ ] **Test:** Repeat and press Esc

### 5.4 Whitelist Links Folder
- [ ] Navigate: Main Menu → Whitelist Links Folder
- [ ] Command executes
- [ ] **Test:** Press Enter to return to menu
- [ ] **Test:** Repeat and press Esc

### 5.5 Other Main Menu Actions
- [ ] Try any other main menu items with pause behavior
- [ ] **Test:** Press Enter to return
- [ ] **Test:** Press Esc to return

---

## 6. AWS Functions (4 tests)

### 6.1 AWS Authentication Error
- [ ] Navigate: Main Menu → AWS Login
- [ ] Trigger an authentication error (wrong credentials, etc.)
- [ ] **Test:** Press Enter after error
- [ ] **Test:** Repeat and press Esc

### 6.2 Sync AWS Accounts - Success
- [ ] Navigate: AWS menu → Sync AWS Accounts
- [ ] Complete successful sync
- [ ] **Test:** Press Enter to return
- [ ] **Test:** Repeat and press Esc

### 6.3 Sync AWS Accounts - Error
- [ ] Navigate: AWS menu → Sync AWS Accounts
- [ ] Trigger an error (e.g., no network)
- [ ] **Test:** Press Enter after error
- [ ] **Test:** Repeat and press Esc

### 6.4 Sync AWS Accounts - Role Sync
- [ ] Navigate: AWS menu → Sync AWS Accounts
- [ ] Complete role synchronization
- [ ] **Test:** Press Enter to return
- [ ] **Test:** Repeat and press Esc

---

## 7. Alohomora Functions (2 tests)

### 7.1 Successful Remote Access
- [ ] Navigate: AWS menu → Alohomora/Remote Access
- [ ] Complete successful connection
- [ ] **Test:** Press Enter to return
- [ ] **Test:** Repeat and press Esc

### 7.2 Connection Error
- [ ] Navigate: AWS menu → Alohomora/Remote Access
- [ ] Trigger connection error
- [ ] **Test:** Press Enter after error
- [ ] **Test:** Repeat and press Esc

---

## 8. EC2 Instance Functions (7 tests)

### 8.1 Get Instance Info - Success
- [ ] Navigate: AWS menu → Get EC2 Instance Info
- [ ] View instance information
- [ ] **Test:** Press Enter to return
- [ ] **Test:** Repeat and press Esc

### 8.2 Get Instance Info - Error
- [ ] Navigate: AWS menu → Get EC2 Instance Info (without auth)
- [ ] Trigger error (no authentication, wrong region, etc.)
- [ ] **Test:** Press Enter after error
- [ ] **Test:** Repeat and press Esc

### 8.3 Get Instance Info - Display
- [ ] Navigate: AWS menu → Get EC2 Instance Info
- [ ] View full instance details
- [ ] **Test:** Press Enter to return
- [ ] **Test:** Repeat and press Esc

### 8.4 Select EC2 Instance - Error
- [ ] Navigate: AWS menu → Select EC2 Instance
- [ ] Trigger selection error
- [ ] **Test:** Press Enter after error
- [ ] **Test:** Repeat and press Esc

### 8.5 Set Default Instance ID - Success
- [ ] Navigate: AWS menu → Set Default Instance ID
- [ ] Complete setting default instance
- [ ] **Test:** Press Enter to return
- [ ] **Test:** Repeat and press Esc

### 8.6 Set Default Instance ID - Error
- [ ] Navigate: AWS menu → Set Default Instance ID
- [ ] Trigger error
- [ ] **Test:** Press Enter after error
- [ ] **Test:** Repeat and press Esc

### 8.7 Set Default Instance ID - Saved
- [ ] Navigate: AWS menu → Set Default Instance ID
- [ ] Successfully save default instance
- [ ] **Test:** Press Enter to return
- [ ] **Test:** Repeat and press Esc

---

## 9. Remote Host Functions (5 tests)

### 9.1 Set Remote Host Info - Success
- [ ] Navigate: AWS menu → Set Default Remote Host Info
- [ ] Complete setting remote host
- [ ] **Test:** Press Enter to return
- [ ] **Test:** Repeat and press Esc

### 9.2 Set Remote Host - Update Success
- [ ] Navigate: AWS menu → Set Default Remote Host Info
- [ ] Update existing remote host info
- [ ] **Test:** Press Enter after success
- [ ] **Test:** Repeat and press Esc

### 9.3 Set Remote Host - Config Error
- [ ] Navigate: AWS menu → Set Default Remote Host Info
- [ ] Trigger configuration error
- [ ] **Test:** Press Enter after error
- [ ] **Test:** Repeat and press Esc

### 9.4 Set Remote Host - Save Error
- [ ] Navigate: AWS menu → Set Default Remote Host Info
- [ ] Trigger save error
- [ ] **Test:** Press Enter after error
- [ ] **Test:** Repeat and press Esc

### 9.5 Set Remote Host - Settings Saved
- [ ] Navigate: AWS menu → Set Default Remote Host Info
- [ ] Successfully save settings
- [ ] **Test:** Press Enter to return
- [ ] **Test:** Repeat and press Esc

---

## 10. Display Functions (4 tests)

### 10.1 Show Current Instance Settings
- [ ] Navigate: AWS menu → Show Current Instance Settings
- [ ] View current settings
- [ ] **Test:** Press Enter to return
- [ ] **Test:** Repeat and press Esc

### 10.2 Get VPN Connections - List Display
- [ ] Navigate: AWS menu → Get VPN Connections
- [ ] View VPN connections list
- [ ] **Test:** Press Enter to return
- [ ] **Test:** Repeat and press Esc

### 10.3 Get VPN Connections - Error
- [ ] Navigate: AWS menu → Get VPN Connections
- [ ] Trigger error (no auth, wrong region, etc.)
- [ ] **Test:** Press Enter after error
- [ ] **Test:** Repeat and press Esc

### 10.4 Get VPN Connections - Shown
- [ ] Navigate: AWS menu → Get VPN Connections
- [ ] View VPN connections details
- [ ] **Test:** Press Enter to return
- [ ] **Test:** Repeat and press Esc

---

## Summary

**Total Tests:** 45 replacements = 90 test cases (Enter + Esc for each)

**Quick Test Priority:**
1. **High Priority** (most commonly used):
   - Package Manager actions (3 tests)
   - Code Count (6 tests)
   - IP Config (1 test)

2. **Medium Priority** (frequently used):
   - Main Menu actions (5 tests)
   - AWS functions (4 tests)

3. **Lower Priority** (less frequently used):
   - Meraki Backup (3 tests)
   - Backup functions (3 tests)
   - Alohomora (2 tests)
   - EC2 functions (7 tests)
   - Remote Host (5 tests)
   - Display functions (4 tests)

**Special Tests:**
- [ ] Code Count pagination with Q key (should quit viewing)
- [ ] Code Count pagination with Esc key (should also quit)
- [ ] All other pauses with Esc key (should continue, not quit)

---

## Regression Testing

After completing above tests, verify no regressions:

- [ ] Menu navigation still works (arrow keys, Enter, Esc)
- [ ] Checkbox selections still work (Space, A, N, Q)
- [ ] Batch selections still work
- [ ] Timed pauses still work (AWS authentication countdown)
- [ ] Interactive ping still works (Ctrl+C to exit)

---

## Sign-off

**Tester:** _________________
**Date:** _________________
**Result:** ☐ Pass ☐ Fail
**Notes:**

