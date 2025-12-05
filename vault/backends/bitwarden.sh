#!/usr/bin/env zsh
# ============================================================
# FILE: vault/backends/bitwarden.sh
# Bitwarden backend implementation for vault abstraction
# Implements the interface defined in _interface.md
# ============================================================

# ============================================================
# Backend Metadata
# ============================================================

vault_backend_name() {
    echo "Bitwarden"
}

# ============================================================
# Initialization
# ============================================================

vault_backend_init() {
    # Check for Bitwarden CLI
    if ! command -v bw >/dev/null 2>&1; then
        fail "Bitwarden CLI (bw) is not installed"
        echo "Install with: brew install bitwarden-cli" >&2
        return 1
    fi

    # Check for jq (required for JSON parsing)
    if ! command -v jq >/dev/null 2>&1; then
        fail "jq is not installed (required for Bitwarden backend)"
        echo "Install with: brew install jq" >&2
        return 1
    fi

    return 0
}

# ============================================================
# Authentication
# ============================================================

vault_backend_login_check() {
    bw login --check >/dev/null 2>&1
}

vault_backend_get_session() {
    local session=""
    local session_file="${VAULT_SESSION_FILE:-$DOTFILES_DIR/vault/.vault-session}"

    # Try environment variable first
    session="${BW_SESSION:-}"

    # Try cached session file
    if [[ -z "$session" && -f "$session_file" ]]; then
        session="$(cat "$session_file")"
    fi

    # Validate existing session
    if [[ -n "$session" ]] && bw unlock --check --session "$session" >/dev/null 2>&1; then
        echo "$session"
        return 0
    fi

    # Check if logged in
    if ! bw login --check >/dev/null 2>&1; then
        fail "Not logged in to Bitwarden. Please run: bw login"
        return 1
    fi

    # Need to unlock
    info "Unlocking Bitwarden vault..."
    session="$(bw unlock --raw)"

    if [[ -z "$session" ]]; then
        fail "Failed to unlock Bitwarden vault"
        return 1
    fi

    # Cache session with secure permissions
    (umask 077 && printf '%s' "$session" > "$session_file")

    echo "$session"
}

# ============================================================
# Vault Sync
# ============================================================

vault_backend_sync() {
    local session="$1"

    if [[ -z "$session" ]]; then
        fail "Session required for sync"
        return 1
    fi

    info "Syncing Bitwarden vault..."
    if ! bw sync --session "$session" >/dev/null 2>&1; then
        warn "Failed to sync Bitwarden vault (may be offline)"
        return 1
    fi

    return 0
}

# ============================================================
# Item Operations
# ============================================================

vault_backend_get_item() {
    local item_name="$1"
    local session="$2"

    if [[ -z "$item_name" || -z "$session" ]]; then
        return 1
    fi

    bw get item "$item_name" --session "$session" 2>/dev/null || echo ""
}

vault_backend_get_notes() {
    local item_name="$1"
    local session="$2"
    local json

    json=$(vault_backend_get_item "$item_name" "$session")
    if [[ -n "$json" ]]; then
        printf '%s' "$json" | jq -r '.notes // ""'
    fi
}

vault_backend_item_exists() {
    local item_name="$1"
    local session="$2"

    bw get item "$item_name" --session "$session" >/dev/null 2>&1
}

vault_backend_get_item_id() {
    local item_name="$1"
    local session="$2"
    local json

    json=$(vault_backend_get_item "$item_name" "$session")
    if [[ -n "$json" ]]; then
        printf '%s' "$json" | jq -r '.id // ""'
    fi
}

vault_backend_list_items() {
    local session="$1"

    if [[ -z "$session" ]]; then
        fail "Session required for list"
        return 1
    fi

    bw list items --session "$session" 2>/dev/null || echo "[]"
}

# ============================================================
# Item Modification
# ============================================================

