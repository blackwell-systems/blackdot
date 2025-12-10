#!/usr/bin/env zsh
# ============================================================
# FILE: vault/backends/1password.sh
# 1Password backend implementation for vault abstraction
# Implements the interface defined in _interface.md
# Requires: 1Password CLI (op) v2.x
# ============================================================

# ============================================================
# Backend Configuration
# ============================================================

# 1Password vault to use (default: Personal)
ONEPASSWORD_VAULT="${ONEPASSWORD_VAULT:-Personal}"

# Category for secure notes
ONEPASSWORD_CATEGORY="Secure Note"

# ============================================================
# Backend Metadata
# ============================================================

vault_backend_name() {
    echo "1Password"
}

# ============================================================
# Initialization
# ============================================================

vault_backend_init() {
    # Check for 1Password CLI
    if ! command -v op >/dev/null 2>&1; then
        fail "1Password CLI (op) is not installed"
        echo "Install with: brew install --cask 1password-cli" >&2
        return 1
    fi

    # Check for jq
    if ! command -v jq >/dev/null 2>&1; then
        fail "jq is not installed (required for 1Password backend)"
        echo "Install with: brew install jq" >&2
        return 1
    fi

    # Check CLI version (require v2.x)
    local version
    version=$(op --version 2>/dev/null | cut -d. -f1)
    if [[ "$version" -lt 2 ]]; then
        fail "1Password CLI v2.x required (found v$version)"
        echo "Upgrade with: brew upgrade 1password-cli" >&2
        return 1
    fi

    return 0
}

# ============================================================
# Authentication
# ============================================================

vault_backend_login_check() {
    # 1Password v2 uses system authentication (Touch ID, etc.)
    # Check if we can access the account
    op account list >/dev/null 2>&1
}

vault_backend_get_session() {
    local session_file="${VAULT_SESSION_FILE:-$BLACKDOT_DIR/vault/.vault-session}"

    # 1Password v2 uses biometric/system auth, not session tokens
    # But we still support service accounts via OP_SERVICE_ACCOUNT_TOKEN

    # Check for service account token
    if [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
        echo "$OP_SERVICE_ACCOUNT_TOKEN"
        return 0
    fi

    # Try cached token (for service account scenarios)
    if [[ -f "$session_file" ]]; then
        local cached
        cached=$(cat "$session_file")
        if [[ -n "$cached" ]] && op account list --session "$cached" >/dev/null 2>&1; then
            echo "$cached"
            return 0
        fi
    fi

    # For interactive use, 1Password v2 handles auth automatically
    # Just verify we're signed in
    if ! op account list >/dev/null 2>&1; then
        fail "Not signed in to 1Password"
        echo "Please sign in: op signin" >&2
        return 1
    fi

    # Return empty string - 1Password v2 doesn't need explicit sessions
    echo ""
    return 0
}

# ============================================================
# Vault Sync
# ============================================================

vault_backend_sync() {
    local session="$1"

    # 1Password syncs automatically, no manual sync needed
    # But we can verify connectivity
    local cmd_args=()
    [[ -n "$session" ]] && cmd_args+=(--session "$session")

    if op vault list "${cmd_args[@]}" >/dev/null 2>&1; then
        return 0
    else
        warn "Unable to connect to 1Password"
        return 1
    fi
}

# ============================================================
# Item Operations
# ============================================================

vault_backend_get_item() {
    local item_name="$1"
    local session="$2"

    if [[ -z "$item_name" ]]; then
        return 1
    fi

    local cmd_args=(--vault "$ONEPASSWORD_VAULT" --format json)
    [[ -n "$session" ]] && cmd_args+=(--session "$session")

    # Get item - 1Password uses title for lookup
    local result
    result=$(op item get "$item_name" "${cmd_args[@]}" 2>/dev/null)

    if [[ -n "$result" ]]; then
        # Normalize to our expected format
        # 1Password structure differs from Bitwarden
        printf '%s' "$result" | jq '{
            id: .id,
            name: .title,
            type: (if .category == "SECURE_NOTE" then 2 else 1 end),
            notes: (if .fields then (.fields[] | select(.id == "notesPlain") | .value) // "" else "" end)
        }'
    fi
}

vault_backend_get_notes() {
    local item_name="$1"
    local session="$2"

    if [[ -z "$item_name" ]]; then
        return 1
    fi

    local cmd_args=(--vault "$ONEPASSWORD_VAULT")
    [[ -n "$session" ]] && cmd_args+=(--session "$session")

    # Get the notesPlain field directly
    op item get "$item_name" --fields notesPlain "${cmd_args[@]}" 2>/dev/null || echo ""
}

vault_backend_item_exists() {
    local item_name="$1"
    local session="$2"

    local cmd_args=(--vault "$ONEPASSWORD_VAULT")
    [[ -n "$session" ]] && cmd_args+=(--session "$session")

    op item get "$item_name" "${cmd_args[@]}" >/dev/null 2>&1
}

vault_backend_get_item_id() {
    local item_name="$1"
    local session="$2"

    local cmd_args=(--vault "$ONEPASSWORD_VAULT" --format json)
    [[ -n "$session" ]] && cmd_args+=(--session "$session")

    op item get "$item_name" "${cmd_args[@]}" 2>/dev/null | jq -r '.id // ""'
}

vault_backend_list_items() {
    local session="$1"

    local cmd_args=(--vault "$ONEPASSWORD_VAULT" --format json)
    [[ -n "$session" ]] && cmd_args+=(--session "$session")

    # List and normalize format
    op item list "${cmd_args[@]}" 2>/dev/null | jq '[.[] | {
        id: .id,
        name: .title,
        type: (if .category == "SECURE_NOTE" then 2 else 1 end)
    }]' || echo "[]"
}

