#!/usr/bin/env zsh
# ============================================================
# FILE: vault/_common.sh
# Shared functions and definitions for vault scripts
# Source this file: source "$(dirname "$0")/_common.sh"
# ============================================================

# Prevent multiple sourcing
[[ -n "${_VAULT_COMMON_LOADED:-}" ]] && return 0
_VAULT_COMMON_LOADED=1

# ============================================================
# Directory paths
# ============================================================
# In zsh, ${0:a:h} gets the absolute path's directory for sourced scripts
VAULT_DIR="${0:a:h}"
DOTFILES_DIR="${VAULT_DIR:h}"  # Parent of vault/
SESSION_FILE="$VAULT_DIR/.vault-session"

# ============================================================
# Color definitions (disabled if not a terminal)
# ============================================================
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    DIM='\033[2m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' DIM='' BOLD='' NC=''
fi

# ============================================================
# Logging functions
# ============================================================
info()  { print "${BLUE}[INFO]${NC} $1"; }
pass()  { print "${GREEN}[OK]${NC} $1"; }
warn()  { print "${YELLOW}[WARN]${NC} $1"; }
fail()  { print "${RED}[FAIL]${NC} $1"; }
dry()   { print "${CYAN}[DRY-RUN]${NC} $1"; }
debug() { [[ "${DEBUG:-}" == "1" ]] && print "${DIM}[DEBUG] $1${NC}"; }

# ============================================================
# Load Vault Abstraction Layer
# ============================================================
# The vault abstraction supports multiple backends:
#   - bitwarden (default)
#   - 1password
#   - pass
# Set DOTFILES_VAULT_BACKEND to switch backends
source "$DOTFILES_DIR/lib/_vault.sh"

# ============================================================
# Vault Items Configuration
# ============================================================
# Configuration is loaded from ~/.config/dotfiles/vault-items.json
# Copy vault/vault-items.example.json to get started
#
# To customize vault items, edit your config file:
#   ~/.config/dotfiles/vault-items.json
# ============================================================

VAULT_CONFIG_FILE="${VAULT_CONFIG_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/vault-items.json}"
VAULT_CONFIG_EXAMPLE="$VAULT_DIR/vault-items.example.json"

# Initialize empty arrays (populated by load_vault_config)
typeset -gA SSH_KEYS=()
typeset -gA DOTFILES_ITEMS=()
typeset -gA SYNCABLE_ITEMS=()
typeset -ga AWS_EXPECTED_PROFILES=()

# Load vault configuration from JSON file
load_vault_config() {
    # Check if config file exists
    if [[ ! -f "$VAULT_CONFIG_FILE" ]]; then
        return 1
    fi

    # Check if jq is available
    if ! command -v jq &>/dev/null && [[ ! -x /usr/bin/jq ]]; then
        warn "jq not installed - cannot load vault config"
        return 1
    fi

    # Use full path to jq if command not in PATH
    local JQ_CMD
    if command -v jq &>/dev/null; then
        JQ_CMD="jq"
    else
        JQ_CMD="/usr/bin/jq"
    fi
    debug "Using JQ_CMD: $JQ_CMD"

    # Validate JSON syntax
    if ! $JQ_CMD -e '.' "$VAULT_CONFIG_FILE" &>/dev/null; then
        fail "Invalid JSON in $VAULT_CONFIG_FILE"
        return 1
    fi

    # Load SSH_KEYS
    typeset -gA SSH_KEYS=()
    while IFS='=' read -r key value; do
        [[ -n "$key" ]] && SSH_KEYS[$key]="${value//\~/$HOME}"
    done < <($JQ_CMD -r '.ssh_keys // {} | to_entries[] | "\(.key)=\(.value)"' "$VAULT_CONFIG_FILE" 2>/dev/null)

    # Load DOTFILES_ITEMS
    # NOTE: Variable must be named 'item_path' not 'path' to avoid zsh PATH conflict
    typeset -gA DOTFILES_ITEMS=()
    while IFS='|' read -r name item_path required item_type; do
        [[ -n "$name" ]] && DOTFILES_ITEMS[$name]="${item_path//\~/$HOME}:$required:$item_type"
    done < <($JQ_CMD -r '.vault_items // {} | to_entries[] | "\(.key)|\(.value.path)|\(.value.required // false | if . then "required" else "optional" end)|\(.value.type)"' "$VAULT_CONFIG_FILE" 2>/dev/null)

    # Load SYNCABLE_ITEMS (use process substitution like SSH_KEYS)
    typeset -gA SYNCABLE_ITEMS=()
    while IFS='=' read -r key value; do
        [[ -n "$key" ]] && SYNCABLE_ITEMS[$key]="${value//\~/$HOME}"
    done < <($JQ_CMD -r '.syncable_items // {} | to_entries[] | "\(.key)=\(.value)"' "$VAULT_CONFIG_FILE" 2>/dev/null)

    # Load AWS_EXPECTED_PROFILES (use process substitution like SSH_KEYS)
    typeset -ga AWS_EXPECTED_PROFILES=()
    while IFS= read -r profile; do
        [[ -n "$profile" ]] && AWS_EXPECTED_PROFILES+=("$profile")
    done < <($JQ_CMD -r '.aws_expected_profiles // [] | .[]' "$VAULT_CONFIG_FILE" 2>/dev/null)

    debug "Loaded vault config from $VAULT_CONFIG_FILE"
    debug "  SSH_KEYS: ${#SSH_KEYS[@]} items"
    debug "  DOTFILES_ITEMS: ${#DOTFILES_ITEMS[@]} items"
    debug "  SYNCABLE_ITEMS: ${#SYNCABLE_ITEMS[@]} items"
    debug "  AWS_EXPECTED_PROFILES: ${#AWS_EXPECTED_PROFILES[@]} profiles"

    return 0
}

