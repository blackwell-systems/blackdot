# Hook Examples

Example hook scripts you can copy to `~/.config/dotfiles/hooks/` to extend dotfiles behavior.

## Installation

```bash
# Create hooks directory
mkdir -p ~/.config/dotfiles/hooks

# Copy a hook (example: permissions fix after vault pull)
mkdir -p ~/.config/dotfiles/hooks/post_vault_pull
cp post_vault_pull/10-fix-permissions.sh ~/.config/dotfiles/hooks/post_vault_pull/
chmod +x ~/.config/dotfiles/hooks/post_vault_pull/10-fix-permissions.sh

# Verify it's registered
dotfiles hook list post_vault_pull
```

## Available Examples

### `post_vault_pull/`
Hooks that run after `blackdot sync` pulls secrets from vault.

| File | Purpose |
|------|---------|
| `10-fix-permissions.sh` | Set correct permissions on SSH keys, AWS credentials |
| `20-ssh-add.sh` | Add SSH keys to the agent |

### `doctor_check/`
Hooks that add custom checks to `blackdot doctor`.

| File | Purpose |
|------|---------|
| `10-custom-checks.sh` | Example custom health checks (VPN, env vars, disk) |

### `shell_init/`
Hooks that run at the end of shell initialization (.zshrc).

| File | Purpose |
|------|---------|
| `10-project-env.zsh` | Load work environment, direnv, AWS profile |

### `directory_change/`
Hooks that run when you `cd` to a new directory.

| File | Purpose |
|------|---------|
| `10-auto-env.zsh` | Auto-activate Python venv, nvm version |

## Naming Convention

Scripts are executed in alphabetical order. Use numeric prefixes:
- `10-*` - Early execution
- `50-*` - Normal priority
- `90-*` - Late execution

## JSON Configuration Alternative

Instead of file-based hooks, you can configure hooks in JSON:

```bash
cat > ~/.config/dotfiles/hooks.json << 'EOF'
{
  "hooks": {
    "post_vault_pull": [
      {"name": "ssh-add", "command": "ssh-add ~/.ssh/id_ed25519 2>/dev/null", "enabled": true, "fail_ok": true}
    ]
  },
  "settings": {"fail_fast": false, "verbose": false, "timeout": 30}
}
EOF
```

## Testing Hooks

```bash
# List hooks for a point
dotfiles hook list post_vault_pull

# Test hooks (verbose dry-run)
dotfiles hook test post_vault_pull

# Run hooks manually with verbose output
dotfiles hook run --verbose post_vault_pull
```

## Hook Points Reference

| Category | Hook Points |
|----------|-------------|
| Lifecycle | `pre_install`, `post_install`, `pre_bootstrap`, `post_bootstrap`, `pre_upgrade`, `post_upgrade` |
| Vault | `pre_vault_pull`, `post_vault_pull`, `pre_vault_push`, `post_vault_push` |
| Doctor | `pre_doctor`, `post_doctor`, `doctor_check` |
| Shell | `shell_init`, `shell_exit`, `directory_change` |
| Setup | `pre_setup_phase`, `post_setup_phase`, `setup_complete` |
