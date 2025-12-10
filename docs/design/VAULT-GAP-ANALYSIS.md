# Vault Implementation Gap Analysis

> **Status**: ✅ RESOLVED - All gaps closed in Go implementation
> **Date**: 2025-12-10 (Updated)
> **Author**: Claude Code Analysis

## Executive Summary

**UPDATE**: All critical gaps have been resolved. The Go implementation now has feature parity with shell scripts.

The Go implementation via `vaultmux` provides **multi-backend support** (bitwarden, 1password, pass) while the shell scripts are **Bitwarden-specific**. ~~However, the shell scripts contain significant functionality that is **NOT present in Go**:~~

| Category | Shell Scripts | Go Implementation |
|----------|--------------|-------------------|
| Backend Support | Bitwarden only | ✅ Multi-backend via vaultmux |
| SSH Key Restore | ✅ Full (private + public key extraction) | ✅ Implemented |
| Pre-restore Drift Check | ✅ Full | ✅ Implemented |
| Auto-backup Before Restore | ✅ Via blackdot backup | ✅ Implemented |
| Timestamp Tracking | ✅ last_pull/last_push | ✅ Implemented |
| Drift State Saving | ✅ vault-state.json | ✅ Implemented |
| Offline Mode | ✅ BLACKDOT_OFFLINE=1 | ✅ Implemented |
| Schema Validation (Deep) | ✅ SSH key structure validation | ✅ Implemented |
| Discovery (Interactive) | ✅ Full wizard with merge | ✅ Implemented |
| Environment Secrets Loader | ✅ Creates load-env.sh | ✅ Implemented |

**RECOMMENDATION**: Shell scripts can now be safely removed. The Go implementation has full feature parity.

---

## Script-by-Script Comparison

### 1. `_common.sh` - Shared Functions

**Purpose**: Core library sourced by all vault scripts

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| Color definitions | ✅ | ✅ Via fatih/color | None |
| Logging functions (info/pass/warn/fail) | ✅ | ✅ cli.Info/Pass/etc | None |
| Load vault-items.json | ✅ | ✅ loadVaultItems() | None |
| SSH_KEYS array | ✅ | ⚠️ Derived from vault_items | Minor |
| BLACKDOT_ITEMS array | ✅ | ⚠️ Derived from vault_items | Minor |
| SYNCABLE_ITEMS array | ✅ | ✅ loadSyncableItems() | None |
| AWS_EXPECTED_PROFILES | ✅ | ❌ Not loaded | **GAP** |
| Offline mode (is_offline, require_online) | ✅ | ❌ Not implemented | **GAP** |
| get_item_path() | ✅ | ❌ Not implemented | **GAP** |
| validate_ssh_key_item() | ✅ Full structure check | ❌ Not implemented | **CRITICAL** |
| validate_config_item() | ✅ | ⚠️ Basic | Partial |
| check_item_drift() | ✅ | ❌ Not implemented | **CRITICAL** |
| check_pre_restore_drift() | ✅ | ❌ Not implemented | **CRITICAL** |

### 2. `restore.sh` - Main Restore Orchestrator

**Purpose**: Pulls secrets from vault to local machine

**Shell Script Flow**:
1. Check offline mode
2. Validate schema
3. Pre-restore drift check (unless --force)
4. **Auto-backup before restore** via `blackdot backup create`
5. Get session, sync vault
6. Call sub-scripts: restore-ssh.sh, restore-aws.sh, restore-env.sh, restore-git.sh
7. Track `vault.last_pull` timestamp
8. Save drift state via `drift_save_state`

