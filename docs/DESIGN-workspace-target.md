# Design Document: Configurable Workspace Target

> **Status:** Draft
> **Author:** Claude Code
> **Date:** 2025-12-05

---

## Overview

This document proposes making the workspace symlink target configurable, allowing users to use their existing project directory layout (e.g., `~/code`, `~/projects`, `~/dev`) instead of the default `~/workspace`.

### Current Behavior

```
/workspace → ~/workspace (hardcoded)
```

### Proposed Behavior

```
/workspace → $WORKSPACE_TARGET (configurable, default: ~/workspace)
```

The symlink **name** (`/workspace`) stays constant for Claude Code session portability. Only the **target** directory becomes configurable.

---

## Motivation

**User Pain Points:**
1. Users with established project layouts (`~/code`, `~/projects`) must reorganize or duplicate
2. Corporate environments may mandate specific directory structures
3. Some users prefer shorter paths like `~/dev`

**Benefits:**
- Zero reorganization needed for existing users
- Respects established workflows
- Maintains full Claude Code session portability (paths still reference `/workspace/...`)

---

## Implementation Plan

### Phase 1: Core Infrastructure

#### 1.1 Environment Variable Support

**File: `bootstrap/_common.sh`**

```bash
# New: Allow customizing workspace target
WORKSPACE_TARGET="${WORKSPACE_TARGET:-$HOME/workspace}"

setup_workspace_layout() {
    echo "Ensuring workspace layout at $WORKSPACE_TARGET..."
    mkdir -p "$WORKSPACE_TARGET"
    mkdir -p "$WORKSPACE_TARGET/code"
}

setup_workspace_symlink() {
    SKIP_WORKSPACE_SYMLINK="${SKIP_WORKSPACE_SYMLINK:-false}"

    if [[ "$SKIP_WORKSPACE_SYMLINK" = "true" ]]; then
        echo "Skipping /workspace symlink (SKIP_WORKSPACE_SYMLINK=true)"
        return 0
    fi

    # Use configurable target instead of hardcoded $HOME/workspace
    local target="${WORKSPACE_TARGET:-$HOME/workspace}"

    if [[ -L /workspace ]]; then
        local current_target
        current_target=$(readlink /workspace)
        if [[ "$current_target" == "$target" ]]; then
            echo "/workspace symlink already correct."
            return 0
        else
            echo "Updating /workspace symlink..."
            sudo rm /workspace && sudo ln -sfn "$target" /workspace
            echo "Updated /workspace -> $target"
            return 0
        fi
    elif [[ -e /workspace ]]; then
        echo "WARNING: /workspace exists but is not a symlink. Skipping."
        return 0
    fi

    echo "Creating /workspace symlink (requires sudo)..."
    if sudo ln -sfn "$target" /workspace 2>/dev/null; then
        pass "Created /workspace -> $target"
        return 0
    fi

    # ... existing macOS synthetic.conf fallback ...
}
```

**Changes:**
- Line 114-116: Use `$WORKSPACE_TARGET` instead of hardcoded `$HOME/workspace`
- Line 123, 136, 141, 142, 156, 157, 170, 177, 181: Replace `$HOME/workspace` with `$target`

#### 1.2 Configuration Persistence

**File: `lib/_config.sh`**

Add to `get_default_config()`:

```json
{
  "version": 3,
  "paths": {
    "dotfiles_dir": "",
    "config_dir": "~/.config/blackdot",
    "backup_dir": "~/.blackdot-backups",
    "workspace_target": "~/workspace"  // NEW
  }
}
```

**New helper function:**

```bash
# Get workspace target from config or env
get_workspace_target() {
    # Priority: env var > config > default
    if [[ -n "${WORKSPACE_TARGET:-}" ]]; then
        echo "$WORKSPACE_TARGET"
    else
        local configured
        configured=$(config_get "paths.workspace_target" "")
        if [[ -n "$configured" && "$configured" != "~" ]]; then
            # Expand ~ to $HOME
            echo "${configured/#\~/$HOME}"
        else
            echo "$HOME/workspace"
        fi
    fi
}
```

#### 1.3 Install Script Update

**File: `install.sh`**

