# Deep Modularity Architecture

> **Goal:** Make this the most modular, opt-in dotfiles system ever engineered.

## Design Principles

1. **Opt-in by default** - Features are disabled until explicitly enabled
2. **Additive composition** - Enable features independently, in any combination
3. **Zero coupling** - Each module works standalone without dependencies
4. **Graceful degradation** - Missing dependencies don't break the system
5. **Configuration layers** - Defaults < User < Machine < Project < Session
6. **Plugin architecture** - Users can add custom modules

---

## Current State Analysis

### What's Already Modular
- Setup wizard (7 steps, each skippable)
- SKIP_* environment variables
- Brewfile tiers (minimal/enhanced/full)
- WORKSPACE_TARGET configurability
- Template system for machine-specific configs
- ZSH modules (00-99 numbered load order)

### What Needs Improvement
- Features are "all or nothing" in some areas
- No central feature registry
- Limited plugin/extension support
- Hard to add custom modules without forking

---

## Proposed Architecture

### 1. Feature Registry (`lib/_features.sh`)

Central registry of all optional features with enable/disable control:

```bash
# Feature definition structure
typeset -gA DOTFILES_FEATURES=(
    # Core (always enabled)
    [shell]=true                  # ZSH + prompt + aliases

    # Opt-in features (default: false)
    [vault]=false                 # Multi-vault secret management
    [workspace_symlink]=false     # /workspace symlink
    [claude_integration]=false    # Claude Code + dotclaude
    [templates]=false             # Machine-specific configs
    [aws_helpers]=false           # AWS SSO helpers
    [git_hooks]=false             # Pre-commit/push hooks
    [health_metrics]=false        # dotfiles metrics collection
    [backup_auto]=false           # Automatic backups
)

# Feature metadata
typeset -gA FEATURE_DEPS=(
    [vault]=""                    # No dependencies
    [claude_integration]="workspace_symlink"
    [templates]=""
    [aws_helpers]=""
    [git_hooks]=""
)

# Check if feature is enabled
feature_enabled() {
    local feature="$1"
    [[ "${DOTFILES_FEATURES[$feature]:-false}" == "true" ]]
}

# Enable a feature (with dependency resolution)
feature_enable() {
    local feature="$1"
    local deps="${FEATURE_DEPS[$feature]:-}"

    # Enable dependencies first
    for dep in ${(s: :)deps}; do
        feature_enable "$dep"
    done

    DOTFILES_FEATURES[$feature]=true
    config_set "features.$feature" "true"
}
```

### 2. Configuration Layers

Priority order (highest wins):
```
1. Session     (environment variables)
2. Project     (.dotfiles.local in project dir)
3. Machine     (~/.config/dotfiles/machine.json)
4. User        (~/.config/dotfiles/config.json)
5. Defaults    (lib/_config.sh defaults)
```

```bash
# Example: Get a config value with layer resolution
config_get_layered() {
    local key="$1"
    local default="$2"

    # 1. Check environment
    local env_key="DOTFILES_${key^^}"
    env_key="${env_key//./_}"
    [[ -n "${(P)env_key:-}" ]] && { echo "${(P)env_key}"; return; }

    # 2. Check project config
    [[ -f ".dotfiles.local" ]] && {
        local val=$(jq -r ".$key // empty" .dotfiles.local 2>/dev/null)
        [[ -n "$val" ]] && { echo "$val"; return; }
    }

    # 3. Check machine config
    [[ -f "$CONFIG_DIR/machine.json" ]] && {
        local val=$(jq -r ".$key // empty" "$CONFIG_DIR/machine.json" 2>/dev/null)
        [[ -n "$val" ]] && { echo "$val"; return; }
    }

    # 4. Check user config
    [[ -f "$CONFIG_FILE" ]] && {
        local val=$(jq -r ".$key // empty" "$CONFIG_FILE" 2>/dev/null)
        [[ -n "$val" ]] && { echo "$val"; return; }
    }

    # 5. Default
    echo "$default"
}
```

### 3. Plugin System (`plugins/`)

Allow users to add custom functionality:

```
plugins/
├── README.md                    # How to create plugins
├── available/                   # All available plugins
│   ├── docker-helpers/
│   │   ├── plugin.json         # Metadata
│   │   ├── install.sh          # Optional install script
│   │   └── docker.zsh          # ZSH module
│   ├── kubernetes/
│   └── terraform/
└── enabled/                     # Symlinks to enabled plugins
    └── docker-helpers -> ../available/docker-helpers
```

**Plugin manifest (`plugin.json`):**
```json
{
    "name": "docker-helpers",
    "version": "1.0.0",
    "description": "Docker aliases and functions",
    "author": "user",
    "dependencies": {
        "commands": ["docker"],
        "features": []
    },
    "files": {
        "zsh": "docker.zsh",
        "install": "install.sh"
    }
}
```

**Plugin commands:**
```bash
dotfiles plugin list              # List available plugins
dotfiles plugin enable <name>     # Enable a plugin
dotfiles plugin disable <name>    # Disable a plugin
dotfiles plugin create <name>     # Scaffold new plugin
```

### 4. Lazy Loading

Only load modules when needed:

```bash
# In zshrc - lazy load heavy modules
_load_aws_helpers() {
    unfunction awsswitch awsprofiles awswho 2>/dev/null
    source "$DOTFILES_DIR/zsh/zsh.d/60-aws.zsh"
}

# Stub functions that trigger lazy load
awsswitch() { _load_aws_helpers; awsswitch "$@"; }
awsprofiles() { _load_aws_helpers; awsprofiles "$@"; }
awswho() { _load_aws_helpers; awswho "$@"; }
```

### 5. Module System (`modules/`)

Refactor ZSH config into independent modules:

