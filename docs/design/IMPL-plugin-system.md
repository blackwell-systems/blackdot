# Plugin System Implementation

> **Status:** Not Started
> **Priority:** High
> **Complexity:** High
> **Target:** v2.2.0
> **Foundation:** [Feature Registry](../features.md) (v2.1.0)

## Overview

The plugin system allows users to extend dotfiles functionality without forking the repository. Plugins are self-contained packages that can add shell functions, aliases, completions, and integrations.

---

## Architecture Foundation

The Plugin System builds on the **Feature Registry** (`lib/_features.sh`) which serves as the control plane for the entire modular architecture:

```
┌─────────────────────────────────────────────┐
│         Feature Registry (v2.1.0)            │
│   - Tracks enabled/disabled features         │
│   - Resolves dependencies                    │
│   - Persists state to config.json            │
└─────────────────┬───────────────────────────┘
                  │ controls
                  ▼
┌─────────────────────────────────────────────┐
│           Plugin System (this doc)           │
│   - Each plugin maps to a feature            │
│   - Uses feature_enabled() for load checks   │
│   - Registers as "integration" category      │
└─────────────────────────────────────────────┘
```

**Key integration points:**
- Plugins register themselves as features in the `integration` category
- `plugin_load()` checks `feature_enabled()` before loading
- Plugin dependencies can require other features (not just commands)
- `blackdot features enable <plugin>` enables a plugin's feature

---

## Goals

1. **Zero-fork extensibility** - Users add functionality without modifying core
2. **Dependency management** - Plugins declare required commands/features
3. **Safe loading** - Malformed plugins don't break the shell
4. **Discoverability** - Easy to find, enable, and manage plugins

---

## Directory Structure

```
plugins/
├── README.md                    # Plugin development guide
├── available/                   # All available plugins (shipped + user-added)
│   ├── docker-helpers/
│   │   ├── plugin.json          # Manifest (required)
│   │   ├── init.zsh             # Main entry point (required)
│   │   ├── completions/         # Optional completions
│   │   │   └── _docker-helpers
│   │   └── README.md            # Plugin documentation
│   ├── kubernetes/
│   ├── terraform/
│   └── node-helpers/
├── enabled/                     # Symlinks to enabled plugins
│   └── docker-helpers -> ../available/docker-helpers
└── local/                       # User's custom plugins (gitignored)
    └── my-company-tools/
```

---

## Plugin Manifest (`plugin.json`)

```json
{
  "name": "docker-helpers",
  "version": "1.0.0",
  "description": "Docker aliases, functions, and completions",
  "author": "Dotfiles Team",
  "license": "MIT",
  "homepage": "https://github.com/example/dotfiles",

  "dependencies": {
    "commands": ["docker"],
    "features": [],
    "plugins": []
  },

  "provides": {
    "commands": ["dps", "dex", "dlog", "dclean"],
    "aliases": ["dc", "dco"],
    "functions": ["docker_cleanup", "docker_shell"]
  },

  "config": {
    "docker.default_shell": {
      "type": "string",
      "default": "/bin/sh",
      "description": "Default shell for docker exec"
    },
    "docker.cleanup_days": {
      "type": "number",
      "default": 7,
      "description": "Remove images older than N days"
    }
  },

  "hooks": {
    "post_install": "scripts/post-install.sh",
    "pre_uninstall": "scripts/pre-uninstall.sh"
  }
}
```

### Manifest Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique plugin identifier (lowercase, hyphens) |
| `version` | Yes | Semver version string |
| `description` | Yes | Short description (< 100 chars) |
| `author` | No | Author name or organization |
| `license` | No | SPDX license identifier |
| `homepage` | No | URL for plugin documentation |
| `dependencies.commands` | No | Required CLI tools (checked before loading) |
| `dependencies.features` | No | Required dotfiles features |
| `dependencies.plugins` | No | Other plugins this depends on |
| `provides.commands` | No | Commands this plugin adds (for docs) |
| `provides.aliases` | No | Aliases this plugin adds |
| `provides.functions` | No | Functions this plugin adds |
| `config` | No | Plugin-specific configuration schema |
| `hooks` | No | Lifecycle hook scripts |

---

## Plugin Entry Point (`init.zsh`)

