# Dotfiles & Vault Setup

**Version:** 1.0.0 | [Changelog](CHANGELOG.md)

This repository contains my personal dotfiles for **macOS** and **Lima** (Linux), used to configure my development environment consistently across both platforms. The dotfiles include configurations for **Zsh**, **Powerlevel10k**, **Homebrew**, **Claude helpers**, and a **Bitwarden-based vault bootstrap** for SSH keys, AWS config/credentials, and environment secrets.

---

## Table of Contents

- [Quick Start](#quick-start)
- [What's New](#whats-new)
- [Directory Structure](#directory-structure)
- [Canonical Workspace](#canonical-workspace-workspace)
- [Global Prerequisites](#global-prerequisites)
- [Bootstrap Overview](#bootstrap-overview)
- [Bootstrapping macOS from Scratch](#bootstrapping-macos-from-scratch)
- [Bootstrapping Lima / Linux Guest](#bootstrapping-lima--linux-guest)
- [Dotfiles Bootstrap Details](#dotfiles-bootstrap-details)
- [Homebrew & Brewfile](#homebrew--brewfile)
- [Vault / Bitwarden Bootstrap](#vault--bitwarden-bootstrap)
- [Restoring from Bitwarden on Any Machine](#restoring-from-bitwarden-on-any-machine)
- [Scripts: What Each Restore Script Expects](#scripts-what-each-restore-script-expects)
- [Validating Vault Items Before Restore](#validating-vault-items-before-restore)
- [One-Time: Push Current Files into Bitwarden](#one-time-push-current-files-into-bitwarden-for-future-you)
- [Rotating / Updating Secrets in Bitwarden](#rotating--updating-secrets-in-bitwarden)
- [Adding New SSH Keys](#adding-new-ssh-keys)
- [Syncing Local Changes to Bitwarden](#syncing-local-changes-to-bitwarden)
- [Maintenance Checklists](#maintenance-checklists)
- [Using the Dotfiles Day-to-Day](#using-the-dotfiles-day-to-day)
- [Health Check](#health-check)
- [Metrics & Observability](#metrics--observability)
- [CI/CD & Testing](#cicd--testing)
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
cd ~/workspace/dotfiles && ./bootstrap-linux.sh

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

## What's New

### Recent Improvements

**✨ Automation & Quality**
- **Pre-commit Hooks**: Automatic shellcheck validation before commits
- **CI/CD Pipeline**: GitHub Actions testing on macOS + Linux
- **Auto-upgrade Command**: `dotfiles-upgrade` - one-command upgrade with health check

**📊 Metrics & Observability**
- **Health Metrics**: Automatic tracking of health check results over time
- **Visualization**: `show-metrics.sh` for trend analysis and statistics
- **Health Score**: Track dotfiles health (0-100) with historical trends

**🎯 Developer Experience**
- **Update Notifications**: Daily check for dotfiles updates
- **Local Overrides**: Machine-specific customizations via `.zshrc.local`
- **Tab Completions**: ZSH completions for AWS commands, dotfiles tools
- **Better Docs**: Comprehensive review and recommendations in `REVIEW.md`

**🔧 New Commands**
```bash
dotfiles-upgrade          # One-command upgrade flow
show-metrics.sh           # View health metrics and trends
dotfiles-upgrade          # Replaces dotfiles-update (with improvements)
```

See [CHANGELOG.md](CHANGELOG.md) for complete version history.

---

## Directory Structure

The dotfiles are organized as follows:

```text
~/workspace/dotfiles
├── bootstrap-dotfiles.sh     # Shared symlink bootstrap (zshrc, p10k, Ghostty, Claude)
├── bootstrap-linux.sh         # Lima / Linux-specific bootstrap wrapper
├── bootstrap-mac.sh          # macOS-specific bootstrap wrapper
├── check-health.sh           # Verify installation health
├── Brewfile                  # Unified Homebrew bundle (macOS + Lima)
├── CHANGELOG.md              # Version history
├── .gitignore                # Excludes .bw-session, editor files
├── claude
│   ├── settings.json         # Claude Code settings (permissions, preferences)
│   └── commands/             # Custom slash commands
│       └── health.md         # /health - run dotfiles health check
├── ghostty
│   └── config                # Ghostty terminal config
├── lima
│   └── lima.yaml             # Lima VM config (host-side)
├── macos
│   ├── apply-settings.sh     # Apply macOS system settings
│   ├── discover-settings.sh  # Capture/diff macOS settings
│   ├── settings.sh           # The actual settings to apply
│   └── snapshots/            # Setting snapshots for diff
├── vault
│   ├── _common.sh            # Shared library (colors, logging, session, SSH_KEYS)
│   ├── bootstrap-vault.sh    # Orchestrates all Bitwarden restores
│   ├── check-vault-items.sh  # Validates required Bitwarden items exist
│   ├── create-vault-item.sh  # Creates new Bitwarden secure notes
│   ├── delete-vault-item.sh  # Deletes items from Bitwarden (with safety)
│   ├── list-vault-items.sh   # Lists all vault items (debug/inventory)
│   ├── sync-to-bitwarden.sh  # Syncs local changes back to Bitwarden
│   ├── restore-ssh.sh        # Restores SSH keys and config from Bitwarden
│   ├── restore-aws.sh        # Restores ~/.aws/config & ~/.aws/credentials
│   ├── restore-env.sh        # Restores environment secrets to ~/.local
│   ├── restore-git.sh        # Restores ~/.gitconfig from Bitwarden
│   ├── template-aws-config   # Reference template for AWS config
│   ├── template-aws-credentials # Reference template for AWS credentials
│   └── README.md             # Vault system documentation
├── zellij
│   └── config.kdl            # Zellij multiplexer config
└── zsh
    ├── p10k.zsh              # Powerlevel10k theme config
    └── zshrc                 # Main Zsh configuration
```

Key pieces:

- **zsh/zshrc**: Main Zsh configuration file (~820 lines, well-organized sections)
- **zsh/p10k.zsh**: Powerlevel10k theme configuration
- **ghostty/config**: Ghostty terminal configuration
- **zellij/config.kdl**: Zellij multiplexer configuration
- **vault/**: Bitwarden-based secure bootstrap for SSH, AWS, and environment secrets
- **claude/**: Claude Code configuration (settings, slash commands)
- **Brewfile**: Shared Homebrew definition used by both macOS and Lima bootstrap scripts
- **Claude Workspace Symlink** inside `bootstrap-dotfiles.sh` ensures that both macOS and Lima point to the shared workspace directory:

  ```
  ~/.claude → ~/workspace/.claude
  ```

---

## Multi-Platform Architecture

This dotfiles system is designed for extensibility across multiple platforms with **90% shared code**.

### Currently Supported Platforms

| Platform | Bootstrap Script | Status | Notes |
|----------|-----------------|---------|-------|
| **macOS** | `bootstrap-mac.sh` | ✅ Fully tested | Apple Silicon & Intel |
| **Lima VM** | `bootstrap-linux.sh` | ✅ Fully tested | Ubuntu 24.04 |
| **WSL2** | `bootstrap-linux.sh` | ✅ Auto-detected | Windows 10/11 |
| **Ubuntu/Debian** | `bootstrap-linux.sh` | ✅ Compatible | Bare metal or VM |

### Extensible to (15-30 minutes each):
- Docker containers
- Arch Linux
- Fedora/RHEL
- FreeBSD/OpenBSD
- Any POSIX-compliant system with ZSH

### Architecture Layers

```
┌──────────────────────────────────────────────┐
│  Platform-Specific Bootstrap (10% of code)   │
│  • Package manager setup (apt/brew/pacman)   │
│  • System-specific configuration             │
│  • GUI tool installation                     │
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│  Shared Dotfiles Layer (90% of code)         │
│  • Symlink management (bootstrap-dotfiles)   │
│  • Shell configuration (zshrc)               │
│  • Vault system (all scripts)                │
│  • Health checks & metrics                   │
│  • Tab completions                           │
└──────────────────────────────────────────────┘
```

### Platform-Independent Components

These work on **any platform** without modification:

**✅ Vault System** (100% portable)
- All `vault/*.sh` scripts
- Just needs: `zsh`, `bw`, `jq`
- Works on Linux, macOS, BSD, WSL, Docker

**✅ Health & Metrics** (100% portable)
- `check-health.sh`
- `show-metrics.sh`
- Cross-platform file permissions handling

**✅ Shell Configuration** (OS-aware)
- `zshrc` with OS detection
- Conditional loading for macOS/Linux
- Portable modern CLI tools (eza, fzf, etc.)

**✅ Package Management** (cross-platform)
- `Brewfile` works on macOS + Linux (Linuxbrew)
- Conditional sections (`on_macos`, `on_linux`)

### Adding a New Platform

Example: Adding Arch Linux support

```bash
# bootstrap-arch.sh (30 lines)
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. System packages (platform-specific)
sudo pacman -Syu --noconfirm git zsh curl base-devel

# 2. Install yay (AUR helper) or use Homebrew
# ... package manager setup ...

# 3. SHARED: Use same Brewfile
brew bundle --file="$DOTFILES_DIR/Brewfile"

# 4. SHARED: Use same dotfiles bootstrap
"$DOTFILES_DIR/bootstrap-dotfiles.sh"

# 5. Set shell to zsh
chsh -s $(command -v zsh)
```

**That's it!** Everything else (vault, health checks, configs, metrics) just works.

### Platform Detection in Scripts

The bootstrap scripts auto-detect their environment:

```bash
# bootstrap-linux.sh detects:
if grep -qiE "(microsoft|wsl)" /proc/version; then
  PLATFORM="WSL2"
  # Install Windows interop tools
elif [[ -n "${LIMA_INSTANCE:-}" ]]; then
  PLATFORM="Lima"
  # Lima-specific tips
fi
```

The `zshrc` also detects OS:

```bash
OS="$(uname -s)"
case "$OS" in
  Darwin)  # macOS-specific settings ;;
  Linux)   # Linux-specific settings ;;
  FreeBSD) # BSD-specific settings ;;
esac
```

### Why This Architecture Matters

**Portability**: Use the same dotfiles on your:
- Work laptop (macOS)
- Personal laptop (Linux)
- Development VM (Lima/WSL)
- CI/CD containers (Docker)
- Cloud instances (any Linux)

**Maintainability**: Fix a bug or add a feature **once**, benefits **all platforms**.

**Extensibility**: New platform = ~30 lines of platform-specific code + reuse 90%.

---

## Canonical Workspace (`~/workspace`)

A key architectural decision in this setup is the **canonical workspace directory** at `~/workspace`. This serves multiple purposes:

### 1. Username-Agnostic Paths

Your home directory path varies by platform and username:
- macOS: `/Users/dayna.blackwell`
- Lima: `/home/dayna.blackwell.linux` or `/home/ubuntu`
- Work laptop: `/Users/dblackwell`

By standardizing on `~/workspace`, all your scripts, aliases, and configurations can reference a **predictable location** regardless of the underlying username or OS.

### 2. Cross-Platform Mount Point

Lima mounts your macOS home directory into the VM. With `~/workspace` as the canonical location:

```yaml
# lima.yaml
mounts:
  - location: "~"
    writable: true
    sshfs:
      followSymlinks: true
```

Both macOS and Lima see the **same files** at `~/workspace`:
- macOS: `/Users/you/workspace` → actual files
- Lima: `/home/you.linux/workspace` → mounted from macOS

This means:
- Edit code on macOS, run tests in Lima
- Same dotfiles repo accessible from both
- Claude CLI shares state via `~/.claude → ~/workspace/.claude`

### 3. Organizational Structure

The workspace provides a consistent hierarchy:

```
~/workspace/
├── .claude/           # Shared Claude CLI state (symlinked from ~/.claude)
├── .zsh_history       # Shared shell history across platforms
├── .notes.md          # Quick notes captured via note/notes commands
├── dotfiles/          # This repository
├── code/              # Active projects
├── whitepapers/       # Documentation, specs
└── patent-pool/       # IP work
```

**Shared shell history**: Command history is stored in `~/workspace/.zsh_history` so your history follows you between macOS and Lima sessions.

Navigation aliases make this seamless:
- `cws` → `cd ~/workspace`
- `ccode` → `cd ~/workspace/code`
- `dotfiles` → `cd ~/workspace/dotfiles`

### 4. Decoupled from User Identity

Your secrets (SSH keys, AWS creds) live in `~/.ssh` and `~/.aws` (user-specific), but your **work** lives in `~/workspace` (portable). This separation means:

- Secrets are restored per-machine via Bitwarden
- Work files are either shared (Lima mount) or synced (git)
- Dotfiles reference `$WORKSPACE` variable, not hardcoded paths

```bash
# In zshrc
export WORKSPACE="$HOME/workspace"
alias cws='cd "$WORKSPACE"'
```

### 5. Claude Session Portability (`/workspace`)

Claude Code stores session history in `~/.claude/projects/` using **path-encoded folder names**:
- Working in `/Users/dayna/workspace/dotfiles` → sessions in `-Users-dayna-workspace-dotfiles/`
- Working in `/home/ubuntu/workspace/dotfiles` → sessions in `-home-ubuntu-workspace-dotfiles/`

Even with the same files (via Lima mount), different paths = different session folders = lost context.

**Solution**: The bootstrap scripts create a `/workspace` symlink:

```bash
# Created by bootstrap-mac.sh and bootstrap-linux.sh
/workspace → ~/workspace
```

Now you can work from `/workspace/...` on both platforms:

```bash
cd /workspace/dotfiles
claude
# → Sessions stored in -workspace-dotfiles/ on BOTH machines
```

**Usage habit**: Always `cd /workspace/...` instead of `~/workspace/...` when running Claude.

### Visual Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     CANONICAL WORKSPACE ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   macOS                              Lima VM                                 │
│   ══════                             ════════                                │
│   /Users/dayna.blackwell/            /home/ubuntu/                           │
│          │                                  │                                │
│          ├── .ssh/        ←── secrets ──→   ├── .ssh/                        │
│          ├── .aws/        (per-machine)     ├── .aws/                        │
│          ├── .gitconfig                     ├── .gitconfig                   │
│          │                                  │                                │
│          └── workspace/ ←────────────────→  └── workspace/ (mounted)         │
│                 │                                  │                         │
│                 ├── dotfiles/    ════════════     (same files)               │
│                 ├── code/                                                    │
│                 ├── .claude/  ←─── symlinked from ~/.claude                  │
│                 └── ...                                                      │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  KEY INSIGHT: /workspace is the canonical path for Claude            │   │
│   │                                                                      │   │
│   │  /workspace → ~/workspace (symlink created by bootstrap scripts)    │   │
│   │                                                                      │   │
│   │  • cd /workspace/dotfiles && claude  → -workspace-dotfiles/         │   │
│   │  • Same session folder on macOS AND Lima                            │   │
│   │  • Portable session history across platforms                        │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Why This Matters

When you set up a new machine or VM, you don't need to update scripts with new usernames. Everything just works because:

1. `~` expands to the correct home directory
2. `~/workspace` is always where your work lives
3. `/workspace` symlink enables portable Claude sessions
4. Secrets are restored to standard locations (`~/.ssh`, `~/.aws`)
5. Symlinks bridge any gaps (`~/.claude → ~/workspace/.claude`)

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
   - `bootstrap-linux.sh`

   Goal: consistent Zsh + p10k + plugins + Ghostty config + Claude across host and Lima.

2. **Vault / Secure secrets bootstrap (Bitwarden)**

   Handled by:

   - `vault/bootstrap-vault.sh`
   - `vault/restore-ssh.sh`
   - `vault/restore-aws.sh`
   - `vault/restore-env.sh`

   Goal: restore **SSH keys**, **AWS config/credentials**, and **env secrets** from Bitwarden.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DOTFILES ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   NEW MACHINE                                                                │
│       │                                                                      │
│       ▼                                                                      │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                 │
│  │  Bootstrap   │────▶│   Restore    │────▶│   Verify     │                 │
│  │  (packages)  │     │  (secrets)   │     │  (health)    │                 │
│  │              │     │              │     │              │                 │
│  │ bootstrap-   │     │ bootstrap-   │     │ check-       │                 │
│  │ mac/lima.sh  │     │ vault.sh     │     │ health.sh    │                 │
│  └──────────────┘     └──────────────┘     └──────────────┘                 │
│         │                    ▲                     │                        │
│         │                    │                     │                        │
│         ▼                    │                     ▼                        │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                 │
│  │   Brewfile   │     │  Bitwarden   │◀────│  Sync Back   │                 │
│  │   (tools)    │     │   (vault)    │     │  (changes)   │                 │
│  │              │     │              │     │              │
│  │ brew, zsh,   │     │ SSH keys,    │     │ sync-to-     │                 │
│  │ plugins...   │     │ AWS, Git,    │     │ bitwarden.sh │                 │
│  └──────────────┘     │ env secrets  │     └──────────────┘                 │
│                       └──────────────┘                                      │
│                              │                                              │
│                              ▼                                              │
│                    ┌──────────────────┐                                     │
│                    │ check-vault-     │                                     │
│                    │ items.sh         │                                     │
│                    │ (pre-flight)     │                                     │
│                    └──────────────────┘                                     │
│                                                                              │
│   FLOW: Clone repo → Bootstrap → Validate vault → Restore → Health check   │
│         ───────────────────────────────────────────────────────────────     │
│         Edit configs locally → Sync back to Bitwarden → Restore elsewhere  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

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
./bootstrap-linux.sh
```

Typical responsibilities of `bootstrap-linux.sh`:

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
- **Claude setup**: Creates `~/workspace/.claude`, symlinks `~/.claude` to it, and links config files from `dotfiles/claude/`

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

# Modern CLI tools
brew "fzf"       # Fuzzy finder
brew "eza"       # Modern ls
brew "fd"        # Fast find
brew "ripgrep"   # Fast grep
brew "zoxide"    # Smart cd
brew "glow"      # Markdown renderer
brew "dust"      # Disk usage
brew "yazi"      # File manager
brew "yq"        # YAML processor
brew "btop"      # System monitor

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

## macOS System Settings

Lives under:

```
~/workspace/dotfiles/macos
```

These scripts let you capture, track, and restore macOS system preferences (trackpad, keyboard, dock, finder, etc.) across machines.

### Workflow: Discover Your Settings

```bash
cd ~/workspace/dotfiles/macos

# 1. Take a snapshot of current settings
./discover-settings.sh --snapshot

# 2. Change settings in System Preferences (trackpad speed, dock size, etc.)

# 3. See what changed
./discover-settings.sh --diff

# 4. Generate settings.sh from your current preferences
./discover-settings.sh --generate
```

### Workflow: Apply Settings on New Machine

```bash
cd ~/workspace/dotfiles/macos

# Review settings first
./apply-settings.sh --dry-run

# Apply settings
./apply-settings.sh

# Or backup before applying
./apply-settings.sh --backup
```

### What's Included

The default `settings.sh` includes sensible developer defaults for:

| Category | Settings |
|----------|----------|
| **Trackpad** | Tap to click, tracking speed, three-finger drag, natural scrolling |
| **Mouse** | Tracking speed |
| **Keyboard** | Fast key repeat, disable auto-correct/capitalize/smart quotes |
| **Dock** | Size, auto-hide, no recent apps, fast animations |
| **Finder** | Show extensions, hidden files, path bar, list view, no .DS_Store on network |
| **Screenshots** | Location, format, no shadow |
| **Misc** | Expanded save dialogs, password on wake, disable crash reporter |

### Customizing

Edit `macos/settings.sh` directly, or regenerate it from your current preferences:

```bash
# Capture YOUR current settings
./discover-settings.sh --generate

# This overwrites settings.sh with your preferences
```

### Useful Commands

```bash
# List all preference domains on your system
./discover-settings.sh --list-domains

# Dump a specific domain
./discover-settings.sh --domain com.apple.dock

# Dump all tracked domains
./discover-settings.sh --all

# Manual: read a specific setting
defaults read com.apple.dock autohide

# Manual: write a setting
defaults write com.apple.dock autohide -bool true
killall Dock
```

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

  - `"SSH-GitHub-Enterprise"` → SSH key for GitHub Enterprise/SSO
  - `"SSH-GitHub-Blackwell"` → SSH key for Blackwell Systems GitHub
  - `"SSH-Config"` → SSH config file with host mappings

- Each SSH key item's **notes** field should contain:

  - The full **OpenSSH private key** block.
  - Optionally the corresponding `ssh-ed25519 ...` public key line.

- The `SSH-Config` item's **notes** field should contain your full `~/.ssh/config` file.

The script:

- Reconstructs these files:

  - `~/.ssh/id_ed25519_enterprise_ghub`
  - `~/.ssh/id_ed25519_enterprise_ghub.pub`
  - `~/.ssh/id_ed25519_blackwell`
  - `~/.ssh/id_ed25519_blackwell.pub`
  - `~/.ssh/config`

- Sets appropriate permissions (`600` for private keys and config, `644` for public keys).

> **Important:** The exact item names (`SSH-GitHub-Enterprise`, `SSH-GitHub-Blackwell`, `SSH-Config`) must match.

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

### `restore-git.sh`

- Expects a **Secure Note** item named `"Git-Config"`.

- The **notes** field should contain your full `~/.gitconfig` file.

The script:

- Writes this to `~/.gitconfig` (backing up any existing file).
- Sets permissions to `644`.

---

## Validating Vault Items Before Restore

Before running `bootstrap-vault.sh` on a new machine, you can verify all required Bitwarden items exist:

```bash
./vault/check-vault-items.sh
```

Example output:

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
You can safely run: ./bootstrap-vault.sh
```

If items are missing, the script will tell you which ones and exit with an error.

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

### 5. Push SSH config into `SSH-Config`

Your SSH config maps hostnames to identity files, which is essential for multi-key setups:

```bash
SSH_CONFIG_JSON=$(jq -Rs --arg name "SSH-Config" \
  '{ type: 2, name: $name, secureNote: { type: 0 }, notes: . }' \
  < ~/.ssh/config)

SSH_CONFIG_ENC=$(printf '%s' "$SSH_CONFIG_JSON" | bw encode)

bw create item "$SSH_CONFIG_ENC" --session "$BW_SESSION"
```

To **update** it later:

```bash
SSH_CONFIG_ID=$(bw list items --search "SSH-Config" --session "$BW_SESSION" | jq -r '.[0].id')
printf '%s' "$SSH_CONFIG_JSON" | bw encode | bw edit item "$SSH_CONFIG_ID" --session "$BW_SESSION"
```

Example `~/.ssh/config` content:

```text
# GitHub-Enterprise - BWH (current SSO / enterprise alias)
Host github-sso
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_enterprise_ghub
  IdentitiesOnly yes
  AddKeysToAgent yes

# GitHub - Business (Blackwell Systems)
Host github-blackwell
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_blackwell
  IdentitiesOnly yes
```

---

### 6. Push environment secrets into `Environment-Secrets` (optional)

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

### 7. Push Git config into `Git-Config`

Your Git configuration contains your identity (name, email) and preferences:

```bash
GIT_CONFIG_JSON=$(jq -Rs --arg name "Git-Config" \
  '{ type: 2, name: $name, secureNote: { type: 0 }, notes: . }' \
  < ~/.gitconfig)

GIT_CONFIG_ENC=$(printf '%s' "$GIT_CONFIG_JSON" | bw encode)

bw create item "$GIT_CONFIG_ENC" --session "$BW_SESSION"
```

To **update** it later:

```bash
GIT_CONFIG_ID=$(bw list items --search "Git-Config" --session "$BW_SESSION" | jq -r '.[0].id')
printf '%s' "$GIT_CONFIG_JSON" | bw encode | bw edit item "$GIT_CONFIG_ID" --session "$BW_SESSION"
```

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

### 3. Add to `_common.sh` (single source of truth)

Edit `vault/_common.sh` and add the new key to the `SSH_KEYS` array:

```bash
declare -A SSH_KEYS=(
    ["SSH-GitHub-Enterprise"]="$HOME/.ssh/id_ed25519_enterprise_ghub"
    ["SSH-GitHub-Blackwell"]="$HOME/.ssh/id_ed25519_blackwell"
    ["SSH-NewService"]="$HOME/.ssh/id_ed25519_newservice"  # ← Add here
)
```

This automatically propagates to:
- `restore-ssh.sh` (restores the key from Bitwarden)
- `check-health.sh` (validates key exists with correct permissions)

### 4. Add to SSH config

```bash
# ~/.ssh/config
Host newservice.example.com
    IdentityFile ~/.ssh/id_ed25519_newservice
    User git
```

### 5. Update SSH config in Bitwarden

After editing `~/.ssh/config`, sync it back:

```bash
./vault/sync-to-bitwarden.sh SSH-Config
```

### 6. Update zshrc for auto-add (optional)

If you want the new key auto-loaded into the SSH agent, add to `zsh/zshrc`:

```bash
# SSH keys to auto-add (canonical list in vault/_common.sh SSH_KEYS array)
_ssh_add_if_missing ~/.ssh/id_ed25519_newservice
```

---

## Syncing Local Changes to Bitwarden

When you modify local config files (`~/.ssh/config`, `~/.aws/config`, `~/.gitconfig`, etc.), sync them back to Bitwarden so other machines can restore the updates.

### Preview changes (dry run)

```bash
./vault/sync-to-bitwarden.sh --dry-run --all
```

### Sync specific items

```bash
./vault/sync-to-bitwarden.sh SSH-Config           # Just SSH config
./vault/sync-to-bitwarden.sh AWS-Config Git-Config  # Multiple items
```

### Sync all items

```bash
./vault/sync-to-bitwarden.sh --all
```

### Supported items

| Item | Local File |
|------|------------|
| `SSH-Config` | `~/.ssh/config` |
| `AWS-Config` | `~/.aws/config` |
| `AWS-Credentials` | `~/.aws/credentials` |
| `Git-Config` | `~/.gitconfig` |
| `Environment-Secrets` | `~/.local/env.secrets` |

---

## Maintenance Checklists

### Adding a New SSH Key

Complete checklist when adding a new SSH identity:

- [ ] Generate key pair: `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_newkey`
- [ ] Push to Bitwarden (see "Adding New SSH Keys" section above)
- [ ] **Add to `SSH_KEYS` array in `vault/_common.sh`** (propagates to restore + health check)
- [ ] Update `~/.ssh/config` with Host entry
- [ ] Sync SSH config: `./vault/sync-to-bitwarden.sh SSH-Config`
- [ ] Update `zsh/zshrc` - add `_ssh_add_if_missing` line (optional, for ssh-agent)
- [ ] Commit dotfiles changes

### Updating AWS Credentials

When AWS credentials or config change:

- [ ] Edit `~/.aws/config` and/or `~/.aws/credentials`
- [ ] Sync to Bitwarden: `./vault/sync-to-bitwarden.sh AWS-Config AWS-Credentials`
- [ ] Verify on other machines: `bw-restore`

### Adding a New Environment Variable

- [ ] Edit `~/.local/env.secrets`
- [ ] Sync to Bitwarden: `./vault/sync-to-bitwarden.sh Environment-Secrets`
- [ ] Source on current shell: `source ~/.local/load-env.sh`

### Modifying SSH Config (add hosts, change options)

- [ ] Edit `~/.ssh/config`
- [ ] Sync to Bitwarden: `./vault/sync-to-bitwarden.sh SSH-Config`
- [ ] Restore on other machines: `bw-restore`

### Updating Git Config

- [ ] Edit `~/.gitconfig`
- [ ] Sync to Bitwarden: `./vault/sync-to-bitwarden.sh Git-Config`

### New Machine Setup

Complete checklist for a fresh machine:

1. [ ] Clone dotfiles: `git clone ... ~/workspace/dotfiles`
2. [ ] Run bootstrap: `./bootstrap-mac.sh` or `./bootstrap-linux.sh`
3. [ ] Login to Bitwarden: `bw login`
4. [ ] Validate vault items: `./vault/check-vault-items.sh`
5. [ ] Restore secrets: `bw-restore`
6. [ ] Run health check: `./check-health.sh`
7. [ ] Restart shell or `source ~/.zshrc`

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

**Modern CLI (eza - ls replacement):**

- `ls` → `eza --color=auto --group-directories-first`
- `ll` → `eza -la --icons --group-directories-first --git`
- `la` → `eza -a --icons --group-directories-first`
- `lt` → `eza -la --icons --tree --level=2` (tree view)
- `lm` → `eza -la --icons --sort=modified` (by modified time)
- `lr` → `eza -la --icons --sort=size --reverse` (by size)

**Disk usage (dust - du replacement):**

- `du` → `dust` (visual disk usage with bar charts)
- `dus` → `dust -s` (summary only)
- `dud` → `dust -d 1` (depth 1, top-level only)

**File manager (yazi):**

- `y` → Launch yazi file manager (cd to directory on exit)
- `fm` → Alias for `y`
- Inside yazi: `h/j/k/l` to navigate, `Enter` to open, `q` to quit

**YAML processing (yq):**

```bash
yq '.spec.containers[0].image' deployment.yaml   # extract value
cat config.yaml | yq '.database.host'            # pipe input
yq -i '.version = "2.0"' config.yaml             # in-place edit
yq eval-all 'select(.kind == "Service")' *.yaml  # filter multiple files
```

**Fuzzy finder (fzf):**

- `Ctrl+R` → Fuzzy search command history
- `Ctrl+T` → Fuzzy search files (insert path)
- `Alt+C` → Fuzzy cd to directory
- `**<tab>` → Fuzzy completion (e.g., `vim **<tab>`)

**Navigation:**

- `cws` → `cd ~/workspace`
- `ccode` → `cd ~/workspace/code`
- `cwhite` → `cd ~/workspace/whitepapers`
- `cpat` → `cd ~/workspace/patent-pool`
- `j` → Fuzzy jump to any git project in `/workspace` (requires fzf)

**Smart directory jumping (zoxide):**

- `z <partial>` → Jump to directory matching pattern (learns your habits)
- `z dot` → Jumps to ~/workspace/dotfiles (after visiting once)
- `z code` → Jumps to ~/workspace/code
- `zi` → Interactive selection with fzf

**Markdown viewing (glow):**

- `md <file>` → Render markdown file beautifully in terminal
- `readme` → Shortcut for `glow README.md`

**Quick Notes:**

- `note <text>` → Save timestamped note to `~/workspace/.notes.md`
- `notes` → View last 20 notes
- `notes all` → View all notes
- `notes edit` → Open notes file in editor
- `notes search <term>` → Search notes

**Vault:**

- `bw-restore` → Run Bitwarden vault bootstrap

**Dotfiles Management:**

- `dotfiles` → `cd ~/workspace/dotfiles`
- `dotfiles-doctor` → Run health check + vault item validation
- `dotfiles-update` → Pull latest dotfiles and re-source zshrc
- `status` → Quick dashboard showing symlinks, SSH, AWS, Lima status

**AWS Profile Management:**

- `awstools` → **Show all AWS commands** with ASCII banner + current status
- `awsprofiles` → List all configured profiles (marks active one)
- `awsswitch` → Interactive profile selector with fzf (auto-login if needed)
- `awsset <profile>` → Set AWS_PROFILE for current shell
- `awsunset` → Clear AWS_PROFILE (return to default)
- `awswho` → Show current AWS identity (account, user, ARN)
- `awslogin [profile]` → SSO login (defaults to current or dev-profile)
- `awsassume <role-arn>` → Assume a role for cross-account access
- `awsclear` → Clear temporary assumed-role credentials

```bash
# Typical workflow
awsswitch              # fuzzy-select profile, auto-login
awswho                 # verify identity

# Or manually
awsset prod-profile
awslogin
```

**Lima VM (macOS only):**

- `lima-dev` → Shell into dev-ubuntu VM
- `lima-start` → Start the VM
- `lima-stop` → Stop the VM
- `lima-status` → List VM status

**Zellij (terminal multiplexer):**

- `Ctrl+g` → Enter mode selection (default leader)
- `Alt+←/→/↑/↓` → Switch between panes
- `Alt+n/p` → Next/previous tab
- `Alt+1-9` → Jump to tab by number
- `Ctrl+t` → New tab
- In scroll mode: arrows, PageUp/Down, Home/End

**Claude Code:**

- `claude` → Wrapper that auto-uses `/workspace` path for portable sessions
- `claude-bedrock` → Run Claude via AWS Bedrock
- `claude-max` → Run Claude via Max subscription

**Clipboard (cross-platform):**

- `copy` / `cb` → Copy stdin to clipboard (works on macOS, Linux X11/Wayland, WSL)
- `paste` / `cbp` → Paste clipboard to stdout

```bash
# Examples
cat file.txt | copy
echo "hello" | copy
paste > pasted.txt
```

**System monitoring:**

- `btop` → Beautiful system monitor (htop replacement)

### Shell Performance

NVM and SDKMAN are lazy-loaded to speed up shell startup. They only initialize when you actually use them:

- **NVM**: Loads when you run `nvm`, `node`, `npm`, `npx`, `yarn`, `pnpm`, or `corepack`
- **SDKMAN**: Loads when you run `sdk`, `java`, `gradle`, `mvn`, `kotlin`, `groovy`, or `scala`

This saves ~200-400ms on every new shell. Measure your startup time with:

```bash
time zsh -i -c exit
```

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

## Health Check

Run the health check script to verify your dotfiles installation:

```bash
./check-health.sh
```

The script verifies:

- **Symlinks**: `~/.zshrc`, `~/.p10k.zsh`, Ghostty config, Claude workspace
- **Required commands**: brew, zsh, git, jq, bw, aws
- **SSH keys and config**: Existence and correct permissions (600 for private keys and config, 644 for public keys)
- **AWS configuration**: Config and credentials files with correct permissions
- **Environment secrets**: `~/.local/env.secrets` and loader script
- **Bitwarden status**: Login and unlock state
- **Shell configuration**: Default shell, plugin availability
- **Workspace layout**: Required directories exist

**Auto-fix mode**: Run with `--fix` to automatically correct permission issues:

```bash
./check-health.sh --fix
```

**Drift detection**: Run with `--drift` to compare local files vs Bitwarden:

```bash
./check-health.sh --drift
```

This checks if your local `~/.ssh/config`, `~/.aws/config`, `~/.gitconfig`, etc. differ from what's stored in Bitwarden. Useful for detecting unsync'd changes before switching machines.

Example drift output:

```
=== Drift Detection (Local vs Bitwarden) ===
[OK] SSH-Config: in sync
[OK] AWS-Config: in sync
[WARN] Git-Config: LOCAL DIFFERS from Bitwarden

To sync local changes to Bitwarden:
  ./vault/sync-to-bitwarden.sh --all
```

Example output:

```
=== Symlinks ===
[OK] ~/.zshrc -> /Users/you/workspace/dotfiles/zsh/zshrc
[OK] ~/.p10k.zsh -> /Users/you/workspace/dotfiles/zsh/p10k.zsh

=== Required Commands ===
[OK] brew (Homebrew 4.x.x)
[OK] zsh (zsh 5.9)
[OK] jq (jq-1.7)

=== SSH Keys ===
[OK] id_ed25519_blackwell (permissions: 600)
[OK] id_ed25519_blackwell.pub (permissions: 644)
[OK] ~/.ssh/config (permissions: 600)

========================================
Health check passed!
========================================
```

Use this after initial setup or when debugging issues.

---

## Metrics & Observability

The dotfiles now include comprehensive metrics collection to track health over time.

### Automatic Metrics Collection

Every time you run `check-health.sh`, metrics are automatically recorded to `~/.dotfiles-metrics.jsonl`:

```json
{
  "timestamp": "2025-11-27T10:30:00-08:00",
  "hostname": "macbook-pro",
  "os": "Darwin",
  "errors": 0,
  "warnings": 2,
  "fixed": 1,
  "health_score": 90,
  "git_branch": "main",
  "git_commit": "abc1234"
}
```

### Viewing Metrics

Use the `show-metrics.sh` script to visualize your dotfiles health:

```bash
# Summary view (default)
./show-metrics.sh

# Graph of health score trend
./show-metrics.sh --graph

# All recorded entries
./show-metrics.sh --all
```

**Example output:**
```
=== Dotfiles Health Metrics Summary ===

Total health checks: 47

Last 10 health checks:
✅ 2025-11-27 | Score: 100/100 | E:0 W:0 | main
✅ 2025-11-26 | Score: 95/100 | E:0 W:1 | main
⚠️  2025-11-25 | Score: 85/100 | E:0 W:3 | feature-branch

Statistics:
  Average health score: 94/100
  Total errors found:   3
  Total warnings found: 28
  Total auto-fixed:     15
  Perfect runs:         35 (74%)

Recent trend (last 5 vs previous 5):
  📈 Improving (92 → 96)
```

### Health Score Calculation

- **Perfect (100)**: No errors, no warnings
- **Each error**: -10 points
- **Each warning**: -5 points
- **Minimum**: 0 points

### Metrics in Aliases

Add to your workflow:

```bash
# Check health and view trends
check-health.sh && show-metrics.sh --graph

# Auto-fix and track
check-health.sh --fix && show-metrics.sh
```

---

## CI/CD & Testing

The dotfiles repository includes comprehensive automated testing via GitHub Actions.

### Continuous Integration

Every push and pull request triggers automated tests:

**Test Jobs:**
1. **ShellCheck Validation**: Validates all shell scripts for syntax and best practices
2. **Markdown Linting**: Checks documentation quality
3. **Repository Structure**: Validates required files exist
4. **Secrets Scanning**: Ensures no secrets in repository
5. **macOS Compatibility**: Tests scripts on macOS
6. **Linux Compatibility**: Tests scripts on Linux
7. **Documentation Quality**: Validates README completeness

### GitHub Actions Workflow

Location: `.github/workflows/test.yml`

```yaml
name: Test Dotfiles
on: [push, pull_request]

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run shellcheck
        run: shellcheck bootstrap-*.sh vault/*.sh check-health.sh
  # ... more jobs
```

### Pre-commit Hooks

Local validation before you commit:

**Installed hooks:**
- ShellCheck validation of all scripts
- Auto-fails commit if validation errors found
- Provides clear error messages

**Bypass if needed:**
```bash
git commit --no-verify  # Use sparingly!
```

### Running Tests Locally

```bash
# Install shellcheck
brew install shellcheck

# Run on all scripts
shellcheck bootstrap-*.sh vault/*.sh check-health.sh

# Check specific script
shellcheck vault/bootstrap-vault.sh
```

### Status Badges

Add to your forked README:

```markdown
![Test Status](https://github.com/your-username/dotfiles/workflows/Test%20Dotfiles/badge.svg)
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
