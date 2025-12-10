# Dotfiles Management Framework

[![Blackwell Systems™](https://raw.githubusercontent.com/blackwell-systems/blackwell-docs-theme/main/badge-trademark.svg)](https://github.com/blackwell-systems)
[![Shell](https://img.shields.io/badge/Shell-Zsh-89e051?logo=zsh&logoColor=white)](https://www.zsh.org/)
[![Claude Code](https://img.shields.io/badge/Built_for-Claude_Code-8A2BE2?logo=anthropic)](https://claude.ai/claude-code)
[![dotclaude](https://img.shields.io/badge/Integrates-dotclaude-8A2BE2?logo=anthropic)](https://github.com/blackwell-systems/dotclaude)
[![Secrets](https://img.shields.io/badge/Secrets-Multi--Vault-ff4081)](https://github.com/blackwell-systems/blackdot#vault--secrets)
[![Version](https://img.shields.io/github/v/release/blackwell-systems/blackdot)](https://github.com/blackwell-systems/blackdot/releases)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows%20%7C%20WSL2%20%7C%20Docker-blue)](https://github.com/blackwell-systems/blackdot)
[![Test Status](https://github.com/blackwell-systems/blackdot/workflows/Test%20Dotfiles/badge.svg)](https://github.com/blackwell-systems/blackdot/actions)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Sponsor](https://img.shields.io/badge/Sponsor-Buy%20Me%20a%20Coffee-yellow?logo=buy-me-a-coffee&logoColor=white)](https://buymeacoffee.com/blackwellsystems)

> A blackdot management framework built on **Feature Registry**, **Configuration Layers**, and **Claude Code Integration**. Multi-vault secrets, portable sessions, machine-specific templates, and self-healing configuration.

[Changelog](https://github.com/blackwell-systems/blackdot/blob/main/CHANGELOG.md) | [GitHub](https://github.com/blackwell-systems/blackdot)

---

## Quick Navigation

| Topic | Description |
|-------|-------------|
| [Architecture](architecture.md) | Framework systems & design |
| [Feature Registry](features.md) | Control plane for all features |
| [Developer Tools](developer-tools.md) | AWS, CDK, Rust, Go, NVM, SDKMAN integrations |
| [Hook System](hooks.md) | Lifecycle hooks for custom behavior |
| [CLI Reference](cli-reference.md) | All commands, flags & environment variables |
| [Full Documentation](README-FULL.md) | Complete 1,900+ line guide |
| [Template System](templates.md) | Machine-specific configuration |
| [State Management](state-management.md) | Setup wizard state, resume & preferences |
| [Vault System](vault-README.md) | Multi-backend secret management |
| [Claude Code + dotclaude](claude-code.md) | Portable sessions, profile sync, git safety hooks |
| [Docker Containers](docker.md) | Test environments & mock vault |
| [Troubleshooting](troubleshooting.md) | Common issues & solutions |
| [macOS Settings](macos-settings.md) | 137+ system preferences |

For detailed feature comparisons vs chezmoi, thoughtbot, holman, and other popular dotfiles, see the [main README on GitHub](https://github.com/blackwell-systems/blackdot#how-this-compares).

---

## One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install.sh | bash
```

After installation, run the setup wizard:

```bash
blackdot setup
```

The wizard guides you through:
- Platform detection and bootstrap
- Vault selection (Bitwarden, 1Password, pass, or skip)
- Secret restoration (SSH keys, AWS credentials, Git config)
- Claude Code integration

**Minimal mode** (shell config only, no secrets integration):

```bash
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install.sh | bash -s -- --minimal
```

Skips: `/workspace` symlink, vault setup, Claude integration. You still get Zsh, CLI tools, and aliases. Run `blackdot setup` later to enable full features.

**Custom workspace** (use `~/code` instead of `~/workspace`):

```bash
WORKSPACE_TARGET=~/code curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install.sh | bash
```

The setup wizard also prompts for workspace directory (Step 1 of 7).

---

## Core Features

**Framework Systems:**
- **Feature Registry** – Modular control plane for all functionality (`blackdot features`)
- **Configuration Layers** – 5-layer priority: env → project → machine → user → defaults
- **Claude Code Integration** – Portable sessions, dotclaude profiles, git safety hooks

**Capabilities:**
- **Multi-vault secret management** – SSH keys, AWS credentials, Git config synced with Bitwarden, 1Password, or pass
- **Age encryption** – Encrypt non-vault secrets for git (template variables, local configs)
- **Deep developer tool integrations** – AWS, CDK, Rust, Go, NVM, SDKMAN with 70+ aliases, helpers, and shell completions
- **Portable Claude sessions** – `/workspace` symlink for consistent paths across machines
- **Machine-specific templates** – Generate configs tailored to each machine
- **Self-healing configuration** – Health checker with auto-fix, drift detection
- **Modern CLI stack** – eza, fzf, ripgrep, zoxide, bat—configured and ready
- **Cross-platform** – macOS, Linux, Windows, WSL2, Docker with [4 container sizes](docker.md)

---

## Claude Code + dotclaude Integration

Integration with Claude Code and [dotclaude](https://github.com/blackwell-systems/dotclaude) profile manager:

| Feature | What It Does |
|---------|--------------|
| **Portable sessions** | `/workspace` symlink (target is configurable) lets Claude conversations continue across machines |
| **[dotclaude](https://github.com/blackwell-systems/dotclaude) profiles** | Manage multiple Claude contexts (work, personal, client projects) |
| **Vault-synced profiles** | `blackdot vault pull` brings your Claude profiles to new machines |
| **Git safety hooks** | PreToolUse hook blocks dangerous commands like `git push --force` |
| **Session validation** | SessionStart hook auto-checks branch sync status |
| **Multi-backend support** | Works with Anthropic Max, AWS Bedrock, Google Vertex AI |

```bash
# Quick setup with dotclaude
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotclaude/main/install.sh | bash
dotclaude create my-project
dotclaude activate my-project
blackdot vault push Claude-Profiles  # Sync to vault for other machines
```

**Without dotclaude?** No problem—portable sessions and git safety hooks work standalone. `blackdot doctor` will gently suggest dotclaude if you're a Claude Code user.

See [Claude Code + dotclaude Integration](claude-code.md) for the full guide including architecture diagrams.

---

## Developer Tool Integrations

Deep integrations with modern developer toolchains—not just aliases, but helpers, completions, and workflow automation.

| Tool Suite | Features | Key Commands |
|------------|----------|--------------|
| **AWS Tools** | Profile switching, SSO login, identity display, role assumption | `awsswitch`, `awslogin`, `awswho`, `awsassume` |
| **CDK Tools** | Deploy, diff, synth, watch with smart defaults | `cdkd`, `cdkdf`, `cdks`, `cdkwatch` |
| **Rust Tools** | Build, test, clippy, fmt, cargo-watch integration | `cb`, `ct`, `ccl`, `cf`, `cw` |
| **Go Tools** | Build, test, coverage, module management | `gob`, `got`, `gotc`, `gomi` |
| **Python Tools** | uv package manager, pytest, auto-venv activation | `uvs`, `uvr`, `uva`, `pt`, `ptx` |
| **NVM** | Lazy-loaded Node.js version manager | Auto-loads on first `node`/`npm` call |
| **SDKMAN** | Lazy-loaded Java/Gradle/Kotlin manager | Auto-loads on first `java`/`gradle` call |

**Shell Completions:** Tab completion for all tool commands—`awsswitch <TAB>`, `blackdot features <TAB>`.

**90+ Aliases:** Opinionated shortcuts that follow consistent naming patterns across toolchains.

**Discoverability:** `zsh-you-should-use` plugin reminds you about aliases you're not using.

```bash
# AWS: Interactive profile switching with fzf
awsswitch              # Fuzzy-select profile, auto-login if expired

# CDK: Deploy with approval confirmation
cdkd                   # cdk deploy with standard flags

# Rust: Watch mode for TDD
cwt                    # cargo watch -x test

# Go: Coverage with browser
gocover                # go test -cover + open HTML report

# Python: Fast package management with uv
uvs && uvr pytest      # Sync deps & run in project env
```

**Feature-gated:** Each tool suite can be enabled/disabled independently:
```bash
blackdot features disable rust_tools --persist
blackdot features enable cdk_tools --persist
```

---

## Quick Start (Manual)

```bash
# 1. Clone
git clone git@github.com:blackwell-systems/blackdot.git ~/workspace/dotfiles
cd ~/workspace/dotfiles

# 2. Run platform bootstrap
./bootstrap/bootstrap-mac.sh   # macOS
./bootstrap/bootstrap-linux.sh # Linux/WSL

# 3. Run setup wizard
blackdot setup
```

**That's it!** The wizard handles:
- Vault selection (Bitwarden, 1Password, pass, or skip)
- Secret restoration (SSH keys, AWS, Git config)
- Claude Code integration
- Progress is saved—resume anytime with `blackdot setup`

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
blackdot status          # Visual dashboard
blackdot doctor          # Health check
blackdot doctor --fix    # Auto-repair
blackdot drift           # Compare local vs vault

# Vault Operations
blackdot sync            # Smart bidirectional sync
blackdot vault pull      # Restore secrets from vault
blackdot vault push      # Push local changes to vault
blackdot vault validate  # Validate vault schema
blackdot vault setup     # Interactive onboarding

# Templates
blackdot template init   # Setup wizard
blackdot template render # Generate configs

# Maintenance
blackdot upgrade         # Pull latest & bootstrap
blackdot lint            # Validate syntax
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
- **[Developer Tools](developer-tools.md)** – AWS, CDK, Rust, Go integrations & 70+ aliases
- **[Claude Code + dotclaude](claude-code.md)** – Portable sessions, profiles & safety hooks
- **[Template System](templates.md)** – Configure per-machine settings
- **[Troubleshooting](troubleshooting.md)** – Solutions to common issues

---

## Contributing

- [Contributing Guide](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)

---

**Questions?** [Open an issue](https://github.com/blackwell-systems/blackdot/issues) or check the [full documentation](README-FULL.md).
