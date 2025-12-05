#!/usr/bin/env zsh
# ============================================================
# FILE: vault/backends/pass.sh
# pass (the standard Unix password manager) backend
# Implements the interface defined in _interface.md
# Requires: pass, gpg
# ============================================================

# ============================================================
# Backend Configuration
# ============================================================

# Prefix for dotfiles items in pass store
# Items will be stored as: dotfiles/Git-Config, dotfiles/SSH-Config, etc.
PASS_PREFIX="${PASS_PREFIX:-dotfiles}"

# Password store location (default: ~/.password-store)
PASSWORD_STORE_DIR="${PASSWORD_STORE_DIR:-$HOME/.password-store}"

# ============================================================
# Backend Metadata
# ============================================================

vault_backend_name() {
    echo "pass"
}

# ============================================================
# Initialization
# ============================================================

vault_backend_init() {
    # Check for pass
    if ! command -v pass >/dev/null 2>&1; then
        fail "pass is not installed"
        echo "Install with: brew install pass" >&2
        return 1
    fi

    # Check for gpg
    if ! command -v gpg >/dev/null 2>&1; then
        fail "gpg is not installed (required for pass)"
        echo "Install with: brew install gnupg" >&2
        return 1
    fi

    # Check password store exists
    if [[ ! -d "$PASSWORD_STORE_DIR" ]]; then
        warn "Password store not initialized at $PASSWORD_STORE_DIR"
        echo "Initialize with: pass init <gpg-id>" >&2
        return 1
    fi

    return 0
}

# ============================================================
# Authentication
# ============================================================

vault_backend_login_check() {
    # pass uses GPG, check if we have a valid GPG key
    # and can access the password store
    if [[ -d "$PASSWORD_STORE_DIR" ]]; then
        # Try to list (this may trigger gpg-agent)
        # Use 'command pass' to avoid shadowing by pass() logging function
        command pass ls >/dev/null 2>&1
        return $?
    fi
    return 1
}

vault_backend_get_session() {
    # pass doesn't use sessions - GPG agent handles auth
    # Return empty string (pass operations will prompt for GPG passphrase if needed)
    echo ""
    return 0
}

# ============================================================
# Vault Sync
# ============================================================

vault_backend_sync() {
    local session="${1:-}"  # Unused for pass

    # pass can use git for sync
    if [[ -d "$PASSWORD_STORE_DIR/.git" ]]; then
        info "Syncing password store with git..."
        (
            cd "$PASSWORD_STORE_DIR"
            git pull --rebase 2>/dev/null || true
            git push 2>/dev/null || true
        )
    fi

    # pass is local-first, sync is optional
    return 0
}

# ============================================================
# Helper: Get full pass path for item
# ============================================================

_pass_path() {
    local item_name="$1"
    echo "$PASS_PREFIX/$item_name"
}

# ============================================================
# Item Operations
# ============================================================

vault_backend_get_item() {
    local item_name="$1"
    local session="$2"  # Unused

    if [[ -z "$item_name" ]]; then
        return 1
    fi

    local pass_path
    pass_path=$(_pass_path "$item_name")

    # Check if exists
    if [[ ! -f "$PASSWORD_STORE_DIR/${pass_path}.gpg" ]]; then
        echo ""
        return 0
    fi

    # Get content and format as JSON
    local content
    content=$(command pass show "$pass_path" 2>/dev/null)

    if [[ -n "$content" ]]; then
        # Create JSON structure similar to other backends
        # Use jq to properly escape content
        printf '%s' "$content" | jq -Rs '{
            id: "'"$pass_path"'",
            name: "'"$item_name"'",
            type: 2,
            notes: .
        }'
    fi
}

vault_backend_get_notes() {
    local item_name="$1"
    local session="$2"  # Unused

    if [[ -z "$item_name" ]]; then
        return 1
    fi

    local pass_path
    pass_path=$(_pass_path "$item_name")

    # Get content directly
    command pass show "$pass_path" 2>/dev/null || echo ""
}

vault_backend_item_exists() {
    local item_name="$1"
    local session="$2"  # Unused

    local pass_path
    pass_path=$(_pass_path "$item_name")

    [[ -f "$PASSWORD_STORE_DIR/${pass_path}.gpg" ]]
}

vault_backend_get_item_id() {
    local item_name="$1"
    # For pass, the "id" is just the path
    _pass_path "$item_name"
}

