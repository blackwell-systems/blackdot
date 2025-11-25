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

# 4. Dotfiles symlinks (shared with macOS) ----------------------------
echo "Linking dotfiles..."
"$DOTFILES_DIR/bootstrap-dotfiles.sh"

# 5. Shared Claude data symlink ---------------------------------------
# Lima sees ~/workspace via the host mount. We want ~/.claude inside
# Lima to also point at the same ~/workspace/.claude.
CLAUDE_SHARED="$HOME/workspace/.claude"

if [ -e "$CLAUDE_SHARED" ]; then
  echo "Found shared Claude directory at $CLAUDE_SHARED"

  # If a real ~/.claude exists and is NOT a symlink, back it up once
  if [ -e "$HOME/.claude" ] && [ ! -L "$HOME/.claude" ]; then
    BACKUP="$HOME/.claude.bak-$(date +%Y%m%d%H%M%S)"
    echo "Backing up existing ~/.claude to $BACKUP"
    mv "$HOME/.claude" "$BACKUP"
  fi

  ln -sfn "$CLAUDE_SHARED" "$HOME/.claude"
  echo "Linked ~/.claude -> $CLAUDE_SHARED"
else
  echo "Note: $CLAUDE_SHARED does not exist yet; skipping Claude symlink."
  echo "      Make sure the host has ~/workspace/.claude (your tar restore),"
  echo "      then rerun this script or run:"
  echo "        ln -sfn \$HOME/workspace/.claude \$HOME/.claude"
fi

# 6. Set default shell to zsh -----------------------------------------
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
echo "Open a new Lima shell to use zsh + Powerlevel10k and shared Claude history."
