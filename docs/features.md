# Feature Registry

> **Deep Modularity:** Every optional feature can be enabled or disabled independently, without breaking other parts of the system.

The Feature Registry (`lib/_features.sh`) is the control plane for the dotfiles framework. All optional functionality flows through it—enabling, disabling, dependency resolution, and persistence.

The registry provides:

- **Opt-in by default** - Features are disabled until explicitly enabled
- **SKIP_* compatibility** - Existing environment variables still work
- **Runtime control** - Enable/disable features without editing files
- **Presets** - Enable common feature combinations with one command
- **Dependency resolution** - Automatically enables required dependencies

---

## Quick Start

```bash
# List all features and their status
dotfiles features

# Enable a feature (runtime only)
dotfiles features enable vault

# Enable and persist to config file
dotfiles features enable vault --persist

# Enable a preset (group of features)
dotfiles features preset developer

# Check if a feature is enabled (for scripts)
if dotfiles features check vault; then
    echo "Vault is enabled"
fi
```

---

## Feature Categories

### Core (Always Enabled)

| Feature | Description |
|---------|-------------|
| `shell` | ZSH shell, prompt, and core aliases |

Core features cannot be disabled—they're essential for the dotfiles system to function.

### Optional Features

| Feature | Description | Dependencies |
|---------|-------------|--------------|
| `workspace_symlink` | `/workspace` symlink for portable Claude sessions | - |
| `claude_integration` | Claude Code integration and hooks | `workspace_symlink` |
| `vault` | Multi-vault secret management (Bitwarden/1Password/pass) | - |
| `encryption` | Age encryption for non-vault secrets (template vars, local configs) | - |
| `templates` | Machine-specific configuration templates | - |
| `hooks` | Lifecycle hooks for custom behavior at key events | - |
| `git_hooks` | Git safety hooks (pre-commit, pre-push) | - |
| `drift_check` | Automatic drift detection on vault operations | `vault` |
| `backup_auto` | Automatic backup before destructive operations | - |
| `health_metrics` | Health check metrics collection and trending | - |
| `macos_settings` | macOS system preferences automation | - |
| `config_layers` | Hierarchical configuration resolution (env>project>machine>user) | - |
| `cli_feature_filter` | Filter CLI help and commands based on enabled features | - |

### Integrations

| Feature | Description | Dependencies |
|---------|-------------|--------------|
| `modern_cli` | Modern CLI tools (eza, bat, ripgrep, fzf, zoxide) | - |
| `aws_helpers` | AWS SSO profile management and helpers | - |
| `cdk_tools` | AWS CDK aliases, helpers, and environment management | `aws_helpers` |
| `rust_tools` | Rust/Cargo aliases and helpers (build, test, clippy, watch) | - |
| `go_tools` | Go aliases and helpers (build, test, coverage, modules) | - |
| `nvm_integration` | Lazy-loaded NVM for Node.js version management | - |
| `sdkman_integration` | Lazy-loaded SDKMAN for Java/Gradle/Kotlin | - |
| `dotclaude` | dotclaude profile management for Claude Code | `claude_integration` |

---

## Commands

### List Features

```bash
# List all features with status
dotfiles features
dotfiles features list

# Filter by category
dotfiles features list core
dotfiles features list optional
dotfiles features list integration

# Show with dependencies
dotfiles features list --all

# Output as JSON (for scripting)
dotfiles features list --json
```

### Enable/Disable Features

```bash
# Enable at runtime (doesn't persist across shell sessions)
dotfiles features enable vault

# Enable and save to config file
dotfiles features enable vault --persist

# Disable a feature
dotfiles features disable vault
dotfiles features disable vault --persist
```

### Presets

Presets enable groups of related features:

```bash
# List available presets
dotfiles features preset --list

# Enable a preset
dotfiles features preset developer
dotfiles features preset developer --persist
```

**Available Presets:**

| Preset | Features Enabled |
|--------|------------------|
| `minimal` | `shell` |
| `developer` | `shell`, `vault`, `aws_helpers`, `git_hooks`, `modern_cli` |
| `claude` | `shell`, `workspace_symlink`, `claude_integration`, `vault`, `git_hooks`, `modern_cli` |
| `full` | All features |

### Check Feature Status

For use in scripts:

```bash
# Returns exit code 0 if enabled, 1 if disabled
if dotfiles features check vault; then
    # Vault is enabled, do something
    dotfiles vault pull
fi
```

---

## Environment Variables

Features can be controlled via environment variables, providing backward compatibility with existing `SKIP_*` patterns:

### SKIP_* Variables (Backward Compatibility)

| Variable | Feature | Effect |
|----------|---------|--------|
| `SKIP_WORKSPACE_SYMLINK=true` | `workspace_symlink` | Disables feature |
| `SKIP_CLAUDE_SETUP=true` | `claude_integration` | Disables feature |
| `DOTFILES_SKIP_DRIFT_CHECK=1` | `drift_check` | Disables feature |

