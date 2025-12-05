# Hook System Implementation

> **Status:** Complete
> **Priority:** Medium
> **Complexity:** Medium
> **Completed:** v3.0
> **Foundation:** [Feature Registry](../features.md) (v2.1.0)

## Overview

The hook system allows users to inject custom behavior at key lifecycle points without modifying core scripts. Hooks are shell functions or scripts that execute before/after major operations.

---

## Architecture Foundation

The Hook System integrates with the **Feature Registry** (`lib/_features.sh`) which serves as the control plane for the entire modular architecture:

```
┌─────────────────────────────────────────────┐
│         Feature Registry (v2.1.0)            │
│   - Tracks enabled/disabled features         │
│   - Resolves dependencies                    │
│   - Persists state to config.json            │
└─────────────────┬───────────────────────────┘
                  │ controls
                  ▼
┌─────────────────────────────────────────────┐
│           Hook System (this doc)             │
│   - Hooks only run if parent feature enabled │
│   - Hook system itself is a feature          │
│   - Hooks can check feature state            │
└─────────────────────────────────────────────┘
```

**Key integration points:**
- The hook system registers as the `hooks` feature (optional category)
- Vault hooks only run if `vault` feature is enabled
- Hooks can call `feature_enabled()` to conditionally execute
- `dotfiles features disable hooks` disables all hook execution

---

## Goals

1. **User customization** - Run custom code at lifecycle events
2. **Non-invasive** - Hooks don't modify core behavior, just extend it
3. **Fail-safe** - Hook failures don't break core operations (configurable)
4. **Transparent** - Easy to see what hooks are registered and when they run

---

## Hook Points

### Core Lifecycle Hooks

| Hook | When | Use Case |
|------|------|----------|
| `pre_install` | Before `install.sh` runs | Backup existing files |
| `post_install` | After `install.sh` completes | Run custom setup |
| `pre_bootstrap` | Before bootstrap script | Check prerequisites |
| `post_bootstrap` | After bootstrap completes | Install extra packages |
| `pre_upgrade` | Before `dotfiles upgrade` | Backup config |
| `post_upgrade` | After upgrade completes | Run migrations |

### Vault Hooks

| Hook | When | Use Case |
|------|------|----------|
| `pre_vault_pull` | Before restoring secrets | Backup existing secrets |
| `post_vault_pull` | After secrets restored | Set permissions, run ssh-add |
| `pre_vault_push` | Before syncing to vault | Validate secrets |
| `post_vault_push` | After vault sync | Notify/log |

### Doctor Hooks

| Hook | When | Use Case |
|------|------|----------|
| `pre_doctor` | Before health check | Custom pre-checks |
| `post_doctor` | After health check | Report to monitoring |
| `doctor_check` | During doctor (adds custom checks) | Add custom validations |

### Shell Hooks

| Hook | When | Use Case |
|------|------|----------|
| `shell_init` | End of .zshrc | Load project-specific config |
| `shell_exit` | Shell exit (via zshexit) | Cleanup, logging |
| `directory_change` | On cd (via chpwd) | Auto-activate envs |

### Setup Wizard Hooks

| Hook | When | Use Case |
|------|------|----------|
| `pre_setup_phase` | Before each wizard phase | Custom validation |
| `post_setup_phase` | After each wizard phase | Phase-specific setup |
| `setup_complete` | After all phases done | Final customization |

---

## Hook Configuration

### File-based Registration (`~/.config/dotfiles/hooks/`)

```
~/.config/dotfiles/hooks/
├── post_vault_pull/
│   ├── 10-ssh-add.sh
│   ├── 20-gpg-import.sh
│   └── 30-notify.sh
├── shell_init/
│   └── 10-project-env.zsh
└── doctor_check/
    └── 10-custom-checks.sh
```

Scripts are executed in alphabetical order (use numeric prefixes).

### JSON Configuration (`~/.config/dotfiles/hooks.json`)

