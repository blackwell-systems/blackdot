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

> **Note:** "Multi-vault" means the system **supports multiple backends**, not that you use them simultaneously. You configure **one active backend at a time**. To switch backends, reconfigure with `blackdot vault setup`.

```bash
# Set your preferred backend (stored in config.json, or override with env var)
export BLACKDOT_VAULT_BACKEND=bitwarden  # default
export BLACKDOT_VAULT_BACKEND=1password
export BLACKDOT_VAULT_BACKEND=pass

# For 1Password, optionally set vault name
export ONEPASSWORD_VAULT=Personal  # default

# For pass, optionally set prefix
export PASS_PREFIX=dotfiles  # default, items stored as dotfiles/Git-Config
```

**Switching backends:**
```bash
blackdot vault setup  # Interactive reconfiguration, updates config.json
```

All `blackdot vault` commands work identically regardless of which backend you've configured.

---

## Quick Reference

| Script | Purpose | Command |
|--------|---------|---------|
| `init-vault.sh` | Configure vault backend with location support | `blackdot vault setup` |
| `restore.sh` | Orchestrates all restores | `blackdot vault pull` |
| `restore-ssh.sh` | Restores SSH keys + config | Called by bootstrap |
| `restore-aws.sh` | Restores AWS config/creds | Called by bootstrap |
| `restore-env.sh` | Restores env secrets | Called by bootstrap |
| `restore-git.sh` | Restores gitconfig | Called by bootstrap |
| `create-vault-item.sh` | Creates new vault items | `blackdot vault create ITEM` |
| `sync-to-vault.sh` | Syncs local → vault | `blackdot vault push --all` |
| `dotfiles-sync` | Smart bidirectional sync | `blackdot sync` or `blackdot vault sync` |
| `validate-schema.sh` | Validates vault item schema | `blackdot vault validate` |
| `delete-vault-item.sh` | Deletes items from vault | `blackdot vault delete ITEM` |
| `check-vault-items.sh` | Pre-flight validation | `blackdot vault check` |
| `list-vault-items.sh` | Debug/inventory tool | `blackdot vault list` |
| `_common.sh` | Shared functions library | Sourced by other scripts |

### Commands

All vault operations are accessed via the unified `blackdot vault` command:

```bash
blackdot vault setup             # Configure or reconfigure vault backend
blackdot vault pull          # Restore all secrets (checks for local drift first)
blackdot vault pull --force  # Skip drift check, overwrite local changes
blackdot vault push             # Sync local changes to vault
blackdot vault push --all       # Sync all items
blackdot vault sync             # Smart bidirectional sync (auto push/pull)
blackdot vault sync --force-local   # Force push local to vault
blackdot vault sync --force-vault   # Force pull vault to local
blackdot vault create           # Create new vault item
blackdot vault validate         # Validate vault item schema
blackdot vault delete           # Delete vault item
blackdot vault list             # List all vault items
blackdot vault check            # Validate required items exist
```

---

## Vault Schema

```json
{
  "version": 3,
  "secrets": [
    {
      "name": "SSH-GitHub",
      "path": "~/.ssh/id_ed25519",
      "type": "ssh-key",
      "required": true,
      "sync": "always",
      "backup": true
    },
    {
      "name": "Git-Config",
      "path": "~/.gitconfig",
      "type": "file",
      "required": true,
      "sync": "manual",
      "backup": true
    }
  ]
}
```

**Schema Fields:**
- `version` - Schema version (3)
- `secrets[]` - Single flat array of all secrets
- `name` - Unique identifier (used in vault item title)
- `path` - Local file path (supports `~` expansion)
- `type` - `ssh-key`, `file`, or custom
- `required` - `true` = `blackdot vault check` validates existence
- `sync` - `always` (auto-sync) or `manual` (on-demand only)
- `backup` - `true` = include in backups

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
export BLACKDOT_VAULT_BACKEND=1password

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
export BLACKDOT_VAULT_BACKEND=pass

