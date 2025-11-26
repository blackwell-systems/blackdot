# Bitwarden Vault Bootstrap System

This directory contains scripts for **bidirectional secret management** with Bitwarden:

- **Restore scripts** pull secrets from Bitwarden → local files
- **Sync/Create scripts** push local changes → Bitwarden
- **Utility scripts** for validation, debugging, deletion, and inventory
- **Shared library** (`_common.sh`) with reusable functions

---

## Quick Reference

| Script | Purpose | Usage / Alias |
|--------|---------|---------------|
| `bootstrap-vault.sh` | Orchestrates all restores | `bw-restore` |
| `restore-ssh.sh` | Restores SSH keys + config | Called by bootstrap |
| `restore-aws.sh` | Restores AWS config/creds | Called by bootstrap |
| `restore-env.sh` | Restores env secrets | Called by bootstrap |
| `restore-git.sh` | Restores gitconfig | Called by bootstrap |
| `create-vault-item.sh` | Creates new vault items | `bw-create ITEM [FILE]` |
| `sync-to-bitwarden.sh` | Syncs local → Bitwarden | `bw-sync --all` |
| `delete-vault-item.sh` | Deletes items from vault | `bw-delete ITEM` |
| `check-vault-items.sh` | Pre-flight validation | `bw-check` |
| `list-vault-items.sh` | Debug/inventory tool | `bw-list [-v]` |
| `_common.sh` | Shared functions library | Sourced by other scripts |

### Shell Aliases

All vault scripts have convenient aliases (defined in `zsh/zshrc`):

```bash
bw-restore  # Restore all secrets from Bitwarden
bw-sync     # Sync local changes to Bitwarden
bw-create   # Create new Bitwarden items
bw-delete   # Delete items from Bitwarden
bw-list     # List all vault items
bw-check    # Validate required items exist
```

---

## Scripts

### `bootstrap-vault.sh`

**Main entry point** - orchestrates all secret restoration.

```bash
./bootstrap-vault.sh
# Or use the alias:
bw-restore
```

**What it does:**
1. Checks/prompts for Bitwarden unlock
2. Caches session to `.bw-session` (secure permissions)
3. Calls each restore script in sequence

**When to use:** New machine setup, or after secrets change in Bitwarden.

---

### `restore-ssh.sh`

Restores SSH keys and config from Bitwarden.

**Bitwarden items:**

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

ssh-ed25519 AAAAC3NzaC1lZDI1... user@host
```

**Permissions:** Private keys `600`, public keys `644`, config `600`

---

### `restore-aws.sh`

Restores AWS CLI configuration files.

**Bitwarden items:**

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
sso_start_url = https://mycompany.awsapps.com/start
sso_region = us-east-1
sso_account_id = 123456789012
sso_role_name = DeveloperAccess
```

**Permissions:** `600` for both files

---

### `restore-env.sh`

Restores environment secrets and creates a loader script.

**Bitwarden items:**

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

**Bitwarden items:**

| Item Name | Writes To |
|-----------|-----------|
| `Git-Config` | `~/.gitconfig` |

**Example notes:**
```ini
[user]
    name = Your Name
    email = you@example.com

[core]
    editor = vim
```

**Permissions:** `644`

---

### `sync-to-bitwarden.sh`

Pushes local config changes back to Bitwarden.

```bash
# Preview changes (no modification)
./sync-to-bitwarden.sh --dry-run --all

# Sync specific items
./sync-to-bitwarden.sh SSH-Config
./sync-to-bitwarden.sh AWS-Config Git-Config

# Sync all
./sync-to-bitwarden.sh --all
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

### `create-vault-item.sh`

Creates new Bitwarden Secure Note items from local files.

```bash
# Create from known dotfile (auto-detects path)
./create-vault-item.sh Git-Config

# Create with explicit path
./create-vault-item.sh Git-Config ~/.gitconfig

# Create custom item
./create-vault-item.sh My-Custom-Note ~/my-file.txt

# Preview creation
./create-vault-item.sh --dry-run Git-Config

