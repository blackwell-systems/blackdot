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

> **The first dotfiles designed for AI-assisted development.** Multi-vault secrets, portable Claude Code sessions, machine-specific templates, and self-healing configuration.

[Changelog](https://github.com/blackwell-systems/dotfiles/blob/main/CHANGELOG.md) | [GitHub](https://github.com/blackwell-systems/dotfiles)

---

## Quick Navigation

| Topic | Description |
|-------|-------------|
| [CLI Reference](cli-reference.md) | All commands, flags & environment variables |
| [Full Documentation](README-FULL.md) | Complete 1,900+ line guide |
| [Feature Registry](features.md) | Opt-in features, presets & modularity |
| [Template System](templates.md) | Machine-specific configuration |
| [State Management](state-management.md) | Setup wizard state, resume & preferences |
| [Vault System](vault-README.md) | Multi-backend secret management |
| [Claude Code + dotclaude](claude-code.md) | Portable sessions, profile sync, git safety hooks |
| [Docker Containers](docker.md) | Test environments & mock vault |
| [Architecture](architecture.md) | System diagrams |
| [Troubleshooting](troubleshooting.md) | Common issues & solutions |
| [macOS Settings](macos-settings.md) | 137+ system preferences |

For detailed feature comparisons vs chezmoi, thoughtbot, holman, and other popular dotfiles, see the [main README on GitHub](https://github.com/blackwell-systems/dotfiles#how-this-compares).

---

## One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash
```

After installation, run the setup wizard:

```bash
dotfiles setup
```

The wizard guides you through:
- Platform detection and bootstrap
- Vault selection (Bitwarden, 1Password, pass, or skip)
- Secret restoration (SSH keys, AWS credentials, Git config)
- Claude Code integration

**Minimal mode** (shell config only, no secrets integration):

```bash
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash -s -- --minimal
```

Skips: `/workspace` symlink, vault setup, Claude integration. You still get Zsh, CLI tools, and aliases. Run `dotfiles setup` later to enable full features.

**Custom workspace** (use `~/code` instead of `~/workspace`):

```bash
WORKSPACE_TARGET=~/code curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash
```

The setup wizard also prompts for workspace directory (Step 1 of 7).

---

## Core Features

- **Feature registry** – Enable exactly what you need with `dotfiles features`. Use presets or toggle individual features
- **Multi-vault secret management** – SSH keys, AWS credentials, Git config synced with Bitwarden, 1Password, or pass
- **Smart secrets onboarding** – Interactive `dotfiles vault setup` detects local secrets and creates vault items
- **Claude Code + dotclaude** – Portable sessions, profile management, git safety hooks, vault-synced Claude profiles
- **Self-healing configuration** – Health checker with auto-fix, drift detection
- **Machine-specific templates** – Generate configs tailored to each machine
- **Modern CLI stack** – eza, fzf, ripgrep, zoxide, bat—configured and ready
- **Cross-platform** – macOS, Linux, Windows, WSL2, Docker with [4 container sizes](docker.md)

---

## Claude Code + dotclaude Integration

**The first dotfiles project designed for AI-assisted development.** This is what sets us apart from chezmoi, yadm, and every other dotfiles manager.

| Feature | What It Does |
|---------|--------------|
| **Portable sessions** | `/workspace` symlink (target is configurable) lets Claude conversations continue across machines |
| **[dotclaude](https://github.com/blackwell-systems/dotclaude) profiles** | Manage multiple Claude contexts (work, personal, client projects) |
| **Vault-synced profiles** | `dotfiles vault pull` brings your Claude profiles to new machines |
| **Git safety hooks** | PreToolUse hook blocks dangerous commands like `git push --force` |
| **Session validation** | SessionStart hook auto-checks branch sync status |
| **Multi-backend support** | Works with Anthropic Max, AWS Bedrock, Google Vertex AI |

```bash
# Quick setup with dotclaude
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotclaude/main/install.sh | bash
dotclaude create my-project
dotclaude activate my-project
dotfiles vault push Claude-Profiles  # Sync to vault for other machines
```

**Without dotclaude?** No problem—portable sessions and git safety hooks work standalone. `dotfiles doctor` will gently suggest dotclaude if you're a Claude Code user.

See [Claude Code + dotclaude Integration](claude-code.md) for the full guide including architecture diagrams.

---

## Quick Start (Manual)

```bash
# 1. Clone
git clone git@github.com:blackwell-systems/dotfiles.git ~/workspace/dotfiles
cd ~/workspace/dotfiles

# 2. Run platform bootstrap
./bootstrap/bootstrap-mac.sh   # macOS
./bootstrap/bootstrap-linux.sh # Linux/WSL

# 3. Run setup wizard
dotfiles setup
```

**That's it!** The wizard handles:
- Vault selection (Bitwarden, 1Password, pass, or skip)
- Secret restoration (SSH keys, AWS, Git config)
- Claude Code integration
- Progress is saved—resume anytime with `dotfiles setup`

> **💡 Why `/workspace` symlink?**
>
> Bootstrap creates `/workspace → ~/workspace` symlink to enable **Claude Code session portability** across machines.
>
> **The problem:** Claude Code uses absolute paths for session folders. Without the symlink:
> - macOS: `/Users/you/workspace/dotfiles` → session `Users-you-workspace-dotfiles`
> - Linux: `/home/you/workspace/dotfiles` → session `home-you-workspace-dotfiles`
> - Different paths = different sessions = **lost conversation history** when switching machines
>
> **The solution:** `/workspace` is the same absolute path everywhere:
> - All machines: `/workspace/dotfiles` → session `workspace-dotfiles` ✨
> - Same session folder across macOS, Linux, WSL2 = **full history syncs**
>
> **Customization:** Target directory is configurable via `WORKSPACE_TARGET=~/code` or the setup wizard - the `/workspace` symlink name stays the same.
>
> **Skip if:** You only use one machine or don't use Claude Code (`SKIP_WORKSPACE_SYMLINK=true`)
>
> [Learn more](README-FULL.md#canonical-workspace-workspace)

**Don't use a vault?** The wizard lets you skip vault setup entirely.

---

## The `dotfiles` Command

```bash
# Status & Health
dotfiles status          # Visual dashboard
dotfiles doctor          # Health check
dotfiles doctor --fix    # Auto-repair
dotfiles drift           # Compare local vs vault

# Vault Operations
dotfiles sync            # Smart bidirectional sync
dotfiles vault pull      # Restore secrets from vault
dotfiles vault push      # Push local changes to vault
dotfiles vault validate  # Validate vault schema
dotfiles vault setup     # Interactive onboarding

# Templates
dotfiles template init   # Setup wizard
dotfiles template render # Generate configs

# Maintenance
dotfiles upgrade         # Pull latest & bootstrap
dotfiles lint            # Validate syntax
```

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

---

## Project Structure

```
dotfiles/
├── bootstrap/           # Platform setup scripts
├── bin/                 # CLI tools (doctor, drift, backup, etc.)
├── vault/               # Multi-vault integration (Bitwarden, 1Password, pass)
├── zsh/zsh.d/           # Modular shell config (10 modules)
├── templates/           # Machine-specific config templates
├── lib/                 # Shared libraries
├── claude/              # Claude Code integration & hooks
├── test/                # 80+ bats-core tests
└── docs/                # This documentation site
```

See [Full Documentation](README-FULL.md) for complete project structure and details.

---

## Next Steps

- **[Full Documentation](README-FULL.md)** – Complete guide with all details
- **[Claude Code + dotclaude](claude-code.md)** – Portable sessions, profiles & safety hooks
- **[Template System](templates.md)** – Configure per-machine settings
- **[Troubleshooting](troubleshooting.md)** – Solutions to common issues

---

## Contributing

- [Contributing Guide](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)

---

**Questions?** [Open an issue](https://github.com/blackwell-systems/dotfiles/issues) or check the [full documentation](README-FULL.md).
