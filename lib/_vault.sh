#!/usr/bin/env zsh
# ============================================================
# FILE: lib/_vault.sh
# Vault abstraction layer - supports multiple vault backends
# Source this file: source "$DOTFILES_DIR/lib/_vault.sh"
# ============================================================

# Prevent multiple sourcing
[[ -n "${_VAULT_LOADED:-}" ]] && return 0
_VAULT_LOADED=1

# ============================================================
# Configuration
# ============================================================

# Determine paths first
if [[ -z "${DOTFILES_DIR:-}" ]]; then
    # Try to determine DOTFILES_DIR from script location
    if [[ -n "${0:a:h}" ]]; then
        DOTFILES_DIR="${0:a:h:h}"  # Go up one level from lib/
    else
        DOTFILES_DIR="$HOME/dotfiles"
    fi
fi

VAULT_BACKENDS_DIR="${VAULT_BACKENDS_DIR:-$DOTFILES_DIR/vault/backends}"
VAULT_SESSION_FILE="${VAULT_SESSION_FILE:-$DOTFILES_DIR/vault/.vault-session}"

# Load state library if available (for config file support)
if [[ -f "$DOTFILES_DIR/lib/_state.sh" ]]; then
    source "$DOTFILES_DIR/lib/_state.sh"
fi

# Get vault backend: config file > env var > default
_get_configured_backend() {
    # 1. Check config file (if state library loaded)
    if type config_get >/dev/null 2>&1; then
        local from_config=$(config_get "vault" "backend" "")
        if [[ -n "$from_config" ]]; then
            echo "$from_config"
            return 0
        fi
    fi

    # 2. Check environment variable
    if [[ -n "${DOTFILES_VAULT_BACKEND:-}" ]]; then
        echo "$DOTFILES_VAULT_BACKEND"
        return 0
    fi

    # 3. Default to bitwarden
    echo "bitwarden"
}

# Set the backend (backward compatible)
DOTFILES_VAULT_BACKEND="$(_get_configured_backend)"

# ============================================================
# Logging (use lib/_logging.sh if available, else define)
# ============================================================
if ! type info >/dev/null 2>&1; then
    if [[ -t 1 ]]; then
        _RED='\033[0;31m' _GREEN='\033[0;32m' _YELLOW='\033[0;33m'
        _BLUE='\033[0;34m' _CYAN='\033[0;36m' _NC='\033[0m'
    else
        _RED='' _GREEN='' _YELLOW='' _BLUE='' _CYAN='' _NC=''
    fi
    info()  { print "${_BLUE}[INFO]${_NC} $1"; }
    pass()  { print "${_GREEN}[OK]${_NC} $1"; }
    warn()  { print "${_YELLOW}[WARN]${_NC} $1"; }
    fail()  { print "${_RED}[FAIL]${_NC} $1"; }
    debug() { [[ "${DEBUG:-}" == "1" ]] && print "[DEBUG] $1"; }
fi

# ============================================================
# Backend Loading
# ============================================================

# Currently loaded backend
_VAULT_CURRENT_BACKEND=""

# Load a vault backend
# Usage: vault_load_backend [backend_name]
vault_load_backend() {
    local backend="${1:-$DOTFILES_VAULT_BACKEND}"
    local backend_file="$VAULT_BACKENDS_DIR/${backend}.sh"

    # Already loaded?
    if [[ "$_VAULT_CURRENT_BACKEND" == "$backend" ]]; then
        return 0
    fi

    # Check backend exists
    if [[ ! -f "$backend_file" ]]; then
        fail "Unknown vault backend: $backend"
        echo "Available backends:" >&2
        vault_list_backends >&2
        return 1
    fi

    # Source the backend
    source "$backend_file"

    # Initialize
    if ! vault_backend_init; then
        fail "Failed to initialize $backend backend"
        return 1
    fi

    _VAULT_CURRENT_BACKEND="$backend"
    debug "Loaded vault backend: $backend"
    return 0
}

