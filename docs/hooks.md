# Hook System

The hook system allows you to inject custom behavior at key lifecycle points without modifying core dotfiles scripts. Hooks are shell scripts or commands that execute before/after major operations.

---

## Quick Start

```bash
# Create a hook directory
mkdir -p ~/.config/dotfiles/hooks/post_vault_pull

# Create a simple hook
cat > ~/.config/dotfiles/hooks/post_vault_pull/10-fix-permissions.sh << 'EOF'
#!/bin/bash
chmod 600 ~/.ssh/id_* 2>/dev/null
chmod 700 ~/.ssh 2>/dev/null
echo "Fixed SSH permissions"
EOF
chmod +x ~/.config/dotfiles/hooks/post_vault_pull/10-fix-permissions.sh

# Verify it's registered
dotfiles hook list post_vault_pull

# Test the hook
dotfiles hook test post_vault_pull
```

---

## Hook Points

### Lifecycle Hooks

| Hook | When | Use Case |
|------|------|----------|
| `pre_install` | Before `install.sh` runs | Backup existing files |
| `post_install` | After `install.sh` completes | Run custom setup |
| `pre_bootstrap` | Before bootstrap script | Check prerequisites |
| `post_bootstrap` | After bootstrap completes | Install extra packages |
| `pre_upgrade` | Before `dotfiles upgrade` | Backup config |
| `post_upgrade` | After upgrade completes | Run migrations |

### Vault Hooks

| Hook | When | Use Case |
|------|------|----------|
| `pre_vault_pull` | Before restoring secrets | Backup existing secrets |
| `post_vault_pull` | After secrets restored | Set permissions, run ssh-add |
| `pre_vault_push` | Before syncing to vault | Validate secrets |
| `post_vault_push` | After vault sync | Notify/log |

### Doctor Hooks

| Hook | When | Use Case |
|------|------|----------|
| `pre_doctor` | Before health check | Custom pre-checks |
| `post_doctor` | After health check | Report to monitoring |
| `doctor_check` | During doctor | Add custom validations |

### Shell Hooks

| Hook | When | Use Case |
|------|------|----------|
| `shell_init` | End of .zshrc | Load project-specific config |
| `shell_exit` | Shell exit | Cleanup, logging |
| `directory_change` | On `cd` | Auto-activate envs |

### Setup Wizard Hooks

| Hook | When | Use Case |
|------|------|----------|
| `pre_setup_phase` | Before each wizard phase | Custom validation |
| `post_setup_phase` | After each wizard phase | Phase-specific setup |
| `setup_complete` | After all phases done | Final customization |

---

## Registration Methods

### 1. File-Based Hooks (Recommended)

Place executable scripts in `~/.config/dotfiles/hooks/<hook_point>/`:

```bash
~/.config/dotfiles/hooks/
├── post_vault_pull/
│   ├── 10-fix-permissions.sh
│   └── 20-ssh-add.sh
├── doctor_check/
│   └── 10-custom-checks.sh
└── shell_init/
    └── 10-project-env.zsh
```

**Naming convention:** Scripts execute in alphabetical order. Use numeric prefixes:
- `10-*` - Early execution
- `50-*` - Normal priority
- `90-*` - Late execution

### 2. JSON Configuration

Configure hooks in `~/.config/dotfiles/hooks.json`:

```json
{
  "hooks": {
    "post_vault_pull": [
      {
        "name": "ssh-add",
        "command": "ssh-add ~/.ssh/id_ed25519 2>/dev/null",
        "enabled": true,
        "fail_ok": true
      },
      {
        "name": "fix-perms",
        "command": "chmod 600 ~/.ssh/id_*",
        "enabled": true
      }
    ],
    "doctor_check": [
      {
        "name": "check-vpn",
        "command": "pgrep -x 'openconnect' > /dev/null && echo 'VPN connected'",
        "enabled": true,
        "fail_ok": true
      }
    ]
  },
  "settings": {
    "fail_fast": false,
    "verbose": false,
    "timeout": 30
  }
}
```

**JSON hook properties:**
- `name` - Identifier for the hook
- `command` - Shell command to execute
- `enabled` - Whether hook is active (default: true)
- `fail_ok` - Continue if hook fails (default: false)

### 3. Inline Registration (Shell Config)

Register hooks programmatically in your `.zshrc.local`:

```zsh
# Source hooks library
source "$DOTFILES_DIR/lib/_hooks.sh"

# Register inline hooks
hook_register "shell_init" "load-work-env" '
    [[ -f ~/.work-env ]] && source ~/.work-env
'

hook_register "directory_change" "auto-nvm" '
    [[ -f .nvmrc ]] && nvm use 2>/dev/null
'
```

---

## CLI Commands

```bash
# List all hook points and their hooks
dotfiles hook list

# List hooks for a specific point
dotfiles hook list post_vault_pull

# Run hooks for a point
dotfiles hook run post_vault_pull

# Run with verbose output
dotfiles hook run --verbose post_vault_pull

# Test hooks (shows what would run)
dotfiles hook test post_vault_pull
```

---

## Example Hooks

The repository includes ready-to-use example hooks in `hooks/examples/`:

### Post Vault Pull - Fix Permissions