# Check if vault config exists
vault_config_exists() {
    [[ -f "$VAULT_CONFIG_FILE" ]]
}

# Require vault config to exist
require_vault_config() {
    if ! vault_config_exists; then
        fail "Vault config not found: $VAULT_CONFIG_FILE"
        echo ""
        echo "To configure vault items, either:"
        echo "  1. Run 'dotfiles setup' to create config interactively"
        echo "  2. Copy the example config:"
        echo "     mkdir -p ~/.config/dotfiles"
        echo "     cp $VAULT_CONFIG_EXAMPLE $VAULT_CONFIG_FILE"
        echo "     \$EDITOR $VAULT_CONFIG_FILE"
        echo ""
        return 1
    fi

    if ! load_vault_config; then
        fail "Failed to load vault config"
        return 1
    fi

    return 0
}

# Load config on source (silent - won't fail if missing)
load_vault_config 2>/dev/null || true

# Get list of SSH key file paths (for ssh-agent loading)
get_ssh_key_paths() {
    for key_path in "${SSH_KEYS[@]}"; do
        echo "$key_path"
    done | /usr/bin/sort
}

# Get list of SSH key vault item names
get_ssh_key_items() {
    for item in "${(@k)SSH_KEYS}"; do
        echo "$item"
    done | /usr/bin/sort
}

# Get required items list
get_required_items() {
    local items=()
    for item in "${(@k)DOTFILES_ITEMS}"; do
        local spec="${DOTFILES_ITEMS[$item]}"
        [[ "$spec" == *":required:"* ]] && items+=("$item")
    done
    printf '%s\n' "${items[@]}" | /usr/bin/sort
}

# Get optional items list
get_optional_items() {
    local items=()
    for item in "${(@k)DOTFILES_ITEMS}"; do
        local spec="${DOTFILES_ITEMS[$item]}"
        [[ "$spec" == *":optional:"* ]] && items+=("$item")
    done
    printf '%s\n' "${items[@]}" | /usr/bin/sort
}

# Get local path for an item (checks all config sources)
get_item_path() {
    local item="$1"

    # Check DOTFILES_ITEMS first (has full metadata)
    local spec="${DOTFILES_ITEMS[$item]:-}"
    if [[ -n "$spec" ]]; then
        echo "${spec%%:*}"
        return 0
    fi

    # Check SYNCABLE_ITEMS
    if [[ -n "${SYNCABLE_ITEMS[$item]:-}" ]]; then
        echo "${SYNCABLE_ITEMS[$item]}"
        return 0
    fi

    # Check SSH_KEYS
    if [[ -n "${SSH_KEYS[$item]:-}" ]]; then
        echo "${SSH_KEYS[$item]}"
        return 0
    fi

    return 1
}

# Check if item is a protected dotfiles item
is_protected_item() {
    local item="$1"
    (( ${+DOTFILES_ITEMS[$item]} ))
}

# ============================================================
# Offline mode support
# ============================================================
# Check if running in offline mode
# Usage: if is_offline; then skip_vault_ops; fi
is_offline() {
    [[ "${DOTFILES_OFFLINE:-0}" == "1" ]]
}

# Wrapper to skip vault operations in offline mode
# Returns 0 (success) if offline, allowing graceful skip
# Usage: require_online || return 0
require_online() {
    if is_offline; then
        warn "Offline mode enabled (DOTFILES_OFFLINE=1) - skipping vault operation"
        return 1
    fi
    return 0
}

