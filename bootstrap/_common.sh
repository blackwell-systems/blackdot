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
# Hooks support (call zsh hooks from bash)
# ============================================================
# Run lifecycle hooks via zsh (since hooks library is zsh)
# Usage: run_hook "pre_bootstrap"
run_hook() {
    local hook_point="$1"
    shift

    # Skip if zsh not available
    if ! command -v zsh &>/dev/null; then
        return 0
    fi

    # Skip if hooks library doesn't exist
    if [[ ! -f "$DOTFILES_DIR/lib/_hooks.sh" ]]; then
        return 0
    fi

    # Run hooks via zsh (silently fail if hooks disabled)
    zsh -c "
        source '$DOTFILES_DIR/lib/_hooks.sh' 2>/dev/null || exit 0
        hook_run '$hook_point' \"\$@\"
    " -- "$@" 2>/dev/null || true
}

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
    echo "  WORKSPACE_TARGET=~/code       Custom workspace directory (default: ~/workspace)"
    echo "  SKIP_WORKSPACE_SYMLINK=true   Skip /workspace symlink creation"
    echo "  SKIP_CLAUDE_SETUP=true        Skip Claude Code configuration"
    echo "  BREWFILE_TIER=minimal         Use Brewfile.minimal (essentials only)"
    echo "  BREWFILE_TIER=enhanced        Use Brewfile.enhanced (modern tools, no containers)"
    echo "  BREWFILE_TIER=full            Use Brewfile (everything) [default]"
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

        # Package tier selection (if not already set via env var)
        if [[ -z "${BREWFILE_TIER:-}" ]]; then
            echo ""
            echo -e "${CYAN}Which package tier would you like?${NC}"
            echo ""
            echo "  1) minimal    ~18 packages  (~2 min)   # Essentials only"
            echo "  2) enhanced   ~43 packages  (~5 min)   # Modern tools, no containers  <- RECOMMENDED"
            echo "  3) full       ~61 packages  (~10 min)  # Everything (Docker, etc.)"
            echo ""
            echo -en "${CYAN}Choice [1-3, default=2]: ${NC}"
            read -r tier_choice
            tier_choice=${tier_choice:-2}

            case "$tier_choice" in
                1)
                    export BREWFILE_TIER="minimal"
                    ;;
                3)
                    export BREWFILE_TIER="full"
                    ;;
                *)
                    export BREWFILE_TIER="enhanced"
                    ;;
            esac
            echo "Selected tier: $BREWFILE_TIER"
        fi

        echo ""
    fi
}

# ============================================================
# Workspace setup (shared between macOS and Linux)
# ============================================================

# Get workspace target from env var, config, or default
# This is inlined here to avoid dependency on _paths.sh during bootstrap
_get_workspace_target() {
    # 1. Check environment variable first
    if [[ -n "${WORKSPACE_TARGET:-}" ]]; then
        echo "${WORKSPACE_TARGET/#\~/$HOME}"
        return 0
    fi

    # 2. Check config file
    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/config.json"
    if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
        local configured
        configured=$(jq -r '.paths.workspace_target // empty' "$config_file" 2>/dev/null)
        if [[ -n "$configured" && "$configured" != "null" && "$configured" != "" ]]; then
            echo "${configured/#\~/$HOME}"
            return 0
        fi
    fi

    # 3. Default
    echo "$HOME/workspace"
}

setup_workspace_layout() {
    local workspace_target
    workspace_target="$(_get_workspace_target)"

    echo "Ensuring workspace layout at $workspace_target..."
    mkdir -p "$workspace_target"
    mkdir -p "$workspace_target/code"
}

