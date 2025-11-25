#!/usr/bin/env bash
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
VAULT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
pass()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; }
dry()   { echo -e "${CYAN}[DRY-RUN]${NC} $1"; }
debug() { [[ "${DEBUG:-}" == "1" ]] && echo -e "${DIM}[DEBUG] $1${NC}"; }

# ============================================================
# Single source of truth: Dotfiles items and their mappings
# Format: "local_path:required|optional"
# ============================================================
declare -A DOTFILES_ITEMS=(
    ["SSH-GitHub-Enterprise"]="$HOME/.ssh/id_ed25519_enterprise_ghub:required:sshkey"
    ["SSH-GitHub-Blackwell"]="$HOME/.ssh/id_ed25519_blackwell:required:sshkey"
    ["SSH-Config"]="$HOME/.ssh/config:required:file"
    ["AWS-Config"]="$HOME/.aws/config:required:file"
    ["AWS-Credentials"]="$HOME/.aws/credentials:required:file"
    ["Git-Config"]="$HOME/.gitconfig:required:file"
    ["Environment-Secrets"]="$HOME/.local/env.secrets:optional:file"
)

# Items that can be synced (file-based, not SSH keys)
declare -A SYNCABLE_ITEMS=(
    ["SSH-Config"]="$HOME/.ssh/config"
    ["AWS-Config"]="$HOME/.aws/config"
    ["AWS-Credentials"]="$HOME/.aws/credentials"
    ["Git-Config"]="$HOME/.gitconfig"
    ["Environment-Secrets"]="$HOME/.local/env.secrets"
)

# Get required items list
get_required_items() {
    local items=()
    for item in "${!DOTFILES_ITEMS[@]}"; do
        local spec="${DOTFILES_ITEMS[$item]}"
        [[ "$spec" == *":required:"* ]] && items+=("$item")
    done
    printf '%s\n' "${items[@]}" | sort
}

# Get optional items list
get_optional_items() {
    local items=()
    for item in "${!DOTFILES_ITEMS[@]}"; do
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
    [[ -v "DOTFILES_ITEMS[$item]" ]]
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
