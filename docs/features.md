# Feature Registry

> **Deep Modularity:** Every optional feature can be enabled or disabled independently, without breaking other parts of the system.

The Feature Registry (`internal/feature/registry.go`) is the control plane for blackdot. All optional functionality flows through it—enabling, disabling, dependency resolution, and persistence. Implemented in Go for cross-platform consistency.

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
blackdot features

# Enable a feature (runtime only)
blackdot features enable vault

# Enable and persist to config file
blackdot features enable vault --persist

# Enable a preset (group of features)
blackdot features preset developer

# Check if a feature is enabled (for scripts)
if blackdot features check vault; then
    echo "Vault is enabled"
fi
```

---

## Feature Categories

### Core (Always Enabled)

| Feature | Description |
|---------|-------------|
| `shell` | ZSH shell, prompt, and core aliases |

Core features cannot be disabled—they're essential for the blackdot system to function.

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
| `python_tools` | Python/uv aliases, pytest helpers, auto-venv activation | - |
| `ssh_tools` | SSH config, key management, agent, and tunnel helpers | - |
| `docker_tools` | Docker container, compose, and network management | - |
| `nvm_integration` | Lazy-loaded NVM for Node.js version management | - |
| `sdkman_integration` | Lazy-loaded SDKMAN for Java/Gradle/Kotlin | - |
| `dotclaude` | dotclaude profile management for Claude Code | `claude_integration` |

---

## Commands

### List Features

```bash
# List all features with status
blackdot features
blackdot features list

# Filter by category
blackdot features list core
blackdot features list optional
blackdot features list integration

# Show with dependencies
blackdot features list --all

# Output as JSON (for scripting)
blackdot features list --json
```

### Enable/Disable Features

```bash
# Enable at runtime (doesn't persist across shell sessions)
blackdot features enable vault

# Enable and save to config file
blackdot features enable vault --persist

# Disable a feature
blackdot features disable vault
blackdot features disable vault --persist
```

### Presets

Presets enable groups of related features:

```bash
# List available presets
blackdot features preset --list

# Enable a preset
blackdot features preset developer
blackdot features preset developer --persist
```

**Available Presets:**

| Preset | Features Enabled |
|--------|------------------|
| `minimal` | `shell`, `config_layers` |
| `developer` | `shell`, `vault`, `aws_helpers`, `cdk_tools`, `rust_tools`, `go_tools`, `python_tools`, `ssh_tools`, `docker_tools`, `nvm_integration`, `sdkman_integration`, `git_hooks`, `modern_cli`, `config_layers` |
| `claude` | `shell`, `workspace_symlink`, `claude_integration`, `vault`, `git_hooks`, `modern_cli`, `config_layers` |
| `full` | All features |

### Check Feature Status

For use in scripts:

```bash
# Returns exit code 0 if enabled, 1 if disabled
if blackdot features check vault; then
    # Vault is enabled, do something
    blackdot vault pull
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
| `BLACKDOT_SKIP_DRIFT_CHECK=1` | `drift_check` | Disables feature |

### Direct Feature Control

Enable or disable any feature directly:

```bash
# Enable a feature
export BLACKDOT_FEATURE_VAULT=true

# Disable a feature
export BLACKDOT_FEATURE_AWS_HELPERS=false
```

---

## Configuration File

Features can be persisted in `~/.config/blackdot/config.json`:

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

Use `blackdot features enable <name> --persist` to update this file automatically.

---

## Priority Order

When checking if a feature is enabled, the Go CLI checks in this order (highest priority first):

1. **Runtime state** - `feature_enable`/`feature_disable` in current session
2. **Environment variables** - `BLACKDOT_FEATURE_*` or `SKIP_*` vars
3. **Config file** - `~/.config/blackdot/config.json`
4. **Registry defaults** - Built-in defaults in `internal/feature/registry.go`

---

## Using Features in Scripts

### Feature Guards (Shell)

Use feature guards to conditionally run code in shell scripts:

```bash
#!/usr/bin/env zsh
# feature_enabled is provided by: eval "$(blackdot shell-init)"

# Skip if feature not enabled
feature_enabled "vault" || return 0

# Now safe to use vault functionality
blackdot vault pull
```

**Note:** `feature_enabled` is a shell function that calls the Go binary. It's automatically available when you load the shell config.

### Checking Dependencies (Go CLI)

```bash
# Check if all dependencies are met
blackdot features status claude_integration

# Get specific feature status
blackdot features check vault && echo "Vault enabled"
```

### JSON Status for Scripting

```bash
# Get all features as JSON
blackdot features list --json | jq '.vault.enabled'

# Get specific feature status
blackdot features status vault
```

---

## Adding New Features

To add a new feature to the registry, edit `internal/feature/registry.go` in the `NewRegistry()` function:

```go
func NewRegistry() *Registry {
    r := &Registry{
        features:  make(map[string]*Feature),
        enabled:   make(map[string]bool),
        conflicts: make(map[string][]string),
        envMap:    make(map[string]string),
    }

    // Add your new feature
    r.register("my_feature", CategoryOptional, "Description of my feature",
        []string{"dependency1", "dependency2"}, DefaultFalse)

    return r
}
```

**Parameters:**
- **Name**: Feature identifier (lowercase with underscores)
- **Category**: `CategoryCore`, `CategoryOptional`, or `CategoryIntegration`
- **Description**: Brief description shown in `blackdot features list`
- **Dependencies**: Slice of required feature names (or `nil`)
- **Default**: `DefaultTrue`, `DefaultFalse`, or `DefaultEnv` (check env var)

---

## Examples

### Minimal Installation

```bash
# Install with just shell config
curl -fsSL .../install.sh | bash -s -- --minimal

# Later, enable only what you need
blackdot features enable vault --persist
blackdot features enable modern_cli --persist
```

### Developer Workstation

```bash
# Enable developer preset
blackdot features preset developer --persist

# Check what's enabled
blackdot features
```

### Claude Code User

```bash
# Enable claude preset (includes workspace_symlink, vault, git_hooks)
blackdot features preset claude --persist

# Verify
blackdot features list optional
```

### CI/CD Environment

```bash
# Disable interactive features
export SKIP_WORKSPACE_SYMLINK=true
export BLACKDOT_SKIP_DRIFT_CHECK=1

# Or use minimal preset
blackdot features preset minimal
```

---

## Troubleshooting

### Feature Won't Enable

1. Check if it's a core feature (cannot be disabled)
2. Check if dependencies are met: `blackdot features status <feature>`
3. Check environment variables: `env | grep -E 'SKIP_|BLACKDOT_FEATURE_'`

### Changes Don't Persist

Use `--persist` flag:
```bash
blackdot features enable vault --persist
```

### Feature Enabled But Not Working

Some features require a shell restart:
```bash
exec zsh
```

Or reload shell initialization:
```bash
eval "$(blackdot shell-init)"
```

---

## Related Systems

The Feature Registry works with two companion systems:

### Configuration Layers

The Configuration Layers system (`internal/config/config.go`) provides a 5-layer priority hierarchy for settings. Features use layered config for their preferences:

```bash
blackdot config get vault.backend    # Get config value
blackdot config show vault.backend   # Show all layers
```

See [Architecture](architecture.md#configuration-layers) for details.

### Claude Code Integration

The Claude Code integration provides portable AI-assisted development across machines:

- **Portable sessions** – `/workspace` symlink for consistent paths everywhere
- **Profile management** – [dotclaude](https://github.com/blackwell-systems/dotclaude) for multiple contexts
- **Git safety hooks** – PreToolUse blocks dangerous commands like `git push --force`
- **Multi-backend** – Works with Anthropic Max, AWS Bedrock, Google Vertex AI

```bash
blackdot setup   # Step 6: Claude Code integration
blackdot doctor  # Validates Claude setup
```

See [Claude Code + dotclaude](claude-code.md) for the full guide.

---

**Questions?** See the [CLI Reference](cli-reference.md) or [open an issue](https://github.com/blackwell-systems/blackdot/issues).
