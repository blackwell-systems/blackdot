# Dotfiles & Vault Setup

[![Test Status](https://github.com/blackwell-systems/dotfiles/workflows/Test%20Dotfiles/badge.svg)](https://github.com/blackwell-systems/dotfiles/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20Linux%20%7C%20Lima%20%7C%20WSL2-blue)
![Shell](https://img.shields.io/badge/Shell-Zsh-blueviolet)
![Secrets](https://img.shields.io/badge/Secrets-Bitwarden-ff4081)
![Claude Portability](https://img.shields.io/badge/Claude_Portability-Enabled-8A2BE2)

> Enterprise-grade, vault-backed dotfiles for multi-machine development. Bitwarden provides the source of truth for secrets, a canonical `/workspace` path keeps Claude Code sessions portable across macOS, Linux, Lima, and WSL2, and health checks guard against drift, broken symlinks, and missing vault state.

**Version:** 1.0.0 | [Changelog](CHANGELOG.md) | [Full Documentation](docs/README-FULL.md)

---

## Features

### Core (works everywhere)
- **Bitwarden vault integration** – SSH keys, AWS credentials, Git config, and environment secrets restored from Bitwarden. One unlock, full environment.
- **Automated health checks** – Validate symlinks, permissions, required tools, and vault sync. Optional auto-fix and drift detection.
- **Modern CLI stack** – eza, fzf, ripgrep, zoxide, bat, and other modern Unix replacements, configured and ready.
- **Idempotent design** – Run bootstrap repeatedly. Scripts converge to known-good state without breaking existing setup.
- **Fast setup** – Clone to working shell in under five minutes.

### Advanced (opt-in)
- **Cross-platform portability** – Same dotfiles on macOS, Linux, WSL2, Lima, or Docker with ~90% shared code.
- **Portable Claude Code sessions** – `/workspace` symlink ensures Claude sessions sync across machines. Start on macOS, continue on Linux, keep your conversation.
- **Metrics and observability** – Track dotfiles health over time. Surface drift, failures, and missing vault items.

---

## Prerequisites

You don’t need Git or the Bitwarden CLI preinstalled – the bootstrap scripts will install the tooling for you.

What you do need:

- A supported environment: macOS, Linux, WSL2, or Lima
- Internet access (to install Homebrew/Brew packages and the Bitwarden CLI)
- A Bitwarden account (for vault-backed secrets)
- A GitHub account with access to this repository

To clone via SSH (recommended), you’ll also want an SSH key configured with GitHub. If you don’t have Git yet, you can either:
- install it the way you normally would on your platform, or  
- download this repository as a ZIP from GitHub, extract it, and run `bootstrap-mac.sh` / `bootstrap-linux.sh` – the scripts will install Git and the Bitwarden CLI for you.

---

## Quick Start

```bash
# 1. Clone
git clone git@github.com:blackwell-systems/dotfiles.git ~/workspace/dotfiles
cd ~/workspace/dotfiles

# 2. Bootstrap (picks your platform automatically)
./bootstrap-mac.sh      # macOS
./bootstrap-linux.sh    # Linux / WSL2 / Lima / Docker

# 3. Restore secrets from Bitwarden
bw login
export BW_SESSION="$(bw unlock --raw)"
./vault/bootstrap-vault.sh

# 4. Verify
./check-health.sh
```

**That's it.** Shell configured, secrets restored, health validated.

<details>
<summary><b>Don't use Bitwarden?</b></summary>

The vault system is optional. Skip step 3 and manually configure:

- `~/.ssh/` – your SSH keys
- `~/.aws/` – your AWS credentials
- `~/.gitconfig` – your git identity

Everything else still works.
</details>

---

## Use Cases

**Single Linux machine** – Vault-backed secrets, health checks, modern CLI. No cross-platform complexity.

**macOS daily driver** – Full experience including Ghostty terminal config and macOS system preferences.

**Docker/CI environments** – Bootstrap in containers for reproducible builds. Vault restore from CI secrets.

**Multi-machine workflow** – Develop on macOS, test on Linux VM, deploy from WSL. Same dotfiles, same secrets, same Claude sessions everywhere.

**Team onboarding** – New developer? Clone, bootstrap, unlock vault. Consistent environment in minutes, not days.

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
./vault/sync-to-bitwarden.sh --all

# New machine: Restore secrets
bw-restore  # Alias for ./vault/bootstrap-vault.sh

# Check for drift (local vs Bitwarden)
./check-health.sh --drift
```

**Supported secrets:**
- SSH keys (multiple identities)
- SSH config (host mappings)
- AWS config & credentials
- Git configuration (.gitconfig)
- Environment variables (.local/env.secrets)

### Tips

<details>
<summary><b>Portable Claude Code Sessions (optional)</b></summary>

If you use Claude Code across multiple machines, the `/workspace` symlink keeps your sessions in sync:

```bash
cd /workspace/my-project  # Same path on all machines
claude                     # Same session everywhere
```

The bootstrap creates `/workspace → ~/workspace` automatically. If you're on a single machine, this just works transparently—no action needed.

**Why this matters:** Claude Code stores sessions by working directory path. Different machines have different home directories (`/Users/name` vs `/home/name`), creating different session IDs. The `/workspace` symlink normalizes this.

**Auto-redirect:** The `claude` wrapper detects `~/workspace/*` paths and automatically switches to `/workspace/*`, showing an educational message to teach you the pattern.

</details>

### Health Checks

Validate your environment anytime:

```bash
./check-health.sh           # Run validation
./check-health.sh --fix     # Auto-repair permissions
./check-health.sh --drift   # Compare local vs Bitwarden
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
├── bootstrap-mac.sh           # macOS setup
├── bootstrap-linux.sh         # Lima/Linux/WSL2 setup
├── bootstrap-dotfiles.sh      # Shared symlink creation
├── check-health.sh            # Health validation (574 lines)
├── show-metrics.sh            # Metrics visualization
├── Brewfile                   # Package definitions
│
├── vault/                     # Bitwarden secret management
│   ├── _common.sh            # Shared config (SSH_KEYS array)
│   ├── bootstrap-vault.sh    # Orchestrator
│   ├── restore-*.sh          # Restore SSH, AWS, Git, env
│   ├── sync-to-bitwarden.sh  # Sync local → Bitwarden
│   └── check-vault-items.sh  # Pre-flight validation
│
├── zsh/                       # Shell configuration
│   ├── zshrc                 # Main config (900+ lines)
│   └── p10k.zsh             # Powerlevel10k theme
│
├── claude/                    # Claude Code integration
│   └── settings.json         # Permissions & preferences
│
├── macos/                     # macOS-specific
│   └── apply-settings.sh     # System preferences
│
└── docs/                      # Documentation
    └── README-FULL.md        # Complete documentation
```

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
- **[Full Documentation](docs/README-FULL.md)** - Complete guide (1,900+ lines)
- **[Vault README](vault/README.md)** - Bitwarden vault details
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contributor guide
- **[SECURITY.md](SECURITY.md)** - Security policy
- **[CHANGELOG.md](CHANGELOG.md)** - Version history

---

## Troubleshooting

### Common Issues

**Claude workspace not detected:**
```bash
# Ensure /workspace symlink exists
ls -la /workspace
# Should point to: /Users/yourname/workspace (macOS) or /home/yourname/workspace (Linux)

# Fix if missing:
sudo ln -sfn $HOME/workspace /workspace
```

**SSH keys not working:**
```bash
# Check permissions
./check-health.sh --fix

# Verify keys are loaded
ssh-add -l

# Test connection
ssh -T git@github.com
```

**Bitwarden session expired:**
```bash
# Re-unlock vault
export BW_SESSION="$(bw unlock --raw)"

# Or logout and login again
bw logout
bw login
```

See [Full Troubleshooting Guide](docs/README-FULL.md#troubleshooting) for more.

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
