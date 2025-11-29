#!/usr/bin/env bash
# ============================================================
# FILE: bootstrap/_common.sh
# Shared functions for bootstrap scripts (macOS/Linux)
# Source this file: source "$(dirname "$0")/bootstrap/_common.sh"
# ============================================================

# Prevent multiple sourcing
if [[ -n "${_BOOTSTRAP_COMMON_LOADED:-}" ]]; then
    return 0
fi
_BOOTSTRAP_COMMON_LOADED=1

# ============================================================
# Source shared logging (provides info, pass, warn, fail, etc.)
# ============================================================
BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$BOOTSTRAP_DIR")"

# shellcheck source=../lib/_logging.sh
source "$DOTFILES_DIR/lib/_logging.sh"

# ============================================================
# Script configuration (set by bootstrap scripts)
# ============================================================
PLATFORM_NAME="${PLATFORM_NAME:-Unknown}"
INTERACTIVE=false

# ============================================================
# Argument parsing
# ============================================================
parse_bootstrap_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --interactive|-i)
                INTERACTIVE=true
                shift
                ;;
            --help|-h)
                show_bootstrap_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

show_bootstrap_help() {
    echo "$PLATFORM_NAME Bootstrap Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --interactive, -i    Prompt for configuration options"
    echo "  --help, -h           Show this help"
    echo ""
    echo "Environment variables:"
    echo "  SKIP_WORKSPACE_SYMLINK=true   Skip /workspace symlink creation"
    echo "  SKIP_CLAUDE_SETUP=true        Skip Claude Code configuration"
}

# ============================================================
# Interactive prompts
# ============================================================
prompt_yes_no() {
    local prompt="$1"
    local default="${2:-Y}"
    local result

    if [[ "$default" == "Y" ]]; then
        prompt="$prompt [Y/n]"
    else
        prompt="$prompt [y/N]"
    fi

    echo -en "${CYAN}$prompt ${NC}"
    read -r result

    if [[ -z "$result" ]]; then
        result="$default"
    fi

    [[ "$result" =~ ^[Yy] ]]
}

run_interactive_config() {
    if $INTERACTIVE; then
        echo ""
        echo -e "${BLUE}=== Interactive Bootstrap Configuration ($PLATFORM_NAME) ===${NC}"
        echo ""

        if ! prompt_yes_no "Enable /workspace symlink for portable Claude sessions?" "Y"; then
            export SKIP_WORKSPACE_SYMLINK=true
        fi

        if ! prompt_yes_no "Configure Claude Code integration?" "Y"; then
            export SKIP_CLAUDE_SETUP=true
        fi

        echo ""
    fi
}

# ============================================================
# Workspace setup (shared between macOS and Linux)
# ============================================================
setup_workspace_layout() {
    echo "Ensuring ~/workspace layout..."
    mkdir -p "$HOME/workspace"
    mkdir -p "$HOME/workspace/code"
}

# ============================================================
# /workspace symlink setup (shared between macOS and Linux)
# ============================================================
setup_workspace_symlink() {
    # Creates /workspace -> ~/workspace for consistent Claude session paths.
    # Optional: enables session portability across machines if you use multiple.
    SKIP_WORKSPACE_SYMLINK="${SKIP_WORKSPACE_SYMLINK:-false}"

    if [[ "$SKIP_WORKSPACE_SYMLINK" != "true" ]] && [[ ! -e /workspace ]]; then
        echo "Creating /workspace symlink (requires sudo)..."
        if sudo ln -sfn "$HOME/workspace" /workspace; then
            echo "Created /workspace -> $HOME/workspace"
        else
            echo "WARNING: Could not create /workspace symlink."
            echo "         Claude sessions will use OS-specific paths."
            echo "         To fix manually: sudo ln -sfn $HOME/workspace /workspace"
        fi
    elif [[ "$SKIP_WORKSPACE_SYMLINK" != "true" ]] && [[ -L /workspace ]]; then
        # Already a symlink - verify it points to the right place
        local current_target
        current_target=$(readlink /workspace)
        if [[ "$current_target" != "$HOME/workspace" ]]; then
            echo "Updating /workspace symlink..."
            sudo rm /workspace && sudo ln -sfn "$HOME/workspace" /workspace
            echo "Updated /workspace -> $HOME/workspace"
        else
            echo "/workspace symlink already correct."
        fi
    elif [[ "$SKIP_WORKSPACE_SYMLINK" = "true" ]]; then
        echo "Skipping /workspace symlink (SKIP_WORKSPACE_SYMLINK=true)"
    elif [[ -e /workspace ]]; then
        echo "WARNING: /workspace exists but is not a symlink. Skipping."
    fi
}

# ============================================================
# Dotfiles symlinks (shared between macOS and Linux)
# ============================================================
link_dotfiles() {
    echo "Linking dotfiles..."
    "$DOTFILES_DIR/bootstrap/bootstrap-dotfiles.sh"
}

# ============================================================
# Brew bundle (shared between macOS and Linux)
# ============================================================
run_brew_bundle() {
    if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
        echo "Running brew bundle ($PLATFORM_NAME)..."
        brew bundle --file="$DOTFILES_DIR/Brewfile"
    else
        echo "No Brewfile found at $DOTFILES_DIR/Brewfile, skipping brew bundle."
    fi
}

# ============================================================
# Homebrew shellenv setup
# ============================================================
add_brew_to_zprofile() {
    local brew_path="$1"
    local shellenv_line="eval \"\$(${brew_path}/bin/brew shellenv)\""

    if [[ -d "$brew_path/bin" ]]; then
        # Only add if not already present
        if ! grep -qF "$brew_path/bin/brew shellenv" "$HOME/.zprofile" 2>/dev/null; then
            echo "Adding Homebrew to .zprofile ($brew_path)..."
            echo "$shellenv_line" >> "$HOME/.zprofile"
        fi
        eval "$("$brew_path/bin/brew" shellenv)"
        return 0
    fi
    return 1
}
