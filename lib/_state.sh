#!/usr/bin/env zsh
# ============================================================
# FILE: lib/_state.sh
# State management for dotfiles setup progress
# v3.0: Uses JSON config backend
# Source this file: source "$DOTFILES_DIR/lib/_state.sh"
# ============================================================

# Prevent multiple sourcing
[[ -n "${_STATE_LOADED:-}" ]] && return 0
_STATE_LOADED=1

# ============================================================
# Load JSON Config System
# ============================================================

# Get script directory
STATE_SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
DOTFILES_DIR="$(cd "$STATE_SCRIPT_DIR/.." && pwd)"

# Source JSON config library
source "$DOTFILES_DIR/lib/_config.sh"

# ============================================================
# Configuration
# ============================================================

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
# Note: CONFIG_FILE is set in _config.sh (config.json)
# Old state.ini/config.ini files are renamed to *.v2-backup during migration

# ============================================================
# Initialization
# ============================================================

# Initialize state - now uses JSON config
state_init() {
    # Create config directory if needed
    mkdir -p "$STATE_DIR" 2>/dev/null
    chmod 700 "$STATE_DIR" 2>/dev/null

    # Initialize JSON config (will create if missing)
    init_config
}

# ============================================================
# State API (v3.0: Uses JSON config)
# ============================================================

# Check if a setup phase is completed
# Usage: if state_completed "symlinks"; then ...
state_completed() {
    local phase="$1"
    state_init

    # Check if phase is in setup.completed array
    local completed_phases
    completed_phases=$(config_get_array "setup.completed" 2>/dev/null)

    if [[ -z "$completed_phases" ]]; then
        return 1
    fi

    echo "$completed_phases" | grep -q "^${phase}$"
}

# Mark a setup phase as completed
# Usage: state_complete "symlinks"
state_complete() {
    local phase="$1"
    state_init

    # Add to setup.completed array (config_array_add avoids duplicates)
    config_array_add "setup.completed" "$phase" 2>/dev/null
}

# Mark a setup phase as incomplete
# Usage: state_reset "symlinks"
state_reset() {
    local phase="$1"
    state_init

    # Remove from setup.completed array
    config_array_remove "setup.completed" "$phase" 2>/dev/null
}

# Get all phase statuses as a summary
# Usage: state_summary
state_summary() {
    state_init
    local phases=("install" "symlinks" "packages" "vault" "secrets" "claude" "template")

    for phase in "${phases[@]}"; do
        if state_completed "$phase"; then
            echo "$phase:completed"
        else
            echo "$phase:pending"
        fi
    done
}

# Check if any setup is needed
# Usage: if state_needs_setup; then ...
state_needs_setup() {
    state_init
    local phases=("workspace" "symlinks" "vault" "secrets")

    for phase in "${phases[@]}"; do
        if ! state_completed "$phase"; then
            return 0  # Needs setup
        fi
    done
    return 1  # Fully configured
}

# Infer state from existing system configuration
# This auto-marks phases as complete if they're already done
# Usage: state_infer
state_infer() {
    state_init

    # Infer workspace: if config exists or /workspace symlink exists
    if ! state_completed "workspace"; then
        local ws_target
        ws_target=$(config_get "paths.workspace_target" "")
        if [[ -n "$ws_target" ]] || [[ -L "/workspace" ]]; then
            state_complete "workspace"
        fi
    fi

    # Infer symlinks: if ~/.zshrc points to our dotfiles
    if ! state_completed "symlinks"; then
        if [[ -L "$HOME/.zshrc" ]]; then
            local target
            target=$(readlink "$HOME/.zshrc" 2>/dev/null || true)
            if [[ "$target" == *dotfiles/zsh/zshrc* ]]; then
                state_complete "symlinks"
            fi
        fi
    fi

    # Infer packages: if brew is available and a tier is set
    if ! state_completed "packages"; then
        local tier
        tier=$(config_get "packages.tier" "")
        if [[ -n "$tier" ]] && command -v brew &>/dev/null; then
            state_complete "packages"
        fi
    fi

    # Infer vault: if a backend is configured
    if ! state_completed "vault"; then
        local backend
        backend=$(config_get "vault.backend" "")
        if [[ -n "$backend" ]]; then
            state_complete "vault"
        fi
    fi

    # Infer secrets: if vault is configured and we've run through secrets
    # This is harder to infer, so we leave it unless explicitly marked

    # Infer claude: if dotclaude is installed or SKIP_CLAUDE is set
    if ! state_completed "claude"; then
        if command -v dotclaude &>/dev/null || ! command -v claude &>/dev/null; then
            state_complete "claude"
        fi
    fi

    # Infer template: if _variables.local.sh exists
    if ! state_completed "template"; then
        if [[ -f "${DOTFILES_DIR:-$HOME/workspace/dotfiles}/templates/_variables.local.sh" ]]; then
            state_complete "template"
        fi
    fi
}

# Get the first incomplete phase
# Usage: next=$(state_next_phase)
state_next_phase() {
    state_init
    local phases=("workspace" "symlinks" "packages" "vault" "secrets" "claude" "template")

    for phase in "${phases[@]}"; do
        if ! state_completed "$phase"; then
            echo "$phase"
            return 0
        fi
    done
    echo ""
    return 1
}

# ============================================================
# Config API (v3.0: Delegates to JSON config in _config.sh)
# Note: config_get and config_set are provided by _config.sh
# Source _config.sh before _state.sh to use these functions
# ============================================================

# Check if a feature is enabled
# Usage: if config_feature_enabled "workspace_symlink"; then ...
# Note: Delegates to feature_enabled() from _features.sh if available
config_feature_enabled() {
    local feature="$1"

    # Use feature registry if available (preferred)
    if type feature_enabled &>/dev/null; then
        feature_enabled "$feature"
        return $?
    fi

    # Fallback: check config file directly
    local value
    value="$(config_get "features.$feature" "true")"
    [[ "$value" == "true" ]]
}

# ============================================================
# Display Helpers
# ============================================================

# Print setup status in a formatted way
# Usage: state_print_status
state_print_status() {
    state_init

    local phases=("symlinks" "packages" "vault" "secrets" "claude" "template")
    local labels=("Symlinks" "Packages" "Vault" "Secrets" "Claude" "Templates")

    echo "Setup Status:"
    echo "─────────────"

    for i in {1..${#phases[@]}}; do
        local phase="${phases[$i]}"
        local label="${labels[$i]}"

        if state_completed "$phase"; then
            echo "  [✓] $label"
        else
            echo "  [ ] $label"
        fi
    done
}

# Get vault backend (from config)
# Usage: backend=$(state_get_vault_backend)
state_get_vault_backend() {
    state_init

    # Get from JSON config
    local backend
    backend=$(config_get "vault.backend" "" 2>/dev/null)

    # Fallback to env var if not in config
    if [[ -z "$backend" ]]; then
        backend="${DOTFILES_VAULT_BACKEND:-bitwarden}"
    fi

    echo "$backend"
}

# ============================================================
# Legacy INI Support (for migration)
# ============================================================

# These are kept for backwards compatibility during migration
# but now delegate to JSON config

# Read from legacy INI (for migration only)
ini_get() {
    local file="$1"
    local section="$2"
    local key="$3"
    local default="${4:-}"

    # Use helper from _config.sh if available
    if declare -f get_ini_value >/dev/null 2>&1; then
        get_ini_value "$section" "$key" "$default"
    else
        echo "$default"
    fi
}
