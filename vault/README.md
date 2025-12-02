# Vault Bootstrap System

This directory contains scripts for **bidirectional secret management** with multiple vault backends:

- **Restore scripts** pull secrets from your vault → local files
- **Sync/Create scripts** push local changes → your vault
- **Utility scripts** for validation, debugging, deletion, and inventory
- **Shared library** (`_common.sh`) with reusable functions
- **Backend abstraction** supporting Bitwarden, 1Password, and pass

---

## Supported Backends

| Backend | CLI Tool | Status | Description |
|---------|----------|--------|-------------|
| **Bitwarden** | `bw` | Default | Full-featured, cloud-synced |
| **1Password** | `op` | Supported | v2 CLI with biometric auth |
| **pass** | `pass` | Supported | GPG-based, git-synced |

### Switching Backends

```bash
# Set your preferred backend (add to ~/.zshrc or ~/.zshenv)
export DOTFILES_VAULT_BACKEND=bitwarden  # default
export DOTFILES_VAULT_BACKEND=1password
export DOTFILES_VAULT_BACKEND=pass

# For 1Password, optionally set vault name
export ONEPASSWORD_VAULT=Personal  # default

# For pass, optionally set prefix
export PASS_PREFIX=dotfiles  # default, items stored as dotfiles/Git-Config
```

All `dotfiles vault` commands work identically regardless of backend.

---

## Quick Reference

| Script | Purpose | Command |
|--------|---------|---------|
| `restore.sh` | Orchestrates all restores | `dotfiles vault restore` |
| `restore-ssh.sh` | Restores SSH keys + config | Called by bootstrap |
| `restore-aws.sh` | Restores AWS config/creds | Called by bootstrap |
| `restore-env.sh` | Restores env secrets | Called by bootstrap |
| `restore-git.sh` | Restores gitconfig | Called by bootstrap |
| `create-vault-item.sh` | Creates new vault items | `dotfiles vault create ITEM` |
| `sync-to-vault.sh` | Syncs local → vault | `dotfiles vault sync --all` |
| `validate-schema.sh` | Validates vault item schema | `dotfiles vault validate` |
| `delete-vault-item.sh` | Deletes items from vault | `dotfiles vault delete ITEM` |
| `check-vault-items.sh` | Pre-flight validation | `dotfiles vault check` |
| `list-vault-items.sh` | Debug/inventory tool | `dotfiles vault list` |
| `_common.sh` | Shared functions library | Sourced by other scripts |

### Commands

All vault operations are accessed via the unified `dotfiles vault` command:

```bash
dotfiles vault restore          # Restore all secrets (checks for local drift first)
dotfiles vault restore --force  # Skip drift check, overwrite local changes
dotfiles vault sync             # Sync local changes to vault
dotfiles vault sync --all       # Sync all items
dotfiles vault create           # Create new vault item
dotfiles vault validate         # Validate vault item schema
dotfiles vault delete           # Delete vault item
dotfiles vault list             # List all vault items
dotfiles vault check            # Validate required items exist
```

---

## Backend Setup

### Bitwarden (Default)

```bash
# Install CLI
brew install bitwarden-cli

# Login (one-time)
bw login

# Verify
bw login --check
```

### 1Password

```bash
# Install CLI
brew install --cask 1password-cli

# Sign in (uses biometric on macOS)
op signin

# Set backend
export DOTFILES_VAULT_BACKEND=1password

# Optionally specify vault
export ONEPASSWORD_VAULT=Personal
```

### pass (Standard Unix Password Manager)

```bash
# Install
brew install pass gnupg

# Initialize with your GPG key
pass init "your-gpg-id@email.com"

# Set backend
export DOTFILES_VAULT_BACKEND=pass

# Items will be stored under dotfiles/ prefix
# e.g., dotfiles/Git-Config, dotfiles/SSH-Config
```

---

## Scripts

### `restore.sh`

**Main entry point** - orchestrates all secret restoration.

```bash
dotfiles vault restore          # Normal restore (checks for drift)
dotfiles vault restore --force  # Skip drift check
```

**What it does:**
1. Initializes the configured vault backend
2. Checks/prompts for vault unlock
3. Caches session to `.vault-session` (secure permissions)
4. **Checks for local drift** - warns if local files differ from vault
5. Calls each restore script in sequence

**Pre-restore drift check:** Before overwriting local files, the script checks if they've changed since the last vault sync. If drift is detected, you'll be prompted to either:
- Sync local changes first (`dotfiles vault sync`)
- Force the restore (`--force` flag)
- Review differences (`dotfiles drift`)

