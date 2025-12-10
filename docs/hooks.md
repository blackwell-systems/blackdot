# Hook System

The hook system allows you to inject custom behavior at key lifecycle points without modifying core blackdot scripts. Hooks are shell scripts or commands that execute before/after major operations.

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
blackdot hook list post_vault_pull

# Test the hook
blackdot hook test post_vault_pull
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
| `pre_upgrade` | Before `blackdot upgrade` | Backup config |
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

### Template & Encryption Hooks

| Hook | When | Use Case |
|------|------|----------|
| `pre_template_render` | Before template rendering | Auto-decrypt .age files |
| `post_template_render` | After templates rendered | Validation, notifications |
| `pre_encrypt` | Before file encryption | Custom pre-processing |
| `post_decrypt` | After file decryption | Permission fixes, validation |

---

## Understanding ZSH Hooks

ZSH provides native hook functions that execute at specific points in the shell lifecycle. The blackdot hook system builds on these to provide a more structured, manageable approach.

### Native ZSH Hook Functions

ZSH has several built-in hook arrays that you can add functions to:

| Hook Array | When It Runs | Example Use |
|------------|--------------|-------------|
| `precmd_functions` | Before each prompt is displayed | Update prompt, show git status |
| `preexec_functions` | Before each command executes | Timing, logging |
| `chpwd_functions` | After directory change (`cd`) | Auto-activate virtualenvs |
| `zshexit_functions` | When shell exits | Cleanup, save history |
| `periodic_functions` | Every `$PERIOD` seconds | Background checks |
| `zshaddhistory_functions` | Before adding to history | Filter sensitive commands |

### How Native ZSH Hooks Work

```zsh
# Method 1: Add function to hook array
my_precmd() {
    echo "About to show prompt"
}
precmd_functions+=( my_precmd )

# Method 2: Use add-zsh-hook (recommended)
autoload -Uz add-zsh-hook
add-zsh-hook precmd my_precmd
add-zsh-hook chpwd my_chpwd_function

# Remove a hook
add-zsh-hook -d precmd my_precmd
```

### Common Native Hook Patterns

**Auto-activate Python virtualenv on cd:**
```zsh
autoload -Uz add-zsh-hook

_auto_venv() {
    if [[ -f "venv/bin/activate" ]]; then
        source venv/bin/activate
    elif [[ -f ".venv/bin/activate" ]]; then
        source .venv/bin/activate
    elif [[ -n "$VIRTUAL_ENV" ]]; then
        # Deactivate if we left a venv directory
        deactivate 2>/dev/null
    fi
}
add-zsh-hook chpwd _auto_venv
```

**Command timing with preexec/precmd:**
```zsh
autoload -Uz add-zsh-hook

_timer_preexec() {
    _cmd_start=$EPOCHREALTIME
}

_timer_precmd() {
    if [[ -n "$_cmd_start" ]]; then
        local elapsed=$(( EPOCHREALTIME - _cmd_start ))
        if (( elapsed > 5 )); then
            echo "Command took ${elapsed}s"
        fi
        unset _cmd_start
    fi
}

add-zsh-hook preexec _timer_preexec
add-zsh-hook precmd _timer_precmd
```

**Filter sensitive commands from history:**
```zsh
_filter_history() {
    local cmd="$1"
    # Don't save commands with secrets
    [[ "$cmd" == *"password"* ]] && return 1
    [[ "$cmd" == *"secret"* ]] && return 1
    [[ "$cmd" == *"AWS_SECRET"* ]] && return 1
    return 0
}
add-zsh-hook zshaddhistory _filter_history
```

### How Dotfiles Hooks Map to ZSH Hooks

The blackdot hook system provides a higher-level abstraction over native ZSH hooks:

| Dotfiles Hook | Underlying ZSH Mechanism |
|---------------|-------------------------|
| `shell_init` | Sourced at end of `.zshrc` |
| `shell_exit` | `zshexit_functions` array |
| `directory_change` | `chpwd_functions` array |

