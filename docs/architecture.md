# Architecture

This page describes the architecture of blackdot—the systems that control how features are loaded, configured, and composed.

## Framework Architecture

Blackdot is a **Go-first** framework with shell integration:

1. **Feature Registry** (`internal/feature/registry.go`) - Modular control plane implemented in Go
2. **Go CLI** (`internal/cli/*.go`) - 20+ Cobra commands for all operations
3. **Vaultmux Library** - External Go library for multi-vault support (Bitwarden/1Password/pass)
4. **Shell Layer** (`zsh/`, `powershell/`) - Aliases and integrations that call the Go binary

**Key principle:** Core functionality lives in Go. Shell provides convenience wrappers and tool integrations.

These systems work together to provide a modular, extensible, cross-platform foundation for AI-assisted development.

## System Overview

```mermaid
graph TB
    subgraph "User Machine"
        CLI["Go Binary<br/>(blackdot)"]
        ZSH["ZSH Shell<br/>(macOS/Linux)"]
        PS["PowerShell<br/>(Windows)"]
    end

    subgraph "Go Implementation"
        FEATURES["Feature Registry<br/>(internal/feature)"]
        VAULT["Vault CLI<br/>(internal/cli/vault.go)"]
        DOCTOR["Health Checks<br/>(internal/cli/doctor.go)"]
        CONFIG["Config Management<br/>(internal/config)"]
    end

    subgraph "External Libraries"
        VAULTMUX["vaultmux<br/>(Go library)"]
        COBRA["Cobra<br/>(CLI framework)"]
    end

    subgraph "External Services"
        VAULT_BACKEND["Multi-Vault<br/>Bitwarden/1Password/pass"]
        GH[GitHub]
    end

    CLI --> FEATURES
    CLI --> VAULT
    CLI --> DOCTOR
    CLI --> CONFIG

    ZSH --> CLI
    PS --> CLI

    VAULT --> VAULTMUX
    VAULTMUX <--> VAULT_BACKEND
    CLI --> COBRA

    GH -->|clone/pull| CLI
```

## Modular Architecture

**Everything is optional except shell config.** The system is designed to be fully modular, allowing users to pick only the components they need. The **feature registry** (`internal/feature/registry.go`) provides centralized control over all optional functionality.

### Feature Registry

The feature registry is the central system for enabling and disabling optional features:

```bash
# List all features
blackdot features

# Enable a feature
blackdot features enable vault --persist

# Use a preset
blackdot features preset developer --persist
```

**Available Features:**

| Category | Features |
|----------|----------|
| **Core** | `shell` (always enabled) |
| **Optional** | `workspace_symlink`, `claude_integration`, `vault`, `encryption`, `hooks`, `templates`, `aws_helpers`, `git_hooks`, `drift_check`, `backup_auto`, `health_metrics`, `macos_settings` |
| **Integration** | `modern_cli`, `nvm_integration`, `sdkman_integration`, `dotclaude` |

**Presets:**

| Preset | Features Enabled |
|--------|------------------|
| `minimal` | `shell` |
| `developer` | `shell`, `vault`, `aws_helpers`, `git_hooks`, `modern_cli` |
| `claude` | `shell`, `workspace_symlink`, `claude_integration`, `vault`, `git_hooks`, `modern_cli` |
| `full` | All features |

See [Feature Registry](features.md) for complete documentation.

### Configuration Layers

The configuration layer system provides a 5-layer priority hierarchy for settings:

```
Priority (highest to lowest):
┌─────────────────────────────────────────────────┐
│ 1. Environment Variables   (session-specific)   │
├─────────────────────────────────────────────────┤
│ 2. Project Config          (.blackdot.local)    │
├─────────────────────────────────────────────────┤
│ 3. Machine Config          (machine.json)       │
├─────────────────────────────────────────────────┤
│ 4. User Config             (config.json)        │
├─────────────────────────────────────────────────┤
│ 5. Defaults                (built-in)           │
└─────────────────────────────────────────────────┘
```

```bash
# Layer-aware config access
config_get_layered "vault.backend"  # Checks all layers in priority order

# Show where a setting comes from
blackdot config layers              # Displays effective config with sources
```

**Layer Files:**