**Skip drift check for automation:**
```bash
DOTFILES_SKIP_DRIFT_CHECK=1 dotfiles vault restore
```

**Offline mode:** For air-gapped environments or when vault is unavailable:
```bash
DOTFILES_OFFLINE=1 dotfiles vault restore  # Exits gracefully, keeps local files
```

**When to use:** New machine setup, or after secrets change in your vault.

---

### `restore-ssh.sh`

Restores SSH keys and config from vault.

**Vault items:**

| Item Name | Contains | Writes To |
|-----------|----------|-----------|
| `SSH-GitHub-Enterprise` | Private + public key | `~/.ssh/id_ed25519_enterprise_ghub{,.pub}` |
| `SSH-GitHub-Blackwell` | Private + public key | `~/.ssh/id_ed25519_blackwell{,.pub}` |
| `SSH-Config` | Full SSH config | `~/.ssh/config` |

**Notes field format for SSH keys:**
```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAA...
-----END OPENSSH PRIVATE KEY-----

ssh-ed25519 AAAAC3NzaC1lZDI1... username@hostname
```

**Permissions:** Private keys `600`, public keys `644`, config `600`

---

### `restore-aws.sh`

Restores AWS CLI configuration files.

**Vault items:**

| Item Name | Writes To |
|-----------|-----------|
| `AWS-Config` | `~/.aws/config` |
| `AWS-Credentials` | `~/.aws/credentials` |

**Example `AWS-Config` notes:**
```ini
[default]
region = us-east-1
output = json

[profile work]
sso_start_url = https://COMPANY.awsapps.com/start
sso_region = us-east-1
sso_account_id = 123456789012
sso_role_name = DeveloperAccess
```

**Permissions:** `600` for both files

---

### `restore-env.sh`

Restores environment secrets and creates a loader script.

**Vault items:**

| Item Name | Writes To |
|-----------|-----------|
| `Environment-Secrets` | `~/.local/env.secrets` |

**Also creates:** `~/.local/load-env.sh` (loader script)

**Example notes:**
```bash
OPENAI_API_KEY=sk-...
GITHUB_TOKEN=ghp_...
ANTHROPIC_API_KEY=sk-ant-...
```

**Usage:**
```bash
source ~/.local/load-env.sh
```

---

### `restore-git.sh`

Restores Git configuration.

**Vault items:**

| Item Name | Writes To |
|-----------|-----------|
| `Git-Config` | `~/.gitconfig` |

**Example notes:**
```ini
[user]
    name = Full Name
    email = email@example.com

[core]
    editor = vim
```

**Permissions:** `644`

---

### `sync-to-vault.sh`

Pushes local config changes back to vault.

```bash
# Preview changes (no modification)
dotfiles vault sync --dry-run --all

# Sync specific items
dotfiles vault sync SSH-Config
dotfiles vault sync AWS-Config Git-Config

# Sync all
dotfiles vault sync --all
```

**Supported items:**

| Item Name | Local File |
|-----------|------------|
| `SSH-Config` | `~/.ssh/config` |
| `AWS-Config` | `~/.aws/config` |
| `AWS-Credentials` | `~/.aws/credentials` |
| `Git-Config` | `~/.gitconfig` |
| `Environment-Secrets` | `~/.local/env.secrets` |

**When to use:** After editing local config files, before switching machines.

---

### `_common.sh`

Shared library sourced by other vault scripts. Provides:

- **Color definitions** - Consistent terminal colors across all scripts
- **Logging functions** - `info()`, `pass()`, `warn()`, `fail()`, `dry()`
- **Item definitions** - Single source of truth for all dotfiles items
- **Vault abstraction** - `vault_get_item()`, `vault_get_notes()`, `vault_item_exists()`
- **Session management** - `get_session()`, `sync_vault()`
- **Legacy aliases** - `bw_*` functions for backward compatibility

**Usage in scripts:**
```bash
#!/usr/bin/env zsh
source "$(dirname "$0")/_common.sh"

require_vault
require_jq
SESSION=$(get_session)
sync_vault "$SESSION"

info "Doing something..."
pass "Success!"
```

**Key data structures:**
```bash
# All dotfiles items with their paths and requirements
DOTFILES_ITEMS["Git-Config"]="$HOME/.gitconfig:required:file"

# Items that can be synced (excludes SSH keys)
SYNCABLE_ITEMS["Git-Config"]="$HOME/.gitconfig"
```

---

## Architecture

### Backend Abstraction Layer