```
modules/
├── core/                        # Always loaded
│   ├── 00-init.zsh
│   ├── 10-env.zsh
│   └── 20-aliases.zsh
├── optional/                    # Loaded if feature enabled
│   ├── aws/
│   │   ├── module.json
│   │   └── aws.zsh
│   ├── claude/
│   ├── git-extras/
│   └── modern-cli/
└── local/                       # User's custom modules (gitignored)
    └── *.zsh
```

**Module manifest (`module.json`):**
```json
{
    "name": "aws",
    "feature": "aws_helpers",
    "load_order": 60,
    "dependencies": ["aws-cli"],
    "lazy": true
}
```

### 6. Hook System

Allow users to inject behavior at key points:

```bash
# Hook points
HOOK_POINTS=(
    "pre_install"
    "post_install"
    "pre_bootstrap"
    "post_bootstrap"
    "pre_vault_pull"
    "post_vault_pull"
    "pre_doctor"
    "post_doctor"
    "shell_init"
    "shell_exit"
)

# Register a hook
hook_register() {
    local point="$1"
    local callback="$2"

    typeset -ga "HOOKS_${point}"
    eval "HOOKS_${point}+=('$callback')"
}

# Run hooks at a point
hook_run() {
    local point="$1"
    shift

    local hooks_var="HOOKS_${point}"
    local hooks=("${(P)hooks_var[@]}")

    for hook in "${hooks[@]}"; do
        "$hook" "$@"
    done
}

# Example usage in user's config:
# ~/.config/dotfiles/hooks.zsh
my_post_vault_pull() {
    echo "Vault pull complete!"
    # Custom logic here
}
hook_register "post_vault_pull" "my_post_vault_pull"
```

---

## Implementation Phases

### Phase 1: Feature Registry (Week 1)
- [ ] Create `lib/_features.sh` with feature definitions
- [ ] Add feature checks to all optional components
- [ ] Update setup wizard to use feature registry
- [ ] Add `dotfiles features` command

### Phase 2: Configuration Layers (Week 2)
- [ ] Implement `config_get_layered()` function
- [ ] Add machine.json support
- [ ] Add project-level .dotfiles.local support
- [ ] Document configuration precedence

### Phase 3: Plugin System (Week 3)
- [ ] Create plugins/ directory structure
- [ ] Implement plugin loading in zshrc
- [ ] Add `dotfiles plugin` subcommand
- [ ] Create 3-5 example plugins

### Phase 4: Module Refactor (Week 4)
- [ ] Restructure zsh.d/ into modules/
- [ ] Add module.json manifests
- [ ] Implement lazy loading for heavy modules
- [ ] Add `dotfiles module` subcommand

### Phase 5: Hook System (Week 5)
- [ ] Implement hook registration/execution
- [ ] Add hook points throughout codebase
- [ ] Document hook API
- [ ] Create example hooks

---

## New Commands

```bash
# Feature management
dotfiles features                 # List all features and status
dotfiles features enable <name>   # Enable a feature
dotfiles features disable <name>  # Disable a feature

# Plugin management
dotfiles plugin list              # List available/enabled plugins
dotfiles plugin enable <name>     # Enable a plugin
dotfiles plugin disable <name>    # Disable a plugin
dotfiles plugin create <name>     # Create new plugin scaffold

# Module management
dotfiles module list              # List all modules
dotfiles module enable <name>     # Enable a module
dotfiles module disable <name>    # Disable a module
dotfiles module reload            # Reload all modules

# Configuration
dotfiles config                   # Show current config (all layers)
dotfiles config get <key>         # Get a config value
dotfiles config set <key> <value> # Set a config value
dotfiles config layers            # Show which layer each setting comes from
```

---

## Example: Enabling Features

### Via Setup Wizard
```
Setup Wizard - Feature Selection

Select features to enable (space to toggle, enter to confirm):

  [x] Shell Config (required)
  [ ] Vault Integration
  [ ] Portable Sessions (/workspace)
  [ ] Claude Code Integration
  [ ] AWS Helpers
  [ ] Template System
  [ ] Git Safety Hooks
  [ ] Health Metrics

Features can be enabled/disabled anytime with:
  dotfiles features enable <name>
```

### Via Command Line
```bash
# Enable specific features
dotfiles features enable vault
dotfiles features enable claude_integration

# Enable a preset (group of features)
dotfiles features preset developer  # vault, aws_helpers, git_hooks
dotfiles features preset claude     # vault, workspace_symlink, claude_integration
```

### Via Config File
```json
{
    "features": {
        "vault": true,
        "workspace_symlink": true,
        "claude_integration": true,
        "aws_helpers": false,
        "templates": true
    }
}
```

---

## Backward Compatibility

- All existing functionality remains as-is
- SKIP_* environment variables still work
- Current config.json format is preserved
- New features are opt-in only

---

## Success Criteria

1. **Zero coupling**: Any feature can be disabled without breaking others
2. **Fast startup**: Shell loads in <100ms even with all features
3. **Easy extension**: Users can add plugins without forking
4. **Clear documentation**: Every feature has clear enable/disable docs
5. **Graceful degradation**: Missing dependencies show helpful messages
6. **Layer visibility**: `dotfiles config layers` shows where each setting comes from

---

## Comparison: Before vs After

| Aspect | Before | After |
|--------|--------|-------|
| Feature control | SKIP_* env vars | Unified feature registry |
| Configuration | Single config.json | Layered (session > project > machine > user) |
| Extensions | Fork the repo | Plugin system |
| Module loading | All at once | Lazy loading |
| Customization | Edit source files | Hook system |
| Discovery | Read the README | `dotfiles features list` |

---

**Status:** Design document - ready for review and implementation planning.
