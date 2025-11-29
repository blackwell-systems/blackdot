# Dotfiles & Vault Setup

[![Test Status](https://github.com/blackwell-systems/dotfiles/workflows/Test%20Dotfiles/badge.svg)](https://github.com/blackwell-systems/dotfiles/actions)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Passing-brightgreen)](https://github.com/blackwell-systems/dotfiles/actions)
[![Tests](https://img.shields.io/badge/Tests-80%2B-brightgreen)](test/)
[![codecov](https://codecov.io/gh/blackwell-systems/dotfiles/branch/main/graph/badge.svg)](https://codecov.io/gh/blackwell-systems/dotfiles)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20Linux%20%7C%20Windows%20%7C%20WSL2%20%7C%20Docker-blue)
![Shell](https://img.shields.io/badge/Shell-Zsh-blueviolet)
![Secrets](https://img.shields.io/badge/Secrets-Bitwarden-ff4081)
![Claude Portability](https://img.shields.io/badge/Claude_Portability-Enabled-8A2BE2)

> Enterprise-grade, vault-backed dotfiles for multi-machine development. Bitwarden provides the source of truth for secrets, a canonical `/workspace` path keeps Claude Code sessions portable across macOS, Linux, Windows, and WSL2, and health checks guard against drift, broken symlinks, and missing vault state.

[![Version](https://img.shields.io/badge/Version-1.7.0-blue)](CHANGELOG.md)

**Version:** 1.7.0 | [Changelog](CHANGELOG.md) | [Full Documentation](docs/README-FULL.md)

---

## Features

### Core (works everywhere)
- **Bitwarden vault integration** – SSH keys, AWS credentials, Git config, and environment secrets restored from Bitwarden. One unlock, full environment. Schema validation ensures item integrity.
- **Machine-specific templates** – Generate configs tailored to each machine (work vs personal, macOS vs Linux). Git identity, SSH hosts, shell settings all adapt automatically.
- **Automated health checks** – Validate symlinks, permissions, required tools, and vault sync. Optional auto-fix and drift detection.
- **Modern CLI stack** – eza, fzf, ripgrep, zoxide, bat, and other modern Unix replacements, configured and ready.
- **Idempotent design** – Run bootstrap repeatedly. Scripts converge to known-good state without breaking existing setup.
- **Fast setup** – Clone to working shell in under five minutes.
- **Comprehensive testing** – 80+ tests (unit, integration, error scenarios) ensure reliability across platforms.

### Advanced (opt-in)
- **Cross-platform portability** – Same dotfiles on macOS, Linux, Windows, WSL2, or Docker with ~90% shared code.
- **Portable Claude Code sessions** – `/workspace` symlink ensures Claude sessions sync across machines. Start on macOS, continue on Linux, keep your conversation.
- **Metrics and observability** – Track dotfiles health over time. Surface drift, failures, and missing vault items.

---

## How This Compares

### Quick Comparison

| Capability           | This Repo                                      | Typical Dotfiles                 |
|----------------------|-----------------------------------------------|----------------------------------|
| **Secrets management** | Bitwarden vault with restore/sync             | Manual copy between machines     |
| **Health validation**  | 573-line checker with `--fix`                 | None                             |
| **Drift detection**    | Compare local vs vault state                  | None                             |
| **Schema validation**  | Validates SSH keys & config structure         | None                             |
| **Unit tests**         | 80+ bats-core tests                           | Rare                             |
| **Docker support**     | Full Dockerfile for containerized bootstrap   | Rare                             |
| **Modular shell config** | 10 modules in `zsh.d/`                      | Single monolithic file           |
| **Optional components** | `SKIP_*` env flags                           | All-or-nothing                   |
| **Cross-platform**     | macOS, Linux, Windows, WSL2, Docker           | Usually single-platform          |

### Detailed Comparison vs Popular Dotfiles

<details>
<summary><b>📊 Feature Matrix: This Repo vs thoughtbot, holman, mathiasbynens, YADR</b></summary>

| Feature | This Repo | thoughtbot | holman | mathiasbynens | YADR |
|---------|-----------|------------|--------|---------------|------|
| **Secrets Management** | ✅ Bitwarden vault | ❌ Manual | ❌ Manual | ❌ Manual | ❌ Manual |
| **Bidirectional Sync** | ✅ Local ↔ Vault | ❌ | ❌ | ❌ | ❌ |
| **Cross-Platform** | ✅ macOS, Linux, Windows, WSL2, Docker | ⚠️ Limited | ⚠️ macOS only | ⚠️ macOS only | ⚠️ Limited |
| **Claude Code Sessions** | ✅ Portable via `/workspace` | ❌ | ❌ | ❌ | ❌ |
| **Health Checks** | ✅ 573 lines + auto-fix | ❌ | ❌ | ❌ | ❌ |
| **Drift Detection** | ✅ Local vs Vault | ❌ | ❌ | ❌ | ❌ |
| **Schema Validation** | ✅ SSH keys, configs | ❌ | ❌ | ❌ | ❌ |
| **Unit Tests** | ✅ 80+ bats tests | ❌ | ❌ | ❌ | ❌ |
| **CI/CD Integration** | ✅ GitHub Actions | ⚠️ Basic | ❌ | ❌ | ❌ |
| **Modular Shell Config** | ✅ 10 modules | ❌ Monolithic | ❌ Monolithic | ❌ Monolithic | ⚠️ Partial |
| **Optional Components** | ✅ SKIP_* flags | ❌ | ❌ | ❌ | ❌ |
| **Docker Bootstrap** | ✅ Full Dockerfile | ❌ | ❌ | ❌ | ❌ |
| **One-Line Installer** | ✅ Interactive mode | ⚠️ Basic | ❌ | ❌ | ✅ |
| **Documentation Site** | ✅ Docsify (searchable) | ⚠️ README only | ⚠️ README only | ⚠️ README only | ⚠️ Wiki |
| **Vault Item Templates** | ✅ With validation | ❌ | ❌ | ❌ | ❌ |
| **Team Onboarding** | ✅ <5 min setup | ⚠️ ~30 min | ⚠️ ~30 min | ⚠️ ~30 min | ⚠️ ~45 min |
| **macOS System Prefs** | ✅ 137 settings | ❌ | ✅ Extensive | ✅ Extensive | ❌ |
| **Active Maintenance** | ✅ 2024 | ⚠️ Sporadic | ❌ Archived | ⚠️ Sporadic | ❌ Minimal |

**Legend:** ✅ Full Support | ⚠️ Partial/Limited | ❌ Not Available

#### Key Differentiators

**vs thoughtbot/dotfiles:**
- ✨ **Secrets Management**: Bitwarden vault vs manual copying
- ✨ **Cross-Platform**: Full Docker/WSL2/Lima support vs macOS/Linux only
- ✨ **Health Monitoring**: Comprehensive checks vs none
- ✨ **Testing**: Unit tests + CI vs basic install script

**vs holman/dotfiles:**
- ✨ **Active Development**: Regular updates vs archived (2018)
- ✨ **Enterprise Ready**: Vault integration, team onboarding vs personal use
- ✨ **Cross-Platform**: Multi-OS support vs macOS only
- ✨ **Portability**: Claude Code sessions, /workspace symlink vs static paths

**vs mathiasbynens/dotfiles:**
- ✨ **Secrets Management**: Vault system vs exposed in git
- ✨ **Health Validation**: Auto-fix capability vs none
- ✨ **Cross-Platform**: Full Linux/WSL2 support vs macOS focus
- ✨ **Testing**: Automated tests vs manual verification
- 🤝 **Similar**: Both have extensive macOS system preferences

**vs YADR (Yet Another Dotfile Repo):**
- ✨ **Lighter Weight**: Focused tooling vs kitchen sink approach
- ✨ **Secrets Safety**: Vault-backed vs all in git
- ✨ **Modern Stack**: eza, fzf, zoxide vs older tools
- ✨ **Maintenance**: Active vs minimal updates
- 🤝 **Similar**: Both aim for comprehensive setup

#### What Makes This Unique

1. **Only dotfiles with Bitwarden bidirectional sync** - Create, restore, validate vault items
2. **Only dotfiles with Claude Code session portability** - `/workspace` symlink + auto-redirect
3. **Only dotfiles with comprehensive health checks** - 573-line validator with auto-fix
4. **Only dotfiles with drift detection** - Compare local vs vault state
5. **Only dotfiles with schema validation** - Ensures SSH keys/configs are valid before restore
6. **Only dotfiles with Docker bootstrap testing** - Reproducible CI/CD environments

</details>

### What you get

- **Vault-backed secrets**: SSH keys, AWS credentials, and configs live in Bitwarden—not scattered across machines or committed to git
- **Self-healing dotfiles**: Health checks catch permission drift, broken symlinks, and missing vault items. Auto-fix with `--fix`
- **Observable state**: Track health metrics over time, detect when things break
- **Tested**: CI runs 80+ tests (unit, integration, error scenarios) on every push

### What's optional

Everything works on a single machine. Cross-platform sync, Claude session portability, and even Bitwarden itself are opt-in:

```bash
# Minimal install (no vault, no /workspace symlink, no Claude setup)
SKIP_WORKSPACE_SYMLINK=true SKIP_CLAUDE_SETUP=true ./bootstrap/bootstrap-linux.sh

# Then manually configure ~/.ssh, ~/.aws, ~/.gitconfig
```

> 💡 **Don't use Bitwarden?** No problem!
>
> The vault system is completely optional. Run with `--minimal` flag:
> ```bash
> curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash -s -- --minimal
> ```
> Then manually configure `~/.ssh`, `~/.aws`, `~/.gitconfig`. All shell config, aliases, and tools still work!

Inspired by: holman/dotfiles, thoughtbot/dotfiles, mathiasbynens/dotfiles

---

## Prerequisites

**Required:**
- A supported environment: macOS, Linux, WSL2, or Lima
- Internet access (for installing packages)

**Auto-installed (if missing):**
- Git (via Xcode tools on macOS or apt on Linux)
- Homebrew/Linuxbrew (bootstrap will install)
- Modern CLI tools (eza, fzf, ripgrep, etc. via Brewfile)

**Optional (for vault features only):**
- **Bitwarden CLI + account** - For automated secret sync
  - Skip with `--minimal` flag (or just don't run `dotfiles vault` commands)
  - Without vault: manually configure `~/.ssh`, `~/.aws`, `~/.gitconfig`

**Optional (for Claude Code portable sessions):**
- **Claude Code installed** - For cross-machine session sync
  - Skip with `SKIP_CLAUDE_SETUP=true`

To clone via SSH (recommended), you’ll also want an SSH key configured with GitHub. If you don’t have Git yet, you can either:
- install it the way you normally would on your platform, or  
- download this repository as a ZIP from GitHub, extract it, and run `bootstrap-mac.sh` / `bootstrap-linux.sh` – the scripts will install Git and the Bitwarden CLI for you.

---

## One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash
```

Or with options:

```bash
# Interactive mode - prompts for configuration
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash -s -- --interactive

# Minimal mode - skip optional features
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash -s -- --minimal
```

---

## Quick Start (Manual)

```bash
# 1. Clone
git clone git@github.com:blackwell-systems/dotfiles.git ~/workspace/dotfiles
cd ~/workspace/dotfiles

# 2. Bootstrap (picks your platform automatically)
./bootstrap/bootstrap-mac.sh      # macOS
./bootstrap/bootstrap-linux.sh    # Linux / WSL2 / Lima / Docker

# 3. Restore secrets from Bitwarden
bw login
export BW_SESSION="$(bw unlock --raw)"
./vault/bootstrap-vault.sh

# 4. Verify
dotfiles doctor
```

**That's it.** Shell configured, secrets restored, health validated.

<details>
<summary><b>Don't use Bitwarden?</b></summary>

The vault system is completely optional. Two options:

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
- `DOTFILES_OFFLINE=1` – Skip all Bitwarden vault operations (for air-gapped or offline environments)

All features are opt-in by default and can be disabled without breaking the rest of the setup.
</details>

---

## Use Cases

- **Single Linux machine** – Vault-backed secrets, health checks, modern CLI. No cross-platform complexity.

- **macOS daily driver** – Full experience including Ghostty terminal config and macOS system preferences.

- **Docker/CI environments** – Bootstrap in containers for reproducible builds. Vault restore from CI secrets.

- **Air-gapped/Offline** – Use `DOTFILES_OFFLINE=1` when Bitwarden isn't available. Vault operations skip gracefully.

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
- AWS CLI, Bitwarden CLI

### Configurations
- SSH keys and config (from Bitwarden)
- AWS credentials and config (from Bitwarden)
- Git configuration (from Bitwarden)
- Environment secrets (from Bitwarden)
- Claude Code settings (shared workspace)

See [Brewfile](Brewfile) for complete package list.

---

## Key Concepts

### Bitwarden Vault System

All secrets are stored in Bitwarden and restored on new machines:

```bash
# First time: Push secrets to Bitwarden
dotfiles vault sync --all

# New machine: Restore secrets
dotfiles vault restore

# Validate vault item schema
dotfiles vault validate

# Check for drift (local vs Bitwarden)
dotfiles drift
```

**Supported secrets:**
- SSH keys (multiple identities)
- SSH config (host mappings)
- AWS config & credentials
- Git configuration (.gitconfig)
- Environment variables (.local/env.secrets)

### Template System (Machine-Specific Configs)

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

See [Template Guide](templates.md) for full documentation.

### Tips

#### Claude Code Integration (optional)

This repo includes a full Claude Code integration layer supporting multiple backends:

```
┌─────────────────────────────────────────────────────────┐
│                    User Commands                        │
│   claude │ claude-max │ claude-bedrock │ claude-status │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│              Session Portability Layer                  │
│   ~/workspace/* → /workspace/* path normalization       │
│   Enables cross-machine session continuity              │
└────────────────────────┬────────────────────────────────┘
                         │
          ┌──────────────┴──────────────┐
          ▼                             ▼
┌─────────────────────┐     ┌─────────────────────┐
│    Claude Max       │     │   AWS Bedrock       │
│  (Direct Anthropic) │     │ (Enterprise/SSO)    │
│                     │     │                     │
│  - Consumer plan    │     │  - Cost controls    │
│  - Simple auth      │     │  - SSO integration  │
│  - No setup needed  │     │  - Usage tracking   │
└─────────────────────┘     └─────────────────────┘
```

| Command | Backend | Use Case |
|---------|---------|----------|
| `claude` | Default | Uses Max subscription or direct API |
| `claude-max` / `cm` | Anthropic Max | Personal/consumer subscription |
| `claude-bedrock` / `cb` | AWS Bedrock | Enterprise, cost-controlled, SSO |
| `claude-status` | — | Show current configuration |

**Setup for AWS Bedrock:**

```bash
# Copy the example config
cp ~/workspace/dotfiles/claude/claude.local.example ~/.claude.local

# Edit with your AWS SSO profile
vim ~/.claude.local
```

Example `~/.claude.local`:
```bash
export CLAUDE_BEDROCK_PROFILE="your-sso-profile"
export CLAUDE_BEDROCK_REGION="us-west-2"
```

**Portable Sessions (multi-machine):**

If you use Claude Code across multiple machines, the `/workspace` symlink keeps sessions in sync:

```bash
cd /workspace/my-project  # Same path on all machines
claude                     # Same session everywhere
```

The bootstrap creates `/workspace → ~/workspace` automatically. If you're on a single machine, this works transparently—no action needed.

**Why this matters:** Claude Code stores sessions by working directory path. Different machines have different home directories (`/Users/name` vs `/home/name`), creating different session IDs. The `/workspace` symlink normalizes this.

**Auto-redirect:** The `claude` wrapper detects `~/workspace/*` paths and automatically switches to `/workspace/*`.

### The `dotfiles` Command

A unified command for managing your dotfiles:

```bash
# Status & Health
dotfiles status          # Quick visual dashboard (color-coded)
dotfiles doctor          # Comprehensive health check
dotfiles doctor --fix    # Auto-repair permission issues
dotfiles drift           # Compare local files vs Bitwarden vault
dotfiles diff            # Preview changes before sync/restore

# Backup & Restore
dotfiles backup          # Create timestamped backup
dotfiles backup --list   # List available backups
dotfiles backup restore  # Restore from backup

# Vault Operations
dotfiles vault restore   # Restore secrets (checks for local drift first)
dotfiles vault restore --force  # Skip drift check, overwrite local
dotfiles vault sync      # Sync local files to Bitwarden
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

### Health Checks

Validate your environment anytime:

```bash
dotfiles doctor             # Comprehensive check
dotfiles doctor --fix       # Auto-repair permissions
dotfiles drift              # Compare local vs Bitwarden vault
```

**Checks performed:**
- Symlinks (zshrc, p10k, claude, ghostty)
- Required commands (brew, zsh, git, bw, aws)
- SSH keys and permissions (600 private, 644 public)
- AWS configuration and credentials
- Bitwarden login status
- Drift detection (local vs vault)

---

## Common Tasks

### Update Dotfiles

```bash
dotfiles-upgrade  # Pull latest, run bootstrap, check health
```

### Sync Secrets

```bash
# Update SSH config locally, then sync to Bitwarden
vim ~/.ssh/config
./vault/sync-to-bitwarden.sh SSH-Config

# View what would be synced (dry run)
./vault/sync-to-bitwarden.sh --dry-run --all
```

### Add New SSH Key

```bash
# 1. Generate key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_newkey

# 2. Add to vault/_common.sh SSH_KEYS array
# 3. Sync to Bitwarden
./vault/sync-to-bitwarden.sh SSH-GitHub-NewKey

# 4. Update SSH config
vim ~/.ssh/config
./vault/sync-to-bitwarden.sh SSH-Config
```

See [Maintenance Checklists](docs/README-FULL.md#maintenance-checklists) for more.

---

## Project Structure

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
├── vault/                     # Bitwarden secret management
│   ├── _common.sh            # Shared config & validation functions
│   ├── bootstrap-vault.sh    # Orchestrator
│   ├── restore-*.sh          # Restore SSH, AWS, Git, env
│   ├── sync-to-bitwarden.sh  # Sync local → Bitwarden
│   ├── validate-schema.sh    # Validate vault item structure
│   └── check-vault-items.sh  # Pre-flight validation
│
├── zsh/                       # Shell configuration
│   ├── zshrc                 # Main loader (sources zsh.d/*.zsh)
│   ├── p10k.zsh             # Powerlevel10k theme
│   ├── completions/          # Tab completions
│   │   └── _dotfiles        # dotfiles command completions
│   └── zsh.d/               # Modular configuration
│       ├── 00-init.zsh      # Initialization & OS detection
│       ├── 10-plugins.zsh   # Plugin loading
│       ├── 20-env.zsh       # Environment variables
│       ├── 30-tools.zsh     # Modern CLI tools
│       ├── 40-aliases.zsh   # Aliases
│       ├── 50-functions.zsh # Shell functions
│       ├── 60-aws.zsh       # AWS helpers
│       ├── 70-claude.zsh    # Claude Code wrapper
│       ├── 80-git.zsh       # Git shortcuts
│       ├── 90-integrations.zsh # Tool integrations
│       └── 99-local.zsh     # Machine-specific overrides (gitignored)
│
├── lib/                       # Shared libraries
│   ├── _logging.sh           # Colors and logging functions
│   └── _templates.sh         # Template engine
│
├── templates/                 # Machine-specific templates
│   ├── _variables.sh         # Default variable definitions
│   ├── _variables.local.sh   # Local overrides (gitignored)
│   └── configs/              # Template files
│       ├── gitconfig.tmpl    # Git configuration
│       ├── 99-local.zsh.tmpl # Shell customization
│       ├── ssh-config.tmpl   # SSH hosts
│       └── claude.local.tmpl # Claude Code settings
│
├── generated/                 # Rendered templates (gitignored)
│
├── test/                      # Test suites (bats-core)
│   ├── vault_common.bats     # Unit tests for vault/_common.sh
│   ├── cli_commands.bats     # Unit tests for CLI commands
│   ├── integration.bats      # Integration tests with mock Bitwarden
│   ├── error_scenarios.bats  # Error handling tests
│   ├── mocks/bw              # Mock Bitwarden CLI
│   └── run_tests.sh          # Test runner
│
├── claude/                    # Claude Code integration
│   ├── settings.json         # Permissions & preferences
│   └── claude.local.example  # Local config template
│
├── macos/                     # macOS-specific
│   └── apply-settings.sh     # System preferences
│
└── docs/                      # Documentation
    ├── README-FULL.md        # Complete documentation
    ├── NOTES.md              # Development notes
    └── BRAND.md              # Brand guidelines
```

---

## Development & Testing

### Docker Bootstrap

Test the bootstrap process in a clean Ubuntu container:

```bash
# Build the Docker image
docker build -t dotfiles-dev .

# Run interactive shell
docker run -it --rm dotfiles-dev

# Run with Bitwarden vault restore
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

### Unit Tests

Run tests with bats-core:

```bash
# Install bats-core (if not already installed)
./test/setup_bats.sh

# Run all tests
./test/run_tests.sh

# Or use bats directly
bats test/vault_common.bats
```

**Current test coverage:**
- ✅ vault/_common.sh data structure helpers (23 tests)
- ✅ Logging functions (info, pass, warn, fail, debug)
- ✅ Item path lookups and validation
- ⏳ Future: vault restoration scripts

Tests run automatically in GitHub Actions on every push.

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
| macOS (Apple Silicon) | ✅ Fully tested | Primary development environment |
| macOS (Intel) | ✅ Fully tested | Auto-detects architecture |
| Lima (Ubuntu 24.04) | ✅ Fully tested | Recommended Linux VM for macOS |
| WSL2 (Windows) | ✅ Auto-detected | Uses Linux bootstrap |
| Ubuntu/Debian | ✅ Compatible | Tested on Ubuntu 24.04 |
| Arch/Fedora/BSD | ⚠️ Experimental | 15-30 min adaptation needed |

---

## Documentation

- **Quick overview:** this README
- **[Full Documentation](README-FULL.md)** - Complete guide (1,900+ lines)
- **[Template Guide](templates.md)** - Machine-specific configuration templates
- **[Architecture](architecture.md)** - System diagrams and component overview
- **[Troubleshooting](troubleshooting.md)** - Common issues and solutions
- **[Vault README](vault-README.md)** - Bitwarden vault details
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contributor guide
- **[SECURITY.md](SECURITY.md)** - Security policy
- **[CHANGELOG.md](CHANGELOG.md)** - Version history

---

## Troubleshooting

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

**Bitwarden session expired:**
```bash
export BW_SESSION="$(bw unlock --raw)"
```

**Tab completion not working:**
```bash
rm -f ~/.zcompdump*      # Clear completion cache
exec zsh                 # Reload shell
```

See **[Troubleshooting Guide](troubleshooting.md)** for complete solutions.

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

- All secrets stored in Bitwarden (encrypted)
- Session caching with 600 permissions
- Pre-commit hooks prevent secret leaks
- Regular security audits (see [SECURITY.md](SECURITY.md))

**Report vulnerabilities:** Use [GitHub Security Advisories](https://github.com/blackwell-systems/dotfiles/security/advisories)

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Acknowledgments

**Tools:**
- [Bitwarden](https://bitwarden.com/) - Secret management
- [Homebrew](https://brew.sh/) - Package management
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k) - Zsh theme
- [Modern CLI Tools](https://github.com/ibraheemdev/modern-unix) - eza, fzf, ripgrep, etc.

**Inspiration:**
- [holman/dotfiles](https://github.com/holman/dotfiles) - Topic-based organization
- [thoughtbot/dotfiles](https://github.com/thoughtbot/dotfiles) - rcm tool
- [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles) - macOS defaults

---

**Questions?** Open an [issue](https://github.com/blackwell-systems/dotfiles/issues) or check the [full documentation](docs/README-FULL.md).
