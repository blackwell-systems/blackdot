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
| `init-vault.sh` | Configure vault backend | `dotfiles vault setup` |
| `restore.sh` | Orchestrates all restores | `dotfiles vault pull` |
| `restore-ssh.sh` | Restores SSH keys + config | Called by bootstrap |
| `restore-aws.sh` | Restores AWS config/creds | Called by bootstrap |
| `restore-env.sh` | Restores env secrets | Called by bootstrap |
| `restore-git.sh` | Restores gitconfig | Called by bootstrap |
| `create-vault-item.sh` | Creates new vault items | `dotfiles vault create ITEM` |
| `sync-to-vault.sh` | Syncs local → vault | `dotfiles vault push --all` |
| `validate-schema.sh` | Validates vault item schema | `dotfiles vault validate` |
| `delete-vault-item.sh` | Deletes items from vault | `dotfiles vault delete ITEM` |
| `check-vault-items.sh` | Pre-flight validation | `dotfiles vault check` |
| `list-vault-items.sh` | Debug/inventory tool | `dotfiles vault list` |
| `_common.sh` | Shared functions library | Sourced by other scripts |

### Commands

All vault operations are accessed via the unified `dotfiles vault` command:

```bash
dotfiles vault setup             # Configure or reconfigure vault backend
dotfiles vault pull          # Restore all secrets (checks for local drift first)
dotfiles vault pull --force  # Skip drift check, overwrite local changes
dotfiles vault push             # Sync local changes to vault
dotfiles vault push --all       # Sync all items
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

## Configuration File

Vault items are defined in a user-editable JSON configuration file. This allows you to customize which secrets to manage without editing source code.

### Location

```
~/.config/dotfiles/vault-items.json
```

### Getting Started

```bash
# Copy the example configuration
mkdir -p ~/.config/dotfiles
cp vault/vault-items.example.json ~/.config/dotfiles/vault-items.json

# Edit to match your vault items
$EDITOR ~/.config/dotfiles/vault-items.json
```

Or use the setup wizard which creates this automatically:
```bash
dotfiles setup
```

### Configuration Structure

```json
{
  "ssh_keys": {
    "SSH-GitHub": "~/.ssh/id_ed25519_github",
    "SSH-Work": "~/.ssh/id_ed25519_work"
  },
  "vault_items": {
    "SSH-GitHub": {
      "path": "~/.ssh/id_ed25519_github",
      "required": true,
      "type": "sshkey"
    },
    "SSH-Config": {
      "path": "~/.ssh/config",
      "required": true,
      "type": "file"
    },
    "AWS-Config": {
      "path": "~/.aws/config",
      "required": true,
      "type": "file"
    }
  },
  "syncable_items": {
    "SSH-Config": "~/.ssh/config",
    "AWS-Config": "~/.aws/config",
    "AWS-Credentials": "~/.aws/credentials"
  },
  "aws_expected_profiles": [
    "default"
  ]
}
```

### Sections

| Section | Purpose |
|---------|---------|
| `ssh_keys` | Maps vault item names to local SSH key paths |
| `vault_items` | All managed items with metadata (path, required, type) |
| `syncable_items` | Items that can sync bidirectionally |
| `aws_expected_profiles` | AWS profiles validated by `dotfiles doctor` |

### Item Types

- `sshkey` - SSH key pair (private + public key in vault notes)
- `file` - Plain text config file

### Required vs Optional

- `required: true` - `dotfiles vault check` will fail if missing
- `required: false` - Restored if present, skipped if not

---

### Pre-Restore Safety Check

The restore command automatically checks if your local files have changed since the last vault push. This prevents accidental data loss:

```bash
$ dotfiles vault pull
[INFO] Checking for local changes before restore...
[WARN] Local files have changed since last vault push:
  - Git-Config (~/.gitconfig)
  - SSH-Config (~/.ssh/config)

Options:
  1. Run 'dotfiles vault push' first to save local changes
  2. Run restore with --force to overwrite local changes
  3. Run 'dotfiles drift' to see detailed differences

[FAIL] Restore aborted to prevent data loss
```

To skip this check (for automation or when you intentionally want to overwrite):
```bash
# Use --force flag
dotfiles vault pull --force

# Or set environment variable
DOTFILES_SKIP_DRIFT_CHECK=1 dotfiles vault pull
```

---

### Offline Mode

For air-gapped environments, vault outages, or when you simply don't have vault access:

```bash
# Skip all vault operations during bootstrap
DOTFILES_OFFLINE=1 ./bootstrap/bootstrap-mac.sh