| Layer | File | Use Case |
|-------|------|----------|
| Environment | `$BLACKDOT_*` vars | CI/CD, temporary overrides |
| Project | `.blackdot.local` | Repository-specific settings |
| Machine | `~/.config/blackdot/machine.json` | Per-machine preferences |
| User | `~/.config/blackdot/config.json` | User preferences |
| Defaults | `internal/config/config.go` | Built-in fallbacks |

### CLI Feature Awareness

The Go CLI adapts based on enabled features:

```bash
blackdot help  # Shows only commands for enabled features
```

**Behavior:**
- Commands for disabled features are hidden from help output
- Tab completion excludes disabled feature commands
- Running a disabled command shows an enable hint

```bash
# Example: vault feature disabled
$ blackdot vault pull
Feature 'vault' is not enabled.
Run: blackdot features enable vault
```

**Implementation:**

Feature checks are implemented in Go (`internal/cli/*.go`):
```go
// Each command checks its feature before running
func newVaultCmd() *cobra.Command {
    // Feature check happens in RunE
    if !registry.IsEnabled("vault") {
        return fmt.Errorf("Feature 'vault' is not enabled...")
    }
}
```

### Core vs. Optional Components

| Component | Type | Feature Flag | Skip Method | Details |
|-----------|------|--------------|-------------|---------|
| **Shell Config** | **REQUIRED** | `shell` | Cannot skip | ZSH configuration, plugins, prompt |
| **Homebrew + Packages** | Optional | - | `--minimal` flag | 80+ CLI tools (fzf, ripgrep, bat, etc.) |
| **Vault System** | Optional | `vault` | Select "Skip" in wizard or `--minimal` | Multi-backend secrets (Bitwarden/1Password/pass) |
| **/workspace Symlink** | Optional | `workspace_symlink` | `SKIP_WORKSPACE_SYMLINK=true` | For portable Claude sessions |
| **Claude Integration** | Optional | `claude_integration` | `SKIP_CLAUDE_SETUP=true` or `--minimal` | dotclaude + hooks + settings |
| **Template Engine** | Optional | `templates` | Don't run `blackdot template` | Machine-specific configs |

### Install Modes

```bash
# Full install - Everything (recommended for Claude Code users)
curl -fsSL [...]/install.sh | bash

# Minimal install - Shell config only
curl -fsSL [...]/install.sh | bash -s -- --minimal

# Custom install - Use environment variables
SKIP_WORKSPACE_SYMLINK=true ./bootstrap/bootstrap-mac.sh
SKIP_CLAUDE_SETUP=true ./bootstrap/bootstrap-linux.sh
```

### Environment Variables

All optional components can be controlled via environment variables:

| Variable | Effect | Use Case |
|----------|--------|----------|
| `--minimal` | Skip Homebrew, vault, Claude, /workspace | Minimal shell-only install |
| `BREWFILE_TIER=minimal` | Install only essentials (18 packages, ~2 min) | CI/CD, servers, containers |
| `BREWFILE_TIER=enhanced` | Modern tools without containers (43 packages, ~5 min) | Developer workstations **← RECOMMENDED** |
| `BREWFILE_TIER=full` | Everything including Docker/Node (61 packages, ~10 min) | Full-stack development |
| `SKIP_WORKSPACE_SYMLINK=true` | Skip `/workspace` symlink | Single-machine setups |
| `SKIP_CLAUDE_SETUP=true` | Skip Claude Code integration | Non-Claude workflows |
| `BLACKDOT_OFFLINE=1` | Skip all vault operations | Air-gapped/offline environments |
| `BLACKDOT_SKIP_DRIFT_CHECK=1` | Skip drift detection | CI/automation pipelines |

**Note:** The `blackdot setup` wizard now presents tier selection interactively. Environment variables are available for advanced/automated setups.

### Component Dependencies

