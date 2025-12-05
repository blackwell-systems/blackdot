#!/usr/bin/env zsh
# Configuration Layers - Hierarchical config resolution
# Provides layered config: env > project > machine > user > defaults
#
# IMPORTANT: This is ADDITIVE to lib/_config.sh
# State management (lib/_state.sh) continues using direct config access.
# Only features and user preferences use layered resolution.

set -euo pipefail

# ============================================================
# Layer File Locations
# ============================================================

CONFIG_LAYER_PROJECT=".dotfiles.json"
CONFIG_LAYER_MACHINE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/machine.json"
CONFIG_LAYER_USER="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/config.json"

# ============================================================
# Layered Config Read
# ============================================================

# Get config value with layer resolution
# Priority: env > project > machine > user > default
# Usage: config_get_layered "vault.backend" "bitwarden"
config_get_layered() {
    local key="$1"
    local default="${2:-}"

    local value=""

    # Layer 1: Environment variable
    # Convert key to env var: vault.backend -> DOTFILES_VAULT_BACKEND
    local env_key="DOTFILES_${key//\./_}"
    env_key="${env_key:u}"  # ZSH uppercase
    if [[ -n "${(P)env_key:-}" ]]; then
        echo "${(P)env_key}"
        return 0
    fi

    # Layer 2: Project config (walk up directory tree)
    local project_config
    project_config=$(_find_project_config) || true
    if [[ -n "$project_config" && -f "$project_config" ]]; then
        value=$(_json_get "$project_config" "$key")
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi

    # Layer 3: Machine config
    if [[ -f "$CONFIG_LAYER_MACHINE" ]]; then
        value=$(_json_get "$CONFIG_LAYER_MACHINE" "$key")
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi

    # Layer 4: User config
    if [[ -f "$CONFIG_LAYER_USER" ]]; then
        value=$(_json_get "$CONFIG_LAYER_USER" "$key")
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi

    # Layer 5: Default
    echo "$default"
}

# Get boolean with layer resolution
# Returns: 0 for true, 1 for false
config_get_layered_bool() {
    local key="$1"
    local default="${2:-false}"

    local value
    value=$(config_get_layered "$key" "$default")

    if [[ "$value" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Get value with source information (for debugging)
# Returns JSON: {"value": "...", "source": "env|project|machine|user|default", "file": "..."}
config_get_with_source() {
    local key="$1"
    local default="${2:-}"

    local value=""
    local source="default"
    local file=""

    # Layer 1: Environment
    local env_key="DOTFILES_${key//\./_}"
    env_key="${env_key:u}"
    if [[ -n "${(P)env_key:-}" ]]; then
        value="${(P)env_key}"
        source="env"
        file="$env_key"
    fi

    # Layer 2: Project
    if [[ -z "$value" ]]; then
        local project_config
        project_config=$(_find_project_config) || true
        if [[ -n "$project_config" && -f "$project_config" ]]; then
            local proj_val
            proj_val=$(_json_get "$project_config" "$key")
            if [[ -n "$proj_val" ]]; then
                value="$proj_val"
                source="project"
                file="$project_config"
            fi
        fi
    fi

    # Layer 3: Machine
    if [[ -z "$value" && -f "$CONFIG_LAYER_MACHINE" ]]; then
        local machine_val
        machine_val=$(_json_get "$CONFIG_LAYER_MACHINE" "$key")
        if [[ -n "$machine_val" ]]; then
            value="$machine_val"
            source="machine"
            file="$CONFIG_LAYER_MACHINE"
        fi
    fi

    # Layer 4: User
    if [[ -z "$value" && -f "$CONFIG_LAYER_USER" ]]; then
        local user_val
        user_val=$(_json_get "$CONFIG_LAYER_USER" "$key")
        if [[ -n "$user_val" ]]; then
            value="$user_val"
            source="user"
            file="$CONFIG_LAYER_USER"
        fi
    fi

    # Layer 5: Default
    if [[ -z "$value" ]]; then
        value="$default"
    fi

    # Output JSON
    printf '{"key":"%s","value":"%s","source":"%s","file":"%s"}\n' \
        "$key" "$value" "$source" "$file"
}

# ============================================================
# Layered Config Write
# ============================================================

# Set config value in specified layer
# Usage: config_set_layered "user" "vault.backend" "1password"
# Layers: user, machine, project
config_set_layered() {
    local layer="$1"
    local key="$2"
    local value="$3"

    local config_file
    case "$layer" in
        user)
            config_file="$CONFIG_LAYER_USER"
            ;;
        machine)
            config_file="$CONFIG_LAYER_MACHINE"
            ;;
        project)
            config_file=$(_find_project_config) || true
            if [[ -z "$config_file" ]]; then
                config_file="$PWD/$CONFIG_LAYER_PROJECT"
            fi
            ;;
        *)
            echo "ERROR: Invalid layer '$layer'. Use: user, machine, project" >&2
            return 1
            ;;
    esac

    # Ensure directory exists
    local config_dir
    config_dir=$(dirname "$config_file")
    mkdir -p "$config_dir"

    # Create file if doesn't exist
    if [[ ! -f "$config_file" ]]; then
        echo '{"version": 1}' > "$config_file"
    fi

    # Determine if value is JSON or string
    # Check for JSON types: true, false, number, array, object
    local tmp_file="${config_file}.tmp"
    local is_json=0

    case "$value" in
        true|false)
            is_json=1
            ;;
        [0-9]*)
            # Check if it's a pure number
            if [[ "$value" =~ ^[0-9]+$ ]]; then
                is_json=1
            fi
            ;;
        \[*)
            # Starts with [ - likely array
            is_json=1
            ;;
        \{*)
            # Starts with { - likely object
            is_json=1
            ;;
    esac

    if [[ $is_json -eq 1 ]]; then
        # JSON value - use without quotes
        jq ".$key = $value" "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
    else
        # String value - use with quotes
        jq --arg val "$value" ".$key = \$val" "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
    fi
}

