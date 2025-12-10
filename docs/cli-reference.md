# CLI Reference

Complete reference for all blackdot commands, options, and environment variables.

---

## Quick Reference

```bash
blackdot status          # Visual dashboard
blackdot doctor          # Health check
blackdot doctor --fix    # Auto-fix issues
blackdot sync            # Smart bidirectional vault sync
blackdot vault pull      # Pull secrets from vault
blackdot vault push      # Push local changes to vault
blackdot template init   # Setup machine-specific configs
blackdot encrypt init    # Initialize age encryption
blackdot help            # Show all commands
```

---

## The `blackdot` Command

The unified command for managing your dotfiles. All subcommands are accessed via `blackdot <command>`.

### Command Overview

| Command | Alias | Description |
|---------|-------|-------------|
| `status` | `s` | Quick visual dashboard |
| `doctor` | `health` | Comprehensive health check |
| `features` | `feat` | **Feature Registry** - enable/disable optional features |
| `hook` | - | **Hook System** - manage lifecycle hooks |
| `config` | `cfg` | **Configuration Layers** - view layered config |
| `drift` | - | Compare local files vs vault |
| `sync` | - | Bidirectional vault sync (smart push/pull) |
| `diff` | - | Preview changes before sync/restore |
| `backup` | - | Backup and restore configuration |
| `vault` | - | Secret vault operations |
| `template` | `tmpl` | Machine-specific config templates |
| `encrypt` | - | **Age Encryption** - encrypt sensitive files |
| `lint` | - | Validate shell config syntax |
| `migrate` | - | Migrate legacy config formats (INI→JSON) |
| `packages` | `pkg` | Check/install Brewfile packages |
| `metrics` | - | Visualize health check metrics over time |
| `setup` | - | Interactive setup wizard |
| `macos` | - | macOS system settings (macOS only) |
| `upgrade` | `update` | Pull latest and run bootstrap |
| `uninstall` | - | Remove dotfiles configuration |
| `cd` | - | Change to dotfiles directory |
| `edit` | - | Open dotfiles in $EDITOR |
| `help` | `-h`, `--help` | Show help |

---

## Status & Health Commands

### `blackdot status`

Display a visual dashboard showing the current state of your dotfiles configuration.

```bash
blackdot status
blackdot s              # Alias
```

**Output includes:**
- Symlink status (zshrc, claude, /workspace)
- SSH agent status (keys loaded)
- AWS authentication status
- Lima VM status (macOS only)
- Suggested fixes for any issues

---

### `blackdot doctor`

Run a comprehensive health check on your dotfiles installation.

```bash
blackdot doctor [OPTIONS]
blackdot health         # Alias
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--fix` | `-f` | Auto-fix permission issues |
| `--quick` | `-q` | Run quick checks only (skip vault) |
| `--help` | `-h` | Show help |

**Examples:**

```bash
blackdot doctor              # Full health check
blackdot doctor --fix        # Auto-repair permissions
blackdot doctor --quick      # Fast checks (skip vault status)
```

**Checks performed:**
- Version and update status
- Symlinks (zshrc, p10k, claude, /workspace)
- Required commands (zsh, git, brew, jq)
- SSH keys and permissions (600 for private, 644 for public)
- AWS configuration and credentials
- Vault login status (unless `--quick`)
- Shell configuration
- Template system status

**Exit codes:**
- `0` - All checks passed
- `1` - One or more checks failed

---

## Feature Management

### `blackdot features`

Central registry for managing optional features. Enable, disable, and query the status of all optional dotfiles functionality.

```bash
blackdot features [COMMAND] [OPTIONS]
blackdot feat               # Alias
```

**Commands:**

| Command | Description |
|---------|-------------|
| `list` | List all features and their status (default) |
| `status [feature]` | Show status for one or all features |
| `enable <feature>` | Enable a feature |
| `disable <feature>` | Disable a feature |
| `preset <name>` | Enable a preset (group of features) |
| `check <feature>` | Check if feature is enabled (for scripts) |
| `help` | Show help |

**List Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--all` | `-a` | Show dependencies |
| `--json` | `-j` | Output as JSON |
| `--category` | `-c` | Filter by category (core, optional, integration) |

**Enable/Disable Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--persist` | `-p` | Save to config file (survives shell restart) |

**Preset Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--list` | `-l` | List available presets |
| `--persist` | `-p` | Save all preset features to config file |

**Available Presets:**

| Preset | Features |
|--------|----------|
| `minimal` | `shell` |
| `developer` | `shell`, `vault`, `aws_helpers`, `git_hooks`, `modern_cli` |
| `claude` | `shell`, `workspace_symlink`, `claude_integration`, `vault`, `git_hooks`, `modern_cli` |
| `full` | All features |

**Examples:**

```bash
# List all features with status
blackdot features
blackdot features list

# Filter by category
blackdot features list optional
blackdot features list integration

# Show with dependencies
blackdot features list --all

# JSON output (for scripting)
blackdot features list --json

# Enable a feature (runtime only)
blackdot features enable vault

# Enable and persist to config file
blackdot features enable vault --persist

# Disable a feature
blackdot features disable health_metrics

# Enable a preset
blackdot features preset developer --persist

# List available presets
blackdot features preset --list

# Check if feature enabled (for scripts)
if dotfiles features check vault; then
    blackdot vault pull
fi
```

**Feature Categories:**

| Category | Description |
|----------|-------------|
| `core` | Always enabled (shell) |
| `optional` | Optional features (vault, templates, etc.) |
| `integration` | Third-party tool integrations (nvm, sdkman, etc.) |

**Environment Variable Control:**

Features can also be controlled via environment variables:

```bash
# SKIP_* variables (backward compatible)
SKIP_WORKSPACE_SYMLINK=true    # Disables workspace_symlink
SKIP_CLAUDE_SETUP=true         # Disables claude_integration
BLACKDOT_SKIP_DRIFT_CHECK=1    # Disables drift_check

# Direct feature control
BLACKDOT_FEATURE_VAULT=true    # Enable vault
BLACKDOT_FEATURE_VAULT=false   # Disable vault
```

**See also:** [Feature Registry](features.md) for complete documentation.

---

## Hook Commands

### `blackdot hook`

Manage lifecycle hooks for custom behavior at key points.

```bash
blackdot hook [COMMAND] [OPTIONS] [HOOK_POINT]
```

**Commands:**

| Command | Description |
|---------|-------------|
| `list` | List all hook points or hooks for a specific point |
| `run` | Execute hooks for a hook point |
| `test` | Test hooks (shows what would run, then executes) |

**Options:**

| Option | Description |
|--------|-------------|
| `--verbose` | Show detailed execution output |
| `--no-hooks` | Skip hook execution (for debugging) |

**Examples:**

```bash
# List all hook points
blackdot hook list