```mermaid
graph TD
    SHELL["Shell Config<br/>REQUIRED"]
    BREW["Homebrew + Packages<br/>optional"]
    VAULT["Vault System<br/>optional"]
    WORKSPACE["Workspace Symlink<br/>optional"]
    CLAUDE["Claude Integration<br/>optional"]
    TEMPLATE["Template Engine<br/>optional"]

    SHELL -.->|uses if present| BREW
    SHELL -.->|uses if present| VAULT
    CLAUDE -.->|uses if present| WORKSPACE
    TEMPLATE -.->|independent| SHELL

    style SHELL fill:#22543d,stroke:#2f855a,color:#e2e8f0
    style BREW fill:#2c5282,stroke:#4299e1,color:#e2e8f0
    style VAULT fill:#2c5282,stroke:#4299e1,color:#e2e8f0
    style WORKSPACE fill:#2c5282,stroke:#4299e1,color:#e2e8f0
    style CLAUDE fill:#2c5282,stroke:#4299e1,color:#e2e8f0
    style TEMPLATE fill:#2c5282,stroke:#4299e1,color:#e2e8f0
```

**Key Design Principles:**
- **No hard dependencies** - Optional components gracefully degrade if missing
- **Enable later** - Started minimal? Run `blackdot setup` to add features
- **Progressive disclosure** - Setup wizard guides you through choices
- **Safe defaults** - Full install gives best experience, minimal still works

## Component Architecture

### CLI Entry Point

The unified `blackdot` Go binary provides a single entry point for all operations:

```mermaid
graph LR
    A[blackdot] --> B{Command}
    B --> C[status]
    B --> D[doctor]
    B --> M[features]
    B --> N[config]
    B --> O[hook]
    B --> E[vault]
    B --> F[backup]
    B --> G[diff]
    B --> H[setup]
    B --> I[upgrade]
    B --> J[uninstall]
    B --> K[macos]
    B --> L[template]

    M --> M1[list]
    M --> M2[enable]
    M --> M3[disable]
    M --> M4[preset]

    N --> N1[layers]
    N --> N2[get]
    N --> N3[set]

    O --> O1[list]
    O --> O2[run]
    O --> O3[test]

    E --> E1[pull]
    E --> E2[push]
    E --> E3[list]
    E --> E4[check]

    L --> L1[init]
    L --> L2[render]
    L --> L3[vars]
    L --> L4[check]
```

### File Flow

```mermaid
flowchart TD
    subgraph "Installation"
        A[install.sh/ps1] --> B[Clone Repository]
        B --> C[Build Go Binary]
        C --> D[Create Symlinks]
        D --> E[blackdot setup wizard]
    end

    subgraph "Secret Management (vaultmux)"
        F[Go CLI] <-->|vaultmux| G[Vault Backend]
        G <-->|bw/op/pass CLI| H[Bitwarden/1Password/pass]
        F --> I[Local Files]
    end

    subgraph "Runtime"
        J[Shell Start] --> K[Load .zshrc]
        K --> L[eval blackdot shell-init]
        L --> M[Load zsh.d/*.zsh]
        M --> N[Ready]
    end

    E --> K
```

## Directory Structure