```json
{
  "hooks": {
    "post_vault_pull": [
      {
        "name": "ssh-add",
        "command": "ssh-add ~/.ssh/id_ed25519",
        "enabled": true,
        "fail_ok": true
      },
      {
        "name": "notify",
        "script": "~/.config/dotfiles/hooks/notify.sh",
        "enabled": true
      }
    ],
    "shell_init": [
      {
        "name": "project-env",
        "function": "load_project_env",
        "enabled": true
      }
    ]
  },
  "settings": {
    "fail_fast": false,
    "verbose": false,
    "timeout": 30
  }
}
```

### Inline Registration (in shell config)

```zsh
# In ~/.zshrc.local or plugin init.zsh
hook_register "post_vault_pull" "my_ssh_add"
hook_register "shell_init" "load_work_config"

my_ssh_add() {
    ssh-add ~/.ssh/id_ed25519 2>/dev/null
}

load_work_config() {
    [[ -f ~/.work-env ]] && source ~/.work-env
}
```

---

## Library Implementation (`lib/_hooks.sh`)

```zsh
#!/usr/bin/env zsh
# lib/_hooks.sh - Hook system library

# Hook storage
typeset -gA HOOKS  # HOOKS[point]="func1 func2 func3"

# Configuration
HOOKS_DIR="${HOOKS_DIR:-$HOME/.config/dotfiles/hooks}"
HOOKS_CONFIG="${HOOKS_CONFIG:-$HOME/.config/dotfiles/hooks.json}"
HOOKS_FAIL_FAST="${HOOKS_FAIL_FAST:-false}"
HOOKS_VERBOSE="${HOOKS_VERBOSE:-false}"
HOOKS_TIMEOUT="${HOOKS_TIMEOUT:-30}"

# Valid hook points
HOOK_POINTS=(
    pre_install post_install
    pre_bootstrap post_bootstrap
    pre_upgrade post_upgrade
    pre_vault_pull post_vault_pull
    pre_vault_push post_vault_push
    pre_doctor post_doctor doctor_check
    shell_init shell_exit directory_change
    pre_setup_phase post_setup_phase setup_complete
)

#######################################
# Validate hook point name
# Arguments: hook_point
# Returns: 0 if valid
#######################################
hook_valid_point() {
    local point="$1"
    [[ " ${HOOK_POINTS[*]} " =~ " ${point} " ]]
}

#######################################
# Register a hook function
# Arguments: hook_point, function_name
# Returns: 0 on success
#######################################
hook_register() {
    local point="$1"
    local func="$2"

    if ! hook_valid_point "$point"; then
        echo "Invalid hook point: $point" >&2
        echo "Valid points: ${HOOK_POINTS[*]}" >&2
        return 1
    fi

    # Verify function exists (if not a path)
    if [[ ! -f "$func" ]] && ! type "$func" &>/dev/null; then
        echo "Hook function not found: $func" >&2
        return 1
    fi

    # Append to hooks list
    if [[ -z "${HOOKS[$point]:-}" ]]; then
        HOOKS[$point]="$func"
    else
        HOOKS[$point]="${HOOKS[$point]} $func"
    fi

    [[ "$HOOKS_VERBOSE" == "true" ]] && echo "Registered hook: $point -> $func"
}

#######################################
# Unregister a hook function
# Arguments: hook_point, function_name
#######################################
hook_unregister() {
    local point="$1"
    local func="$2"

    if [[ -n "${HOOKS[$point]:-}" ]]; then
        HOOKS[$point]="${HOOKS[$point]//$func/}"
        HOOKS[$point]="${HOOKS[$point]//  / }"  # Clean double spaces
    fi
}

#######################################
# Run all hooks for a point
# Arguments: hook_point, [args...]
# Returns: 0 if all succeed, 1 if any fail (respects fail_fast)
#######################################
hook_run() {
    local point="$1"
    shift
    local args=("$@")
    local failed=0

    [[ "$HOOKS_VERBOSE" == "true" ]] && echo "Running hooks: $point"

    # Run file-based hooks first
    if [[ -d "${HOOKS_DIR}/${point}" ]]; then
        for script in "${HOOKS_DIR}/${point}"/*.{sh,zsh}(N); do
            [[ -x "$script" ]] || continue
            _hook_exec_script "$script" "${args[@]}" || {
                failed=1
                [[ "$HOOKS_FAIL_FAST" == "true" ]] && return 1
            }
        done
    fi

    # Run registered function hooks
    local funcs="${HOOKS[$point]:-}"
    for func in ${(s: :)funcs}; do
        [[ -z "$func" ]] && continue
        _hook_exec_func "$func" "${args[@]}" || {
            failed=1
            [[ "$HOOKS_FAIL_FAST" == "true" ]] && return 1
        }
    done

    # Run JSON-configured hooks
    _hook_run_json_hooks "$point" "${args[@]}" || failed=1

    return $failed
}

#######################################
# Execute a hook script with timeout
# Arguments: script_path, [args...]
#######################################
_hook_exec_script() {
    local script="$1"
    shift

    [[ "$HOOKS_VERBOSE" == "true" ]] && echo "  Running script: $script"

    if command -v timeout &>/dev/null; then
        timeout "$HOOKS_TIMEOUT" "$script" "$@"
    else
        "$script" "$@"
    fi
}

#######################################
# Execute a hook function
# Arguments: function_name, [args...]
#######################################
_hook_exec_func() {
    local func="$1"
    shift

    [[ "$HOOKS_VERBOSE" == "true" ]] && echo "  Running function: $func"

    "$func" "$@"
}

#######################################
# Run hooks from JSON config
# Arguments: hook_point, [args...]
#######################################
_hook_run_json_hooks() {
    local point="$1"
    shift
    local args=("$@")

    [[ -f "$HOOKS_CONFIG" ]] || return 0

    local hooks_json
    hooks_json=$(jq -r ".hooks.\"$point\" // []" "$HOOKS_CONFIG" 2>/dev/null)
    [[ "$hooks_json" == "[]" ]] && return 0

    local count=$(echo "$hooks_json" | jq 'length')
    local i=0
    while (( i < count )); do
        local enabled=$(echo "$hooks_json" | jq -r ".[$i].enabled // true")
        [[ "$enabled" != "true" ]] && { ((i++)); continue; }

        local name=$(echo "$hooks_json" | jq -r ".[$i].name // \"hook-$i\"")
        local fail_ok=$(echo "$hooks_json" | jq -r ".[$i].fail_ok // false")

        # Execute command, script, or function
        local cmd=$(echo "$hooks_json" | jq -r ".[$i].command // empty")
        local script=$(echo "$hooks_json" | jq -r ".[$i].script // empty")
        local func=$(echo "$hooks_json" | jq -r ".[$i].function // empty")

        local result=0
        if [[ -n "$cmd" ]]; then
            [[ "$HOOKS_VERBOSE" == "true" ]] && echo "  Running command ($name): $cmd"
            eval "$cmd" || result=$?
        elif [[ -n "$script" ]]; then
            script="${script/#\~/$HOME}"
            [[ -x "$script" ]] && _hook_exec_script "$script" "${args[@]}" || result=$?
        elif [[ -n "$func" ]]; then
            type "$func" &>/dev/null && _hook_exec_func "$func" "${args[@]}" || result=$?
        fi

        if (( result != 0 )) && [[ "$fail_ok" != "true" ]]; then
            echo "Hook failed: $name" >&2
            [[ "$HOOKS_FAIL_FAST" == "true" ]] && return 1
        fi

        ((i++))
    done
}

#######################################
# List all registered hooks
# Arguments: [hook_point] (optional, list all if omitted)
#######################################
hook_list() {
    local point="${1:-}"

    if [[ -n "$point" ]]; then
        echo "Hooks for: $point"
        echo ""

        # File-based
        if [[ -d "${HOOKS_DIR}/${point}" ]]; then
            echo "  File-based:"
            for script in "${HOOKS_DIR}/${point}"/*.{sh,zsh}(N); do
                echo "    - $(basename "$script")"
            done
        fi

        # Registered functions
        local funcs="${HOOKS[$point]:-}"
        if [[ -n "$funcs" ]]; then
            echo "  Functions:"
            for func in ${(s: :)funcs}; do
                echo "    - $func"
            done
        fi

        # JSON
        if [[ -f "$HOOKS_CONFIG" ]]; then
            local json_hooks=$(jq -r ".hooks.\"$point\"[]?.name // empty" "$HOOKS_CONFIG" 2>/dev/null)
            if [[ -n "$json_hooks" ]]; then
                echo "  JSON config:"
                echo "$json_hooks" | while read -r name; do
                    echo "    - $name"
                done
            fi
        fi
    else
        echo "All hook points:"
        echo ""
        for p in "${HOOK_POINTS[@]}"; do
            local count=0
            [[ -d "${HOOKS_DIR}/${p}" ]] && count=$((count + $(ls "${HOOKS_DIR}/${p}"/*.{sh,zsh} 2>/dev/null | wc -l)))
            [[ -n "${HOOKS[$p]:-}" ]] && count=$((count + $(echo "${HOOKS[$p]}" | wc -w)))
            printf "  %-20s %d hook(s)\n" "$p" "$count"
        done
    fi
}

#######################################
# Initialize hooks from config
# Called during shell/script init
#######################################
hook_init() {
    # Load settings from JSON config
    if [[ -f "$HOOKS_CONFIG" ]]; then
        HOOKS_FAIL_FAST=$(jq -r '.settings.fail_fast // false' "$HOOKS_CONFIG")
        HOOKS_VERBOSE=$(jq -r '.settings.verbose // false' "$HOOKS_CONFIG")
        HOOKS_TIMEOUT=$(jq -r '.settings.timeout // 30' "$HOOKS_CONFIG")
    fi
}
```