# List hooks for a specific point
blackdot hook list post_vault_pull

# Run hooks for a point
blackdot hook run post_vault_pull

# Run with verbose output
blackdot hook run --verbose shell_init

# Test hooks (dry-run + execute)
blackdot hook test doctor_check
```

### Hook Points

| Category | Hook Points |
|----------|-------------|
| **Lifecycle** | `pre_install`, `post_install`, `pre_bootstrap`, `post_bootstrap`, `pre_upgrade`, `post_upgrade` |
| **Vault** | `pre_vault_pull`, `post_vault_pull`, `pre_vault_push`, `post_vault_push` |
| **Doctor** | `pre_doctor`, `post_doctor`, `doctor_check` |
| **Shell** | `shell_init`, `shell_exit`, `directory_change` |
| **Setup** | `pre_setup_phase`, `post_setup_phase`, `setup_complete` |

### Creating Hooks

**File-based hooks** (recommended):
```bash
# Create hook directory
mkdir -p ~/.config/blackdot/hooks/post_vault_pull

# Create executable script
cat > ~/.config/blackdot/hooks/post_vault_pull/10-fix-perms.sh << 'EOF'
#!/bin/bash
chmod 600 ~/.ssh/id_* 2>/dev/null
EOF
chmod +x ~/.config/blackdot/hooks/post_vault_pull/10-fix-perms.sh
```

**JSON-based hooks:**
```bash
# Configure in hooks.json
cat > ~/.config/blackdot/hooks.json << 'EOF'
{
  "hooks": {
    "post_vault_pull": [
      {"name": "ssh-add", "command": "ssh-add ~/.ssh/id_ed25519", "enabled": true, "fail_ok": true}
    ]
  }
}
EOF
```

**See also:** [Hook System](hooks.md) for complete documentation.

---

## Configuration Commands

### `blackdot config`

View and manage configuration across all layers.

```bash
blackdot config [COMMAND] [OPTIONS]
blackdot cfg                # Alias
```

**Commands:**

| Command | Description |
|---------|-------------|
| `layers` | Show effective config with source layer for each setting |
| `get <key>` | Get a specific config value |
| `set <key> <value>` | Set a config value in user layer |
| `help` | Show help |

**Examples:**

```bash
# Show all config with sources
blackdot config layers

# Output:
# vault.backend = bitwarden (user)
# vault.auto_sync = false (default)
# setup.completed = ["symlinks","packages"] (machine)

# Get specific value
blackdot config get vault.backend