```bash
# Line 33: Use env var or default
WORKSPACE_TARGET="${WORKSPACE_TARGET:-$HOME/workspace}"
INSTALL_DIR="$WORKSPACE_TARGET/dotfiles"

# Line 136: Create workspace directory
mkdir -p "$WORKSPACE_TARGET"
```

Also update help text:

```bash
echo "    WORKSPACE_TARGET=~/code ./install.sh   # Use ~/code instead of ~/workspace"
```

---

### Phase 2: CLI Tools Updates

All CLI tools that use fallback path detection need updating.

#### 2.1 Shared Helper Function

**File: `lib/_paths.sh`** (NEW FILE)

```bash
#!/usr/bin/env bash
# Shared path resolution for CLI tools

# Get dotfiles directory with fallback logic
get_dotfiles_dir() {
    if [[ -n "${BLACKDOT_DIR:-}" ]]; then
        echo "$BLACKDOT_DIR"
        return 0
    fi

    # Check configured workspace target
    local workspace_target
    workspace_target="$(get_workspace_target)"

    # Try workspace target first
    if [[ -d "$workspace_target/dotfiles" ]]; then
        echo "$workspace_target/dotfiles"
        return 0
    fi

    # Fallback to /workspace (the symlink)
    if [[ -d "/workspace/dotfiles" ]]; then
        echo "/workspace/dotfiles"
        return 0
    fi

    # Legacy fallbacks
    if [[ -d "$HOME/workspace/dotfiles" ]]; then
        echo "$HOME/workspace/dotfiles"
        return 0
    fi

    return 1
}

get_workspace_target() {
    # Check env var first
    if [[ -n "${WORKSPACE_TARGET:-}" ]]; then
        echo "$WORKSPACE_TARGET"
        return
    fi

    # Check config file
    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/config.json"
    if [[ -f "$config_file" ]]; then
        local configured
        configured=$(jq -r '.paths.workspace_target // empty' "$config_file" 2>/dev/null)
        if [[ -n "$configured" && "$configured" != "null" ]]; then
            echo "${configured/#\~/$HOME}"
            return
        fi
    fi

    # Default
    echo "$HOME/workspace"
}
```

#### 2.2 CLI Tools to Update

| File | Current Code | Change Needed |
|------|--------------|---------------|
| `bin/blackdot-doctor` | Lines 17-20: hardcoded `~/workspace/dotfiles`, `/workspace/dotfiles` | Use `get_dotfiles_dir()` |
| `bin/blackdot-lint` | Lines 20-23: same pattern | Use `get_dotfiles_dir()` |
| `bin/blackdot-packages` | Lines 18-21: same pattern | Use `get_dotfiles_dir()` |
| `bin/blackdot-backup` | Lines 23-26: same pattern | Use `get_dotfiles_dir()` |
| `bin/blackdot-diff` | Line 35, 149: hardcoded `$HOME/workspace/dotfiles/vault` | Use `get_dotfiles_dir()` |
| `bin/blackdot-uninstall` | Line 53: `/workspace`, Line 124: `$HOME/workspace/dotfiles` | Use `get_workspace_target()` |

**Example update for `bin/blackdot-doctor`:**

```bash
# Before (lines 14-41):
if [[ -n "${BLACKDOT_DIR:-}" ]]; then
    BLACKDOT_DIR="$BLACKDOT_DIR"
elif [[ -d "$HOME/workspace/dotfiles" ]]; then
    BLACKDOT_DIR="$HOME/workspace/dotfiles"
elif [[ -d "/workspace/dotfiles" ]]; then
    BLACKDOT_DIR="/workspace/dotfiles"
else
    # ... error handling ...
fi

# After:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/lib/_paths.sh" 2>/dev/null || true

BLACKDOT_DIR="${BLACKDOT_DIR:-$(get_dotfiles_dir)}"
if [[ -z "$BLACKDOT_DIR" || ! -d "$BLACKDOT_DIR" ]]; then
    # ... error handling ...
fi
```

---

### Phase 3: Template System Updates

#### 3.1 Auto-Detection

**File: `lib/_templates.sh`**

```bash
# Line 190: Update auto vars
build_auto_vars() {
    TMPL_AUTO=(
        # ... existing ...
        [workspace]="$(get_workspace_target)"  # Was: "${WORKSPACE:-$HOME/workspace}"
        # ... rest ...
    )
}
```