---

## CLI Command (`bin/dotfiles-hook`)

```bash
#!/usr/bin/env bash
# bin/dotfiles-hook - Hook management CLI
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/_logging.sh"
source "${SCRIPT_DIR}/../lib/_hooks.sh"

usage() {
    cat <<EOF
Usage: dotfiles hook <command> [args]

Commands:
  list [point]            List hooks (all or for specific point)
  run <point> [args]      Manually run hooks for a point
  add <point> <script>    Add a hook script
  remove <point> <name>   Remove a hook
  points                  List all available hook points
  test <point>            Test hooks for a point (dry run)

Options:
  --verbose               Show detailed output
  -h, --help              Show this help

Hook Points:
  pre_install, post_install, pre_bootstrap, post_bootstrap,
  pre_vault_pull, post_vault_pull, pre_vault_push, post_vault_push,
  pre_doctor, post_doctor, doctor_check,
  shell_init, shell_exit, directory_change,
  pre_setup_phase, post_setup_phase, setup_complete

Examples:
  dotfiles hook list
  dotfiles hook list post_vault_pull
  dotfiles hook run post_vault_pull
  dotfiles hook add post_vault_pull ~/scripts/my-hook.sh
EOF
}

cmd_list() {
    hook_list "${1:-}"
}

cmd_run() {
    local point="${1:?Hook point required}"
    shift
    hook_run "$point" "$@"
}

cmd_add() {
    local point="${1:?Hook point required}"
    local script="${2:?Script path required}"

    if ! hook_valid_point "$point"; then
        fail "Invalid hook point: $point"
        exit 1
    fi

    if [[ ! -f "$script" ]]; then
        fail "Script not found: $script"
        exit 1
    fi

    local hooks_dir="$HOME/.config/dotfiles/hooks/$point"
    mkdir -p "$hooks_dir"

    local basename=$(basename "$script")
    cp "$script" "$hooks_dir/$basename"
    chmod +x "$hooks_dir/$basename"

    pass "Added hook: $hooks_dir/$basename"
}

cmd_remove() {
    local point="${1:?Hook point required}"
    local name="${2:?Hook name required}"

    local hook_path="$HOME/.config/dotfiles/hooks/$point/$name"
    if [[ -f "$hook_path" ]]; then
        rm "$hook_path"
        pass "Removed hook: $hook_path"
    else
        fail "Hook not found: $hook_path"
        exit 1
    fi
}

cmd_points() {
    echo "Available hook points:"
    echo ""
    for point in "${HOOK_POINTS[@]}"; do
        echo "  $point"
    done
}

cmd_test() {
    local point="${1:?Hook point required}"
    HOOKS_VERBOSE=true
    echo "Testing hooks for: $point"
    echo "---"
    hook_run "$point" --dry-run
}

# Main
case "${1:-}" in
    list)       shift; cmd_list "$@" ;;
    run)        shift; cmd_run "$@" ;;
    add)        shift; cmd_add "$@" ;;
    remove)     shift; cmd_remove "$@" ;;
    points)     cmd_points ;;
    test)       shift; cmd_test "$@" ;;
    --verbose)  HOOKS_VERBOSE=true; shift; "$0" "$@" ;;
    -h|--help)  usage ;;
    *)          usage; exit 1 ;;
esac
```