```
blackdot/
├── install.sh                    # Unix installer
├── install-windows.ps1           # Windows PowerShell installer
├── Install.ps1                   # Legacy Windows installer
├── doc.go                        # Go package documentation
│
├── cmd/blackdot/                 # Go CLI entry point
│   └── main.go                   # Binary entry point
│
├── internal/                     # Go implementation
│   ├── cli/                      # Cobra commands (30+ files)
│   │   ├── root.go               # Root command
│   │   ├── features.go           # Feature management
│   │   ├── vault.go              # Vault operations (vaultmux)
│   │   ├── doctor.go             # Health checks
│   │   ├── status.go             # System status
│   │   ├── backup.go             # Backup/restore
│   │   ├── setup.go              # Setup wizard
│   │   ├── hook.go               # Hook management
│   │   ├── config.go             # Config management
│   │   ├── shell_init.go         # Shell initialization code
│   │   ├── tools_*.go            # Developer tool integrations
│   │   └── ...                   # Other commands
│   ├── feature/                  # Feature registry
│   │   ├── registry.go           # Registry implementation
│   │   ├── registry_test.go      # Registry tests
│   │   └── presets.go            # Preset configurations
│   ├── config/                   # Configuration management
│   │   ├── config.go             # JSON config read/write
│   │   └── config_test.go        # Config tests
│   ├── shell/                    # Shell utilities
│   │   └── shell.go              # Shell detection
│   └── template/                 # Template engine
│       └── raymond_engine.go     # Handlebars templates
│
├── bin/                          # Compiled Go binary
│   └── blackdot                  # The CLI (or blackdot.exe on Windows)
│
├── brew/                         # Homebrew Brewfiles
│   ├── Brewfile                  # Full install (~80 packages)
│   ├── Brewfile.enhanced         # Modern tools (~40 packages)
│   └── Brewfile.minimal          # Essentials only (~15 packages)
│
├── docker/                       # Docker configurations
│   ├── Dockerfile.minimal        # Base with Go binary only
│   ├── Dockerfile.medium         # With Homebrew
│   └── Dockerfile.full           # Complete environment
│
├── lib/                          # Minimal shell helpers
│   ├── _colors.sh                # Color output functions
│   ├── _hooks.sh                 # Hook system helpers
│   └── _logging.sh               # Shell logging (info, pass, warn, fail)
│
├── zsh/                          # Zsh config (macOS/Linux)
│   ├── .zshrc                    # Main entry (symlinked to ~/)
│   ├── .p10k.zsh                 # Powerlevel10k theme
│   ├── completions/              # Tab completions
│   │   └── _blackdot             # CLI completions
│   └── zsh.d/                    # Modular config (18 files)
│       ├── 00-init.zsh           # Shell initialization, feature_enabled()
│       ├── 10-plugins.zsh        # ZSH plugins
│       ├── 20-env.zsh            # Environment variables
│       ├── 30-tools.zsh          # Tool PATH setup
│       ├── 40-aliases.zsh        # Aliases, blackdot command
│       ├── 50-functions.zsh      # Shell functions
│       ├── 60-aws.zsh            # AWS/CDK integrations
│       ├── 62-rust.zsh           # Rust tools
│       ├── 63-go.zsh             # Go tools
│       ├── 64-python.zsh         # Python/uv tools
│       ├── 65-ssh.zsh            # SSH tools
│       ├── 66-docker.zsh         # Docker tools
│       ├── 70-claude.zsh         # Claude Code integration
│       ├── 80-git.zsh            # Git aliases
│       ├── 90-integrations.zsh   # NVM, SDKMAN
│       └── 99-local.zsh.example  # Local overrides template
│
├── powershell/                   # PowerShell module (Windows)
│   ├── Blackdot.psm1             # Main module
│   ├── Blackdot.psd1             # Module manifest
│   ├── Install-Blackdot.ps1      # Module installer
│   └── Install-Packages.ps1      # Winget package installer
│
├── vault/                        # Vault configuration
│   ├── README.md                 # Vault documentation
│   └── vault-items.example.json  # Example vault schema
│
├── claude/                       # Claude Code integration
│   ├── hooks/                    # Git safety hooks
│   │   ├── git-sync-check.ps1    # PowerShell version
│   │   ├── block-dangerous-git.ps1
│   │   └── *.sh                  # Bash/Zsh versions
│   └── commands/                 # Slash commands
│
└── docs/                         # Docsify documentation site
    ├── index.html                # Docsify config
    ├── _sidebar.md               # Navigation
    ├── _coverpage.md             # Landing page
    ├── README.md                 # Homepage
    └── *.md                      # Documentation pages (29 files)
```

**Key changes from shell-based architecture:**
- `cmd/` and `internal/` contain all Go implementation
- `bin/` contains only the compiled Go binary
- `lib/` reduced to 3 files (colors, hooks, logging)
- No shell scripts in `bin/`, `vault/`, or elsewhere - all functionality in Go
- Shell layer (`zsh.d/`) calls Go binary for all operations

## ZSH Module Load Order

The modular ZSH configuration loads files in numbered order:

```mermaid
flowchart LR
    A[00-init] --> B[10-environment]
    B --> C[20-history]
    C --> D[30-prompt]
    D --> E[40-aliases]
    E --> F[50-functions]
    F --> G[60-completions]
    G --> H[70-plugins]
    H --> I[80-tools]
    I --> J[90-local]
```