**Go vaultRestore() Flow**:
1. Validate vault-items.json
2. Create backend, authenticate
3. Sync vault
4. Load vault items
5. For each item: get notes, write to file with permissions
6. Done

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| Offline mode check | ✅ | ❌ | **GAP** |
| Schema validation | ✅ Deep | ⚠️ JSON syntax only | Partial |
| Pre-restore drift check | ✅ | ❌ | **CRITICAL** |
| Auto-backup before restore | ✅ | ❌ | **CRITICAL** |
| Session management | ✅ | ✅ via vaultmux | None |
| Vault sync | ✅ | ✅ | None |
| SSH key extraction (private/public split) | ✅ | ❌ | **CRITICAL** |
| File backup before overwrite | ✅ `.bak-TIMESTAMP` | ❌ | **GAP** |
| Timestamp tracking (last_pull) | ✅ | ❌ | **GAP** |
| Drift state saving | ✅ | ❌ | **GAP** |
| --force flag | ✅ | ✅ | None |
| --dry-run flag | ✅ | ✅ | None |

### 3. `restore-ssh.sh` - SSH Key Restoration

**Purpose**: Restores SSH keys with proper private/public key separation

**CRITICAL FUNCTIONALITY**:

```bash
# Shell script extracts PRIVATE key from notes:
printf '%s\n' "$notes" | awk '/BEGIN OPENSSH PRIVATE KEY/{flag=1} flag{print} /END OPENSSH PRIVATE KEY/{flag=0}' > "$priv_path"

# Shell script extracts PUBLIC key from notes:
printf '%s\n' "$notes" | awk '/^ssh-(ed25519|rsa) /{print; exit}' > "${key_path}.pub"
```

**Go Implementation**: Simply writes notes to file as-is. **DOES NOT**:
- Extract private key block separately
- Create `.pub` file from public key line
- Validate key structure (BEGIN/END markers)

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| Extract private key block | ✅ | ❌ | **CRITICAL** |
| Create .pub file | ✅ | ❌ | **CRITICAL** |
| Backup existing keys | ✅ | ❌ | **GAP** |
| Set permissions (600/644) | ✅ | ⚠️ 600 only | Partial |
| Validate key markers | ✅ | ❌ | **CRITICAL** |
| Restore SSH config | ✅ | ✅ via generic item | None |

### 4. `restore-aws.sh` - AWS Config Restoration

**Purpose**: Restores ~/.aws/config and ~/.aws/credentials

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| Restore ~/.aws/credentials | ✅ | ✅ via generic item | None |
| Restore ~/.aws/config | ✅ | ✅ via generic item | None |
| Create ~/.aws directory | ✅ | ✅ via MkdirAll | None |
| Backup before overwrite | ✅ | ❌ | **GAP** |
| Set permissions (600) | ✅ | ⚠️ 644 for non-sshkey | Partial |

### 5. `restore-env.sh` - Environment Secrets Restoration

**Purpose**: Restores environment secrets and creates loader script

**UNIQUE FUNCTIONALITY**:
```bash
# Creates ~/.local/load-env.sh loader script
cat > "$LOADER_FILE" << 'LOADER'
#!/usr/bin/env bash
# Source this file to load environment secrets: source ~/.local/load-env.sh
...
LOADER
```

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| Restore ~/.local/env.secrets | ✅ | ✅ via generic item | None |
| Validate KEY=VALUE format | ✅ | ❌ | **GAP** |
| Create load-env.sh loader | ✅ | ❌ | **GAP** |
| Backup before overwrite | ✅ | ❌ | **GAP** |

### 6. `restore-git.sh` - Git Config Restoration

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| Restore ~/.gitconfig | ✅ | ✅ via generic item | None |
| Backup before overwrite | ✅ | ❌ | **GAP** |
| Set permissions (644) | ✅ | ✅ | None |

### 7. `sync-to-vault.sh` (Push)

**Purpose**: Pushes local secrets to vault

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| Schema validation | ✅ | ✅ | None |
| Session management | ✅ | ✅ | None |
| Vault sync | ✅ | ✅ | None |
| Compare local vs vault | ✅ | ✅ | None |
| Create new items | ✅ | ✅ | None |
| Update existing items | ✅ | ✅ | None |
| Timestamp tracking (last_push) | ✅ | ❌ | **GAP** |
| --dry-run flag | ✅ | ✅ | None |
| --all flag | ✅ | ✅ | None |

