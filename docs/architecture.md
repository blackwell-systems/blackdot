# Architecture

This page describes the architecture of the blackdot framework—the systems that control how features are loaded, configured, and composed.

## Framework Architecture

The blackdot system is built on three core architectural systems:

1. **Feature Registry** (`lib/_features.sh`) - Modular control plane for all functionality
2. **Configuration Layers** (`lib/_config_layers.sh`) - 5-layer priority system for settings
3. **Claude Code Integration** (`claude/`, `/workspace`) - Portable sessions, dotclaude profiles, git safety hooks

Additional systems:

4. **Hook System** (`lib/_hooks.sh`) - Lifecycle hooks for custom behavior at key points
5. **Encryption System** (`lib/_encryption.sh`) - Age-based file encryption for non-vault secrets

These systems work together to provide a modular, extensible foundation for AI-assisted development across machines.

## System Overview

```mermaid
graph TB
    subgraph "User Machine"
        CLI[blackdot CLI]
        ZSH[ZSH Shell]
        SYMLINKS[Symlinked Configs]
    end

    subgraph "Dotfiles Repository"
        BOOTSTRAP[Bootstrap Scripts]
        VAULT_SCRIPTS[Vault Scripts]
        DOCTOR[Health Checks]
        ZSHD[ZSH Modules]
    end

    subgraph "External Services"
        VAULT_BACKEND["Multi-Vault<br/>Bitwarden/1Password/pass"]
        GH[GitHub]
    end

    CLI --> DOCTOR
    CLI --> VAULT_SCRIPTS
    CLI --> BOOTSTRAP
    ZSH --> ZSHD
    SYMLINKS --> ZSHD

    VAULT_SCRIPTS <--> VAULT_BACKEND
    BOOTSTRAP --> SYMLINKS
    GH --> BOOTSTRAP
```

## Modular Architecture

**Everything is optional except shell config.** The system is designed to be fully modular, allowing users to pick only the components they need. The **feature registry** (`lib/_features.sh`) provides centralized control over all optional functionality.

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
| Machine | `~/.config/dotfiles/machine.json` | Per-machine preferences |
| User | `~/.config/dotfiles/config.json` | User preferences |
| Defaults | `lib/_config_layers.sh` | Built-in fallbacks |

### CLI Feature Awareness

The CLI adapts based on enabled features:

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

```bash
# In lib/_cli_features.sh
_cli_feature_map=(
    ["vault:pull"]="vault"
    ["vault:push"]="vault"
    ["template:render"]="templates"
    # ...
)

# Commands check feature status before executing
cli_command_available "vault:pull"  # Returns 0 if vault enabled
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
curl -fsSL [...]/install.sh | bash && blackdot setup

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

    style SHELL fill:#4CAF50
    style BREW fill:#FFC107
    style VAULT fill:#FFC107
    style WORKSPACE fill:#FFC107
    style CLAUDE fill:#FFC107
    style TEMPLATE fill:#FFC107
```

**Key Design Principles:**
- **No hard dependencies** - Optional components gracefully degrade if missing
- **Enable later** - Started minimal? Run `blackdot setup` to add features
- **Progressive disclosure** - Setup wizard guides you through choices
- **Safe defaults** - Full install gives best experience, minimal still works

## Component Architecture

### CLI Entry Point

The unified `dotfiles` command provides a single entry point for all operations:

```mermaid
graph LR
    A[dotfiles] --> B{Command}
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
        A[install.sh] --> B[bootstrap-*.sh]
        B --> C[Create Symlinks]
        B --> D[Install Dependencies]
    end

    subgraph "Secret Management"
        E[Bitwarden Vault] <-->|restore| F[Local Files]
        F <-->|sync| E
    end

    subgraph "Runtime"
        G[Shell Start] --> H[Load .zshrc]
        H --> I[Load zsh.d/*.zsh]
        I --> J[Ready]
    end

    C --> H
```

## Directory Structure

