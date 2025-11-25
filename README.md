# Dotfiles & Vault Setup

This repository contains my personal dotfiles for **macOS** and **Lima** (Linux), used to configure my development environment consistently across both platforms. The dotfiles include configurations for **Zsh**, **Powerlevel10k**, **Homebrew**, **Claude helpers**, and a **Bitwarden-based vault bootstrap** for SSH keys, AWS config/credentials, and environment secrets.

---

## Directory Structure

The dotfiles are organized as follows:

```text
~/workspace/dotfiles
├── bootstrap-dotfiles.sh     # Shared symlink bootstrap (zshrc, p10k, Ghostty)
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

Symlinks in your home directory (`~/.zshrc`, `~/.p10k.zsh`, etc.) point to these files.

---

## Global Prerequisites

On **both macOS and Lima/Linux**, you’ll eventually want:

- **Zsh** as your login shell  
- **Homebrew** (macOS or Linuxbrew)  
- **Git**  
- **Bitwarden CLI** (`bw`)  
- **jq** (for JSON manipulation)  
- **AWS CLI v2** (for AWS workflows)

You can install most of these via Homebrew (after the basic bootstrap is done).

---

## Bootstrap Overview

There are two big pillars:

1. **Dotfiles / Shell bootstrap**

   Handled by:

   - `bootstrap-dotfiles.sh`
   - `bootstrap-mac.sh`
   - `bootstrap-lima.sh`

   Goal: consistent Zsh + p10k + plugins + Ghostty config across host and Lima.

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
  - Ghostty config symlink into:

    ```text
    ~/Library/Application Support/com.mitchellh.ghostty/config
    ```

4. **Open a new terminal**

This ensures the new `~/.zshrc` and Powerlevel10k config are picked up.

---

## Bootstrapping Lima / Linux Guest

Assuming your Lima VM shares `~/workspace` from macOS:

1. **Start Lima with your config**

On macOS, from your dotfiles repo:

```bash
limactl start ~/workspace/dotfiles/lima/lima.yaml
limactl shell lima-dev-ubuntu
```

2. **Inside Lima, run the Lima bootstrap**

```bash
cd ~/workspace/dotfiles
./bootstrap-lima.sh
```

Typical responsibilities of `bootstrap-lima.sh`:

- Ensure **Linuxbrew** (`brew`) is installed.  
- Ensure `brew` is on `PATH`.  
- Run the **same Brewfile** as macOS:

  ```bash
  brew bundle --file="$DOTFILES_DIR/Brewfile"
  ```

- Call `bootstrap-dotfiles.sh` to wire up `.zshrc`, `.p10k.zsh`, and any Linux-specific pieces if needed.

3. **Restart the shell**

Open a new shell in Lima so Zsh + Powerlevel10k + plugins are active.

---

## Dotfiles Bootstrap Details

### `bootstrap-dotfiles.sh`

This is the **central symlink script**. It:

- Detects `DOTFILES_DIR` (usually `~/workspace/dotfiles`)  
- Creates or force-updates symlinks:

  - `~/.zshrc    -> $DOTFILES_DIR/zsh/zshrc`  
  - `~/.p10k.zsh -> $DOTFILES_DIR/zsh/p10k.zsh`  
  - Ghostty config symlink on macOS (under `~/Library/Application Support/com.mitchellh.ghostty/config`)

OS-specific scripts (`bootstrap-mac.sh`, `bootstrap-lima.sh`) call this; you can also run it manually if you need to re-point symlinks.

---

## Homebrew & Brewfile

The **Brewfile** at the root of the repo:

```text
~/workspace/dotfiles/Brewfile
```

is the single source of truth for Homebrew packages on **both** macOS and Lima.

- `bootstrap-mac.sh` and `bootstrap-lima.sh` both run:

  ```bash
  brew bundle --file="$DOTFILES_DIR/Brewfile"
  ```

- Cross-platform formulae can be listed normally, for example:

  ```ruby
  brew "git"
  brew "zsh"
  brew "tmux"
  brew "node"
  brew "zellij"
  brew "powerlevel10k"
  brew "zsh-autosuggestions"
  brew "zsh-syntax-highlighting"
  ```

- macOS-only GUI tools can be added as `cask` lines; these are effectively ignored on Linux:

  ```ruby
  cask "ghostty"
  cask "vscodium"
  cask "microsoft-edge"
  cask "claude-code"
  cask "nosql-workbench"
  cask "mongodb-compass"
  cask "rectangle"
  cask "font-meslo-for-powerlevel10k"
  ```

> Over time, you can refine the Brewfile to exactly what you consider “baseline” for both environments.

### Updating the Brewfile

On a machine that’s already configured the way you like:

1. Install tools as normal:

   ```bash
   brew install <formula>
   brew install --cask <something>   # macOS only
   ```

2. Regenerate the Brewfile from the current system:

   ```bash
   cd ~/workspace/dotfiles
   brew bundle dump --force --file=./Brewfile
   ```

3. Review and prune anything that shouldn’t be part of the “global default” setup, then commit.

If you ever need to, you can later split into `Brewfile.mac` / `Brewfile.lima`, but for now a unified Brewfile keeps everything simple and reproducible.

---

## Vault / Bitwarden Bootstrap

The **vault system** lives entirely under:

```text
~/workspace/dotfiles/vault
    ├── bootstrap-vault.sh
    ├── restore-ssh.sh
    ├── restore-aws.sh
    └── restore-env.sh