#### 3.2 Variable Defaults

**File: `templates/_variables.sh`**

```bash
# Line 129: Update computed defaults
get_computed_defaults() {
    # Use the helper instead of hardcoded path
    local workspace
    if type get_workspace_target &>/dev/null; then
        workspace="$(get_workspace_target)"
    else
        workspace="${TMPL_AUTO[workspace]:-$HOME/workspace}"
    fi

    [[ -z "${TMPL_DEFAULTS[projects_dir]}" ]] && TMPL_DEFAULTS[projects_dir]="$workspace/projects"
    [[ -z "${TMPL_DEFAULTS[notes_dir]}" ]] && TMPL_DEFAULTS[notes_dir]="$workspace/notes"
    [[ -z "${TMPL_DEFAULTS[scripts_dir]}" ]] && TMPL_DEFAULTS[scripts_dir]="$workspace/scripts"
}
```

---

### Phase 4: Other Scripts

#### 4.1 Bootstrap Dotfiles

**File: `bootstrap/bootstrap-dotfiles.sh`**

```bash
# Line 55: Update Claude shared path
WORKSPACE_TARGET="${WORKSPACE_TARGET:-$HOME/workspace}"
CLAUDE_SHARED="$WORKSPACE_TARGET/.claude"
```

#### 4.2 Vault Discovery

**File: `vault/discover-secrets.sh`**

```bash
# Line 181, 313: Update search paths
local workspace_target="$(get_workspace_target)"
local dotfiles_dirs=("$HOME/dotfiles" "$HOME/.dotfiles" "$workspace_target/dotfiles")
```

---

### Phase 5: Doctor Health Check

**File: `bin/blackdot-doctor`**

Update the `/workspace` symlink check to be target-aware:

```bash
# Around line 215: Update symlink check
local expected_target
expected_target="$(get_workspace_target)"

if [[ -L "/workspace" ]]; then
    local actual_target
    actual_target=$(readlink /workspace)
    if [[ "$actual_target" == "$expected_target" ]]; then
        pass "/workspace symlink correct (-> $expected_target)"
    else
        warn "/workspace points to $actual_target (expected $expected_target)"
    fi
else
    warn "/workspace symlink not configured (optional for multi-machine)"
fi
```

---

### Phase 6: Dockerfiles (Optional)

Dockerfiles can use build args to customize:

**Example: `Dockerfile.lite`**

```dockerfile
ARG WORKSPACE_TARGET=/root/workspace
ENV WORKSPACE=${WORKSPACE_TARGET}

# ... rest uses $WORKSPACE instead of hardcoded paths ...
```

| File | Lines to Update |
|------|-----------------|
| `Dockerfile.lite` | 39, 41, 44-50, 53-56, 61, 64-65, 87-88 |
| `Dockerfile.medium` | 10, 49, 52, 55-58, 62-63, 103 |
| `Dockerfile.extralite` | 18, 20, 23-28, 31-33, 37-39, 58-59 |
| `Dockerfile` | 32, 35, 39, 88, 103 |

---

## Configuration Summary

### Environment Variable

```bash
WORKSPACE_TARGET="$HOME/code" ./install.sh
```

### Config File

```json
{
  "paths": {
    "workspace_target": "~/code"
  }
}
```

### Interactive Setup

Could add to setup wizard:

```
Where do you keep your projects?
  1) ~/workspace (default)
  2) ~/code
  3) ~/projects
  4) Custom path

Select [1]:
```

---

## File Change Summary

### Must Change (Core)

| File | Type | Complexity |
|------|------|------------|
| `bootstrap/_common.sh` | Modify | Low |
| `lib/_config.sh` | Modify | Low |
| `lib/_paths.sh` | **New file** | Low |
| `install.sh` | Modify | Low |

### Must Change (CLI Tools)

| File | Type | Complexity |
|------|------|------------|
| `bin/blackdot-doctor` | Modify | Low |
| `bin/blackdot-lint` | Modify | Low |
| `bin/blackdot-packages` | Modify | Low |
| `bin/blackdot-backup` | Modify | Low |
| `bin/blackdot-diff` | Modify | Low |
| `bin/blackdot-uninstall` | Modify | Low |

