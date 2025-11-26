#!/usr/bin/env bash
# ============================================================
# FILE: bootstrap-lima.sh
# ============================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Lima (dev-ubuntu) bootstrap starting ==="

# 1. Basic apt packages -----------------------------------------------
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential curl file git zsh

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
  echo "Running brew bundle (Lima)..."
  brew bundle --file="$DOTFILES_DIR/Brewfile"
else
  echo "No Brewfile found at $DOTFILES_DIR/Brewfile, skipping brew bundle."
fi

# 4. Workspace layout ---------------------------------------------------
echo "Ensuring ~/workspace layout..."
mkdir -p "$HOME/workspace"
mkdir -p "$HOME/workspace/code"

# 5. Canonical /workspace path ------------------------------------------
# Creates /workspace -> ~/workspace so Claude sessions use consistent paths
# across macOS and Linux (encodes to -workspace-... instead of -home-...).
if [ ! -e /workspace ]; then
  echo "Creating /workspace symlink (requires sudo)..."
  if sudo ln -sfn "$HOME/workspace" /workspace; then
    echo "Created /workspace -> $HOME/workspace"
  else
    echo "WARNING: Could not create /workspace symlink."
    echo "         Claude sessions will use OS-specific paths."
    echo "         To fix manually: sudo ln -sfn $HOME/workspace /workspace"
  fi
elif [ -L /workspace ]; then
  # Already a symlink - verify it points to the right place
  current_target=$(readlink /workspace)
  if [ "$current_target" != "$HOME/workspace" ]; then
    echo "Updating /workspace symlink..."
    sudo rm /workspace && sudo ln -sfn "$HOME/workspace" /workspace
    echo "Updated /workspace -> $HOME/workspace"
  else
    echo "/workspace symlink already correct."
  fi
else
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

echo "=== Lima bootstrap complete ==="
echo "Next:"
echo "  - Open a new shell to use zsh + Powerlevel10k."
echo "  - Use 'cd /workspace/...' when running Claude for portable session history."