```
┌─────────────────────────────────────────────────────────────────┐
│                    VAULT SYSTEM ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   USER COMMANDS                                                  │
│   ═══════════════════════════════════════════════════════════    │
│   dotfiles vault restore | sync | create | delete | list        │
│                     ↓                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   OPERATION LAYER                                                │
│   ═════════════════════════════════════════════════════════════  │
│   restore-*.sh, sync-to-vault.sh, create/delete scripts         │
│                     ↓                                            │
│   _common.sh (data structures, validation, drift detection)     │
│                     ↓                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   VAULT ABSTRACTION (lib/_vault.sh)                             │
│   ═════════════════════════════════════════════════════════════  │
│   vault_get_session()  vault_get_item()   vault_create_item()   │
│   vault_sync()         vault_get_notes()  vault_update_item()   │
│   vault_login_check()  vault_item_exists() vault_delete_item()  │
│                     ↓                                            │
│   Loads backend based on DOTFILES_VAULT_BACKEND                 │
│                     ↓                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   BACKENDS (vault/backends/*.sh)                                │
│   ═════════════════════════════════════════════════════════════  │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│   │  bitwarden  │  │  1password  │  │    pass     │             │
│   │    (bw)     │  │    (op)     │  │ (pass/gpg)  │             │
│   └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Adding a New Backend

1. Create `vault/backends/newbackend.sh`
2. Implement required functions (see `backends/_interface.md`)
3. Test with `DOTFILES_VAULT_BACKEND=newbackend dotfiles vault list`

---

## Vault Items (Complete List)

All items must be **Secure Notes** (or equivalent) with content in the **notes** field:

| Item Name | Required | Description |
|-----------|----------|-------------|
| `SSH-GitHub-Enterprise` | Yes | SSH key for work/enterprise account |
| `SSH-GitHub-Blackwell` | Yes | SSH key for personal account |
| `SSH-Config` | Yes | Full `~/.ssh/config` contents |
| `AWS-Config` | Yes | Full `~/.aws/config` contents |
| `AWS-Credentials` | Yes | Full `~/.aws/credentials` contents |
| `Git-Config` | Yes | Full `~/.gitconfig` contents |
| `Environment-Secrets` | No | `KEY=value` pairs for env vars |

---

## Common Workflows

### New Machine Setup

```bash
# 1. Clone dotfiles
git clone git@github.com:YOUR-USERNAME/dotfiles.git ~/workspace/dotfiles
cd ~/workspace/dotfiles

# 2. Run bootstrap (packages, symlinks)
./bootstrap/bootstrap-mac.sh  # or ./bootstrap/bootstrap-linux.sh

# 3. Login to your vault
bw login                    # Bitwarden
op signin                   # 1Password
# (pass uses GPG, no login needed)

# 4. Validate vault items exist
dotfiles vault check

# 5. Restore secrets
dotfiles vault restore

# 6. Verify
dotfiles doctor
```

### After Editing Local Config

```bash
# Edit config locally
vim ~/.gitconfig

# Sync to vault
dotfiles vault sync Git-Config

# Or sync all
dotfiles vault sync --all
```

### Switching Backends

```bash
# 1. Export from current backend
dotfiles vault list  # Note all items

# 2. Set new backend
export DOTFILES_VAULT_BACKEND=1password

# 3. Create items in new backend
dotfiles vault create Git-Config
dotfiles vault create SSH-Config
# ... etc

# 4. Verify
dotfiles vault check
```

---

## Session Caching

The `.vault-session` file caches your vault session token:

- Created by `restore.sh` with `600` permissions
- Reused if still valid (avoids repeated unlock prompts)
- Safe to delete - will prompt for unlock again

```bash
# Clear cached session
rm vault/.vault-session
```

---

## Adding a New SSH Key

1. Generate key: `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_newkey`
2. Push to vault (see main README)
3. **Add to `SSH_KEYS` array in `vault/_common.sh`** (single source of truth):
   ```bash
   typeset -A SSH_KEYS=(
       ["SSH-GitHub-Enterprise"]="$HOME/.ssh/id_ed25519_enterprise_ghub"
       ["SSH-GitHub-Blackwell"]="$HOME/.ssh/id_ed25519_blackwell"
       ["SSH-NewService"]="$HOME/.ssh/id_ed25519_newkey"  # ← Add here
   )
   ```
   This automatically propagates to `restore-ssh.sh` and `bin/dotfiles-doctor`.
4. Update `~/.ssh/config` with Host entry
5. Sync: `dotfiles vault sync SSH-Config`