# ============================================================
# /workspace symlink setup (shared between macOS and Linux)
# ============================================================
setup_workspace_symlink() {
    # Creates /workspace -> $WORKSPACE_TARGET for consistent Claude session paths.
    # The /workspace path stays constant for portability; only the target changes.
    # Optional: enables session portability across machines if you use multiple.
    SKIP_WORKSPACE_SYMLINK="${SKIP_WORKSPACE_SYMLINK:-false}"

    if [[ "$SKIP_WORKSPACE_SYMLINK" = "true" ]]; then
        echo "Skipping /workspace symlink (SKIP_WORKSPACE_SYMLINK=true)"
        return 0
    fi

    # Get the configured workspace target
    local target
    target="$(_get_workspace_target)"

    # Check if /workspace already exists and is correct
    if [[ -L /workspace ]]; then
        local current_target
        current_target=$(readlink /workspace)
        if [[ "$current_target" == "$target" ]]; then
            echo "/workspace symlink already correct -> $target"
            return 0
        else
            echo "Updating /workspace symlink..."
            sudo rm /workspace && sudo ln -sfn "$target" /workspace
            echo "Updated /workspace -> $target"
            return 0
        fi
    elif [[ -e /workspace ]]; then
        echo "WARNING: /workspace exists but is not a symlink. Skipping."
        return 0
    fi

    # Detect OS for platform-specific handling
    local os_type
    os_type="$(uname -s)"

    # Try to create the symlink
    echo "Creating /workspace symlink (requires sudo)..."
    if sudo ln -sfn "$target" /workspace 2>/dev/null; then
        pass "Created /workspace -> $target"
        return 0
    fi

    # Handle macOS read-only filesystem (Catalina+)
    if [[ "$os_type" == "Darwin" ]]; then
        warn "Could not create /workspace symlink (read-only filesystem)"
        echo ""
        echo "Modern macOS requires using synthetic.conf for root-level symlinks."
        echo ""
        echo "To fix this, run the following commands:"
        echo ""
        echo "  1. Create synthetic.conf entry:"
        echo "     ${CYAN}echo -e 'workspace\t$target' | sudo tee -a /etc/synthetic.conf${NC}"
        echo ""
        echo "  2. Reboot to apply:"
        echo "     ${CYAN}sudo reboot${NC}"
        echo ""
        echo "  Or wait until next reboot - the symlink will appear automatically."
        echo ""
        info "For now, Claude sessions will use $target paths (still works fine)"
    else
        # Non-macOS failure
        warn "Could not create /workspace symlink"
        echo "  To fix manually: sudo ln -sfn $target /workspace"
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
# Template rendering (machine-specific configs)
# ============================================================
render_templates() {
    local template_script="$DOTFILES_DIR/bin/dotfiles-template"
    local local_vars="$DOTFILES_DIR/templates/_variables.local.sh"

    # Check if template system is configured
    if [[ ! -f "$local_vars" ]]; then
        echo "Template system not configured yet."
        echo "Run 'dotfiles template init' after bootstrap to set up machine-specific configs."
        return 0
    fi

    # Render templates if configured
    if [[ -x "$template_script" ]]; then
        echo "Rendering machine-specific templates..."
        "$template_script" render --force
    else
        echo "Template script not found or not executable: $template_script"
    fi
}

# ============================================================
# Brew bundle (shared between macOS and Linux)
# ============================================================
run_brew_bundle() {
    # Determine which Brewfile to use based on BREWFILE_TIER
    local brewfile="$DOTFILES_DIR/Brewfile"
    local tier="${BREWFILE_TIER:-full}"

    case "$tier" in
        minimal)
            brewfile="$DOTFILES_DIR/Brewfile.minimal"
            echo "Using minimal tier (essentials only)..."
            ;;
        enhanced)
            brewfile="$DOTFILES_DIR/Brewfile.enhanced"
            echo "Using enhanced tier (modern tools, no containers)..."
            ;;
        full|*)
            brewfile="$DOTFILES_DIR/Brewfile"
            echo "Using full tier (everything)..."
            ;;
    esac

    if [[ ! -f "$brewfile" ]]; then
        echo "No Brewfile found at $brewfile, skipping brew bundle."
        return 0
    fi

    echo "Running brew bundle ($PLATFORM_NAME)..."

    # Run brew bundle, but don't fail the entire bootstrap if there are issues
    if ! brew bundle --file="$brewfile"; then
        warn "Brew bundle completed with warnings"

        # Auto-fix common link conflicts (e.g., npm-installed packages conflicting with brew)
        info "Checking for link conflicts..."

        # Try to fix unlinked packages from the Brewfile
        # Parse the Brewfile and try to link each formula
        local failed_links=()
        while IFS= read -r line; do
            # Extract formula names from 'brew "formula-name"' lines
            if [[ "$line" =~ ^brew[[:space:]]+\"([^\"]+)\" ]]; then
                local formula="${BASH_REMATCH[1]}"
                # Check if it's installed but not linked
                if brew list --formula "$formula" &>/dev/null; then
                    if ! brew --prefix "$formula" &>/dev/null; then
                        info "Attempting to link $formula..."
                        if brew link --overwrite "$formula" 2>/dev/null; then
                            pass "Linked $formula"
                        else
                            warn "Could not link $formula (non-critical)"
                            failed_links+=("$formula")
                        fi
                    fi
                fi
            fi
        done < "$brewfile"

        if [[ ${#failed_links[@]} -gt 0 ]]; then
            warn "Some packages could not be linked: ${failed_links[*]}"
            info "You can manually fix with: brew link --overwrite <package>"
        fi

        pass "Package installation completed"
        info "Run 'brew doctor' if you encounter issues"
    else
        pass "All packages installed successfully"
    fi
}

# ============================================================
# Homebrew installation with retry logic
# ============================================================
install_homebrew() {
    local max_retries=3
    local retry_delay=2
    local attempt=1

    info "Installing Homebrew..."

    while [[ $attempt -le $max_retries ]]; do
        if [[ $attempt -gt 1 ]]; then
            warn "Retry attempt $attempt of $max_retries (waiting ${retry_delay}s)..."
            sleep "$retry_delay"
            retry_delay=$((retry_delay * 2))
        fi

        # Try to install Homebrew
        if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>&1; then
            pass "Homebrew installed successfully"
            return 0
        fi

        attempt=$((attempt + 1))
    done

    # Failed after all retries
    fail "Failed to install Homebrew after $max_retries attempts"
    warn "This could be due to:"
    warn "  - Network connectivity issues"
    warn "  - GitHub rate limiting"
    warn "  - System requirements not met"
    echo ""
    warn "You can:"
    warn "  1. Check your internet connection and try again"
    warn "  2. Install Homebrew manually: https://brew.sh"
    warn "  3. Continue without Homebrew (not recommended)"
    echo ""

    # Ask if they want to continue without Homebrew
    echo -n "Continue without Homebrew? [y/N]: "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        warn "Continuing without Homebrew (package installation will be skipped)"
        return 0
    else
        fail "Bootstrap aborted. Please install Homebrew and try again."
        exit 1
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