# ============================================================
# Layer Display Functions
# ============================================================

# Show all layers and their values for a key
config_show_layers() {
    local key="$1"

    echo "Configuration layers for: $key"
    echo ""

    # Environment
    local env_key="DOTFILES_${key//\./_}"
    env_key="${env_key:u}"
    local env_val="${(P)env_key:-}"
    printf "  %-12s %s\n" "env:" "${env_val:-(not set)}"

    # Project
    local project_config
    project_config=$(_find_project_config) || true
    local proj_val=""
    if [[ -n "$project_config" && -f "$project_config" ]]; then
        proj_val=$(_json_get "$project_config" "$key")
    fi
    printf "  %-12s %s\n" "project:" "${proj_val:-(not set)}"

    # Machine
    local machine_val=""
    if [[ -f "$CONFIG_LAYER_MACHINE" ]]; then
        machine_val=$(_json_get "$CONFIG_LAYER_MACHINE" "$key")
    fi
    printf "  %-12s %s\n" "machine:" "${machine_val:-(not set)}"

    # User
    local user_val=""
    if [[ -f "$CONFIG_LAYER_USER" ]]; then
        user_val=$(_json_get "$CONFIG_LAYER_USER" "$key")
    fi
    printf "  %-12s %s\n" "user:" "${user_val:-(not set)}"

    # Resolved
    echo ""
    local resolved
    resolved=$(config_get_layered "$key")
    printf "  %-12s %s\n" "=> resolved:" "${resolved:-(empty)}"
}

# Show merged config from all layers
config_show_merged() {
    local merged="{}"

    # Start with user config (lowest priority that's a file)
    if [[ -f "$CONFIG_LAYER_USER" ]]; then
        merged=$(jq -s '.[0] * .[1]' <(echo "$merged") "$CONFIG_LAYER_USER" 2>/dev/null || echo "$merged")
    fi

    # Merge machine config
    if [[ -f "$CONFIG_LAYER_MACHINE" ]]; then
        merged=$(jq -s '.[0] * .[1]' <(echo "$merged") "$CONFIG_LAYER_MACHINE" 2>/dev/null || echo "$merged")
    fi

    # Merge project config
    local project_config
    project_config=$(_find_project_config) || true
    if [[ -n "$project_config" && -f "$project_config" ]]; then
        merged=$(jq -s '.[0] * .[1]' <(echo "$merged") "$project_config" 2>/dev/null || echo "$merged")
    fi

    echo "$merged" | jq '.'
}

# ============================================================
# Layer Initialization
# ============================================================

# Initialize machine config
# Usage: config_init_machine "work-macbook"
config_init_machine() {
    local machine_id="${1:-$(hostname -s)}"

    if [[ -f "$CONFIG_LAYER_MACHINE" ]]; then
        echo "Machine config already exists: $CONFIG_LAYER_MACHINE" >&2
        return 1
    fi

    mkdir -p "$(dirname "$CONFIG_LAYER_MACHINE")"

    cat > "$CONFIG_LAYER_MACHINE" <<EOF
{
  "version": 1,
  "machine_id": "$machine_id",
  "vault": {},
  "features": {},
  "paths": {},
  "shell": {}
}
EOF

    echo "Created machine config: $CONFIG_LAYER_MACHINE"
}

# Initialize project config in current directory
config_init_project() {
    local config_file="$PWD/$CONFIG_LAYER_PROJECT"

    if [[ -f "$config_file" ]]; then
        echo "Project config already exists: $config_file" >&2
        return 1
    fi

    cat > "$config_file" <<'EOF'
{
  "version": 1,
  "features": {},
  "shell": {},
  "aliases": {}
}
EOF

    echo "Created project config: $config_file"
}

# ============================================================
# Internal Helper Functions
# ============================================================

# Find project config by walking up directory tree
_find_project_config() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/$CONFIG_LAYER_PROJECT" ]]; then
            echo "$dir/$CONFIG_LAYER_PROJECT"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Get value from JSON file (returns empty string if not found)
_json_get() {
    local file="$1"
    local key="$2"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    local value
    value=$(jq -r "if .$key == null then empty else .$key end" "$file" 2>/dev/null || true)

    if [[ -n "$value" && "$value" != "null" ]]; then
        echo "$value"
    fi
}

# ============================================================
# Feature Registry Integration
# ============================================================

# Check if config_layers feature is enabled (bootstrap check)
# This allows the feature to be disabled entirely
_config_layers_enabled() {
    # If feature registry is loaded, check it
    if type feature_enabled &>/dev/null; then
        feature_enabled "config_layers" && return 0 || return 1
    fi
    # Default to enabled if feature registry not loaded yet
    return 0
}