vault_backend_create_item() {
    local item_name="$1"
    local content="$2"
    local session="$3"

    if [[ -z "$item_name" || -z "$session" ]]; then
        fail "Item name and session required"
        return 1
    fi

    # Check if item already exists
    if vault_backend_item_exists "$item_name" "$session"; then
        fail "Item '$item_name' already exists. Use update instead."
        return 1
    fi

    # Create secure note JSON template
    # Type 2 = Secure Note in Bitwarden
    local json_template
    json_template=$(cat <<EOF
{
    "type": 2,
    "secureNote": {
        "type": 0
    },
    "name": "$item_name",
    "notes": "",
    "favorite": false
}
EOF
)

    # Add content to notes field using jq
    local json_with_content
    json_with_content=$(printf '%s' "$json_template" | jq --arg notes "$content" '.notes = $notes')

    # Create the item
    if printf '%s' "$json_with_content" | bw encode | bw create item --session "$session" >/dev/null 2>&1; then
        pass "Created item '$item_name' in Bitwarden"
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

    if [[ -z "$item_name" || -z "$session" ]]; then
        fail "Item name and session required"
        return 1
    fi

    # Get current item
    local current_json
    current_json=$(vault_backend_get_item "$item_name" "$session")

    if [[ -z "$current_json" ]]; then
        fail "Item '$item_name' not found"
        return 1
    fi

    # Get item ID
    local item_id
    item_id=$(printf '%s' "$current_json" | jq -r '.id')

    if [[ -z "$item_id" || "$item_id" == "null" ]]; then
        fail "Could not get ID for item '$item_name'"
        return 1
    fi

    # Update notes field
    local updated_json
    updated_json=$(printf '%s' "$current_json" | jq --arg notes "$content" '.notes = $notes')

    # Push update
    if printf '%s' "$updated_json" | bw encode | bw edit item "$item_id" --session "$session" >/dev/null 2>&1; then
        pass "Updated item '$item_name' in Bitwarden"
        return 0
    else
        fail "Failed to update item '$item_name'"
        return 1
    fi
}

vault_backend_delete_item() {
    local item_name="$1"
    local session="$2"

    if [[ -z "$item_name" || -z "$session" ]]; then
        fail "Item name and session required"
        return 1
    fi

    # Get item ID
    local item_id
    item_id=$(vault_backend_get_item_id "$item_name" "$session")

    if [[ -z "$item_id" || "$item_id" == "null" ]]; then
        fail "Item '$item_name' not found"
        return 1
    fi

    # Delete the item
    if bw delete item "$item_id" --session "$session" >/dev/null 2>&1; then
        pass "Deleted item '$item_name' from Bitwarden"
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
    if command -v bw >/dev/null 2>&1; then
        local version
        version=$(bw --version 2>/dev/null || echo "unknown")
        pass "Bitwarden CLI installed (v$version)"
    else
        fail "Bitwarden CLI not installed"
        status=1
    fi

    # Check logged in
    if bw login --check >/dev/null 2>&1; then
        pass "Logged in to Bitwarden"
    else
        warn "Not logged in to Bitwarden"
        status=1
    fi

    # Check session
    local session_file="${VAULT_SESSION_FILE:-$DOTFILES_DIR/vault/.vault-session}"
    if [[ -f "$session_file" ]]; then
        local session
        session=$(cat "$session_file")
        if bw unlock --check --session "$session" >/dev/null 2>&1; then
            pass "Valid session cached"
        else
            warn "Cached session expired"
        fi
    else
        info "No session cached"
    fi

    return $status
}

# ============================================================
# Optional: Attachments (Bitwarden supports these)
# ============================================================

vault_backend_get_attachment() {
    local item_name="$1"
    local attachment_name="$2"
    local session="$3"

    if [[ -z "$item_name" || -z "$attachment_name" || -z "$session" ]]; then
        fail "Item name, attachment name, and session required"
        return 1
    fi

    # Get item ID first
    local item_id
    item_id=$(vault_backend_get_item_id "$item_name" "$session")

    if [[ -z "$item_id" ]]; then
        fail "Item '$item_name' not found"
        return 1
    fi

    # Get attachment
    bw get attachment "$attachment_name" --itemid "$item_id" --session "$session" --raw 2>/dev/null
}

# ============================================================
# Location Management (v3.1)
# Folder-based organization for Bitwarden
# ============================================================

# List all folders in the vault
# Returns: JSON array of folder names
vault_backend_list_locations() {
    local session="$1"

    if [[ -z "$session" ]]; then
        fail "Session required for listing folders"
        return 1
    fi

    bw list folders --session "$session" 2>/dev/null | jq -r '[.[].name]' || echo "[]"
}

# Check if a folder exists
vault_backend_location_exists() {
    local folder_name="$1"
    local session="$2"

    if [[ -z "$folder_name" || -z "$session" ]]; then
        return 1
    fi

    bw list folders --session "$session" 2>/dev/null | \
        jq -e ".[] | select(.name == \"$folder_name\")" >/dev/null 2>&1
}