```
dotfiles/
├── install.sh              # One-line installer
├── bootstrap/              # Platform bootstrap scripts
│   ├── bootstrap-mac.sh    # macOS setup
│   ├── bootstrap-linux.sh  # Linux/WSL setup
│   ├── bootstrap-blackdot.sh # Symlink setup
│   └── _common.sh          # Shared bootstrap functions
├── bin/                    # CLI tools
│   ├── blackdot-doctor     # Health checks
│   ├── blackdot-drift      # Vault comparison
│   ├── blackdot-features   # Feature registry management
│   ├── blackdot-hook       # Hook system management
│   ├── blackdot-sync       # Bidirectional vault sync
│   ├── blackdot-diff       # Preview changes
│   ├── blackdot-backup     # Backup/restore
│   ├── blackdot-setup      # Setup wizard
│   ├── blackdot-migrate    # Config migration orchestrator
│   ├── blackdot-migrate-config    # INI→JSON config migration
│   ├── blackdot-migrate-vault-schema # Legacy vault schema migration
│   ├── blackdot-uninstall  # Clean removal
│   └── blackdot-metrics    # Show metrics
│
├── zsh/
│   ├── .zshrc              # Main entry (symlinked)
│   ├── .p10k.zsh           # Powerlevel10k theme
│   ├── completions/        # Tab completions
│   │   └── _blackdot       # CLI completions
│   └── zsh.d/              # Modular config
│       ├── 00-init.zsh
│       ├── 10-environment.zsh
│       ├── 20-history.zsh
│       ├── 30-prompt.zsh
│       ├── 40-aliases.zsh  # blackdot command
│       ├── 50-functions.zsh
│       ├── 60-completions.zsh
│       ├── 70-plugins.zsh
│       ├── 80-tools.zsh
│       └── 90-local.zsh
│
├── lib/                    # Shared libraries
│   ├── _logging.sh         # Logging functions
│   ├── _config.sh          # JSON config abstraction
│   ├── _config_layers.sh   # Configuration Layers (5-layer priority)
│   ├── _cli_features.sh    # CLI Feature Awareness
│   ├── _features.sh        # Feature Registry (control plane)
│   ├── _hooks.sh           # Hook System (lifecycle hooks)
│   ├── _drift.sh           # Fast drift detection (shell startup)
│   ├── _state.sh           # Setup state management
│   ├── _vault.sh           # Vault abstraction layer
│   ├── _templates.sh       # Template engine
│   ├── _errors.sh          # Error handling
│   └── _paths.sh           # Path utilities
│
├── vault/
│   ├── _common.sh          # Config loader & validation
│   ├── vault-items.example.json # Example config template
│   ├── restore.sh          # Restore secrets
│   ├── sync-to-vault.sh
│   └── restore-*.sh        # Category restores
│
├── hooks/
│   └── examples/           # Example hook scripts
│       ├── post_vault_pull/
│       ├── doctor_check/
│       ├── shell_init/
│       └── directory_change/
│
├── macos/
│   └── settings.sh         # macOS defaults
│
├── claude/
│   └── commands/           # Slash commands
│
└── docs/                   # Documentation site
```

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
| `40-aliases.zsh` | Shell aliases, `dotfiles` command |
| `50-functions.zsh` | Shell functions, `status` |
| `60-completions.zsh` | Tab completion setup |
| `70-plugins.zsh` | ZSH plugins |
| `80-tools.zsh` | Tool integrations (nvm, etc.) |
| `90-local.zsh` | Machine-specific overrides |

## Vault System

The vault system provides bidirectional sync with multiple backends (Bitwarden, 1Password, pass).

### Configuration

Vault items are defined in a user-editable config file:

```
~/.config/dotfiles/vault-items.json    # Vault schema (single secrets[] array)
~/.config/dotfiles/config.json         # Config (vault backend, state, paths)
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
- ✅ Valid JSON syntax
- ✅ Required fields (path, required, type)
- ✅ Valid type values ("file" or "sshkey")
- ✅ Naming conventions (capital letter start)
- ✅ Path format (~, /, or $ prefix)

**Interactive error recovery:**
If validation fails during setup, offers to open editor for immediate fixes with automatic re-validation after save.

### Data Flow

```mermaid
sequenceDiagram
    participant User
    participant CLI as blackdot CLI
    participant Config as ~/.config/dotfiles
    participant Local as Local Files
    participant BW as Bitwarden

    User->>CLI: blackdot vault setup
    CLI->>Config: Create vault-items.json
    CLI->>Config: Set backend (bitwarden/1password/pass)

    User->>CLI: blackdot vault pull
    CLI->>BW: Fetch secrets
    BW-->>CLI: Return encrypted data
    CLI->>Local: Write files (600 perms)

    User->>CLI: blackdot vault push
    CLI->>Local: Read files
    CLI->>BW: Update vault items
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

The hook system (`lib/_hooks.sh`) allows custom behavior at lifecycle events without modifying core scripts.

### Hook Points

| Category | Hook Points |
|----------|-------------|
| **Lifecycle** | `pre_install`, `post_install`, `pre_bootstrap`, `post_bootstrap`, `pre_upgrade`, `post_upgrade` |
| **Vault** | `pre_vault_pull`, `post_vault_pull`, `pre_vault_push`, `post_vault_push` |
| **Doctor** | `pre_doctor`, `post_doctor`, `doctor_check` |
| **Shell** | `shell_init`, `shell_exit`, `directory_change` |
| **Setup** | `pre_setup_phase`, `post_setup_phase`, `setup_complete` |

### Registration Methods

1. **File-based** - Scripts in `~/.config/dotfiles/hooks/<hook_point>/`
2. **JSON config** - Hooks defined in `~/.config/dotfiles/hooks.json`
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

State is saved to `~/.config/dotfiles/config.json`:
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