# Overwrite existing item
./create-vault-item.sh --force Git-Config
```

**Known items (auto-detect path):**

| Item Name | Default Path |
|-----------|--------------|
| `SSH-Config` | `~/.ssh/config` |
| `AWS-Config` | `~/.aws/config` |
| `AWS-Credentials` | `~/.aws/credentials` |
| `Git-Config` | `~/.gitconfig` |
| `Environment-Secrets` | `~/.local/env.secrets` |

**When to use:** Initial setup to push local configs to Bitwarden for the first time.

---

### `delete-vault-item.sh`

Deletes items from Bitwarden vault with safety checks.

```bash
# Preview deletion (recommended first step)
./delete-vault-item.sh --dry-run TEST-NOTE

# Delete with confirmation prompt
./delete-vault-item.sh TEST-NOTE

# Delete multiple items without prompts
./delete-vault-item.sh --force OLD-KEY OTHER-ITEM

# List all items (to find exact names)
./delete-vault-item.sh --list
```

**Safety features:**
- Protected items (SSH-*, AWS-*, Git-Config, etc.) require typing the item name to confirm
- Non-protected items prompt for y/N confirmation (bypass with `--force`)
- `--dry-run` shows what would be deleted without making changes
- Shows item details (type, size, modified date) before deletion

**When to use:** Cleaning up test items, removing old/unused secrets.

---

### `check-vault-items.sh`

Pre-flight validation - ensures required Bitwarden items exist.

```bash
./check-vault-items.sh
```

**Example output:**
```
=== Required Items ===
[OK] SSH-GitHub-Enterprise
[OK] SSH-GitHub-Blackwell
[OK] SSH-Config
[OK] AWS-Config
[OK] AWS-Credentials
[OK] Git-Config

=== Optional Items ===
[OK] Environment-Secrets

========================================
All required vault items present!
```

**When to use:** Before `bootstrap-vault.sh` on a new machine.

---

### `list-vault-items.sh`

Debug tool - lists all Bitwarden items relevant to dotfiles.

```bash
# Standard
./list-vault-items.sh

# Verbose (IDs + content preview)
./list-vault-items.sh --verbose
```

**Example output:**
```
=== Expected Dotfiles Items ===

[FOUND] SSH-GitHub-Enterprise
        Type: Secure Note | Notes: 2048 chars | Modified: 2024-11-20

[FOUND] Git-Config
        Type: Secure Note | Notes: 512 chars | Modified: 2024-11-25

[MISSING] Some-Other-Item

=== All Secure Notes in Vault ===
  ✓ SSH-Config (dotfiles)
  ✓ Git-Config (dotfiles)
  ○ Other-Secure-Note
```

**When to use:** Troubleshooting missing items, verifying what's stored.

---

### `_common.sh`

Shared library sourced by other vault scripts. Provides:

- **Color definitions** - Consistent terminal colors across all scripts
- **Logging functions** - `info()`, `pass()`, `warn()`, `fail()`, `dry()`
- **Item definitions** - Single source of truth for all dotfiles items
- **Session management** - `get_session()`, `sync_vault()`
- **Prerequisite checks** - `require_bw()`, `require_jq()`, `require_logged_in()`
- **Bitwarden helpers** - `bw_get_item()`, `bw_get_notes()`, `bw_item_exists()`

**Usage in scripts:**
```bash
#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

