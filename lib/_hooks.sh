#!/usr/bin/env zsh
# ============================================================
# FILE: lib/_hooks.sh
# Hook System Library (v3.1)
# Allows users to inject custom behavior at lifecycle events
#
# Usage:
#   source "${DOTFILES_DIR}/lib/_hooks.sh"
#   hook_register "post_vault_pull" "my_function"
#   hook_run "post_vault_pull"
#
# Hook Points:
#   pre_install, post_install, pre_bootstrap, post_bootstrap,
#   pre_upgrade, post_upgrade, pre_vault_pull, post_vault_pull,
#   pre_vault_push, post_vault_push, pre_doctor, post_doctor,
#   doctor_check, shell_init, shell_exit, directory_change,
#   pre_setup_phase, post_setup_phase, setup_complete
#
# Design Goals:
# - User customization without modifying core scripts
# - Fail-safe: hook failures don't break core operations (configurable)
# - Transparent: easy to see registered hooks and when they run
# - Feature-gated: respects feature registry
# ============================================================

# Prevent multiple sourcing
if [[ -n "${_HOOKS_SOURCED:-}" ]]; then
    return 0
fi
_HOOKS_SOURCED=1

# ============================================================
# Configuration
# ============================================================

# Hook storage: HOOKS[point]="func1 func2 func3"
typeset -gA HOOKS=()

# Configuration with environment variable overrides
HOOKS_DIR="${DOTFILES_HOOKS_DIR:-${HOME}/.config/dotfiles/hooks}"
HOOKS_CONFIG="${DOTFILES_HOOKS_CONFIG:-${HOME}/.config/dotfiles/hooks.json}"
HOOKS_FAIL_FAST="${DOTFILES_HOOKS_FAIL_FAST:-false}"
HOOKS_VERBOSE="${DOTFILES_HOOKS_VERBOSE:-false}"
HOOKS_TIMEOUT="${DOTFILES_HOOKS_TIMEOUT:-30}"

# Master disable switch
HOOKS_DISABLED="${DOTFILES_HOOKS_DISABLED:-false}"

# ============================================================
# Valid Hook Points
# ============================================================

# All valid hook points
HOOK_POINTS=(
    # Install/Bootstrap lifecycle
    pre_install post_install
    pre_bootstrap post_bootstrap
    pre_upgrade post_upgrade

    # Vault operations
    pre_vault_pull post_vault_pull
    pre_vault_push post_vault_push

    # Doctor/Health
    pre_doctor post_doctor doctor_check

    # Shell lifecycle
    shell_init shell_exit directory_change

    # Setup wizard
    pre_setup_phase post_setup_phase setup_complete
)

# Map hook points to parent features (for feature-gated execution)
typeset -gA HOOK_FEATURE_MAP=(
    ["pre_vault_pull"]="vault"
    ["post_vault_pull"]="vault"
    ["pre_vault_push"]="vault"
    ["post_vault_push"]="vault"
)

# ============================================================
# Core Functions
# ============================================================

#######################################
# Validate hook point name
# Arguments:
#   $1 - hook point name
# Returns:
#   0 if valid, 1 if invalid
#######################################
hook_valid_point() {
    local point="$1"

    if [[ -z "$point" ]]; then
        return 1
    fi

    # Check if point is in HOOK_POINTS array
    local p
    for p in "${HOOK_POINTS[@]}"; do
        [[ "$p" == "$point" ]] && return 0
    done

    return 1
}

