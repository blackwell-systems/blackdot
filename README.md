# Dotfiles & Vault Setup

This repository contains my personal dotfiles for **macOS** and **Lima** (Linux), used to configure my development environment consistently across both platforms. The dotfiles include configurations for **Zsh**, **Powerlevel10k**, **Homebrew**, **Claude helpers**, and a **Bitwarden-based vault bootstrap** for SSH keys, AWS config/credentials, and environment secrets.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Directory Structure](#directory-structure)
- [Global Prerequisites](#global-prerequisites)
- [Bootstrap Overview](#bootstrap-overview)
- [Bootstrapping macOS from Scratch](#bootstrapping-macos-from-scratch)
- [Bootstrapping Lima / Linux Guest](#bootstrapping-lima--linux-guest)
- [Dotfiles Bootstrap Details](#dotfiles-bootstrap-details)
- [Homebrew & Brewfile](#homebrew--brewfile)
- [Vault / Bitwarden Bootstrap](#vault--bitwarden-bootstrap)
- [Restoring from Bitwarden on Any Machine](#restoring-from-bitwarden-on-any-machine)
- [Scripts: What Each Restore Script Expects](#scripts-what-each-restore-script-expects)
- [One-Time: Push Current Files into Bitwarden](#one-time-push-current-files-into-bitwarden-for-future-you)
- [Rotating / Updating Secrets in Bitwarden](#rotating--updating-secrets-in-bitwarden)
- [Adding New SSH Keys](#adding-new-ssh-keys)
- [Using the Dotfiles Day-to-Day](#using-the-dotfiles-day-to-day)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Quick Start

**Already set up? Here's the TL;DR:**

```bash
# New macOS machine
git clone git@github.com:your-username/dotfiles.git ~/workspace/dotfiles
cd ~/workspace/dotfiles && ./bootstrap-mac.sh

# New Lima VM
cd ~/workspace/dotfiles && ./bootstrap-lima.sh

# Restore secrets from Bitwarden (either platform)
bw login && export BW_SESSION="$(bw unlock --raw)"
./vault/bootstrap-vault.sh

# Or use the alias (after shell restart)
bw-restore
```

**What gets set up:**
- Zsh + Powerlevel10k + plugins (autosuggestions, syntax highlighting)
- All Homebrew packages from `Brewfile`
- SSH keys, AWS credentials, and env secrets from Bitwarden
- Claude CLI with shared workspace across macOS/Lima

---

## Directory Structure

The dotfiles are organized as follows:

```text
~/workspace/dotfiles
├── bootstrap-dotfiles.sh     # Shared symlink bootstrap (zshrc, p10k, Ghostty, Claude)
├── bootstrap-lima.sh         # Lima / Linux-specific bootstrap wrapper
├── bootstrap-mac.sh          # macOS-specific bootstrap wrapper
├── Brewfile                  # Unified Homebrew bundle (macOS + Lima)
├── ghostty
│   └── config                # Ghostty terminal config
├── lima
│   └── lima.yaml             # Lima VM config (host-side)
├── vault
│   ├── bootstrap-vault.sh    # Orchestrates all Bitwarden restores
│   ├── restore-ssh.sh        # Restores SSH keys from Bitwarden
│   ├── restore-aws.sh        # Restores ~/.aws/config & ~/.aws/credentials
│   └── restore-env.sh        # Restores environment secrets to ~/.local
└── zsh
    ├── p10k.zsh              # Powerlevel10k theme config
    └── zshrc                 # Main Zsh configuration
```

Key pieces:

- **zsh/zshrc**: Main Zsh configuration file  
- **zsh/p10k.zsh**: Powerlevel10k theme configuration  
- **ghostty/config**: Ghostty terminal configuration  
- **vault/**: Bitwarden-based secure bootstrap for SSH, AWS, and environment secrets  
- **Brewfile**: Shared Homebrew definition used by both macOS and Lima bootstrap scripts  
- **Claude Workspace Symlink** inside `bootstrap-dotfiles.sh` ensures that both macOS and Lima point to the shared workspace directory:

  ```
  ~/.claude → ~/workspace/.claude
  ```

---

## Global Prerequisites

On **both macOS and Lima/Linux**, you’ll eventually want:

- **Zsh** as your login shell  
- **Homebrew** (macOS or Linuxbrew)  
- **Git**  
- **Bitwarden CLI** (`bw`)  
- **jq** (for JSON manipulation)  
- **AWS CLI v2** (for AWS workflows)  
- **Claude Code (CLI)** via Homebrew (installed from Brewfile on both macOS + Lima)

You can install most of these via Homebrew (after the basic bootstrap is done).

---

## Bootstrap Overview

There are two big pillars:

1. **Dotfiles / Shell bootstrap**

   Handled by:

   - `bootstrap-dotfiles.sh`
   - `bootstrap-mac.sh`
   - `bootstrap-lima.sh`

   Goal: consistent Zsh + p10k + plugins + Ghostty config + Claude across host and Lima.

2. **Vault / Secure secrets bootstrap (Bitwarden)**

   Handled by:

   - `vault/bootstrap-vault.sh`
   - `vault/restore-ssh.sh`
   - `vault/restore-aws.sh`
   - `vault/restore-env.sh`

   Goal: restore **SSH keys**, **AWS config/credentials**, and **env secrets** from Bitwarden.

---

## Bootstrapping macOS from Scratch

1. **Create workspace directory**

```bash
mkdir -p ~/workspace
cd ~/workspace
```

2. **Clone dotfiles repo**

```bash
git clone git@github.com:your-username/dotfiles.git
cd ~/workspace/dotfiles
```

3. **Run macOS bootstrap**

```bash
./bootstrap-mac.sh
```

Typical responsibilities of `bootstrap-mac.sh`:

- Install **Xcode Command Line Tools** (if missing).  
- Install or update **Homebrew**.  
- Ensure `brew` is on `PATH`.  
- Run the **shared Brewfile**:

  ```bash
  brew bundle --file="$DOTFILES_DIR/Brewfile"
  ```

- Run `bootstrap-dotfiles.sh` to create symlinks:

  - `~/.zshrc    → ~/workspace/dotfiles/zsh/zshrc`  
  - `~/.p10k.zsh → ~/workspace/dotfiles/zsh/p10k.zsh`  
  - `~/.claude   → ~/workspace/.claude`  
  - Ghostty config symlink into:

    ```
    ~/Library/Application Support/com.mitchellh.ghostty/config
    ```

4. **Open a new terminal**

This ensures the new `~/.zshrc`, Powerlevel10k, plugins, and Claude integration are picked up.

---

## Bootstrapping Lima / Linux Guest

Assuming your Lima VM shares `~/workspace` from macOS:

1. **Start Lima**

```bash
limactl start ~/workspace/dotfiles/lima/lima.yaml
limactl shell lima-dev-ubuntu
```

2. **Run the Lima bootstrap**

```bash
cd ~/workspace/dotfiles
./bootstrap-lima.sh
```

Typical responsibilities of `bootstrap-lima.sh`:

- Install essential packages (`git`, `zsh`, etc.).  
- Install **Linuxbrew** if missing.  
- Ensure `brew` is on `PATH`.  
- Run the **same Brewfile** used by macOS.  
- Call `bootstrap-dotfiles.sh` to symlink everything, including:

  - `~/.claude → ~/workspace/.claude`
  - shared Zsh files
  - shared p10k config

3. **Restart Lima shell**

---

## Dotfiles Bootstrap Details

### `bootstrap-dotfiles.sh`

This file creates all unified symlinks:

- `~/.zshrc    -> $DOTFILES_DIR/zsh/zshrc`  
- `~/.p10k.zsh -> $DOTFILES_DIR/zsh/p10k.zsh`  
- Ghostty config (macOS only)  
- **Claude workspace symlink**:

  ```
  if [ ! -L "$HOME/.claude" ]; then
      ln -s ~/workspace/.claude ~/.claude
  fi
  ```

This ensures Claude CLI sees a *shared* workspace on both platforms.

---

## Homebrew & Brewfile

The **Brewfile** is shared by both macOS and Lima and includes:

- Core CLI tools  
- Zsh + plugins  
- Docker  
- Lima  
- jq, awscli, bitwarden-cli  
- Claude Code for both macOS + Linux  
- macOS-only casks (ignored automatically on Linux)

Example (abbreviated):

```ruby
brew "git"
brew "zsh"
brew "tmux"
brew "zellij"
brew "node"
brew "docker"
brew "lima"
brew "powerlevel10k"
brew "zsh-autosuggestions"
brew "zsh-syntax-highlighting"
brew "jq"
brew "awscli"
brew "bitwarden-cli"
brew "claude-code"

on_macos do
  cask "ghostty"
  cask "claude-code"
  cask "font-meslo-for-powerlevel10k"
  cask "microsoft-edge"
  cask "nosql-workbench"
  cask "mongodb-compass"
  cask "rectangle"
  cask "vscodium"
end
```

You can regenerate:

```bash
brew bundle dump --force --file=./Brewfile
```

and prune as needed.

---

## Vault / Bitwarden Bootstrap

Lives under:

```
~/workspace/dotfiles/vault
```

Restores:

- **SSH keys**  
- **AWS config & credentials**  
- **Environment secrets**  

via Bitwarden Secure Notes.

Same flow on macOS and Lima.

---

## Restoring from Bitwarden on Any Machine

Once the dotfiles are in place and `bw` is installed:

1. **Ensure you are logged into Bitwarden CLI**

```bash
bw login                     # if not already logged in
export BW_SESSION="$(bw unlock --raw)"
bw sync --session "$BW_SESSION"
```

2. **Run the vault bootstrap**

```bash
cd ~/workspace/dotfiles/vault
./bootstrap-vault.sh
```

`bootstrap-vault.sh` will:

- Reuse `vault/.bw-session` if valid, or call `bw unlock --raw` and store the session.
- Call:

  - `restore-ssh.sh "$SESSION"`
  - `restore-aws.sh "$SESSION"`
  - `restore-env.sh "$SESSION"`

After this finishes:

- Your **SSH keys** are back under `~/.ssh`.
- Your **AWS config/credentials** are restored.
- Your **env secrets** file and loader script are in `~/.local`.

---

## Scripts: What Each Restore Script Expects

### `restore-ssh.sh`

- Reads Bitwarden **Secure Note** items:

  - `"SSH-GitHub-Enterprise"`
  - `"SSH-GitHub-Blackwell"`

- Each item's **notes** field should contain:

  - The full **OpenSSH private key** block.
  - Optionally the corresponding `ssh-ed25519 ...` public key line.

The script:

- Reconstructs these files:

  - `~/.ssh/id_ed25519_enterprise_ghub`
  - `~/.ssh/id_ed25519_enterprise_ghub.pub`
  - `~/.ssh/id_ed25519_blackwell`
  - `~/.ssh/id_ed25519_blackwell.pub`

- Sets appropriate permissions (`600` for private, `644` for public).

> **Important:** The exact item names (`SSH-GitHub-Enterprise`, `SSH-GitHub-Blackwell`) need to match.

---

### `restore-aws.sh`

- Expects two **Secure Note** items in Bitwarden:

  - `"AWS-Config"`       → contains your full `~/.aws/config`
  - `"AWS-Credentials"`  → contains your full `~/.aws/credentials`

- The **notes** field of each item is the raw file content.

The script:

- Writes `~/.aws/config` and `~/.aws/credentials` directly from these notes.
- Sets safe permissions (`600` where appropriate).

---

### `restore-env.sh`

- Expects a **Secure Note** item named `"Environment-Secrets"`.

- The **notes** field should contain lines like:

  ```text
  SOME_API_KEY=...
  ANOTHER_SECRET=...
  ```

The script:

- Writes this into `~/.local/env.secrets`.
- Creates `~/.local/load-env.sh` which exports everything when sourced:

  ```bash
  # Example usage in your shell:
  source ~/.local/load-env.sh
  ```

---

## One-Time: Push Current Files into Bitwarden (for Future-You)

The idea: run these **once** on a "known-good" machine (your macOS host), so future machines can restore from Bitwarden with `bootstrap-vault.sh`.

You can also do all of this manually in the Bitwarden GUI, but here's the CLI version for reproducibility.

### 1. Ensure `BW_SESSION` is set

```bash
export BW_SESSION="$(bw unlock --raw)"
bw sync --session "$BW_SESSION"
```

---

### 2. Push `~/.aws/config` into `AWS-Config`

```bash
cd ~/workspace/dotfiles/vault

CONFIG_JSON=$(jq -Rs --arg name "AWS-Config" \
  '{ type: 2, name: $name, secureNote: { type: 0 }, notes: . }' \
  < ~/.aws/config)

CONFIG_ENC=$(printf '%s' "$CONFIG_JSON" | bw encode)

bw create item "$CONFIG_ENC" --session "$BW_SESSION"
```

To **update** it later instead of creating duplicates:

```bash
AWS_CONFIG_ID=$(bw list items --search "AWS-Config" --session "$BW_SESSION" | jq -r '.[0].id')
printf '%s' "$CONFIG_JSON" | bw encode | bw edit item "$AWS_CONFIG_ID" --session "$BW_SESSION"
```

---

### 3. Push `~/.aws/credentials` into `AWS-Credentials`

```bash
CREDS_JSON=$(jq -Rs --arg name "AWS-Credentials" \
  '{ type: 2, name: $name, secureNote: { type: 0 }, notes: . }' \
  < ~/.aws/credentials)

CREDS_ENC=$(printf '%s' "$CREDS_JSON" | bw encode)

bw create item "$CREDS_ENC" --session "$BW_SESSION"
```

To **update** later:

```bash
AWS_CREDS_ID=$(bw list items --search "AWS-Credentials" --session "$BW_SESSION" | jq -r '.[0].id')
printf '%s' "$CREDS_JSON" | bw encode | bw edit item "$AWS_CREDS_ID" --session "$BW_SESSION"
```

---

### 4. Push SSH keys into Secure Notes

You'll create one note per SSH identity:

- `SSH-GitHub-Enterprise`    → `id_ed25519_enterprise_ghub`
- `SSH-GitHub-Blackwell`     → `id_ed25519_blackwell`

Each note will contain the **private key** (already passphrase-protected by OpenSSH) and optionally the **public key**.

#### Enterprise key

```bash
(
  cat ~/.ssh/id_ed25519_enterprise_ghub
  echo
  cat ~/.ssh/id_ed25519_enterprise_ghub.pub
) | jq -Rs '{
  type: 2,
  name: "SSH-GitHub-Enterprise",
  secureNote: { type: 0 },
  notes: .
}' | bw encode | bw create item --session "$BW_SESSION"
```

#### Blackwell key

```bash
(
  cat ~/.ssh/id_ed25519_blackwell
  echo
  cat ~/.ssh/id_ed25519_blackwell.pub
) | jq -Rs '{
  type: 2,
  name: "SSH-GitHub-Blackwell",
  secureNote: { type: 0 },
  notes: .
}' | bw encode | bw create item --session "$BW_SESSION"
```

> If you prefer, you can also create these as **Secure Notes** in the Bitwarden GUI and paste the contents of the private + public key directly into the Notes field. The restore script just looks at `notes`.

---

### 5. Push environment secrets into `Environment-Secrets` (optional)

1. First, create a local file with the secrets you want portable:

```bash
mkdir -p ~/.local
cat > ~/.local/env.secrets <<'EOF'
# Example
OPENAI_API_KEY=...
GITHUB_TOKEN=...
EOF
chmod 600 ~/.local/env.secrets
```

2. Then push it into Bitwarden:

```bash
ENV_JSON=$(jq -Rs --arg name "Environment-Secrets" \
  '{ type: 2, name: $name, secureNote: { type: 0 }, notes: . }' \
  < ~/.local/env.secrets)

ENV_ENC=$(printf '%s' "$ENV_JSON" | bw encode)

bw create item "$ENV_ENC" --session "$BW_SESSION"
```

Now `restore-env.sh` will bring this back on any new machine and create `~/.local/load-env.sh` to load it.

---

## Rotating / Updating Secrets in Bitwarden

When you need to update existing secrets (rotated credentials, new API keys, etc.):

### Update AWS Config/Credentials

```bash
# Ensure session is active
export BW_SESSION="$(bw unlock --raw)"
bw sync --session "$BW_SESSION"

# Update AWS-Config
AWS_CONFIG_ID=$(bw list items --search "AWS-Config" --session "$BW_SESSION" | jq -r '.[0].id')
CONFIG_JSON=$(jq -Rs --arg name "AWS-Config" \
  '{ type: 2, name: $name, secureNote: { type: 0 }, notes: . }' \
  < ~/.aws/config)
printf '%s' "$CONFIG_JSON" | bw encode | bw edit item "$AWS_CONFIG_ID" --session "$BW_SESSION"

# Update AWS-Credentials
AWS_CREDS_ID=$(bw list items --search "AWS-Credentials" --session "$BW_SESSION" | jq -r '.[0].id')
CREDS_JSON=$(jq -Rs --arg name "AWS-Credentials" \
  '{ type: 2, name: $name, secureNote: { type: 0 }, notes: . }' \
  < ~/.aws/credentials)
printf '%s' "$CREDS_JSON" | bw encode | bw edit item "$AWS_CREDS_ID" --session "$BW_SESSION"

# Sync to ensure changes propagate
bw sync --session "$BW_SESSION"
```

### Update Environment Secrets

```bash
# Edit your local secrets file
vim ~/.local/env.secrets

# Push updated version
ENV_ID=$(bw list items --search "Environment-Secrets" --session "$BW_SESSION" | jq -r '.[0].id')
ENV_JSON=$(jq -Rs --arg name "Environment-Secrets" \
  '{ type: 2, name: $name, secureNote: { type: 0 }, notes: . }' \
  < ~/.local/env.secrets)
printf '%s' "$ENV_JSON" | bw encode | bw edit item "$ENV_ID" --session "$BW_SESSION"
```

### Rotate an SSH Key

```bash
# Generate new key
ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/id_ed25519_newkey

# Update in Bitwarden (find the item ID first)
KEY_ID=$(bw list items --search "SSH-KeyName" --session "$BW_SESSION" | jq -r '.[0].id')

(
  cat ~/.ssh/id_ed25519_newkey
  echo
  cat ~/.ssh/id_ed25519_newkey.pub
) | jq -Rs '{
  type: 2,
  name: "SSH-KeyName",
  secureNote: { type: 0 },
  notes: .
}' | bw encode | bw edit item "$KEY_ID" --session "$BW_SESSION"
```

---

## Adding New SSH Keys

To add a new SSH identity to the vault system:

### 1. Generate the key pair

```bash
ssh-keygen -t ed25519 -C "purpose@example.com" -f ~/.ssh/id_ed25519_newservice
```

### 2. Push to Bitwarden

```bash
export BW_SESSION="$(bw unlock --raw)"

(
  cat ~/.ssh/id_ed25519_newservice
  echo
  cat ~/.ssh/id_ed25519_newservice.pub
) | jq -Rs '{
  type: 2,
  name: "SSH-NewService",
  secureNote: { type: 0 },
  notes: .
}' | bw encode | bw create item --session "$BW_SESSION"
```

### 3. Update `restore-ssh.sh`

Add a new block to `vault/restore-ssh.sh`:

```bash
# NewService key
restore_key "SSH-NewService" "id_ed25519_newservice"
```

Or if the script uses explicit blocks, add:

```bash
echo "Restoring SSH-NewService..."
NOTES=$(bw get notes "SSH-NewService" --session "$BW_SESSION")
echo "$NOTES" | grep -A 100 "BEGIN OPENSSH PRIVATE KEY" | grep -B 100 "END OPENSSH PRIVATE KEY" > ~/.ssh/id_ed25519_newservice
echo "$NOTES" | grep "^ssh-ed25519" > ~/.ssh/id_ed25519_newservice.pub
chmod 600 ~/.ssh/id_ed25519_newservice
chmod 644 ~/.ssh/id_ed25519_newservice.pub
```

### 4. Add to SSH config (optional)

```bash
# ~/.ssh/config
Host newservice.example.com
    IdentityFile ~/.ssh/id_ed25519_newservice
    User git
```

---

## Using the Dotfiles Day-to-Day

### Aliases (defined in zshrc)

**Git shortcuts:**

- `gst` → `git status`
- `gss` → `git status -sb`
- `ga` / `gaa` → `git add` / `git add --all`
- `gco` / `gcb` → `git checkout` / `git checkout -b`
- `gd` / `gds` → `git diff` / `git diff --staged`
- `gpl` → `git pull`
- `gp` / `gpf` → `git push` / `git push --force-with-lease`
- `gcm` → `git commit -m`
- `gca` → `git commit --amend`
- `gl1` → `git log --oneline -n 15`
- `glg` → `git log --oneline --graph --all`

**Navigation:**

- `cws` → `cd ~/workspace`
- `ccode` → `cd ~/workspace/code`
- `cwhite` → `cd ~/workspace/whitepapers`
- `cpat` → `cd ~/workspace/patent-pool`

**Vault:**

- `bw-restore` → Run Bitwarden vault bootstrap

### Claude helpers

- `claude-bedrock "prompt"`  
- `claude-max "prompt"`  
- `claude-run bedrock "prompt"`  
- `claude-run max "prompt"`

### Environment secrets

```bash
source ~/.local/load-env.sh
```

---

## Troubleshooting

### Claude workspace not detected

Make sure:

```bash
ls -ld ~/.claude
# should be → ~/workspace/.claude
```

If not, rerun:

```bash
~/workspace/dotfiles/bootstrap-dotfiles.sh
```

### Bitwarden CLI issues

**Session expired or invalid:**

```bash
bw logout
bw login
export BW_SESSION="$(bw unlock --raw)"
bw sync --session "$BW_SESSION"
```

**"Cannot find item" errors:**

```bash
# List all items to verify names
bw list items --session "$BW_SESSION" | jq '.[].name'

# Search for specific item
bw list items --search "SSH-GitHub" --session "$BW_SESSION" | jq '.[] | {name, id}'
```

**Session file issues:**

```bash
# Remove cached session and re-authenticate
rm -f ~/workspace/dotfiles/vault/.bw-session
export BW_SESSION="$(bw unlock --raw)"
```

### Powerlevel10k / icons missing or broken

1. Ensure the Nerd Font is installed:

   ```bash
   brew list | grep -i font
   # Should show: font-meslo-lg-nerd-font or similar
   ```

2. Configure your terminal to use the font (Ghostty, iTerm2, etc.)

3. Re-run Powerlevel10k configuration:

   ```bash
   p10k configure
   ```

### SSH keys not working after restore

**Check permissions:**

```bash
ls -la ~/.ssh/
# Private keys should be 600, public keys 644
chmod 600 ~/.ssh/id_ed25519_*
chmod 644 ~/.ssh/id_ed25519_*.pub
```

**Test SSH connection:**

```bash
ssh -T git@github.com -i ~/.ssh/id_ed25519_blackwell
```

**SSH agent not running:**

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_blackwell
```

### AWS credentials not working

**Check file permissions:**

```bash
ls -la ~/.aws/
# Both files should be 600
chmod 600 ~/.aws/config ~/.aws/credentials
```

**Verify profile exists:**

```bash
aws configure list-profiles
aws sts get-caller-identity --profile dev-profile
```

**SSO session expired:**

```bash
aws sso login --profile dev-profile
```

### Lima VM issues

**VM not starting:**

```bash
limactl stop lima-dev-ubuntu
limactl delete lima-dev-ubuntu
limactl start ~/workspace/dotfiles/lima/lima.yaml
```

**Shared directory not mounted:**

```bash
# Inside Lima
ls ~/workspace
# If empty, check lima.yaml mount configuration
```

**Shell not using zsh:**

```bash
# Set zsh as default
chsh -s $(which zsh)
# Then restart Lima shell
exit
limactl shell lima-dev-ubuntu
```

### Symlinks broken or pointing to wrong location

```bash
# Check current symlinks
ls -la ~/.zshrc ~/.p10k.zsh

# Remove and recreate
rm ~/.zshrc ~/.p10k.zsh
~/workspace/dotfiles/bootstrap-dotfiles.sh
```

### Environment secrets not loading

```bash
# Check if loader script exists
cat ~/.local/load-env.sh

# Source manually to test
source ~/.local/load-env.sh
echo $SOME_EXPECTED_VAR

# If missing, re-run vault restore
./vault/bootstrap-vault.sh
```

---

## License

This repository is licensed under the **MIT License**.

By following this guide, you can fully restore your **dotfiles**, **SSH keys**, **AWS configuration**, **packages via Brewfile**, **Claude workspace**, and **environment secrets** across macOS and Lima/Linux in a reproducible, vault-backed, fully unified way.