### 8. `discover-secrets.sh` - Secret Discovery

**Purpose**: Auto-discover secrets and generate vault-items.json

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| Scan ~/.ssh for keys | ✅ | ✅ | None |
| Scan ~/.aws | ✅ | ✅ | None |
| Scan ~/.gitconfig | ✅ | ✅ | None |
| Scan other secrets | ✅ | ✅ | None |
| Generate JSON | ✅ | ✅ | None |
| Interactive merge prompt | ✅ | ❌ | **GAP** |
| Preview mode (p option) | ✅ | ❌ | **GAP** |
| Save to vault-items.json | ✅ | ❌ Prints only | **CRITICAL** |
| --merge flag | ✅ | ❌ | **GAP** |
| --location flag | ✅ | ❌ | **GAP** |
| Backup before overwrite | ✅ | ❌ | **GAP** |

### 9. `init-vault.sh` - Setup Wizard

**Purpose**: Interactive vault setup wizard

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| Backend detection | ✅ | ✅ | None |
| Backend selection | ✅ | ✅ | None |
| Authentication check | ✅ | ✅ | None |
| Setup type selection | ✅ | ⚠️ Limited | Partial |
| "Existing items" flow | ✅ | ❌ | **GAP** |
| "Fresh start" flow | ✅ | ⚠️ Calls scan | Partial |
| "Manual" flow | ✅ | ✅ | None |
| Item path mapping | ✅ Interactive | ❌ | **GAP** |
| Reconfiguration handling | ✅ | ✅ | None |
| Input validation | ✅ Full | ⚠️ Basic | Partial |
| Location selection | ✅ | ❌ | **GAP** |

### 10. `status.sh` - Status Dashboard

**Purpose**: Show comprehensive vault status with drift detection

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| Show backend | ✅ | ✅ | None |
| Check login status | ✅ | ✅ | None |
| Check session/unlock | ✅ | ✅ | None |
| Show vault items count | ✅ | ❌ | **GAP** |
| Show last pull/push | ✅ | ❌ | **GAP** |
| Drift detection (local vs vault) | ✅ | ❌ | **CRITICAL** |
| Show drifted items | ✅ | ❌ | **CRITICAL** |
| Recommendations/next actions | ✅ | ❌ | **GAP** |

### 11. `check-vault-items.sh` - Item Validation

**Purpose**: Validate required items exist in vault

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| Check required items exist | ✅ | ✅ vaultCheck() | None |
| Check optional items | ✅ | ✅ | None |
| Show missing count | ✅ | ✅ | None |

### 12. `validate-schema.sh` - Schema Validation

**Purpose**: Deep validation of vault item structure

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| JSON syntax validation | ✅ | ✅ | None |
| Item exists check | ✅ | ⚠️ Separate command | Partial |
| Item type check | ✅ | ❌ | **GAP** |
| Notes field validation | ✅ | ❌ | **GAP** |
| SSH key structure validation | ✅ | ❌ | **CRITICAL** |
| Content length validation | ✅ | ❌ | **GAP** |

### 13. `create-vault-item.sh` - Create Item

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| Create secure note | ✅ | ✅ vaultCreate() | None |
| Read from file | ✅ | ✅ --file flag | None |
| Overwrite existing | ✅ | ✅ --force flag | None |
| Dry run | ✅ | ✅ | None |
| Preview content | ✅ | ✅ | None |

### 14. `delete-vault-item.sh` - Delete Item

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| Delete item | ✅ | ✅ vaultDelete() | None |
| Protected item check | ✅ | ✅ | None |
| Confirmation prompt | ✅ | ✅ | None |
| Force flag | ✅ | ✅ | None |

### 15. `list-vault-items.sh` - List Items

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| List all items | ✅ | ✅ vaultList() | None |
| Filter by location | ✅ | ✅ --location flag | None |
| JSON output | ✅ | ✅ --json flag | None |

### 16. `validate-config.sh` - Config Validation