#######################################
# Register a hook function
# Arguments:
#   $1 - hook point name
#   $2 - function name or script path
# Returns:
#   0 on success, 1 on error
#######################################
hook_register() {
    local point="$1"
    local func="$2"

    # Validate inputs
    if [[ -z "$point" || -z "$func" ]]; then
        echo "hook_register: missing arguments" >&2
        echo "Usage: hook_register <hook_point> <function_name>" >&2
        return 1
    fi

    # Validate hook point
    if ! hook_valid_point "$point"; then
        echo "hook_register: invalid hook point: $point" >&2
        echo "Valid points: ${HOOK_POINTS[*]}" >&2
        return 1
    fi

    # Verify function exists (if not a file path)
    if [[ ! -f "$func" ]] && ! type "$func" &>/dev/null; then
        echo "hook_register: function or script not found: $func" >&2
        return 1
    fi

    # Check for duplicate registration (idempotency)
    if [[ -n "${HOOKS[$point]:-}" ]]; then
        # Check if already registered
        local existing
        for existing in ${(s: :)HOOKS[$point]}; do
            if [[ "$existing" == "$func" ]]; then
                # Already registered, skip silently (idempotent)
                [[ "$HOOKS_VERBOSE" == "true" ]] && \
                    echo "hook_register: already registered: $point -> $func" >&2
                return 0
            fi
        done
        # Append to existing hooks
        HOOKS[$point]="${HOOKS[$point]} $func"
    else
        # First hook for this point
        HOOKS[$point]="$func"
    fi

    [[ "$HOOKS_VERBOSE" == "true" ]] && \
        echo "hook_register: registered $point -> $func" >&2

    return 0
}

#######################################
# Unregister a hook function
# Arguments:
#   $1 - hook point name
#   $2 - function name to remove
# Returns:
#   0 on success
#######################################
hook_unregister() {
    local point="$1"
    local func="$2"

    if [[ -z "${HOOKS[$point]:-}" ]]; then
        return 0  # Nothing to unregister
    fi

    # Remove function from hooks list
    local new_hooks=""
    local existing
    for existing in ${(s: :)HOOKS[$point]}; do
        if [[ "$existing" != "$func" ]]; then
            if [[ -z "$new_hooks" ]]; then
                new_hooks="$existing"
            else
                new_hooks="$new_hooks $existing"
            fi
        fi
    done

    HOOKS[$point]="$new_hooks"

    [[ "$HOOKS_VERBOSE" == "true" ]] && \
        echo "hook_unregister: removed $point -> $func" >&2

    return 0
}