### Must Change (Templates)

| File | Type | Complexity |
|------|------|------------|
| `lib/_templates.sh` | Modify | Low |
| `templates/_variables.sh` | Modify | Low |

### Should Change (Other Scripts)

| File | Type | Complexity |
|------|------|------------|
| `bootstrap/bootstrap-dotfiles.sh` | Modify | Low |
| `vault/discover-secrets.sh` | Modify | Low |

### Optional (Dockerfiles)

| File | Type | Complexity |
|------|------|------------|
| `Dockerfile.lite` | Modify | Medium |
| `Dockerfile.medium` | Modify | Medium |
| `Dockerfile.extralite` | Modify | Medium |
| `Dockerfile` | Modify | Medium |

### Documentation (No Code Changes)

Documentation can remain as-is with defaults shown, plus a note about customization:

```markdown
> **Tip:** Use `WORKSPACE_TARGET=~/code` to use a different project directory.
> The `/workspace` symlink will point to your chosen directory.
```

---

## Migration Path

### Existing Users

No migration needed - default behavior unchanged (`~/workspace`).

### Users Who Want Custom Path

1. Set `WORKSPACE_TARGET` before running install/bootstrap
2. Or edit `~/.config/blackdot/config.json` and re-run bootstrap

---

## Testing Plan

1. **Unit tests:** Add tests for `get_workspace_target()` function
2. **Integration tests:** Test with `WORKSPACE_TARGET` set to non-default
3. **Manual testing:**
   - Fresh install with `WORKSPACE_TARGET=~/code`
   - Upgrade existing install (should keep `~/workspace`)
   - Doctor check with custom target

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking existing installs | Default unchanged; env var opt-in |
| Path inconsistency across tools | Centralized `get_workspace_target()` helper |
| Symlink confusion | Doctor clearly reports actual vs expected target |
| Docker builds break | Use build args with sensible defaults |

---

## Implementation Order

1. **Create `lib/_paths.sh`** - Central helper functions
2. **Update `lib/_config.sh`** - Add schema and getter
3. **Update `bootstrap/_common.sh`** - Core symlink logic
4. **Update `install.sh`** - Initial setup
5. **Update CLI tools** - Use new helpers
6. **Update templates** - Use workspace target
7. **Update doctor** - Enhanced symlink check
8. **Update other scripts** - bootstrap-dotfiles, discover-secrets
9. **Optional: Dockerfiles** - Build arg support
10. **Add tests** - Unit and integration

---

## Appendix: Full File List with Line Numbers

### bootstrap/_common.sh
- Line 61: Add `WORKSPACE_TARGET` to env var docs
- Line 98-99: Update interactive prompt
- Line 114-116: `setup_workspace_layout()` - use target var
- Line 123: Comment update
- Line 125: Add target variable
- Line 136-142: All `$HOME/workspace` → `$target`
- Line 156-157: Same
- Line 170: synthetic.conf message
- Line 177, 181: Error messages

### install.sh
- Line 33: `INSTALL_DIR` calculation
- Line 57, 65: Help text
- Line 136: `mkdir` command

### lib/_config.sh
- Line 46-49: Add `workspace_target` to default config

### bin/blackdot-doctor
- Lines 17-20: Path detection
- Lines 23-24, 34, 38: Error messages
- Line 212: Claude symlink check
- Lines 215-218: /workspace symlink check

### bin/blackdot-lint
- Lines 20-23: Path detection

### bin/blackdot-packages
- Lines 18-21: Path detection

### bin/blackdot-backup
- Lines 23-26: Path detection

### bin/blackdot-diff
- Line 35: Hardcoded vault path
- Line 149: Same

### bin/blackdot-uninstall
- Line 53: `/workspace` in SYMLINKS array
- Line 124-131: `$HOME/workspace/dotfiles` removal logic

### bootstrap/bootstrap-dotfiles.sh
- Line 55: `CLAUDE_SHARED` path

### vault/discover-secrets.sh
- Line 181: Search paths array
- Line 313: Same pattern

### lib/_templates.sh
- Line 190: `[workspace]` auto var

### templates/_variables.sh
- Line 129: `get_computed_defaults()` workspace reference