# ============================================================
# Prerequisite checks (using vault abstraction)
# ============================================================
require_vault() {
    # Skip in offline mode
    is_offline && return 0

    # Initialize vault backend
    vault_init || exit 1
}

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        fail "jq is not installed."
        echo "Install with: brew install jq" >&2
        exit 1
    fi
}

require_logged_in() {
    # Skip in offline mode
    is_offline && return 0

    # Initialize and check login
    vault_init || exit 1
    if ! vault_login_check; then
        fail "Not logged in to $(vault_name)."
        echo "Please log in to your vault provider" >&2
        exit 1
    fi
}

# ============================================================
# Legacy aliases for backward compatibility
# These wrap the new vault_* functions
# ============================================================
require_bw() {
    require_vault
}

get_session() {
    vault_get_session
}

sync_vault() {
    local session="$1"
    vault_sync "$session"
}

bw_get_item() {
    local item_name="$1"
    local session="$2"
    vault_get_item "$item_name" "$session"
}

bw_get_notes() {
    local item_name="$1"
    local session="$2"
    vault_get_notes "$item_name" "$session"
}

bw_item_exists() {
    local item_name="$1"
    local session="$2"
    vault_item_exists "$item_name" "$session"
}

bw_get_item_id() {
    local item_name="$1"
    local session="$2"
    vault_get_item_id "$item_name" "$session"
}

# ============================================================
# Schema Validation Functions (using vault abstraction)
# ============================================================

# Validate that an item exists
validate_item_exists() {
    local item_name="$1"
    local session="$2"

    if ! vault_item_exists "$item_name" "$session"; then
        fail "Validation failed: Item '$item_name' does not exist in vault"
        return 1
    fi

    debug "✓ Item '$item_name' exists"
    return 0
}

# Validate that an item has notes field with content
validate_item_has_notes() {
    local item_name="$1"
    local session="$2"

    local notes
    notes=$(vault_get_notes "$item_name" "$session")

    if [[ -z "$notes" || "$notes" == "null" ]]; then
        fail "Validation failed: Item '$item_name' has empty or missing notes field"
        return 1
    fi

    debug "✓ Item '$item_name' has notes content"
    return 0
}

# Validate that an item is a secure note (type check)
validate_item_type() {
    local item_name="$1"
    local session="$2"
    local expected_type="${3:-2}"  # 2 = secureNote (Bitwarden convention)

    local json item_type
    json=$(vault_get_item "$item_name" "$session")
    item_type=$(printf '%s' "$json" | jq -r '.type // ""')

    if [[ "$item_type" != "$expected_type" ]]; then
        fail "Validation failed: Item '$item_name' has type $item_type, expected $expected_type (secureNote)"
        return 1
    fi

    debug "✓ Item '$item_name' has correct type"
    return 0
}

# Validate SSH key item structure
validate_ssh_key_item() {
    local item_name="$1"
    local session="$2"

    # Check item exists
    validate_item_exists "$item_name" "$session" || return 1

    # Check it's a secure note
    validate_item_type "$item_name" "$session" || return 1

    # Check it has notes
    validate_item_has_notes "$item_name" "$session" || return 1

    # Check notes contain private key
    local notes
    notes=$(vault_get_notes "$item_name" "$session")

    if ! printf '%s' "$notes" | grep -q "BEGIN OPENSSH PRIVATE KEY"; then
        fail "Validation failed: Item '$item_name' notes do not contain 'BEGIN OPENSSH PRIVATE KEY'"
        return 1
    fi

    if ! printf '%s' "$notes" | grep -q "END OPENSSH PRIVATE KEY"; then
        fail "Validation failed: Item '$item_name' notes do not contain 'END OPENSSH PRIVATE KEY'"
        return 1
    fi

    # Check notes contain public key
    if ! printf '%s' "$notes" | grep -qE "^ssh-(ed25519|rsa|ecdsa) "; then
        fail "Validation failed: Item '$item_name' notes do not contain a public key line (ssh-ed25519/rsa/ecdsa)"
        return 1
    fi

    pass "✓ SSH key item '$item_name' validated successfully"
    return 0
}

# Validate file-based config item
validate_config_item() {
    local item_name="$1"
    local session="$2"
    local min_length="${3:-10}"  # Minimum content length

    # Check item exists
    validate_item_exists "$item_name" "$session" || return 1

    # Check it's a secure note
    validate_item_type "$item_name" "$session" || return 1

    # Check it has notes with minimum length
    local notes
    notes=$(vault_get_notes "$item_name" "$session")

    if [[ -z "$notes" || "$notes" == "null" ]]; then
        fail "Validation failed: Item '$item_name' has empty notes"
        return 1
    fi

    local content_length
    content_length=$(printf '%s' "$notes" | wc -c | tr -d ' ')

    if [[ "$content_length" -lt "$min_length" ]]; then
        fail "Validation failed: Item '$item_name' notes too short ($content_length < $min_length chars)"
        return 1
    fi

    pass "✓ Config item '$item_name' validated successfully"
    return 0
}