#######################################
# Run all hooks for a point
# Arguments:
#   $1 - hook point name (or --verbose flag)
#   $@ - additional args passed to hooks
# Options:
#   --verbose   Show detailed hook execution
#   --no-hooks  Skip hook execution entirely
# Returns:
#   0 if all succeed, 1 if any fail (respects fail_fast)
#######################################
hook_run() {
    local verbose_override=""
    local skip_hooks=""

    # Parse flags
    while [[ "$1" == --* ]]; do
        case "$1" in
            --verbose) verbose_override="true"; shift ;;
            --no-hooks) skip_hooks="true"; shift ;;
            *) break ;;
        esac
    done

    local point="$1"
    shift
    local args=("$@")
    local failed=0

    # Local verbose setting (flag overrides global)
    local verbose="${verbose_override:-$HOOKS_VERBOSE}"

    # Temporarily set global for internal functions if --verbose was passed
    local saved_verbose="$HOOKS_VERBOSE"
    [[ -n "$verbose_override" ]] && HOOKS_VERBOSE="$verbose_override"

    # --no-hooks flag
    if [[ "$skip_hooks" == "true" ]]; then
        [[ "$verbose" == "true" ]] && \
            echo "hook_run: skipped via --no-hooks flag" >&2
        return 0
    fi

    # Master disable check
    if [[ "$HOOKS_DISABLED" == "true" ]]; then
        [[ "$verbose" == "true" ]] && \
            echo "hook_run: hooks disabled globally" >&2
        return 0
    fi

    # Check if hooks feature is enabled (if feature registry available)
    if type feature_enabled &>/dev/null; then
        if ! feature_enabled "hooks" 2>/dev/null; then
            [[ "$verbose" == "true" ]] && \
                echo "hook_run: hooks feature disabled" >&2
            return 0
        fi
    fi

    # Check parent feature for this hook point
    local parent_feature="${HOOK_FEATURE_MAP[$point]:-}"
    if [[ -n "$parent_feature" ]] && type feature_enabled &>/dev/null; then
        if ! feature_enabled "$parent_feature" 2>/dev/null; then
            [[ "$verbose" == "true" ]] && \
                echo "hook_run: parent feature '$parent_feature' disabled for $point" >&2
            return 0
        fi
    fi

    # Validate hook point
    if ! hook_valid_point "$point"; then
        echo "hook_run: invalid hook point: $point" >&2
        return 1
    fi

    [[ "$verbose" == "true" ]] && \
        echo "hook_run: running hooks for $point" >&2

    # 1. Run file-based hooks first (from hooks directory)
    if [[ -d "${HOOKS_DIR}/${point}" ]]; then
        local script
        for script in "${HOOKS_DIR}/${point}"/*.{sh,zsh}(N); do
            [[ -f "$script" ]] || continue
            [[ -x "$script" ]] || {
                [[ "$verbose" == "true" ]] && \
                    echo "hook_run: skipping non-executable: $script" >&2
                continue
            }
            _hook_exec_script "$script" "${args[@]}" || {
                failed=1
                echo "hook_run: script failed: $script" >&2
                if [[ "$HOOKS_FAIL_FAST" == "true" ]]; then
                    echo "hook_run: stopping (fail_fast=true)" >&2
                    HOOKS_VERBOSE="$saved_verbose"
                    return 1
                fi
            }
        done
    fi

    # 2. Run registered function hooks
    local funcs="${HOOKS[$point]:-}"
    if [[ -n "$funcs" ]]; then
        local func
        for func in ${(s: :)funcs}; do
            [[ -z "$func" ]] && continue
            _hook_exec_func "$func" "${args[@]}" || {
                failed=1
                echo "hook_run: function failed: $func" >&2
                if [[ "$HOOKS_FAIL_FAST" == "true" ]]; then
                    echo "hook_run: stopping (fail_fast=true)" >&2
                    HOOKS_VERBOSE="$saved_verbose"
                    return 1
                fi
            }
        done
    fi

    # 3. Run JSON-configured hooks
    _hook_run_json_hooks "$point" "${args[@]}" || {
        failed=1
        if [[ "$HOOKS_FAIL_FAST" == "true" ]]; then
            HOOKS_VERBOSE="$saved_verbose"
            return 1
        fi
    }

    # Restore global verbose setting
    HOOKS_VERBOSE="$saved_verbose"
    return $failed
}

#######################################
# Execute a hook script with optional timeout
# Arguments:
#   $1 - script path
#   $@ - additional args
# Returns:
#   script exit code
#######################################
_hook_exec_script() {
    local script="$1"
    shift

    [[ "$HOOKS_VERBOSE" == "true" ]] && \
        echo "  hook_exec_script: $script" >&2

    if command -v timeout &>/dev/null && [[ "$HOOKS_TIMEOUT" -gt 0 ]]; then
        timeout "$HOOKS_TIMEOUT" "$script" "$@"
    else
        "$script" "$@"
    fi
}

#######################################
# Execute a hook function
# Arguments:
#   $1 - function name
#   $@ - additional args
# Returns:
#   function exit code
#######################################
_hook_exec_func() {
    local func="$1"
    shift

    [[ "$HOOKS_VERBOSE" == "true" ]] && \
        echo "  hook_exec_func: $func" >&2

    # Check if function exists
    if ! type "$func" &>/dev/null; then
        echo "  hook_exec_func: function not found: $func" >&2
        return 1
    fi

    "$func" "$@"
}

#######################################
# Run hooks from JSON config
# Arguments:
#   $1 - hook point
#   $@ - additional args
# Returns:
#   0 if all succeed, 1 if any fail
#######################################
_hook_run_json_hooks() {
    local point="$1"
    shift
    local args=("$@")
    local failed=0

    # Check if config file exists
    [[ -f "$HOOKS_CONFIG" ]] || return 0

    # Check if jq is available
    if ! command -v jq &>/dev/null; then
        [[ "$HOOKS_VERBOSE" == "true" ]] && \
            echo "  hook_run_json: jq not available, skipping JSON hooks" >&2
        return 0
    fi

    # Get hooks for this point
    local hooks_json
    hooks_json=$(jq -r ".hooks.\"$point\" // []" "$HOOKS_CONFIG" 2>/dev/null) || return 0
    [[ "$hooks_json" == "[]" || "$hooks_json" == "null" ]] && return 0

    # Get hook count
    local count
    count=$(echo "$hooks_json" | jq 'length' 2>/dev/null) || return 0
    [[ "$count" -eq 0 ]] && return 0

    local i=0
    while (( i < count )); do
        # Check if enabled (default: true)
        local enabled
        enabled=$(echo "$hooks_json" | jq -r ".[$i].enabled" 2>/dev/null)
        [[ "$enabled" == "null" ]] && enabled="true"
        if [[ "$enabled" != "true" ]]; then
            ((i++))
            continue
        fi

        local name
        name=$(echo "$hooks_json" | jq -r ".[$i].name // \"hook-$i\"" 2>/dev/null)

        local fail_ok
        fail_ok=$(echo "$hooks_json" | jq -r ".[$i].fail_ok" 2>/dev/null)
        [[ "$fail_ok" == "null" ]] && fail_ok="false"

        # Get execution type: command, script, or function
        local cmd script func
        cmd=$(echo "$hooks_json" | jq -r ".[$i].command // empty" 2>/dev/null)
        script=$(echo "$hooks_json" | jq -r ".[$i].script // empty" 2>/dev/null)
        func=$(echo "$hooks_json" | jq -r ".[$i].function // empty" 2>/dev/null)

        local result=0

        if [[ -n "$cmd" ]]; then
            [[ "$HOOKS_VERBOSE" == "true" ]] && \
                echo "  hook_json: running command ($name): $cmd" >&2
            # Run in subshell to prevent 'exit' from killing our shell
            ( eval "$cmd" ) || result=$?
        elif [[ -n "$script" ]]; then
            # Expand ~ to $HOME
            script="${script/#\~/$HOME}"
            if [[ -x "$script" ]]; then
                _hook_exec_script "$script" "${args[@]}" || result=$?
            else
                echo "  hook_json: script not executable: $script" >&2
                result=1
            fi
        elif [[ -n "$func" ]]; then
            if type "$func" &>/dev/null; then
                _hook_exec_func "$func" "${args[@]}" || result=$?
            else
                echo "  hook_json: function not found: $func" >&2
                result=1
            fi
        fi

        if (( result != 0 )); then
            if [[ "$fail_ok" != "true" ]]; then
                echo "hook_run: JSON hook failed: $name" >&2
                failed=1
                if [[ "$HOOKS_FAIL_FAST" == "true" ]]; then
                    return 1
                fi
            else
                [[ "$HOOKS_VERBOSE" == "true" ]] && \
                    echo "  hook_json: $name failed but fail_ok=true" >&2
            fi
        fi

        ((i++))
    done

    return $failed
}

#######################################
# List all registered hooks
# Arguments:
#   $1 - (optional) specific hook point to list
# Outputs:
#   List of hooks to stdout
#######################################
hook_list() {
    local point="${1:-}"

    if [[ -n "$point" ]]; then
        # List hooks for specific point
        if ! hook_valid_point "$point"; then
            echo "hook_list: invalid hook point: $point" >&2
            return 1
        fi

        echo "Hooks for: $point"
        echo ""

        # File-based hooks
        if [[ -d "${HOOKS_DIR}/${point}" ]]; then
            local scripts=("${HOOKS_DIR}/${point}"/*.{sh,zsh}(N))
            if [[ ${#scripts[@]} -gt 0 ]]; then
                echo "  File-based:"
                local script
                for script in "${scripts[@]}"; do
                    [[ -f "$script" ]] || continue
                    local status="[x]"
                    [[ -x "$script" ]] && status="[+]"
                    echo "    $status $(basename "$script")"
                done
            fi
        fi

        # Registered functions
        local funcs="${HOOKS[$point]:-}"
        if [[ -n "$funcs" ]]; then
            echo "  Functions:"
            local func
            for func in ${(s: :)funcs}; do
                echo "    - $func"
            done
        fi

        # JSON config
        if [[ -f "$HOOKS_CONFIG" ]] && command -v jq &>/dev/null; then
            local json_hooks
            json_hooks=$(jq -r ".hooks.\"$point\"[]?.name // empty" "$HOOKS_CONFIG" 2>/dev/null)
            if [[ -n "$json_hooks" ]]; then
                echo "  JSON config:"
                echo "$json_hooks" | while read -r name; do
                    [[ -n "$name" ]] && echo "    - $name"
                done
            fi
        fi
    else
        # List all hook points with counts
        echo "All hook points:"
        echo ""

        local p
        for p in "${HOOK_POINTS[@]}"; do
            local count=0

            # Count file-based hooks
            if [[ -d "${HOOKS_DIR}/${p}" ]]; then
                local scripts=("${HOOKS_DIR}/${p}"/*.{sh,zsh}(N))
                count=$((count + ${#scripts[@]}))
            fi

            # Count registered functions
            if [[ -n "${HOOKS[$p]:-}" ]]; then
                local funcs_count
                funcs_count=$(echo "${HOOKS[$p]}" | wc -w)
                count=$((count + funcs_count))
            fi

            # Count JSON hooks
            if [[ -f "$HOOKS_CONFIG" ]] && command -v jq &>/dev/null; then
                local json_count
                json_count=$(jq -r ".hooks.\"$p\" | length // 0" "$HOOKS_CONFIG" 2>/dev/null || echo 0)
                count=$((count + json_count))
            fi

            printf "  %-25s %d hook(s)\n" "$p" "$count"
        done
    fi
}

#######################################
# Get list of valid hook points
# Outputs:
#   Hook points to stdout
#######################################
hook_points() {
    local p
    for p in "${HOOK_POINTS[@]}"; do
        echo "$p"
    done
}

#######################################
# Initialize hooks from config
# Should be called during shell/script init
#######################################
hook_init() {
    # Load settings from JSON config
    if [[ -f "$HOOKS_CONFIG" ]] && command -v jq &>/dev/null; then
        local val

        val=$(jq -r '.settings.fail_fast // empty' "$HOOKS_CONFIG" 2>/dev/null)
        [[ -n "$val" && "$val" != "null" ]] && HOOKS_FAIL_FAST="$val"

        val=$(jq -r '.settings.verbose // empty' "$HOOKS_CONFIG" 2>/dev/null)
        [[ -n "$val" && "$val" != "null" ]] && HOOKS_VERBOSE="$val"

        val=$(jq -r '.settings.timeout // empty' "$HOOKS_CONFIG" 2>/dev/null)
        [[ -n "$val" && "$val" != "null" ]] && HOOKS_TIMEOUT="$val"
    fi

    [[ "$HOOKS_VERBOSE" == "true" ]] && \
        echo "hook_init: initialized (fail_fast=$HOOKS_FAIL_FAST, verbose=$HOOKS_VERBOSE, timeout=$HOOKS_TIMEOUT)" >&2
}

#######################################
# Clear all registered hooks (useful for testing)
#######################################
hook_clear() {
    HOOKS=()
    [[ "$HOOKS_VERBOSE" == "true" ]] && \
        echo "hook_clear: all hooks cleared" >&2
}

# ============================================================
# Export for use in scripts
# ============================================================
export HOOKS_DIR HOOKS_CONFIG HOOKS_FAIL_FAST HOOKS_VERBOSE HOOKS_TIMEOUT HOOKS_DISABLED