require_bw
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

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    VAULT SCRIPTS DATA FLOW                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   BITWARDEN VAULT                    LOCAL MACHINE               │
│   ═══════════════                    ═════════════               │
│                                                                  │
│   ┌─────────────────┐                ┌─────────────────┐        │
│   │ SSH-GitHub-*    │ ──restore───▶  │ ~/.ssh/         │        │
│   │ SSH-Config      │    ssh.sh      │   id_ed25519_*  │        │
│   │                 │                │   config        │        │
│   └─────────────────┘                └─────────────────┘        │
│                                              │                   │
│   ┌─────────────────┐                        │ sync-to-         │
│   │ AWS-Config      │ ──restore───▶  ┌──────▼──────────┐        │
│   │ AWS-Credentials │    aws.sh      │ ~/.aws/         │        │
│   │                 │ ◀──────────────│   config        │        │
│   └─────────────────┘   bitwarden.sh │   credentials   │        │
│                                      └─────────────────┘        │
│   ┌─────────────────┐                                           │
│   │ Git-Config      │ ──restore───▶  ┌─────────────────┐        │
│   │                 │    git.sh      │ ~/.gitconfig    │        │
│   │                 │ ◀──────────────│                 │        │
│   └─────────────────┘   bitwarden.sh └─────────────────┘        │
│                                                                  │
│   ┌─────────────────┐                ┌─────────────────┐        │
│   │ Environment-    │ ──restore───▶  │ ~/.local/       │        │
│   │ Secrets         │    env.sh      │   env.secrets   │        │
│   │                 │ ◀──────────────│   load-env.sh   │        │
│   └─────────────────┘   bitwarden.sh └─────────────────┘        │
│                                                                  │
│   ═══════════════════════════════════════════════════════════   │
│                                                                  │
│   UTILITIES:                                                     │
│   • bootstrap-vault.sh     →  Orchestrates all restore-*.sh      │
│   • create-vault-item.sh   →  Initial push to Bitwarden          │
│   • check-vault-items.sh   →  Pre-flight validation              │
│   • list-vault-items.sh    →  Debug/inventory tool               │
│   • delete-vault-item.sh   →  Remove items from vault            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Bitwarden Item Names (Complete List)

All items must be **Secure Notes** with content in the **notes** field:

| Item Name | Required | Description |
|-----------|----------|-------------|
| `SSH-GitHub-Enterprise` | Yes | SSH key for GitHub Enterprise/SSO |
| `SSH-GitHub-Blackwell` | Yes | SSH key for Blackwell Systems GitHub |
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
git clone git@github.com:you/dotfiles.git ~/workspace/dotfiles

# 2. Run bootstrap (packages, symlinks)
./bootstrap-mac.sh  # or ./bootstrap-lima.sh

# 3. Login to Bitwarden
bw login

# 4. Validate vault items exist
./vault/check-vault-items.sh

# 5. Restore secrets
./vault/bootstrap-vault.sh  # or: bw-restore

# 6. Verify
./check-health.sh
```

### After Editing Local Config

```bash
# Edit config locally
vim ~/.gitconfig

# Sync to Bitwarden
./vault/sync-to-bitwarden.sh Git-Config

# Or sync all
./vault/sync-to-bitwarden.sh --all
```

### Troubleshooting Missing Items

```bash
# List all vault items
./vault/list-vault-items.sh --verbose

# Check specific item
bw get item "Git-Config" --session "$BW_SESSION" | jq '.notes'
```

### Check for Drift

```bash
# Compare local files vs Bitwarden
../check-health.sh --drift
```

---

## Session Caching

The `.bw-session` file caches your Bitwarden session token:

- Created by `bootstrap-vault.sh` with `600` permissions
- Reused if still valid (avoids repeated unlock prompts)
- Safe to delete - will prompt for unlock again

```bash
# Clear cached session
rm vault/.bw-session
```

---

## Adding a New SSH Key

1. Generate key: `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_newkey`
2. Push to Bitwarden (see main README)
3. **Add to `SSH_KEYS` array in `vault/_common.sh`** (single source of truth):
   ```bash
   declare -A SSH_KEYS=(
       ["SSH-GitHub-Enterprise"]="$HOME/.ssh/id_ed25519_enterprise_ghub"
       ["SSH-GitHub-Blackwell"]="$HOME/.ssh/id_ed25519_blackwell"
       ["SSH-NewService"]="$HOME/.ssh/id_ed25519_newkey"  # ← Add here
   )
   ```
   This automatically propagates to `restore-ssh.sh` and `check-health.sh`.
4. Update `~/.ssh/config` with Host entry
5. Sync: `./sync-to-bitwarden.sh SSH-Config`
6. (Optional) Add to `zsh/zshrc` for ssh-agent auto-load:
   ```bash
   _ssh_add_if_missing ~/.ssh/id_ed25519_newkey
   ```
