# Unified Setup Experience Plan

> **Status:** Proposal
> **Created:** 2025-12-02
> **Goal:** Transform fragmented installation into a cohesive, stateful experience

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Problem Decomposition](#problem-decomposition)
4. [Proposed Architecture](#proposed-architecture)
5. [State Management Design](#state-management-design)
6. [Implementation Plan](#implementation-plan)
7. [Migration Strategy](#migration-strategy)
8. [User Experience Flows](#user-experience-flows)
9. [Risk Analysis](#risk-analysis)
10. [Success Criteria](#success-criteria)

---

## Executive Summary

### The Problem

The current dotfiles setup experience is fragmented across multiple scripts with overlapping responsibilities, no persistent state, and confusing terminology. Users encounter:

- **Multiple entry points** that do similar things differently
- **Lost configuration** when switching terminals or rebooting
- **Confusing "bootstrap" terminology** used for unrelated operations
- **No resume capability** if setup is interrupted
- **Manual persistence required** for vault backend selection

### The Solution

Create a **unified, stateful setup system** with:

1. **Single configuration command** (`dotfiles setup`) as the primary interface
2. **Persistent state file** tracking what's configured and what isn't
3. **Clear phase separation** (install vs configure vs verify)
4. **Idempotent operations** that can safely resume from any point
5. **Consistent terminology** throughout

### Expected Outcomes

| Metric | Current | Target |
|--------|---------|--------|
| Entry points to understand | 4+ | 2 |
| Commands to complete setup | 3-5 | 1-2 |
| State persistence | Session-only | Permanent |
| Resume capability | None | Full |
| Time to onboard new user | 20-30 min | 10-15 min |

---

## Current State Analysis

### Entry Point Inventory

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CURRENT ENTRY POINTS                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. install.sh                                                          │
│     ├── Clones repo                                                     │
│     ├── Runs OS bootstrap                                               │
│     ├── --interactive → also runs dotfiles-init                         │
│     └── Prints "run dotfiles init"                                      │
│                                                                         │
│  2. bootstrap/bootstrap-mac.sh (or linux)                               │
│     ├── Installs Homebrew                                               │
│     ├── Runs brew bundle                                                │
│     ├── Creates symlinks                                                │
│     └── Creates /workspace symlink                                      │
│                                                                         │
│  3. bin/dotfiles-init                                                   │
│     ├── May re-run bootstrap (!)                                        │
│     ├── Vault backend selection                                         │
│     ├── Vault login/unlock                                              │
│     ├── Calls bootstrap-vault.sh                                        │
│     ├── Claude setup                                                    │
│     └── Health check                                                    │
│                                                                         │
│  4. vault/bootstrap-vault.sh                                            │
│     ├── Drift check                                                     │
│     ├── Calls restore-ssh.sh                                            │
│     ├── Calls restore-aws.sh                                            │
│     ├── Calls restore-env.sh                                            │
│     └── Calls restore-git.sh                                            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### State Tracking Gaps

| What | Where Stored | Persistence | Problem |
|------|--------------|-------------|---------|
| Vault backend | `$DOTFILES_VAULT_BACKEND` env | Session only | Lost on reboot |
| Vault session | `.vault-session` file | Until logout | OK |
| Setup completed | Nowhere | N/A | Can't detect |
| Symlinks done | Filesystem check | Permanent | OK but scattered |
| Packages installed | Brewfile.lock.json | Permanent | Not checked |
| Secrets restored | Filesystem check | Permanent | No metadata |

### Terminology Confusion

| Term | Used In | Actually Means |
|------|---------|----------------|
| "bootstrap" | bootstrap-mac.sh | OS-level setup (brew, symlinks) |
| "bootstrap" | bootstrap-vault.sh | Secret restoration |
| "bootstrap" | bootstrap-dotfiles.sh | Symlink creation only |
| "init" | dotfiles-init | Interactive wizard (everything) |
| "restore" | vault restore | Fetch secrets from vault |
| "sync" | vault sync | Push local to vault |

### Dependency Graph (Current)

```
install.sh ─────────────────────────────────────────┐
     │                                              │
     ▼                                              │
bootstrap-mac.sh ◄──────────────────────────────────┤ (may be called twice!)
     │                                              │
     ├──► _common.sh                                │
     │        │                                     │
     │        └──► bootstrap-dotfiles.sh            │
     │                                              │
     ▼                                              │
[User prompted to run dotfiles init]                │
     │                                              │
     ▼                                              │
dotfiles-init ──────────────────────────────────────┘
     │
     ├──► Step 1: Bootstrap (again?!)
     │
     ├──► Step 2: Vault backend selection
     │        │
     │        └──► export DOTFILES_VAULT_BACKEND (session only!)
     │
     ├──► Step 3: bootstrap-vault.sh
     │        │
     │        ├──► _common.sh ──► lib/_vault.sh
     │        │
     │        ├──► restore-ssh.sh
     │        ├──► restore-aws.sh
     │        ├──► restore-env.sh
     │        └──► restore-git.sh
     │
     ├──► Step 4: Claude setup
     │
     └──► Step 5: dotfiles-doctor
```

---

## Problem Decomposition

### Problem 1: Multiple Entry Points

**Symptom:** User doesn't know which script to run

**Root Cause:** Historical accumulation of scripts without consolidation

**Evidence:**
- `install.sh` line 174-179: calls `dotfiles-init` if `--interactive`
- `dotfiles-init` line 91-107: may re-run the same bootstrap
- Both can be run independently with different results

**Impact:**
- Confusion about "correct" way to set up
- Duplicate work if both paths taken
- Different outcomes depending on entry point

### Problem 2: No Persistent State

**Symptom:** User must re-select vault backend every session

**Root Cause:** Backend stored in environment variable only

**Evidence:**
- `dotfiles-init` line 151: `export DOTFILES_VAULT_BACKEND="$SELECTED_BACKEND"`
- `lib/_vault.sh` line 17: defaults to bitwarden if not set
- No file writes for configuration choices

**Impact:**
- Frustrating repeated configuration
- Defaults to wrong backend after reboot
- No way to know what was previously configured

### Problem 3: Overloaded "Bootstrap" Terminology

**Symptom:** Confusion about what "bootstrap" does

**Root Cause:** Same term used for unrelated operations

**Evidence:**
- `bootstrap-mac.sh`: OS setup
- `bootstrap-vault.sh`: Secret restoration
- `bootstrap-dotfiles.sh`: Symlink creation

**Impact:**
- Documentation is confusing
- Error messages are ambiguous
- Users don't know what failed

### Problem 4: No Resume Capability

**Symptom:** Interrupted setup must restart from beginning

**Root Cause:** No checkpointing or progress tracking

**Evidence:**
- Each script checks prerequisites independently
- No shared state about what's completed
- `dotfiles-init` does basic check but can't resume mid-step

**Impact:**
- Network failures waste time
- Partial setups are hard to complete
- Users don't know what succeeded

### Problem 5: Implicit Dependencies

**Symptom:** Scripts fail cryptically when prerequisites missing

**Root Cause:** Prerequisites checked ad-hoc in each script

**Evidence:**
- `vault/_common.sh` line 176-182: `require_jq()` exits on failure
- `bootstrap-mac.sh` line 43-61: Homebrew check inline
- Different error handling in each script

**Impact:**
- Inconsistent error messages
- No unified prerequisite check
- Hard to debug failures

---

## Proposed Architecture

### Design Principles

1. **Single Source of Truth** - One config file for all state
2. **Idempotent Everything** - Safe to run any command multiple times
3. **Clear Phases** - Install → Configure → Verify
4. **Progressive Disclosure** - Simple by default, advanced when needed
5. **Fail Fast, Recover Gracefully** - Check prerequisites early, save progress often

### New Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         PROPOSED ARCHITECTURE                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  PHASE 1: INSTALL (one-time, non-interactive)                           │
│  ════════════════════════════════════════════                           │
│                                                                         │
│  install.sh                                                             │
│     ├── Clone repo                                                      │
│     ├── Run OS setup (packages, symlinks)                               │
│     ├── Print: "Run 'dotfiles setup' to configure"                      │
│     └── Exit (no --interactive flag)                                    │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  PHASE 2: CONFIGURE (idempotent wizard)                                 │
│  ══════════════════════════════════════                                 │
│                                                                         │
│  dotfiles setup                                                         │
│     ├── Load state from ~/.config/dotfiles/state.toml                   │
│     ├── Show current status (what's done, what's pending)               │
│     ├── For each pending item:                                          │
│     │      ├── Prompt user (or use saved preference)                    │
│     │      ├── Execute configuration                                    │
│     │      └── Save progress to state file                              │
│     └── Run verification                                                │
│                                                                         │
│  Configurable Items:                                                    │
│     ├── vault_backend: bitwarden | 1password | pass | none              │
│     ├── secrets_restored: true | false                                  │
│     ├── claude_configured: true | false                                 │
│     └── template_configured: true | false                               │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  PHASE 3: VERIFY (read-only health check)                               │
│  ════════════════════════════════════════                               │
│                                                                         │
│  dotfiles doctor                                                        │
│     ├── Check all components                                            │
│     ├── Report status                                                   │
│     └── Suggest fixes (--fix to auto-repair)                            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Command Restructuring

| Current | Proposed | Change |
|---------|----------|--------|
| `dotfiles init` | `dotfiles setup` | Rename for clarity |
| `dotfiles vault restore` | `dotfiles secrets restore` | Clearer terminology |
| `dotfiles vault sync` | `dotfiles secrets sync` | Consistency |
| `bootstrap-vault.sh` | `vault/restore.sh` | Remove "bootstrap" |
| `--interactive` flag | Remove | `dotfiles setup` is always interactive |

### File Restructuring

```
Current:                          Proposed:
────────                          ─────────
bootstrap/                        setup/
├── bootstrap-mac.sh              ├── install-macos.sh
├── bootstrap-linux.sh            ├── install-linux.sh
├── bootstrap-dotfiles.sh         ├── create-symlinks.sh
└── _common.sh                    └── _common.sh

vault/                            secrets/
├── bootstrap-vault.sh            ├── restore.sh          (renamed)
├── restore-ssh.sh                ├── restore-ssh.sh
├── restore-aws.sh                ├── restore-aws.sh
├── restore-env.sh                ├── restore-env.sh
├── restore-git.sh                ├── restore-git.sh
├── sync-to-vault.sh              ├── sync.sh             (renamed)
└── _common.sh                    └── _common.sh

bin/                              bin/
├── dotfiles-init                 ├── dotfiles-setup      (renamed)
├── dotfiles-doctor               ├── dotfiles-doctor
└── ...                           └── ...

(new)                             lib/
                                  ├── _state.sh           (NEW)
                                  ├── _vault.sh
                                  └── _logging.sh
```

---

## State Management Design

### State File Location

```
~/.config/dotfiles/
├── state.toml          # Setup progress and preferences
├── config.toml         # User configuration (vault backend, etc.)
└── cache/
    └── doctor.json     # Health check history (existing metrics)
```

### State File Schema

**`~/.config/dotfiles/config.toml`** - User Preferences (Persistent)

```toml
# Dotfiles Configuration
# This file stores your preferences. Edit manually or via 'dotfiles setup'.

[vault]
# Which vault backend to use: bitwarden, 1password, pass, none
backend = "bitwarden"

[features]
# Optional features
workspace_symlink = true      # Create /workspace symlink
claude_integration = true     # Set up Claude Code integration
template_system = false       # Use machine-specific templates

[machine]
# Machine-specific identifiers (used by template system)
name = "macbook-pro-work"
type = "work"                 # work, personal, server
```

**`~/.config/dotfiles/state.toml`** - Setup Progress (Auto-managed)

```toml
# Dotfiles Setup State
# Auto-generated by 'dotfiles setup'. Do not edit manually.

[install]
completed = true
completed_at = "2025-12-02T10:30:00Z"
version = "1.8.5"

[symlinks]
completed = true
completed_at = "2025-12-02T10:30:15Z"
items = ["zshrc", "p10k", "claude", "zellij"]

[packages]
completed = true
completed_at = "2025-12-02T10:35:00Z"
brewfile_hash = "abc123..."

[vault]
configured = true
configured_at = "2025-12-02T10:36:00Z"
backend = "bitwarden"
logged_in = true              # Updated on each check

[secrets]
restored = true
restored_at = "2025-12-02T10:37:00Z"
items = ["SSH-GitHub-Enterprise", "SSH-GitHub-Blackwell", "Git-Config", "AWS-Config"]

[claude]
configured = true
configured_at = "2025-12-02T10:38:00Z"
dotclaude_installed = true

[verification]
last_check = "2025-12-02T10:40:00Z"
status = "healthy"
issues = []
```

### State Library API

**`lib/_state.sh`** - State Management Functions

```bash
# ============================================================
# State Management API
# ============================================================

# Initialize state directory and files
state_init() {
    local config_dir="$HOME/.config/dotfiles"
    mkdir -p "$config_dir/cache"
    touch "$config_dir/config.toml"
    touch "$config_dir/state.toml"
}

# Read a config value
# Usage: value=$(config_get "vault.backend")
config_get() {
    local key="$1"
    local default="${2:-}"
    # Parse TOML and return value
}

# Write a config value
# Usage: config_set "vault.backend" "1password"
config_set() {
    local key="$1"
    local value="$2"
    # Update TOML file
}

# Check if a setup phase is completed
# Usage: if state_completed "symlinks"; then ...
state_completed() {
    local phase="$1"
    # Check state.toml
}

# Mark a setup phase as completed
# Usage: state_complete "symlinks" '["zshrc", "p10k"]'
state_complete() {
    local phase="$1"
    local metadata="${2:-}"
    # Update state.toml with timestamp
}

# Get setup progress summary
# Usage: state_summary
state_summary() {
    # Return structured summary of all phases
}

# Reset state for a phase (for re-running)
# Usage: state_reset "secrets"
state_reset() {
    local phase="$1"
    # Clear completed flag for phase
}
```

### State Transitions

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        STATE MACHINE                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  [FRESH]                                                                │
│     │                                                                   │
│     │ install.sh                                                        │
│     ▼                                                                   │
│  [INSTALLED]                                                            │
│     │ state: install.completed = true                                   │
│     │                                                                   │
│     │ dotfiles setup (auto-detects state)                               │
│     ▼                                                                   │
│  ┌──────────────────────────────────────────────────────┐               │
│  │ SETUP WIZARD (each step saves progress)              │               │
│  │                                                      │               │
│  │  [SYMLINKS] ──► [PACKAGES] ──► [VAULT] ──► [SECRETS] │               │
│  │       │              │            │            │     │               │
│  │       ▼              ▼            ▼            ▼     │               │
│  │    state:         state:       state:       state:   │               │
│  │    symlinks.      packages.    vault.       secrets. │               │
│  │    completed      completed    configured   restored │               │
│  │                                                      │               │
│  └──────────────────────────────────────────────────────┘               │
│     │                                                                   │
│     │ All phases completed                                              │
│     ▼                                                                   │
│  [CONFIGURED]                                                           │
│     │                                                                   │
│     │ dotfiles doctor                                                   │
│     ▼                                                                   │
│  [VERIFIED]                                                             │
│     state: verification.status = "healthy"                              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

Re-entry Points:
────────────────
• dotfiles setup     → Resumes from first incomplete phase
• dotfiles setup -f  → Re-runs all phases (with confirmation)
• dotfiles secrets restore → Just re-runs secrets phase
• dotfiles doctor --fix    → Repairs without full setup
```

---

## Implementation Plan

### Phase 1: Foundation (Non-Breaking)

**Goal:** Add state management without changing existing behavior

**Tasks:**

1. **Create `lib/_state.sh`**
   - Implement state file reading/writing
   - TOML parsing (simple subset, no dependencies)
   - Backward compatibility (works if no state file)

2. **Create `lib/_config.sh`**
   - User preference management
   - Vault backend persistence
   - Feature flags

3. **Update `lib/_vault.sh`**
   - Read backend from config file first
   - Fall back to env var, then default
   - Priority: config.toml > $DOTFILES_VAULT_BACKEND > "bitwarden"

4. **Add state directory setup**
   - Create `~/.config/dotfiles/` on first run
   - Migrate existing `.vault-session` location

**Deliverables:**
- `lib/_state.sh` (new)
- `lib/_config.sh` (new)
- Updated `lib/_vault.sh`
- No changes to user-facing commands

### Phase 2: Unified Setup Command

**Goal:** Create `dotfiles setup` as the primary configuration interface

**Tasks:**

1. **Create `bin/dotfiles-setup`**
   - Read current state
   - Show progress dashboard
   - Run pending phases interactively
   - Save progress after each phase

2. **Refactor `bin/dotfiles-init`**
   - Become thin wrapper around `dotfiles-setup`
   - Deprecation warning pointing to new command
   - Eventually remove

3. **Update `install.sh`**
   - Remove `--interactive` flag
   - Always end with "Run 'dotfiles setup'"
   - Never call dotfiles-init directly

4. **Add setup phases as modules**
   - `setup/phase-symlinks.sh`
   - `setup/phase-packages.sh`
   - `setup/phase-vault.sh`
   - `setup/phase-secrets.sh`
   - `setup/phase-claude.sh`

**Deliverables:**
- `bin/dotfiles-setup` (new)
- `setup/phase-*.sh` modules (new)
- Updated `install.sh`
- Deprecated `bin/dotfiles-init`

### Phase 3: Terminology Cleanup

**Goal:** Consistent naming throughout codebase

**Tasks:**

1. **Rename vault scripts**
   ```
   vault/bootstrap-vault.sh → vault/restore.sh
   ```

2. **Update command aliases**
   ```bash
   # In 40-aliases.zsh
   "vault restore" → calls vault/restore.sh
   "secrets restore" → alias for vault restore (new)
   "secrets sync" → alias for vault sync (new)
   ```

3. **Rename bootstrap scripts**
   ```
   bootstrap/bootstrap-mac.sh → setup/install-macos.sh
   bootstrap/bootstrap-linux.sh → setup/install-linux.sh
   bootstrap/bootstrap-dotfiles.sh → setup/create-symlinks.sh
   ```

4. **Update all documentation**
   - README.md
   - docs/*.md
   - Inline help text
   - Error messages

**Deliverables:**
- Renamed files with git mv (preserves history)
- Updated aliases maintaining backward compatibility
- Comprehensive documentation update

### Phase 4: Enhanced Resume Capability

**Goal:** Robust handling of interrupted setups

**Tasks:**

1. **Add checkpointing to each phase**
   - Save progress before risky operations
   - Restore checkpoint on failure

2. **Add `--resume` flag to setup**
   - Skip completed phases automatically
   - Show what will be run

3. **Add `--reset` flag for re-running**
   - Clear state for specific phase
   - Confirm before destructive reset

4. **Network failure handling**
   - Retry with exponential backoff
   - Cache downloads when possible
   - Clear error messages with retry instructions

**Deliverables:**
- Checkpoint system in `lib/_state.sh`
- Updated `dotfiles-setup` with flags
- Improved error handling throughout

### Phase 5: Status Dashboard Enhancement

**Goal:** Clear visualization of setup state

**Tasks:**

1. **Update `dotfiles status`**
   - Read from state file
   - Show setup progress
   - Indicate what's pending

2. **Add quick setup prompts**
   - If setup incomplete, offer to continue
   - Show single command to fix

3. **Integrate with doctor**
   - Doctor reads state file
   - Suggests `dotfiles setup` for missing config

**Deliverables:**
- Enhanced status function
- Integrated doctor suggestions
- Cohesive user guidance

---

## Migration Strategy

### Backward Compatibility

**Existing users should experience no breaking changes:**

1. **Environment variable still works**
   ```bash
   # This continues to work
   export DOTFILES_VAULT_BACKEND=1password
   dotfiles vault restore
   ```

2. **Old commands still work**
   ```bash
   # These remain functional
   dotfiles init          # Shows deprecation, runs setup
   dotfiles vault restore # Works as before
   ```

3. **No state file? No problem**
   ```bash
   # If ~/.config/dotfiles/state.toml doesn't exist:
   # - Commands work normally
   # - First run of 'dotfiles setup' creates it
   # - Infers current state from filesystem
   ```

### State Inference for Existing Users

When `dotfiles setup` runs for the first time on an existing installation:

```bash
state_infer() {
    # Check if already set up
    if [[ -L "$HOME/.zshrc" ]]; then
        state_complete "symlinks"
    fi

    if [[ -f "$HOME/.ssh/id_ed25519_enterprise_ghub" ]]; then
        state_complete "secrets"
    fi

    if [[ -n "${DOTFILES_VAULT_BACKEND:-}" ]]; then
        config_set "vault.backend" "$DOTFILES_VAULT_BACKEND"
    fi

    # ... etc
}
```

### Deprecation Timeline

| Version | Change |
|---------|--------|
| 1.9.0 | Add `dotfiles setup`, state management |
| 1.9.0 | `dotfiles init` shows deprecation warning |
| 1.10.0 | `--interactive` flag removed from install.sh |
| 2.0.0 | `dotfiles init` removed (alias to setup) |
| 2.0.0 | Old script names removed |

---

## User Experience Flows

### Flow A: Fresh Install (New User)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ FRESH INSTALL FLOW                                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  $ curl -fsSL .../install.sh | bash                                     │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │     ____        __  _____ __                                    │    │
│  │    / __ \____  / /_/ __(_) /__  _____                           │    │
│  │   / / / / __ \/ __/ /_/ / / _ \/ ___/                           │    │
│  │  / /_/ / /_/ / /_/ __/ / /  __(__  )                            │    │
│  │ /_____/\____/\__/_/ /_/_/\___/____/                             │    │
│  │                                                                 │    │
│  │ [INFO] Detected platform: macOS                                 │    │
│  │ [INFO] Cloning repository...                                    │    │
│  │ [OK] Cloned to ~/workspace/dotfiles                             │    │
│  │                                                                 │    │
│  │ [INFO] Installing packages...                                   │    │
│  │ [OK] Homebrew installed                                         │    │
│  │ [OK] Packages installed from Brewfile                           │    │
│  │                                                                 │    │
│  │ [INFO] Creating symlinks...                                     │    │
│  │ [OK] Linked ~/.zshrc                                            │    │
│  │ [OK] Linked ~/.p10k.zsh                                         │    │
│  │                                                                 │    │
│  │ ╔══════════════════════════════════════════════════════════╗    │    │
│  │ ║            Installation Complete!                        ║    │    │
│  │ ╚══════════════════════════════════════════════════════════╝    │    │
│  │                                                                 │    │
│  │ Next step:                                                      │    │
│  │   dotfiles setup                                                │    │
│  │                                                                 │    │
│  │ >>> Run 'exec zsh' to start using your new shell <<<            │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  $ exec zsh                                                             │
│  $ dotfiles setup                                                       │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ DOTFILES SETUP                                                  │    │
│  │ ═══════════════                                                 │    │
│  │                                                                 │    │
│  │ Current Status:                                                 │    │
│  │   [✓] Symlinks created                                          │    │
│  │   [✓] Packages installed                                        │    │
│  │   [ ] Vault not configured                                      │    │
│  │   [ ] Secrets not restored                                      │    │
│  │   [ ] Claude not configured                                     │    │
│  │                                                                 │    │
│  │ ─────────────────────────────────────────────────────────────── │    │
│  │                                                                 │    │
│  │ STEP 1: Vault Configuration                                     │    │
│  │                                                                 │    │
│  │ Available vault backends:                                       │    │
│  │   1) bitwarden                                                  │    │
│  │   2) 1password                                                  │    │
│  │   3) pass                                                       │    │
│  │   4) Skip (configure secrets manually)                          │    │
│  │                                                                 │    │
│  │ Select backend [1]: 2                                           │    │
│  │                                                                 │    │
│  │ [INFO] Saving preference: vault.backend = 1password             │    │
│  │ [INFO] Please sign in to 1Password...                           │    │
│  │ [OK] 1Password authenticated                                    │    │
│  │ [OK] Vault configured ✓                                         │    │
│  │                                                                 │    │
│  │ ─────────────────────────────────────────────────────────────── │    │
│  │                                                                 │    │
│  │ STEP 2: Restore Secrets                                         │    │
│  │                                                                 │    │
│  │ Would restore:                                                  │    │
│  │   • SSH keys (2 keys)                                           │    │
│  │   • AWS credentials                                             │    │
│  │   • Git configuration                                           │    │
│  │   • Environment secrets                                         │    │
│  │                                                                 │    │
│  │ Restore secrets? [Y/n]: y                                       │    │
│  │                                                                 │    │
│  │ [OK] SSH keys restored                                          │    │
│  │ [OK] AWS credentials restored                                   │    │
│  │ [OK] Git config restored                                        │    │
│  │ [OK] Secrets restored ✓                                         │    │
│  │                                                                 │    │
│  │ ─────────────────────────────────────────────────────────────── │    │
│  │                                                                 │    │
│  │ STEP 3: Claude Code (Optional)                                  │    │
│  │                                                                 │    │
│  │ Claude Code detected. Install dotclaude for profile sync?       │    │
│  │ [Y/n]: y                                                        │    │
│  │                                                                 │    │
│  │ [OK] dotclaude installed ✓                                      │    │
│  │                                                                 │    │
│  │ ═══════════════════════════════════════════════════════════════ │    │
│  │                                                                 │    │
│  │ SETUP COMPLETE!                                                 │    │
│  │                                                                 │    │
│  │   [✓] Symlinks created                                          │    │
│  │   [✓] Packages installed                                        │    │
│  │   [✓] Vault configured (1password)                              │    │
│  │   [✓] Secrets restored                                          │    │
│  │   [✓] Claude configured                                         │    │
│  │                                                                 │    │
│  │ Run 'dotfiles doctor' to verify everything is healthy.          │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Flow B: Returning User (New Machine)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ RETURNING USER FLOW                                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  User has secrets in 1Password, setting up new MacBook                  │
│                                                                         │
│  $ curl -fsSL .../install.sh | bash                                     │
│  ... [installation output] ...                                          │
│                                                                         │
│  $ exec zsh                                                             │
│  $ dotfiles setup                                                       │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ DOTFILES SETUP                                                  │    │
│  │                                                                 │    │
│  │ Current Status:                                                 │    │
│  │   [✓] Symlinks created                                          │    │
│  │   [✓] Packages installed                                        │    │
│  │   [ ] Vault not configured                                      │    │
│  │   [ ] Secrets not restored                                      │    │
│  │                                                                 │    │
│  │ Select vault backend [1]: 2  (1password)                        │    │
│  │                                                                 │    │
│  │ [INFO] 1Password CLI detected                                   │    │
│  │ [INFO] Please authenticate with 1Password...                    │    │
│  │                                                                 │    │
│  │ $ op signin                                                     │    │
│  │ ... [1Password auth] ...                                        │    │
│  │                                                                 │    │
│  │ [OK] 1Password authenticated                                    │    │
│  │                                                                 │    │
│  │ Restore secrets? [Y/n]: y                                       │    │
│  │                                                                 │    │
│  │ [OK] All secrets restored from 1Password                        │    │
│  │                                                                 │    │
│  │ SETUP COMPLETE! Ready to use.                                   │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  # Later, on ANOTHER new machine:                                       │
│                                                                         │
│  $ dotfiles setup                                                       │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ Found existing configuration:                                   │    │
│  │   Vault: 1password                                              │    │
│  │                                                                 │    │
│  │ Use same settings? [Y/n]: y                                     │    │
│  │                                                                 │    │
│  │ [OK] Restored all secrets                                       │    │
│  │ [OK] Setup complete in 30 seconds                               │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  (Config synced via vault, so preferences carry over!)                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Flow C: Interrupted Setup (Resume)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ INTERRUPTED SETUP FLOW                                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  $ dotfiles setup                                                       │
│                                                                         │
│  [✓] Symlinks created                                                   │
│  [✓] Packages installed                                                 │
│  [✓] Vault configured (bitwarden)                                       │
│                                                                         │
│  Restoring secrets...                                                   │
│  [OK] SSH keys restored                                                 │
│  [FAIL] Network error fetching AWS-Config                               │
│                                                                         │
│  Setup incomplete. Progress saved.                                      │
│  Run 'dotfiles setup' to resume.                                        │
│                                                                         │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  # Later, network is back:                                              │
│                                                                         │
│  $ dotfiles setup                                                       │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ Resuming setup from previous session...                         │    │
│  │                                                                 │    │
│  │ Completed:                                                      │    │
│  │   [✓] Symlinks                                                  │    │
│  │   [✓] Packages                                                  │    │
│  │   [✓] Vault (bitwarden)                                         │    │
│  │   [~] Secrets (partial - SSH done, AWS pending)                 │    │
│  │                                                                 │    │
│  │ Continue? [Y/n]: y                                              │    │
│  │                                                                 │    │
│  │ [OK] AWS credentials restored                                   │    │
│  │ [OK] Git config restored                                        │    │
│  │ [OK] Environment secrets restored                               │    │
│  │                                                                 │    │
│  │ SETUP COMPLETE!                                                 │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Flow D: Status Check (Existing User)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ STATUS CHECK FLOW                                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  $ dotfiles status                                                      │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                                                                 │    │
│  │  ╭─────────────────────────────────────────────────────────╮    │    │
│  │  │              D O T F I L E S   S T A T U S              │    │    │
│  │  ╰─────────────────────────────────────────────────────────╯    │    │
│  │                                                                 │    │
│  │  Setup Progress          Health                                 │    │
│  │  ──────────────          ──────                                 │    │
│  │  [✓] Symlinks            Shell:     ✓ zsh 5.9                   │    │
│  │  [✓] Packages            Vault:     ✓ 1password (logged in)     │    │
│  │  [✓] Vault               SSH:       ✓ 2 keys loaded             │    │
│  │  [✓] Secrets             AWS:       ✓ default profile           │    │
│  │  [✓] Claude              Git:       ✓ user configured           │    │
│  │                                                                 │    │
│  │  Configuration                                                  │    │
│  │  ─────────────                                                  │    │
│  │  Vault backend:   1password                                     │    │
│  │  Machine:         macbook-pro-work                              │    │
│  │  Last verified:   2 hours ago                                   │    │
│  │                                                                 │    │
│  │  Quick Commands                                                 │    │
│  │  ──────────────                                                 │    │
│  │  dotfiles doctor          Full health check                     │    │
│  │  dotfiles secrets sync    Push changes to vault                 │    │
│  │  dotfiles upgrade         Update dotfiles                       │    │
│  │                                                                 │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Risk Analysis

### Technical Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| TOML parsing complexity | Medium | Medium | Use simple subset, test extensively |
| State file corruption | High | Low | Atomic writes, backup before modify |
| Migration breaks existing setup | High | Medium | Inference from filesystem, gradual rollout |
| Backward compatibility issues | Medium | Medium | Extensive testing, deprecation period |

### User Experience Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Confusion during transition | Medium | High | Clear deprecation messages, documentation |
| Lost preferences during upgrade | High | Low | Config file in vault, backup on upgrade |
| Too many prompts in setup | Medium | Medium | Smart defaults, remember choices |

### Implementation Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Scope creep | Medium | High | Strict phase boundaries, MVP focus |
| Breaking changes cascade | High | Medium | Comprehensive test suite, staged rollout |
| Documentation lag | Medium | High | Update docs in same PR as code |

---

## Success Criteria

### Quantitative Metrics

| Metric | Current | Target | Measurement |
|--------|---------|--------|-------------|
| Commands to complete setup | 3-5 | 1-2 | Count user actions |
| Time to first working shell | 20-30 min | 10-15 min | Timed test |
| Setup resume success rate | 0% | 95%+ | Test interrupted setups |
| Documentation accuracy | Unknown | 100% | Audit pass |

### Qualitative Criteria

- [ ] New user can complete setup without reading docs
- [ ] Existing user upgrade is seamless
- [ ] `dotfiles setup` is discoverable from any state
- [ ] Error messages include actionable next steps
- [ ] State file is human-readable for debugging
- [ ] All terminology is consistent across codebase

### Test Scenarios

1. **Fresh macOS install** - Complete setup from curl to working shell
2. **Fresh Linux install** - Same as above on Ubuntu/Debian
3. **Upgrade from 1.8.x** - Existing user upgrades, state inferred
4. **Interrupted setup** - Kill during secret restore, resume works
5. **Backend switch** - Change from Bitwarden to 1Password
6. **Multi-machine sync** - Config preferences carry via vault
7. **Offline mode** - Setup works without vault (manual secrets)

---

## Appendix: File Changes Summary

### New Files

```
lib/_state.sh                    # State management API
lib/_config.sh                   # Config file management
bin/dotfiles-setup               # New unified setup command
setup/phase-symlinks.sh          # Modular setup phases
setup/phase-packages.sh
setup/phase-vault.sh
setup/phase-secrets.sh
setup/phase-claude.sh
```

### Renamed Files

```
vault/bootstrap-vault.sh    →    vault/restore.sh
bootstrap/bootstrap-mac.sh  →    setup/install-macos.sh
bootstrap/bootstrap-linux.sh →   setup/install-linux.sh
bootstrap/bootstrap-dotfiles.sh → setup/create-symlinks.sh
```

### Modified Files

```
install.sh                       # Remove --interactive, update messaging
zsh/zsh.d/40-aliases.zsh         # Add new command aliases
zsh/zsh.d/50-functions.zsh       # Update status() to read state
bin/dotfiles-doctor              # Read state, suggest setup
lib/_vault.sh                    # Read backend from config file
```

### Deprecated Files

```
bin/dotfiles-init                # Wrapper to dotfiles-setup (remove in 2.0)
```

---

## Next Steps

1. **Review this plan** - Get feedback on approach
2. **Prototype state management** - Build `lib/_state.sh` first
3. **Test state inference** - Ensure existing users aren't broken
4. **Build setup wizard** - Create `dotfiles setup` incrementally
5. **Update documentation** - As each phase completes
6. **Staged rollout** - Beta test before full release