```bash
#!/bin/bash
# hooks/examples/post_vault_pull/10-fix-permissions.sh
# Set correct permissions on sensitive files after vault pull

# SSH keys
chmod 700 ~/.ssh 2>/dev/null
chmod 600 ~/.ssh/id_* 2>/dev/null
chmod 644 ~/.ssh/*.pub 2>/dev/null
chmod 600 ~/.ssh/config 2>/dev/null

# AWS credentials
chmod 700 ~/.aws 2>/dev/null
chmod 600 ~/.aws/credentials 2>/dev/null
chmod 600 ~/.aws/config 2>/dev/null

echo "Fixed permissions on SSH and AWS files"
```

### Post Vault Pull - SSH Add

```bash
#!/bin/bash
# hooks/examples/post_vault_pull/20-ssh-add.sh
# Add SSH keys to agent after vault pull

# Start ssh-agent if not running
if ! pgrep -u "$USER" ssh-agent > /dev/null; then
    eval "$(ssh-agent -s)" > /dev/null
fi

# Add common keys
for key in ~/.ssh/id_ed25519 ~/.ssh/id_rsa ~/.ssh/id_ed25519_github; do
    [[ -f "$key" ]] && ssh-add "$key" 2>/dev/null
done
```

### Doctor Check - Custom Validations

```bash
#!/bin/bash
# hooks/examples/doctor_check/10-custom-checks.sh
# Add custom checks to dotfiles doctor

# Check VPN connection
if command -v openconnect &>/dev/null; then
    if pgrep -x "openconnect" > /dev/null; then
        echo "[OK] VPN connected"
    else
        echo "[WARN] VPN not connected"
    fi
fi

# Check required env vars
for var in GITHUB_TOKEN AWS_PROFILE; do
    if [[ -n "${!var}" ]]; then
        echo "[OK] $var is set"
    else
        echo "[WARN] $var not set"
    fi
done
```

### Shell Init - Project Environment

```zsh
#!/usr/bin/env zsh
# hooks/examples/shell_init/10-project-env.zsh
# Load work environment at shell startup

# Load direnv if available
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# Set default AWS profile for work
[[ -z "$AWS_PROFILE" ]] && export AWS_PROFILE="work"

# Load work-specific aliases
[[ -f ~/.work-aliases ]] && source ~/.work-aliases
```

### Directory Change - Auto Environment

```zsh
#!/usr/bin/env zsh
# hooks/examples/directory_change/10-auto-env.zsh
# Auto-activate environments when entering directories

# Auto-activate Python venv
if [[ -f "venv/bin/activate" ]]; then
    source venv/bin/activate
elif [[ -f ".venv/bin/activate" ]]; then
    source .venv/bin/activate
fi

# Auto-switch Node version with nvm
if [[ -f ".nvmrc" ]] && command -v nvm &>/dev/null; then
    nvm use 2>/dev/null
fi
```

### Installing Example Hooks

```bash
# Copy an example to your hooks directory
mkdir -p ~/.config/dotfiles/hooks/post_vault_pull
cp ~/workspace/dotfiles/hooks/examples/post_vault_pull/10-fix-permissions.sh \
   ~/.config/dotfiles/hooks/post_vault_pull/
chmod +x ~/.config/dotfiles/hooks/post_vault_pull/10-fix-permissions.sh
```

---

## Feature Integration

The hook system integrates with the [Feature Registry](features.md):

- **Hooks are a feature** - Enable/disable with `dotfiles features enable/disable hooks`
- **Parent feature gating** - Vault hooks only run if `vault` feature is enabled
- **Feature checks in hooks** - Use `feature_enabled "name"` in your hook scripts

```bash
# Disable all hooks
dotfiles features disable hooks

# Re-enable hooks
dotfiles features enable hooks --persist
```

---

## Configuration Options

### Settings in hooks.json

```json
{
  "settings": {
    "fail_fast": false,    // Stop on first hook failure
    "verbose": false,      // Show detailed output
    "timeout": 30          // Max seconds per hook
  }
}
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOTFILES_HOOKS_VERBOSE` | `false` | Enable verbose hook output |
| `DOTFILES_HOOKS_DISABLED` | `false` | Disable all hooks |
| `DOTFILES_HOOKS_FAIL_FAST` | `false` | Stop on first failure |

---

## Troubleshooting

### Hook not running?

1. **Check it's executable:** `chmod +x ~/.config/dotfiles/hooks/<point>/<script>`
2. **Check feature enabled:** `dotfiles features | grep hooks`
3. **Check parent feature:** Vault hooks require `vault` feature enabled
4. **Test manually:** `dotfiles hook test <point>`

### Hook failing silently?

Run with verbose mode:
```bash
dotfiles hook run --verbose <point>
```

### View registered hooks

```bash
dotfiles hook list        # All hooks
dotfiles hook list <point> # Specific point
```

---

## Best Practices

1. **Use numeric prefixes** for execution order (10-, 20-, 50-, 90-)
2. **Set `fail_ok: true`** for non-critical hooks
3. **Keep hooks fast** - Shell init hooks affect startup time
4. **Use verbose logging** during development
5. **Test hooks** before relying on them: `dotfiles hook test <point>`

---

## See Also

- [Feature Registry](features.md) - Control plane for hook feature
- [CLI Reference](cli-reference.md) - Full `dotfiles hook` command reference
- [Design Document](design/IMPL-hook-system.md) - Implementation details
