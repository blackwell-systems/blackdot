#!/usr/bin/env zsh
# Feature Registry (v3.0)
# Central registry for all optional features with enable/disable control
#
# Design Goals:
# - All features are opt-in by default (disabled until enabled)
# - SKIP_* environment variables provide backward compatibility
# - Features can be enabled/disabled at runtime
# - Dependencies are resolved automatically
#
# NOTE: Do NOT use "set -euo pipefail" here - this file is sourced into
# interactive shells and those options would kill the shell on any error.

# ============================================================
# Feature Definitions
# ============================================================
# Features are organized into categories:
# - Core: Always enabled, cannot be disabled
# - Optional: Disabled by default, can be enabled
# - Integration: Third-party tool integrations

# All features with their default state
# Format: feature_name -> "default_enabled|description|category|dependencies"
typeset -gA FEATURE_REGISTRY=(
    # Core features (always enabled)
    ["shell"]="true|ZSH shell, prompt, and core aliases|core|"

    # Optional features (default: disabled or env-controlled)
    ["workspace_symlink"]="env|/workspace symlink for portable sessions|optional|"
    ["claude_integration"]="env|Claude Code integration and hooks|optional|workspace_symlink"
    ["vault"]="false|Multi-vault secret management (Bitwarden/1Password/pass)|optional|"
    ["templates"]="false|Machine-specific configuration templates|optional|"
    ["git_hooks"]="true|Git safety hooks (pre-commit, pre-push)|optional|"
    ["drift_check"]="env|Automatic drift detection on vault operations|optional|vault"
    ["backup_auto"]="false|Automatic backup before destructive operations|optional|"
    ["health_metrics"]="false|Health check metrics collection and trending|optional|"
    ["macos_settings"]="true|macOS system preferences automation|optional|"
    ["config_layers"]="true|Hierarchical configuration resolution (env>project>machine>user)|optional|"
    ["cli_feature_filter"]="true|Filter CLI help and commands based on enabled features|optional|"
    ["hooks"]="true|Lifecycle hooks for custom behavior at key events|optional|"
    ["encryption"]="false|Age encryption for sensitive files (templates, secrets)|optional|"

    # Integration features (third-party tool integrations)
    ["modern_cli"]="true|Modern CLI tools (eza, bat, ripgrep, fzf, zoxide)|integration|"
    ["aws_helpers"]="true|AWS SSO profile management and helpers|integration|"
    ["cdk_tools"]="true|AWS CDK aliases, helpers, and environment management|integration|aws_helpers"
    ["rust_tools"]="true|Rust/Cargo aliases and helpers|integration|"
    ["go_tools"]="true|Go aliases and helpers|integration|"
    ["python_tools"]="true|Python/uv aliases, auto-venv, pytest helpers|integration|"
    ["ssh_tools"]="true|SSH config, key management, agent, and tunnel helpers|integration|"
    ["docker_tools"]="true|Docker container, compose, and network management|integration|"
    ["nvm_integration"]="true|Lazy-loaded NVM for Node.js version management|integration|"
    ["sdkman_integration"]="true|Lazy-loaded SDKMAN for Java/Gradle/Kotlin|integration|"
    ["dotclaude"]="false|dotclaude profile management for Claude Code|integration|claude_integration"
)

# Environment variable mappings for backward compatibility
# Maps SKIP_* vars to feature names
typeset -gA FEATURE_ENV_MAP=(
    ["SKIP_WORKSPACE_SYMLINK"]="workspace_symlink"
    ["SKIP_CLAUDE_SETUP"]="claude_integration"
    ["DOTFILES_SKIP_DRIFT_CHECK"]="drift_check"
)

# ============================================================
# Feature State Storage
# ============================================================
# Runtime feature state (overrides registry defaults)
typeset -gA FEATURE_STATE=()

# ============================================================
# Core Functions
# ============================================================

