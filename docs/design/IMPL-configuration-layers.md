# Configuration Layers Implementation

> **Status:** Not Started
> **Priority:** High
> **Complexity:** Medium
> **Target:** v2.2.0
> **Foundation:** [Feature Registry](../features.md) (v2.1.0)

## Overview

Configuration layers provide hierarchical config resolution, allowing settings to be overridden at different levels (project, machine, user) without modifying the main config file.

---

## Architecture Foundation

Configuration Layers provides the data layer that works alongside the **Feature Registry** (`lib/_features.sh`) control plane:

```
┌─────────────────────────────────────────────┐
│         Feature Registry (v2.1.0)            │
│   - Controls what's enabled/disabled         │
│   - Reads feature state from config          │
│   - Already uses config.json for persistence │
└─────────────────┬───────────────────────────┘
                  │ reads/writes
                  ▼
┌─────────────────────────────────────────────┐
│       Configuration Layers (this doc)        │
│   - Provides layered config resolution       │
│   - Features can be overridden per-machine   │
│   - Projects can override feature defaults   │
└─────────────────────────────────────────────┘
```

**Key integration points:**
- Feature state (`features.*`) resolves through config layers
- Machine config can override feature defaults for that machine
- Project config can enable/disable features per-project
- `feature_enabled()` will use `config_get_layered()` internally

**Example: Feature state through layers**
```bash
# Default (lib/_features.sh): claude_integration = false
# User config.json: features.claude_integration = true
# Machine config: features.claude_integration = false  # Work laptop
# Result: claude_integration is DISABLED on this machine
```

---

## Goals

1. **Layer precedence** - Clear override rules (session > project > machine > user > defaults)
2. **No conflicts** - Higher layers cleanly override lower layers
3. **Transparency** - Easy to see which layer a setting comes from
4. **Portability** - Project configs travel with repos, machine configs stay local

---

## Layer Hierarchy

```
Priority (highest to lowest):
┌─────────────────────────────────────────┐
│ 1. Session (environment variables)       │  DOTFILES_VAULT_BACKEND=1password
├─────────────────────────────────────────┤
│ 2. Project (.dotfiles.json in repo)      │  Per-project overrides
├─────────────────────────────────────────┤
│ 3. Machine (~/.config/dotfiles/          │  Machine-specific settings
│            machine.json)                 │  (work laptop vs home desktop)
├─────────────────────────────────────────┤
│ 4. User (~/.config/dotfiles/             │  User preferences
│         config.json)                     │  (current config file)
├─────────────────────────────────────────┤
│ 5. Defaults (lib/_config.sh)             │  Built-in defaults
└─────────────────────────────────────────┘
```

---

## File Locations

| Layer | Location | Git Tracked | Purpose |
|-------|----------|-------------|---------|
| Session | Environment | N/A | Temporary overrides |
| Project | `.dotfiles.json` (in project root) | Yes | Project-specific settings |
| Machine | `~/.config/dotfiles/machine.json` | No | Machine-specific settings |
| User | `~/.config/dotfiles/config.json` | No | User preferences (existing) |
| Defaults | `lib/_config.sh` | Yes | Built-in defaults |

---

## Configuration Schema

### Project Config (`.dotfiles.json`)

```json
{
  "$schema": "https://dotfiles.example.com/schema/project.json",
  "version": 1,

  "features": {
    "vault": false,
    "templates": true
  },

  "shell": {
    "auto_activate_venv": true,
    "node_version_file": ".nvmrc"
  },

  "hooks": {
    "directory_change": [
      { "command": "source .env", "if_exists": ".env" }
    ]
  },

  "aliases": {
    "dev": "npm run dev",
    "test": "npm test"
  }
}
```

### Machine Config (`machine.json`)

```json
{
  "$schema": "https://dotfiles.example.com/schema/machine.json",
  "version": 1,
  "machine_id": "work-macbook-2024",

  "vault": {
    "backend": "1password"
  },

  "paths": {
    "workspace": "~/Code",
    "dotfiles_dir": "~/Code/dotfiles"
  },

  "features": {
    "claude_integration": false
  },

  "packages": {
    "tier": "full",
    "extras": ["docker", "kubernetes-cli"]
  },

  "shell": {
    "theme": "work",
    "prompt_context": "work"
  }
}
```

