# Bitwarden Vault Bootstrap System

This directory contains scripts for **bidirectional secret management** with Bitwarden:

- **Restore scripts** pull secrets from Bitwarden → local files
- **Sync/Create scripts** push local changes → Bitwarden
- **Utility scripts** for validation, debugging, deletion, and inventory
- **Shared library** (`_common.sh`) with reusable functions

---

## Quick Reference

| Script | Purpose | Command |
|--------|---------|---------|
| `bootstrap-vault.sh` | Orchestrates all restores | `dotfiles vault restore` |
| `restore-ssh.sh` | Restores SSH keys + config | Called by bootstrap |
| `restore-aws.sh` | Restores AWS config/creds | Called by bootstrap |
| `restore-env.sh` | Restores env secrets | Called by bootstrap |
| `restore-git.sh` | Restores gitconfig | Called by bootstrap |
| `create-vault-item.sh` | Creates new vault items | `dotfiles vault create ITEM` |
| `sync-to-bitwarden.sh` | Syncs local → Bitwarden | `dotfiles vault sync --all` |
| `validate-schema.sh` | Validates vault item schema | `dotfiles vault validate` |
| `delete-vault-item.sh` | Deletes items from vault | `dotfiles vault delete ITEM` |
| `check-vault-items.sh` | Pre-flight validation | `dotfiles vault check` |
| `list-vault-items.sh` | Debug/inventory tool | `dotfiles vault list` |
| `_common.sh` | Shared functions library | Sourced by other scripts |
| `template-aws-config` | Reference template | Example AWS config structure |
| `template-aws-credentials` | Reference template | Example AWS credentials structure |

### Commands

All vault operations are accessed via the unified `dotfiles vault` command:

```bash
dotfiles vault restore     # Restore all secrets from Bitwarden
dotfiles vault sync        # Sync local changes to Bitwarden
dotfiles vault sync --all  # Sync all items
dotfiles vault create      # Create new vault item
dotfiles vault validate    # Validate vault item schema
dotfiles vault delete      # Delete vault item
dotfiles vault list        # List all vault items
dotfiles vault check       # Validate required items exist
```

---

## Scripts

### `bootstrap-vault.sh`

**Main entry point** - orchestrates all secret restoration.

```bash
dotfiles vault restore
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
| `SSH-GitHub-Personal` | Private + public key | `~/.ssh/id_ed25519_personal{,.pub}` |
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
sso_start_url = https://COMPANY.awsapps.com/start
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
    name = Full Name
    email = email@example.com

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

### `validate-schema.sh`

Validates that all Bitwarden vault items have the correct schema and structure.

```bash
# Validate all vault items
dotfiles vault validate
```

**What it validates:**

| Check | SSH Keys | Config Files |
|-------|----------|--------------|
| Item exists in vault | ✅ | ✅ |
| Item type is Secure Note | ✅ | ✅ |
| Notes field has content | ✅ | ✅ |
| Contains `BEGIN OPENSSH PRIVATE KEY` | ✅ | - |
| Contains `END OPENSSH PRIVATE KEY` | ✅ | - |
| Contains public key line (ssh-ed25519/rsa) | ✅ | - |
| Notes length > minimum chars | - | ✅ |

**Exit codes:**
- `0` = All items validated successfully
- `1` = One or more validation failures

**Example output:**
```
Validating vault items schema...
[OK] ✓ SSH key item 'SSH-GitHub-Enterprise' validated successfully
[OK] ✓ SSH key item 'SSH-GitHub-Personal' validated successfully
[OK] ✓ Config item 'SSH-Config' validated successfully
[OK] ✓ Config item 'AWS-Config' validated successfully
[OK] ✓ Config item 'AWS-Credentials' validated successfully
[OK] ✓ Config item 'Git-Config' validated successfully
[OK] ✓ All vault items validated successfully
```

**Common validation errors:**
- **Item missing**: Item name typo or not created yet → use `dotfiles vault create`
- **Empty notes**: Item exists but has no content → re-sync with `dotfiles vault sync`
- **Missing key blocks**: SSH key format incorrect → check Bitwarden web vault
- **Wrong item type**: Should be "Secure Note" not "Login" or "Card"

**When to use:**
- Before restoring secrets on a new machine
- After manually editing items in Bitwarden web vault
- In CI/CD to validate vault state before deployments
- Troubleshooting restoration issues

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
[OK] SSH-GitHub-Personal
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

### `template-aws-config`

Reference template showing the expected structure for `~/.aws/config`.

**Contains:**
- SSO profile definitions with placeholder URLs
- Multiple account profiles (dev, prod, personal)
- Region settings

**Placeholders:**
- `{{SSO_DEV_START_URL}}` - Your dev SSO portal URL
- `{{SSO_DEV_REGION}}` - SSO region for dev
- `{{SSO_PROD_START_URL}}` - Your prod SSO portal URL
- `{{SSO_PROD_REGION}}` - SSO region for prod

**When to use:** Reference when creating your `AWS-Config` Bitwarden item.

---

### `template-aws-credentials`

Reference template showing the expected structure for `~/.aws/credentials`.

**Contains:**
- Static credential profiles with placeholder keys
- Session token example for temporary credentials

**Placeholders:**
- `{{PERSONAL_AWS_ACCESS_KEY_ID}}` - Personal account access key
- `{{PERSONAL_AWS_SECRET_ACCESS_KEY}}` - Personal account secret key
- `{{WORK_AWS_ACCESS_KEY_ID}}` - Work account access key
- `{{WORK_AWS_SECRET_ACCESS_KEY}}` - Work account secret key
- `{{PROD_*}}` - Production environment temporary credentials

**When to use:** Reference when creating your `AWS-Credentials` Bitwarden item.

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
| `SSH-GitHub-Enterprise` | Yes | SSH key for work/enterprise account |
| `SSH-GitHub-Personal` | Yes | SSH key for personal account |
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
./bootstrap-mac.sh  # or ./bootstrap-linux.sh

# 3. Login to Bitwarden
bw login

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

# Sync to Bitwarden
dotfiles vault sync Git-Config

# Or sync all
dotfiles vault sync --all
```

### Troubleshooting Missing Items

```bash
# List all vault items
dotfiles vault list

# Check specific item
bw get item "Git-Config" --session "$BW_SESSION" | jq '.notes'
```

### Check for Drift

```bash
# Compare local files vs Bitwarden
dotfiles drift
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
       ["SSH-GitHub-Personal"]="$HOME/.ssh/id_ed25519_personal"
       ["SSH-NewService"]="$HOME/.ssh/id_ed25519_newkey"  # ← Add here
   )
   ```
   This automatically propagates to `restore-ssh.sh` and `dotfiles-doctor.sh`.
4. Update `~/.ssh/config` with Host entry
5. Sync: `./sync-to-bitwarden.sh SSH-Config`
6. (Optional) Add to `zsh/zshrc` for ssh-agent auto-load:
   ```bash
   _ssh_add_if_missing ~/.ssh/id_ed25519_newkey
   ```