# Get feature metadata
# Usage: _feature_meta "vault" "description"
# Returns: The specified field (default_enabled, description, category, dependencies)
_feature_meta() {
    local feature="$1"
    local field="${2:-description}"
    local entry="${FEATURE_REGISTRY[$feature]:-}"

    if [[ -z "$entry" ]]; then
        return 1
    fi

    # Parse entry: "default_enabled|description|category|dependencies"
    local IFS='|'
    local parts=("${(@s:|:)entry}")

    case "$field" in
        default|default_enabled) echo "${parts[1]:-false}" ;;
        description|desc)        echo "${parts[2]:-}" ;;
        category|cat)            echo "${parts[3]:-optional}" ;;
        dependencies|deps)       echo "${parts[4]:-}" ;;
        *)                       echo "${parts[2]:-}" ;;
    esac
}

# Check if feature exists in registry
# Usage: feature_exists "vault"
feature_exists() {
    local feature="$1"
    [[ -n "${FEATURE_REGISTRY[$feature]:-}" ]]
}

# Check if a feature is enabled
# Usage: if feature_enabled "vault"; then ...
# Checks in order: runtime state -> env vars -> config file -> registry default
feature_enabled() {
    local feature="$1"

    # 1. Feature must exist in registry
    if ! feature_exists "$feature"; then
        return 1
    fi

    # 2. Check runtime state (highest priority)
    if [[ -n "${FEATURE_STATE[$feature]:-}" ]]; then
        [[ "${FEATURE_STATE[$feature]}" == "true" ]]
        return $?
    fi

    # 3. Check environment variable overrides (backward compatibility)
    local env_value
    env_value=$(_feature_from_env "$feature")
    if [[ -n "$env_value" ]]; then
        [[ "$env_value" == "true" ]]
        return $?
    fi

    # 4. Check config file
    if [[ -f "${CONFIG_FILE:-}" ]]; then
        local config_value
        # Note: don't use // empty as it treats false as empty
        config_value=$(jq -r ".features.${feature}" "$CONFIG_FILE" 2>/dev/null || true)
        if [[ -n "$config_value" && "$config_value" != "null" ]]; then
            [[ "$config_value" == "true" ]]
            return $?
        fi
    fi

    # 5. Fall back to registry default
    local default
    default=$(_feature_meta "$feature" "default")

    # Handle "env" default (means check env var, if not set, disabled)
    if [[ "$default" == "env" ]]; then
        return 1  # Default to disabled if no env var set
    fi

    [[ "$default" == "true" ]]
}

# Check environment variables for feature state
# Returns: "true", "false", or "" (not set)
_feature_from_env() {
    local feature="$1"

    # Check direct feature env var first: DOTFILES_FEATURE_<NAME>=true|false
    local direct_var="DOTFILES_FEATURE_${(U)feature}"  # uppercase
    if [[ -n "${(P)direct_var:-}" ]]; then
        local val="${(P)direct_var}"
        if [[ "$val" == "true" || "$val" == "1" ]]; then
            echo "true"
        else
            echo "false"
        fi
        return
    fi

    # Check SKIP_* backward compatibility vars
    for env_var in "${(@k)FEATURE_ENV_MAP}"; do
        if [[ "${FEATURE_ENV_MAP[$env_var]}" == "$feature" ]]; then
            local skip_val="${(P)env_var:-}"
            if [[ -n "$skip_val" ]]; then
                # SKIP_* vars are inverted: SKIP_X=true means feature=false
                if [[ "$skip_val" == "true" || "$skip_val" == "1" ]]; then
                    echo "false"
                else
                    echo "true"
                fi
                return
            fi
        fi
    done

    echo ""  # Not set via env
}

# Enable a feature at runtime
# Usage: feature_enable "vault"
# Automatically enables dependencies, checks for cycles and conflicts
feature_enable() {
    local feature="$1"

    if ! feature_exists "$feature"; then
        echo "ERROR: Unknown feature: $feature" >&2
        return 1
    fi

    # Check for circular dependencies before enabling
    if ! _detect_circular_dep "$feature"; then
        return 1
    fi

    # Check for conflicts with already-enabled features
    if ! _check_conflicts "$feature"; then
        return 1
    fi

    # Enable dependencies first
    local deps
    deps=$(_feature_meta "$feature" "deps")
    if [[ -n "$deps" ]]; then
        for dep in ${(s:,:)deps}; do
            # Trim whitespace
            dep="${dep// /}"
            [[ -z "$dep" ]] && continue

            if ! feature_enabled "$dep"; then
                feature_enable "$dep" || return 1
            fi
        done
    fi

    FEATURE_STATE[$feature]="true"
    # Export as env var so subprocesses (like dotfiles features list) can see it
    export "DOTFILES_FEATURE_${(U)feature}=true"
}

