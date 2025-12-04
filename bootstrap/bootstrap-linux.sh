#!/usr/bin/env bash
# ============================================================
# FILE: bootstrap-linux.sh
# Linux bootstrap (Ubuntu/Debian/WSL2/Lima)
# Usage:
#   ./bootstrap-linux.sh              # Standard bootstrap
#   ./bootstrap-linux.sh --interactive  # Prompt for options
#   ./bootstrap-linux.sh --help       # Show help
# ============================================================
set -euo pipefail

# DOTFILES_DIR is parent of bootstrap/
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ============================================================
# Detect environment (before sourcing common)
# ============================================================
IS_WSL=false
IS_LIMA=false
export PLATFORM_NAME="Linux"

if grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
    IS_WSL=true
    export PLATFORM_NAME="WSL2"
elif [[ -n "${LIMA_INSTANCE:-}" ]]; then
    IS_LIMA=true
    export PLATFORM_NAME="Lima"
fi

# Source shared bootstrap functions
# shellcheck source=bootstrap/_common.sh
source "$DOTFILES_DIR/bootstrap/_common.sh"

# Parse arguments (sets INTERACTIVE flag)
parse_bootstrap_args "$@"

# Run interactive configuration if --interactive
run_interactive_config

echo "=== Linux bootstrap starting ($PLATFORM_NAME) ==="

# ============================================================
# 1. Basic apt packages (Linux-specific)
# ============================================================
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential curl file git zsh

# WSL-specific: Windows interop tools
if $IS_WSL; then
    echo "Detected WSL2, installing Windows interop tools..."
    # wslu provides wslview (xdg-open equivalent), wslpath, etc.
    sudo apt-get install -y wslu 2>/dev/null || echo "wslu not available, skipping"
fi

# ============================================================
# 2. Linuxbrew (Linux-specific path)
# ============================================================
BREW_LINUX_PATH="/home/linuxbrew/.linuxbrew"

if ! command -v brew >/dev/null 2>&1; then
    install_homebrew
fi

# Ensure brew shellenv is in .zprofile
if [[ -d "$BREW_LINUX_PATH/bin" ]]; then
    add_brew_to_zprofile "$BREW_LINUX_PATH"
fi

# Verify brew is available
if ! command -v brew >/dev/null 2>&1; then
    echo "WARNING: Linuxbrew not found in PATH after installation."
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
# 7. Set default shell to zsh (Linux-specific)
# ============================================================
if [[ "$SHELL" != "$(command -v zsh)" ]]; then
    echo "Setting default shell to zsh..."
    if chsh -s "$(command -v zsh)"; then
        echo "Default shell changed to zsh."
    else
        echo "Could not change shell automatically; run this manually:"
        echo "  chsh -s \$(command -v zsh)"
    fi
fi

# ============================================================
# Done - Platform-specific tips
# ============================================================
echo "=== Linux bootstrap complete ($PLATFORM_NAME) ==="
echo ""
echo "Next step:"
echo "  dotfiles setup"
echo ""
echo "This will configure your vault backend and restore secrets."
echo ""

if $IS_WSL; then
    echo "WSL-specific tips:"
    echo "  - Windows clipboard works via clip.exe (already configured in zshrc)"
    echo "  - Access Windows files: /mnt/c/Users/..."
elif $IS_LIMA; then
    echo "Lima-specific tips:"
    echo "  - macOS home mounted at ~/workspace (writable)"
    echo "  - Use lima-dev/lima-start/lima-stop aliases from macOS"
fi
