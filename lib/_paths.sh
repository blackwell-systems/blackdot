#!/usr/bin/env bash
# ============================================================
# FILE: lib/_paths.sh
# Centralized path resolution for dotfiles CLI tools
#
# Provides consistent path detection across all tools with
# support for configurable workspace target.
#
# Usage:
#   source "$DOTFILES_DIR/lib/_paths.sh"
#   workspace=$(get_workspace_target)
#   dotfiles_dir=$(get_dotfiles_dir)
# ============================================================

# Prevent multiple sourcing
[[ -n "${_PATHS_SOURCED:-}" ]] && return 0
_PATHS_SOURCED=1

# ============================================================
# Workspace Target Resolution
# ============================================================
# Priority order:
#   1. WORKSPACE_TARGET environment variable
#   2. config.json paths.workspace_target
#   3. Default: $HOME/workspace
# ============================================================

get_workspace_target() {
    # 1. Check environment variable first (highest priority)
    if [[ -n "${WORKSPACE_TARGET:-}" ]]; then
        # Expand ~ if present
        echo "${WORKSPACE_TARGET/#\~/$HOME}"
        return 0
    fi

    # 2. Check config file
    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/config.json"
    if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
        local configured
        configured=$(jq -r '.paths.workspace_target // empty' "$config_file" 2>/dev/null)
        if [[ -n "$configured" && "$configured" != "null" && "$configured" != "" ]]; then
            # Expand ~ to $HOME
            echo "${configured/#\~/$HOME}"
            return 0
        fi
    fi

    # 3. Default
    echo "$HOME/workspace"
}

# ============================================================
# Dotfiles Directory Resolution
# ============================================================
# Priority order:
#   1. DOTFILES_DIR environment variable
#   2. $WORKSPACE_TARGET/dotfiles (if exists)
#   3. /workspace/dotfiles (symlink)
#   4. ~/workspace/dotfiles (legacy default)
#   5. ~/.dotfiles (common alternative)
#   6. ~/dotfiles (another common location)
# ============================================================

get_dotfiles_dir() {
    # 1. Check environment variable first
    if [[ -n "${DOTFILES_DIR:-}" && -d "${DOTFILES_DIR}" ]]; then
        echo "$DOTFILES_DIR"
        return 0
    fi

    # 2. Check configured workspace target
    local workspace_target
    workspace_target="$(get_workspace_target)"

    if [[ -d "$workspace_target/dotfiles" ]]; then
        echo "$workspace_target/dotfiles"
        return 0
    fi

    # 3. Check /workspace symlink (portable path)
    if [[ -d "/workspace/dotfiles" ]]; then
        echo "/workspace/dotfiles"
        return 0
    fi

    # 4. Legacy default location
    if [[ -d "$HOME/workspace/dotfiles" ]]; then
        echo "$HOME/workspace/dotfiles"
        return 0
    fi

    # 5. Common alternative locations
    if [[ -d "$HOME/.dotfiles" ]]; then
        echo "$HOME/.dotfiles"
        return 0
    fi

    if [[ -d "$HOME/dotfiles" ]]; then
        echo "$HOME/dotfiles"
        return 0
    fi

    # Not found - return empty and let caller handle error
    return 1
}

# ============================================================
# Workspace Symlink Validation
# ============================================================
# Check if /workspace symlink points to the expected target
# Returns:
#   0 - symlink correct
#   1 - symlink missing
#   2 - symlink points to wrong target
#   3 - /workspace exists but is not a symlink
# ============================================================

check_workspace_symlink() {
    local expected_target
    expected_target="$(get_workspace_target)"

    if [[ -L "/workspace" ]]; then
        local actual_target
        actual_target=$(readlink /workspace 2>/dev/null)
        if [[ "$actual_target" == "$expected_target" ]]; then
            return 0  # Correct
        else
            return 2  # Wrong target
        fi
    elif [[ -e "/workspace" ]]; then
        return 3  # Exists but not a symlink
    else
        return 1  # Missing
    fi
}

# ============================================================
# Helper: Get workspace symlink status message
# ============================================================

get_workspace_symlink_status() {
    local expected_target
    expected_target="$(get_workspace_target)"

    check_workspace_symlink
    local status=$?

    case $status in
        0)
            echo "correct"
            echo "/workspace -> $expected_target"
            ;;
        1)
            echo "missing"
            echo "/workspace symlink not configured"
            ;;
        2)
            local actual_target
            actual_target=$(readlink /workspace 2>/dev/null)
            echo "wrong_target"
            echo "/workspace -> $actual_target (expected: $expected_target)"
            ;;
        3)
            echo "not_symlink"
            echo "/workspace exists but is not a symlink"
            ;;
    esac

    return $status
}
