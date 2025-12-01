# CLI Reference

Complete reference for all dotfiles commands, options, and environment variables.

---

## Quick Reference

```bash
dotfiles status          # Visual dashboard
dotfiles doctor          # Health check
dotfiles doctor --fix    # Auto-fix issues
dotfiles vault restore   # Restore secrets from vault
dotfiles vault sync      # Sync local changes to vault
dotfiles template init   # Setup machine-specific configs
dotfiles help            # Show all commands
```

---

## The `dotfiles` Command

The unified command for managing your dotfiles. All subcommands are accessed via `dotfiles <command>`.

### Command Overview

| Command | Alias | Description |
|---------|-------|-------------|
| `status` | `s` | Quick visual dashboard |
| `doctor` | `health` | Comprehensive health check |
| `drift` | - | Compare local files vs vault |
| `diff` | - | Preview changes before sync/restore |
| `backup` | - | Backup and restore configuration |
| `vault` | - | Secret vault operations |
| `template` | `tmpl` | Machine-specific config templates |
| `lint` | - | Validate shell config syntax |
| `packages` | `pkg` | Check/install Brewfile packages |
| `metrics` | - | Visualize health check metrics over time |
| `init` | - | First-time setup wizard |
| `upgrade` | `update` | Pull latest and run bootstrap |
| `uninstall` | - | Remove dotfiles configuration |
| `cd` | - | Change to dotfiles directory |
| `edit` | - | Open dotfiles in $EDITOR |
| `help` | `-h`, `--help` | Show help |

---

## Status & Health Commands

### `dotfiles status`

Display a visual dashboard showing the current state of your dotfiles configuration.

```bash
dotfiles status
dotfiles s              # Alias
```

**Output includes:**
- Symlink status (zshrc, claude, /workspace)
- SSH agent status (keys loaded)
- AWS authentication status
- Lima VM status (macOS only)
- Suggested fixes for any issues

---

### `dotfiles doctor`

Run a comprehensive health check on your dotfiles installation.

```bash
dotfiles doctor [OPTIONS]
dotfiles health         # Alias
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--fix` | `-f` | Auto-fix permission issues |
| `--quick` | `-q` | Run quick checks only (skip vault) |
| `--help` | `-h` | Show help |

**Examples:**

```bash
dotfiles doctor              # Full health check
dotfiles doctor --fix        # Auto-repair permissions
dotfiles doctor --quick      # Fast checks (skip vault status)
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

### `dotfiles drift`

Compare local configuration files against vault to detect differences.

```bash
dotfiles drift
```

**Checks these items:**
- SSH-Config (`~/.ssh/config`)
- AWS-Config (`~/.aws/config`)
- AWS-Credentials (`~/.aws/credentials`)
- Git-Config (`~/.gitconfig`)
- Environment-Secrets (`~/.local/env.secrets`)

**Output:**
- Shows which items are in sync
- Shows which items have local changes
- Suggests next steps (sync or restore)

---

### `dotfiles diff`

Preview differences between local files and vault before performing sync or restore operations.

```bash
dotfiles diff [OPTIONS] [ITEM]
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
dotfiles diff                 # Show all differences
dotfiles diff --sync          # What would be pushed to vault
dotfiles diff --restore       # What would be restored locally
dotfiles diff SSH-Config      # Diff specific item
```

---

## Backup & Restore

### `dotfiles backup`

Create timestamped backups of configuration files or restore from previous backups.

```bash
dotfiles backup [COMMAND] [OPTIONS]
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
dotfiles backup              # Create new backup
dotfiles backup --list       # List available backups
dotfiles backup restore      # Restore from latest backup
dotfiles backup restore backup-20240115-143022  # Restore specific
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
- Backups stored in `~/.dotfiles-backups/`
- Maximum 10 backups retained (oldest auto-deleted)
- Each backup includes a manifest with metadata

---

## Vault Commands

### `dotfiles vault`

Manage secrets stored in your vault. Supports multiple backends with a unified interface.

```bash
dotfiles vault <command> [OPTIONS]
```

**Subcommands:**