---

## Integration Points

### In bootstrap scripts

```bash
# bootstrap-mac.sh
source "$DOTFILES_DIR/lib/_hooks.sh"

hook_run "pre_bootstrap"

# ... bootstrap logic ...

hook_run "post_bootstrap"
```

### In vault scripts

```bash
# vault/restore-secrets.sh
source "$DOTFILES_DIR/lib/_hooks.sh"

hook_run "pre_vault_pull"

# ... restore logic ...

hook_run "post_vault_pull"
```

### In shell init

```zsh
# zsh/zsh.d/99-hooks.zsh
source "${DOTFILES_DIR}/lib/_hooks.sh"
hook_init

# Run shell_init hooks
hook_run "shell_init"

# Setup directory change hook
chpwd_functions+=(_dotfiles_directory_change_hook)
_dotfiles_directory_change_hook() {
    hook_run "directory_change" "$PWD"
}

# Setup exit hook
zshexit() {
    hook_run "shell_exit"
}
```

---

## Example Hooks

### `post_vault_pull/10-ssh-add.sh`

```bash
#!/usr/bin/env bash
# Add SSH keys to agent after vault pull

for key in ~/.ssh/id_ed25519 ~/.ssh/id_rsa; do
    [[ -f "$key" ]] && ssh-add "$key" 2>/dev/null
done
```

