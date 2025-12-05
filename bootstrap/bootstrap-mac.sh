#!/usr/bin/env bash
# ============================================================
# FILE: bootstrap-mac.sh
# macOS bootstrap script
# Usage:
#   ./bootstrap-mac.sh              # Standard bootstrap
#   ./bootstrap-mac.sh --interactive  # Prompt for options
#   ./bootstrap-mac.sh --help       # Show help
# ============================================================
set -euo pipefail

# DOTFILES_DIR is parent of bootstrap/
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Set platform name before sourcing common (used in help text)
export PLATFORM_NAME="macOS"

# Source shared bootstrap functions
# shellcheck source=bootstrap/_common.sh
source "$DOTFILES_DIR/bootstrap/_common.sh"

# Parse arguments (sets INTERACTIVE flag)
parse_bootstrap_args "$@"

# Run interactive configuration if --interactive
run_interactive_config

echo "=== macOS bootstrap starting ==="

# Run pre-bootstrap hooks
run_hook "pre_bootstrap"

# ============================================================
# 1. Xcode CLI tools (macOS-specific)
# ============================================================
if ! xcode-select -p >/dev/null 2>&1; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install || true
    echo "Please rerun this script after Xcode tools finish installing."
    exit 0
fi

# ============================================================
# 2. Homebrew (macOS-specific paths)
# ============================================================
if ! command -v brew >/dev/null 2>&1; then
    install_homebrew

    # After fresh installation, detect which Homebrew was installed
    # Apple Silicon: /opt/homebrew, Intel: /usr/local
    if [[ -d /opt/homebrew/bin ]]; then
        BREW_PREFIX="/opt/homebrew"
    elif [[ -d /usr/local/bin/brew ]]; then
        BREW_PREFIX="/usr/local"
    fi

    # Add to .zprofile and activate for this session
    if [[ -n "${BREW_PREFIX:-}" ]]; then
        add_brew_to_zprofile "$BREW_PREFIX"
        eval "$("$BREW_PREFIX/bin/brew" shellenv)"
    else
        echo "WARNING: Homebrew installation location not found."
    fi
else
    # Homebrew already installed - just activate for this session
    eval "$(brew shellenv)"
fi

# ============================================================
# 3. Brew Bundle (shared)
# ============================================================
run_brew_bundle

# ============================================================
# 4. Workspace layout (shared)
# ============================================================
setup_workspace_layout

# ============================================================
# 5. /workspace symlink (shared)
# ============================================================
setup_workspace_symlink

# ============================================================
# 6. Dotfiles symlinks (shared)
# ============================================================
link_dotfiles

# ============================================================
# Done
# ============================================================
# Run post-bootstrap hooks
run_hook "post_bootstrap"

echo "=== macOS bootstrap complete ==="
echo ""
echo "Next step:"
echo "  dotfiles setup"
echo ""
echo "This will configure your vault backend and restore secrets."
