# Configuration Layers

The configuration layers system provides hierarchical config resolution, allowing settings to be overridden at different levels—from project-specific to machine-specific to user defaults—without modifying core files.

---

## Quick Start

```bash
# Initialize machine-specific config
dotfiles config init machine my-laptop

# Set a machine-specific value
dotfiles config set machine vault.backend 1password

# View where a setting comes from
dotfiles config show vault.backend

# See merged config from all layers
dotfiles config merged
```

---

## Overview

### Layer Hierarchy

Settings resolve from highest to lowest priority:

```
Priority (highest → lowest)
─────────────────────────────────────────────────────────
 1. Session     Environment variables (DOTFILES_*)
 2. Project     .dotfiles.json in project root
 3. Machine     ~/.config/dotfiles/machine.json
 4. User        ~/.config/dotfiles/config.json
 5. Defaults    Built-in defaults
─────────────────────────────────────────────────────────
```

### File Locations

| Layer | Location | Git Tracked | Purpose |
|-------|----------|-------------|---------|
| Session | Environment | N/A | Temporary overrides |
| Project | `.dotfiles.json` (project root) | Yes | Project-specific settings |
| Machine | `~/.config/dotfiles/machine.json` | No | Machine-specific settings |
| User | `~/.config/dotfiles/config.json` | No | User preferences |
| Defaults | `lib/_config.sh` | Yes | Built-in defaults |

---

## Commands

### `dotfiles config get <key> [default]`

Get a configuration value with layered resolution.

```bash
dotfiles config get vault.backend
# Output: bitwarden

dotfiles config get shell.theme "default"
# Output: default (if not set)
```

### `dotfiles config set <layer> <key> <value>`

Set a configuration value in a specific layer.

```bash
# Set in user config
dotfiles config set user vault.backend bitwarden

# Set in machine config
dotfiles config set machine vault.backend 1password

# Set in project config (current directory)
dotfiles config set project features.vault false
```

### `dotfiles config show <key>`

Show the value from all layers to understand where settings come from.

```bash
dotfiles config show vault.backend
```

Output:
```
Configuration layers for: vault.backend

  env:        (not set)
  project:    (not set)
  machine:    1password
  user:       bitwarden

  resolved:   1password
```

### `dotfiles config list`

Show all layer locations and their status.

```bash
dotfiles config list
```

Output:
```
Configuration Layers
═══════════════════════════════════════════════════════════════

Layer Locations:
───────────────────────────────────────────────────────────────
  env:         DOTFILES_* environment variables
  project:     .dotfiles.json (not found in current directory)
  machine:     ~/.config/dotfiles/machine.json ✓
  user:        ~/.config/dotfiles/config.json ✓

Priority: env > project > machine > user > default
```

### `dotfiles config merged`

Show the merged configuration from all layers.

```bash
dotfiles config merged
```

### `dotfiles config init <layer> [id]`

Initialize a configuration layer.

```bash
# Initialize machine config
dotfiles config init machine work-macbook

# Initialize project config in current directory
dotfiles config init project
```

### `dotfiles config edit [layer]`

Open a config file in your editor.

```bash
# Edit user config (default)
dotfiles config edit

# Edit machine config
dotfiles config edit machine

# Edit project config
dotfiles config edit project
```

---

## Configuration Examples

### Machine Config (`machine.json`)

Machine-specific settings that don't travel between computers:

```json
{
  "version": 1,
  "machine_id": "work-macbook-2024",

  "vault": {
    "backend": "1password"
  },

  "paths": {
    "workspace": "~/Code",
    "dotfiles_dir": "~/Code/dotfiles"
  },

  "features": {
    "claude_integration": false
  },

  "packages": {
    "tier": "full",
    "extras": ["docker", "kubernetes-cli"]
  },

  "shell": {
    "theme": "work",
    "prompt_context": "work"
  }
}
```

### Project Config (`.dotfiles.json`)

Project-specific settings that travel with the repository:

```json
{
  "version": 1,

  "features": {
    "vault": false,
    "templates": true
  },

  "shell": {
    "auto_activate_venv": true,
    "node_version_file": ".nvmrc"
  },

  "hooks": {
    "directory_change": [
      { "command": "source .env", "if_exists": ".env" }
    ]
  },

  "aliases": {
    "dev": "npm run dev",
    "test": "npm test"
  }
}
```

### User Config (`config.json`)

Default preferences for all machines:

```json
{
  "version": 3,
  "vault": {
    "backend": "bitwarden",
    "auto_sync": false
  },
  "features": {
    "vault": true,
    "workspace_symlink": true
  },
  "setup": {
    "completed": ["symlinks", "packages"]
  }
}
```

---

## Use Cases

### Work vs Personal Machine

Configure different vault backends for different machines:

```bash
# On work laptop
dotfiles config init machine work-macbook
dotfiles config set machine vault.backend 1password
dotfiles config set machine features.claude_integration false

# On personal desktop
dotfiles config init machine home-desktop
dotfiles config set machine vault.backend bitwarden
dotfiles config set machine packages.tier full
```

### Project-Specific Settings

Set up auto-activation and aliases for a specific project:

```bash
cd ~/projects/webapp
dotfiles config init project

# The .dotfiles.json file is created
# Edit to add project-specific aliases and settings
```

### Temporary Override

Override settings for the current session only:

```bash
# Override vault backend for this session
export DOTFILES_VAULT_BACKEND=pass
dotfiles vault pull  # Uses pass instead of configured backend

# Override feature for testing
export DOTFILES_FEATURES_VAULT=false
dotfiles doctor
```

### CI/CD Environments

Use environment variables to configure behavior in CI:

```bash
# In CI pipeline
export DOTFILES_VAULT_BACKEND=none
export DOTFILES_FEATURES_TEMPLATES=false
./install.sh
```

---

## Environment Variable Override

Any configuration key can be overridden via environment variable:

| Config Key | Environment Variable |
|------------|---------------------|
| `vault.backend` | `DOTFILES_VAULT_BACKEND` |
| `features.vault` | `DOTFILES_FEATURES_VAULT` |
| `shell.theme` | `DOTFILES_SHELL_THEME` |
| `packages.tier` | `DOTFILES_PACKAGES_TIER` |

Pattern: `config.key.name` → `DOTFILES_CONFIG_KEY_NAME`

---

## State vs Configuration

The dotfiles system distinguishes between **state** (what happened) and **configuration** (what should happen):

| Data Type | Example | Layer-Aware | Why |
|-----------|---------|-------------|-----|
| Setup state | `setup.completed[]` | No | Machine reality doesn't vary |
| Preferences | `vault.backend` | Yes | Can differ by machine |
| Feature state | `features.vault` | Yes | Can be overridden per-project |

**State management** (`lib/_state.sh`) always uses direct access to track what has happened on this specific machine. Configuration layers handle preferences that can vary.

---

## Integration with Features

The [Feature Registry](features.md) uses configuration layers to resolve feature state:

```bash
# Default: claude_integration disabled
# User config: features.claude_integration = true
# Machine config: features.claude_integration = false (work laptop)
# Result: claude_integration is DISABLED on this machine

dotfiles features status claude_integration
# Shows: disabled (via machine config)
```

---

## Best Practices

### What Goes Where

| Setting Type | Recommended Layer | Reason |
|--------------|------------------|--------|
| Default preferences | User | Applies everywhere |
| Work-specific settings | Machine | Stays on work machine |
| Project dependencies | Project | Travels with code |
| Temporary testing | Environment | Session-only |

### Security

- **Project configs are git-tracked** – Don't put secrets in `.dotfiles.json`
- **Machine configs are local** – Safe for machine-specific settings
- **Environment vars are transient** – Good for CI/CD overrides
- **Secrets** – Use the [Vault System](vault-README.md) for secrets

### Debugging

When a setting isn't what you expect:

```bash
# See all layers for a setting
dotfiles config show vault.backend

# Check environment
env | grep DOTFILES_

# See merged result
dotfiles config merged | jq '.vault'
```

---

## Troubleshooting

### Setting Not Taking Effect

```bash
# Check layer resolution
dotfiles config show <key>

# A higher-priority layer may be overriding
```

### Project Config Not Found

```bash
# Project config must be named .dotfiles.json
# Must be in current directory or parent

ls -la .dotfiles.json
```

### Machine Config Not Initialized

```bash
# Initialize machine config first
dotfiles config init machine $(hostname -s)
```

---

## Related Documentation

- [Feature Registry](features.md) - Feature enable/disable system
- [State Management](state-management.md) - Setup wizard state tracking
- [CLI Reference](cli-reference.md) - All dotfiles commands
- [Design Document](design/IMPL-configuration-layers.md) - Technical implementation details