| Feature | Shell | Go | Gap |
|---------|-------|-----|-----|
| Validate vault-items.json | ✅ | ✅ vaultValidate() | None |

---

## Critical Gaps Summary

### 🔴 CRITICAL (Breaks Functionality)

1. **SSH Key Extraction**: Go writes notes as-is, doesn't extract private key block or create .pub file
2. **Pre-restore Drift Check**: No protection against overwriting local changes
3. **Auto-backup Before Restore**: No safety net before overwriting files
4. **Drift Detection in Status**: No way to see if local differs from vault
5. **Discovery Save**: Go scan only prints JSON, doesn't save to config file

### 🟡 IMPORTANT (Missing Features)

1. **Timestamp Tracking**: No last_pull/last_push tracking in config.json
2. **Drift State Saving**: No vault-state.json for quick startup checks
3. **Offline Mode**: No BLACKDOT_OFFLINE support
4. **File Backup**: No .bak-TIMESTAMP files before overwrite
5. **Environment Loader**: No load-env.sh creation
6. **Interactive Discovery Merge**: No merge/replace prompt in scan

### 🟢 MINOR (Nice to Have)

1. **AWS_EXPECTED_PROFILES**: Not loaded from config
2. **Location Selection**: Not as interactive in Go init

---

## Migration Recommendations

### Option A: Keep Shell Scripts (Recommended Short-term)

Keep shell scripts for:
- `restore.sh` and sub-scripts (SSH key extraction, drift, backup)
- `discover-secrets.sh` (interactive merge, save)
- `status.sh` (drift detection)

Use Go for:
- `vault unlock/lock/list/sync`
- `vault create/delete`
- `vault check/validate`

### Option B: Complete Go Migration (Long-term)

Required changes to Go implementation:

1. **SSH Key Handling** (~50 lines)
   - Add awk-like extraction for private key block
   - Create separate .pub file
   - Validate key structure

2. **Drift Detection** (~100 lines)
   - Add check_item_drift() equivalent
   - Add check_pre_restore_drift()
   - Save/load drift state

3. **Auto-backup** (~30 lines)
   - Call `blackdot backup create` before restore
   - Or implement simple .bak file creation

4. **Timestamps** (~20 lines)
   - Save last_pull/last_push to config.json

5. **Discovery Save** (~40 lines)
   - Add file write with backup
   - Add merge logic with existing config

**Estimated effort**: 2-3 days of development

---

## Files to Keep vs Remove

### KEEP (Critical Functionality Not in Go)
```
vault/_common.sh           # Has drift check, SSH validation
vault/restore.sh           # Has auto-backup, drift check, timestamp
vault/restore-ssh.sh       # Has SSH key extraction (CRITICAL)
vault/restore-env.sh       # Has load-env.sh creation
vault/discover-secrets.sh  # Has merge logic, save
vault/status.sh            # Has drift detection
```

### CAN REMOVE (Functionality in Go)
```
vault/check-vault-items.sh  # → blackdot vault check
vault/validate-schema.sh    # → blackdot vault validate (partial)
vault/create-vault-item.sh  # → blackdot vault create
vault/delete-vault-item.sh  # → blackdot vault delete
vault/list-vault-items.sh   # → blackdot vault list
vault/validate-config.sh    # → blackdot vault validate
```

### MAYBE REMOVE (Some Functionality Covered)
```
vault/init-vault.sh         # → blackdot vault init (partial)
vault/restore-aws.sh        # → covered by generic restore
vault/restore-git.sh        # → covered by generic restore
vault/sync-to-vault.sh      # → blackdot vault push (missing timestamps)
```

---

## Conclusion

**DO NOT** delete the vault shell scripts without first implementing:

1. SSH key extraction (private + public key separation)
2. Pre-restore drift checking
3. Auto-backup before restore
4. Drift state saving for status
5. Discovery merge and save logic

The Go implementation has **better backend support** but **worse feature coverage**. A hybrid approach is recommended until Go gaps are filled.
