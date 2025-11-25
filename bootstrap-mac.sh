#!/usr/bin/env bash
set -euo pipefail

# Resolve dotfiles repo dir based on this script's location
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE_PATH="$DOTFILES_DIR/Brewfile"

echo "=== macOS bootstrap starting ==="
echo "Dotfiles directory: $DOTFILES_DIR"

# ------------------------------------------------------------
# 1. Xcode Command Line Tools
# ------------------------------------------------------------
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Installing Xcode Command Line Tools..."
  xcode-select --install || true
  echo
  echo "Xcode Command Line Tools installation started."
  echo "Please rerun this script after the installation finishes."
  exit 0
fi

# ------------------------------------------------------------
# 2. Homebrew
# ------------------------------------------------------------
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

# Make sure brew is on PATH for current shell
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi

# ------------------------------------------------------------
# 3. Brew Bundle (uses shared mac+Lima Brewfile)
# ------------------------------------------------------------
if [ -f "$BREWFILE_PATH" ]; then
  echo "Running brew bundle with $BREWFILE_PATH ..."
  brew bundle --file="$BREWFILE_PATH"
else
  echo "No Brewfile found at $BREWFILE_PATH, skipping brew bundle."
fi

# ------------------------------------------------------------
# 4. Workspace layout (shared mount for macOS + Lima)
# ------------------------------------------------------------
echo "Ensuring ~/workspace layout..."
mkdir -p "$HOME/workspace/code"
mkdir -p "$HOME/workspace/whitepapers"
mkdir -p "$HOME/workspace/patent-pool"

# ------------------------------------------------------------
# 5. Dotfiles symlinks
# ------------------------------------------------------------
if [ -x "$DOTFILES_DIR/bootstrap-dotfiles.sh" ]; then
  echo "Linking dotfiles via bootstrap-dotfiles.sh..."
  "$DOTFILES_DIR/bootstrap-dotfiles.sh"
else
  echo "WARNING: $DOTFILES_DIR/bootstrap-dotfiles.sh not found or not executable; skipping dotfile symlinks."
fi

echo "=== macOS bootstrap complete ==="
echo "Next:"
echo "  - Open Ghostty, confirm Meslo Nerd Font is selected."
echo "  - Create/start your Lima dev-ubuntu VM using the lima/dev-ubuntu.yaml template."
echo "  - Inside Lima, run:  ~/workspace/dotfiles/bootstrap-lima.sh"

