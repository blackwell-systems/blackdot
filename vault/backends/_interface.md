# Vault Backend Interface Specification

This document defines the contract that all vault backends must implement.

## Overview

The vault abstraction layer allows dotfiles to work with multiple secret management backends (Bitwarden, 1Password, pass, HashiCorp Vault, etc.) without changing the core logic.

## Environment Variable

```bash
DOTFILES_VAULT_BACKEND="${DOTFILES_VAULT_BACKEND:-bitwarden}"
```

## Required Functions

Every backend MUST implement these functions:

### `vault_backend_init`

Initialize the backend and verify prerequisites.

```bash
vault_backend_init()
# Returns: 0 on success, 1 on failure
# Side effects: May set backend-specific variables
# Should check: CLI tool installed, minimum version, etc.
```

### `vault_backend_name`

Return the human-readable backend name.

```bash
vault_backend_name()
# Returns: String (e.g., "Bitwarden", "1Password")
# Example: echo "Bitwarden"
```

### `vault_backend_login_check`

Check if the user is logged in to the vault.

```bash
vault_backend_login_check()
# Returns: 0 if logged in, 1 if not
# Should NOT prompt for login
```

### `vault_backend_get_session`

Get or create a session token for authenticated operations.

```bash
vault_backend_get_session()
# Returns: Session token string (stdout)
# May prompt: For master password if needed
# Side effects: May cache session to file
# Exit: On failure to authenticate
```

### `vault_backend_sync`

Synchronize local vault cache with remote server.

```bash
vault_backend_sync(session)
# Args: session - Session token
# Returns: 0 on success, 1 on failure
# For local-only backends (pass): No-op, return 0
```

### `vault_backend_get_item`

Get full item data as JSON.

```bash
vault_backend_get_item(item_name, session)
# Args: item_name - Name of the item
#       session   - Session token
# Returns: JSON string (stdout) or empty string if not found
# Format: Must include at minimum: { "id": "...", "name": "...", "notes": "..." }
```

### `vault_backend_get_notes`

Get the notes/content field of an item.

```bash
vault_backend_get_notes(item_name, session)
# Args: item_name - Name of the item
#       session   - Session token
# Returns: Content string (stdout) or empty if not found
```

### `vault_backend_item_exists`

Check if an item exists in the vault.

```bash
vault_backend_item_exists(item_name, session)
# Args: item_name - Name of the item
#       session   - Session token
# Returns: 0 if exists, 1 if not
```

### `vault_backend_list_items`

List all items in the vault.

```bash
vault_backend_list_items(session)
# Args: session - Session token
# Returns: JSON array of items (stdout)
# Format: [{"id": "...", "name": "...", "type": ...}, ...]
```

### `vault_backend_create_item`

Create a new secure note item.

```bash
vault_backend_create_item(item_name, content, session)
# Args: item_name - Name for the new item
#       content   - Notes/content to store
#       session   - Session token
# Returns: 0 on success, 1 on failure
# Behavior: Should fail if item already exists (use update instead)
```

### `vault_backend_update_item`

Update an existing item's content.

```bash
vault_backend_update_item(item_name, content, session)
# Args: item_name - Name of the item to update
#       content   - New notes/content
#       session   - Session token
# Returns: 0 on success, 1 on failure
```

### `vault_backend_delete_item`

Delete an item from the vault.

```bash
vault_backend_delete_item(item_name, session)
# Args: item_name - Name of the item to delete
#       session   - Session token
# Returns: 0 on success, 1 on failure
```

## Optional Functions

Backends MAY implement these for enhanced functionality:

### `vault_backend_get_item_id`

Get the unique ID of an item (some backends need this for updates).

```bash
vault_backend_get_item_id(item_name, session)
# Returns: Item ID string or empty
```

### `vault_backend_health_check`

Perform backend-specific health diagnostics.

```bash
vault_backend_health_check()
# Returns: 0 if healthy, 1 if issues detected
# Output: Diagnostic messages to stdout
```

### `vault_backend_get_attachment`

Get an attachment from an item (for backends that support it).

```bash
vault_backend_get_attachment(item_name, attachment_name, session)
# Returns: Attachment content (stdout)
```

## Session Management

- Session tokens should be cached in `$VAULT_DIR/.vault-session`
- File permissions must be 600 (owner read/write only)
- Backends should validate cached sessions before use
- Invalid sessions should trigger re-authentication

## Error Handling

- All functions should use `set -euo pipefail` error handling
- Failures should output error messages to stderr
- Return codes: 0 = success, 1 = failure
- Critical failures may call `exit 1`

## Item Storage Convention

All backends should store dotfiles secrets as "secure notes" or equivalent:
- Item name: Exact match (e.g., "Git-Config", "SSH-GitHub-Enterprise")
- Content: Stored in notes/content field
- Type: Secure note (not login, card, or identity)

## Example Backend Template

```bash
#!/usr/bin/env zsh
# vault/backends/example.sh - Example backend implementation

vault_backend_init() {
    if ! command -v example-cli >/dev/null 2>&1; then
        fail "example-cli is not installed"
        return 1
    fi
    return 0
}

vault_backend_name() {
    echo "Example Vault"
}

vault_backend_login_check() {
    example-cli status >/dev/null 2>&1
}

vault_backend_get_session() {
    # Implementation here
}

# ... implement all required functions
```

## Supported Backends

| Backend | CLI Tool | Status |
|---------|----------|--------|
| Bitwarden | `bw` | Implemented |
| 1Password | `op` | Implemented |
| pass | `pass` | Implemented |
| HashiCorp Vault | `vault` | Planned |
| AWS Secrets Manager | `aws` | Planned |

## Testing Backends

Each backend should be testable with:

```bash
# Set backend
export DOTFILES_VAULT_BACKEND=example

# Test basic operations
source lib/_vault.sh
vault_init
vault_get_session
vault_list_items "$SESSION"
```