### User Config (`config.json`) - Existing

```json
{
  "version": 3,
  "vault": {
    "backend": "bitwarden",
    "auto_sync": false
  },
  "features": {
    "vault": true,
    "workspace_symlink": true
  },
  "setup": {
    "completed": ["symlinks", "packages"]
  }
}
```

---

## Library Implementation (`lib/_config_layers.sh`)

```zsh
#!/usr/bin/env zsh
# lib/_config_layers.sh - Layered configuration system

# Layer file locations
CONFIG_LAYER_PROJECT=".dotfiles.json"
CONFIG_LAYER_MACHINE="$HOME/.config/dotfiles/machine.json"
CONFIG_LAYER_USER="$HOME/.config/dotfiles/config.json"

# Cache for resolved values (cleared on config reload)
typeset -gA CONFIG_CACHE=()
CONFIG_CACHE_TTL=60  # seconds

#######################################
# Get config value with layer resolution
# Arguments: key (dot notation), [default]
# Returns: resolved value
#######################################
config_get_layered() {
    local key="$1"
    local default="${2:-}"

    # Check cache first
    local cache_key="layered:$key"
    if [[ -n "${CONFIG_CACHE[$cache_key]:-}" ]]; then
        echo "${CONFIG_CACHE[$cache_key]}"
        return
    fi

    local value=""
    local source=""

    # Layer 1: Environment variable
    # Convert key to env var: vault.backend -> DOTFILES_VAULT_BACKEND
    local env_key="DOTFILES_${key//\./_}"
    env_key="${env_key:u}"  # uppercase
    if [[ -n "${(P)env_key:-}" ]]; then
        value="${(P)env_key}"
        source="env"
    fi

    # Layer 2: Project config (if in a project directory)
    if [[ -z "$value" ]]; then
        local project_config=$(_find_project_config)
        if [[ -n "$project_config" && -f "$project_config" ]]; then
            local proj_val=$(jq -r ".$key // empty" "$project_config" 2>/dev/null)
            if [[ -n "$proj_val" && "$proj_val" != "null" ]]; then
                value="$proj_val"
                source="project:$project_config"
            fi
        fi
    fi

    # Layer 3: Machine config
    if [[ -z "$value" && -f "$CONFIG_LAYER_MACHINE" ]]; then
        local machine_val=$(jq -r ".$key // empty" "$CONFIG_LAYER_MACHINE" 2>/dev/null)
        if [[ -n "$machine_val" && "$machine_val" != "null" ]]; then
            value="$machine_val"
            source="machine"
        fi
    fi

    # Layer 4: User config
    if [[ -z "$value" && -f "$CONFIG_LAYER_USER" ]]; then
        local user_val=$(jq -r ".$key // empty" "$CONFIG_LAYER_USER" 2>/dev/null)
        if [[ -n "$user_val" && "$user_val" != "null" ]]; then
            value="$user_val"
            source="user"
        fi
    fi

    # Layer 5: Default
    if [[ -z "$value" ]]; then
        value="$default"
        source="default"
    fi

    # Cache the result
    CONFIG_CACHE[$cache_key]="$value"

    echo "$value"
}

#######################################
# Get config value with source info
# Arguments: key
# Returns: JSON with value and source
#######################################
config_get_with_source() {
    local key="$1"

    local value=""
    local source="default"
    local file=""

    # Check each layer and record source
    local env_key="DOTFILES_${key//\./_}"
    env_key="${env_key:u}"
    if [[ -n "${(P)env_key:-}" ]]; then
        value="${(P)env_key}"
        source="env"
        file="$env_key"
    fi

    if [[ -z "$value" ]]; then
        local project_config=$(_find_project_config)
        if [[ -n "$project_config" && -f "$project_config" ]]; then
            local proj_val=$(jq -r ".$key // empty" "$project_config" 2>/dev/null)
            if [[ -n "$proj_val" && "$proj_val" != "null" ]]; then
                value="$proj_val"
                source="project"
                file="$project_config"
            fi
        fi
    fi

    if [[ -z "$value" && -f "$CONFIG_LAYER_MACHINE" ]]; then
        local machine_val=$(jq -r ".$key // empty" "$CONFIG_LAYER_MACHINE" 2>/dev/null)
        if [[ -n "$machine_val" && "$machine_val" != "null" ]]; then
            value="$machine_val"
            source="machine"
            file="$CONFIG_LAYER_MACHINE"
        fi
    fi

    if [[ -z "$value" && -f "$CONFIG_LAYER_USER" ]]; then
        local user_val=$(jq -r ".$key // empty" "$CONFIG_LAYER_USER" 2>/dev/null)
        if [[ -n "$user_val" && "$user_val" != "null" ]]; then
            value="$user_val"
            source="user"
            file="$CONFIG_LAYER_USER"
        fi
    fi

    printf '{"key":"%s","value":%s,"source":"%s","file":"%s"}' \
        "$key" \
        "$(echo "$value" | jq -R '.')" \
        "$source" \
        "$file"
}

#######################################
# Find project config by walking up directory tree
# Returns: path to .dotfiles.json or empty
#######################################
_find_project_config() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/$CONFIG_LAYER_PROJECT" ]]; then
            echo "$dir/$CONFIG_LAYER_PROJECT"
            return
        fi
        dir="$(dirname "$dir")"
    done
}

#######################################
# Set config value in specified layer
# Arguments: layer, key, value
# layer: user, machine, project
#######################################
config_set_layered() {
    local layer="$1"
    local key="$2"
    local value="$3"

    local config_file
    case "$layer" in
        user)    config_file="$CONFIG_LAYER_USER" ;;
        machine) config_file="$CONFIG_LAYER_MACHINE" ;;
        project)
            config_file=$(_find_project_config)
            [[ -z "$config_file" ]] && config_file="$PWD/$CONFIG_LAYER_PROJECT"
            ;;
        *)
            echo "Invalid layer: $layer (use: user, machine, project)" >&2
            return 1
            ;;
    esac

    # Ensure directory exists
    local config_dir=$(dirname "$config_file")
    mkdir -p "$config_dir"

    # Create file if doesn't exist
    if [[ ! -f "$config_file" ]]; then
        echo '{"version": 1}' > "$config_file"
    fi

    # Update value using jq
    local tmp_file="${config_file}.tmp"
    jq ".$key = $value" "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"

    # Clear cache
    CONFIG_CACHE=()
}

#######################################
# Show all layers and their values for a key
# Arguments: key
#######################################
config_show_layers() {
    local key="$1"

    echo "Configuration layers for: $key"
    echo ""

    # Environment
    local env_key="DOTFILES_${key//\./_}"
    env_key="${env_key:u}"
    local env_val="${(P)env_key:-}"
    printf "  %-10s %s\n" "env:" "${env_val:-(not set)}"

    # Project
    local project_config=$(_find_project_config)
    local proj_val=""
    if [[ -n "$project_config" && -f "$project_config" ]]; then
        proj_val=$(jq -r ".$key // empty" "$project_config" 2>/dev/null)
    fi
    printf "  %-10s %s\n" "project:" "${proj_val:-(not set)}"

    # Machine
    local machine_val=""
    if [[ -f "$CONFIG_LAYER_MACHINE" ]]; then
        machine_val=$(jq -r ".$key // empty" "$CONFIG_LAYER_MACHINE" 2>/dev/null)
    fi
    printf "  %-10s %s\n" "machine:" "${machine_val:-(not set)}"

    # User
    local user_val=""
    if [[ -f "$CONFIG_LAYER_USER" ]]; then
        user_val=$(jq -r ".$key // empty" "$CONFIG_LAYER_USER" 2>/dev/null)
    fi
    printf "  %-10s %s\n" "user:" "${user_val:-(not set)}"

    # Resolved
    echo ""
    local resolved=$(config_get_layered "$key")
    printf "  %-10s %s\n" "resolved:" "${resolved:-(empty)}"
}

#######################################
# Show all config from all layers merged
#######################################
config_show_merged() {
    local merged="{}"

    # Start with user config (lowest priority that's a file)
    if [[ -f "$CONFIG_LAYER_USER" ]]; then
        merged=$(jq -s '.[0] * .[1]' <(echo "$merged") "$CONFIG_LAYER_USER")
    fi

    # Merge machine config
    if [[ -f "$CONFIG_LAYER_MACHINE" ]]; then
        merged=$(jq -s '.[0] * .[1]' <(echo "$merged") "$CONFIG_LAYER_MACHINE")
    fi

    # Merge project config
    local project_config=$(_find_project_config)
    if [[ -n "$project_config" && -f "$project_config" ]]; then
        merged=$(jq -s '.[0] * .[1]' <(echo "$merged") "$project_config")
    fi

    echo "$merged" | jq '.'
}

#######################################
# Initialize machine config with machine ID
# Arguments: [machine_id]
#######################################
config_init_machine() {
    local machine_id="${1:-$(hostname -s)}"

    if [[ -f "$CONFIG_LAYER_MACHINE" ]]; then
        echo "Machine config already exists: $CONFIG_LAYER_MACHINE"
        return 1
    fi

    mkdir -p "$(dirname "$CONFIG_LAYER_MACHINE")"

    cat > "$CONFIG_LAYER_MACHINE" <<EOF
{
  "version": 1,
  "machine_id": "$machine_id",
  "vault": {},
  "features": {},
  "paths": {},
  "shell": {}
}
EOF

    echo "Created machine config: $CONFIG_LAYER_MACHINE"
    echo "Edit to customize settings for this machine."
}

#######################################
# Initialize project config in current directory
#######################################
config_init_project() {
    local config_file="$PWD/$CONFIG_LAYER_PROJECT"

    if [[ -f "$config_file" ]]; then
        echo "Project config already exists: $config_file"
        return 1
    fi

    cat > "$config_file" <<EOF
{
  "\$schema": "https://dotfiles.example.com/schema/project.json",
  "version": 1,

  "features": {},

  "shell": {
    "auto_activate_venv": false
  },

  "aliases": {}
}
EOF

    echo "Created project config: $config_file"
    echo "Edit to customize settings for this project."
}

#######################################
# Clear config cache (call after config changes)
#######################################
config_cache_clear() {
    CONFIG_CACHE=()
}
```

