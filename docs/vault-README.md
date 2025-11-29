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
dotfiles vault restore          # Restore all secrets (checks for local drift first)
dotfiles vault restore --force  # Skip drift check, overwrite local changes
dotfiles vault sync             # Sync local changes to Bitwarden
dotfiles vault sync --all       # Sync all items
dotfiles vault create           # Create new vault item
dotfiles vault validate         # Validate vault item schema
dotfiles vault delete           # Delete vault item
dotfiles vault list             # List all vault items
dotfiles vault check            # Validate required items exist
```

### Pre-Restore Safety Check

The restore command automatically checks if your local files have changed since the last vault sync. This prevents accidental data loss:

```bash
$ dotfiles vault restore
[INFO] Checking for local changes before restore...
[WARN] Local files have changed since last vault sync:
  - Git-Config (~/.gitconfig)
  - SSH-Config (~/.ssh/config)

Options:
  1. Run 'dotfiles vault sync' first to save local changes
  2. Run restore with --force to overwrite local changes
  3. Run 'dotfiles drift' to see detailed differences

[FAIL] Restore aborted to prevent data loss
```

To skip this check (for automation or when you intentionally want to overwrite):
```bash
# Use --force flag
dotfiles vault restore --force

# Or set environment variable
DOTFILES_SKIP_DRIFT_CHECK=1 dotfiles vault restore
```

> 📖 **Full Documentation:** For complete documentation including all script details, item formats, and workflows, see the [vault/README.md](https://github.com/blackwell-systems/dotfiles/blob/main/vault/README.md) file in the repository.

---

### Offline Mode

For air-gapped environments, Bitwarden outages, or when you simply don't have vault access:

```bash
# Skip all vault operations during bootstrap
DOTFILES_OFFLINE=1 ./bootstrap/bootstrap-mac.sh

# Or for individual commands
DOTFILES_OFFLINE=1 dotfiles vault restore  # Exits gracefully
DOTFILES_OFFLINE=1 dotfiles vault sync     # Exits gracefully
```

When offline mode is enabled:
- `dotfiles vault restore` - Skips restore, keeps existing local files
- `dotfiles vault sync` - Skips sync with helpful message
- All other dotfiles commands work normally

---

## Common Workflows

### First Time Setup

```bash
# 1. Login to Bitwarden
bw login

# 2. Push your existing secrets to Bitwarden
dotfiles vault sync --all

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

# 3. Login to Bitwarden
bw login

# 4. Restore all secrets
dotfiles vault restore
```

### Daily Operations

```bash
# Update SSH config locally
vim ~/.ssh/config

# Sync changes to Bitwarden
dotfiles vault sync SSH-Config

# Check vault health
dotfiles vault check

# Validate vault schema
dotfiles vault validate
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
- `SSH-GitHub-Personal` → `~/.ssh/id_ed25519_personal{,.pub}`

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
- ✅ Item exists in vault
- ✅ Item type is Secure Note
- ✅ Notes field has content
- ✅ SSH keys contain BEGIN/END markers
- ✅ SSH keys contain public key line
- ✅ Config files meet minimum length

**Common errors:**
- Item missing → Create with `dotfiles vault create`
- Empty notes → Re-sync with `dotfiles vault sync`
- Wrong format → Edit in Bitwarden web vault

---

## Troubleshooting

### Session Expired

```bash
# Re-unlock vault
export BW_SESSION="$(bw unlock --raw)"

# Or logout and login
bw logout
bw login
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

- **Session file** (`.bw-session`) is created with `600` permissions (owner read/write only)
- **SSH private keys** are set to `600` automatically
- **Protected items** (SSH-*, AWS-*, Git-Config) require confirmation before deletion
- **Vault sync** creates backups before overwriting (`.bak-YYYYMMDDHHMMSS`)

---

**Learn More:**
- [Main Documentation](/)
- [Full README](README-FULL.md)
- [GitHub Repository](https://github.com/blackwell-systems/dotfiles)