# Items will be stored under dotfiles/ prefix
# e.g., dotfiles/Git-Config, dotfiles/SSH-Config
```

---

## Location Management

The vault setup wizard v2 introduces location-based organization. Instead of scanning your entire vault, you tell the system where your dotfiles secrets are stored.

### Why Location Management?

1. **Respects your existing structure** - Use your own folder/vault/directory naming
2. **No random scanning** - The system asks you where to look
3. **Works on new machines** - Vault-first discovery without local files
4. **Supports all backends** - Unified API across Bitwarden, 1Password, and pass

### Location Types by Backend

| Backend | Location Type | Config Value | Example |
|---------|---------------|--------------|---------|
| **Bitwarden** | `folder` | Folder name | `"dotfiles"` |
| **1Password** | `vault` | Vault name | `"Personal"` (planned) |
| **1Password** | `tag` | Tag name | `"dotfiles"` (planned) |
| **pass** | `directory` | Directory name | `"dotfiles"` |
| **Any** | `prefix` | Name prefix | `"SSH-"` |
| **Any** | `none` | No filter | Legacy behavior |

### Setup Wizard v2 Flow

The wizard (`blackdot vault init`) now has three modes:

1. **Existing Items** - You have secrets in your vault already
   - Select or create a location (folder/directory)
   - Import items from that location
   - Map each item to a local path

2. **Fresh Start** - Create new items from local files
   - Scans local machine for secrets
   - Creates vault items with your naming preference
   - Stores in your chosen location

3. **Manual Setup** - Configure yourself
   - Creates minimal config
   - You edit `vault-items.json` directly

### Configuration Example

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "vault_location": {
    "type": "folder",
    "value": "dotfiles"
  },
  "vault_items": {
    "SSH-GitHub": {
      "path": "~/.ssh/id_ed25519_github",
      "required": true,
      "type": "sshkey"
    }
  }
}
```

### Design Document

For the full design rationale, see: [`docs/design/vault-setup-wizard-v2.md`](design/vault-setup-wizard-v2.md)

---

## Configuration File

Vault items are defined in a user-editable JSON configuration file. This allows you to customize which secrets to manage without editing source code.

### Location

```
~/.config/blackdot/vault-items.json
```

### Getting Started

```bash
# Copy the example configuration
mkdir -p ~/.config/blackdot
cp vault/vault-items.example.json ~/.config/blackdot/vault-items.json

# Edit to match your vault items
$EDITOR ~/.config/blackdot/vault-items.json
```

Or use the setup wizard which creates this automatically:
```bash
blackdot setup
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
| `aws_expected_profiles` | AWS profiles validated by `blackdot doctor` |

### Item Types

- `sshkey` - SSH key pair (private + public key in vault notes)
- `file` - Plain text config file

### Required vs Optional

- `required: true` - `blackdot vault check` will fail if missing
- `required: false` - Restored if present, skipped if not

---

### Pre-Restore Safety Check

The restore command automatically checks if your local files have changed since the last vault push. This prevents accidental data loss:

```bash
$ blackdot vault pull
[INFO] Checking for local changes before restore...
[WARN] Local files have changed since last vault push:
  - Git-Config (~/.gitconfig)
  - SSH-Config (~/.ssh/config)

Options:
  1. Run 'blackdot vault push' first to save local changes
  2. Run restore with --force to overwrite local changes
  3. Run 'blackdot drift' to see detailed differences

[FAIL] Restore aborted to prevent data loss
```

To skip this check (for automation or when you intentionally want to overwrite):
```bash
# Use --force flag
blackdot vault pull --force

# Or set environment variable
BLACKDOT_SKIP_DRIFT_CHECK=1 blackdot vault pull
```

---

### Offline Mode

For air-gapped environments, vault outages, or when you simply don't have vault access:

```bash
# Skip all vault operations during bootstrap
BLACKDOT_OFFLINE=1 ./bootstrap/bootstrap-mac.sh

# Or for individual commands
BLACKDOT_OFFLINE=1 blackdot vault pull  # Exits gracefully
BLACKDOT_OFFLINE=1 blackdot vault push     # Exits gracefully
```

When offline mode is enabled:
- `blackdot vault pull` - Skips restore, keeps existing local files
- `blackdot vault push` - Skips sync with helpful message
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
│   blackdot vault pull | sync | create | delete | list        │
│                     ↓                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   OPERATION LAYER                                                │
│   ═════════════════════════════════════════════════════════════  │
│   restore-*.sh, sync-to-vault.sh, create/delete scripts         │
│                     ↓                                            │
│   _common.sh (validation, drift detection, config loader)       │
│                     ↓                                            │
│   ~/.config/blackdot/vault-items.json (user configuration)      │
│                     ↓                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   VAULT ABSTRACTION (lib/_vault.sh)                             │
│   ═════════════════════════════════════════════════════════════  │
│   vault_get_session()  vault_get_item()   vault_create_item()   │
│   vault_sync()         vault_get_notes()  vault_update_item()   │
│   vault_login_check()  vault_item_exists() vault_delete_item()  │
│                     ↓                                            │
│   Loads backend based on BLACKDOT_VAULT_BACKEND                 │
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
3. Test with `BLACKDOT_VAULT_BACKEND=newbackend dotfiles vault list`

---

## Common Workflows

### First Time Setup

```bash
# 1. Login to your vault
bw login                    # Bitwarden
op signin                   # 1Password
# (pass uses GPG, no login needed)