---

## CLI Command (`bin/dotfiles-config`)

```bash
#!/usr/bin/env bash
# bin/dotfiles-config - Configuration management CLI
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/_logging.sh"
source "${SCRIPT_DIR}/../lib/_config_layers.sh"

usage() {
    cat <<EOF
Usage: dotfiles config <command> [args]

Commands:
  get <key>               Get config value (layered resolution)
  set <key> <value>       Set config value in user layer
  set --machine <k> <v>   Set config value in machine layer
  set --project <k> <v>   Set config value in project layer
  layers <key>            Show all layers for a key
  show                    Show merged config from all layers
  show --layer <name>     Show specific layer (user, machine, project)
  init machine [id]       Initialize machine config
  init project            Initialize project config in current dir
  edit [layer]            Open config in editor

Options:
  --json                  Output in JSON format
  -h, --help              Show this help

Examples:
  dotfiles config get vault.backend
  dotfiles config set vault.auto_sync true
  dotfiles config set --machine vault.backend 1password
  dotfiles config layers vault.backend
  dotfiles config init machine work-laptop
  dotfiles config init project
EOF
}

cmd_get() {
    local key="${1:?Key required}"
    local json=false
    [[ "${2:-}" == "--json" ]] && json=true

    if $json; then
        config_get_with_source "$key"
    else
        config_get_layered "$key"
    fi
}

cmd_set() {
    local layer="user"
    local key=""
    local value=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --machine) layer="machine"; shift ;;
            --project) layer="project"; shift ;;
            --user)    layer="user"; shift ;;
            *)
                if [[ -z "$key" ]]; then
                    key="$1"
                else
                    value="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$key" || -z "$value" ]]; then
        fail "Usage: dotfiles config set [--layer] <key> <value>"
        exit 1
    fi

    # Auto-detect JSON vs string
    if [[ "$value" =~ ^(true|false|[0-9]+|\[.*\]|\{.*\})$ ]]; then
        config_set_layered "$layer" "$key" "$value"
    else
        config_set_layered "$layer" "$key" "\"$value\""
    fi

    pass "Set $key = $value in $layer layer"
}

cmd_layers() {
    local key="${1:?Key required}"
    config_show_layers "$key"
}

cmd_show() {
    local layer=""
    [[ "${1:-}" == "--layer" ]] && layer="${2:-}"

    case "$layer" in
        user)
            [[ -f "$CONFIG_LAYER_USER" ]] && jq '.' "$CONFIG_LAYER_USER" || echo "{}"
            ;;
        machine)
            [[ -f "$CONFIG_LAYER_MACHINE" ]] && jq '.' "$CONFIG_LAYER_MACHINE" || echo "{}"
            ;;
        project)
            local project_config=$(_find_project_config)
            [[ -n "$project_config" && -f "$project_config" ]] && jq '.' "$project_config" || echo "{}"
            ;;
        "")
            config_show_merged
            ;;
        *)
            fail "Unknown layer: $layer (use: user, machine, project)"
            exit 1
            ;;
    esac
}

cmd_init() {
    local type="${1:?Type required (machine or project)}"
    shift

    case "$type" in
        machine) config_init_machine "$@" ;;
        project) config_init_project ;;
        *)
            fail "Unknown type: $type (use: machine or project)"
            exit 1
            ;;
    esac
}

cmd_edit() {
    local layer="${1:-user}"
    local config_file

    case "$layer" in
        user)    config_file="$CONFIG_LAYER_USER" ;;
        machine) config_file="$CONFIG_LAYER_MACHINE" ;;
        project)
            config_file=$(_find_project_config)
            [[ -z "$config_file" ]] && config_file="$PWD/$CONFIG_LAYER_PROJECT"
            ;;
        *)
            fail "Unknown layer: $layer"
            exit 1
            ;;
    esac

    ${EDITOR:-vim} "$config_file"
}

# Main
case "${1:-}" in
    get)        shift; cmd_get "$@" ;;
    set)        shift; cmd_set "$@" ;;
    layers)     shift; cmd_layers "$@" ;;
    show)       shift; cmd_show "$@" ;;
    init)       shift; cmd_init "$@" ;;
    edit)       shift; cmd_edit "$@" ;;
    -h|--help)  usage ;;
    *)          usage; exit 1 ;;
esac
```

