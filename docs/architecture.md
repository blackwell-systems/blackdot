# Architecture

This page describes the high-level architecture and component interactions of the dotfiles system.

## System Overview

```mermaid
graph TB
    subgraph "User Machine"
        CLI[dotfiles CLI]
        ZSH[ZSH Shell]
        SYMLINKS[Symlinked Configs]
    end

    subgraph "Dotfiles Repository"
        BOOTSTRAP[Bootstrap Scripts]
        VAULT[Vault Scripts]
        DOCTOR[Health Checks]
        ZSHD[ZSH Modules]
    end

    subgraph "External Services"
        BW[Bitwarden Vault]
        GH[GitHub]
    end

    CLI --> DOCTOR
    CLI --> VAULT
    CLI --> BOOTSTRAP
    ZSH --> ZSHD
    SYMLINKS --> ZSHD

    VAULT <--> BW
    BOOTSTRAP --> SYMLINKS
    GH --> BOOTSTRAP
```

## Component Architecture

### CLI Entry Point

The unified `dotfiles` command provides a single entry point for all operations:

```mermaid
graph LR
    A[dotfiles] --> B{Command}
    B --> C[status]
    B --> D[doctor]
    B --> E[vault]
    B --> F[backup]
    B --> G[diff]
    B --> H[setup]
    B --> I[upgrade]
    B --> J[uninstall]
    B --> K[macos]

    E --> E1[restore]
    E --> E2[sync]
    E --> E3[list]
    E --> E4[check]
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
│   ├── bootstrap-dotfiles.sh # Symlink setup
│   └── _common.sh          # Shared bootstrap functions
├── bin/                    # CLI tools
│   ├── dotfiles-doctor     # Health checks
│   ├── dotfiles-drift      # Vault comparison
│   ├── dotfiles-diff       # Preview changes
│   ├── dotfiles-backup     # Backup/restore
│   ├── dotfiles-setup      # Setup wizard
│   ├── dotfiles-uninstall  # Clean removal
│   └── dotfiles-metrics    # Show metrics
│
├── zsh/
│   ├── .zshrc              # Main entry (symlinked)
│   ├── .p10k.zsh           # Powerlevel10k theme
│   ├── completions/        # Tab completions
│   │   └── _dotfiles       # CLI completions
│   └── zsh.d/              # Modular config
│       ├── 00-init.zsh
│       ├── 10-environment.zsh
│       ├── 20-history.zsh
│       ├── 30-prompt.zsh
│       ├── 40-aliases.zsh  # dotfiles command
│       ├── 50-functions.zsh
│       ├── 60-completions.zsh
│       ├── 70-plugins.zsh
│       ├── 80-tools.zsh
│       └── 90-local.zsh
│
├── vault/
│   ├── _common.sh          # Shared definitions
│   ├── restore.sh          # Restore secrets
│   ├── sync-to-vault.sh
│   └── restore-*.sh        # Category restores
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

The vault system provides bidirectional sync with Bitwarden:

```mermaid
sequenceDiagram
    participant User
    participant CLI as dotfiles CLI
    participant Local as Local Files
    participant BW as Bitwarden

    User->>CLI: dotfiles vault restore
    CLI->>BW: Fetch secrets
    BW-->>CLI: Return encrypted data
    CLI->>Local: Write files (600 perms)

    User->>CLI: dotfiles vault sync
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
  "name": "dotfiles-item-name",
  "type": 2,
  "notes": "item content here",
  "fields": [
    {"name": "type", "value": "config"},
    {"name": "path", "value": "$HOME/.config/file"}
  ]
}
```

## Health Check System

The `dotfiles doctor` command validates system state:

```mermaid
flowchart TD
    A[dotfiles doctor] --> B{Check Type}
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
    A[dotfiles backup] --> B[Collect Files]
    B --> C[Create tar.gz]
    C --> D[~/.dotfiles-backups/]
    D --> E[Auto-cleanup > 10]

    F[dotfiles backup restore] --> G[List Backups]
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
| Bootstrap | Scripts | System | `dotfiles setup` |
| Restore | Bitwarden | Local | `dotfiles vault restore` |
| Sync | Local | Bitwarden | `dotfiles vault sync` |
| Backup | Config | Archive | `dotfiles backup` |
| Restore | Archive | Config | `dotfiles backup restore` |
| Upgrade | GitHub | Local | `dotfiles upgrade` |
| Remove | Local | (deleted) | `dotfiles uninstall` |
