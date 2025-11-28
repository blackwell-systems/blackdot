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

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Interactive mode flag
INTERACTIVE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --interactive|-i)
            INTERACTIVE=true
            shift
            ;;
        --help|-h)
            echo "Linux Bootstrap Script"
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
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Interactive prompts
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

# Detect environment
IS_WSL=false
IS_LIMA=false
PLATFORM="Linux"

if grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
  IS_WSL=true
  PLATFORM="WSL2"
elif [[ -n "${LIMA_INSTANCE:-}" ]]; then
  IS_LIMA=true
  PLATFORM="Lima"
fi

if $INTERACTIVE; then
    echo ""
    echo -e "${BLUE}=== Interactive Bootstrap Configuration ($PLATFORM) ===${NC}"
    echo ""

    if ! prompt_yes_no "Enable /workspace symlink for portable Claude sessions?" "Y"; then
        export SKIP_WORKSPACE_SYMLINK=true
    fi

    if ! prompt_yes_no "Configure Claude Code integration?" "Y"; then
        export SKIP_CLAUDE_SETUP=true
    fi

    echo ""
fi

echo "=== Linux bootstrap starting ($PLATFORM) ==="

# 1. Basic apt packages -----------------------------------------------
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential curl file git zsh

# WSL-specific: Windows interop tools
if $IS_WSL; then
  echo "Detected WSL2, installing Windows interop tools..."
  # wslu provides wslview (xdg-open equivalent), wslpath, etc.
  sudo apt-get install -y wslu 2>/dev/null || echo "wslu not available, skipping"
fi

# 2. Linuxbrew install (if not present) -------------------------------
BREW_LINUX_PATH="/home/linuxbrew/.linuxbrew"

if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Linuxbrew..."
  /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Ensure brew shellenv is in .zprofile (idempotent)
if [ -d "$BREW_LINUX_PATH/bin" ]; then
  # Only add if not already present
  if ! grep -qF "$BREW_LINUX_PATH/bin/brew shellenv" "$HOME/.zprofile" 2>/dev/null; then
    echo "Adding Linuxbrew to .zprofile..."
    echo "eval \"\$($BREW_LINUX_PATH/bin/brew shellenv)\"" >> "$HOME/.zprofile"
  fi
  eval "$("$BREW_LINUX_PATH/bin/brew" shellenv)"
fi

# Verify brew is available
if ! command -v brew >/dev/null 2>&1; then
  echo "WARNING: Linuxbrew not found in PATH after installation."
fi

# 3. Brew Bundle (shared Brewfile with macOS) -------------------------
if [ -f "$DOTFILES_DIR/Brewfile" ]; then
  echo "Running brew bundle ($PLATFORM)..."
  brew bundle --file="$DOTFILES_DIR/Brewfile"
else
  echo "No Brewfile found at $DOTFILES_DIR/Brewfile, skipping brew bundle."
fi

# 4. Workspace layout ---------------------------------------------------
echo "Ensuring ~/workspace layout..."
mkdir -p "$HOME/workspace"
mkdir -p "$HOME/workspace/code"

# 5. Canonical /workspace path ------------------------------------------
# Creates /workspace -> ~/workspace for consistent Claude session paths.
# Optional: enables session portability across machines if you use multiple.
SKIP_WORKSPACE_SYMLINK="${SKIP_WORKSPACE_SYMLINK:-false}"

if [ "$SKIP_WORKSPACE_SYMLINK" != "true" ] && [ ! -e /workspace ]; then
  echo "Creating /workspace symlink (requires sudo)..."
  if sudo ln -sfn "$HOME/workspace" /workspace; then
    echo "Created /workspace -> $HOME/workspace"
  else
    echo "WARNING: Could not create /workspace symlink."
    echo "         Claude sessions will use OS-specific paths."
    echo "         To fix manually: sudo ln -sfn $HOME/workspace /workspace"
  fi
elif [ "$SKIP_WORKSPACE_SYMLINK" != "true" ] && [ -L /workspace ]; then
  # Already a symlink - verify it points to the right place
  current_target=$(readlink /workspace)
  if [ "$current_target" != "$HOME/workspace" ]; then
    echo "Updating /workspace symlink..."
    sudo rm /workspace && sudo ln -sfn "$HOME/workspace" /workspace
    echo "Updated /workspace -> $HOME/workspace"
  else
    echo "/workspace symlink already correct."
  fi
elif [ "$SKIP_WORKSPACE_SYMLINK" = "true" ]; then
  echo "Skipping /workspace symlink (SKIP_WORKSPACE_SYMLINK=true)"
elif [ -e /workspace ]; then
  echo "WARNING: /workspace exists but is not a symlink. Skipping."
fi

# 6. Dotfiles symlinks (shared with macOS) ----------------------------
echo "Linking dotfiles..."
"$DOTFILES_DIR/bootstrap-dotfiles.sh"

# 7. Set default shell to zsh -----------------------------------------
if [ "$SHELL" != "$(command -v zsh)" ]; then
  echo "Setting default shell to zsh..."
  if chsh -s "$(command -v zsh)"; then
    echo "Default shell changed to zsh."
  else
    echo "Could not change shell automatically; run this manually:"
    echo "  chsh -s \$(command -v zsh)"
  fi
fi

# 8. Platform-specific tips --------------------------------------------
echo "=== Linux bootstrap complete ($PLATFORM) ==="
echo ""
echo "Next steps:"
echo "  - Open a new shell to use zsh + Powerlevel10k"
echo "  - Use 'cd /workspace/...' for Claude (optional: enables cross-machine sessions)"
echo ""

if $IS_WSL; then
  echo "WSL-specific:"
  echo "  - Windows clipboard works via clip.exe (already configured in zshrc)"
  echo "  - Access Windows files: /mnt/c/Users/..."
  echo "  - Open files in Windows: explorer.exe . (or use wslview)"
  echo ""
elif $IS_LIMA; then
  echo "Lima-specific:"
  echo "  - macOS home mounted at ~/workspace (writable)"
  echo "  - Files are shared between macOS and Lima"
  echo "  - Use lima-dev/lima-start/lima-stop aliases from macOS"
  echo ""
fi

echo "To restore secrets from Bitwarden:"
echo "  bw login && export BW_SESSION=\"\$(bw unlock --raw)\""
echo "  bw-restore"
