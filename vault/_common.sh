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
SESSION_FILE="$VAULT_DIR/.bw-session"

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
# Single source of truth: SSH Keys
# Format: "bitwarden_item" => "private_key_path"
# To add a new SSH key, add it here and it propagates everywhere
# ============================================================
typeset -A SSH_KEYS=(
    ["SSH-GitHub-Enterprise"]="$HOME/.ssh/id_ed25519_enterprise_ghub"
    ["SSH-GitHub-Blackwell"]="$HOME/.ssh/id_ed25519_blackwell"
)

# Get list of SSH key file paths (for ssh-agent loading)
get_ssh_key_paths() {
    for key_path in "${SSH_KEYS[@]}"; do
        echo "$key_path"
    done | sort
}

# Get list of SSH key Bitwarden item names
get_ssh_key_items() {
    for item in "${(k)SSH_KEYS[@]}"; do
        echo "$item"
    done | sort
}

# ============================================================
# Single source of truth: AWS Profiles (for health check)
# Add profiles here that should be validated
# ============================================================
AWS_EXPECTED_PROFILES=(
    "default"
)

# ============================================================
# Single source of truth: Dotfiles items and their mappings
# Format: "local_path:required|optional:type"
# ============================================================
typeset -A DOTFILES_ITEMS=(
    ["SSH-GitHub-Enterprise"]="$HOME/.ssh/id_ed25519_enterprise_ghub:required:sshkey"
    ["SSH-GitHub-Blackwell"]="$HOME/.ssh/id_ed25519_blackwell:required:sshkey"
    ["SSH-Config"]="$HOME/.ssh/config:required:file"
    ["AWS-Config"]="$HOME/.aws/config:required:file"
    ["AWS-Credentials"]="$HOME/.aws/credentials:required:file"
    ["Git-Config"]="$HOME/.gitconfig:required:file"
    ["Environment-Secrets"]="$HOME/.local/env.secrets:optional:file"
)

# Items that can be synced (file-based, not SSH keys)
typeset -A SYNCABLE_ITEMS=(
    ["SSH-Config"]="$HOME/.ssh/config"
    ["AWS-Config"]="$HOME/.aws/config"
    ["AWS-Credentials"]="$HOME/.aws/credentials"
    ["Git-Config"]="$HOME/.gitconfig"
    ["Environment-Secrets"]="$HOME/.local/env.secrets"
)

# Get required items list
get_required_items() {
    local items=()
    for item in "${(k)DOTFILES_ITEMS[@]}"; do
        local spec="${DOTFILES_ITEMS[$item]}"
        [[ "$spec" == *":required:"* ]] && items+=("$item")
    done
    printf '%s\n' "${items[@]}" | sort
}

# Get optional items list
get_optional_items() {
    local items=()
    for item in "${(k)DOTFILES_ITEMS[@]}"; do
        local spec="${DOTFILES_ITEMS[$item]}"
        [[ "$spec" == *":optional:"* ]] && items+=("$item")
    done
    printf '%s\n' "${items[@]}" | sort
}

# Get local path for an item
get_item_path() {
    local item="$1"
    local spec="${DOTFILES_ITEMS[$item]:-}"
    [[ -n "$spec" ]] && echo "${spec%%:*}"
}

# Check if item is a protected dotfiles item
is_protected_item() {
    local item="$1"
    (( ${+DOTFILES_ITEMS[$item]} ))
}

# ============================================================
# Prerequisite checks
# ============================================================
require_bw() {
    if ! command -v bw >/dev/null 2>&1; then
        fail "Bitwarden CLI (bw) is not installed."
        echo "Install with: brew install bitwarden-cli" >&2
        exit 1
    fi
}

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        fail "jq is not installed."
        echo "Install with: brew install jq" >&2
        exit 1
    fi
}

require_logged_in() {
    if ! bw login --check >/dev/null 2>&1; then
        fail "Not logged in to Bitwarden."
        echo "Please run: bw login" >&2
        exit 1
    fi
}