| Module | Purpose |
|--------|---------|
| `00-init.zsh` | Strict mode, basic setup |
| `10-environment.zsh` | PATH, environment variables |
| `20-history.zsh` | History configuration |
| `30-prompt.zsh` | Powerlevel10k prompt |
| `40-aliases.zsh` | Shell aliases, `blackdot` command |
| `50-functions.zsh` | Shell functions, `status` |
| `60-completions.zsh` | Tab completion setup |
| `70-plugins.zsh` | ZSH plugins |
| `80-tools.zsh` | Tool integrations (nvm, etc.) |
| `90-local.zsh` | Machine-specific overrides |

## PowerShell Module (Windows)

The PowerShell module provides equivalent functionality for Windows users:

```powershell
Import-Module Blackdot
```

| Component | Purpose |
|-----------|---------|
| `Blackdot.psm1` | Main module with all functions |
| `Blackdot.psd1` | Module manifest (version, exports) |
| Hooks | `Invoke-BlackdotHook`, `Enable-BlackdotHooks` |
| Git aliases | `gst`, `gd`, `gco`, `gcm`, `gp`, `gl` |
| Tool wrappers | `aws-*`, `docker-*`, `claude-*` |
| Navigation | `z` (zoxide), `fnm-*` (Node.js) |

**Installation:**
```powershell
irm https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install-windows.ps1 | iex
```

Both Zsh and PowerShell modules share the same aliases where possible, so commands like `gst` (git status) work in both shells.

## Vault System

The vault system (`internal/cli/vault.go` + `vaultmux` library) provides bidirectional sync with multiple backends (Bitwarden, 1Password, pass). All vault operations are implemented in Go.

### Configuration

Vault items are defined in a user-editable config file:

```
~/.config/blackdot/vault-items.json    # Vault schema (single secrets[] array)
~/.config/blackdot/config.json         # Config (vault backend, state, paths)
```

**Vault Schema:** Uses a single `secrets[]` array for all secrets. Each item has granular control for sync, backup, and required status.

See `vault/vault-items.example.json` for the template.

### Schema Validation

The vault system validates `vault-items.json` before all sync operations:

```bash
blackdot vault validate  # Manual validation
```

**Automatic validation:**
- Before `blackdot vault push` operations
- Before `blackdot vault pull` operations
- During setup wizard vault configuration phase

**Validates:**
- Valid JSON syntax
- Required fields (path, required, type)
- Valid type values ("file" or "sshkey")
- Naming conventions (capital letter start)
- Path format (~, /, or $ prefix)

**Interactive error recovery:**
If validation fails during setup, offers to open editor for immediate fixes with automatic re-validation after save.

### Data Flow

```mermaid
sequenceDiagram
    participant User
    participant CLI as Go CLI (blackdot)
    participant VMux as vaultmux Library
    participant Config as ~/.config/blackdot
    participant Local as Local Files
    participant BW as Bitwarden

    User->>CLI: blackdot vault setup
    CLI->>Config: Create vault-items.json
    CLI->>Config: Set backend (bitwarden/1password/pass)

    User->>CLI: blackdot vault pull
    CLI->>VMux: vaultmux.GetItem()
    VMux->>BW: bw get item
    BW-->>VMux: Return encrypted data
    VMux-->>CLI: Parsed secret
    CLI->>Local: Write files (600 perms)

    User->>CLI: blackdot vault push
    CLI->>Local: Read files
    CLI->>VMux: vaultmux.UpdateItem()
    VMux->>BW: bw edit item
```

### Protected Items

The vault system protects certain items from accidental deletion:

- SSH keys and config
- AWS credentials
- Git configuration
- Environment secrets

### Vault Item Schema

Each vault item follows a consistent schema:

```json
{
  "name": "blackdot-item-name",
  "type": 2,
  "notes": "item content here",
  "fields": [
    {"name": "type", "value": "config"},
    {"name": "path", "value": "$HOME/.config/file"}
  ]
}
```

## Hook System

The hook system (`internal/cli/hook.go` + `lib/_hooks.sh`) allows custom behavior at lifecycle events without modifying core scripts. Go handles registration and execution, while shell helpers provide convenience functions.

### Hook Points