```zsh
# plugins/available/docker-helpers/init.zsh
# Docker Helpers Plugin

# Guard: only load if docker is available
(( $+commands[docker] )) || return 0

# Plugin configuration (with defaults from manifest)
local default_shell="${DOTFILES_PLUGIN_DOCKER_DEFAULT_SHELL:-/bin/sh}"
local cleanup_days="${DOTFILES_PLUGIN_DOCKER_CLEANUP_DAYS:-7}"

# Aliases
alias dc='docker compose'
alias dco='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# Functions
dex() {
    local container="${1:?Container name required}"
    local shell="${2:-$default_shell}"
    docker exec -it "$container" "$shell"
}

dlog() {
    local container="${1:?Container name required}"
    local lines="${2:-100}"
    docker logs -f --tail "$lines" "$container"
}

dclean() {
    echo "Removing stopped containers..."
    docker container prune -f
    echo "Removing dangling images..."
    docker image prune -f
    echo "Removing images older than ${cleanup_days} days..."
    docker image prune -a -f --filter "until=${cleanup_days}d"
}

# Completions (if in completions/ directory, auto-loaded)
```

---

## Library Implementation (`lib/_plugins.sh`)

```zsh
#!/usr/bin/env zsh
# lib/_plugins.sh - Plugin system library

# Plugin directories
PLUGINS_DIR="${BLACKDOT_DIR}/plugins"
PLUGINS_AVAILABLE="${PLUGINS_DIR}/available"
PLUGINS_ENABLED="${PLUGINS_DIR}/enabled"
PLUGINS_LOCAL="${PLUGINS_DIR}/local"

# Loaded plugins tracking
typeset -gA LOADED_PLUGINS=()

#######################################
# List all available plugins
# Returns: plugin names, one per line
#######################################
plugin_list_available() {
    local dir
    for dir in "$PLUGINS_AVAILABLE"/*/ "$PLUGINS_LOCAL"/*/; do
        [[ -f "${dir}plugin.json" ]] && basename "$dir"
    done | sort -u
}

#######################################
# List enabled plugins
# Returns: plugin names, one per line
#######################################
plugin_list_enabled() {
    local link
    for link in "$PLUGINS_ENABLED"/*(N); do
        [[ -L "$link" ]] && basename "$link"
    done
}

#######################################
# Check if plugin is enabled
# Arguments: plugin_name
# Returns: 0 if enabled, 1 otherwise
#######################################
plugin_enabled() {
    local name="$1"
    [[ -L "${PLUGINS_ENABLED}/${name}" ]]
}

#######################################
# Get plugin directory
# Arguments: plugin_name
# Returns: path to plugin directory
#######################################
plugin_dir() {
    local name="$1"
    if [[ -d "${PLUGINS_LOCAL}/${name}" ]]; then
        echo "${PLUGINS_LOCAL}/${name}"
    elif [[ -d "${PLUGINS_AVAILABLE}/${name}" ]]; then
        echo "${PLUGINS_AVAILABLE}/${name}"
    fi
}

#######################################
# Read plugin manifest field
# Arguments: plugin_name, field (jq syntax)
# Returns: field value
#######################################
plugin_meta() {
    local name="$1"
    local field="$2"
    local dir=$(plugin_dir "$name")

    [[ -f "${dir}/plugin.json" ]] || return 1
    jq -r "$field // empty" "${dir}/plugin.json"
}

#######################################
# Check plugin dependencies
# Arguments: plugin_name
# Returns: 0 if satisfied, 1 with error message
#######################################
plugin_check_deps() {
    local name="$1"
    local dir=$(plugin_dir "$name")
    local missing=()

    # Check required commands
    local cmds=($(plugin_meta "$name" '.dependencies.commands[]?' 2>/dev/null))
    for cmd in "${cmds[@]}"; do
        (( $+commands[$cmd] )) || missing+=("command:$cmd")
    done

    # Check required features
    local features=($(plugin_meta "$name" '.dependencies.features[]?' 2>/dev/null))
    for feat in "${features[@]}"; do
        feature_enabled "$feat" || missing+=("feature:$feat")
    done

    # Check required plugins
    local plugins=($(plugin_meta "$name" '.dependencies.plugins[]?' 2>/dev/null))
    for plug in "${plugins[@]}"; do
        plugin_enabled "$plug" || missing+=("plugin:$plug")
    done

    if (( ${#missing[@]} > 0 )); then
        echo "Missing dependencies: ${missing[*]}" >&2
        return 1
    fi
    return 0
}

#######################################
# Enable a plugin
# Arguments: plugin_name
# Returns: 0 on success
#######################################
plugin_enable() {
    local name="$1"
    local dir=$(plugin_dir "$name")

    # Validate plugin exists
    if [[ -z "$dir" || ! -d "$dir" ]]; then
        echo "Plugin not found: $name" >&2
        return 1
    fi

    # Check manifest exists
    if [[ ! -f "${dir}/plugin.json" ]]; then
        echo "Invalid plugin (missing plugin.json): $name" >&2
        return 1
    fi

    # Check dependencies
    if ! plugin_check_deps "$name"; then
        return 1
    fi

    # Create enabled symlink
    mkdir -p "$PLUGINS_ENABLED"
    ln -sf "$dir" "${PLUGINS_ENABLED}/${name}"

    # Run post_install hook if exists
    local hook=$(plugin_meta "$name" '.hooks.post_install // empty')
    if [[ -n "$hook" && -x "${dir}/${hook}" ]]; then
        "${dir}/${hook}"
    fi

    echo "Enabled plugin: $name"
    echo "Restart shell or run: source ~/.zshrc"
}

#######################################
# Disable a plugin
# Arguments: plugin_name
# Returns: 0 on success
#######################################
plugin_disable() {
    local name="$1"
    local dir=$(plugin_dir "$name")

    if [[ ! -L "${PLUGINS_ENABLED}/${name}" ]]; then
        echo "Plugin not enabled: $name" >&2
        return 1
    fi

    # Run pre_uninstall hook if exists
    local hook=$(plugin_meta "$name" '.hooks.pre_uninstall // empty')
    if [[ -n "$hook" && -x "${dir}/${hook}" ]]; then
        "${dir}/${hook}"
    fi

    rm "${PLUGINS_ENABLED}/${name}"
    echo "Disabled plugin: $name"
    echo "Restart shell or run: source ~/.zshrc"
}

#######################################
# Load a plugin (called during shell init)
# Arguments: plugin_name
# Returns: 0 on success
#######################################
plugin_load() {
    local name="$1"
    local dir=$(plugin_dir "$name")

    # Skip if already loaded
    [[ -n "${LOADED_PLUGINS[$name]}" ]] && return 0

    # Check dependencies silently
    if ! plugin_check_deps "$name" 2>/dev/null; then
        return 1
    fi

    # Source init.zsh
    if [[ -f "${dir}/init.zsh" ]]; then
        source "${dir}/init.zsh"
        LOADED_PLUGINS[$name]=1
    fi

    # Load completions
    if [[ -d "${dir}/completions" ]]; then
        fpath=("${dir}/completions" $fpath)
    fi
}

#######################################
# Load all enabled plugins
# Called from zshrc
#######################################
plugin_load_all() {
    local name
    for name in $(plugin_list_enabled); do
        plugin_load "$name"
    done
}

#######################################
# Create plugin scaffold
# Arguments: plugin_name
#######################################
plugin_create() {
    local name="$1"
    local dir="${PLUGINS_LOCAL}/${name}"

    if [[ -d "$dir" ]]; then
        echo "Plugin already exists: $dir" >&2
        return 1
    fi

    mkdir -p "$dir/completions"

    # Create manifest
    cat > "${dir}/plugin.json" <<EOF
{
  "name": "${name}",
  "version": "0.1.0",
  "description": "Description of ${name}",
  "author": "$(git config user.name 2>/dev/null || echo 'Your Name')",

  "dependencies": {
    "commands": [],
    "features": [],
    "plugins": []
  },

  "provides": {
    "commands": [],
    "aliases": [],
    "functions": []
  }
}
EOF

    # Create init.zsh
    cat > "${dir}/init.zsh" <<'EOF'
#!/usr/bin/env zsh
# Plugin: ${name}

# Add your aliases, functions, and configuration here

EOF

    # Create README
    cat > "${dir}/README.md" <<EOF
# ${name}

Description of what this plugin does.

## Installation

\`\`\`bash
blackdot plugin enable ${name}
\`\`\`

## Usage

Document commands and functions here.
EOF

    echo "Created plugin scaffold: $dir"
    echo "Edit ${dir}/init.zsh to add functionality"
}
```

