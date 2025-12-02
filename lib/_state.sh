#!/usr/bin/env zsh
# ============================================================
# FILE: lib/_state.sh
# State management for dotfiles setup progress
# Source this file: source "$DOTFILES_DIR/lib/_state.sh"
# ============================================================

# Prevent multiple sourcing
[[ -n "${_STATE_LOADED:-}" ]] && return 0
_STATE_LOADED=1

# ============================================================
# Configuration
# ============================================================

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
STATE_FILE="$STATE_DIR/state.ini"
CONFIG_FILE="$STATE_DIR/config.ini"

# ============================================================
# Initialization
# ============================================================

# Initialize state directory and files
# Usage: state_init
state_init() {
    if [[ ! -d "$STATE_DIR" ]]; then
        mkdir -p "$STATE_DIR"
        chmod 700 "$STATE_DIR"
    fi

    # Create state file if missing
    if [[ ! -f "$STATE_FILE" ]]; then
        cat > "$STATE_FILE" << 'EOF'
# Dotfiles Setup State
# Auto-managed by dotfiles setup. Do not edit manually.

[install]
completed=false

[symlinks]
completed=false

[packages]
completed=false

[vault]
completed=false

[secrets]
completed=false

[claude]
completed=false

[verification]
last_check=
status=unknown
EOF
        chmod 600 "$STATE_FILE"
    fi

    # Create config file if missing
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Dotfiles Configuration
# Edit manually or via 'dotfiles setup'

[vault]
backend=

[features]
workspace_symlink=true
claude_integration=true

[machine]
name=
type=
EOF
        chmod 600 "$CONFIG_FILE"
    fi
}

# ============================================================
# INI File Parsing (Pure Shell)
# ============================================================

# Read a value from an INI file
# Usage: value=$(ini_get "file.ini" "section" "key")
ini_get() {
    local file="$1"
    local section="$2"
    local key="$3"
    local default="${4:-}"

    [[ ! -f "$file" ]] && echo "$default" && return 1

    local in_section=false
    local value=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Check for section header [section]
        if [[ "$line" =~ '^\[([^]]+)\]$' ]]; then
            if [[ "${match[1]}" == "$section" ]]; then
                in_section=true
            else
                in_section=false
            fi
            continue
        fi

        # If in target section, look for key=value
        if $in_section && [[ "$line" =~ '^([^=]+)=(.*)$' ]]; then
            local k="${match[1]}"
            local v="${match[2]}"
            # Trim whitespace
            k="${k## }"; k="${k%% }"
            v="${v## }"; v="${v%% }"
            if [[ "$k" == "$key" ]]; then
                value="$v"
                break
            fi
        fi
    done < "$file"

    if [[ -n "$value" ]]; then
        echo "$value"
        return 0
    else
        echo "$default"
        return 1
    fi
}

# Write a value to an INI file
# Usage: ini_set "file.ini" "section" "key" "value"
ini_set() {
    local file="$1"
    local section="$2"
    local key="$3"
    local value="$4"

    # Create file with section if it doesn't exist
    if [[ ! -f "$file" ]]; then
        echo "[$section]" > "$file"
        echo "$key=$value" >> "$file"
        return 0
    fi

    local temp_file="${file}.tmp.$$"
    local in_section=false
    local key_found=false
    local section_found=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check for section header [section]
        if [[ "$line" =~ '^\[([^]]+)\]$' ]]; then
            # If we were in target section and didn't find key, add it
            if $in_section && ! $key_found; then
                echo "$key=$value" >> "$temp_file"
                key_found=true
            fi

            if [[ "${match[1]}" == "$section" ]]; then
                in_section=true
                section_found=true
            else
                in_section=false
            fi
            echo "$line" >> "$temp_file"
            continue
        fi

        # If in target section and this is the key, update it
        if $in_section && [[ "$line" =~ '^([^=]+)=(.*)$' ]]; then
            local k="${match[1]}"
            k="${k## }"; k="${k%% }"
            if [[ "$k" == "$key" ]]; then
                echo "$key=$value" >> "$temp_file"
                key_found=true
                continue
            fi
        fi

        echo "$line" >> "$temp_file"
    done < "$file"

    # If section not found, add it
    if ! $section_found; then
        echo "" >> "$temp_file"
        echo "[$section]" >> "$temp_file"
        echo "$key=$value" >> "$temp_file"
    # If in section at EOF and key not found, add it
    elif $in_section && ! $key_found; then
        echo "$key=$value" >> "$temp_file"
    fi

    mv "$temp_file" "$file"
}

# ============================================================
# State API
# ============================================================

# Check if a setup phase is completed
# Usage: if state_completed "symlinks"; then ...
state_completed() {
    local phase="$1"
    state_init
    local value=$(ini_get "$STATE_FILE" "$phase" "completed" "false")
    [[ "$value" == "true" ]]
}