# ============================================================
# Item Modification
# ============================================================

vault_backend_create_item() {
    local item_name="$1"
    local content="$2"
    local session="$3"

    if [[ -z "$item_name" ]]; then
        fail "Item name required"
        return 1
    fi

    local cmd_args=(--vault "$ONEPASSWORD_VAULT")
    [[ -n "$session" ]] && cmd_args+=(--session "$session")

    # Check if exists
    if vault_backend_item_exists "$item_name" "$session"; then
        fail "Item '$item_name' already exists. Use update instead."
        return 1
    fi

    # Create secure note with content
    # 1Password uses --title for name and notesPlain for notes
    if op item create \
        --category "$ONEPASSWORD_CATEGORY" \
        --title "$item_name" \
        --vault "$ONEPASSWORD_VAULT" \
        "notesPlain=$content" \
        ${session:+--session "$session"} >/dev/null 2>&1; then
        pass "Created item '$item_name' in 1Password"
        return 0
    else
        fail "Failed to create item '$item_name'"
        return 1
    fi
}

vault_backend_update_item() {
    local item_name="$1"
    local content="$2"
    local session="$3"

    if [[ -z "$item_name" ]]; then
        fail "Item name required"
        return 1
    fi

    local cmd_args=(--vault "$ONEPASSWORD_VAULT")
    [[ -n "$session" ]] && cmd_args+=(--session "$session")

    # Check if exists
    if ! vault_backend_item_exists "$item_name" "$session"; then
        fail "Item '$item_name' not found"
        return 1
    fi

    # Update the item
    if op item edit "$item_name" \
        --vault "$ONEPASSWORD_VAULT" \
        "notesPlain=$content" \
        ${session:+--session "$session"} >/dev/null 2>&1; then
        pass "Updated item '$item_name' in 1Password"
        return 0
    else
        fail "Failed to update item '$item_name'"
        return 1
    fi
}

vault_backend_delete_item() {
    local item_name="$1"
    local session="$2"

    if [[ -z "$item_name" ]]; then
        fail "Item name required"
        return 1
    fi

    local cmd_args=(--vault "$ONEPASSWORD_VAULT")
    [[ -n "$session" ]] && cmd_args+=(--session "$session")

    # Delete the item
    if op item delete "$item_name" "${cmd_args[@]}" >/dev/null 2>&1; then
        pass "Deleted item '$item_name' from 1Password"
        return 0
    else
        fail "Failed to delete item '$item_name'"
        return 1
    fi
}

# ============================================================
# Optional: Health Check
# ============================================================

vault_backend_health_check() {
    local status=0

    # Check CLI installed
    if command -v op >/dev/null 2>&1; then
        local version
        version=$(op --version 2>/dev/null || echo "unknown")
        pass "1Password CLI installed (v$version)"
    else
        fail "1Password CLI not installed"
        status=1
    fi

    # Check signed in
    if op account list >/dev/null 2>&1; then
        local account
        account=$(op account list --format json 2>/dev/null | jq -r '.[0].email // "unknown"')
        pass "Signed in to 1Password ($account)"
    else
        warn "Not signed in to 1Password"
        status=1
    fi

    # Check vault access
    if op vault get "$ONEPASSWORD_VAULT" >/dev/null 2>&1; then
        pass "Vault '$ONEPASSWORD_VAULT' accessible"
    else
        warn "Cannot access vault '$ONEPASSWORD_VAULT'"
        status=1
    fi

    return $status
}

# ============================================================
# Optional: Attachments
# ============================================================

vault_backend_get_attachment() {
    local item_name="$1"
    local attachment_name="$2"
    local session="$3"

    if [[ -z "$item_name" || -z "$attachment_name" ]]; then
        fail "Item name and attachment name required"
        return 1
    fi

    local cmd_args=(--vault "$ONEPASSWORD_VAULT")
    [[ -n "$session" ]] && cmd_args+=(--session "$session")

    # 1Password uses 'op document get' for attachments in some cases
    # or 'op item get' with --fields for file fields
    op document get "$attachment_name" "${cmd_args[@]}" 2>/dev/null || \
        op item get "$item_name" --fields "$attachment_name" "${cmd_args[@]}" 2>/dev/null
}
