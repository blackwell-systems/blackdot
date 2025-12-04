# Dotfiles v3.0 - Breaking Changes Proposal

> **Status:** Proposal / Design Document
> **Target Version:** 3.0.0
> **Current Version:** 2.3.0+
> **Breaking Changes:** Yes - Major redesign
> **Migration Tool:** Included

---

## Executive Summary

**Objective:** Eliminate fundamental UX confusion by restructuring command names, simplifying workflows, and making safety features mandatory.

**Impact:**
- ✅ Solves 4 remaining critical pain points
- ✅ Makes commands intuitive (git-inspired)
- ✅ Mandatory safety (auto-backup, validation)
- ❌ Breaks existing scripts/workflows
- ❌ Requires user migration

**Timeline:**
- Phase 1: Implement new commands (alongside old) - 1 week
- Phase 2: Add deprecation warnings - 1 week
- Phase 3: Remove old commands - 1 week
- Phase 4: Documentation - 3 days
- **Total:** 3-4 weeks

---

## Breaking Changes

### 1. Command Namespace Restructure

#### Current (v2.3.0)
```bash
dotfiles vault init             # Configure vault
dotfiles vault discover         # Auto-discover secrets
dotfiles vault restore          # Pull from vault
dotfiles vault sync             # Push to vault
```