# Disable a feature at runtime
# Usage: feature_disable "vault"
# WARNING: Does not check if other features depend on this one
feature_disable() {
    local feature="$1"

    if ! feature_exists "$feature"; then
        echo "ERROR: Unknown feature: $feature" >&2
        return 1
    fi

    # Cannot disable core features
    local category
    category=$(_feature_meta "$feature" "category")
    if [[ "$category" == "core" ]]; then
        echo "ERROR: Cannot disable core feature: $feature" >&2
        return 1
    fi

    FEATURE_STATE[$feature]="false"
    # Export as env var so subprocesses (like dotfiles features list) can see it
    export "DOTFILES_FEATURE_${(U)feature}=false"
}

# Runtime feature guard for use inside shell functions
# Usage: require_feature "ssh_tools" || return 1
# Returns 1 if feature is disabled (with user-friendly message)
require_feature() {
    local feature="$1"
    local silent="${2:-false}"

    if feature_enabled "$feature"; then
        return 0
    fi

    if [[ "$silent" != "true" ]]; then
        echo "Feature '$feature' is disabled." >&2
        echo "Enable with: dotfiles features enable $feature" >&2
    fi
    return 1
}

# Persist feature state to config file
# Usage: feature_persist "vault" "true"
feature_persist() {
    local feature="$1"
    local enabled="${2:-true}"

    if ! feature_exists "$feature"; then
        echo "ERROR: Unknown feature: $feature" >&2
        return 1
    fi

    # Ensure config file exists
    local config_file="${CONFIG_FILE:-$HOME/.config/dotfiles/config.json}"
    local config_dir="$(dirname "$config_file")"

    # Create config directory and file if they don't exist
    if [[ ! -d "$config_dir" ]]; then
        mkdir -p "$config_dir" 2>/dev/null || {
            echo "ERROR: Cannot create config directory: $config_dir" >&2
            return 1
        }
    fi

    if [[ ! -f "$config_file" ]]; then
        # Create minimal config with features object
        echo '{"version": 3, "features": {}}' > "$config_file" || {
            echo "ERROR: Cannot create config file: $config_file" >&2
            return 1
        }
    fi

    # Ensure jq is available
    if ! command -v jq &>/dev/null; then
        echo "ERROR: jq is required for feature persistence. Install with: brew install jq" >&2
        return 1
    fi

    # Update config file (ensure features object exists)
    local tmp_file="${config_file}.tmp"
    if [[ "$enabled" == "true" ]]; then
        jq ".features = (.features // {}) | .features.${feature} = true" "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
    else
        jq ".features = (.features // {}) | .features.${feature} = false" "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
    fi

    # Update runtime state
    FEATURE_STATE[$feature]="$enabled"
}

# ============================================================
# Query Functions
# ============================================================

# List all features
# Usage: feature_list [category]
# Returns: List of feature names, one per line
feature_list() {
    local filter_category="${1:-}"
    local feature category

    for feature in "${(@k)FEATURE_REGISTRY}"; do
        if [[ -z "$filter_category" ]]; then
            echo "$feature"
        else
            category="$(_feature_meta "$feature" "category")"
            if [[ "$category" == "$filter_category" ]]; then
                echo "$feature"
            fi
        fi
    done | sort
}