# Validate all required vault items
validate_all_items() {
    local session="$1"
    local errors=0

    info "Validating vault items schema..."

    # Validate SSH keys
    for item in "${(@k)SSH_KEYS}"; do
        if ! validate_ssh_key_item "$item" "$session" 2>&1; then
            ((errors++))
        fi
    done

    # Validate config files
    for item in SSH-Config AWS-Config AWS-Credentials Git-Config; do
        if [[ -n "${DOTFILES_ITEMS[$item]:-}" ]]; then
            if ! validate_config_item "$item" "$session" 2>&1; then
                ((errors++))
            fi
        fi
    done

    # Optional items (don't fail if missing, but validate if present)
    for item in "${(@k)DOTFILES_ITEMS}"; do
        local spec="${DOTFILES_ITEMS[$item]}"
        if [[ "$spec" == *":optional:"* ]] && vault_item_exists "$item" "$session"; then
            if ! validate_config_item "$item" "$session" 1 2>&1; then
                warn "Optional item '$item' failed validation"
            fi
        fi
    done

    if [[ $errors -gt 0 ]]; then
        fail "Validation completed with $errors error(s)"
        return 1
    fi

    pass "All vault items validated successfully"
    return 0
}

# ============================================================
# Pre-restore drift check (using vault abstraction)
# Checks if local files differ from vault before restore
# ============================================================

# Check if a single item has drifted from vault
# Returns 0 if no drift, 1 if drifted, 2 if local missing
check_item_drift() {
    local item_name="$1"
    local session="$2"
    local local_path

    # Get local path for this item
    local_path=$(get_item_path "$item_name")
    if [[ -z "$local_path" ]]; then
        # Try SYNCABLE_ITEMS
        local_path="${SYNCABLE_ITEMS[$item_name]:-}"
    fi

    if [[ -z "$local_path" ]]; then
        debug "No local path for item '$item_name'"
        return 0
    fi

    # If local file doesn't exist, no drift to worry about
    if [[ ! -f "$local_path" ]]; then
        debug "Local file not found: $local_path"
        return 2
    fi

    # Get vault content
    local vault_content
    vault_content=$(vault_get_notes "$item_name" "$session")

    if [[ -z "$vault_content" || "$vault_content" == "null" ]]; then
        debug "Vault item '$item_name' has no content"
        return 0
    fi

    # Compare local vs vault
    local local_content
    local_content=$(cat "$local_path")

    if [[ "$local_content" != "$vault_content" ]]; then
        return 1  # Drifted
    fi

    return 0  # No drift
}

# Check all syncable items for drift before restore
# Returns 0 if safe to restore, 1 if drift detected (user should sync first)
check_pre_restore_drift() {
    local session="$1"
    local force="${2:-false}"
    local drifted_items=()

    info "Checking for local changes before restore..."

    for item_name in "${(@k)SYNCABLE_ITEMS}"; do
        local result
        check_item_drift "$item_name" "$session"
        result=$?

        if [[ $result -eq 1 ]]; then
            drifted_items+=("$item_name")
        fi
    done

    if [[ ${#drifted_items[@]} -gt 0 ]]; then
        warn "Local files have changed since last vault sync:"
        for item in "${drifted_items[@]}"; do
            local path="${SYNCABLE_ITEMS[$item]:-$(get_item_path "$item")}"
            echo "  - $item ($path)"
        done
        echo ""

        if [[ "$force" == "true" ]]; then
            warn "Proceeding with restore (--force specified)"
            return 0
        fi

        echo -e "${YELLOW}Options:${NC}"
        echo "  1. Run 'dotfiles vault push' first to save local changes"
        echo "  2. Run restore with --force to overwrite local changes"
        echo "  3. Run 'dotfiles drift' to see detailed differences"
        echo ""
        fail "Restore aborted to prevent data loss"
        return 1
    fi

    pass "No local drift detected - safe to restore"
    return 0
}

# Environment variable to skip drift check (for automation)
# Usage: DOTFILES_SKIP_DRIFT_CHECK=1 dotfiles vault pull
skip_drift_check() {
    [[ "${DOTFILES_SKIP_DRIFT_CHECK:-0}" == "1" ]]
}
