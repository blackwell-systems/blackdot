#!/usr/bin/env bash
# ============================================================
# FILE: bootstrap-mac.sh
# ============================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== macOS bootstrap starting ==="

# 1. Xcode CLI tools ----------------------------------------------------
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Installing Xcode Command Line Tools..."
  xcode-select --install || true
  echo "Please rerun this script after Xcode tools finish installing."
  exit 0
fi

# 2. Homebrew -----------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Ensure brew shellenv is in .zprofile (idempotent)
# Apple Silicon: /opt/homebrew, Intel: /usr/local
add_brew_to_zprofile() {
  local brew_path="$1"
  local shellenv_line="eval \"\$(${brew_path}/bin/brew shellenv)\""

  if [ -d "$brew_path/bin" ]; then
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

# Try Apple Silicon path first, then Intel path
if [ -d /opt/homebrew ]; then
  add_brew_to_zprofile "/opt/homebrew"
elif [ -d /usr/local/Homebrew ]; then
  add_brew_to_zprofile "/usr/local"
fi

# Make sure brew is on PATH for this session
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
else
  echo "WARNING: Homebrew not found in PATH after installation."
fi

# 3. Brew Bundle --------------------------------------------------------
if [ -f "$DOTFILES_DIR/Brewfile" ]; then
  echo "Running brew bundle..."
  brew bundle --file="$DOTFILES_DIR/Brewfile"
else
  echo "No Brewfile found at $DOTFILES_DIR/Brewfile, skipping brew bundle."
fi

# 4. Workspace layout ---------------------------------------------------
echo "Ensuring ~/workspace layout..."
mkdir -p "$HOME/workspace"
mkdir -p "$HOME/workspace/code"
# NOTE:
#   whitepapers/ and patent-pool/ are repos now, so we do NOT pre-create
#   ~/workspace/whitepapers or ~/workspace/patent-pool to avoid nesting.

# 5. Dotfiles symlinks --------------------------------------------------
echo "Linking dotfiles..."
"$DOTFILES_DIR/bootstrap-dotfiles.sh"

# 6. Shared Claude data symlink ----------------------------------------
# Goal: make ~/.claude point at the shared ~/workspace/.claude so both
# macOS and Lima use the same history / state.
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
  echo "      After you untar/restore your Claude data into $CLAUDE_SHARED,"
  echo "      rerun this script or create the symlink manually:"
  echo "        ln -sfn \$HOME/workspace/.claude \$HOME/.claude"
fi

echo "=== macOS bootstrap complete ==="
echo "Next:"
echo "  - Open Ghostty and confirm Meslo Nerd Font is selected."
echo "  - Clone your repos into ~/workspace (whitepapers, patent-pool, etc.)."
echo "  - Claude CLI/Code will now use shared history via ~/workspace/.claude."
