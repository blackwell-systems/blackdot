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
| `validate-schema.sh` | Validates vault item schema | `bw-validate` |
| `delete-vault-item.sh` | Deletes items from vault | `bw-delete ITEM` |
| `check-vault-items.sh` | Pre-flight validation | `bw-check` |
| `list-vault-items.sh` | Debug/inventory tool | `bw-list [-v]` |
| `_common.sh` | Shared functions library | Sourced by other scripts |
| `template-aws-config` | Reference template | Example AWS config structure |
| `template-aws-credentials` | Reference template | Example AWS credentials structure |

### Shell Aliases

All vault scripts have convenient aliases (defined in `zsh/zshrc`):

```bash
bw-restore   # Restore all secrets from Bitwarden
bw-sync      # Sync local changes to Bitwarden
bw-create    # Create new Bitwarden items
bw-validate  # Validate vault item schema
bw-delete    # Delete items from Bitwarden
bw-list      # List all vault items
bw-check     # Validate required items exist
```

> 📖 **Full Documentation:** For complete documentation including all script details, item formats, and workflows, see the [vault/README.md](https://github.com/blackwell-systems/dotfiles/blob/main/vault/README.md) file in the repository.

---

## Common Workflows

### First Time Setup

```bash
# 1. Login to Bitwarden
bw login

# 2. Push your existing secrets to Bitwarden
bw-sync --all

# 3. Verify items were created
bw-list
```

### New Machine Setup

```bash
# 1. Clone dotfiles
git clone git@github.com:blackwell-systems/dotfiles.git ~/workspace/dotfiles
cd ~/workspace/dotfiles

# 2. Bootstrap the system
./bootstrap-mac.sh  # or bootstrap-linux.sh

# 3. Login to Bitwarden
bw login

# 4. Restore all secrets
bw-restore
```

### Daily Operations

```bash
# Update SSH config locally
vim ~/.ssh/config

# Sync changes to Bitwarden
bw-sync SSH-Config

# Check vault health
bw-check

# Validate vault schema
bw-validate
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
bw-validate
```

**Validates:**
- ✅ Item exists in vault
- ✅ Item type is Secure Note
- ✅ Notes field has content
- ✅ SSH keys contain BEGIN/END markers
- ✅ SSH keys contain public key line
- ✅ Config files meet minimum length

**Common errors:**
- Item missing → Create with `bw-create`
- Empty notes → Re-sync with `bw-sync`
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
bw-list

# Check for typos in item name
bw-check
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
