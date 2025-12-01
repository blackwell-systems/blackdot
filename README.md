# Dotfiles & Vault Setup

[![Blackwell Systems™](https://raw.githubusercontent.com/blackwell-systems/blackwell-docs-theme/main/badge-trademark.svg)](https://github.com/blackwell-systems)
[![Claude Code](https://img.shields.io/badge/Built_for-Claude_Code-8A2BE2?logo=anthropic)](https://claude.ai/claude-code)
[![Secrets](https://img.shields.io/badge/Secrets-Multi--Vault-ff4081)](https://github.com/blackwell-systems/dotfiles#vault--secrets)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows%20%7C%20WSL2%20%7C%20Docker-blue)](https://github.com/blackwell-systems/dotfiles)

[![Shell](https://img.shields.io/badge/Shell-Zsh-89e051?logo=zsh&logoColor=white)](https://www.zsh.org/)
[![Test Status](https://github.com/blackwell-systems/dotfiles/workflows/Test%20Dotfiles/badge.svg)](https://github.com/blackwell-systems/dotfiles/actions)
[![Tests](https://img.shields.io/badge/Tests-124-brightgreen)](test/)
[![Version](https://img.shields.io/github/v/release/blackwell-systems/dotfiles)](https://github.com/blackwell-systems/dotfiles/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Sponsor](https://img.shields.io/badge/Sponsor-Buy%20Me%20a%20Coffee-yellow?logo=buy-me-a-coffee&logoColor=white)](https://buymeacoffee.com/blackwellsystems)

> **The first dotfiles designed for AI-assisted development.** Opinionated, batteries-included configuration for developers who use Claude Code across machines. Multi-vault secrets, portable sessions, machine-specific templates, and self-healing config.

[Changelog](CHANGELOG.md) | [Full Documentation](docs/README-FULL.md)

---

## Dotfiles for the AI-assisted development era

> **"Start on Mac, continue on Linux, keep your conversation."**

If you use Claude Code across multiple machines, this is the only dotfiles solution that:

1. **Portable Sessions** – `/workspace` symlink ensures identical paths everywhere. Claude sessions sync seamlessly.
2. **Auto-Redirect** – Work in `~/workspace/project`? Claude automatically uses `/workspace/project` for session continuity.
3. **Multi-Backend Support** – Works with Claude via Anthropic Max, AWS Bedrock, or any provider.

---

## Features

### Core (works everywhere)
- **Interactive setup wizard** – `dotfiles init` guides you through platform detection, vault selection (Bitwarden/1Password/pass), and secret restoration. One command, complete setup.
- **Multi-vault secret management** – SSH keys, AWS credentials, Git config synced with your choice of Bitwarden, 1Password, or pass. Unified API across all backends.
- **Claude Code integration** – Portable sessions across machines via `/workspace` symlink. Start on Mac, continue on Linux, same conversation. Auto-redirect from `~/workspace` keeps sessions synced.
- **Self-healing configuration** – Health checker with `--fix` mode. Drift detection catches local vs vault differences before they cause problems.
- **Machine-specific templates** – Generate configs tailored to each machine (work vs personal, macOS vs Linux). Variables, conditionals, loops.
- **Modern CLI stack** – eza, fzf, ripgrep, zoxide, bat, yazi—configured and ready. Lazy-loaded for fast shell startup.
- **Idempotent design** – Run bootstrap repeatedly. Scripts converge to known-good state. Safe to re-run anytime.
- **Comprehensive testing** – 124 tests ensure reliability across platforms. Unit, integration, and error scenario coverage.

### Advanced (opt-in)
- **Cross-platform portability** – Same dotfiles on macOS, Linux, Windows, WSL2, or Docker. 90% shared code, 10% platform-specific.
- **Metrics and observability** – Track dotfiles health over time. Visualize trends, catch regressions early.
- **Git safety hooks** – Defensive hooks block dangerous git commands (force push, hard reset, secrets commits). [Learn more](docs/claude-code.md)
- **Docker test environment** – Try the entire system in a disposable Alpine container before installing. 30-second trust verification.

---

## How This Compares

### Quick Comparison

| Capability           | This Repo                                      | Typical Dotfiles                 |
|----------------------|-----------------------------------------------|----------------------------------|
| **Secrets management** | Multi-vault (Bitwarden, 1Password, pass)      | Manual copy between machines     |
| **Health validation**  | Checker with `--fix`                          | None                             |
| **Drift detection**    | Compare local vs vault state                  | None                             |
| **Schema validation**  | Validates SSH keys & config structure         | None                             |
| **Unit tests**         | 80+ bats-core tests                           | Rare                             |
| **Docker support**     | Full Dockerfile for containerized bootstrap   | Rare                             |
| **Modular shell config** | 10 modules in `zsh.d/`                      | Single monolithic file           |
| **Optional components** | `SKIP_*` env flags                           | All-or-nothing                   |
| **Cross-platform**     | macOS, Linux, Windows, WSL2, Docker           | Usually single-platform          |

### Why This Repo vs chezmoi?

chezmoi is the most popular dotfiles manager. Here's how we compare:

| Feature | This Repo | chezmoi |
|---------|-----------|---------|
| **Secret Management** | 3 vault backends (bw/op/pass) with unified API | External tools only (no unified API) |
| **Bidirectional Sync** | Local ↔ Vault | Templates only (one-way) |
| **Claude Code Sessions** | Native integration | None |
| **Health Checks** | Yes, with auto-fix | None |
| **Drift Detection** | Local vs Vault comparison | `chezmoi diff` (files only) |
| **Schema Validation** | SSH keys, configs | None |
| **Machine Templates** | Custom engine | Go templates |
| **Cross-Platform** | 5 platforms + Docker | Excellent |
| **Learning Curve** | Shell scripts | YAML + Go templates |
| **Single Binary** | Requires zsh | Go binary |

### Detailed Comparison vs Popular Dotfiles

<details>
<summary><b>Feature Matrix: This Repo vs thoughtbot, holman, mathiasbynens, YADR</b></summary>

| Feature | This Repo | thoughtbot | holman | mathiasbynens | YADR |
|---------|-----------|------------|--------|---------------|------|
| **Secrets Management** | Multi-vault (bw/op/pass) | Manual | Manual | Manual | Manual |
| **Bidirectional Sync** | Local ↔ Vault | No | No | No | No |
| **Cross-Platform** | macOS, Linux, Windows, WSL2, Docker | Limited | macOS only | macOS only | Limited |
| **Claude Code Sessions** | Portable via `/workspace` | No | No | No | No |
| **Health Checks** | Yes, with auto-fix | No | No | No | No |
| **Drift Detection** | Local vs Vault | No | No | No | No |
| **Schema Validation** | SSH keys, configs | No | No | No | No |
| **Unit Tests** | 80+ bats tests | No | No | No | No |
| **CI/CD Integration** | GitHub Actions | Basic | No | No | No |
| **Modular Shell Config** | 10 modules | Monolithic | Monolithic | Monolithic | Partial |
| **Optional Components** | SKIP_* flags | No | No | No | No |
| **Docker Bootstrap** | Full Dockerfile | No | No | No | No |
| **One-Line Installer** | Interactive mode | Basic | No | No | Yes |
| **Documentation Site** | Docsify (searchable) | README only | README only | README only | Wiki |
| **Vault Item Templates** | With validation | No | No | No | No |
| **Team Onboarding** | <5 min setup | ~30 min | ~30 min | ~30 min | ~45 min |
| **macOS System Prefs** | 137 settings | No | Extensive | Extensive | No |
| **Active Maintenance** | 2024 | Sporadic | Archived | Sporadic | Minimal |

#### Key Differentiators

**vs thoughtbot/dotfiles:**
- **Secrets Management**: Multi-vault backends vs manual copying
- **Cross-Platform**: Full Docker/WSL2/Lima support vs macOS/Linux only
- **Health Monitoring**: Comprehensive checks vs none
- **Testing**: Unit tests + CI vs basic install script

**vs holman/dotfiles:**
- **Active Development**: Regular updates vs archived (2018)
- **Enterprise Ready**: Multi-vault support, team onboarding vs personal use
- **Cross-Platform**: Multi-OS support vs macOS only
- **Portability**: Claude Code sessions, /workspace symlink vs static paths

**vs mathiasbynens/dotfiles:**
- **Secrets Management**: Multi-vault system vs exposed in git
- **Health Validation**: Auto-fix capability vs none
- **Cross-Platform**: Full Linux/WSL2 support vs macOS focus
- **Testing**: Automated tests vs manual verification
- **Similar**: Both have extensive macOS system preferences

**vs YADR (Yet Another Dotfile Repo):**
- **Lighter Weight**: Focused tooling vs kitchen sink approach
- **Secrets Safety**: Multi-vault backends vs all in git
- **Modern Stack**: eza, fzf, zoxide vs older tools
- **Maintenance**: Active vs minimal updates
- **Similar**: Both aim for comprehensive setup

#### What Makes This Unique

1. **Only dotfiles with multi-vault backend support** - Bitwarden, 1Password, or pass with unified API
2. **Only dotfiles with Claude Code session portability** - `/workspace` symlink + auto-redirect
3. **Only dotfiles with comprehensive health checks** - Validator with auto-fix
4. **Only dotfiles with drift detection** - Compare local vs vault state
5. **Only dotfiles with schema validation** - Ensures SSH keys/configs are valid before restore
6. **Only dotfiles with Docker bootstrap testing** - Reproducible CI/CD environments
7. **Only dotfiles with machine-specific templates** - Auto-generate configs for work vs personal machines

</details>

### What you get

- **Vault-backed secrets**: SSH keys, AWS credentials, and configs live in your vault (Bitwarden, 1Password, or pass)—not scattered across machines or committed to git
- **Self-healing dotfiles**: Health checks catch permission drift, broken symlinks, and missing vault items. Auto-fix with `--fix`
- **Observable state**: Track health metrics over time, detect when things break
- **Tested**: CI runs shellcheck, zsh syntax validation, and unit tests on every push

### Modern, opinionated defaults

| Choice | Default | Why |
|--------|---------|-----|
| Shell | Zsh + Powerlevel10k | Fast, extensible, great prompts |
| Package manager | Homebrew | Works on macOS and Linux |
| CLI tools | eza, fzf, ripgrep, bat | Modern replacements for ls, find, grep, cat |
| Secrets | Vault-backed (not in git) | Security best practice |
| Structure | Modular `zsh.d/` | Easier to maintain than monolithic |

Override anything in `99-local.zsh` or fork to customize.

### What's optional

Everything works on a single machine. Cross-platform sync, Claude session portability, and vault integration are opt-in:

```bash
# Minimal install (no vault, no /workspace symlink, no Claude setup)
SKIP_WORKSPACE_SYMLINK=true SKIP_CLAUDE_SETUP=true ./bootstrap/bootstrap-linux.sh

# Then manually configure ~/.ssh, ~/.aws, ~/.gitconfig
```

> 💡 **Don't use a vault manager?** No problem!
>
> The vault system is completely optional. Run with `--minimal` flag:
> ```bash
> curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash -s -- --minimal
> ```
> Then manually configure `~/.ssh`, `~/.aws`, `~/.gitconfig`. All shell config, aliases, and tools still work!
>
> Or choose your preferred vault backend: Bitwarden (default), 1Password, or pass.

Inspired by: holman/dotfiles, thoughtbot/dotfiles, mathiasbynens/dotfiles

---

## Prerequisites

**Required:**
- A supported environment: macOS, Windows, Linux, WSL2, or Lima
- Internet access (for installing packages)

**Auto-installed (if missing):**
- Git (via Xcode tools on macOS or apt on Linux)
- Homebrew/Linuxbrew (bootstrap will install)
- Modern CLI tools (eza, fzf, ripgrep, etc. via Brewfile)

**Optional (for vault features only):**
- **Vault CLI** - Bitwarden (`bw`), 1Password (`op`), or pass for automated secret sync
  - Skip with `--minimal` flag (or just don't run `dotfiles vault` commands)
  - Without vault: manually configure `~/.ssh`, `~/.aws`, `~/.gitconfig`

**Optional (for Claude Code portable sessions):**
- **Claude Code installed** - For cross-machine session sync
  - Skip with `SKIP_CLAUDE_SETUP=true`

To clone via SSH (recommended), you’ll also want an SSH key configured with GitHub. If you don’t have Git yet, you can either:
- install it the way you normally would on your platform, or  
- download this repository as a ZIP from GitHub, extract it, and run `bootstrap-mac.sh` / `bootstrap-linux.sh` / `bootstrap-windows.sh` – the scripts will install Git and configure your environment.

---

## Try Before Installing

**Don't trust random install scripts?** Smart! Test the entire system in a disposable Alpine container (< 30 seconds):

```bash
git clone https://github.com/blackwell-systems/dotfiles.git
cd dotfiles
docker build -f Dockerfile.lite -t dotfiles-lite .
docker run -it --rm dotfiles-lite

# Inside container - explore safely:
dotfiles status      # See what's configured
dotfiles doctor      # Run health checks
dotfiles help        # View all commands
exit                 # Container auto-deletes
```

**Why Alpine?** Lightweight (5MB base), fast boot, isolated environment. Perfect for trust-but-verify.

**→ [Full Test Drive Guide](docs/TESTDRIVE.md)** - Sample workflows, dotclaude integration, troubleshooting

---

## One-Line Install

**Recommended (interactive setup):**
```bash
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash -s -- --interactive
```

This launches the setup wizard which:
- Auto-detects your platform (macOS, Linux, WSL2)
- Detects available vault CLIs (Bitwarden, 1Password, pass)
- Prompts you to choose your vault (or skip)
- Restores secrets and validates setup

**Other install options:**

```bash
# Default (non-interactive)
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash

# Minimal mode - skip vault and optional features
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash -s -- --minimal
```

---

## Quick Start (Manual)

```bash
# 1. Clone
git clone git@github.com:blackwell-systems/dotfiles.git ~/workspace/dotfiles
cd ~/workspace/dotfiles

# 2. Run interactive setup wizard
dotfiles init
```

**That's it!** The wizard handles:
- Platform detection and bootstrap
- Vault selection (Bitwarden, 1Password, pass, or skip)
- Secret restoration
- Health validation

> **💡 Why `~/workspace`?** Bootstrap creates `/workspace → ~/workspace` symlink for **portable Claude Code sessions**. Use `/workspace/project` paths and your AI conversations sync across macOS, Linux, WSL—same session folder, same history. [Learn more](docs/README-FULL.md#canonical-workspace-workspace)

<details>
<summary><b>Don't use a vault manager?</b></summary>

The vault system supports Bitwarden, 1Password, and pass. Or skip it entirely:

**Option 1: Use `--minimal` flag**
```bash
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash -s -- --minimal
```

**Option 2: Skip step 3 and manually configure:**
- `~/.ssh/` – your SSH keys
- `~/.aws/` – your AWS credentials
- `~/.gitconfig` – your git identity
- `~/.local/env.secrets` – environment variables

All shell config, aliases, functions, and CLI tools still work. Only vault sync features are disabled.
</details>

<details>
<summary><b>Optional Components (environment variables)</b></summary>

Skip optional features using environment variables:

```bash
# Skip /workspace symlink creation (single-machine setup)
SKIP_WORKSPACE_SYMLINK=true ./bootstrap/bootstrap-mac.sh

# Skip Claude Code setup
SKIP_CLAUDE_SETUP=true ./bootstrap/bootstrap-linux.sh

# Combine flags
SKIP_WORKSPACE_SYMLINK=true SKIP_CLAUDE_SETUP=true ./bootstrap/bootstrap-mac.sh
```

**Available flags:**
- `SKIP_WORKSPACE_SYMLINK=true` – Skip `/workspace` symlink creation (for single-machine setups)
- `SKIP_CLAUDE_SETUP=true` – Skip `~/.claude` configuration symlink
- `DOTFILES_OFFLINE=1` – Skip all vault operations (for air-gapped or offline environments)
- `DOTFILES_SKIP_DRIFT_CHECK=1` – Skip drift check before vault restore (useful for CI/automation)

All features are opt-in by default and can be disabled without breaking the rest of the setup.
</details>

---

## Use Cases

- **Single Linux machine** – Vault-backed secrets, health checks, modern CLI. No cross-platform complexity.

- **macOS daily driver** – Full experience including Ghostty terminal config and macOS system preferences.

- **Docker/CI environments** – Bootstrap in containers for reproducible builds. Vault restore from CI secrets.

- **Air-gapped/Offline** – Use `DOTFILES_OFFLINE=1` when vault isn't available. Vault operations skip gracefully.

- **Multi-machine workflow** – Develop on macOS, test on Linux VM, deploy from WSL. Same dotfiles, same secrets, same Claude sessions everywhere.

- **Team onboarding** – New developer? Clone, bootstrap, unlock vault. Consistent environment in minutes, not days.

---

## What Gets Installed

### Shell & Prompt
- Zsh with Powerlevel10k theme
- Auto-suggestions and syntax highlighting
- Modern CLI replacements (eza, bat, fd, ripgrep)

### Development Tools
- Homebrew package manager
- Git, GitHub CLI, Node.js
- Docker, Lima (Linux VM)
- AWS CLI, Vault CLI (Bitwarden/1Password/pass)

### Configurations
- SSH keys and config (from vault)
- AWS credentials and config (from vault)
- Git configuration (from vault)
- Environment secrets (from vault)
- Claude Code settings (shared workspace)

See [Brewfile](Brewfile) for complete package list.

---

## Key Concepts

<details>
<summary><h3>Workspace Architecture (Portable Sessions)</h3></summary>

Bootstrap creates `/workspace → ~/workspace` symlink for **portable Claude Code sessions** across machines.

**The Problem:** Claude Code stores sessions by working directory path:
- macOS: `/Users/name/project` → session `-Users-name-project-`
- Linux: `/home/name/project` → session `-home-name-project-`
- **Result:** Different machines = different session folders = lost conversation history

**The Solution:** Use `/workspace/project` everywhere:
```bash
# ✅ Portable (use this)
cd /workspace/my-project
claude

# Session stored as: ~/.claude/projects/-workspace-my-project-/
# Same on ALL machines! Resume conversations anywhere.

# ❌ Non-portable (avoid)
cd ~/workspace/my-project  # Different path per OS
```

**Auto-redirect:** The `claude` wrapper detects `~/workspace/*` and automatically switches to `/workspace/*`.

**Why it matters:** Work on Mac, continue on Linux, **same conversation, full history**. No other dotfiles system does this.

[Full workspace documentation →](docs/README-FULL.md#canonical-workspace-workspace)

</details>

<details>
<summary><h3>Claude Code Backends</h3></summary>

Multiple backend support for different use cases:

| Command | Backend | Use Case |
|---------|---------|----------|
| `claude` | Default | Uses Max subscription or direct API |
| `claude-max` / `cm` | Anthropic Max | Personal/consumer subscription |
| `claude-bedrock` / `cb` | AWS Bedrock | Enterprise, cost-controlled, SSO |

**Setup for AWS Bedrock:**
```bash
cp ~/workspace/dotfiles/claude/claude.local.example ~/.claude.local
vim ~/.claude.local  # Add AWS SSO profile
```

[Full Claude Code guide →](docs/claude-code.md)

</details>

<details>
<summary><h3>Vault System (Multi-Backend)</h3></summary>

Secrets are stored in your preferred vault and restored on new machines:

```bash
# Set your preferred backend (add to ~/.zshrc)
export DOTFILES_VAULT_BACKEND=bitwarden  # default
export DOTFILES_VAULT_BACKEND=1password  # 1Password CLI v2
export DOTFILES_VAULT_BACKEND=pass       # Standard Unix password manager

# First time: Push secrets to vault
dotfiles vault sync --all

# New machine: Restore secrets
dotfiles vault restore

# Validate vault item schema
dotfiles vault validate

# Check for drift (local vs vault)
dotfiles drift
```

**Supported backends:**
| Backend | CLI Tool | Description |
|---------|----------|-------------|
| Bitwarden | `bw` | Default, full-featured, cloud-synced |
| 1Password | `op` | v2 CLI with biometric auth |
| pass | `pass` | GPG-based, git-synced, local-first |

**Supported secrets:**
- SSH keys (multiple identities)
- SSH config (host mappings)
- AWS config & credentials
- Git configuration (.gitconfig)
- Environment variables (.local/env.secrets)

</details>

<details>
<summary><h3>Template System (Machine-Specific Configs)</h3></summary>

Generate configuration files tailored to each machine using templates:

```bash
# First-time setup
dotfiles template init       # Interactive setup wizard

# View detected values
dotfiles template vars       # List all variables

# Generate configs
dotfiles template render     # Render all templates
dotfiles template link       # Symlink to destinations

# Maintenance
dotfiles template check      # Validate syntax
dotfiles template diff       # Show what would change
```

**How it works:**
1. Templates in `templates/configs/*.tmpl` use `{{ variable }}` syntax
2. Variables are auto-detected (hostname, OS, user) or user-configured
3. Rendered files go to `generated/` and are symlinked to destinations

**Supported templates:**
- `.gitconfig` - Git identity, signing, editor, aliases
- `99-local.zsh` - Machine-specific shell config
- `ssh-config` - SSH host configurations
- `claude.local` - Claude Code backend settings

**Variable precedence:**
1. Environment variables (`DOTFILES_TMPL_*`)
2. Local overrides (`templates/_variables.local.sh`)
3. Machine-type defaults (work/personal)
4. Auto-detected values (hostname, OS, etc.)

See [Template Guide](docs/templates.md) for full documentation.

</details>

<details>
<summary><h3>The `dotfiles` Command</h3></summary>

A unified command for managing your dotfiles:

```bash
# Status & Health
dotfiles status          # Quick visual dashboard (color-coded)
dotfiles doctor          # Comprehensive health check
dotfiles doctor --fix    # Auto-repair permission issues
dotfiles drift           # Compare local files vs vault
dotfiles diff            # Preview changes before sync/restore

# Backup & Restore
dotfiles backup          # Create timestamped backup
dotfiles backup --list   # List available backups
dotfiles backup restore  # Restore from backup

# Vault Operations
dotfiles vault restore   # Restore secrets (checks for local drift first)
dotfiles vault restore --force  # Skip drift check, overwrite local
dotfiles vault sync      # Sync local files to vault
dotfiles vault list      # List vault items
dotfiles vault check     # Validate vault items exist

# Setup & Maintenance
dotfiles init            # First-time setup wizard
dotfiles upgrade         # Pull latest, run bootstrap, verify
dotfiles uninstall       # Clean removal (with --dry-run option)
dotfiles lint            # Validate shell config syntax
dotfiles lint --fix      # Auto-fix permissions
dotfiles packages        # Check Brewfile package status
dotfiles packages --install  # Install missing packages

# Templates (machine-specific configs)
dotfiles template init   # Setup template variables
dotfiles template vars   # List all variables
dotfiles template render # Generate configs from templates
dotfiles template link   # Symlink generated files
dotfiles template diff   # Show what would change

# Navigation
dotfiles cd              # Navigate to dotfiles directory
dotfiles edit            # Open dotfiles in $EDITOR
dotfiles help            # Show all commands
```

</details>

<details>
<summary><h3>Health Checks</h3></summary>

Validate your environment anytime:

```bash
dotfiles doctor             # Comprehensive check
dotfiles doctor --fix       # Auto-repair permissions
dotfiles drift              # Compare local vs vault
```

**Checks performed:**
- Symlinks (zshrc, p10k, claude, ghostty)
- Required commands (brew, zsh, git, bw, aws)
- SSH keys and permissions (600 private, 644 public)
- AWS configuration and credentials
- Vault login status
- Drift detection (local vs vault)

</details>

---

## Common Tasks

### Update Dotfiles

```bash
dotfiles-upgrade  # Pull latest, run bootstrap, check health
```

### Sync Secrets

```bash
# Update SSH config locally, then sync to vault
vim ~/.ssh/config
dotfiles vault sync SSH-Config

# View what would be synced (dry run)
dotfiles vault sync --dry-run --all
```

### Add New SSH Key

```bash
# 1. Generate key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_newkey

# 2. Add to vault/_common.sh SSH_KEYS array
# 3. Sync to vault
dotfiles vault sync SSH-GitHub-NewKey

# 4. Update SSH config
vim ~/.ssh/config
dotfiles vault sync SSH-Config
```

See [Maintenance Checklists](docs/README-FULL.md#maintenance-checklists) for more.

---

## Project Structure

<details>
<summary><b>Directory Layout</b></summary>

```
dotfiles/
├── Brewfile                   # Package definitions
├── Dockerfile                 # Docker bootstrap example
├── install.sh                 # One-line installer entry point
│
├── bootstrap/                 # Platform bootstrap scripts
│   ├── _common.sh            # Shared bootstrap functions
│   ├── bootstrap-mac.sh      # macOS setup
│   ├── bootstrap-linux.sh    # Linux/WSL2/Lima setup
│   └── bootstrap-dotfiles.sh # Symlink creation
│
├── bin/                       # CLI commands (use: dotfiles <command>)
│   ├── dotfiles-doctor       # Health validation
│   ├── dotfiles-drift        # Drift detection
│   ├── dotfiles-backup       # Backup/restore
│   ├── dotfiles-diff         # Preview changes
│   ├── dotfiles-init         # Setup wizard
│   ├── dotfiles-metrics      # Metrics visualization
│   └── dotfiles-uninstall    # Clean removal
│
├── vault/                     # Multi-backend secret management
│   ├── _common.sh            # Shared config & validation
│   ├── backends/             # Vault backend implementations
│   │   ├── bitwarden.sh
│   │   ├── 1password.sh
│   │   └── pass.sh
│   ├── bootstrap-vault.sh    # Orchestrator
│   ├── restore-*.sh          # Restore SSH, AWS, Git, env
│   └── sync-to-vault.sh      # Sync local → vault
│
├── zsh/                       # Shell configuration
│   ├── zshrc                 # Main loader
│   ├── p10k.zsh             # Powerlevel10k theme
│   ├── completions/          # Tab completions
│   └── zsh.d/               # Modular config (00-99)
│       ├── 00-init.zsh      # Initialization
│       ├── 40-aliases.zsh   # Aliases & dotfiles command
│       ├── 70-claude.zsh    # Claude Code wrapper
│       └── 99-local.zsh     # Machine-specific (gitignored)
│
├── lib/                       # Shared libraries
│   ├── _logging.sh           # Colors and logging
│   ├── _templates.sh         # Template engine
│   └── _vault.sh             # Vault abstraction layer
│
├── templates/                 # Machine-specific templates
│   ├── _variables.sh         # Default variables
│   ├── _variables.local.sh   # Local overrides (gitignored)
│   └── configs/*.tmpl        # Template files
│
├── generated/                 # Rendered templates (gitignored)
│
├── claude/                    # Claude Code integration
│   ├── settings.json         # Permissions & preferences
│   ├── hooks/                # Defensive git hooks
│   └── commands/             # Custom slash commands
│
├── test/                      # Test suites (bats-core)
│   ├── *.bats               # Unit & integration tests
│   ├── fixtures/            # Test data (vault items, etc.)
│   └── mocks/               # Mock CLI tools
│
├── macos/                     # macOS system preferences
├── ghostty/                   # Ghostty terminal config
├── zellij/                    # Zellij multiplexer config
├── lima/                      # Lima VM configuration
│
└── docs/                      # Documentation (Docsify)
    ├── cli-reference.md      # All commands & flags
    ├── README-FULL.md        # Complete guide
    └── *.md                  # Topic guides
```

</details>

---

## Development & Testing

### Docker Bootstrap

Test the bootstrap process in a clean Ubuntu container:

```bash
# Build the Docker image
docker build -t dotfiles-dev .

# Run interactive shell
docker run -it --rm dotfiles-dev

# Run with vault restore (Bitwarden example)
export BW_SESSION="$(bw unlock --raw)"
docker run -it --rm -e BW_SESSION="$BW_SESSION" dotfiles-dev

# Mount local dotfiles for testing changes
docker run -it --rm -v $PWD:/home/developer/workspace/dotfiles dotfiles-dev
```

The Dockerfile demonstrates:
- Clean environment setup from Ubuntu 24.04
- Full bootstrap process (Homebrew, packages, dotfiles)
- CI/CD integration patterns
- Reproducible development containers

### Testing (80+ tests)

Run tests with bats-core:

```bash
# Install bats-core (if not already installed)
./test/setup_bats.sh

# Run all tests
./test/run_tests.sh

# Or run specific suites
./test/run_tests.sh unit         # Unit tests only
./test/run_tests.sh integration  # Integration tests only
./test/run_tests.sh error        # Error scenario tests only
./test/run_tests.sh all          # All tests (default)
```

**Test suites:**

| Suite | Tests | Description |
|-------|-------|-------------|
| Unit | 39 | vault/_common.sh functions, CLI commands |
| Integration | 21 | Mock Bitwarden, backup/restore cycles |
| Error Scenarios | 20+ | Permission errors, missing files, edge cases |

**CI/CD validates on every push:**
- ShellCheck for bash scripts
- ZSH syntax validation
- All test suites (unit, integration, error)
- Code coverage via kcov + Codecov
- Cross-platform compatibility (macOS + Linux)

### Modular Shell Configuration

The zsh configuration is modular for easier maintenance and customization:

```bash
zsh/zsh.d/
├── 00-init.zsh          # Powerlevel10k, OS detection
├── 10-plugins.zsh       # Plugin loading
├── 20-env.zsh           # Environment variables
├── 30-tools.zsh         # CLI tool configurations (eza, fzf, bat)
├── 40-aliases.zsh       # Aliases
├── 50-functions.zsh     # Shell functions
├── 60-aws.zsh           # AWS helpers
├── 70-claude.zsh        # Claude Code wrapper
├── 80-git.zsh           # Git shortcuts
├── 90-integrations.zsh  # Tool integrations
└── 99-local.zsh         # Machine-specific overrides (gitignored)
```

To customize:
1. Copy `zsh/zsh.d/99-local.zsh.example` to `zsh/zsh.d/99-local.zsh`
2. Add machine-specific aliases, environment variables, or PATH entries
3. This file is gitignored and won't be overwritten on updates

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| macOS (Apple Silicon) | Fully tested | Primary development environment |
| macOS (Intel) | Fully tested | Auto-detects architecture |
| Lima (Ubuntu 24.04) | Fully tested | Recommended Linux VM for macOS |
| WSL2 (Windows) | Auto-detected | Uses Linux bootstrap |
| Windows (Git Bash/MSYS2) | Native support | Uses Windows bootstrap |
| Ubuntu/Debian | Compatible | Tested on Ubuntu 24.04 |
| Arch/Fedora/BSD | Experimental | 15-30 min adaptation needed |

---

## Documentation

- **Quick overview:** this README
- **[CLI Reference](docs/cli-reference.md)** - All commands, flags, and environment variables
- **[Full Documentation](docs/README-FULL.md)** - Complete guide (1,900+ lines)
- **[Template Guide](docs/templates.md)** - Machine-specific configuration templates
- **[Claude Code Guide](docs/claude-code.md)** - Multi-backend setup and session portability
- **[Architecture](docs/architecture.md)** - System diagrams and component overview
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions
- **[Vault README](docs/vault-README.md)** - Multi-vault backend details
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contributor guide
- **[SECURITY.md](SECURITY.md)** - Security policy
- **[CHANGELOG.md](CHANGELOG.md)** - Version history

---

## Troubleshooting

<details>
<summary><b>Quick Fixes & Common Issues</b></summary>

### Quick Fixes

```bash
# Run diagnostics
dotfiles doctor          # Check all systems
dotfiles doctor --fix    # Auto-repair issues
dotfiles status          # Visual dashboard
```

### Common Issues

**SSH keys not working:**
```bash
dotfiles doctor --fix    # Fix permissions
ssh-add -l               # Verify keys loaded
ssh -T git@github.com    # Test connection
```

**Vault session expired:**
```bash
# Bitwarden
export BW_SESSION="$(bw unlock --raw)"

# 1Password - re-sign in
op signin
```

**Tab completion not working:**
```bash
rm -f ~/.zcompdump*      # Clear completion cache
exec zsh                 # Reload shell
```

See **[Troubleshooting Guide](docs/troubleshooting.md)** for complete solutions.

</details>

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development workflow
- Testing requirements
- Commit conventions
- Pull request process

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community guidelines.

---

## Security

- All secrets stored in vault (encrypted)
- Session caching with 600 permissions
- Pre-commit hooks prevent secret leaks
- Regular security audits (see [SECURITY.md](SECURITY.md))

**Report vulnerabilities:** Use [GitHub Security Advisories](https://github.com/blackwell-systems/dotfiles/security/advisories)

---

## Acknowledgments

<details>
<summary><b>Credits & Inspiration</b></summary>

**AI & Development:**
- [Anthropic](https://anthropic.com/) - Claude AI and Claude Code
- [Claude Code](https://claude.ai/code) - AI-assisted development

**Tools:**
- [Bitwarden](https://bitwarden.com/) - Secret management
- [Homebrew](https://brew.sh/) - Package management
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k) - Zsh theme
- [Modern CLI Tools](https://github.com/ibraheemdev/modern-unix) - eza, fzf, ripgrep, etc.

**Inspiration:**
- [holman/dotfiles](https://github.com/holman/dotfiles) - Topic-based organization
- [thoughtbot/dotfiles](https://github.com/thoughtbot/dotfiles) - rcm tool
- [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles) - macOS defaults

</details>

---

## Trademarks

Blackwell Systems™ and the Blackwell Systems logo are trademarks of Dayna Blackwell.
You may use the name "Blackwell Systems" to refer to this project, but you may not
use the name or logo in a way that suggests endorsement or official affiliation
without prior written permission. See [BRAND.md](BRAND.md) for usage guidelines.

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

**Questions?** Open an [issue](https://github.com/blackwell-systems/dotfiles/issues) or check the [full documentation](docs/README-FULL.md).