| Category | Hook Points |
|----------|-------------|
| **Lifecycle** | `pre_install`, `post_install`, `pre_bootstrap`, `post_bootstrap`, `pre_upgrade`, `post_upgrade` |
| **Vault** | `pre_vault_pull`, `post_vault_pull`, `pre_vault_push`, `post_vault_push` |
| **Doctor** | `pre_doctor`, `post_doctor`, `doctor_check` |
| **Shell** | `shell_init`, `shell_exit`, `directory_change` |
| **Setup** | `pre_setup_phase`, `post_setup_phase`, `setup_complete` |

### Registration Methods

1. **File-based** - Scripts in `~/.config/blackdot/hooks/<hook_point>/`
2. **JSON config** - Hooks defined in `~/.config/blackdot/hooks.json`
3. **Inline** - Registered programmatically via `hook_register`

### Integration Points

```mermaid
flowchart TD
    A[install.sh] -->|pre/post_install| H[Hook System]
    B[bootstrap-*.sh] -->|pre/post_bootstrap| H
    C[blackdot sync] -->|pre/post_vault_*| H
    D[blackdot doctor] -->|pre/post/check_doctor| H
    E[.zshrc] -->|shell_init/exit| H
    F[cd command] -->|directory_change| H

    H --> G[User Scripts]
```

See [Hook System](hooks.md) for complete documentation.

## Setup Wizard

The interactive setup wizard (`blackdot setup`) guides users through installation with visual feedback:

### Progress Visualization

```
╔═══════════════════════════════════════════════════════════════╗
║ Step 4 of 7: Vault Configuration
╠═══════════════════════════════════════════════════════════════╣
║ ██████████░░░░░░░░░░ 57%
╚═══════════════════════════════════════════════════════════════╝
```

**Features:**
- **Unicode progress bars** - 20-character bar with █ (completed) and ░ (remaining)
- **Step counter** - Shows current step and total steps
- **Percentage indicator** - Exact completion percentage
- **Overview display** - All steps shown at beginning
- **Division by zero protection** - Guards against edge cases
- **Overflow protection** - Clamps progress to valid range

**Setup phases:**
1. Workspace - Configure workspace directory target
2. Symlinks - Shell configuration
3. Packages - Homebrew installation (tier selection)
4. Vault - Backend selection
5. Secrets - Credential restoration
6. Claude Code - Optional integration
7. Templates - Machine-specific configs

### State Persistence

State is saved to `~/.config/blackdot/config.json`:
- Setup completion status per phase
- User preferences (vault backend, package tier)
- Can resume if interrupted

See [State Management](state-management.md) for details.

## Health Check System

The `blackdot doctor` command validates system state:

```mermaid
flowchart TD
    A[blackdot doctor] --> B{Check Type}
    B --> C[File Permissions]
    B --> D[Symlink Status]
    B --> E[Directory Structure]
    B --> F[Tool Availability]
    B --> G[Vault Connection]

    C --> H{--fix flag?}
    D --> H
    E --> H

    H -->|Yes| I[Auto-remediate]
    H -->|No| J[Report Only]
```

## Backup System

The backup system creates timestamped archives:

```mermaid
flowchart LR
    A[blackdot backup] --> B[Collect Files]
    B --> C[Create tar.gz]
    C --> D[~/.blackdot-backups/]
    D --> E[Auto-cleanup > 10]

    F[blackdot backup restore] --> G[List Backups]
    G --> H[Select Backup]
    H --> I[Extract & Restore]
```

## Platform Support

```mermaid
graph TB
    subgraph "Supported Platforms"
        A[macOS] --> D[bootstrap-mac.sh]
        B[Linux] --> E[bootstrap-linux.sh]
        C[WSL2] --> E
        F[Docker] --> E
        G[Lima] --> E
    end

    D --> H[Homebrew]
    E --> I[apt/dnf]

    H --> J[Common Setup]
    I --> J
```

## Data Flow Summary

| Flow | Source | Destination | Command |
|------|--------|-------------|---------|
| Install | GitHub | Local | `curl ... \| bash` |
| Bootstrap | Scripts | System | `blackdot setup` |
| Pull | Bitwarden | Local | `blackdot vault pull` |
| Push | Local | Bitwarden | `blackdot vault push` |
| Backup | Config | Archive | `blackdot backup` |
| Restore | Archive | Config | `blackdot backup restore` |
| Upgrade | GitHub | Local | `blackdot upgrade` |
| Remove | Local | (deleted) | `blackdot uninstall` |

