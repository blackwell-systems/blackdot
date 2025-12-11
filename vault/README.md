# Vault System

The vault system provides **bidirectional secret management** with multiple vault backends through the `vaultmux` library:

- **Pull** secrets from your vault to local files
- **Push** local changes to your vault
- **Validate** vault item schema
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
export BLACKDOT_VAULT_BACKEND=bitwarden  # default
export BLACKDOT_VAULT_BACKEND=1password
export BLACKDOT_VAULT_BACKEND=pass

# For 1Password, optionally set vault name
export ONEPASSWORD_VAULT=Personal  # default

# For pass, optionally set prefix
export PASS_PREFIX=dotfiles  # default, items stored as dotfiles/Git-Config
```

All `blackdot vault` commands work identically regardless of backend.

---

## Quick Reference

All vault operations are accessed via the unified `blackdot vault` command:

```bash
# Setup & Configuration
blackdot vault setup            # Setup vault backend (first-time setup)

# Pull & Push (git-inspired)
blackdot vault pull             # Pull secrets FROM vault to local
blackdot vault pull --force     # Skip drift check, overwrite local
blackdot vault push [item]      # Push secrets TO vault
blackdot vault push --all       # Push all items
blackdot vault status           # Show sync status

# Management
blackdot vault list             # List all vault items
blackdot vault check            # Validate required items exist
blackdot vault validate         # Validate vault item schema
blackdot vault create           # Create new vault item
blackdot vault delete           # Delete vault item
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

## Configuration Files

### vault-items.json

User configuration for vault items. Located at `~/.config/blackdot/vault-items.json`:

```json
{
  "vault_location": {
    "type": "folder",
    "value": "dotfiles"
  },
  "vault_items": {
    "SSH-GitHub": {
      "path": "~/.ssh/id_ed25519_github",
      "required": true,
      "type": "sshkey"
    },
    "Git-Config": {
      "path": "~/.gitconfig",
      "required": true,
      "type": "file"
    }
  }
}
```

### Item Types

- `sshkey` - SSH key pair (private + public key in vault notes)
- `file` - Plain text config file

### Getting Started

```bash
# Copy the example configuration
mkdir -p ~/.config/blackdot
cp vault/vault-items.example.json ~/.config/blackdot/vault-items.json

# Edit to match your vault items
$EDITOR ~/.config/blackdot/vault-items.json

# Or use the setup wizard
blackdot vault setup
```

---

## Architecture

### vaultmux Abstraction Layer

The vault system uses `vaultmux`, a polymorphic secrets manager library that provides a unified API across all backends:

```mermaid
graph LR
    CLI[blackdot CLI] --> VM[vaultmux]
    VM --> BW[Bitwarden]
    VM --> OP[1Password]
    VM --> P[pass]
```

**How it works:**
1. User runs `blackdot vault <command>`
2. Go CLI loads backend based on `BLACKDOT_VAULT_BACKEND` or config.json
3. `vaultmux` provides unified API: `GetItem()`, `CreateItem()`, `UpdateItem()`, `DeleteItem()`
4. Backend-specific code handles CLI differences (bw, op, pass)

### Adding a New Backend

New backends are implemented in the `vaultmux` Go library:
- Repository: `github.com/blackwell-systems/vaultmux`
- See vaultmux documentation for backend implementation guide

---

## Common Workflows

### New Machine Setup

```bash
# 1. Clone dotfiles
git clone git@github.com:YOUR-USERNAME/dotfiles.git ~/workspace/blackdot
cd ~/workspace/blackdot

# 2. Run bootstrap (packages, symlinks)
./bootstrap/bootstrap-mac.sh  # or ./bootstrap/bootstrap-linux.sh

# 3. Login to your vault
bw login                    # Bitwarden
op signin                   # 1Password
# (pass uses GPG, no login needed)

# 4. Validate vault items exist
blackdot vault check

# 5. Restore secrets
blackdot vault pull

# 6. Verify
blackdot doctor
```

### After Editing Local Config

```bash
# Edit config locally
vim ~/.gitconfig

# Push to vault
blackdot vault push Git-Config

# Or push all
blackdot vault push --all
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

**Permissions:** Private keys `600`, public keys `644`, config `600`

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

## Offline Mode

For air-gapped environments or when vault is unavailable:

```bash
# Skip all vault operations during bootstrap
BLACKDOT_OFFLINE=1 ./bootstrap/bootstrap-mac.sh

# Or for individual commands
BLACKDOT_OFFLINE=1 blackdot vault pull  # Exits gracefully
```

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

- **SSH private keys** are set to `600` automatically
- **Protected items** (SSH-*, AWS-*, Git-Config) require confirmation before deletion
- **Vault sync** creates backups before overwriting

---

**Learn More:**
- [Main Documentation](../docs/)
- [GitHub Repository](https://github.com/blackwell-systems/blackdot)
