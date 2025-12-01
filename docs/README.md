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
| [Template System](templates.md) | Machine-specific configuration |
| [Vault System](vault-README.md) | Multi-backend secret management |
| [Claude Code Integration](claude-code.md) | Portable sessions & git safety hooks |
| [Architecture](architecture.md) | System diagrams |
| [Troubleshooting](troubleshooting.md) | Common issues & solutions |
| [macOS Settings](macos-settings.md) | 137+ system preferences |

For detailed feature comparisons vs chezmoi, thoughtbot, holman, and other popular dotfiles, see the [main README on GitHub](https://github.com/blackwell-systems/dotfiles#how-this-compares).

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

## Core Features

- **Multi-vault secret management** – SSH keys, AWS credentials, Git config synced with Bitwarden, 1Password, or pass
- **Claude Code integration** – Portable sessions across machines via `/workspace` symlink
- **Self-healing configuration** – Health checker with auto-fix, drift detection
- **Machine-specific templates** – Generate configs tailored to each machine
- **Modern CLI stack** – eza, fzf, ripgrep, zoxide, bat—configured and ready
- **Cross-platform** – macOS, Linux, Windows, WSL2, Docker

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
dotfiles vault restore   # Restore secrets
dotfiles vault sync      # Sync local to vault

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
- **[Template System](templates.md)** – Configure per-machine settings
- **[Claude Code Integration](claude-code.md)** – Portable sessions & safety hooks
- **[Troubleshooting](troubleshooting.md)** – Solutions to common issues

---

## Contributing

- [Contributing Guide](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)

---

**Questions?** [Open an issue](https://github.com/blackwell-systems/dotfiles/issues) or check the [full documentation](README-FULL.md).