# Set value in user config
blackdot config set vault.auto_backup true
```

**Layer Priority (highest to lowest):**

| Priority | Layer | Source |
|----------|-------|--------|
| 1 | Environment | `$BLACKDOT_*` variables |
| 2 | Project | `.blackdot.local` in current directory |
| 3 | Machine | `~/.config/blackdot/machine.json` |
| 4 | User | `~/.config/blackdot/config.json` |
| 5 | Defaults | Built-in fallbacks |

**See also:** [Architecture - Configuration Layers](architecture.md#configuration-layers)

---

### `blackdot drift`

Compare local configuration files against vault to detect differences.

```bash
blackdot drift [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--quick` | `-q` | Fast check against cached state (no vault access) |
| `--help` | `-h` | Show help |

**Modes:**

| Mode | Speed | Vault Access | Description |
|------|-------|--------------|-------------|
| Full (default) | ~2-5s | Required | Connects to vault, compares live vault content |
| Quick (`--quick`) | <50ms | Not required | Compares against cached checksums from last pull |

**Checks these items:**
- SSH-Config (`~/.ssh/config`)
- AWS-Config (`~/.aws/config`)
- AWS-Credentials (`~/.aws/credentials`)
- Git-Config (`~/.gitconfig`)
- Environment-Secrets (`~/.local/env.secrets`)
- Template-Variables (`~/.config/blackdot/template-variables.sh`)

**Output:**
- Shows which items are in sync
- Shows which items have local changes
- Suggests next steps (sync or restore)

**Examples:**

```bash
blackdot drift           # Full check (connects to vault)
blackdot drift --quick   # Fast check (local checksums only)
```

**Shell Startup Integration:**

Drift detection runs automatically on shell startup using quick mode. If local files have changed since your last `vault pull`, you'll see:

```
⚠ Drift detected: Git-Config Template-Variables
  Run: blackdot drift (to compare) or blackdot vault pull (to restore)
```

Disable with: `export BLACKDOT_SKIP_DRIFT_CHECK=1`

**How it works:**
1. After `blackdot vault pull`, checksums are saved to `~/.cache/dotfiles/vault-state.json`
2. On shell startup, local files are compared against cached checksums
3. If checksums differ, a warning is shown
4. Run full `blackdot drift` to compare against actual vault content

---

### `blackdot sync`

Bidirectional sync between local files and vault. Intelligently determines sync direction based on what changed.

```bash
blackdot sync [OPTIONS] [ITEMS...]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--dry-run` | `-n` | Show what would be synced without making changes |
| `--force-local` | `-l` | Push all local changes to vault (overwrite vault) |
| `--force-vault` | `-v` | Pull all vault content to local (overwrite local) |
| `--verbose` | - | Show detailed comparison info (checksums) |
| `--all` | `-a` | Sync all syncable items |
| `--help` | `-h` | Show help |

**Sync Behavior:**

By default, sync determines the correct direction for each item:

| Condition | Action |
|-----------|--------|
| Local changed since last sync | Push to vault |
| Vault changed since last sync | Pull from vault |
| Both changed | **Conflict** - requires `--force-*` flag |
| Neither changed | Skip (already in sync) |

**Conflict Resolution:**

When both local and vault have changed since last sync:

```bash
blackdot sync --force-local   # Push local changes, overwrite vault
blackdot sync --force-vault   # Pull vault changes, overwrite local
```

**Syncable Items:**
- `SSH-Config` (`~/.ssh/config`)
- `AWS-Config` (`~/.aws/config`)
- `AWS-Credentials` (`~/.aws/credentials`)
- `Git-Config` (`~/.gitconfig`)
- `Environment-Secrets` (`~/.local/env.secrets`)
- `Template-Variables` (`~/.config/blackdot/template-variables.sh`)
- `Claude-Profiles` (`~/.claude/profiles.json`)

**Examples:**

```bash
blackdot sync                     # Smart sync all items
blackdot sync --dry-run           # Preview what would be synced
blackdot sync Git-Config          # Sync single item
blackdot sync --force-local       # Push all local to vault
blackdot sync --force-vault       # Pull all vault to local
blackdot sync --verbose           # Show checksum details
```

**How it works:**
1. Loads cached checksums from `~/.cache/dotfiles/vault-state.json` (baseline from last sync)
2. Calculates current checksums for local files
3. Fetches vault content and calculates checksums
4. Compares each against baseline to determine which side changed
5. Performs push/pull operations based on detected changes
6. Updates drift state after successful sync

**Exit Codes:**
- `0` - All items synced successfully
- `1` - One or more items failed to sync
- `2` - Conflicts detected (use `--force-*` to resolve)

---

### `blackdot diff`

Preview differences between local files and vault before performing sync or restore operations.

```bash
blackdot diff [OPTIONS] [ITEM]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--sync` | `-s` | Preview what sync would push to vault |
| `--restore` | `-r` | Preview what restore would change locally |
| `--help` | `-h` | Show help |

**Arguments:**

| Argument | Description |
|----------|-------------|
| `ITEM` | Show diff for specific item (e.g., `SSH-Config`) |

**Examples:**

```bash
blackdot diff                 # Show all differences
blackdot diff --sync          # What would be pushed to vault
blackdot diff --restore       # What would be restored locally
blackdot diff SSH-Config      # Diff specific item
```

---

## Backup & Restore

### `blackdot backup`

Create timestamped backups of configuration files or restore from previous backups.

```bash
blackdot backup [COMMAND] [OPTIONS]
```

**Commands:**

| Command | Description |
|---------|-------------|
| (none) | Create new backup |
| `--list`, `-l`, `list` | List available backups |
| `restore [ID]` | Restore from backup (latest if no ID) |
| `--help`, `-h`, `help` | Show help |

**Examples:**

```bash
blackdot backup              # Create new backup
blackdot backup --list       # List available backups
blackdot backup restore      # Restore from latest backup
blackdot backup restore backup-20240115-143022  # Restore specific
```

**Files backed up:**
- `~/.ssh/config`
- `~/.ssh/known_hosts`
- `~/.gitconfig`
- `~/.aws/config`
- `~/.aws/credentials`
- `~/.local/env.secrets`
- `~/.zshrc`
- `~/.p10k.zsh`

**Storage:**
- Backups stored in `~/.blackdot-backups/`
- Maximum 10 backups retained (oldest auto-deleted)
- Each backup includes a manifest with metadata

---

### `blackdot migrate`

**Configuration Migration** - Migrate legacy configuration formats to JSON.

```bash
blackdot migrate [OPTIONS]
```

**What it migrates:**
- Config format: `config.ini` → `config.json`
- Vault schema: Legacy format → current `secrets[]` array format
- Preserves vault backend settings and setup state

**Options:**

| Option | Description |
|--------|-------------|
| `-y`, `--yes` | Skip confirmation prompt |
| `-h`, `--help` | Show help |

**Examples:**

```bash
blackdot migrate              # Interactive migration with confirmation
blackdot migrate --yes        # Skip confirmation, migrate immediately
```

**Safety:**
- Creates timestamped backups before migration
- Idempotent - safe to run multiple times
- Automatically detects if migration is needed

---

## Vault Commands

### `blackdot vault`

Manage secrets stored in your vault. Supports multiple backends with a unified interface.

```bash
blackdot vault <command> [OPTIONS]
```

**Subcommands:**

| Command | Description |
|---------|-------------|
| `init` | Configure vault backend with location support (v2 wizard) |
| `pull` | Pull secrets from vault to local machine |
| `push` | Push local files to vault |
| `sync` | Bidirectional sync (smart push/pull based on changes) |
| `setup` | Interactive onboarding wizard (three modes: Existing/Fresh/Manual) |
| `list` | List vault items (supports location filtering) |
| `check` | Validate vault items exist |
| `validate` | Validate vault item schema |
| `create` | Create new vault item |
| `delete` | Delete vault item(s) |
| `help` | Show help |

---

### vault create

Create a new Secure Note item in the vault.

```bash
blackdot vault create <item-name> [content] [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--dry-run` | `-n` | Preview without making changes |
| `--force` | `-f` | Overwrite if item already exists |
| `--file` | | Read content from file instead of argument |

**Content Sources (in order of precedence):**
1. Command line argument: `blackdot vault create Name "content"`
2. File: `blackdot vault create Name --file ~/path/to/file`
3. Stdin: `echo "content" | dotfiles vault create Name`

**Examples:**

```bash
# Create from argument
blackdot vault create API-Key "sk-1234567890"

# Create from file
blackdot vault create SSH-Config --file ~/.ssh/config

# Create from stdin
cat ~/.gitconfig | dotfiles vault create Git-Config

# Preview what would be created
blackdot vault create --dry-run Test-Item "preview content"

# Overwrite existing item
blackdot vault create --force API-Key "new-key"
```

---

### vault delete

Delete one or more items from the vault.

```bash
blackdot vault delete <item-name>... [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--dry-run` | `-n` | Preview without making changes |
| `--force` | `-f` | Skip confirmation prompts (except protected items) |

**Protected Items:**

These items require typing the item name to confirm deletion, even with `--force`:
- `SSH-*` - SSH keys and configs
- `AWS-*` - AWS credentials
- `Git-Config` - Git configuration
- `Environment-Secrets` - Environment variables

**Examples:**

```bash
# Delete single item (with confirmation)
blackdot vault delete OLD-API-KEY

# Delete multiple items with force
blackdot vault delete --force TEMP-1 TEMP-2 TEMP-3

# Preview what would be deleted
blackdot vault delete --dry-run OLD-KEY

# Protected item requires typing name even with force
blackdot vault delete SSH-Work
# Type "SSH-Work" to confirm
```

---

### Supported Backends

The vault system supports three backends with identical functionality:

| Backend | CLI Tool | Description |
|---------|----------|-------------|
| **Bitwarden** | `bw` | Default. Cloud-synced, full-featured |
| **1Password** | `op` | v2 CLI with biometric auth on macOS |
| **pass** | `pass` | GPG-based, git-synced, local-first |

#### Switching Backends

```bash
# Set backend in ~/.zshrc or ~/.zshenv
export BLACKDOT_VAULT_BACKEND=bitwarden  # (default)
export BLACKDOT_VAULT_BACKEND=1password
export BLACKDOT_VAULT_BACKEND=pass
```

All `blackdot vault` commands work identically regardless of backend.

#### Backend Setup

**Bitwarden (default):**
```bash
brew install bitwarden-cli
bw login
export BW_SESSION="$(bw unlock --raw)"
```

**1Password:**
```bash
brew install --cask 1password-cli
op signin
export BLACKDOT_VAULT_BACKEND=1password
export ONEPASSWORD_VAULT=Personal  # optional, default vault
```

**pass:**
```bash
brew install pass
pass init <gpg-key-id>
export BLACKDOT_VAULT_BACKEND=pass
export PASS_PREFIX=dotfiles  # optional, items stored as dotfiles/Git-Config
```

---

### Location Management

Vault items can be organized by location (folder, vault, directory) depending on your backend:

| Backend | Location Type | Example |
|---------|---------------|---------|
| **Bitwarden** | `folder` | Items in "dotfiles" folder |
| **1Password** | `vault` or `tag` | Items in "Personal" vault (planned) |
| **pass** | `directory` | Items in `dotfiles/` prefix directory |

**Configuration in `vault-items.json`:**
```json
{
  "vault_location": {
    "type": "folder",
    "value": "dotfiles"
  },
  "vault_items": { ... }
}
```

**Location types:**
- `folder` - Bitwarden folders
- `vault` - 1Password vaults (planned)
- `tag` - 1Password tags (planned)
- `directory` - pass directories/prefixes
- `prefix` - Name-based prefix filtering
- `none` - No location filtering (legacy behavior)

The setup wizard (`blackdot vault init`) guides you through selecting or creating a location.

---

### Configuration File

Vault items are defined in a user-editable JSON config:

```
~/.config/blackdot/vault-items.json
```

**Setup:**
```bash
# Copy example and customize
mkdir -p ~/.config/blackdot
cp vault/vault-items.example.json ~/.config/blackdot/vault-items.json
$EDITOR ~/.config/blackdot/vault-items.json

# Or use the setup wizard
blackdot setup
```

### Example Managed Items

Define your items in the config file. Example structure:

| Item Name | Local Path | Type |
|-----------|------------|------|
| `SSH-GitHub` | `~/.ssh/id_ed25519_github` | SSH key |
| `SSH-Work` | `~/.ssh/id_ed25519_work` | SSH key |
| `SSH-Config` | `~/.ssh/config` | Config file |
| `AWS-Config` | `~/.aws/config` | Config file |
| `AWS-Credentials` | `~/.aws/credentials` | Config file |
| `Git-Config` | `~/.gitconfig` | Config file |
| `Environment-Secrets` | `~/.local/env.secrets` | Config file (optional) |

---

### `blackdot vault pull`

Pull secrets from vault to local machine.

```bash
blackdot vault pull [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--force` | `-f` | Skip drift check, overwrite local changes |

**Behavior:**
1. Creates auto-backup of existing files
2. Checks for local drift (unless `--force`)
3. Syncs vault to get latest
4. Pulls SSH keys, AWS config, Git config, etc.
5. Sets correct file permissions

**Environment variables:**
- `BLACKDOT_SKIP_DRIFT_CHECK=1` - Skip drift check (for automation)

---

### `blackdot vault push`

Push local configuration files to vault.

```bash
blackdot vault push [OPTIONS] [ITEMS...]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--dry-run` | `-n` | Show what would be pushed without making changes |
| `--all` | `-a` | Push all items |
| `--help` | `-h` | Show help |

**Arguments:**

| Argument | Description |
|----------|-------------|
| `ITEMS` | Specific items to push (space-separated) |

**Pushable items:**
- `SSH-Config`
- `AWS-Config`
- `AWS-Credentials`
- `Git-Config`
- `Environment-Secrets`
- `Template-Variables`

**Examples:**

```bash
blackdot vault push --all            # Push all items
blackdot vault push --dry-run --all  # Preview changes
blackdot vault push SSH-Config       # Push single item
blackdot vault push Git-Config AWS-Config  # Push multiple
```

---

### `blackdot vault sync`

Bidirectional sync - intelligently determines whether to push or pull each item.

```bash
blackdot vault sync [OPTIONS] [ITEMS...]
```

Same as `blackdot sync`. See [dotfiles sync](#dotfiles-sync) for full documentation.

**Quick Examples:**

```bash
blackdot vault sync                  # Smart sync all items
blackdot vault sync --dry-run        # Preview changes
blackdot vault sync --force-local    # Force push local to vault
blackdot vault sync --force-vault    # Force pull vault to local
```

---

### `blackdot vault list`

List vault items managed by dotfiles.

```bash
blackdot vault list
```

---

### `blackdot vault check`

Validate that required vault items exist.

```bash
blackdot vault check
```

---

### `blackdot vault validate`

Validate vault item schema (structure, content format).

```bash
blackdot vault validate
```

**Validates:**
- SSH keys contain proper BEGIN/END markers
- Config files have minimum content length
- Items are correct type (secureNote)

---

## Template Commands

### `blackdot template`

Manage machine-specific configuration templates.

```bash
blackdot template <command> [OPTIONS]
blackdot tmpl <command>   # Alias
```

**Subcommands:**

| Command | Alias | Description |
|---------|-------|-------------|
| `init` | - | Interactive setup wizard |
| `render` | - | Render templates to generated/ |
| `check` | `validate` | Validate template syntax |
| `diff` | - | Show differences between templates and generated |
| `vars` | `variables` | List all template variables |
| `edit` | - | Open _variables.local.sh in editor |
| `link` | `symlink` | Create symlinks from generated files |
| `list` | `ls` | List available templates |
| `vault` | - | Sync template variables with vault |
| `help` | `-h`, `--help` | Show help |

---

### `blackdot template init`

Interactive setup wizard for the template system.

```bash
blackdot template init
```

**What it does:**
1. Detects system info (hostname, OS, architecture)
2. Creates `templates/_variables.local.sh`
3. Opens editor to customize variables

**Vault Integration:**
Template variables can be stored in your vault for portable restoration across machines:

```bash
# Store in vault (current machine)
blackdot vault push Template-Variables

# Restore from vault (new machine)
blackdot vault pull
blackdot template render --all
```

Variables are stored at `~/.config/blackdot/template-variables.sh` (XDG location).

---

### `blackdot template render`

Render templates to the `generated/` directory.

```bash
blackdot template render [OPTIONS] [FILE]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--dry-run` | `-n` | Show what would be done |
| `--force` | `-f` | Force re-render even if up to date |
| `--verbose` | `-v` | Show detailed output |

**Arguments:**

| Argument | Description |
|----------|-------------|
| `FILE` | Render specific template only |

**Examples:**

```bash
blackdot template render              # Render all templates
blackdot template render --dry-run    # Preview changes
blackdot template render gitconfig    # Render specific template
```

---

### `blackdot template vars`

List all template variables and their current values.

```bash
blackdot template vars [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--quiet` | `-q` | Minimal output (values only) |

---

### `blackdot template link`

Create symlinks from generated files to their destinations.

```bash
blackdot template link [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--dry-run` | `-n` | Show what would be linked |

**Link destinations:**
- `gitconfig` -> `~/.gitconfig`
- `99-local.zsh` -> `zsh/zsh.d/99-local.zsh`
- `ssh-config` -> `~/.ssh/config`
- `claude.local` -> `~/.claude.local`

---

### `blackdot template diff`

Show differences between templates and generated files.

```bash
blackdot template diff [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--verbose` | `-v` | Show detailed diff output |

---

### `blackdot template list`

List available templates and their status.

```bash
blackdot template list
blackdot template ls    # Alias
```

**Status indicators:**
- Up to date
- Stale (needs re-rendering)
- Not generated

---

### `blackdot template vault`

Sync template variables (`_variables.local.sh`) with your vault for cross-machine portability.

```bash
blackdot template vault <command> [OPTIONS]
```

**Subcommands:**

| Command | Description |
|---------|-------------|
| `push` | Push local variables to vault |
| `pull` | Pull from vault to local file |
| `diff` | Show differences between local and vault |
| `sync` | Bidirectional sync with conflict detection |
| `status` | Show sync status (default) |
| `help` | Show help |

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--force` | `-f` | Force overwrite without confirmation |
| `--prefer-local` | - | On sync conflict, use local file |
| `--prefer-vault` | - | On sync conflict, use vault item |
| `--no-backup` | - | Don't backup local file on pull |

**Examples:**

```bash
# Backup template variables to vault
blackdot template vault push

# Restore on new machine
blackdot template vault pull

# Check sync status
blackdot template vault status

# See differences
blackdot template vault diff

# Sync with conflict resolution
blackdot template vault sync --prefer-local
```

**Vault Item:** `Template-Variables`

Works with all vault backends (Bitwarden, 1Password, pass).

---

## Encryption Commands

### `blackdot encrypt`

Manage file encryption using the `age` tool. Encrypts sensitive files that aren't managed by vault (like template variables).

```bash
blackdot encrypt <command> [OPTIONS]
```

**Subcommands:**

| Command | Description |
|---------|-------------|
| `init` | Initialize encryption (generate age key pair) |
| `encrypt <file>` | Encrypt a file (creates `.age` file, removes original) |
| `decrypt <file>` | Decrypt a `.age` file |
| `edit <file>` | Decrypt, open in $EDITOR, re-encrypt on save |
| `list` | List encrypted and unencrypted sensitive files |
| `status` | Show encryption status and key info |
| `push-key` | Push private key to vault for backup/recovery |
| `help` | Show help |

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--keep` | `-k` | Keep original file when encrypting/decrypting |
| `--force` | `-f` | Force operation (e.g., regenerate keys) |
| `--dry-run` | `-n` | Show what would be done |

---

### `blackdot encrypt init`

Initialize age encryption by generating a new key pair.

```bash
blackdot encrypt init [--force]
```

**What it creates:**
- `~/.config/blackdot/age-key.txt` - Private key (mode 600)
- `~/.config/blackdot/age-recipients.txt` - Public key

**Example:**

```bash
blackdot encrypt init          # Generate new key pair
blackdot encrypt init --force  # Regenerate keys (WARNING: loses access to encrypted files)
```

---

### `blackdot encrypt <file>`

Encrypt a file using age.

```bash
blackdot encrypt <file> [--keep]
```

**Behavior:**
1. Encrypts file to `<file>.age`
2. Removes original file (unless `--keep`)
3. The `.age` file can be committed to git

**Examples:**

```bash
# Encrypt template variables
blackdot encrypt templates/_variables.local.sh

# Keep original file
blackdot encrypt templates/_arrays.local.json --keep

# Preview
blackdot encrypt templates/_variables.local.sh --dry-run
```

---

### `blackdot encrypt decrypt <file>`

Decrypt an `.age` file.

```bash
blackdot encrypt decrypt <file.age> [--keep]
```

**Behavior:**
1. Decrypts `<file>.age` to `<file>`
2. Removes `.age` file (unless `--keep`)

**Examples:**

```bash
# Decrypt template variables
blackdot encrypt decrypt templates/_variables.local.sh.age

# Keep encrypted file
blackdot encrypt decrypt templates/_variables.local.sh.age --keep
```

---

### `blackdot encrypt edit`

Edit an encrypted file in place.

```bash
blackdot encrypt edit <file>
```

**Workflow:**
1. Decrypts file to temporary location
2. Opens in `$EDITOR`
3. Re-encrypts on save

**Example:**

```bash
blackdot encrypt edit templates/_variables.local.sh.age
```

---

### `blackdot encrypt list`

List encrypted files and files that should be encrypted.

```bash
blackdot encrypt list
```

**Output shows:**
- Files already encrypted (`.age` files)
- Sensitive files that should be encrypted (matching patterns like `*.secret`, `_variables.local.sh`)

---

### `blackdot encrypt status`

Show encryption status and key information.

```bash
blackdot encrypt status
```

**Output includes:**
- Whether `age` is installed
- Key initialization status
- Public key (safe to share)
- Count of encrypted files

---

### `blackdot encrypt push-key`

Push your private key to vault for backup and recovery on other machines.

```bash
blackdot encrypt push-key
```

**Vault item:** `Age-Private-Key`

**Recovery on new machine:**
```bash
blackdot vault pull        # Restores age key via post_vault_pull hook
blackdot encrypt status    # Verify key restored
```

---

### Encryption + Hooks Integration

The encryption system integrates with dotfiles hooks:

| Hook | When | Action |
|------|------|--------|
| `pre_template_render` | Before template rendering | Auto-decrypt `.age` files in templates/ |
| `post_vault_pull` | After vault pull | Restore age key from vault if missing |
| `pre_encrypt` | Before encryption | Custom pre-encrypt logic |
| `post_decrypt` | After decryption | Custom post-decrypt logic |

**Example workflow:**

```bash
# First machine: encrypt and commit
blackdot encrypt templates/_variables.local.sh
blackdot encrypt push-key
git add templates/_variables.local.sh.age
git commit -m "Add encrypted template vars"
git push

# New machine: clone and decrypt
git pull
blackdot vault pull          # Restores age key
blackdot template render     # Auto-decrypts via hook
```

---

### When to Use Encryption vs Vault

| Use Case | Solution |
|----------|----------|
| SSH keys, AWS credentials | **Vault** (remote storage, pull on demand) |
| Template variables (emails, signing keys) | **Encryption** (committed to git, encrypted) |
| Files that need to be in git | **Encryption** |
| Files that should never be in git | **Vault** |

**Key insight:** Vault and encryption serve different purposes. Vault is for secrets that live remotely. Encryption is for secrets that live in your git repo.

---

## Maintenance Commands

### `blackdot lint`

Validate shell configuration syntax.

```bash
blackdot lint [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--fix` | `-f` | Auto-fix what's possible (permissions) |
| `--verbose` | `-v` | Show detailed output |
| `--help` | `-h` | Show help |

**Checks:**
- ZSH syntax in `zsh/zsh.d/*.zsh`
- Bash syntax in `bootstrap/*.sh`, `vault/*.sh`
- Shellcheck warnings (if installed)
- Config file existence (Brewfile, p10k.zsh)

**Examples:**

```bash
blackdot lint              # Check all configs
blackdot lint --fix        # Fix permissions
blackdot lint --verbose    # Detailed output
```

---

### `blackdot packages`

Check and install Brewfile packages.

```bash
blackdot packages [OPTIONS]
blackdot pkg [OPTIONS]    # Alias
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--check` | `-c` | Show what's missing from Brewfile |
| `--install` | `-i` | Install missing packages |
| `--outdated` | `-o` | Show outdated packages |
| `--help` | `-h` | Show help |

**Examples:**

```bash
blackdot packages              # Overview
blackdot packages --check      # Show missing packages
blackdot packages --install    # Install from Brewfile
blackdot packages --outdated   # Show outdated
```

---

### `blackdot upgrade`

Pull latest changes and run bootstrap.

```bash
blackdot upgrade
blackdot update          # Alias
```

**What it does:**
1. Pulls latest changes from current branch
2. Re-runs bootstrap to update symlinks
3. Updates Homebrew packages from Brewfile
4. Runs health check with `--fix`

---

### `blackdot setup`

Interactive setup wizard with persistent state. **Use this after bootstrap** for guided configuration.

```bash
blackdot setup [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--status` | `-s` | Show current setup progress only |
| `--reset` | `-r` | Reset state and re-run from beginning |
| `--help` | `-h` | Show help |

**Setup phases:**
1. **Symlinks** - Creates shell configuration symlinks
2. **Packages** - Installs Homebrew packages from Brewfile
3. **Vault** - Selects and authenticates vault backend
4. **Secrets** - Restores SSH keys, AWS creds, Git config
5. **Claude Code** - Optionally installs dotclaude for profile management

**Features:**
- **Progress persistence** - Saves state to `~/.config/blackdot/`
- **Resume support** - Continue where you left off if interrupted
- **State inference** - Detects existing installations automatically

**Vault backend support:**
- **Bitwarden** (`bw`) - Handles login + unlock flow
- **1Password** (`op`) - Handles signin flow
- **pass** - Checks GPG agent access
- **None** - Skip vault, configure secrets manually

**Examples:**

```bash
blackdot setup              # Run interactive wizard
blackdot setup --status     # Check progress
blackdot setup --reset      # Start over
```

---

### `blackdot uninstall`

Remove dotfiles configuration.

```bash
blackdot uninstall [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--dry-run` | `-n` | Show what would be removed |
| `--keep-secrets` | `-k` | Keep SSH keys and AWS credentials |
| `--help` | `-h` | Show help |

**Examples:**

```bash
blackdot uninstall --dry-run        # Preview removal
blackdot uninstall --keep-secrets   # Remove but keep secrets
blackdot uninstall                  # Full removal (prompts)
```

---

### `blackdot metrics`

Visualize health check metrics over time.

```bash
blackdot metrics [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--summary` | `-s` | Summary view (default) |
| `--graph` | `-g` | ASCII graph of health score trend |
| `--all` | `-a` | Show all metrics entries |

**Examples:**

```bash
blackdot metrics              # Summary
blackdot metrics --graph      # Trend visualization
blackdot metrics --all        # All entries
```

---

## macOS Commands

### `blackdot macos`

Manage macOS system preferences (macOS only).

```bash
blackdot macos <command>
```

**Subcommands:**

| Command | Description |
|---------|-------------|
| `apply` | Apply settings from `macos/settings.sh` |
| `preview` | Dry-run mode - show what would be changed |
| `discover` | Capture current macOS settings |
| `help` | Show help |

---

### `blackdot macos apply`

Apply macOS system preferences from `settings.sh`.

```bash
blackdot macos apply [OPTIONS]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--backup` | Backup current settings before applying |

**Settings applied:**
- Trackpad (tap to click, tracking speed, three-finger drag)
- Keyboard (fast key repeat, disable auto-correct)
- Dock (auto-hide, size, no recent apps)
- Finder (show extensions, hidden files, path bar)
- Screenshots (location, format, no shadow)
- Security (password on wake, disable crash reporter)

**Example:**

```bash
blackdot macos apply          # Apply all settings
blackdot macos apply --backup # Backup first, then apply
```

---

### `blackdot macos preview`

Show what settings would be changed without making changes.

```bash
blackdot macos preview
```

Same as `blackdot macos apply --dry-run`.

---

### `blackdot macos discover`

Discover and capture current macOS settings.

```bash
blackdot macos discover [OPTIONS]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--snapshot` | Take a snapshot of current settings |
| `--diff` | Compare current settings to last snapshot |
| `--generate` | Generate `settings.sh` from current preferences |
| `--domain <name>` | Show settings for specific domain |
| `--list-domains` | List all preference domains |
| `--all` | Dump all tracked domains |

**Examples:**

```bash
# Discover workflow
blackdot macos discover --snapshot   # Take snapshot
# Make changes in System Preferences
blackdot macos discover --diff       # See what changed
blackdot macos discover --generate   # Generate settings.sh

# Inspect specific domain
blackdot macos discover --domain com.apple.dock
```

---

## Navigation Commands

### `blackdot cd`

Change to the dotfiles directory.

```bash
blackdot cd
```

Equivalent to: `cd ~/workspace/dotfiles`

---

### `blackdot edit`

Open dotfiles in your editor.

```bash
blackdot edit
```

Uses `$EDITOR` (defaults to vim).

---

## Installer Script

### `install.sh`

One-line installer for dotfiles.

```bash
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install.sh | bash
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--minimal` | `-m` | Skip optional features (vault, Claude setup) |
| `--ssh` | - | Clone using SSH instead of HTTPS |
| `--help` | `-h` | Show help |

**After installation:**

Run `blackdot setup` for interactive configuration of vault, secrets, and Claude Code.

**Examples:**

```bash
# Default install (one-liner)
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install.sh | bash

# Minimal mode (no vault, no Claude)
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install.sh -o install.sh && bash install.sh --minimal

# Clone via SSH
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install.sh -o install.sh && bash install.sh --ssh
```

---

## Environment Variables

### Bootstrap & Installation

| Variable | Values | Description |
|----------|--------|-------------|
| `SKIP_WORKSPACE_SYMLINK` | `true` | Skip `/workspace` symlink creation |
| `SKIP_CLAUDE_SETUP` | `true` | Skip Claude Code configuration |
| `BREWFILE_TIER` | `minimal` | Install only essentials (18 packages, ~2 min) |
| `BREWFILE_TIER` | `enhanced` | Modern CLI tools without containers (43 packages, ~5 min) **← RECOMMENDED** |
| `BREWFILE_TIER` | `full` | Everything including Docker/Node (61 packages, ~10 min) [default] |

**Note:** The `blackdot setup` wizard now presents tier selection interactively. These environment variables are for advanced/automated setups.

**Examples:**

```bash
# Single-machine setup (no /workspace symlink)
SKIP_WORKSPACE_SYMLINK=true ./bootstrap/bootstrap-mac.sh

# Skip Claude integration
SKIP_CLAUDE_SETUP=true ./bootstrap/bootstrap-linux.sh

# Use minimal Brewfile tier (essentials only)
BREWFILE_TIER=minimal ./bootstrap/bootstrap-mac.sh

# Use enhanced tier (modern tools, no containers)
BREWFILE_TIER=enhanced ./bootstrap/bootstrap-linux.sh

# Combine flags
BREWFILE_TIER=enhanced SKIP_CLAUDE_SETUP=true ./bootstrap/bootstrap-mac.sh
```

---

### Vault Operations

| Variable | Values | Description |
|----------|--------|-------------|
| `BLACKDOT_VAULT_BACKEND` | `bitwarden`, `1password`, `pass` | Vault backend to use (default: `bitwarden`) |
| `BLACKDOT_OFFLINE` | `1` | Skip all vault operations |
| `BLACKDOT_SKIP_DRIFT_CHECK` | `1` | Skip drift check before restore |
| `BW_SESSION` | session token | Bitwarden session (set by `bw unlock`) |
| `ONEPASSWORD_VAULT` | vault name | 1Password vault name (default: `Personal`) |
| `PASS_PREFIX` | prefix | Pass store prefix (default: `blackdot`) |

**Examples:**

```bash
# Use 1Password instead of Bitwarden
export BLACKDOT_VAULT_BACKEND=1password

# Offline mode (air-gapped environments)
BLACKDOT_OFFLINE=1 ./bootstrap/bootstrap-linux.sh

# Force pull without drift check
BLACKDOT_SKIP_DRIFT_CHECK=1 blackdot vault pull
```

---

### Template System

| Variable | Values | Description |
|----------|--------|-------------|
| `BLACKDOT_TMPL_*` | any | Override any template variable |
| `BLACKDOT_MACHINE_TYPE` | `work`, `personal` | Force machine type detection |
| `DEBUG` | `1` | Enable debug output |

**Examples:**

```bash
# Override git email for one render
BLACKDOT_TMPL_GIT_EMAIL="other@example.com" blackdot template render

# Force machine type
BLACKDOT_MACHINE_TYPE=work blackdot template render

# Debug template rendering
DEBUG=1 dotfiles template render
```

---

### Debug & Development

| Variable | Values | Description |
|----------|--------|-------------|
| `DEBUG` | `1` | Enable debug output in vault and template operations |
| `BLACKDOT_DIR` | path | Override dotfiles directory location |

---

## Shell Functions

These functions are available after sourcing the zsh configuration.

### `status`

Same as `blackdot status`. Visual dashboard.

```bash
status
```

### `j`

Jump to any project by fuzzy search.

```bash
j [BASE_DIR]
```

Uses `fzf` to find git repositories under `/workspace` (or specified directory).

### `note` / `notes`

Quick timestamped notes.

```bash
note "Your note text"     # Add a note
notes                      # View recent notes
notes all                  # View all notes
notes edit                 # Open notes file
notes search <term>        # Search notes
```

Notes stored in `~/workspace/.notes.md`.

### `dotfiles-upgrade`

Same as `blackdot upgrade`. Pull and update.

```bash
dotfiles-upgrade
```

---

## Exit Codes

Most commands follow these conventions:

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Failure (check failed, item not found, etc.) |

---

## File Locations

| File | Purpose |
|------|---------|
| `~/workspace/dotfiles/` | Dotfiles repository |
| `~/.blackdot-backups/` | Backup storage |
| `~/.blackdot-metrics.jsonl` | Health check metrics |
| `~/workspace/.notes.md` | Quick notes |
| `vault/.vault-session` | Cached vault session |
| `templates/_variables.local.sh` | Local template overrides (repo-specific) |
| `~/.config/blackdot/template-variables.sh` | Template variables (XDG, vault-portable) |
| `generated/` | Rendered templates |
| `~/.config/blackdot/config.json` | All configuration and state (JSON format) |
| `~/.config/blackdot/vault-items.json` | Vault items schema |
| `~/.cache/dotfiles/vault-state.json` | Drift detection cache (file checksums from last vault pull) |

---

## State Management

The `blackdot setup` wizard uses persistent state in JSON format. See [State Management](state-management.md) for full documentation.

### Configuration File

#### `~/.config/blackdot/config.json`

All state and configuration in a single JSON file:

```json
{
  "version": 3,
  "vault": {
    "backend": "bitwarden",
    "auto_sync": false,
    "auto_backup": true
  },
  "setup": {
    "completed": ["symlinks", "packages", "vault", "secrets"],
    "current_tier": "enhanced"
  },
  "paths": {
    "dotfiles_dir": "~/workspace/dotfiles",
    "config_dir": "~/.config/blackdot"
  }
}
```

**Key Sections:**
- `setup.completed[]` - Array of completed setup phases
- `vault.backend` - Preferred vault backend (`bitwarden`, `1password`, `pass`)
- `paths.dotfiles_dir` - Custom dotfiles installation directory

**Completed Phases:**
- `symlinks` - Shell configuration symlinks created
- `packages` - Homebrew packages installed
- `vault` - Vault backend selected and authenticated
- `secrets` - Secrets restored from vault
- `claude` - Claude Code integration configured
- `template` - Machine-specific templates configured

### State Commands

```bash
blackdot setup --status    # Show current setup state
blackdot setup --reset     # Reset state and re-run setup
```

### State Inference

If state files don't exist, `blackdot setup` infers state from the filesystem:
- Symlinks: Checks if `~/.zshrc` points to dotfiles
- Packages: Checks if Homebrew is installed
- Vault: Checks for vault CLI and credentials
- Secrets: Checks for `~/.ssh/config`, `~/.gitconfig`
- Claude: Checks if Claude CLI is installed

---

## Claude Code Commands

Commands for working with Claude Code across different backends.

### `claude`

Run Claude Code with automatic path normalization for portable sessions.

```bash
claude [ARGS...]
```

**Behavior:**
- If in `~/workspace/*` and `/workspace` exists, automatically redirects to `/workspace/*`
- Shows educational message explaining session portability
- Passes all arguments to `claude`

**Why:** Claude Code stores sessions by working directory path. The `/workspace` symlink ensures identical paths across macOS, Linux, WSL, etc.

---

### `claude-bedrock` / `cb`

Run Claude Code via AWS Bedrock.

```bash
claude-bedrock [ARGS...]
cb [ARGS...]              # Alias
```

**Requirements:**
- `CLAUDE_BEDROCK_PROFILE` set in `~/.claude.local`
- Valid AWS SSO session (auto-prompts if expired)

**Environment set:**
- `AWS_PROFILE` - Your Bedrock profile
- `AWS_REGION` - Bedrock region
- `CLAUDE_CODE_USE_BEDROCK=1`
- `ANTHROPIC_MODEL` - Bedrock model ID

---

### `claude-max` / `cm`

Run Claude Code via Anthropic Max subscription.

```bash
claude-max [ARGS...]
cm [ARGS...]              # Alias
```

Clears all Bedrock-related environment variables to use your Max subscription.

---

### `claude-run`

Unified command to run Claude with a specific backend.

```bash
claude-run {bedrock|max} [ARGS...]
```

**Examples:**

```bash
claude-run bedrock         # Use AWS Bedrock
claude-run max             # Use Anthropic Max
```

---

### `claude-status`

Show current Claude Code configuration.

```bash
claude-status
```

**Output includes:**
- Session portability status
- Max output tokens setting
- Bedrock configuration (profile, region, model)
- SSO authentication status

---

### Claude Configuration

Configuration file: `~/.claude.local`

```bash
# AWS Bedrock settings
export CLAUDE_BEDROCK_PROFILE="your-sso-profile"
export CLAUDE_BEDROCK_REGION="us-west-2"
export CLAUDE_BEDROCK_MODEL="us.anthropic.claude-sonnet-4-5-20250929-v1:0"
export CLAUDE_BEDROCK_FAST_MODEL="us.anthropic.claude-3-5-haiku-20241022-v1:0"
```

---

## AWS Commands

AWS profile management, SSO authentication, and role assumption helpers.

### Overview

| Command | Description |
|---------|-------------|
| `awsprofiles` | List all profiles (* = active) |
| `awsswitch` | Fuzzy-select profile (fzf) + auto-login |
| `awsset <profile>` | Set AWS_PROFILE for this shell |
| `awsunset` | Clear AWS_PROFILE |
| `awslogin [profile]` | SSO login (defaults to current profile) |
| `awswho` | Show current identity (account/user/ARN) |
| `awsassume <arn>` | Assume role for cross-account access |
| `awsclear` | Clear temporary assumed-role credentials |
| `awstools` | Show all AWS commands with banner |

---

### `awsprofiles`

List all configured AWS profiles.

```bash
awsprofiles
```

Shows `*` next to the currently active profile.

---

### `awsswitch`

Interactive profile selector using fzf.

```bash
awsswitch
```

- Presents fuzzy-searchable list of profiles
- Sets `AWS_PROFILE` on selection
- Auto-triggers SSO login if session expired
- Shows identity after switch

**Requires:** `fzf`

---

### `awsset` / `awsunset`

Set or clear AWS profile for current shell.

```bash
awsset <profile>   # Set AWS_PROFILE
awsunset           # Clear AWS_PROFILE
```

---

### `awslogin`

SSO login helper.

```bash
awslogin [profile]
```

If no profile specified, uses `$AWS_PROFILE` or defaults to `dev-profile`.

---

### `awswho`

Show current AWS identity.

```bash
awswho
```

Displays account, user, and ARN via `aws sts get-caller-identity`.

---

### `awsassume` / `awsclear`

Assume a role for cross-account access.

```bash
awsassume <role-arn> [session-name]
awsclear    # Clear temporary credentials
```

Sets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`.

---

### `awstools`

Show all AWS commands with decorative banner.

```bash
awstools
```

---

## Git Shortcuts

Git aliases and cross-platform clipboard utilities.

### Git Aliases

| Alias | Command | Description |
|-------|---------|-------------|
| `gst` | `git status` | Status |
| `gss` | `git status -sb` | Short status |
| `ga` | `git add` | Add files |
| `gaa` | `git add --all` | Add all files |
| `gb` | `git branch` | List branches |
| `gba` | `git branch -a` | List all branches |
| `gco` | `git checkout` | Checkout |
| `gcb` | `git checkout -b` | Create and checkout branch |
| `gd` | `git diff` | Diff |
| `gds` | `git diff --staged` | Diff staged changes |
| `gpl` | `git pull` | Pull |
| `gp` | `git push` | Push |
| `gpf` | `git push --force-with-lease` | Force push (safe) |
| `gcm` | `git commit -m` | Commit with message |
| `gca` | `git commit --amend` | Amend commit |
| `gcl` | `git clone` | Clone |
| `gl1` | `git log --oneline -n 15` | Short log (15 commits) |
| `glg` | `git log --oneline --graph --all` | Graph log |

---

### Clipboard Functions

Cross-platform clipboard utilities (macOS, Linux, WSL).

```bash
echo "text" | copy    # Copy to clipboard
paste                  # Paste from clipboard
```

**Aliases:**
- `cb` - `copy`
- `cbp` - `paste`

**Supported backends:**
- macOS: `pbcopy`/`pbpaste`
- Wayland: `wl-copy`/`wl-paste`
- X11: `xclip` or `xsel`
- WSL: `clip.exe`/PowerShell

---

## Navigation Aliases

Quick navigation to common directories.

| Alias | Destination |
|-------|-------------|
| `cws` | `$WORKSPACE` (~/workspace) |
| `ccode` | `$WORKSPACE/code` |
| `cwhite` | `$WORKSPACE/whitepapers` |
| `cpat` | `$WORKSPACE/patent-pool` |

---

## Utility Functions

### `j` - Project Jumper

Jump to any git project by fuzzy search.

```bash
j [BASE_DIR]
```

- Searches for `.git` directories under `/workspace` (or specified base)
- Uses `fzf` for fuzzy selection
- Preview shows directory contents

**Requires:** `fzf`, optionally `fd` for faster search

---

### `note` / `notes` - Quick Notes

Capture timestamped notes instantly.

```bash
note "Your note text"     # Add a note
notes                      # View recent notes (last 20)
notes all                  # View all notes
notes edit                 # Open notes file in $EDITOR
notes search <term>        # Search notes
```

Notes stored in `~/workspace/.notes.md`.

---

### `dotfiles-upgrade`

Same as `blackdot upgrade`. Pull latest and update.

```bash
dotfiles-upgrade
```

---

## See Also

- [Full Documentation](README-FULL.md) - Complete guide
- [Vault System](vault-README.md) - Multi-backend secret management
- [Template System](templates.md) - Machine-specific configuration
- [State Management](state-management.md) - Setup wizard state and resume
- [Claude Code Integration](claude-code.md) - Portable sessions & safety hooks
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