# Get folder ID by name
_bw_get_folder_id() {
    local folder_name="$1"
    local session="$2"

    bw list folders --session "$session" 2>/dev/null | \
        jq -r ".[] | select(.name == \"$folder_name\") | .id" 2>/dev/null
}

# Create a new folder
vault_backend_create_location() {
    local folder_name="$1"
    local session="$2"

    if [[ -z "$folder_name" || -z "$session" ]]; then
        fail "Folder name and session required"
        return 1
    fi

    # Check if already exists
    if vault_backend_location_exists "$folder_name" "$session"; then
        info "Folder '$folder_name' already exists"
        return 0
    fi

    # Create the folder
    local folder_json="{\"name\": \"$folder_name\"}"
    if echo "$folder_json" | bw encode | bw create folder --session "$session" >/dev/null 2>&1; then
        pass "Created folder '$folder_name' in Bitwarden"
        return 0
    else
        fail "Failed to create folder '$folder_name'"
        return 1
    fi
}

# List items in a specific folder
# Usage: vault_backend_list_items_in_location "folder" "dotfiles" "$SESSION"
vault_backend_list_items_in_location() {
    local loc_type="$1"
    local loc_value="$2"
    local session="$3"

    if [[ -z "$session" ]]; then
        fail "Session required for listing items"
        return 1
    fi

    case "$loc_type" in
        folder)
            if [[ -z "$loc_value" ]]; then
                # No folder specified, list all
                vault_backend_list_items "$session"
                return
            fi

            # Get folder ID
            local folder_id
            folder_id=$(_bw_get_folder_id "$loc_value" "$session")

            if [[ -z "$folder_id" ]]; then
                warn "Folder '$loc_value' not found"
                echo "[]"
                return 1
            fi

            # List items in folder
            bw list items --folderid "$folder_id" --session "$session" 2>/dev/null || echo "[]"
            ;;

        prefix)
            # Filter by name prefix
            if [[ -z "$loc_value" ]]; then
                vault_backend_list_items "$session"
                return
            fi

            bw list items --session "$session" 2>/dev/null | \
                jq "[.[] | select(.name | startswith(\"$loc_value\"))]" || echo "[]"
            ;;

        none|"")
            # No location filter, list all
            vault_backend_list_items "$session"
            ;;

        *)
            warn "Unknown location type: $loc_type"
            vault_backend_list_items "$session"
            ;;
    esac
}

# Create item in a specific folder
# Usage: vault_backend_create_item_in_location "Item-Name" "content" "folder_name" "$SESSION"
vault_backend_create_item_in_location() {
    local item_name="$1"
    local content="$2"
    local folder_name="$3"
    local session="$4"

    if [[ -z "$item_name" || -z "$session" ]]; then
        fail "Item name and session required"
        return 1
    fi

    # Check if item already exists
    if vault_backend_item_exists "$item_name" "$session"; then
        fail "Item '$item_name' already exists. Use update instead."
        return 1
    fi

    # Get folder ID if specified
    local folder_id=""
    if [[ -n "$folder_name" ]]; then
        folder_id=$(_bw_get_folder_id "$folder_name" "$session")
        if [[ -z "$folder_id" ]]; then
            # Create the folder first
            vault_backend_create_location "$folder_name" "$session" || return 1
            folder_id=$(_bw_get_folder_id "$folder_name" "$session")
        fi
    fi

    # Create secure note JSON template
    local json_template
    if [[ -n "$folder_id" ]]; then
        json_template=$(cat <<EOF
{
    "type": 2,
    "secureNote": {"type": 0},
    "name": "$item_name",
    "notes": "",
    "folderId": "$folder_id",
    "favorite": false
}
EOF
)
    else
        json_template=$(cat <<EOF
{
    "type": 2,
    "secureNote": {"type": 0},
    "name": "$item_name",
    "notes": "",
    "favorite": false
}
EOF
)
    fi

    # Add content to notes field
    local json_with_content
    json_with_content=$(printf '%s' "$json_template" | jq --arg notes "$content" '.notes = $notes')

    # Create the item
    if printf '%s' "$json_with_content" | bw encode | bw create item --session "$session" >/dev/null 2>&1; then
        if [[ -n "$folder_name" ]]; then
            pass "Created item '$item_name' in folder '$folder_name'"
        else
            pass "Created item '$item_name' in Bitwarden"
        fi
        return 0
    else
        fail "Failed to create item '$item_name'"
        return 1
    fi
}