# Or for individual commands
DOTFILES_OFFLINE=1 dotfiles vault pull  # Exits gracefully
DOTFILES_OFFLINE=1 dotfiles vault push     # Exits gracefully
```

When offline mode is enabled:
- `dotfiles vault pull` - Skips restore, keeps existing local files
- `dotfiles vault push` - Skips sync with helpful message
- All other dotfiles commands work normally

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
│   dotfiles vault pull | sync | create | delete | list        │
│                     ↓                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   OPERATION LAYER                                                │
│   ═════════════════════════════════════════════════════════════  │
│   restore-*.sh, sync-to-vault.sh, create/delete scripts         │
│                     ↓                                            │
│   _common.sh (validation, drift detection, config loader)       │
│                     ↓                                            │
│   ~/.config/dotfiles/vault-items.json (user configuration)      │
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

## Common Workflows

### First Time Setup

```bash
# 1. Login to your vault
bw login                    # Bitwarden
op signin                   # 1Password
# (pass uses GPG, no login needed)

# 2. Push your existing secrets to vault
dotfiles vault push --all

# 3. Verify items were created
dotfiles vault list
```

### New Machine Setup

```bash
# 1. Clone dotfiles
git clone git@github.com:blackwell-systems/dotfiles.git ~/workspace/dotfiles
cd ~/workspace/dotfiles

# 2. Bootstrap the system
./bootstrap/bootstrap-mac.sh  # or bootstrap-linux.sh

# 3. Login to your vault
bw login                    # Bitwarden
op signin                   # 1Password
# (pass uses GPG, no login needed)

# 4. Restore all secrets
dotfiles vault pull
```

### Daily Operations

```bash
# Update SSH config locally
vim ~/.ssh/config

# Sync changes to vault
dotfiles vault push SSH-Config

# Check vault health
dotfiles vault check

# Validate vault schema
dotfiles vault validate
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

## Vault Items Structure

### SSH Keys

Each SSH key item should contain:

```
-----BEGIN OPENSSH PRIVATE KEY-----
<private key content>
-----END OPENSSH PRIVATE KEY-----

ssh-ed25519 AAAAC3... username@hostname
```

**Item Names:**
- `SSH-GitHub-Enterprise` → `~/.ssh/id_ed25519_enterprise_ghub{,.pub}`
- `SSH-GitHub-Blackwell` → `~/.ssh/id_ed25519_blackwell{,.pub}`

### Configuration Files

File-based config items contain the full file content in the notes field:

| Item Name | Local File |
|-----------|------------|
| `SSH-Config` | `~/.ssh/config` |
| `AWS-Config` | `~/.aws/config` |
| `AWS-Credentials` | `~/.aws/credentials` |
| `Git-Config` | `~/.gitconfig` |
| `Environment-Secrets` | `~/.local/env.secrets` |

---

## Schema Validation

The `validate-schema.sh` script ensures all vault items have correct structure:

```bash
# Validate all items
dotfiles vault validate
```

**Validates:**
- Item exists in vault
- Item type is Secure Note
- Notes field has content
- SSH keys contain BEGIN/END markers
- SSH keys contain public key line
- Config files meet minimum length

**Common errors:**
- Item missing → Create with `dotfiles vault create`
- Empty notes → Re-sync with `dotfiles vault push`
- Wrong format → Edit in vault web interface

---

## Troubleshooting

### Session Expired

```bash
# Bitwarden: Re-unlock vault
export BW_SESSION="$(bw unlock --raw)"

# Or logout and login
bw logout
bw login

# 1Password: Re-sign in
op signin
```

### Item Not Found

```bash
# List all items to verify name
dotfiles vault list

# Check for typos in item name
dotfiles vault check
```

### Permission Errors

```bash
# Fix SSH key permissions
chmod 600 ~/.ssh/id_ed25519_*
chmod 644 ~/.ssh/id_ed25519_*.pub
chmod 600 ~/.ssh/config
```

---

## Security Notes

- **Session file** (`.vault-session`) is created with `600` permissions (owner read/write only)
- **SSH private keys** are set to `600` automatically
- **Protected items** (SSH-*, AWS-*, Git-Config) require confirmation before deletion
- **Vault sync** creates backups before overwriting (`.bak-YYYYMMDDHHMMSS`)

---

**Learn More:**
- [Main Documentation](/)
- [Full README](README-FULL.md)
- [GitHub Repository](https://github.com/blackwell-systems/dotfiles)
