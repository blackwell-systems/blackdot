#!/usr/bin/env zsh
# JSON Config Abstraction Layer (v3.0)
# Provides functions to read/write JSON configuration

set -euo pipefail

# ============================================================
# Configuration Paths
# ============================================================

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
CONFIG_FILE="$CONFIG_DIR/config.json"
CONFIG_INI="$CONFIG_DIR/config.ini"  # Legacy v2.x
CONFIG_BACKUP_DIR="$CONFIG_DIR/backups"

# ============================================================
# Default Configuration (v3.0)
# ============================================================

get_default_config() {
    cat <<'EOF'
{
  "version": 3,
  "vault": {
    "backend": "",
    "auto_sync": false,
    "auto_backup": true
  },
  "backup": {
    "enabled": true,
    "auto_backup": true,
    "retention_days": 30,
    "max_snapshots": 10,
    "compress": true,
    "location": "~/.local/share/dotfiles/backups"
  },
  "setup": {
    "completed": [],
    "current_tier": "enhanced"
  },
  "packages": {
    "tier": "enhanced",
    "auto_update": false,
    "parallel_install": false
  },
  "paths": {
    "dotfiles_dir": "",
    "config_dir": "~/.config/dotfiles",
    "backup_dir": "~/.local/share/dotfiles/backups"
  }
}
EOF
}

# ============================================================
# Config Initialization
# ============================================================

init_config() {
    # Create config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR"

    # If no config exists, create default
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Creating default config: $CONFIG_FILE" >&2
        get_default_config > "$CONFIG_FILE"

        # Auto-detect dotfiles_dir if possible
        if [[ -n "${DOTFILES_DIR:-}" ]]; then
            config_set "paths.dotfiles_dir" "$DOTFILES_DIR"
        fi
    fi
}

# ============================================================
# Config Read Operations
# ============================================================

config_get() {
    local key="$1"
    local default="${2:-}"

    # Ensure config exists
    [[ -f "$CONFIG_FILE" ]] || init_config

    # Use jq to extract value (handle booleans properly - false is valid, not empty)
    local value
    value=$(jq -r "if .$key == null then empty else .$key end" "$CONFIG_FILE" 2>/dev/null)

    # Return value or default
    if [[ -n "$value" && "$value" != "null" ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

config_get_bool() {
    local key="$1"
    local default="${2:-false}"

    local value
    value=$(config_get "$key" "$default")

    # Convert to boolean
    if [[ "$value" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

config_get_array() {
    local key="$1"

    # Ensure config exists
    [[ -f "$CONFIG_FILE" ]] || init_config

    # Get array as newline-separated values
    jq -r ".$key[]? // empty" "$CONFIG_FILE" 2>/dev/null
}

# ============================================================
# Config Write Operations
# ============================================================

config_set() {
    local key="$1"
    local value="$2"

    # Ensure config exists
    [[ -f "$CONFIG_FILE" ]] || init_config

    # Create backup
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"

    # Update value using jq
    local tmp_file="$CONFIG_FILE.tmp"
    jq --arg val "$value" ".$key = \$val" "$CONFIG_FILE" > "$tmp_file"
    mv "$tmp_file" "$CONFIG_FILE"
}

config_set_bool() {
    local key="$1"
    local value="$2"

    # Ensure config exists
    [[ -f "$CONFIG_FILE" ]] || init_config

    # Create backup
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"

    # Update boolean value using jq
    local tmp_file="$CONFIG_FILE.tmp"
    if [[ "$value" == "true" || "$value" == "1" ]]; then
        jq ".$key = true" "$CONFIG_FILE" > "$tmp_file"
    else
        jq ".$key = false" "$CONFIG_FILE" > "$tmp_file"
    fi
    mv "$tmp_file" "$CONFIG_FILE"
}

config_array_add() {
    local key="$1"
    local value="$2"

    # Ensure config exists
    [[ -f "$CONFIG_FILE" ]] || init_config

    # Create backup
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"

    # Add to array (avoid duplicates)
    local tmp_file="$CONFIG_FILE.tmp"
    jq --arg val "$value" \
        ".$key = (.$key // [] | if contains([\$val]) then . else . + [\$val] end)" \
        "$CONFIG_FILE" > "$tmp_file"
    mv "$tmp_file" "$CONFIG_FILE"
}

config_array_remove() {
    local key="$1"
    local value="$2"

    # Ensure config exists
    [[ -f "$CONFIG_FILE" ]] || init_config

    # Create backup
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"

    # Remove from array
    local tmp_file="$CONFIG_FILE.tmp"
    jq --arg val "$value" ".$key = (.$key // [] | map(select(. != \$val)))" \
        "$CONFIG_FILE" > "$tmp_file"
    mv "$tmp_file" "$CONFIG_FILE"
}

# ============================================================
# Config Validation
# ============================================================

config_validate() {
    # Ensure config exists
    [[ -f "$CONFIG_FILE" ]] || init_config

    # Validate JSON syntax
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        echo "ERROR: Invalid JSON in $CONFIG_FILE" >&2
        return 1
    fi

    # Check version
    local version
    version=$(config_get "version" "0")
    if [[ "$version" != "3" ]]; then
        echo "WARNING: Config version is $version, expected 3" >&2
        echo "Run: dotfiles migrate-config" >&2
        return 1
    fi

    return 0
}

# ============================================================
# Legacy INI Support (for migration)
# ============================================================

has_legacy_config() {
    [[ -f "$CONFIG_INI" ]] && [[ ! -f "$CONFIG_FILE" ]]
}

get_ini_value() {
    local section="$1"
    local key="$2"
    local default="${3:-}"

    if [[ ! -f "$CONFIG_INI" ]]; then
        echo "$default"
        return
    fi

    # Simple INI parser (good enough for our use case)
    local value
    value=$(awk -F= -v section="$section" -v key="$key" '
        /^\[/ { current_section = substr($0, 2, length($0)-2) }
        current_section == section && $1 == key { print $2; exit }
    ' "$CONFIG_INI" | tr -d ' ')

    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# ============================================================
# Helper Functions
# ============================================================

config_show() {
    # Ensure config exists
    [[ -f "$CONFIG_FILE" ]] || init_config

    # Pretty-print config
    jq '.' "$CONFIG_FILE"
}

config_backup() {
    # Ensure config exists
    [[ -f "$CONFIG_FILE" ]] || return 0

    # Create backup directory
    mkdir -p "$CONFIG_BACKUP_DIR"

    # Create timestamped backup
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$CONFIG_BACKUP_DIR/config-$timestamp.json"

    cp "$CONFIG_FILE" "$backup_file"
    echo "$backup_file"
}

# ============================================================
# Note: Functions are automatically available when this file
# is sourced - no explicit export needed
# ============================================================