# Mark a setup phase as completed
# Usage: state_complete "symlinks"
state_complete() {
    local phase="$1"
    state_init
    ini_set "$STATE_FILE" "$phase" "completed" "true"
    ini_set "$STATE_FILE" "$phase" "completed_at" "$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')"
}

# Mark a setup phase as incomplete
# Usage: state_reset "symlinks"
state_reset() {
    local phase="$1"
    state_init
    ini_set "$STATE_FILE" "$phase" "completed" "false"
    ini_set "$STATE_FILE" "$phase" "completed_at" ""
}

# Get all phase statuses as a summary
# Usage: state_summary
state_summary() {
    state_init
    local phases=("install" "symlinks" "packages" "vault" "secrets" "claude")

    for phase in "${phases[@]}"; do
        local completed=$(ini_get "$STATE_FILE" "$phase" "completed" "false")
        local at=$(ini_get "$STATE_FILE" "$phase" "completed_at" "")
        if [[ "$completed" == "true" ]]; then
            echo "$phase:completed:$at"
        else
            echo "$phase:pending:"
        fi
    done
}

# Check if any setup is needed
# Usage: if state_needs_setup; then ...
state_needs_setup() {
    state_init
    local phases=("symlinks" "vault" "secrets")

    for phase in "${phases[@]}"; do
        if ! state_completed "$phase"; then
            return 0  # Needs setup
        fi
    done
    return 1  # Fully configured
}

# Get the first incomplete phase
# Usage: next=$(state_next_phase)
state_next_phase() {
    state_init
    local phases=("symlinks" "packages" "vault" "secrets" "claude")

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
# State Inference (for existing installations)
# ============================================================

# Infer state from filesystem for existing users
# Usage: state_infer
state_infer() {
    state_init

    local dotfiles_dir="${DOTFILES_DIR:-$HOME/workspace/dotfiles}"

    # Check symlinks
    if [[ -L "$HOME/.zshrc" && -L "$HOME/.p10k.zsh" ]]; then
        state_complete "symlinks"
    fi

    # Check if install happened (repo exists)
    if [[ -d "$dotfiles_dir/.git" ]]; then
        state_complete "install"
    fi

    # Check packages (Brewfile.lock.json exists)
    if [[ -f "$dotfiles_dir/Brewfile.lock.json" ]]; then
        state_complete "packages"
    fi

    # Check vault (only if explicitly configured in config file or session exists)
    local configured_backend=$(config_get "vault" "backend" "")
    if [[ -n "$configured_backend" && "$configured_backend" != "none" ]]; then
        state_complete "vault"
    elif [[ -f "$dotfiles_dir/vault/.vault-session" ]]; then
        state_complete "vault"
        # Migrate env var to config if set explicitly
        if [[ -n "${DOTFILES_VAULT_BACKEND:-}" && "${DOTFILES_VAULT_BACKEND}" != "bitwarden" ]]; then
            config_set "vault" "backend" "$DOTFILES_VAULT_BACKEND"
        fi
    fi

    # Check secrets (SSH keys exist)
    if [[ -f "$HOME/.ssh/id_ed25519_enterprise_ghub" ]] || [[ -f "$HOME/.ssh/id_ed25519_blackwell" ]]; then
        state_complete "secrets"
    fi

    # Check Claude (.claude directory linked)
    if [[ -L "$HOME/.claude" ]]; then
        state_complete "claude"
    fi
}

# ============================================================
# Config API (User Preferences)
# ============================================================

# Get a config value
# Usage: value=$(config_get "vault" "backend")
config_get() {
    local section="$1"
    local key="$2"
    local default="${3:-}"
    state_init
    ini_get "$CONFIG_FILE" "$section" "$key" "$default"
}

# Set a config value
# Usage: config_set "vault" "backend" "1password"
config_set() {
    local section="$1"
    local key="$2"
    local value="$3"
    state_init
    ini_set "$CONFIG_FILE" "$section" "$key" "$value"
}

# Check if a feature is enabled
# Usage: if config_feature_enabled "workspace_symlink"; then ...
config_feature_enabled() {
    local feature="$1"
    local value=$(config_get "features" "$feature" "true")
    [[ "$value" == "true" ]]
}

# ============================================================
# Display Helpers
# ============================================================

# Print setup status in a formatted way
# Usage: state_print_status
state_print_status() {
    state_init

    local phases=("symlinks" "packages" "vault" "secrets" "claude")
    local labels=("Symlinks" "Packages" "Vault" "Secrets" "Claude")

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

# Get vault backend (from config, env, or default)
# Usage: backend=$(state_get_vault_backend)
state_get_vault_backend() {
    # Priority: config file > env var > default
    local from_config=$(config_get "vault" "backend" "")

    if [[ -n "$from_config" ]]; then
        echo "$from_config"
    elif [[ -n "${DOTFILES_VAULT_BACKEND:-}" ]]; then
        echo "$DOTFILES_VAULT_BACKEND"
    else
        echo "bitwarden"
    fi
}