---

## CLI Command (`bin/blackdot-plugin`)

```bash
#!/usr/bin/env bash
# bin/blackdot-plugin - Plugin management CLI
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/_logging.sh"
source "${SCRIPT_DIR}/../lib/_plugins.sh"

usage() {
    cat <<EOF
Usage: dotfiles plugin <command> [args]

Commands:
  list                    List all plugins (available and enabled)
  enable <name>           Enable a plugin
  disable <name>          Disable a plugin
  create <name>           Create new plugin scaffold in plugins/local/
  info <name>             Show plugin details
  check <name>            Check plugin dependencies

Options:
  --json                  Output in JSON format
  -h, --help              Show this help

Examples:
  dotfiles plugin list
  dotfiles plugin enable docker-helpers
  dotfiles plugin create my-tools
  dotfiles plugin info kubernetes
EOF
}

cmd_list() {
    local show_json=false
    [[ "${1:-}" == "--json" ]] && show_json=true

    local available=($(plugin_list_available))
    local enabled=($(plugin_list_enabled))

    if $show_json; then
        echo '{"available":['
        local first=true
        for name in "${available[@]}"; do
            $first || echo ","
            first=false
            local is_enabled=false
            [[ " ${enabled[*]} " =~ " ${name} " ]] && is_enabled=true
            local desc=$(plugin_meta "$name" '.description // "No description"')
            local ver=$(plugin_meta "$name" '.version // "0.0.0"')
            printf '{"name":"%s","version":"%s","enabled":%s,"description":"%s"}' \
                "$name" "$ver" "$is_enabled" "$desc"
        done
        echo ']}'
        return
    fi

    echo "Available Plugins:"
    echo ""
    for name in "${available[@]}"; do
        local status="[ ]"
        [[ " ${enabled[*]} " =~ " ${name} " ]] && status="[x]"
        local desc=$(plugin_meta "$name" '.description // "No description"')
        printf "  %s %-20s %s\n" "$status" "$name" "$desc"
    done
    echo ""
    echo "Enable:  dotfiles plugin enable <name>"
    echo "Disable: dotfiles plugin disable <name>"
}

cmd_enable() {
    local name="${1:?Plugin name required}"
    plugin_enable "$name"
}

cmd_disable() {
    local name="${1:?Plugin name required}"
    plugin_disable "$name"
}

cmd_create() {
    local name="${1:?Plugin name required}"
    plugin_create "$name"
}

cmd_info() {
    local name="${1:?Plugin name required}"
    local dir=$(plugin_dir "$name")

    if [[ -z "$dir" ]]; then
        fail "Plugin not found: $name"
        exit 1
    fi

    echo "Plugin: $name"
    echo "Location: $dir"
    echo "Enabled: $(plugin_enabled "$name" && echo "yes" || echo "no")"
    echo ""

    if [[ -f "${dir}/plugin.json" ]]; then
        echo "Manifest:"
        jq '.' "${dir}/plugin.json"
    fi
}

cmd_check() {
    local name="${1:?Plugin name required}"
    if plugin_check_deps "$name"; then
        pass "All dependencies satisfied for: $name"
    else
        fail "Missing dependencies for: $name"
        exit 1
    fi
}

# Main
case "${1:-}" in
    list)       shift; cmd_list "$@" ;;
    enable)     shift; cmd_enable "$@" ;;
    disable)    shift; cmd_disable "$@" ;;
    create)     shift; cmd_create "$@" ;;
    info)       shift; cmd_info "$@" ;;
    check)      shift; cmd_check "$@" ;;
    -h|--help)  usage ;;
    *)          usage; exit 1 ;;
esac
```