```

### What it does

- Uses **Bitwarden CLI** to unlock your vault and cache a session.  
- Restores:
  - `~/.ssh/…` keys used for GitHub and other services.  
  - `~/.aws/config` and `~/.aws/credentials`.  
  - Environment secrets into `~/.local/env.secrets` + a helper `load-env.sh`.

### Bitwarden basics for this setup

1. **Login (once per machine)**

```bash
bw login
# follow prompts for email + master password
```

2. **Unlock to get a session**

You can either:

```bash
export BW_SESSION="$(bw unlock --raw)"
```

or let `vault/bootstrap-vault.sh` manage its own cached session file.

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

- Each item’s **notes** field should contain:

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

The idea: run these **once** on a “known-good” machine (your macOS host), so future machines can restore from Bitwarden with `bootstrap-vault.sh`.

You can also do all of this manually in the Bitwarden GUI, but here’s the CLI version for reproducibility.

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

You’ll create one note per SSH identity:

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

## Using the Dotfiles Day-to-Day

### Claude helpers

From your shell, you have helpers like:

- `claude-bedrock "prompt..."`  
- `claude-max "prompt..."`  
- `claude-run bedrock "prompt..."`  
- `claude-run max "prompt..."`

These functions set the correct environment variables so you can cleanly switch between AWS Bedrock and Claude Max.

### Navigation aliases

Defined in `zsh/zshrc`:

- `cws`     → `cd ~/workspace`  
- `ccode`   → `cd ~/workspace/code`  
- `cwhite`  → `cd ~/workspace/whitepapers`  
- `cpat`    → `cd ~/workspace/patent-pool`

You can tweak these in `zsh/zshrc` as your workspace grows.

---

## Troubleshooting

### Powerlevel10k / icons missing

- Ensure Powerlevel10k is installed via Homebrew:

  ```bash
  brew install powerlevel10k
  ```

- Make sure your terminal uses a Nerd Font (configured in Ghostty / terminal preferences).  
- Verify `~/.p10k.zsh` exists and is symlinked correctly.

### Bitwarden CLI weirdness

- Confirm:

  ```bash
  bw --version
  bw login
  export BW_SESSION="$(bw unlock --raw)"
  bw list items --session "$BW_SESSION" | head
  ```

- If something gets wedged, you can log out and log in again:

  ```bash
  bw logout
  bw login
  export BW_SESSION="$(bw unlock --raw)"
  ```

---

## License

This repository is licensed under the **MIT License**.

By following this guide, you can fully restore your **dotfiles**, **SSH keys**, **AWS configuration**, **packages via Brewfile**, and **environment secrets** across macOS and Lima/Linux in a reproducible, vault-backed way.