### `shell_init/10-project-env.zsh`

```zsh
#!/usr/bin/env zsh
# Auto-load project environment

load_project_env() {
    # Load .env if present
    [[ -f .env ]] && source .env

    # Load direnv
    (( $+commands[direnv] )) && eval "$(direnv hook zsh)"

    # Auto-activate Python venv
    [[ -d .venv ]] && source .venv/bin/activate
}
```

### `doctor_check/10-custom.sh`

```bash
#!/usr/bin/env bash
# Custom health checks

# Check VPN connection
if ! ping -c1 -W1 internal.company.com &>/dev/null; then
    echo "WARN: VPN not connected"
fi

# Check license file
if [[ ! -f ~/.license ]]; then
    echo "WARN: License file missing"
fi
```

---

## Testing

```bash
# Test hook registration
test/hooks/test_registration.bats

# Test hook execution
test/hooks/test_execution.bats

# Test file-based hooks
test/hooks/test_file_hooks.bats

# Test JSON config
test/hooks/test_json_config.bats
```

---

## Security Considerations

1. **No remote execution** - Only local scripts/functions
2. **Explicit enable** - Hooks must be explicitly placed/registered
3. **Timeout protection** - Prevent runaway hooks
4. **No privilege escalation** - Hooks run as current user

---

## Lessons Learned (from v2.1-v2.3 implementations)

Based on implementing CLI Feature Awareness, Configuration Layers, and Feature Registry:

### 1. Environment Variable Overrides
Add env var control for scripting/CI:
```bash
# In lib/_hooks.sh
DOTFILES_HOOKS_DISABLED=true  # Skip all hook execution
DOTFILES_HOOKS_VERBOSE=true   # Show detailed execution log
DOTFILES_HOOKS_TIMEOUT=60     # Override timeout

# Check at start of hook_run()
if [[ "${DOTFILES_HOOKS_DISABLED:-}" == "true" ]]; then
    return 0
fi
```