# List available backends
vault_list_backends() {
    local backends_dir="$VAULT_BACKENDS_DIR"
    if [[ -d "$backends_dir" ]]; then
        for f in "$backends_dir"/*.sh; do
            [[ -f "$f" ]] || continue
            local name="${f:t:r}"  # Get filename without path and extension
            [[ "$name" == _* ]] && continue  # Skip _interface.md etc
            echo "  - $name"
        done
    fi
}

# Get current backend name
vault_current_backend() {
    if [[ -n "$_VAULT_CURRENT_BACKEND" ]]; then
        echo "$_VAULT_CURRENT_BACKEND"
    else
        echo "$DOTFILES_VAULT_BACKEND"
    fi
}

# ============================================================
# Public API Functions
# These wrap the backend implementations
# ============================================================

# Initialize vault (load backend)
# Usage: vault_init [backend]
vault_init() {
    vault_load_backend "${1:-}"
}

# Get the backend's human-readable name
vault_name() {
    _ensure_backend_loaded || return 1
    vault_backend_name
}

# Check if logged in
vault_login_check() {
    _ensure_backend_loaded || return 1
    vault_backend_login_check
}

# Get session token
# Usage: SESSION=$(vault_get_session)
vault_get_session() {
    _ensure_backend_loaded || return 1
    vault_backend_get_session
}

# Sync vault with remote
# Usage: vault_sync "$SESSION"
vault_sync() {
    _ensure_backend_loaded || return 1
    vault_backend_sync "$@"
}

# Get item JSON
# Usage: json=$(vault_get_item "Git-Config" "$SESSION")
vault_get_item() {
    _ensure_backend_loaded || return 1
    vault_backend_get_item "$@"
}

# Get item notes/content
# Usage: content=$(vault_get_notes "Git-Config" "$SESSION")
vault_get_notes() {
    _ensure_backend_loaded || return 1
    vault_backend_get_notes "$@"
}

# Check if item exists
# Usage: if vault_item_exists "Git-Config" "$SESSION"; then ...
vault_item_exists() {
    _ensure_backend_loaded || return 1
    vault_backend_item_exists "$@"
}

# Get item ID
# Usage: id=$(vault_get_item_id "Git-Config" "$SESSION")
vault_get_item_id() {
    _ensure_backend_loaded || return 1
    if type vault_backend_get_item_id >/dev/null 2>&1; then
        vault_backend_get_item_id "$@"
    else
        # Default implementation: extract from get_item
        local json
        json=$(vault_backend_get_item "$@")
        [[ -n "$json" ]] && printf '%s' "$json" | jq -r '.id // ""'
    fi
}

# List all items
# Usage: vault_list_items "$SESSION"
vault_list_items() {
    _ensure_backend_loaded || return 1
    vault_backend_list_items "$@"
}

# Create new item
# Usage: vault_create_item "Item-Name" "content" "$SESSION"
vault_create_item() {
    _ensure_backend_loaded || return 1
    vault_backend_create_item "$@"
}

# Update existing item
# Usage: vault_update_item "Item-Name" "new content" "$SESSION"
vault_update_item() {
    _ensure_backend_loaded || return 1
    vault_backend_update_item "$@"
}

# Delete item
# Usage: vault_delete_item "Item-Name" "$SESSION"
vault_delete_item() {
    _ensure_backend_loaded || return 1
    vault_backend_delete_item "$@"
}

# ============================================================
# Optional API Functions (may not be implemented by all backends)
# ============================================================

# Health check
vault_health_check() {
    _ensure_backend_loaded || return 1
    if type vault_backend_health_check >/dev/null 2>&1; then
        vault_backend_health_check
    else
        # Default: just check login
        if vault_backend_login_check; then
            pass "Vault backend $(vault_backend_name) is healthy"
            return 0
        else
            fail "Not logged in to $(vault_backend_name)"
            return 1
        fi
    fi
}

# Get attachment
vault_get_attachment() {
    _ensure_backend_loaded || return 1
    if type vault_backend_get_attachment >/dev/null 2>&1; then
        vault_backend_get_attachment "$@"
    else
        fail "Attachments not supported by $(vault_backend_name) backend"
        return 1
    fi
}

# ============================================================
# Helper Functions
# ============================================================

# Ensure a backend is loaded
_ensure_backend_loaded() {
    if [[ -z "$_VAULT_CURRENT_BACKEND" ]]; then
        vault_load_backend || return 1
    fi
    return 0
}

# Check if required CLI tool is installed
vault_require_cli() {
    local cli="$1"
    local install_hint="${2:-}"

    if ! command -v "$cli" >/dev/null 2>&1; then
        fail "$cli is not installed"
        [[ -n "$install_hint" ]] && echo "Install with: $install_hint" >&2
        return 1
    fi
    return 0
}

# Require jq for JSON parsing (used by most backends)
vault_require_jq() {
    vault_require_cli "jq" "brew install jq"
}

# Cache session token securely
vault_cache_session() {
    local session="$1"
    local session_file="${2:-$VAULT_SESSION_FILE}"

    (umask 077 && printf '%s' "$session" > "$session_file")
}

# Read cached session token
vault_read_cached_session() {
    local session_file="${1:-$VAULT_SESSION_FILE}"

    if [[ -f "$session_file" ]]; then
        cat "$session_file"
    fi
}

# Clear cached session
vault_clear_session() {
    local session_file="${1:-$VAULT_SESSION_FILE}"

    [[ -f "$session_file" ]] && rm -f "$session_file"
}

# ============================================================
# Vault Schema Validation
# ============================================================

# Validate vault-items.json against JSON schema
# Returns 0 if valid, 1 if invalid
# Usage: vault_validate_schema [path_to_vault_items_json]
vault_validate_schema() {
    local vault_items_file="${1:-$HOME/.config/dotfiles/vault-items.json}"
    local schema_file="$DOTFILES_DIR/vault/vault-items.schema.json"

    # Check if vault-items.json exists
    if [[ ! -f "$vault_items_file" ]]; then
        warn "vault-items.json not found at: $vault_items_file"
        info "Run 'dotfiles vault scan' to create it"
        return 1
    fi

    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        warn "jq not installed - skipping schema validation"
        info "Install jq for schema validation: brew install jq"
        return 0  # Don't fail if jq is missing
    fi

    # Validate JSON syntax first
    if ! jq empty "$vault_items_file" 2>/dev/null; then
        fail "Invalid JSON syntax in vault-items.json"
        info "Check syntax: jq . $vault_items_file"
        return 1
    fi

    # Validate required fields
    local errors=""

    # Check vault_items is present (required field)
    if ! jq -e '.vault_items' "$vault_items_file" >/dev/null 2>&1; then
        errors+="✗ Missing required field: vault_items\n"
    fi

    # Validate vault_items structure
    if jq -e '.vault_items' "$vault_items_file" >/dev/null 2>&1; then
        local item_errors=$(jq -r '
            .vault_items | to_entries[] |
            select(.value.path == null or .value.required == null or .value.type == null) |
            "✗ Item \(.key): missing required field (path, required, or type)"
        ' "$vault_items_file" 2>/dev/null)

        if [[ -n "$item_errors" ]]; then
            errors+="$item_errors\n"
        fi

        # Validate type field values
        local type_errors=$(jq -r '
            .vault_items | to_entries[] |
            select(.value.type != null and (.value.type != "file" and .value.type != "sshkey")) |
            "✗ Item \(.key): invalid type \"\(.value.type)\" (must be \"file\" or \"sshkey\")"
        ' "$vault_items_file" 2>/dev/null)

        if [[ -n "$type_errors" ]]; then
            errors+="$type_errors\n"
        fi
    fi

    # Validate item names match pattern ^[A-Z][A-Za-z0-9-]*$
    local name_errors=$(jq -r '
        (.vault_items // {} | keys[]) as $key |
        select($key | test("^[A-Z][A-Za-z0-9-]*$") | not) |
        "✗ Invalid item name: \($key) (must start with capital, contain only alphanumeric and hyphens)"
    ' "$vault_items_file" 2>/dev/null)

    if [[ -n "$name_errors" ]]; then
        errors+="$name_errors\n"
    fi

    # Report errors if any
    if [[ -n "$errors" ]]; then
        fail "vault-items.json validation failed:"
        echo ""
        echo -e "$errors" | sed 's/^/  /'
        echo ""
        info "See example: $DOTFILES_DIR/vault/vault-items.example.json"
        info "Schema: $schema_file"
        return 1
    fi

    # Validation passed
    return 0
}

# ============================================================
# Offline Mode Support
# ============================================================

# Check if running in offline mode
vault_is_offline() {
    [[ "${DOTFILES_OFFLINE:-0}" == "1" ]]
}

# Wrapper to skip vault operations in offline mode
vault_require_online() {
    if vault_is_offline; then
        warn "Offline mode enabled (DOTFILES_OFFLINE=1) - skipping vault operation"
        return 1
    fi
    return 0
}
