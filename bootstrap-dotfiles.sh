#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

echo "Dotfiles repo: $DOTFILES_DIR"
echo "Detected OS: $OS"

# Zsh config (shared)
ln -sf "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/zsh/p10k.zsh" "$HOME/.p10k.zsh"

# Ghostty config (macOS only)
if [ "$OS" = "Darwin" ]; then
  GHOSTTY_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
  mkdir -p "$GHOSTTY_DIR"
  if [ -f "$DOTFILES_DIR/ghostty/config" ]; then
    ln -sf "$DOTFILES_DIR/ghostty/config" "$GHOSTTY_DIR/config"
  fi
fi

echo "Symlinks created:"
ls -l "$HOME/.zshrc" "$HOME/.p10k.zsh" 2>/dev/null || true
if [ "$OS" = "Darwin" ]; then
  ls -l "$HOME/Library/Application Support/com.mitchellh.ghostty/config" 2>/dev/null || true
fi

echo "Done. Open a new shell to pick up changes."