# ============================================================
# Session management
# ============================================================

# Get a valid Bitwarden session
# Usage: SESSION=$(get_session) or get_session (sets BW_SESSION)
get_session() {
    local session="${BW_SESSION:-}"

    # Try cached session file
    if [[ -z "$session" && -f "$SESSION_FILE" ]]; then
        session="$(cat "$SESSION_FILE")"
    fi

    # Validate session
    if [[ -n "$session" ]] && bw unlock --check --session "$session" >/dev/null 2>&1; then
        echo "$session"
        return 0
    fi

    # Need to unlock
    info "Unlocking Bitwarden vault..."
    session="$(bw unlock --raw)"

    if [[ -z "$session" ]]; then
        fail "Failed to unlock Bitwarden vault."
        exit 1
    fi

    # Cache session with secure permissions
    (umask 077 && printf '%s' "$session" > "$SESSION_FILE")

    echo "$session"
}

# Sync the Bitwarden vault
sync_vault() {
    local session="$1"
    info "Syncing Bitwarden vault..."
    bw sync --session "$session" >/dev/null
}

# ============================================================
# Bitwarden item operations
# ============================================================

# Get item JSON from Bitwarden
# Returns empty string if not found
bw_get_item() {
    local item_name="$1"
    local session="$2"
    bw get item "$item_name" --session "$session" 2>/dev/null || echo ""
}

# Get notes field from item
bw_get_notes() {
    local item_name="$1"
    local session="$2"
    local json
    json=$(bw_get_item "$item_name" "$session")
    [[ -n "$json" ]] && printf '%s' "$json" | jq -r '.notes // ""'
}

# Check if item exists
bw_item_exists() {
    local item_name="$1"
    local session="$2"
    bw get item "$item_name" --session "$session" >/dev/null 2>&1
}

# Get item ID
bw_get_item_id() {
    local item_name="$1"
    local session="$2"
    local json
    json=$(bw_get_item "$item_name" "$session")
    [[ -n "$json" ]] && printf '%s' "$json" | jq -r '.id'
}

# ============================================================
# Schema Validation Functions
# ============================================================

# Validate that an item exists
validate_item_exists() {
    local item_name="$1"
    local session="$2"

    if ! bw_item_exists "$item_name" "$session"; then
        fail "Validation failed: Item '$item_name' does not exist in Bitwarden vault"
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
    notes=$(bw_get_notes "$item_name" "$session")

    if [[ -z "$notes" || "$notes" == "null" ]]; then
        fail "Validation failed: Item '$item_name' has empty or missing notes field"
        return 1
    fi

    debug "✓ Item '$item_name' has notes content"
    return 0
}

# Validate that an item is a secure note
validate_item_type() {
    local item_name="$1"
    local session="$2"
    local expected_type="${3:-2}"  # 2 = secureNote in Bitwarden

    local json item_type
    json=$(bw_get_item "$item_name" "$session")
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
    notes=$(bw_get_notes "$item_name" "$session")

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
    notes=$(bw_get_notes "$item_name" "$session")

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
    for item in "${(k)SSH_KEYS[@]}"; do
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
    for item in "${(k)DOTFILES_ITEMS[@]}"; do
        local spec="${DOTFILES_ITEMS[$item]}"
        if [[ "$spec" == *":optional:"* ]] && bw_item_exists "$item" "$session"; then
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
# Pre-restore drift check
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
    vault_content=$(bw_get_notes "$item_name" "$session")

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

    for item_name in "${(k)SYNCABLE_ITEMS[@]}"; do
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
        echo "  1. Run 'dotfiles vault sync' first to save local changes"
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
# Usage: DOTFILES_SKIP_DRIFT_CHECK=1 dotfiles vault restore
skip_drift_check() {
    [[ "${DOTFILES_SKIP_DRIFT_CHECK:-0}" == "1" ]]
}