---

## Multi-Platform Architecture

Blackdot is designed for extensibility across multiple platforms with **90% shared code**.

### Platform Support Matrix

| Platform | Bootstrap Script | Status | Notes |
|----------|-----------------|---------|-------|
| **macOS** | `bootstrap-mac.sh` | Fully tested | Apple Silicon & Intel |
| **Windows** | `install-windows.ps1` | Fully tested | Native PowerShell module |
| **Lima VM** | `bootstrap-linux.sh` | Fully tested | Ubuntu 24.04 |
| **WSL2** | `bootstrap-linux.sh` | Auto-detected | Windows 10/11 with Linux |
| **Ubuntu/Debian** | `bootstrap-linux.sh` | Compatible | Bare metal or VM |

### Extensible to (~30 minutes each):
- Docker containers
- Arch Linux
- Fedora/RHEL
- FreeBSD/OpenBSD
- Any POSIX-compliant system with ZSH or Windows with PowerShell

### Architecture Layers

```mermaid
flowchart TB
    platform["<b>Platform-Specific Bootstrap</b><br/>(10% of code)<br/>━━━━━━━━━━━━━━━━━━━━━<br/>• Package manager setup (apt/brew/winget)<br/>• System-specific configuration<br/>• GUI tool installation"]

    shared["<b>Shared Blackdot Layer</b><br/>(90% of code)<br/>━━━━━━━━━━━━━━━━━━━━━<br/>• Go CLI (blackdot commands)<br/>• Shell integration (Zsh/PowerShell)<br/>• Vault system (vaultmux)<br/>• Health checks & metrics<br/>• Feature Registry"]

    platform --> shared

    style platform fill:#2c5282,stroke:#4299e1,color:#e2e8f0
    style shared fill:#1a365d,stroke:#2c5282,color:#e2e8f0
```

### Platform-Independent Components

These work on **any platform** without modification:

**Go CLI** (100% portable)
- Single binary (`blackdot`) works on macOS, Linux, Windows
- All commands: `doctor`, `vault`, `status`, `features`, `config`, etc.
- Cross-platform file permissions handling
- Identical behavior across all platforms

**Vault System** (vaultmux - 100% portable)
- Multi-backend support via vaultmux Go library
- Backends: Bitwarden (`bw`), 1Password (`op`), pass (`pass/gpg`)
- Works on Linux, macOS, BSD, WSL, Windows, Docker
- Same vault operations across all platforms

**Feature Registry** (Go - 100% portable)
- `internal/feature/registry.go` - central control plane
- Enable/disable features: `blackdot features enable/disable <name>`
- Dependency resolution and conflict detection
- Works identically everywhere

**Shell Integration** (Platform-specific wrappers)
- **Unix/Linux/macOS**: Zsh configuration (`zsh/zshrc`, `zsh.d/*.zsh`)
- **Windows**: PowerShell module (`powershell/Blackdot.psm1`)
- Both call the same Go CLI binary
- Platform-specific aliases and helpers that invoke Go commands

### Adding a New Platform

Example: Adding Arch Linux support (~30 lines)

```bash
#!/usr/bin/env bash
set -euo pipefail

BLACKDOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. System packages (platform-specific)
sudo pacman -Syu --noconfirm git zsh curl base-devel

# 2. Install Homebrew (optional but recommended)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 3. SHARED: Use same Brewfile
brew bundle --file="$BLACKDOT_DIR/brew/Brewfile"

# 4. SHARED: Use same blackdot bootstrap
"$BLACKDOT_DIR/bootstrap/bootstrap-blackdot.sh"

# 5. Set shell to zsh
chsh -s $(command -v zsh)
```

Everything else (vault, health checks, configs, metrics) works without modification.

### Platform Detection

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

### Why Multi-Platform Matters

**Portability**: Use the same configuration across:
- Work and personal machines (macOS/Linux)
- Development VMs (Lima/WSL)
- CI/CD containers (Docker)
- Cloud instances