vault_backend_list_items() {
    local session="${1:-}"  # Unused

    # List all items under our prefix
    local items_json="[]"

    if [[ -d "$PASSWORD_STORE_DIR/$PASS_PREFIX" ]]; then
        # Find all .gpg files and convert to JSON array
        items_json=$(find "$PASSWORD_STORE_DIR/$PASS_PREFIX" -name "*.gpg" -type f 2>/dev/null | while read -r file; do
            # Extract item name from path
            local rel_path="${file#$PASSWORD_STORE_DIR/$PASS_PREFIX/}"
            local item_name="${rel_path%.gpg}"
            echo "$item_name"
        done | jq -Rs 'split("\n") | map(select(length > 0)) | map({
            id: ("'"$PASS_PREFIX"'/" + .),
            name: .,
            type: 2
        })')
    fi

    echo "$items_json"
}

# ============================================================
# Item Modification
# ============================================================

vault_backend_create_item() {
    local item_name="$1"
    local content="$2"
    local session="$3"  # Unused

    if [[ -z "$item_name" ]]; then
        fail "Item name required"
        return 1
    fi

    local pass_path
    pass_path=$(_pass_path "$item_name")

    # Check if exists
    if [[ -f "$PASSWORD_STORE_DIR/${pass_path}.gpg" ]]; then
        fail "Item '$item_name' already exists. Use update instead."
        return 1
    fi

    # Create parent directory if needed
    local parent_dir
    parent_dir=$(dirname "$PASSWORD_STORE_DIR/${pass_path}.gpg")
    mkdir -p "$parent_dir"

    # Insert content (pass insert with -m for multiline)
    if printf '%s' "$content" | command pass insert -m "$pass_path" >/dev/null 2>&1; then
        pass "Created item '$item_name' in pass"
        return 0
    else
        fail "Failed to create item '$item_name'"
        return 1
    fi
}

vault_backend_update_item() {
    local item_name="$1"
    local content="$2"
    local session="$3"  # Unused

    if [[ -z "$item_name" ]]; then
        fail "Item name required"
        return 1
    fi

    local pass_path
    pass_path=$(_pass_path "$item_name")

    # Check if exists
    if [[ ! -f "$PASSWORD_STORE_DIR/${pass_path}.gpg" ]]; then
        fail "Item '$item_name' not found"
        return 1
    fi

    # Update by overwriting (pass insert -f for force)
    if printf '%s' "$content" | command pass insert -m -f "$pass_path" >/dev/null 2>&1; then
        pass "Updated item '$item_name' in pass"
        return 0
    else
        fail "Failed to update item '$item_name'"
        return 1
    fi
}

vault_backend_delete_item() {
    local item_name="$1"
    local session="$2"  # Unused

    if [[ -z "$item_name" ]]; then
        fail "Item name required"
        return 1
    fi

    local pass_path
    pass_path=$(_pass_path "$item_name")

    # Check if exists
    if [[ ! -f "$PASSWORD_STORE_DIR/${pass_path}.gpg" ]]; then
        fail "Item '$item_name' not found"
        return 1
    fi

    # Delete (pass rm -f for force, no prompt)
    if command pass rm -f "$pass_path" >/dev/null 2>&1; then
        pass "Deleted item '$item_name' from pass"
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

    # Check pass installed
    if command -v pass >/dev/null 2>&1; then
        local version
        version=$(command pass version 2>/dev/null | head -1 || echo "unknown")
        pass "pass installed ($version)"
    else
        fail "pass not installed"
        status=1
    fi

    # Check gpg
    if command -v gpg >/dev/null 2>&1; then
        local gpg_version
        gpg_version=$(gpg --version 2>/dev/null | head -1 || echo "unknown")
        pass "gpg installed ($gpg_version)"
    else
        fail "gpg not installed"
        status=1
    fi

    # Check password store
    if [[ -d "$PASSWORD_STORE_DIR" ]]; then
        local item_count
        item_count=$(find "$PASSWORD_STORE_DIR" -name "*.gpg" -type f 2>/dev/null | wc -l | tr -d ' ')
        pass "Password store exists ($item_count items)"
    else
        fail "Password store not found at $PASSWORD_STORE_DIR"
        status=1
    fi

    # Check dotfiles prefix exists
    if [[ -d "$PASSWORD_STORE_DIR/$PASS_PREFIX" ]]; then
        local dotfiles_count
        dotfiles_count=$(find "$PASSWORD_STORE_DIR/$PASS_PREFIX" -name "*.gpg" -type f 2>/dev/null | wc -l | tr -d ' ')
        pass "Dotfiles prefix exists ($dotfiles_count items)"
    else
        info "Dotfiles prefix '$PASS_PREFIX' not yet created"
    fi

    # Check GPG agent
    if gpg-connect-agent /bye >/dev/null 2>&1; then
        pass "GPG agent running"
    else
        warn "GPG agent not running (may prompt for passphrase)"
    fi

    return $status
}

