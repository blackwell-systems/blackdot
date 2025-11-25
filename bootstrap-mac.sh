#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== macOS bootstrap starting ==="

# 1. Xcode CLI tools
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Installing Xcode Command Line Tools..."
  xcode-select --install || true
  echo "Please rerun this script after Xcode tools finish installing."
  exit 0
fi

# 2. Homebrew
if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for Apple Silicon
  if [ -d /opt/homebrew/bin ]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
else
  echo "Homebrew already installed."
fi

# Make sure brew is on PATH
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi

# 3. Brew Bundle
if [ -f "$DOTFILES_DIR/Brewfile" ]; then
  echo "Running brew bundle..."
  brew bundle --file="$DOTFILES_DIR/Brewfile"
else
  echo "No Brewfile found at $DOTFILES_DIR/Brewfile, skipping brew bundle."
fi

# 4. Workspace layout
echo "Ensuring ~/workspace layout..."
mkdir -p "$HOME/workspace/code"
mkdir -p "$HOME/workspace/whitepapers"
mkdir -p "$HOME/workspace/patent-pool"

# 5. Dotfiles symlinks
echo "Linking dotfiles..."
"$DOTFILES_DIR/bootstrap-dotfiles.sh"

echo "=== macOS bootstrap complete ==="
echo "Next:"
echo "  - Open Ghostty, confirm Meslo Nerd Font is selected."
echo "  - Create/start your Lima dev-ubuntu VM using the lima/dev-ubuntu.yaml template."