---

## Shell Integration

Add to `zsh/zsh.d/95-plugins.zsh`:

```zsh
# Load plugin system
if [[ -f "${BLACKDOT_DIR}/lib/_plugins.sh" ]]; then
    source "${BLACKDOT_DIR}/lib/_plugins.sh"
    plugin_load_all
fi
```

---

## Shipped Plugins (Examples)

### docker-helpers
- `dps` - Pretty docker ps
- `dex` - Docker exec with default shell
- `dlog` - Follow container logs
- `dclean` - Cleanup old images/containers

### kubernetes
- `k` - kubectl alias
- `kctx` - Context switching
- `kns` - Namespace switching
- `klog` - Pod log viewer

### node-helpers
- `nvm` lazy loading
- `npm` aliases
- Node version detection per project

### git-extras
- `glog` - Pretty git log
- `gclean` - Branch cleanup
- `gsync` - Fetch + prune + pull

---

## Testing

```bash
# Test plugin discovery
test/plugins/test_discovery.bats

# Test enable/disable
test/plugins/test_lifecycle.bats

# Test dependency checking
test/plugins/test_dependencies.bats

# Test plugin loading
test/plugins/test_loading.bats
```

---

## Migration Path

1. Create `plugins/` directory structure
2. Extract existing optional functionality into plugins:
   - AWS helpers → `plugins/available/aws-helpers/`
   - Git extras → `plugins/available/git-extras/`