# ============================================================
# Location Management (v3.1)
# Directory-based organization for pass
# ============================================================

# List available directories (top-level prefixes)
# Returns: JSON array of directory names
vault_backend_list_locations() {
    local session="${1:-}"  # Unused for pass

    # Find top-level directories in password store
    local dirs=()
    if [[ -d "$PASSWORD_STORE_DIR" ]]; then
        while IFS= read -r dir; do
            [[ -n "$dir" ]] && dirs+=("$dir")
        done < <(find "$PASSWORD_STORE_DIR" -maxdepth 1 -type d -not -name ".*" -not -path "$PASSWORD_STORE_DIR" 2>/dev/null | xargs -n1 basename 2>/dev/null)
    fi

    # Output as JSON array
    if [[ ${#dirs[@]} -eq 0 ]]; then
        echo "[]"
    else
        printf '%s\n' "${dirs[@]}" | jq -R . | jq -s .
    fi
}

# Check if a directory exists
vault_backend_location_exists() {
    local dir_name="${1:-}"
    local session="${2:-}"  # Unused

    [[ -n "$dir_name" ]] && [[ -d "$PASSWORD_STORE_DIR/$dir_name" ]]
}

# Create a new directory
vault_backend_create_location() {
    local dir_name="${1:-}"
    local session="${2:-}"  # Unused

    if [[ -z "$dir_name" ]]; then
        fail "Directory name required"
        return 1
    fi

    local full_path="$PASSWORD_STORE_DIR/$dir_name"

    if [[ -d "$full_path" ]]; then
        info "Directory '$dir_name' already exists"
        return 0
    fi

    if mkdir -p "$full_path"; then
        pass "Created directory '$dir_name' in password store"
        return 0
    else
        fail "Failed to create directory '$dir_name'"
        return 1
    fi
}

# List items in a specific directory
# Usage: vault_backend_list_items_in_location "directory" "dotfiles" "$SESSION"
vault_backend_list_items_in_location() {
    local loc_type="${1:-}"
    local loc_value="${2:-}"
    local session="${3:-}"  # Unused

    case "$loc_type" in
        directory)
            if [[ -z "$loc_value" ]]; then
                # No directory specified, use default prefix
                loc_value="$PASS_PREFIX"
            fi

            local search_dir="$PASSWORD_STORE_DIR/$loc_value"

            if [[ ! -d "$search_dir" ]]; then
                echo "[]"
                return 0
            fi

            # Find all .gpg files and convert to JSON array
            find "$search_dir" -name "*.gpg" -type f 2>/dev/null | while read -r file; do
                # Extract item name from path
                local rel_path="${file#$PASSWORD_STORE_DIR/$loc_value/}"
                local item_name="${rel_path%.gpg}"
                echo "$item_name"
            done | jq -R . | jq -s 'map({name: ., type: 2, id: .})'
            ;;

        none|"")
            # No location filter, use default prefix
            vault_backend_list_items "$session"
            ;;

        *)
            warn "Unknown location type for pass: $loc_type (use 'directory')"
            vault_backend_list_items "$session"
            ;;
    esac
}

# Create item in a specific directory
# Usage: vault_backend_create_item_in_location "Item-Name" "content" "directory" "$SESSION"
vault_backend_create_item_in_location() {
    local item_name="$1"
    local content="$2"
    local dir_name="$3"
    local session="$4"  # Unused

    if [[ -z "$item_name" ]]; then
        fail "Item name required"
        return 1
    fi

    # Use specified directory or default prefix
    local prefix="${dir_name:-$PASS_PREFIX}"
    local pass_path="$prefix/$item_name"

    # Check if exists
    if [[ -f "$PASSWORD_STORE_DIR/${pass_path}.gpg" ]]; then
        fail "Item '$item_name' already exists in '$prefix'. Use update instead."
        return 1
    fi

    # Create parent directory if needed
    local parent_dir
    parent_dir=$(dirname "$PASSWORD_STORE_DIR/${pass_path}.gpg")
    mkdir -p "$parent_dir"

    # Insert content
    if printf '%s' "$content" | command pass insert -m "$pass_path" >/dev/null 2>&1; then
        pass "Created item '$item_name' in directory '$prefix'"
        return 0
    else
        fail "Failed to create item '$item_name'"
        return 1
    fi
}