# Get feature status as JSON
# Usage: feature_status "vault"
feature_status() {
    local feature="$1"

    if ! feature_exists "$feature"; then
        echo "{\"error\": \"Unknown feature: $feature\"}"
        return 1
    fi

    local enabled="false"
    feature_enabled "$feature" && enabled="true"

    local desc category deps default
    desc="$(_feature_meta "$feature" "description")"
    category="$(_feature_meta "$feature" "category")"
    deps="$(_feature_meta "$feature" "deps")"
    default="$(_feature_meta "$feature" "default")"

    cat <<EOF
{
  "name": "$feature",
  "enabled": $enabled,
  "default": "$default",
  "description": "$desc",
  "category": "$category",
  "dependencies": "${deps:-none}"
}
EOF
}

# Get all features status as JSON
# Usage: feature_status_all
feature_status_all() {
    echo "{"
    local first=true
    local feature enabled desc category
    for feature in $(feature_list | sort); do
        enabled="false"
        feature_enabled "$feature" && enabled="true"

        desc="$(_feature_meta "$feature" "description")"
        category="$(_feature_meta "$feature" "category")"

        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi

        printf '  "%s": {"enabled": %s, "category": "%s", "description": "%s"}' \
            "$feature" "$enabled" "$category" "$desc"
    done
    echo ""
    echo "}"
}

# ============================================================
# Dependency Resolution & Validation
# ============================================================

# Detect circular dependencies
# Usage: _detect_circular_dep "feature" "visited_features..."
# Returns: 0 if no cycle, 1 if cycle detected (prints cycle path)
_detect_circular_dep() {
    local feature="$1"
    shift
    local -a visited=("$@")

    # Check if already in visit path = cycle
    local v
    for v in "${visited[@]}"; do
        if [[ "$v" == "$feature" ]]; then
            # Found cycle - print the path
            echo "Circular dependency detected: ${visited[*]} → $feature" >&2
            return 1
        fi
    done

    # Add to path and check deps recursively
    visited+=("$feature")
    local deps
    deps=$(_feature_meta "$feature" "deps")

    if [[ -n "$deps" ]]; then
        local dep
        for dep in ${(s:,:)deps}; do
            # Trim whitespace
            dep="${dep// /}"
            [[ -z "$dep" ]] && continue

            if ! _detect_circular_dep "$dep" "${visited[@]}"; then
                return 1
            fi
        done
    fi

    return 0
}

# Validate all feature dependencies for cycles
# Usage: feature_validate
# Returns: 0 if valid, 1 if cycles found
feature_validate() {
    local has_errors=0
    local feature

    echo "Validating feature dependencies..."

    for feature in "${(@k)FEATURE_REGISTRY}"; do
        if ! _detect_circular_dep "$feature"; then
            has_errors=1
        fi
    done

    # Check for conflict violations (enabled features that conflict)
    local conflicts enabled_conflicts=()
    for feature in "${(@k)FEATURE_REGISTRY}"; do
        if feature_enabled "$feature" 2>/dev/null; then
            conflicts="${FEATURE_CONFLICTS[$feature]:-}"
            if [[ -n "$conflicts" ]]; then
                local conflict
                for conflict in ${(s:,:)conflicts}; do
                    conflict="${conflict// /}"
                    if feature_enabled "$conflict" 2>/dev/null; then
                        echo "Conflict: '$feature' and '$conflict' are both enabled but mutually exclusive" >&2
                        has_errors=1
                    fi
                done
            fi
        fi
    done

    if [[ $has_errors -eq 0 ]]; then
        echo "✓ All feature dependencies are valid"
        return 0
    else
        return 1
    fi
}

# Feature conflicts (mutually exclusive features)
# Format: feature -> "conflict1,conflict2,..."
typeset -gA FEATURE_CONFLICTS=(
    # Example: if we had multiple vault backends as separate features
    # ["pass_vault"]="bitwarden_vault,onepassword_vault"
)

# Check if enabling a feature would create a conflict
# Usage: _check_conflicts "feature"
# Returns: 0 if no conflict, 1 if conflict exists
_check_conflicts() {
    local feature="$1"
    local conflicts="${FEATURE_CONFLICTS[$feature]:-}"

    if [[ -z "$conflicts" ]]; then
        return 0
    fi

    local conflict
    for conflict in ${(s:,:)conflicts}; do
        conflict="${conflict// /}"
        if feature_enabled "$conflict" 2>/dev/null; then
            echo "ERROR: Cannot enable '$feature': conflicts with enabled feature '$conflict'" >&2
            return 1
        fi
    done

    return 0
}

