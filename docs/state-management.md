# State Management

The `dotfiles setup` wizard uses a persistent state system to track progress, save preferences, and enable resume capability.

---

## Overview

State management provides:

- **Progress Tracking** - Remember which setup phases are complete
- **Resume Support** - Continue where you left off if interrupted
- **Preference Persistence** - Save choices like vault backend across sessions
- **State Inference** - Auto-detect existing installations from filesystem

---

## State Files

All state files are stored in `~/.config/dotfiles/`:

| File | Purpose |
|------|---------|
| `state.ini` | Setup wizard phase completion |
| `config.ini` | User preferences and settings |

### `~/.config/dotfiles/state.ini`

Tracks which setup phases have been completed:

```ini
[phases]
symlinks = complete
packages = complete
vault = complete
secrets = complete
claude = complete
```

**Phases:**

| Phase | Description | What It Does |
|-------|-------------|--------------|
| `symlinks` | Shell configuration | Links `.zshrc`, `.p10k.zsh` to home directory |
| `packages` | Homebrew packages | Installs packages from Brewfile |
| `vault` | Vault backend | Selects and authenticates vault (Bitwarden/1Password/pass) |
| `secrets` | Secret restoration | Restores SSH keys, AWS creds, Git config from vault |
| `claude` | Claude Code | Optionally installs dotclaude for profile management |

### `~/.config/dotfiles/config.ini`

Stores persistent user preferences:

```ini
[vault]
backend = bitwarden
```

**Settings:**

| Section | Key | Values | Description |
|---------|-----|--------|-------------|
| `vault` | `backend` | `bitwarden`, `1password`, `pass`, `none` | Preferred vault backend |

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
[✓] Symlinks    - Shell configuration linked
[✓] Packages    - Homebrew packages installed
[✓] Vault       - Backend: bitwarden
[✓] Secrets     - SSH keys, AWS, Git restored
[ ] Claude      - Not configured
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
1. Reads existing state from `state.ini`
2. Skips completed phases
3. Continues from where you left off

---

## State Inference

When state files don't exist (fresh install or after reset), `dotfiles setup` infers state from the filesystem:

| Phase | Detection Method |
|-------|------------------|
| Symlinks | Checks if `~/.zshrc` is a symlink pointing to dotfiles |
| Packages | Checks if Homebrew (`brew`) is installed |
| Vault | Checks for vault CLI (`bw`/`op`/`pass`) and valid session |
| Secrets | Checks for `~/.ssh/config`, `~/.gitconfig`, `~/.aws/config` |
| Claude | Checks if `claude` CLI is in PATH |

This means you can run `dotfiles setup` on an existing installation and it will recognize what's already configured.

---

## Library Functions

The state system is implemented in `lib/_state.sh`:

### Phase State Functions

```bash
# Initialize state (creates directory and files if needed)
state_init

# Check if a phase is completed
if state_completed "symlinks"; then
    echo "Symlinks already configured"
fi

# Mark a phase as complete
state_complete "packages"

# Check if setup is needed (any incomplete phases)
if state_needs_setup; then
    echo "Run: dotfiles setup"
fi

# Infer state from filesystem
state_infer
```

### Config Functions

```bash
# Get a config value
backend=$(config_get "vault" "backend")

# Set a config value
config_set "vault" "backend" "1password"
```

---

## Integration with Vault

The vault backend preference is persisted in `config.ini`:

```bash
# Priority order for vault backend:
# 1. Config file (~/.config/dotfiles/config.ini)
# 2. Environment variable (DOTFILES_VAULT_BACKEND)
# 3. Default (bitwarden)
```

When you select a vault during `dotfiles setup`, it's saved to the config file. This means:
- No need to export `DOTFILES_VAULT_BACKEND` in your shell
- Preference persists across shell restarts
- Works automatically with all `dotfiles vault` commands

---

## File Format

Both state files use INI format for simplicity and shell compatibility:

```ini
[section]
key = value
```

**Why INI?**
- Pure zsh parsing (no external dependencies like `jq`)
- Human-readable and hand-editable if needed
- Simple key-value structure
- Compatible with standard tools

---

## Troubleshooting

### State Not Persisting

Check file permissions:

```bash
ls -la ~/.config/dotfiles/
# Should show: drwx------ (700) for directory
# Files should be: -rw------- (600)
```

Fix permissions:

```bash
chmod 700 ~/.config/dotfiles
chmod 600 ~/.config/dotfiles/*.ini
```

### Wrong Vault Backend

Check current config:

```bash
cat ~/.config/dotfiles/config.ini
```

Reset vault selection:

```bash
# Edit config directly
echo "[vault]
backend = 1password" > ~/.config/dotfiles/config.ini

# Or reset and re-run setup
dotfiles setup --reset
```

### State Out of Sync

If state doesn't match reality:

```bash
# Option 1: Let inference fix it
rm ~/.config/dotfiles/state.ini
dotfiles setup  # Will infer from filesystem

# Option 2: Full reset
dotfiles setup --reset
```

### Manual State Editing

You can edit state files directly:

```bash
# Mark a phase as incomplete to re-run it
vim ~/.config/dotfiles/state.ini
# Change: packages = complete
# To:     packages = incomplete
```

---

## See Also

- [Setup Wizard](cli-reference.md#dotfiles-setup) - Full setup command reference
- [Vault System](vault-README.md) - Multi-backend secret management
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