**Maintainability**: Fix bugs or add features **once**, benefits **all platforms**.

**Extensibility**: New platform = ~30 lines of platform-specific code + reuse 90%.

---

## Workspace Architecture

The canonical workspace directory at `~/workspace` (with `/workspace` symlink) enables portable paths across machines.

### Visual Overview

```mermaid
flowchart TB
    subgraph host["Host: /Users/username/ (macOS)"]
        h_secrets["Secrets<br/>(.ssh, .aws, .gitconfig)<br/><small>Per-machine</small>"]
        h_workspace["~/workspace/<br/><small>Shared files</small>"]
    end

    subgraph guest["Guest: /home/username/ (Lima/WSL)"]
        g_secrets["Secrets<br/>(.ssh, .aws, .gitconfig)<br/><small>Per-machine</small>"]
        g_workspace["~/workspace/<br/><small>Mounted from host</small>"]
    end

    subgraph shared["Shared: ~/workspace/ Content"]
        direction LR
        blackdot["blackdot/"]
        code["code/"]
        claude[".claude/"]
    end

    h_workspace <-->|same files| g_workspace
    h_workspace -.-> shared
    g_workspace -.-> shared

    h_secrets <-.->|vault push| g_secrets

    symlink["/workspace → ~/workspace<br/><small>Ensures identical paths across all machines</small>"]

    style host fill:#1a365d,stroke:#2c5282,color:#e2e8f0
    style guest fill:#1a365d,stroke:#2c5282,color:#e2e8f0
    style shared fill:#2c5282,stroke:#4299e1,color:#e2e8f0
    style symlink fill:#22543d,stroke:#2f855a,color:#e2e8f0
    style h_workspace fill:#2c5282,stroke:#4299e1,color:#e2e8f0
    style g_workspace fill:#2c5282,stroke:#4299e1,color:#e2e8f0
    style claude fill:#2f855a,stroke:#48bb78,color:#e2e8f0
```

**Key concepts:**
- **Host & Guest** share `~/workspace/` (mounted/synced)
- **Secrets** (.ssh, .aws, .gitconfig) are per-machine, synced via vault
- **`/workspace` symlink** ensures identical paths: `cd /workspace/blackdot` works everywhere
- **Claude Code sessions** are portable across machines via shared `.claude/` state

### Bootstrap Flow

```mermaid
flowchart TB
    machine["New Machine"]

    subgraph setup["Setup Phase"]
        bootstrap["Bootstrap<br/><small>bootstrap-mac/linux.sh</small><br/>Install packages, tools, shell"]
        restore["Restore Secrets<br/><small>blackdot vault pull</small><br/>SSH, AWS, Git, env"]
        verify["Health Check<br/><small>blackdot doctor</small><br/>Verify installation"]
    end

    subgraph tools["Package Sources"]
        brewfile["Brewfile<br/><small>brew, zsh, plugins...</small>"]
    end

    subgraph vault["Multi-Vault Backend"]
        vault_storage["Vault Storage<br/><small>Bitwarden / 1Password / pass</small><br/>• SSH keys<br/>• AWS credentials<br/>• Git config<br/>• Environment secrets"]
    end

    subgraph sync["Maintenance"]
        sync_back["blackdot vault push<br/><small>Push local changes back</small>"]
    end

    machine --> bootstrap
    bootstrap --> restore
    restore --> verify

    bootstrap -.->|installs| brewfile
    restore -->|pulls from| vault_storage
    verify -->|after changes| sync_back
    sync_back -->|updates| vault_storage

    style machine fill:#2d3748,stroke:#4a5568,color:#e2e8f0
    style setup fill:#1a365d,stroke:#2c5282,color:#e2e8f0
    style tools fill:#1a365d,stroke:#2c5282,color:#e2e8f0
    style vault fill:#1a365d,stroke:#2c5282,color:#e2e8f0
    style sync fill:#1a365d,stroke:#2c5282,color:#e2e8f0
    style bootstrap fill:#2c5282,stroke:#4299e1,color:#e2e8f0
    style restore fill:#2c5282,stroke:#4299e1,color:#e2e8f0
    style verify fill:#22543d,stroke:#2f855a,color:#e2e8f0
```