### 2. Meta-Feature Pattern
Register hook system itself as a feature with parent feature awareness:
```zsh
# In FEATURE_REGISTRY
["hooks"]="true|Lifecycle hook system|optional|"

# Vault hooks only run if both enabled
hook_run() {
    local point="$1"

    # Meta-feature: is hook system enabled?
    feature_enabled "hooks" || return 0

    # Parent feature check (e.g., vault hooks need vault)
    if [[ "$point" == *vault* ]]; then
        feature_enabled "vault" || return 0
    fi

    # ... run hooks
}
```

### 3. `--force` Bypass Pattern
Allow skipping hooks in emergencies:
```bash
# In vault scripts
if [[ "${1:-}" != "--no-hooks" ]]; then
    hook_run "pre_vault_pull"
fi

# Usage: dotfiles vault pull --no-hooks
```

### 4. Helpful Error Messages with Enable Hints
When hooks fail, show context:
```bash
hook_run() {
    # ...
    if (( result != 0 )); then
        echo "Hook failed: $name" >&2
        echo "  Disable with: dotfiles features disable hooks" >&2
        echo "  Or skip with: --no-hooks flag" >&2
    fi
}
```

### 5. jq Boolean Handling
Don't use `// empty` for booleans - it treats `false` as empty:
```bash
# WRONG
enabled=$(jq -r '.enabled // empty' hooks.json)

# CORRECT
enabled=$(jq -r '.enabled' hooks.json)
[[ "$enabled" != "null" ]] || enabled="true"
```

### 6. Layered Configuration Support
Allow hooks config from multiple sources (like config_layers):
```bash
# Priority: env > project > user
# Project hooks in .dotfiles.json
# User hooks in ~/.config/dotfiles/hooks.json

_hooks_get_config() {
    local project_hooks=""
    [[ -f .dotfiles.json ]] && project_hooks=$(jq -r '.hooks // empty' .dotfiles.json)

    # Merge project + user hooks
}
```

### 7. Testing Pattern with zsh
All hook tests need zsh:
```bash
@test "hook_run executes hooks in order" {
  run zsh -c "
    source '$HOOKS_SH'
    hook_register 'test_point' 'test_func'
    test_func() { echo 'executed'; }
    hook_run 'test_point'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"executed"* ]]
}
```

### 8. CLI Integration Pattern
```zsh
# In lib/_cli_features.sh
["hook"]="hooks"
["hooks"]="hooks"

# In CLI_COMMAND_HELP
["hooks"]="hooks|Hook Management|Lifecycle hook configuration|
  hooks list       List all hooks
  hooks run        Manually trigger hooks
  hooks add        Add a hook script
  ..."

# In CLI_SUBCOMMAND_FEATURES
["hooks:list"]="hooks"
["hooks:run"]="hooks"
["hooks:add"]="hooks"
```

### 9. Integration with Config Layers
Hook settings should respect config layer precedence:
```bash
# Allow project-level hook overrides
# .dotfiles.json in repo can add project-specific hooks
{
  "hooks": {
    "post_install": [
      {"name": "project-setup", "script": "./scripts/setup.sh"}
    ]
  }
}
```

---

## Existing Functionality to Consolidate

The following existing functionality in the codebase would be brought under hook system administration:

### Vault Hooks (Already Implemented Inline)

| Current Location | Function | Hook Point |
|-----------------|----------|------------|
| `vault/_common.sh:546` | `check_pre_restore_drift()` | `pre_vault_pull` |
| `vault/restore.sh:155-193` | Auto-backup before restore | `pre_vault_pull` |
| `vault/restore.sh:199-212` | Run restore scripts in order | `vault_pull` |
| `vault/restore.sh:219-227` | Track timestamp, save drift state | `post_vault_pull` |
| `vault/restore-ssh.sh:79,117` | `chmod 600` on keys/config | `post_vault_pull` |
| `vault/restore-aws.sh:55` | `chmod 600` on credentials | `post_vault_pull` |
| `vault/restore-env.sh:68` | `chmod 600` on .env file | `post_vault_pull` |