# Check if all dependencies for a feature are met
# Usage: feature_deps_met "claude_integration"
feature_deps_met() {
    local feature="$1"

    local deps
    deps=$(_feature_meta "$feature" "deps")

    if [[ -z "$deps" ]]; then
        return 0  # No dependencies
    fi

    for dep in ${(s: :)deps}; do
        if ! feature_enabled "$dep"; then
            return 1
        fi
    done

    return 0
}

# Get missing dependencies for a feature
# Usage: feature_missing_deps "claude_integration"
feature_missing_deps() {
    local feature="$1"
    local missing=()

    local deps
    deps=$(_feature_meta "$feature" "deps")

    if [[ -z "$deps" ]]; then
        return 0
    fi

    for dep in ${(s: :)deps}; do
        if ! feature_enabled "$dep"; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "${missing[*]}"
        return 1
    fi

    return 0
}

# ============================================================
# Preset Support
# ============================================================
# Presets are named groups of features that can be enabled together

typeset -gA FEATURE_PRESETS=(
    ["minimal"]="shell config_layers"
    ["developer"]="shell vault aws_helpers cdk_tools rust_tools go_tools python_tools ssh_tools docker_tools nvm_integration sdkman_integration git_hooks modern_cli config_layers"
    ["claude"]="shell workspace_symlink claude_integration vault git_hooks modern_cli config_layers"
    ["full"]="shell workspace_symlink claude_integration vault templates aws_helpers cdk_tools rust_tools go_tools python_tools ssh_tools docker_tools git_hooks drift_check backup_auto health_metrics config_layers modern_cli nvm_integration sdkman_integration"
)

# Enable a preset
# Usage: feature_preset_enable "developer"
feature_preset_enable() {
    local preset="$1"
    local features="${FEATURE_PRESETS[$preset]:-}"

    if [[ -z "$features" ]]; then
        echo "ERROR: Unknown preset: $preset" >&2
        echo "Available presets: ${(k)FEATURE_PRESETS[*]}" >&2
        return 1
    fi

    for feature in ${(s: :)features}; do
        feature_enable "$feature"
    done
}

# List available presets
# Usage: feature_preset_list
feature_preset_list() {
    for preset in "${(@k)FEATURE_PRESETS}"; do
        echo "$preset: ${FEATURE_PRESETS[$preset]}"
    done | sort
}

# ============================================================
# Guard Functions (for use in scripts)
# ============================================================

# Guard: Only run if feature is enabled
# Usage: feature_guard "vault" || return 0
feature_guard() {
    local feature="$1"
    local message="${2:-Feature '$feature' is not enabled}"

    if ! feature_enabled "$feature"; then
        if [[ -n "${DOTFILES_VERBOSE:-}" ]]; then
            echo "SKIP: $message" >&2
        fi
        return 1
    fi

    return 0
}

# Guard with dependency check
# Usage: feature_guard_with_deps "claude_integration" || return 0
feature_guard_with_deps() {
    local feature="$1"

    if ! feature_enabled "$feature"; then
        return 1
    fi

    local missing
    if missing=$(feature_missing_deps "$feature"); then
        return 0
    else
        echo "WARN: Feature '$feature' is missing dependencies: $missing" >&2
        return 1
    fi
}

# ============================================================
# Initialization
# ============================================================

# Initialize feature system (call once at startup)
# Usage: feature_init
feature_init() {
    # Source config if not already loaded
    if [[ -z "${CONFIG_FILE:-}" ]]; then
        CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
        CONFIG_FILE="$CONFIG_DIR/config.json"
    fi

    # Clear runtime state
    FEATURE_STATE=()
}

# Auto-initialize if sourced directly
if [[ "${BASH_SOURCE[0]:-${(%):-%x}}" == "${0}" ]] || [[ -z "${FEATURE_REGISTRY_INIT:-}" ]]; then
    feature_init
    FEATURE_REGISTRY_INIT=1
fi
