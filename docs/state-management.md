# State Management

The `blackdot setup` wizard uses a persistent state system to track progress, save preferences, and enable resume capability. State management is a foundation component that works with the [Configuration Layers](architecture.md#configuration-layers) system.

---

## Overview

State management provides:

- **Progress Tracking** - Remember which setup phases are complete
- **Resume Support** - Continue where you left off if interrupted
- **Preference Persistence** - Save choices like vault backend across sessions
- **State Inference** - Auto-detect existing installations from filesystem
- **Feature Persistence** - Store enabled/disabled features for the [Feature Registry](features.md)

---

## Configuration File

All state and configuration is stored in a single JSON file:

**`~/.config/blackdot/config.json`**

```json
{
  "version": 3,
  "vault": {
    "backend": "bitwarden",
    "auto_sync": false,
    "auto_backup": true
  },
  "backup": {
    "enabled": true,
    "auto_backup": true,
    "retention_days": 30,
    "max_snapshots": 10,
    "compress": true,
    "location": "~/.local/share/dotfiles/backups"
  },
  "setup": {
    "completed": ["symlinks", "packages", "vault", "secrets"],
    "current_tier": "enhanced"
  },
  "packages": {
    "tier": "enhanced",
    "auto_update": false,
    "parallel_install": false
  },
  "paths": {
    "dotfiles_dir": "~/workspace/dotfiles",
    "config_dir": "~/.config/blackdot",
    "backup_dir": "~/.local/share/dotfiles/backups"
  },
  "features": {
    "vault": true,
    "claude_integration": true,
    "workspace_symlink": true
  }
}
```

### Setup State (`setup.completed[]`)

The `setup.completed` array tracks which setup phases have been completed:

**Phases:**

| Phase | Description | What It Does |
|-------|-------------|--------------|
| `workspace` | Workspace directory | Configures workspace directory and /workspace symlink |
| `symlinks` | Shell configuration | Links `.zshrc`, `.p10k.zsh` to home directory |
| `packages` | Homebrew packages | Installs packages from Brewfile |
| `vault` | Vault backend | Selects and authenticates vault (Bitwarden/1Password/pass) |
| `secrets` | Secret restoration | Restores SSH keys, AWS creds, Git config from vault |
| `claude` | Claude Code | Optionally installs dotclaude for profile management |
| `template` | Templates | Machine-specific config templates setup |

### Configuration Settings

All settings are now stored in the same `config.json` file:

**Vault Settings (`vault.*`):**
- `vault.backend` - `bitwarden`, `1password`, `pass`, or empty
- `vault.auto_sync` - Auto-sync changes to vault (default: `false`)
- `vault.auto_backup` - Auto-backup before operations (default: `true`)

**Backup Settings (`backup.*`):**
- `backup.enabled` - Enable backup system (default: `true`)
- `backup.auto_backup` - Auto-backup before destructive operations (default: `true`)
- `backup.retention_days` - Keep backups for N days (default: `30`)
- `backup.max_snapshots` - Maximum number of backups (default: `10`)
- `backup.compress` - Use gzip compression (default: `true`)
- `backup.location` - Backup directory path

**Paths (`paths.*`):**
- `paths.dotfiles_dir` - Custom dotfiles installation directory
- `paths.config_dir` - Configuration directory (default: `~/.config/blackdot`)
- `paths.backup_dir` - Backup storage location

**Feature State (`features.*`):**

The feature registry persists enabled/disabled features in the config file:

- `features.vault` - Multi-vault secret management
- `features.workspace_symlink` - /workspace symlink for portable sessions
- `features.claude_integration` - Claude Code integration and hooks
- `features.templates` - Machine-specific config templates
- And more... (see [Feature Registry](features.md))

```bash
# Enable a feature and persist to config
blackdot features enable vault --persist

# Disable a feature and persist
blackdot features disable drift_check --persist

# Apply a preset and persist all features
blackdot features preset developer --persist
```

**Priority order for feature state:**
1. Runtime state (current shell session)
2. Environment variables (`BLACKDOT_FEATURE_<NAME>` or `SKIP_*`)
3. Config file (`features.*` in config.json)
4. Feature presets in Go CLI

---

## Commands

### Check Setup Status

```bash
blackdot setup --status
```

Shows current setup progress with visual checkmarks:

```
Setup Status
============
[✓] Workspace   - /workspace → ~/workspace
[✓] Symlinks    - Shell configuration linked
[✓] Packages    - Homebrew packages installed
[✓] Vault       - Backend: bitwarden
[✓] Secrets     - SSH keys, AWS, Git restored
[ ] Claude      - Not configured
[ ] Templates   - Not configured
```

### Reset State

```bash
blackdot setup --reset
```

Clears all state and re-runs setup from the beginning. Useful when:
- Switching to a different vault backend
- Troubleshooting setup issues
- Starting fresh after major changes

### Resume Setup

```bash
blackdot setup
```

If interrupted, simply run `blackdot setup` again. It automatically:
1. Reads existing state from `config.json`
2. Skips completed phases
3. Continues from where you left off

---

## State Inference

When state files don't exist (fresh install or after reset), `blackdot setup` infers state from the filesystem:

| Phase | Detection Method |
|-------|------------------|
| Workspace | Checks if `/workspace` symlink exists |
| Symlinks | Checks if `~/.zshrc` is a symlink pointing to dotfiles |
| Packages | Checks if Homebrew (`brew`) is installed |
| Vault | Checks for vault CLI (`bw`/`op`/`pass`) and valid session |
| Secrets | Checks for `~/.ssh/config`, `~/.gitconfig`, `~/.aws/config` |
| Claude | Checks if `claude` CLI is in PATH |

This means you can run `blackdot setup` on an existing installation and it will recognize what's already configured.

---

## Configuration Access

State and configuration are managed by the Go CLI (`blackdot`). The CLI reads and writes `~/.config/blackdot/config.json` directly.

### CLI Commands

```bash
# View current configuration
blackdot config show

# Get a specific value
blackdot config get vault.backend
blackdot config get backup.retention_days

# Set values
blackdot config set vault.backend 1password
blackdot config set backup.retention_days 60
```

### Direct JSON Access

You can also edit `config.json` directly with `jq`:

```bash
# Get a value
jq '.vault.backend' ~/.config/blackdot/config.json

# Set a value
jq '.vault.backend = "1password"' ~/.config/blackdot/config.json > /tmp/config.json && \
    mv /tmp/config.json ~/.config/blackdot/config.json

# Add to array
jq '.setup.completed += ["symlinks"]' ~/.config/blackdot/config.json > /tmp/config.json && \
    mv /tmp/config.json ~/.config/blackdot/config.json
```

---

## Integration with Vault

The vault backend preference is persisted in `config.json`:

```bash
# Priority order for vault backend:
# 1. Config file (~/.config/blackdot/config.json → vault.backend)
# 2. Environment variable (BLACKDOT_VAULT_BACKEND)
# 3. Default (bitwarden)
```

When you select a vault during `blackdot setup`, it's saved to the config file. This means:
- No need to export `BLACKDOT_VAULT_BACKEND` in your shell
- Preference persists across shell restarts
- Works automatically with all `blackdot vault` commands

---

## File Format

Configuration uses JSON format for flexibility and nested structure support:

```json
{
  "version": 3,
  "vault": { "backend": "bitwarden" },
  "setup": { "completed": ["symlinks", "packages"] }
}
```

**Why JSON?**
- Nested structures (e.g., `vault.backend`, `backup.retention_days`)
- Array support (e.g., `setup.completed[]`)
- Native jq support (jq already required dependency)
- Consistent with `vault-items.json` format
- Enables complex configurations (per-install paths, feature flags)
- Still human-readable and hand-editable

**Dependencies:**
- `jq` - JSON processor (already in Brewfile, required for vault operations)

---

## Troubleshooting

### State Not Persisting

Check file permissions:

```bash
ls -la ~/.config/blackdot/
# Should show: drwx------ (700) for directory
# config.json should be: -rw------- (600)
```

Fix permissions:

```bash
chmod 700 ~/.config/blackdot
chmod 600 ~/.config/blackdot/config.json
```

### Wrong Vault Backend

Check current config:

```bash
cat ~/.config/blackdot/config.json
# Or pretty-print:
jq '.' ~/.config/blackdot/config.json
```

Change vault backend:

```bash
# Edit with jq
jq '.vault.backend = "1password"' ~/.config/blackdot/config.json > /tmp/config.json && \
    mv /tmp/config.json ~/.config/blackdot/config.json

# Or reset and re-run setup
blackdot setup --reset
```

### Invalid JSON

If config.json gets corrupted:

```bash
# Validate JSON
jq empty ~/.config/blackdot/config.json

# If invalid, restore from backup
ls ~/.config/blackdot/backups/
cp ~/.config/blackdot/backups/config-YYYYMMDD_HHMMSS.json ~/.config/blackdot/config.json

# Or reset to defaults
rm ~/.config/blackdot/config.json
blackdot setup  # Will create new config
```

### State Out of Sync

If state doesn't match reality:

```bash
# Option 1: Let inference fix it
jq '.setup.completed = []' ~/.config/blackdot/config.json > /tmp/config.json && \
    mv /tmp/config.json ~/.config/blackdot/config.json
blackdot setup  # Will infer from filesystem

# Option 2: Full reset
blackdot setup --reset
```

### Manual State Editing

You can edit config.json directly with jq:

```bash
# Mark a phase as incomplete (remove from array)
jq '.setup.completed = (.setup.completed | map(select(. != "packages")))' \
    ~/.config/blackdot/config.json > /tmp/config.json && \
    mv /tmp/config.json ~/.config/blackdot/config.json

# Or edit manually with vim (be careful with JSON syntax!)
vim ~/.config/blackdot/config.json
```

---

## See Also

- [Setup Wizard](cli-reference.md#dotfiles-setup) - Full setup command reference
- [Feature Registry](features.md) - Enable/disable optional features
- [Vault System](vault-README.md) - Multi-backend secret management
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
