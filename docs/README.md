# Dotfiles & Vault Setup

[![Test Status](https://github.com/blackwell-systems/dotfiles/workflows/Test%20Dotfiles/badge.svg)](https://github.com/blackwell-systems/dotfiles/actions)
[![Tests](https://img.shields.io/badge/Tests-80%2B-brightgreen)](test/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20Linux%20%7C%20Windows%20%7C%20WSL2%20%7C%20Docker-blue)
![Claude Code](https://img.shields.io/badge/Claude_Code-Native_Integration-8A2BE2)

> **The first dotfiles designed for AI-assisted development.** Multi-vault secrets, portable Claude Code sessions, machine-specific templates, and self-healing configuration.

**Version:** 1.8.0 | [Changelog](https://github.com/blackwell-systems/dotfiles/blob/main/CHANGELOG.md) | [GitHub](https://github.com/blackwell-systems/dotfiles)

---

## Quick Navigation

| Topic | Description |
|-------|-------------|
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

```bash
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash
```

Or with options:

```bash
# Interactive mode - prompts for configuration
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash -s -- --interactive

# Minimal mode - skip optional features (vault, Claude setup)
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

# 2. Bootstrap
./bootstrap/bootstrap-mac.sh      # macOS
./bootstrap/bootstrap-linux.sh    # Linux / WSL2 / Docker

# 3. Restore secrets from vault (optional)
bw login && export BW_SESSION="$(bw unlock --raw)"
./vault/bootstrap-vault.sh

# 4. Verify
dotfiles doctor
```

**Don't use a vault?** Run with `--minimal` or skip step 3. Manually configure `~/.ssh`, `~/.aws`, `~/.gitconfig`.

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