| Command | Description |
|---------|-------------|
| `restore` | Restore all secrets from vault |
| `sync` | Sync local files to vault |
| `list` | List vault items |
| `check` | Validate vault items exist |
| `validate` | Validate vault item schema |
| `create` | Create new vault item |
| `delete` | Delete vault item |
| `help` | Show help |

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
export DOTFILES_VAULT_BACKEND=bitwarden  # (default)
export DOTFILES_VAULT_BACKEND=1password
export DOTFILES_VAULT_BACKEND=pass
```

All `dotfiles vault` commands work identically regardless of backend.

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
export DOTFILES_VAULT_BACKEND=1password
export ONEPASSWORD_VAULT=Personal  # optional, default vault
```

**pass:**
```bash
brew install pass
pass init <gpg-key-id>
export DOTFILES_VAULT_BACKEND=pass
export PASS_PREFIX=dotfiles  # optional, items stored as dotfiles/Git-Config
```

---

### Managed Secrets

The vault system manages these items:

| Item Name | Local Path | Type |
|-----------|------------|------|
| `SSH-GitHub-Enterprise` | `~/.ssh/id_ed25519_enterprise_ghub` | SSH key |
| `SSH-GitHub-Blackwell` | `~/.ssh/id_ed25519_blackwell` | SSH key |
| `SSH-Config` | `~/.ssh/config` | Config file |
| `AWS-Config` | `~/.aws/config` | Config file |
| `AWS-Credentials` | `~/.aws/credentials` | Config file |
| `Git-Config` | `~/.gitconfig` | Config file |
| `Environment-Secrets` | `~/.local/env.secrets` | Config file (optional) |

---

### `dotfiles vault restore`

Restore secrets from vault to local machine.

```bash
dotfiles vault restore [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--force` | `-f` | Skip drift check, overwrite local changes |

**Behavior:**
1. Checks for local drift (unless `--force`)
2. Syncs vault to get latest
3. Restores SSH keys, AWS config, Git config, etc.
4. Sets correct file permissions

**Environment variables:**
- `DOTFILES_SKIP_DRIFT_CHECK=1` - Skip drift check (for automation)

---

### `dotfiles vault sync`

Sync local configuration files back to vault.

```bash
dotfiles vault sync [OPTIONS] [ITEMS...]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--dry-run` | `-n` | Show what would be synced without making changes |
| `--all` | `-a` | Sync all items |
| `--help` | `-h` | Show help |

**Arguments:**

| Argument | Description |
|----------|-------------|
| `ITEMS` | Specific items to sync (space-separated) |

**Syncable items:**
- `SSH-Config`
- `AWS-Config`
- `AWS-Credentials`
- `Git-Config`
- `Environment-Secrets`

**Examples:**

```bash
dotfiles vault sync --all            # Sync all items
dotfiles vault sync --dry-run --all  # Preview changes
dotfiles vault sync SSH-Config       # Sync single item
dotfiles vault sync Git-Config AWS-Config  # Sync multiple
```

---

### `dotfiles vault list`

List vault items managed by dotfiles.

```bash
dotfiles vault list
```

---

### `dotfiles vault check`

Validate that required vault items exist.

```bash
dotfiles vault check
```

---

### `dotfiles vault validate`

Validate vault item schema (structure, content format).

```bash
dotfiles vault validate
```

**Validates:**
- SSH keys contain proper BEGIN/END markers
- Config files have minimum content length
- Items are correct type (secureNote)

---

## Template Commands

### `dotfiles template`

Manage machine-specific configuration templates.

