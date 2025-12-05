# State Management

The `dotfiles setup` wizard uses a persistent state system to track progress, save preferences, and enable resume capability.

> **v3.0 Update:** State management now uses JSON configuration format. Run `dotfiles migrate` to upgrade from v2.x INI files.

---

## Overview

State management provides:

- **Progress Tracking** - Remember which setup phases are complete
- **Resume Support** - Continue where you left off if interrupted
- **Preference Persistence** - Save choices like vault backend across sessions
- **State Inference** - Auto-detect existing installations from filesystem

---

## Configuration File

All state and configuration is stored in a single JSON file:

**`~/.config/dotfiles/config.json`**

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
    "config_dir": "~/.config/dotfiles",
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
- `paths.config_dir` - Configuration directory (default: `~/.config/dotfiles`)
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
dotfiles features enable vault --persist

# Disable a feature and persist
dotfiles features disable drift_check --persist

# Apply a preset and persist all features
dotfiles features preset developer --persist
```

**Priority order for feature state:**
1. Runtime state (current shell session)
2. Environment variables (`DOTFILES_FEATURE_<NAME>` or `SKIP_*`)
3. Config file (`features.*` in config.json)
4. Registry defaults (lib/_features.sh)

### Migrating from v2.x

If you're upgrading from v2.x (INI files):

```bash
dotfiles migrate              # Interactive migration
dotfiles migrate --yes        # Skip confirmation

# Old files (v2.x):
~/.config/dotfiles/state.ini
~/.config/dotfiles/config.ini

# New file (v3.0):
~/.config/dotfiles/config.json

# Backup location:
~/.config/dotfiles/backups/pre-v3-migration-YYYYMMDD_HHMMSS/
```

---

## Commands

### Check Setup Status

```bash
dotfiles setup --status
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
dotfiles setup --reset
```

Clears all state and re-runs setup from the beginning. Useful when:
- Switching to a different vault backend
- Troubleshooting setup issues
- Starting fresh after major changes

### Resume Setup

```bash
dotfiles setup
```

If interrupted, simply run `dotfiles setup` again. It automatically:
1. Reads existing state from `config.json`
2. Skips completed phases
3. Continues from where you left off

---

## State Inference

When state files don't exist (fresh install or after reset), `dotfiles setup` infers state from the filesystem:

| Phase | Detection Method |
|-------|------------------|
| Workspace | Checks if `/workspace` symlink exists |
| Symlinks | Checks if `~/.zshrc` is a symlink pointing to dotfiles |
| Packages | Checks if Homebrew (`brew`) is installed |
| Vault | Checks for vault CLI (`bw`/`op`/`pass`) and valid session |
| Secrets | Checks for `~/.ssh/config`, `~/.gitconfig`, `~/.aws/config` |
| Claude | Checks if `claude` CLI is in PATH |

This means you can run `dotfiles setup` on an existing installation and it will recognize what's already configured.

---

## Library Functions

The state system is implemented in `lib/_state.sh` (uses `lib/_config.sh` as backend):

### Phase State Functions

```bash
# Initialize state (creates config.json if needed)
state_init

# Check if a phase is completed
if state_completed "symlinks"; then
    echo "Symlinks already configured"
fi

# Mark a phase as complete (adds to setup.completed[] array)
state_complete "packages"

# Mark a phase as incomplete (removes from array)
state_reset "vault"

# Check if setup is needed (any incomplete phases)
if state_needs_setup; then
    echo "Run: dotfiles setup"
fi

# Get next incomplete phase
next_phase=$(state_next_phase)

# Infer state from filesystem
state_infer
```

### Config Functions

Direct JSON config access via `lib/_config.sh`:

```bash
# Get a config value (supports nested keys)
backend=$(config_get "vault.backend")
tier=$(config_get "packages.tier" "enhanced")

# Set a config value
config_set "vault.backend" "1password"
config_set "backup.retention_days" "60"

# Boolean values (use config_get_bool for conditionals)
config_set_bool "vault.auto_sync" true
if config_get_bool "backup.enabled"; then
    echo "Backups are enabled"
fi

# Note: config_get returns "true" or "false" as strings for booleans
compress=$(config_get "backup.compress" "true")
[[ "$compress" == "true" ]] && echo "Compression enabled"

# Array operations
config_array_add "setup.completed" "symlinks"
config_array_remove "setup.completed" "vault"
config_get_array "setup.completed"  # Returns: symlinks\npackages\nsecrets

# Validation and display
config_validate                     # Validate JSON syntax and version
config_show                         # Pretty-print entire config
config_backup                       # Create timestamped backup
```

**Legacy API Compatibility:**
```bash
# v2.x API still works (delegates to v3.0 backend)
backend=$(config_get "vault" "backend")      # Converts to vault.backend
config_set "vault" "backend" "bitwarden"    # Converts to vault.backend
```

---

## Integration with Vault

The vault backend preference is persisted in `config.json`:

```bash
# Priority order for vault backend:
# 1. Config file (~/.config/dotfiles/config.json → vault.backend)
# 2. Environment variable (DOTFILES_VAULT_BACKEND)
# 3. Default (bitwarden)
```

When you select a vault during `dotfiles setup`, it's saved to the config file. This means:
- No need to export `DOTFILES_VAULT_BACKEND` in your shell
- Preference persists across shell restarts
- Works automatically with all `dotfiles vault` commands

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
ls -la ~/.config/dotfiles/
# Should show: drwx------ (700) for directory
# config.json should be: -rw------- (600)
```

Fix permissions:

```bash
chmod 700 ~/.config/dotfiles
chmod 600 ~/.config/dotfiles/config.json
```

### Wrong Vault Backend

Check current config:

```bash
cat ~/.config/dotfiles/config.json
# Or pretty-print:
jq '.' ~/.config/dotfiles/config.json
```

Change vault backend:

```bash
# Edit with jq
jq '.vault.backend = "1password"' ~/.config/dotfiles/config.json > /tmp/config.json && \
    mv /tmp/config.json ~/.config/dotfiles/config.json

# Or reset and re-run setup
dotfiles setup --reset
```

### Invalid JSON

If config.json gets corrupted:

```bash
# Validate JSON
jq empty ~/.config/dotfiles/config.json

# If invalid, restore from backup
ls ~/.config/dotfiles/backups/
cp ~/.config/dotfiles/backups/config-YYYYMMDD_HHMMSS.json ~/.config/dotfiles/config.json

# Or reset to defaults
rm ~/.config/dotfiles/config.json
dotfiles setup  # Will create new config
```

### State Out of Sync

If state doesn't match reality:

```bash
# Option 1: Let inference fix it
jq '.setup.completed = []' ~/.config/dotfiles/config.json > /tmp/config.json && \
    mv /tmp/config.json ~/.config/dotfiles/config.json
dotfiles setup  # Will infer from filesystem

# Option 2: Full reset
dotfiles setup --reset
```

### Manual State Editing

You can edit config.json directly with jq:

```bash
# Mark a phase as incomplete (remove from array)
jq '.setup.completed = (.setup.completed | map(select(. != "packages")))' \
    ~/.config/dotfiles/config.json > /tmp/config.json && \
    mv /tmp/config.json ~/.config/dotfiles/config.json

# Or edit manually with vim (be careful with JSON syntax!)
vim ~/.config/dotfiles/config.json
```

---

## See Also

- [Setup Wizard](cli-reference.md#dotfiles-setup) - Full setup command reference
- [Feature Registry](features.md) - Enable/disable optional features
- [Vault System](vault-README.md) - Multi-backend secret management
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