---

## Migration from Current System

### Phase 1: Add Layer Support

1. Create `lib/_config_layers.sh`
2. Add `config_get_layered()` alongside existing `config_get()`
3. Existing code continues using `config_get()`

### Phase 2: Migrate Internal Usage

1. Update scripts to use `config_get_layered()` where appropriate
2. Feature registry uses layered config for feature state
3. Add machine config documentation

### Phase 3: Deprecate Direct Config Access

1. `config_get()` internally calls `config_get_layered()`
2. Full backward compatibility maintained
3. Document layer system in docs

---

## Use Cases

### 1. Work vs Personal Machine

```bash
# On work laptop
dotfiles config init machine work-macbook
dotfiles config set --machine vault.backend 1password
dotfiles config set --machine features.claude_integration false

# On personal desktop
dotfiles config init machine home-desktop
dotfiles config set --machine vault.backend bitwarden
dotfiles config set --machine packages.tier full
```

### 2. Project-Specific Settings

```bash
# In a Node.js project
cd ~/projects/webapp
dotfiles config init project

# Edit .dotfiles.json
{
  "shell": {
    "auto_activate_venv": false
  },
  "aliases": {
    "start": "npm run dev",
    "test": "npm test"
  }
}
```

### 3. Temporary Override

```bash
# Override for current session only
export DOTFILES_VAULT_BACKEND=pass
dotfiles vault pull  # Uses pass instead of configured backend
```

---

## Testing

```bash
# Test layer resolution
test/config/test_layers.bats

# Test machine config
test/config/test_machine.bats

# Test project config
test/config/test_project.bats

# Test environment overrides
test/config/test_env_override.bats
```

---

## Security Considerations

1. **Project configs are git-tracked** - Don't put secrets in `.dotfiles.json`
2. **Machine configs are local** - Safe for machine-specific secrets
3. **Environment vars are transient** - Good for CI/CD overrides

---

*Created: 2025-12-05*