# 2. Push your existing secrets to vault
blackdot vault push --all

# 3. Verify items were created
blackdot vault list
```

### New Machine Setup

```bash
# 1. Clone dotfiles
git clone git@github.com:blackwell-systems/blackdot.git ~/workspace/dotfiles
cd ~/workspace/dotfiles

# 2. Bootstrap the system
./bootstrap/bootstrap-mac.sh  # or bootstrap-linux.sh

# 3. Login to your vault
bw login                    # Bitwarden
op signin                   # 1Password
# (pass uses GPG, no login needed)

# 4. Restore all secrets
blackdot vault pull
```

### Daily Operations

```bash
# Update SSH config locally
vim ~/.ssh/config

# Smart sync - auto-detects push/pull direction
blackdot sync

# Or explicitly push changes to vault
blackdot vault push SSH-Config

# Check vault health
blackdot vault check

# Validate vault schema
blackdot vault validate
```

### Switching Backends

```bash
# 1. Export from current backend
blackdot vault list  # Note all items

# 2. Set new backend
export BLACKDOT_VAULT_BACKEND=1password

# 3. Create items in new backend
blackdot vault create Git-Config
blackdot vault create SSH-Config
# ... etc

# 4. Verify
blackdot vault check
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
| `Template-Variables` | `~/.config/blackdot/template-variables.sh` |

---

## Template Variables Integration

The vault system can store and restore machine-specific template variables, enabling portable configurations across machines.

### What are Template Variables?

Template variables customize dotfiles per-machine. They're stored in `~/.config/blackdot/template-variables.sh`:

```bash
# Machine-specific template variables
TMPL_DEFAULTS[git_name]="Your Name"
TMPL_DEFAULTS[git_email]="your@email.com"
TMPL_DEFAULTS[company]="ACME Corp"
```

### Vault Workflow

**Push to vault (current machine):**
```bash
# Store template variables in your vault
pass insert -mf dotfiles/Template-Variables < ~/.config/blackdot/template-variables.sh

# Or with Bitwarden (via vault scripts)
blackdot vault push Template-Variables
```

**Pull from vault (new machine):**
```bash
# Restore template variables from vault
pass show dotfiles/Template-Variables > ~/.config/blackdot/template-variables.sh

# Then render templates
blackdot template render --all
```

### Location Priority

The template system loads variables from these locations (in order):
1. `~/.config/blackdot/template-variables.sh` (XDG, vault-portable)
2. `templates/_variables.local.sh` (repo-specific fallback)
3. `templates/_variables.sh` (defaults)

### Complete New Machine Workflow

```bash
# 1. Clone dotfiles
git clone git@github.com:USER/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 2. Run bootstrap
./bootstrap/bootstrap-mac.sh

# 3. Login to vault and pull secrets
bw login  # or: op signin / pass init
blackdot vault pull

# 4. Render templates (uses restored variables)
blackdot template render --all
```

---

## Schema Validation

The `validate-config.sh` script validates your `vault-items.json` configuration file against the JSON schema:

```bash
# Validate configuration
blackdot vault validate
```

**What it validates:**
- ✅ Valid JSON syntax
- ✅ Required fields present (path, required, type)
- ✅ Valid type values ("file" or "sshkey")
- ✅ Item naming conventions (must start with capital letter)
- ✅ Path format (must start with ~, /, or $)

**Validation runs automatically:**
- Before `blackdot vault push` operations
- Before `blackdot vault pull` operations
- During setup wizard vault configuration phase

**Interactive error recovery:**
If validation fails during setup, the wizard offers to open your editor:
```
Vault configuration is invalid

Open editor to fix now? [Y/n]: y
```

After you fix errors and save, validation re-runs automatically.

**Example output:**
```
════════════════════════════════════════════════════════════
  Vault Configuration Schema Validation
════════════════════════════════════════════════════════════

Validating: /home/user/.config/blackdot/vault-items.json

Configuration summary:
  • 5 vault items configured
  • 2 SSH keys configured
  • 3 syncable items configured

✓ vault-items.json schema is valid
```

**Common errors and fixes:**
- `Missing required field: vault_items` → Add empty object: `"vault_items": {}`
- `Item X: missing required field (path, required, or type)` → Add missing fields
- `Item X: invalid type "folder"` → Change to "file" or "sshkey"
- `Invalid JSON syntax` → Run `jq . ~/.config/blackdot/vault-items.json` to find syntax errors

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
blackdot vault list

# Check for typos in item name
blackdot vault check
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
- [GitHub Repository](https://github.com/blackwell-systems/blackdot)