**Problems:**
- "init" vs "discover" confusion persists
- "restore" sounds like recovery, not sync
- "sync" implies bidirectional (it's not)

#### Proposed (v3.0)
```bash
# Setup & Configuration
dotfiles vault setup            # First-time: backend + discover + push (replaces init)
dotfiles vault scan             # Re-scan for new secrets (replaces discover)

# Sync Operations (git-inspired)
dotfiles vault pull             # Pull secrets FROM vault (replaces restore)
dotfiles vault push [item]      # Push secrets TO vault (replaces sync)
dotfiles vault status           # Show sync status (NEW)

# Safety
dotfiles vault backup           # Create manual backup (already exists)
dotfiles rollback               # Rollback to last backup (NEW - not vault subcommand)
```

**Benefits:**
- `setup` clearly indicates first-time wizard
- `pull/push` matches git (familiar to developers)
- `scan` is obviously different from `setup`
- `rollback` is top-level emergency command

**Migration:**
```bash
# v2.3.0 → v3.0 mapping
vault init     → vault setup
vault discover → vault scan
vault restore  → vault pull
vault sync     → vault push
(new)          → vault status
(new)          → rollback (top-level)
```

---

### 2. Backup System - Make It Core

#### Current (v2.3.0)
```bash
# Backup is hidden
bin/dotfiles-backup create      # Not advertised
dotfiles vault backup           # Added in v2.3, but vault namespace is confusing
```

**Problems:**
- Backup feels like vault feature (it's not)
- No easy rollback command
- Not obvious how to use

#### Proposed (v3.0)
```bash
# Backup as first-class citizen
dotfiles backup                 # Alias for 'backup create'
dotfiles backup create          # Create snapshot
dotfiles backup list            # List all snapshots
dotfiles backup restore <name>  # Restore specific snapshot
dotfiles backup clean           # Remove old snapshots

# Quick rollback
dotfiles rollback               # Instant rollback to last snapshot
dotfiles rollback --to <name>   # Rollback to specific snapshot
```

**Mandatory Auto-Backup:**
```bash
# These commands ALWAYS create backup first (no opt-out)
dotfiles vault pull             # Auto-backup before pulling
dotfiles vault push --all       # Auto-backup before mass push
dotfiles setup                  # Auto-backup before setup wizard

# Only way to skip (dangerous!)
dotfiles vault pull --no-backup --i-know-what-im-doing
```

**Configuration:**
```json
{
  "backup": {
    "enabled": true,
    "auto_backup": true,
    "retention_days": 30,
    "max_snapshots": 10,
    "compress": true,
    "location": "~/.local/share/dotfiles/backups"
  }
}
```

**Benefits:**
- Clear separation: `backup` = safety, `vault` = sync
- `rollback` is obvious emergency command
- Mandatory safety by default
- Users trust the system more

---

### 3. Config File Format - INI → JSON

#### Current (v2.3.0)
```ini
# ~/.config/dotfiles/config.ini
[vault]
backend=bitwarden

[state]
packages=completed
```

**Problems:**
- INI is old/limited
- No nested structures
- No arrays
- No comments in values

#### Proposed (v3.0)
```json
{
  "version": 3,
  "vault": {
    "backend": "bitwarden",
    "auto_sync": false,
    "auto_backup": true
  },
  "backup": {
    "enabled": true,
    "retention_days": 30,
    "max_snapshots": 10,
    "compress": true
  },
  "setup": {
    "completed": ["symlinks", "packages", "vault", "secrets"],
    "current_tier": "enhanced"
  },
  "packages": {
    "tier": "enhanced",
    "auto_update": false,
    "parallel_install": false
  },
  "paths": {
    "dotfiles_dir": "~/workspace/dotfiles",
    "config_dir": "~/.config/dotfiles",
    "backup_dir": "~/.local/share/dotfiles/backups"
  }
}
```

**Migration:**
```bash
# Auto-migrate on first v3.0 run
dotfiles migrate-config
# Reads config.ini, writes config.json, backs up old
```

**Benefits:**
- Nested structures
- Arrays support
- Native support via jq (already used throughout codebase)
- Consistent with vault-items.json format
- Allows per-install paths (fixes hardcoded path issue)
- Zero new dependencies (jq already required)

---

### 4. Vault Items Schema - Simplify

#### Current (v2.3.0)
```json
{
  "$schema": "...",
  "ssh_keys": {
    "GitHub": "~/.ssh/id_ed25519"
  },
  "vault_items": {
    "SSH-GitHub": {
      "path": "~/.ssh/id_ed25519",
      "required": true,
      "type": "sshkey"
    }
  },
  "syncable_items": {
    "Git-Config": "~/.gitconfig"
  },
  "aws_expected_profiles": ["default", "work"]
}
```

**Problems:**
- Data duplication (ssh_keys vs vault_items)
- Three different formats for items
- Confusing distinction between vault_items and syncable_items

#### Proposed (v3.0)
```json
{
  "version": 3,
  "secrets": [
    {
      "name": "SSH-GitHub",
      "path": "~/.ssh/id_ed25519",
      "type": "ssh-key",
      "required": true,
      "sync": "always",
      "backup": true
    },
    {
      "name": "Git-Config",
      "path": "~/.gitconfig",
      "type": "file",
      "required": true,
      "sync": "manual",
      "backup": true
    },
    {
      "name": "AWS-Credentials",
      "path": "~/.aws/credentials",
      "type": "file",
      "required": false,
      "sync": "always",
      "backup": true,
      "profiles": ["default", "work"]
    }
  ]
}
```

**Benefits:**
- Single flat array (no duplication)
- Per-item sync control
- Version field enables auto-migration
- Clearer schema
- Per-item backup control

**Migration:**
```bash
# Auto-migrate on first v3.0 run
dotfiles vault migrate-schema
# Reads old vault-items.json, writes new format, backs up old
```

---

### 5. Setup Wizard - Show Tier Options

#### Current (v2.3.0)
```bash
dotfiles setup
> Install packages? [Y/n]:
# Just runs brew bundle, no choice of tier
```

**Problems:**
- User doesn't know about BREWFILE_TIER
- Can't see package differences
- No control over what's installed

#### Proposed (v3.0)
```bash
dotfiles setup

STEP 2 of 6: Packages
─────────────────────────────

Which package tier would you like?

  1) minimal    20 packages (~2 min)
     Core tools: zsh, git, jq, curl, wget

  2) enhanced   80 packages (~8 min)  ← RECOMMENDED
     Core + dev tools: fzf, ripgrep, bat, eza, zoxide, etc.

  3) full       120 packages (~15 min)
     Enhanced + language tools: node, python, rust, go, etc.

  4) custom     Choose packages interactively

Your choice [2]: 2

Installing 80 packages (enhanced tier)...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 15/80 (18%)

Currently: ripgrep (downloading...)
  ✓ bat
  ✓ fzf
  ✓ eza
  ⧗ ripgrep
  ○ zoxide (queued)

Estimated time: 6 minutes remaining
```

**Implementation:**
```bash
# Tier detection
TIER_MINIMAL=(zsh git jq curl wget ...)    # ~20 packages
TIER_ENHANCED=(${TIER_MINIMAL[@]} fzf bat eza ...) # ~80
TIER_FULL=(${TIER_ENHANCED[@]} node python rust ...) # ~120

# Brewfile becomes generated
brew install ${TIER_PACKAGES[@]}
```

**Benefits:**
- Users see options upfront
- No mysterious environment variables
- Clear time estimates
- Visual progress bar

---

### 6. Error Messages - Add Fix Commands

#### Current (v2.3.0)
```bash
❌ Vault is locked
```

**Problem:** User doesn't know what to do next

#### Proposed (v3.0)
```bash
❌ Vault is locked

   Why: Bitwarden session expired
   Impact: Cannot pull secrets from vault

   Fix: Unlock your vault
   → bw unlock
   → export BW_SESSION="$(bw unlock --raw)"

   Or: Use different backend
   → dotfiles vault setup

   Help: https://docs.dotfiles.io/vault/locked
```

**Implementation:**
```bash
# lib/_errors.sh
error_with_fix() {
    local error_code="$1"
    local context="$2"

    case "$error_code" in
        VAULT_LOCKED)
            fail "Vault is locked"
            echo ""
            echo "   Why: Bitwarden session expired"
            echo "   Impact: Cannot pull secrets from vault"
            echo ""
            echo "   Fix: Unlock your vault"
            echo "   → ${CYAN}bw unlock${NC}"
            echo "   → ${CYAN}export BW_SESSION=\"\$(bw unlock --raw)\"${NC}"
            echo ""
            echo "   Or: Use different backend"
            echo "   → ${CYAN}dotfiles vault setup${NC}"
            echo ""
            echo "   Help: ${DIM}https://docs.dotfiles.io/vault/locked${NC}"
            ;;
    esac
}
```

**Benefits:**
- Every error is actionable
- Users know exactly what to do
- Reduces support burden
- Links to documentation

---

### 7. Doctor Health Score - Add Interpretation

#### Current (v2.3.0)
```bash
Health Score: 30/100
```

**Problem:** User doesn't know if 30 is good or bad

#### Proposed (v3.0)
```bash
═══════════════════════════════════════════════════════════
  ⚠️  Health Score: 30/100 - Needs Attention
═══════════════════════════════════════════════════════════

Score Interpretation:
  🟢 80-100  Healthy      - All checks passed
  🟡 60-79   Minor Issues - Some warnings, safe to use
  🟠 40-59   Needs Work   - Several issues, fix recommended
  🔴 0-39    Critical     - Major problems, fix immediately

Your Issues:
  3 failed checks   (-30 points)
  8 warnings        (-40 points)

Quick Fixes (would improve to 85/100):
  ✓ Fix ~/.ssh permissions      → +10 points
  ✓ Install missing packages    → +15 points
  ✓ Configure vault backend     → +10 points

Run 'dotfiles doctor --fix' to auto-repair common issues
```

**Benefits:**
- Clear interpretation
- Actionable suggestions
- Shows impact of fixes
- Auto-fix option

---

## Migration Strategy

### Phase 1: Dual Command Support (Week 1)

**Add new commands alongside old:**
```bash
# Both work, old commands show deprecation warning
dotfiles vault init      # Shows: "⚠️  'vault init' is deprecated, use 'vault setup'"
dotfiles vault setup     # New command

dotfiles vault restore   # Shows: "⚠️  'vault restore' is deprecated, use 'vault pull'"
dotfiles vault pull      # New command
```

**Implementation:**
```bash
# zsh/zsh.d/40-aliases.zsh
vault)
    case "$subcmd" in
        init)
            warn "⚠️  'vault init' is deprecated and will be removed in v3.1"
            info "Use 'dotfiles vault setup' instead"
            echo ""
            "$VAULT_DIR/init-vault.sh" "$@"  # Still works
            ;;
        setup)
            "$VAULT_DIR/init-vault.sh" "$@"  # New name, same script
            ;;
        restore)
            warn "⚠️  'vault restore' is deprecated, use 'vault pull'"
            "$VAULT_DIR/restore.sh" "$@"
            ;;
        pull)
            "$VAULT_DIR/restore.sh" "$@"  # New name, same script
            ;;
    esac
    ;;
```

### Phase 2: Auto-Migration (Week 2)

**On first v3.0 run:**
```bash
╔════════════════════════════════════════════════════════════╗
║  Dotfiles v3.0 - Migration Required                       ║
╚════════════════════════════════════════════════════════════╝

This is a major version upgrade with breaking changes.

Changes:
  • Config format: config.ini → config.json
  • Vault schema: v2 → v3 (simplified format)
  • Commands renamed (see: dotfiles help)

Migration:
  ✓ Backup current config
  ✓ Migrate config.ini → config.json
  ✓ Migrate vault-items.json → v3 schema
  ✓ Update paths in config

This will take ~30 seconds.

Continue with migration? [Y/n]: y

Migrating...
  ✓ Backed up config to: ~/.config/dotfiles/backups/pre-v3-migration/
  ✓ Converted config.ini → config.json
  ✓ Migrated vault-items.json (v2 → v3)
  ✓ Updated 6 file paths

Migration complete! 🎉

What's new in v3.0:
  • New commands: vault setup, vault pull/push, rollback
  • Mandatory auto-backup before destructive operations
  • Improved error messages with fix suggestions
  • Package tier selection in setup wizard

Run 'dotfiles doctor' to verify everything works.
```

**Implementation:**
```bash
# bin/dotfiles-migrate-v3
#!/usr/bin/env zsh
set -euo pipefail

BACKUP_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/backups/pre-v3-migration-$(date +%Y%m%d_%H%M%S)"

# 1. Backup
mkdir -p "$BACKUP_DIR"
cp ~/.config/dotfiles/config.ini "$BACKUP_DIR/" 2>/dev/null || true
cp ~/.config/dotfiles/vault-items.json "$BACKUP_DIR/" 2>/dev/null || true

# 2. Migrate config.ini → config.json
# (convert INI format to JSON with jq)

# 3. Migrate vault-items.json
# (convert old schema to new schema)

# 4. Create migration marker
echo "3.0" > ~/.config/dotfiles/.migrated
```

### Phase 3: Remove Old Commands (Week 3)

**Remove deprecated commands:**
```bash
# Old commands removed, show helpful error
dotfiles vault init
# Error: 'vault init' was removed in v3.0
#        Use 'dotfiles vault setup' instead
#        See: https://docs.dotfiles.io/migration/v3
```

### Phase 4: Documentation (Week 3-4)

**Update all docs:**
- README.md - New command examples
- CHANGELOG.md - Breaking changes documented
- docs/migration-v3.md - Migration guide
- docs/vault-README.md - New command names
- Update all examples in code comments

---

## Testing Strategy

### Unit Tests
```bash
# test/v3-commands.bats
@test "vault setup works" {
    run dotfiles vault setup --dry-run
    [ "$status" -eq 0 ]
}

@test "vault pull creates backup" {
    run dotfiles vault pull --dry-run
    [[ "$output" =~ "Creating backup" ]]
}

@test "rollback command exists" {
    run dotfiles rollback --help
    [ "$status" -eq 0 ]
}
```

### Integration Tests
```bash
# test/migration.bats
@test "migration from v2 to v3" {
    # Setup v2 config
    # Run migration
    # Verify v3 config created
    # Verify backup created
    # Verify old config still readable
}
```

### Manual Testing Checklist
```markdown
- [ ] Fresh install on macOS
- [ ] Fresh install on Linux
- [ ] Migration from v2.3.0 → v3.0
- [ ] All new commands work
- [ ] Old commands show deprecation warnings
- [ ] Auto-backup works before destructive operations
- [ ] Rollback works
- [ ] Package tier selection in setup
- [ ] Error messages show fix commands
- [ ] Health score shows interpretation
- [ ] Doctor --fix works
```

---

## Implementation Plan

### Week 1: Core Changes
- [x] Rename command handlers (clean break, no warnings) - `zsh/zsh.d/40-aliases.zsh`
- [x] Add `dotfiles rollback` command - Top-level command
- [x] Add `dotfiles vault status` command - Shows vault sync status
- [x] Update help text for all commands - Clean v3.0 help
- [x] Migration tools created - `bin/dotfiles-migrate*`

### Week 2: Config & Schema
- [x] Implement JSON config support (using jq) - `lib/_config.sh`
- [x] Create config migration (INI → JSON) - `bin/dotfiles-migrate-config`
- [x] Implement v3 vault-items schema - Single secrets[] array
- [x] Create schema migration (v2 → v3) - `bin/dotfiles-migrate-vault-schema`
- [x] Add migration orchestrator - `bin/dotfiles-migrate`, `dotfiles migrate` command

### Week 3: UX Improvements
- [ ] Add package tier selection to setup
- [ ] Add progress bar to package install
- [ ] Implement error messages with fixes
- [ ] Add health score interpretation
- [ ] Add `doctor --fix` auto-repair

### Week 4: Documentation & Testing
- [ ] Update all documentation
- [ ] Write migration guide
- [ ] Add unit tests
- [ ] Add integration tests
- [ ] Manual testing across platforms

---

## Rollback Plan

**If v3.0 has critical bugs:**

1. **Immediate:**
   ```bash
   git checkout v2.3.0
   ./install.sh
   ```

2. **Restore Config:**
   ```bash
   cp ~/.config/dotfiles/backups/pre-v3-migration/config.ini ~/.config/dotfiles/
   cp ~/.config/dotfiles/backups/pre-v3-migration/vault-items.json ~/.config/dotfiles/
   ```

3. **Communicate:**
   - GitHub issue with bug details
   - Revert to v2.3.x in README
   - Fix bugs, re-release v3.0.1

---

## Breaking Changes Summary

| Change | Impact | Migration |
|--------|--------|-----------|
| `vault init` → `vault setup` | High | Alias + deprecation warning |
| `vault restore` → `vault pull` | High | Alias + deprecation warning |
| `vault sync` → `vault push` | High | Alias + deprecation warning |
| `vault discover` → `vault scan` | Medium | Alias + deprecation warning |
| config.ini → config.json | Medium | Auto-migration script |
| vault-items v2 → v3 | Low | Auto-migration script |
| Mandatory auto-backup | Low | Config option to disable |
| New error format | None | Backwards compatible |
| Package tier selection | None | Defaults to current behavior |
| Health score interpretation | None | Backwards compatible |

---

## Success Criteria

**v3.0 is successful if:**
- ✅ 95%+ of users migrate successfully without issues
- ✅ Support requests decrease by 30% (better UX)
- ✅ Setup time decreases by 20% (clearer workflow)
- ✅ User confidence increases (mandatory backups)
- ✅ All automated tests pass
- ✅ No critical bugs in first 2 weeks

---

## Appendix: Command Reference

### Complete v2 → v3 Mapping

```bash
# Setup & Configuration
v2: dotfiles vault init             → v3: dotfiles vault setup
v2: dotfiles vault discover         → v3: dotfiles vault scan
v2: (none)                          → v3: dotfiles vault status

# Sync
v2: dotfiles vault restore          → v3: dotfiles vault pull
v2: dotfiles vault restore --force  → v3: dotfiles vault pull --force
v2: dotfiles vault sync             → v3: dotfiles vault push
v2: dotfiles vault sync --all       → v3: dotfiles vault push --all

# Backup & Safety
v2: bin/dotfiles-backup create      → v3: dotfiles backup
v2: dotfiles vault backup           → v3: dotfiles backup (moved out of vault)
v2: (none)                          → v3: dotfiles rollback
v2: (none)                          → v3: dotfiles backup list
v2: (none)                          → v3: dotfiles backup restore <name>

# Management (unchanged)
v2: dotfiles vault list             → v3: dotfiles vault list
v2: dotfiles vault check            → v3: dotfiles vault check
v2: dotfiles vault create           → v3: dotfiles vault create
v2: dotfiles vault delete           → v3: dotfiles vault delete

# Doctor (enhanced)
v2: dotfiles doctor                 → v3: dotfiles doctor (with score interpretation)
v2: (none)                          → v3: dotfiles doctor --fix (auto-repair)

# Setup (enhanced)
v2: dotfiles setup                  → v3: dotfiles setup (with tier selection)
```

---

## Approval Required

**Before implementing, confirm:**
- [ ] Command names approved (setup, scan, pull, push, rollback)
- [ ] Config format change approved (JSON)
- [ ] Schema change approved (v3 format)
- [ ] Migration strategy approved (auto-migrate)
- [ ] Timeline approved (4 weeks)
- [ ] Breaking changes acceptable (no customers yet)

**Sign-off:**
- [ ] Product Owner: _______________
- [ ] Lead Developer: _______________
- [ ] Date: _______________

---

**Next Steps:** If approved, create implementation tasks and begin Phase 1.