**Migration benefit:** Unified permission-setting hook instead of scattered `chmod` calls.

### Bootstrap Hooks (Hardcoded in Scripts)

| Current Location | Function | Hook Point |
|-----------------|----------|------------|
| `bootstrap/bootstrap-mac.sh:33-38` | Xcode CLI tools check | `pre_bootstrap` |
| `bootstrap/bootstrap-mac.sh:43-64` | Homebrew installation | `bootstrap_packages` |
| `bootstrap/bootstrap-mac.sh:69` | `run_brew_bundle` | `bootstrap_packages` |
| `bootstrap/bootstrap-mac.sh:74-79` | Workspace layout setup | `post_bootstrap` |
| `bootstrap/_common.sh:237` | Suggest `template init` | `post_bootstrap` |

**Migration benefit:** Users can add custom post-bootstrap hooks for extra package installation.

### Setup Wizard Hooks

| Current Location | Function | Hook Point |
|-----------------|----------|------------|
| `bin/dotfiles-setup:328` | Create symlinks | `setup_symlinks` |
| `bin/dotfiles-setup:662` | `chmod 600` vault session | `post_setup_vault` |
| `bin/dotfiles-setup:947` | Template init | `post_setup` |

**Migration benefit:** Project-specific setup hooks via `.dotfiles.json`.

### Template Hooks

| Current Location | Function | Hook Point |
|-----------------|----------|------------|
| `lib/_templates.sh` | Render templates | `template_render` |
| `bin/dotfiles-template:link` | Create symlinks | `post_template_render` |

**Migration benefit:** Custom post-render hooks for file permissions, notifications.

### Doctor/Health Hooks

| Current Location | Function | Hook Point |
|-----------------|----------|------------|
| `bin/dotfiles-doctor:302,334` | Auto-fix permissions | `doctor_fix` |

**Migration benefit:** Extensible auto-fix system with user-defined repairs.

### Claude Code Hooks (Already Hook-Based)

These are already implemented as Claude Code native hooks and serve as the reference implementation:

| Current Location | Function | Hook Point |
|-----------------|----------|------------|
| `claude/hooks/block-dangerous-git.sh` | Block dangerous git commands | `PreToolUse` |
| `claude/hooks/git-sync-check.sh` | Check git sync status | `SessionStart` |

**Pattern to follow:** These scripts demonstrate the hook interface (stdin JSON, exit codes).

### Proposed Hook Consolidation

```zsh
# Instead of scattered chmod calls in restore scripts:
# vault/restore-ssh.sh:79
chmod 600 "$priv_path"

# Becomes a hook in ~/.config/dotfiles/hooks.json:
{
  "post_vault_pull": [
    {
      "name": "fix-ssh-permissions",
      "type": "function",
      "function": "chmod 600 ~/.ssh/id_*"
    }
  ]
}

# Or register programmatically:
hook_register "post_vault_pull" "fix_ssh_permissions"
fix_ssh_permissions() {
    chmod 600 ~/.ssh/id_* 2>/dev/null || true
    chmod 644 ~/.ssh/*.pub 2>/dev/null || true
}
```

### Migration Priority

| Priority | Hook Point | Current Code | Benefit |
|----------|-----------|--------------|---------|
| **High** | `post_vault_pull` | Scattered chmod, ssh-add | Unified permissions + key loading |
| **High** | `pre_vault_pull` | `check_pre_restore_drift()` | Configurable safety checks |
| **Medium** | `post_bootstrap` | Template suggestions | User-defined post-install |
| **Medium** | `doctor_fix` | Hardcoded auto-repairs | Extensible repair system |
| **Low** | `post_template_render` | Link creation | Custom linking logic |

### Implementation Notes

1. **Backward compatibility:** Keep existing inline functions, have hook system call them
2. **Default hooks:** Register built-in functions as default hooks (users can override)
3. **Feature-gated:** Only run vault hooks if `vault` feature enabled
4. **Error isolation:** Hook failures don't break core operations (log and continue)

---

*Created: 2025-12-05*
*Updated: 2025-12-05 (Added Lessons Learned, Existing Functionality)*