**Why use blackdot hooks instead of native?**

1. **File-based organization** - Hooks live in `~/.config/dotfiles/hooks/`, not scattered in `.zshrc`
2. **Easy enable/disable** - Toggle with `blackdot features` or JSON config
3. **Ordering control** - Numeric prefixes (10-, 20-, 90-) guarantee execution order
4. **Visibility** - `blackdot hook list` shows all registered hooks
5. **Testing** - `blackdot hook test` validates hooks without running them
6. **Feature gating** - Hooks respect the Feature Registry

### Using Both Systems Together

You can use native ZSH hooks alongside blackdot hooks:

```zsh
# In ~/.zshrc.local - use native hooks for fast, inline operations
autoload -Uz add-zsh-hook

# Fast inline hook (native)
_update_title() {
    print -Pn "\e]0;%~\a"  # Set terminal title to current dir
}
add-zsh-hook precmd _update_title

# Complex hook (blackdot system) - lives in separate file
# ~/.config/dotfiles/hooks/directory_change/10-project-env.zsh
```

**Best practice:** Use native hooks for simple, fast operations that need to run on every prompt. Use blackdot hooks for more complex, configurable behavior.

### Performance Considerations

Native ZSH hooks run synchronously and can affect shell responsiveness:

```zsh
# BAD: Slow hook blocks every prompt
_slow_precmd() {
    git fetch origin 2>/dev/null  # Network call on every prompt!
}

# GOOD: Background the slow operation
_fast_precmd() {
    (git fetch origin 2>/dev/null &)
}

# BETTER: Only run periodically
PERIOD=300  # Every 5 minutes
_periodic_fetch() {
    git fetch origin 2>/dev/null
}
add-zsh-hook periodic _periodic_fetch
```

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
source "$BLACKDOT_DIR/lib/_hooks.sh"

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
blackdot hook list

# List hooks for a specific point
blackdot hook list post_vault_pull

# Run hooks for a point
blackdot hook run post_vault_pull

# Run with verbose output
blackdot hook run --verbose post_vault_pull

# Test hooks (shows what would run)
blackdot hook test post_vault_pull
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
# Add custom checks to blackdot doctor

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

- **Hooks are a feature** - Enable/disable with `blackdot features enable/disable hooks`
- **Parent feature gating** - Vault hooks only run if `vault` feature is enabled
- **Feature checks in hooks** - Use `feature_enabled "name"` in your hook scripts

```bash
# Disable all hooks
blackdot features disable hooks

# Re-enable hooks
blackdot features enable hooks --persist
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
| `BLACKDOT_HOOKS_VERBOSE` | `false` | Enable verbose hook output |
| `BLACKDOT_HOOKS_DISABLED` | `false` | Disable all hooks |
| `BLACKDOT_HOOKS_FAIL_FAST` | `false` | Stop on first failure |

---

## Troubleshooting

### Hook not running?

1. **Check it's executable:** `chmod +x ~/.config/dotfiles/hooks/<point>/<script>`
2. **Check feature enabled:** `blackdot features | grep hooks`
3. **Check parent feature:** Vault hooks require `vault` feature enabled
4. **Test manually:** `blackdot hook test <point>`

### Hook failing silently?

Run with verbose mode:
```bash
blackdot hook run --verbose <point>
```

### View registered hooks

```bash
blackdot hook list        # All hooks
blackdot hook list <point> # Specific point
```

---

## Best Practices

1. **Use numeric prefixes** for execution order (10-, 20-, 50-, 90-)
2. **Set `fail_ok: true`** for non-critical hooks
3. **Keep hooks fast** - Shell init hooks affect startup time
4. **Use verbose logging** during development
5. **Test hooks** before relying on them: `blackdot hook test <point>`

---

## See Also

- [Feature Registry](features.md) - Control plane for hook feature
- [CLI Reference](cli-reference.md) - Full `blackdot hook` command reference
- [Design Document](design/IMPL-hook-system.md) - Implementation details