### Direct Feature Control

Enable or disable any feature directly:

```bash
# Enable a feature
export DOTFILES_FEATURE_VAULT=true

# Disable a feature
export DOTFILES_FEATURE_AWS_HELPERS=false
```

---

## Configuration File

Features can be persisted in `~/.config/dotfiles/config.json`:

```json
{
  "version": 3,
  "features": {
    "vault": true,
    "workspace_symlink": true,
    "claude_integration": true,
    "templates": false
  }
}
```

Use `dotfiles features enable <name> --persist` to update this file automatically.

---

## Priority Order

When checking if a feature is enabled, the system checks in this order (highest priority first):

1. **Runtime state** - `feature_enable`/`feature_disable` in current session
2. **Environment variables** - `DOTFILES_FEATURE_*` or `SKIP_*` vars
3. **Config file** - `~/.config/dotfiles/config.json`
4. **Registry defaults** - Built-in defaults in `lib/_features.sh`

---

## Using Features in Scripts

### Feature Guards

Use feature guards to conditionally run code:

```bash
#!/usr/bin/env zsh
source "$DOTFILES_DIR/lib/_features.sh"

# Skip if feature not enabled
feature_guard "vault" || return 0

# Now safe to use vault functionality
vault_pull
```

### Checking Dependencies

```bash
# Check if all dependencies are met
if feature_deps_met "claude_integration"; then
    echo "All dependencies satisfied"
fi

# Get list of missing dependencies
missing=$(feature_missing_deps "claude_integration")
if [[ -n "$missing" ]]; then
    echo "Missing: $missing"
fi
```

### JSON Status for Scripting

```bash
# Get all features as JSON
dotfiles features list --json | jq '.vault.enabled'

# Get specific feature status
dotfiles features status vault
```

---

## Adding New Features

To add a new feature to the registry, edit `lib/_features.sh`:

```bash
typeset -gA FEATURE_REGISTRY=(
    # ... existing features ...

    # Add your new feature
    ["my_feature"]="false|Description of my feature|optional|dependency1 dependency2"
)
```

Format: `"default|description|category|dependencies"`

- **default**: `true`, `false`, or `env` (check env var)
- **category**: `core`, `optional`, or `integration`
- **dependencies**: Space-separated list of required features

---

## Examples

### Minimal Installation

```bash
# Install with just shell config
curl -fsSL .../install.sh | bash -s -- --minimal

# Later, enable only what you need
dotfiles features enable vault --persist
dotfiles features enable modern_cli --persist
```

### Developer Workstation

```bash
# Enable developer preset
dotfiles features preset developer --persist

# Check what's enabled
dotfiles features
```

### Claude Code User

```bash
# Enable claude preset (includes workspace_symlink, vault, git_hooks)
dotfiles features preset claude --persist

# Verify
dotfiles features list optional
```

### CI/CD Environment

```bash
# Disable interactive features
export SKIP_WORKSPACE_SYMLINK=true
export DOTFILES_SKIP_DRIFT_CHECK=1

# Or use minimal preset
dotfiles features preset minimal
```

---

## Troubleshooting

### Feature Won't Enable

1. Check if it's a core feature (cannot be disabled)
2. Check if dependencies are met: `dotfiles features status <feature>`
3. Check environment variables: `env | grep -E 'SKIP_|DOTFILES_FEATURE_'`

### Changes Don't Persist

Use `--persist` flag:
```bash
dotfiles features enable vault --persist
```

### Feature Enabled But Not Working

Some features require a shell restart:
```bash
exec zsh
```

Or source the feature registry:
```bash
source "$DOTFILES_DIR/lib/_features.sh"
```

---

## Related Systems

The Feature Registry works with two companion systems:

### Configuration Layers

The Configuration Layers system (`lib/_config_layers.sh`) provides a 5-layer priority hierarchy for settings. Features use layered config for their preferences:

```bash
config_get_layered "vault.backend"  # Checks all layers in priority order
```

See [Architecture](architecture.md#configuration-layers) for details.

### Claude Code Integration

The Claude Code integration provides portable AI-assisted development across machines:

- **Portable sessions** – `/workspace` symlink for consistent paths everywhere
- **Profile management** – [dotclaude](https://github.com/blackwell-systems/dotclaude) for multiple contexts
- **Git safety hooks** – PreToolUse blocks dangerous commands like `git push --force`
- **Multi-backend** – Works with Anthropic Max, AWS Bedrock, Google Vertex AI

```bash
dotfiles setup   # Step 6: Claude Code integration
dotfiles doctor  # Validates Claude setup
```

See [Claude Code + dotclaude](claude-code.md) for the full guide.

---

**Questions?** See the [CLI Reference](cli-reference.md) or [open an issue](https://github.com/blackwell-systems/dotfiles/issues).