3. Update `zsh.d/` to load via plugin system
4. Document in `docs/plugins.md`

---

## Security Considerations

1. **Local plugins only** - No remote plugin installation
2. **Manifest validation** - Validate plugin.json schema before loading
3. **No eval** - Plugins are sourced, not eval'd
4. **Dependency verification** - Check command existence before loading

---

## Lessons Learned (from v2.1-v2.3 implementations)

Based on implementing CLI Feature Awareness, Configuration Layers, and Feature Registry:

### 1. Environment Variable Overrides
Add env var bypass for scripting/CI:
```bash
# In lib/_plugins.sh
DOTFILES_PLUGIN_FORCE=true   # Bypass dependency checks
DOTFILES_PLUGIN_VERBOSE=true # Show debug output
```

### 2. Meta-Feature Pattern
Register plugin system itself as a feature:
```zsh
# In FEATURE_REGISTRY
["plugins"]="true|Plugin system for extensibility|optional|"

# Check before loading any plugins
feature_enabled "plugins" || return 0
```

### 3. `--force` Escape Hatch
Always provide bypass for guards:
```bash
# Enable plugin even if deps missing
blackdot plugin enable docker-helpers --force
```

### 4. Per-Plugin Help with Feature Status
Show plugin details with enable hints:
```bash
blackdot plugin info docker-helpers
# Shows: enabled/disabled, deps status, enable command
```

### 5. jq Boolean Handling
Don't use `// empty` for booleans - it treats `false` as empty:
```bash
# WRONG - returns empty for false
jq -r '.enabled // empty' manifest.json

# CORRECT - returns "false" string
jq -r '.enabled' manifest.json
```

### 6. Consistent Feature Guard Pattern
```zsh
plugin_load() {
    local name="$1"

    # Environment override
    if [[ "${DOTFILES_PLUGIN_FORCE:-}" == "true" ]]; then
        # Skip dependency check
    fi

    # Meta-feature check
    if ! feature_enabled "plugins"; then
        return 0
    fi

    # Individual plugin feature check
    if ! feature_enabled "plugin_${name}"; then
        return 0
    fi

    # ... load plugin
}
```

### 7. Testing with zsh
All plugin tests need zsh since scripts use zsh syntax:
```bash
@test "plugin_load works" {
  run zsh -c "source '$PLUGINS_SH'; plugin_load 'docker-helpers'"
  [ "$status" -eq 0 ]
}
```

### 8. CLI Integration Pattern
Add to CLI_COMMAND_FEATURES and CLI_COMMAND_HELP:
```zsh
# In lib/_cli_features.sh
["plugin"]="plugins"

# In zsh/zsh.d/40-aliases.zsh CLI_COMMAND_HELP
["plugin"]="plugins|Plugin Management|Manage dotfiles plugins|
  plugin list       List available plugins
  plugin enable     Enable a plugin
  ..."
```

---

## Open Questions

1. Should plugins support update/upgrade from git remotes?
2. Plugin versioning and compatibility with dotfiles versions?
3. Should we support plugin "packs" (collections of plugins)?

---

*Created: 2025-12-05*
*Updated: 2025-12-05 (Added Lessons Learned)*
