# Extending Vault Backends

> **Add support for any secret management tool**

The dotfiles vault system uses a pluggable backend architecture. This guide explains how to add support for a new vault provider.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        dotfiles vault                           │
├─────────────────────────────────────────────────────────────────┤
│                       lib/_vault.sh                             │
│                    (Abstraction Layer)                          │
│         vault_get_item(), vault_sync(), vault_login_check()     │
├──────────┬──────────┬──────────┬──────────┬────────────────────┤
│ bitwarden│ 1password│   pass   │  (your)  │      ...           │
│   .sh    │    .sh   │   .sh    │   .sh    │                    │
└──────────┴──────────┴──────────┴──────────┴────────────────────┘
           vault/backends/*.sh
```

**Key concepts:**

1. **Abstraction layer** (`lib/_vault.sh`) - Provides unified API for all vault operations
2. **Backend implementations** (`vault/backends/*.sh`) - Provider-specific logic
3. **Environment variable** - `BLACKDOT_VAULT_BACKEND` selects which backend to use

---

## Quick Start: Create a New Backend

### Step 1: Create the backend file

```bash
# Create your backend file
touch vault/backends/mybackend.sh
chmod +x vault/backends/mybackend.sh
```

### Step 2: Implement required functions

Every backend must implement these 12 functions:

| Function | Purpose |
|----------|---------|
| `vault_backend_init` | Check prerequisites (CLI installed, etc.) |
| `vault_backend_name` | Return human-readable name |
| `vault_backend_login_check` | Check if user is authenticated |
| `vault_backend_get_session` | Get/create session token |
| `vault_backend_sync` | Sync with remote (or no-op) |
| `vault_backend_get_item` | Get item as JSON |
| `vault_backend_get_notes` | Get item content/notes |
| `vault_backend_item_exists` | Check if item exists |
| `vault_backend_list_items` | List all items |
| `vault_backend_create_item` | Create new item |
| `vault_backend_update_item` | Update existing item |
| `vault_backend_delete_item` | Delete item |

### Step 3: Test your backend

```bash
# Set your backend
export BLACKDOT_VAULT_BACKEND=mybackend

# Test it
blackdot vault list
blackdot doctor
```

---

## Complete Example: HashiCorp Vault Backend

Here's a full implementation for HashiCorp Vault:

```bash
#!/usr/bin/env zsh
# vault/backends/hashicorp.sh
# HashiCorp Vault backend implementation

# ============================================================
# Configuration
# ============================================================

# Secret engine path (default: kv-v2 at secret/)
HCV_ENGINE="${HCV_ENGINE:-secret}"
HCV_PATH="${HCV_PATH:-dotfiles}"

# ============================================================
# Backend Metadata
# ============================================================

vault_backend_name() {
    echo "HashiCorp Vault"
}

# ============================================================
# Initialization
# ============================================================

vault_backend_init() {
    # Check for vault CLI
    if ! command -v vault >/dev/null 2>&1; then
        fail "HashiCorp Vault CLI is not installed"
        echo "Install with: brew install vault" >&2
        return 1
    fi

    # Check VAULT_ADDR is set
    if [[ -z "${VAULT_ADDR:-}" ]]; then
        fail "VAULT_ADDR environment variable not set"
        echo "Set with: export VAULT_ADDR=https://vault.example.com" >&2
        return 1
    fi

    return 0
}

# ============================================================
# Authentication
# ============================================================

vault_backend_login_check() {
    # Check if token is valid
    vault token lookup >/dev/null 2>&1
}

vault_backend_get_session() {
    # HashiCorp Vault uses VAULT_TOKEN env var
    # Return existing token or empty (vault CLI handles auth)
    if [[ -n "${VAULT_TOKEN:-}" ]]; then
        echo "$VAULT_TOKEN"
        return 0
    fi

    # Check if logged in
    if ! vault token lookup >/dev/null 2>&1; then
        fail "Not authenticated to HashiCorp Vault"
        echo "Please run: vault login" >&2
        return 1
    fi

    # Token is in vault's config
    echo ""
    return 0
}

# ============================================================
# Vault Sync
# ============================================================

vault_backend_sync() {
    # HashiCorp Vault is server-based, no sync needed
    return 0
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

    local secret_path="$HCV_ENGINE/data/$HCV_PATH/$item_name"

    # Get secret and format as expected JSON
    local result
    result=$(vault kv get -format=json "$HCV_ENGINE/$HCV_PATH/$item_name" 2>/dev/null) || return 0

    # Transform to our standard format
    printf '%s' "$result" | jq '{
        id: .request_id,
        name: "'"$item_name"'",
        type: 2,
        notes: .data.data.content
    }'
}

vault_backend_get_notes() {
    local item_name="$1"
    local session="$2"

    vault kv get -field=content "$HCV_ENGINE/$HCV_PATH/$item_name" 2>/dev/null || echo ""
}

vault_backend_item_exists() {
    local item_name="$1"
    local session="$2"

    vault kv get "$HCV_ENGINE/$HCV_PATH/$item_name" >/dev/null 2>&1
}

vault_backend_get_item_id() {
    local item_name="$1"
    # HashiCorp Vault uses paths as IDs
    echo "$HCV_ENGINE/$HCV_PATH/$item_name"
}

vault_backend_list_items() {
    local session="$1"

    # List keys and format as JSON array
    vault kv list -format=json "$HCV_ENGINE/$HCV_PATH" 2>/dev/null | jq '[.[] | {
        id: ("'"$HCV_ENGINE/$HCV_PATH/"'" + .),
        name: .,
        type: 2
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

    # Check if exists
    if vault_backend_item_exists "$item_name" "$session"; then
        fail "Item '$item_name' already exists. Use update instead."
        return 1
    fi

    # Create secret
    if vault kv put "$HCV_ENGINE/$HCV_PATH/$item_name" content="$content" >/dev/null 2>&1; then
        pass "Created item '$item_name' in HashiCorp Vault"
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

    # Update secret (kv put overwrites)
    if vault kv put "$HCV_ENGINE/$HCV_PATH/$item_name" content="$content" >/dev/null 2>&1; then
        pass "Updated item '$item_name' in HashiCorp Vault"
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

    if vault kv delete "$HCV_ENGINE/$HCV_PATH/$item_name" >/dev/null 2>&1; then
        pass "Deleted item '$item_name' from HashiCorp Vault"
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
    if command -v vault >/dev/null 2>&1; then
        local version
        version=$(vault version 2>/dev/null | head -1)
        pass "HashiCorp Vault CLI installed ($version)"
    else
        fail "HashiCorp Vault CLI not installed"
        status=1
    fi

    # Check VAULT_ADDR
    if [[ -n "${VAULT_ADDR:-}" ]]; then
        pass "VAULT_ADDR set: $VAULT_ADDR"
    else
        fail "VAULT_ADDR not set"
        status=1
    fi

    # Check authentication
    if vault token lookup >/dev/null 2>&1; then
        pass "Authenticated to HashiCorp Vault"
    else
        warn "Not authenticated to HashiCorp Vault"
        status=1
    fi

    return $status
}
```

---

## Function Reference

### Required Functions

#### `vault_backend_init`

Called once when the backend is loaded. Check prerequisites and fail fast if something is missing.

```bash
vault_backend_init() {
    if ! command -v mycli >/dev/null 2>&1; then
        fail "mycli is not installed"
        echo "Install with: brew install mycli" >&2
        return 1
    fi
    return 0
}
```

#### `vault_backend_name`

Return a human-readable name for display in status messages.

```bash
vault_backend_name() {
    echo "My Secret Manager"
}
```

#### `vault_backend_get_session`

Get or create an authentication token. May prompt the user for credentials.

```bash
vault_backend_get_session() {
    # Try cached token first
    local session_file="${VAULT_SESSION_FILE:-$BLACKDOT_DIR/vault/.vault-session}"

    if [[ -f "$session_file" ]]; then
        local cached=$(cat "$session_file")
        if mycli validate-token "$cached" 2>/dev/null; then
            echo "$cached"
            return 0
        fi
    fi

    # Need to authenticate
    local token
    token=$(mycli login --raw)

    if [[ -n "$token" ]]; then
        # Cache with secure permissions
        (umask 077 && printf '%s' "$token" > "$session_file")
        echo "$token"
        return 0
    fi

    fail "Failed to authenticate"
    return 1
}
```

#### `vault_backend_get_notes`

Get the content/notes of an item. This is what gets written to config files during restore.

```bash
vault_backend_get_notes(item_name, session) {
    local item_name="$1"
    local session="$2"

    mycli get "$item_name" --field content --session "$session" 2>/dev/null || echo ""
}
```

### Optional Functions

#### `vault_backend_health_check`

Provide detailed diagnostics for `blackdot doctor`.

```bash
vault_backend_health_check() {
    local status=0

    if command -v mycli >/dev/null 2>&1; then
        pass "mycli installed"
    else
        fail "mycli not installed"
        status=1
    fi

    # Add more checks...

    return $status
}
```

#### `vault_backend_get_attachment`

Support for file attachments (not all backends support this).

```bash
vault_backend_get_attachment(item_name, attachment_name, session) {
    # Return raw file content to stdout
}
```

---

## JSON Format Convention

The `vault_backend_get_item` function should return JSON with at least these fields:

```json
{
    "id": "unique-identifier",
    "name": "Git-Config",
    "type": 2,
    "notes": "actual file content here..."
}
```

Where `type: 2` indicates a "secure note" (borrowed from Bitwarden's type system).

---

## Item Naming Convention

blackdot expects these item names in the vault:

| Item Name | Local Path | Description |
|-----------|------------|-------------|
| `Git-Config` | `~/.gitconfig` | Git configuration |
| `SSH-Config` | `~/.ssh/config` | SSH configuration |
| `SSH-GitHub-Enterprise` | `~/.ssh/id_ed25519_enterprise` | SSH key (private + public) |
| `AWS-Config` | `~/.aws/config` | AWS CLI config |
| `AWS-Credentials` | `~/.aws/credentials` | AWS credentials |
| `Environment-Secrets` | `~/.local/env.secrets` | Environment variables |

SSH key items should contain both private and public key in the notes field:

```
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
ssh-ed25519 AAAA... comment
```

---

## Testing Your Backend

### Manual Testing

```bash
# Set your backend
export BLACKDOT_VAULT_BACKEND=mybackend

# Source the abstraction layer
source lib/_vault.sh

# Initialize
vault_init

# Get session
SESSION=$(vault_get_session)

# Test operations
vault_list_items "$SESSION"
vault_get_notes "Git-Config" "$SESSION"
vault_item_exists "SSH-Config" "$SESSION" && echo "exists"
```

### Integration Testing

```bash
# Full integration test
export BLACKDOT_VAULT_BACKEND=mybackend

# Should work with all vault commands
blackdot vault list
blackdot vault pull --dry-run
blackdot sync --dry-run
blackdot doctor
blackdot drift
```

---

## Tips

1. **Fail fast** - Check prerequisites in `vault_backend_init` and fail with helpful messages
2. **Handle missing items gracefully** - Return empty strings, not errors
3. **Cache sessions securely** - Use 600 permissions on session files
4. **Use jq for JSON** - All backends assume jq is available
5. **Test offline behavior** - `BLACKDOT_OFFLINE=1` should skip vault operations gracefully

---

## Existing Backends

| Backend | File | CLI | Status |
|---------|------|-----|--------|
| Bitwarden | `bitwarden.sh` | `bw` | Production |
| 1Password | `1password.sh` | `op` | Production |
| pass | `pass.sh` | `pass` + `gpg` | Production |

---

## Interface Specification

For the complete technical specification, see [`vault/backends/_interface.md`](https://github.com/blackwell-systems/blackdot/blob/main/vault/backends/_interface.md).

---

## Contributing

To contribute a new backend:

1. Create `vault/backends/yourbackend.sh`
2. Implement all required functions
3. Add health check function
4. Test thoroughly
5. Update this documentation
6. Submit a pull request