```bash
dotfiles template <command> [OPTIONS]
dotfiles tmpl <command>   # Alias
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
| `help` | `-h`, `--help` | Show help |

---

### `dotfiles template init`

Interactive setup wizard for the template system.

```bash
dotfiles template init
```

**What it does:**
1. Detects system info (hostname, OS, architecture)
2. Creates `templates/_variables.local.sh`
3. Opens editor to customize variables

---

### `dotfiles template render`

Render templates to the `generated/` directory.

```bash
dotfiles template render [OPTIONS] [FILE]
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
dotfiles template render              # Render all templates
dotfiles template render --dry-run    # Preview changes
dotfiles template render gitconfig    # Render specific template
```

---

### `dotfiles template vars`

List all template variables and their current values.

```bash
dotfiles template vars [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--quiet` | `-q` | Minimal output (values only) |

---

### `dotfiles template link`

Create symlinks from generated files to their destinations.

```bash
dotfiles template link [OPTIONS]
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

### `dotfiles template diff`

Show differences between templates and generated files.

```bash
dotfiles template diff [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--verbose` | `-v` | Show detailed diff output |

---

### `dotfiles template list`

List available templates and their status.

```bash
dotfiles template list
dotfiles template ls    # Alias
```

**Status indicators:**
- Up to date
- Stale (needs re-rendering)
- Not generated

---

## Maintenance Commands

### `dotfiles lint`

Validate shell configuration syntax.

```bash
dotfiles lint [OPTIONS]
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
dotfiles lint              # Check all configs
dotfiles lint --fix        # Fix permissions
dotfiles lint --verbose    # Detailed output
```

---

### `dotfiles packages`

Check and install Brewfile packages.

```bash
dotfiles packages [OPTIONS]
dotfiles pkg [OPTIONS]    # Alias
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
dotfiles packages              # Overview
dotfiles packages --check      # Show missing packages
dotfiles packages --install    # Install from Brewfile
dotfiles packages --outdated   # Show outdated
```

---

### `dotfiles upgrade`

Pull latest changes and run bootstrap.

```bash
dotfiles upgrade
dotfiles update          # Alias
```

**What it does:**
1. Pulls latest changes from current branch
2. Re-runs bootstrap to update symlinks
3. Updates Homebrew packages from Brewfile
4. Runs health check with `--fix`

---

### `dotfiles init`

Interactive first-time setup wizard. **Use this after cloning the repository** for guided setup.

```bash
dotfiles init
```

**What it does:**
1. **Checks current state** - Detects if already initialized
2. **Runs bootstrap** - Creates symlinks, installs packages
3. **Vault selection** - Auto-detects installed vault CLIs (Bitwarden, 1Password, pass)
   - Prompts you to choose which vault to use
   - Option to skip vault entirely (manual secret config)
   - Never auto-selects - you always choose
4. **Vault authentication** - Guides login/unlock for selected backend
5. **Secret restoration** - Restores SSH keys, AWS creds, Git config from vault
6. **Claude Code setup** - Optionally installs dotclaude for profile management
7. **Health check** - Verifies everything is configured correctly

**Vault backend support:**
- **Bitwarden** (`bw`) - Handles login + unlock flow
- **1Password** (`op`) - Handles signin flow
- **pass** - Checks GPG agent access
- **None** - Skip vault, configure secrets manually

**Environment variables:**
- `DOTFILES_VAULT_BACKEND` - Pre-select backend (skips prompt)

---

### `dotfiles uninstall`

Remove dotfiles configuration.

```bash
dotfiles uninstall [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--dry-run` | `-n` | Show what would be removed |
| `--keep-secrets` | `-k` | Keep SSH keys and AWS credentials |
| `--help` | `-h` | Show help |

**Examples:**

```bash
dotfiles uninstall --dry-run        # Preview removal
dotfiles uninstall --keep-secrets   # Remove but keep secrets
dotfiles uninstall                  # Full removal (prompts)
```

---

### `dotfiles metrics`

Visualize health check metrics over time.

```bash
dotfiles metrics [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--summary` | `-s` | Summary view (default) |
| `--graph` | `-g` | ASCII graph of health score trend |
| `--all` | `-a` | Show all metrics entries |

**Examples:**

```bash
dotfiles metrics              # Summary
dotfiles metrics --graph      # Trend visualization
dotfiles metrics --all        # All entries
```

---

## Navigation Commands

### `dotfiles cd`

Change to the dotfiles directory.

```bash
dotfiles cd
```

Equivalent to: `cd ~/workspace/dotfiles`

---

### `dotfiles edit`

Open dotfiles in your editor.

```bash
dotfiles edit
```

Uses `$EDITOR` (defaults to vim).

---

## Installer Script

### `install.sh`

One-line installer for dotfiles.

```bash
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--interactive` | `-i` | Prompt for configuration options |
| `--minimal` | `-m` | Skip optional features (vault, Claude setup) |
| `--ssh` | - | Clone using SSH instead of HTTPS |
| `--help` | `-h` | Show help |

**Examples:**

```bash
# Default install
curl -fsSL ... | bash

# Interactive mode
curl -fsSL ... | bash -s -- --interactive

# Minimal mode (no vault, no Claude)
curl -fsSL ... | bash -s -- --minimal

# Clone via SSH
curl -fsSL ... | bash -s -- --ssh
```

---

## Environment Variables

### Bootstrap & Installation

| Variable | Values | Description |
|----------|--------|-------------|
| `SKIP_WORKSPACE_SYMLINK` | `true` | Skip `/workspace` symlink creation |
| `SKIP_CLAUDE_SETUP` | `true` | Skip Claude Code configuration |

**Examples:**

```bash
# Single-machine setup (no /workspace symlink)
SKIP_WORKSPACE_SYMLINK=true ./bootstrap/bootstrap-mac.sh

# Skip Claude integration
SKIP_CLAUDE_SETUP=true ./bootstrap/bootstrap-linux.sh

# Combine flags
SKIP_WORKSPACE_SYMLINK=true SKIP_CLAUDE_SETUP=true ./bootstrap/bootstrap-mac.sh
```

---

### Vault Operations

| Variable | Values | Description |
|----------|--------|-------------|
| `DOTFILES_VAULT_BACKEND` | `bitwarden`, `1password`, `pass` | Vault backend to use (default: `bitwarden`) |
| `DOTFILES_OFFLINE` | `1` | Skip all vault operations |
| `DOTFILES_SKIP_DRIFT_CHECK` | `1` | Skip drift check before restore |
| `BW_SESSION` | session token | Bitwarden session (set by `bw unlock`) |
| `ONEPASSWORD_VAULT` | vault name | 1Password vault name (default: `Personal`) |
| `PASS_PREFIX` | prefix | Pass store prefix (default: `dotfiles`) |

**Examples:**

```bash
# Use 1Password instead of Bitwarden
export DOTFILES_VAULT_BACKEND=1password

# Offline mode (air-gapped environments)
DOTFILES_OFFLINE=1 ./bootstrap/bootstrap-linux.sh

# Force restore without drift check
DOTFILES_SKIP_DRIFT_CHECK=1 dotfiles vault restore
```

---

### Template System

| Variable | Values | Description |
|----------|--------|-------------|
| `DOTFILES_TMPL_*` | any | Override any template variable |
| `DOTFILES_MACHINE_TYPE` | `work`, `personal` | Force machine type detection |
| `DEBUG` | `1` | Enable debug output |

**Examples:**

```bash
# Override git email for one render
DOTFILES_TMPL_GIT_EMAIL="other@example.com" dotfiles template render

# Force machine type
DOTFILES_MACHINE_TYPE=work dotfiles template render

# Debug template rendering
DEBUG=1 dotfiles template render
```

---

### Debug & Development

| Variable | Values | Description |
|----------|--------|-------------|
| `DEBUG` | `1` | Enable debug output in vault and template operations |
| `DOTFILES_DIR` | path | Override dotfiles directory location |

---

## Shell Functions

These functions are available after sourcing the zsh configuration.

### `status`

Same as `dotfiles status`. Visual dashboard.

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

Same as `dotfiles upgrade`. Pull and update.

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
| `~/.dotfiles-backups/` | Backup storage |
| `~/.dotfiles-metrics.jsonl` | Health check metrics |
| `~/workspace/.notes.md` | Quick notes |
| `vault/.vault-session` | Cached vault session |
| `templates/_variables.local.sh` | Local template overrides |
| `generated/` | Rendered templates |

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

Same as `dotfiles upgrade`. Pull latest and update.

```bash
dotfiles-upgrade
```

---

## See Also

- [Full Documentation](README-FULL.md) - Complete guide
- [Vault System](vault-README.md) - Multi-backend secret management
- [Template System](templates.md) - Machine-specific configuration
- [Claude Code Integration](claude-code.md) - Portable sessions & safety hooks
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
