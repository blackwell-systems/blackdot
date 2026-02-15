# Blackdot

[![Go](https://img.shields.io/badge/Go-1.24%2B-00ADD8?logo=go&logoColor=white)](https://go.dev/)
[![Platform](https://img.shields.io/badge/macOS%20%7C%20Linux%20%7C%20Windows%20%7C%20WSL2%20%7C%20Docker-blue)](https://github.com/blackwell-systems/blackdot)
[![Test Status](https://github.com/blackwell-systems/blackdot/workflows/Test%20Blackdot/badge.svg)](https://github.com/blackwell-systems/blackdot/actions)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

Your secrets, shell config, and dev environment follow you to any machine with one command.

Blackdot is a dotfiles framework built in Go. It manages shell configuration, secrets (via Bitwarden, 1Password, or pass), developer tool setup, and Claude Code integration across macOS, Linux, Windows, WSL2, and Docker.

```bash
# macOS / Linux / WSL
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install-windows.ps1 | iex
```

The installer runs an interactive setup wizard. You choose what to install — everything is optional except base shell config. [Install options](#install-options) | [Docker test drive](docs/docker.md)

---

## What You Get

**Shell** — Zsh with Powerlevel10k, modular config (`zsh.d/`), 90+ aliases. PowerShell module on Windows.

**Secrets** — Unified API across Bitwarden, 1Password, and pass. Bidirectional sync, drift detection, schema validation. Your SSH keys, AWS creds, and git config restore on any new machine in seconds.

**Developer tools** — AWS, Docker, Go, Rust, Python, SSH, NVM, SDKMAN integrations. Three package tiers (minimal/enhanced/full) via Homebrew or winget.

**Claude Code** — Portable sessions via `/workspace` symlink, [dotclaude](https://github.com/blackwell-systems/dotclaude) profile sync, git safety hooks that prevent destructive commands.

**Feature registry** — Central control plane. Enable/disable any capability. Four presets (minimal, developer, claude, full) with dependency resolution.

**Self-healing** — `blackdot doctor --fix` validates your setup and auto-repairs common issues. Drift detection compares local state against your vault.

```bash
blackdot features              # See what's enabled
blackdot features preset dev   # Enable developer tools
blackdot vault pull            # Restore secrets from vault
blackdot doctor                # Health check + auto-fix
blackdot status                # Visual dashboard
```

---

## How It Works

```
┌──────────────────────────────────────────────┐
│              Feature Registry                 │
│         (controls what's loaded)              │
├──────────┬──────────┬────────────┬───────────┤
│  Vault   │ Templates│   Hooks    │  Config   │
│ (secrets)│ (machine │ (lifecycle)│  Layers   │
│  bw/op/  │  configs)│            │ (5-layer  │
│  pass    │          │            │  priority)│
├──────────┴──────────┴────────────┴───────────┤
│       Go CLI  ←→  Shell Modules (zsh.d/)     │
└──────────────────────────────────────────────┘
```

The Go binary (`blackdot`) is the core. Shell modules in `zsh.d/` call back into it for feature checks. Config resolves through 5 layers: environment > project > machine > user > defaults.

[Architecture docs](docs/architecture.md) | [CLI reference](docs/cli-reference.md)

---

## Choose Your Level

Everything is optional except shell config. Start minimal, add what you need.

| Component | What It Does | How to Skip |
|-----------|-------------|-------------|
| **Shell config** | Zsh/PowerShell + prompt, plugins, aliases | Cannot skip (core) |
| **Packages** | CLI tools via Homebrew/winget (18/43/61 packages) | `--minimal` flag |
| **Vault** | Multi-backend secrets management | Select "Skip" in wizard |
| **Claude Code** | Portable sessions + dotclaude profiles | `SKIP_CLAUDE_SETUP=true` |
| **Templates** | Machine-specific configs (work vs personal) | Don't run `blackdot template` |
| **Workspace symlink** | `/workspace` for cross-machine path consistency | `SKIP_WORKSPACE_SYMLINK=true` |

**Presets** for quick setup:

```bash
blackdot features preset minimal    # Shell only
blackdot features preset developer  # + vault, tools, git hooks
blackdot features preset claude     # + portable sessions, dotclaude
blackdot features preset full       # Everything
```

---

## Install Options

```bash
# Minimal: just shell config, no packages/vault/Claude
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install.sh | bash -s -- --minimal

# Custom workspace directory (default: ~/workspace)
WORKSPACE_TARGET=~/code curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install.sh | bash
```

**Manual clone:**

```bash
git clone git@github.com:blackwell-systems/blackdot.git ~/workspace/blackdot
cd ~/workspace/blackdot
./bootstrap/bootstrap-mac.sh    # or bootstrap-linux.sh
blackdot setup                  # Interactive wizard
```

**Windows:** See [Windows Setup Guide](docs/windows-setup.md).

---

## Common Tasks

```bash
# Sync secrets
blackdot vault pull                    # Restore all secrets
blackdot vault push SSH-Config         # Push local changes to vault
blackdot sync                          # Smart bidirectional sync

# Manage features
blackdot features enable vault --persist
blackdot features disable drift_check

# Maintenance
blackdot upgrade                       # Pull latest + bootstrap + health check
blackdot doctor --fix                  # Diagnose and auto-repair
blackdot backup create                 # Snapshot current state
```

---

## Platform Support

| Platform | Status |
|----------|--------|
| macOS (Apple Silicon / Intel) | Fully tested |
| Windows (PowerShell 5.1+) | Fully tested |
| WSL2 | Auto-detected, uses Linux bootstrap |
| Linux (Ubuntu/Debian) | Fully tested |
| Docker | 4 image variants ([guide](docs/docker.md)) |

---

<details>
<summary><b>How Blackdot compares to other dotfiles managers</b></summary>

### vs chezmoi

chezmoi is the most popular dotfiles manager and excellent at file-based config management. Blackdot takes a different approach — it's an application framework, not a file syncer:

| | Blackdot | chezmoi |
|---|---|---|
| **Core model** | Feature registry + vault sync | Template-based file management |
| **Secrets** | Unified API across 3 vault backends | External tool integration |
| **Sync direction** | Bidirectional (local ↔ vault) | One-way (template → target) |
| **Configuration** | 5-layer priority resolution | Single config file |
| **Health checks** | `doctor --fix` with auto-repair | `doctor` (diagnostic only) |
| **AI integration** | Claude Code sessions + dotclaude | None |
| **Learning curve** | CLI commands | YAML + Go templates |

### vs traditional dotfiles repos (holman, thoughtbot, mathiasbynens)

Traditional repos are collections of config files with a bootstrap script. Blackdot adds structure on top: a feature registry, vault-backed secrets, health checks, drift detection, and a CLI that ties it all together. The tradeoff is complexity — if you just want to symlink some rc files, a simple repo is fine.

**Blackdot is worth it when you:**
- Manage secrets across multiple machines
- Want to enable/disable capabilities without editing files
- Use Claude Code and want session portability
- Need health checks and drift detection
- Work across macOS, Linux, and Windows

</details>

---

## Documentation

| Guide | Description |
|-------|-------------|
| [CLI Reference](docs/cli-reference.md) | All commands and flags |
| [Feature Registry](docs/features.md) | Enable/disable capabilities |
| [Vault System](docs/vault-README.md) | Multi-backend secrets |
| [Developer Tools](docs/developer-tools.md) | AWS, Docker, Go, Rust, Python, SSH |
| [Claude Code](docs/claude-code.md) | Portable sessions + dotclaude |
| [Hook System](docs/hooks.md) | 19 lifecycle hooks |
| [Templates](docs/templates.md) | Machine-specific configs |
| [Architecture](docs/architecture.md) | System design |
| [Configuration Layers](docs/configuration-layers.md) | 5-layer priority |
| [Troubleshooting](docs/troubleshooting.md) | Common issues + fixes |

**Full docs site:** [blackwell-systems.github.io/blackdot](https://blackwell-systems.github.io/blackdot/)

---

## Contributing

Contributions welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for workflow, testing, and commit conventions.

Report security issues via [GitHub Security Advisories](https://github.com/blackwell-systems/blackdot/security/advisories).

---

## License

Apache License 2.0 — see [LICENSE](LICENSE).

Blackwell Systems™ is a trademark of Dayna Blackwell. See [BRAND.md](docs/BRAND.md) for usage guidelines.
