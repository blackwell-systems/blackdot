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

# ============================================================
# Claude Code setup
# ============================================================
CLAUDE_SHARED="$HOME/workspace/.claude"

# Create shared Claude directory if it doesn't exist
mkdir -p "$CLAUDE_SHARED"
mkdir -p "$CLAUDE_SHARED/commands"

# Symlink ~/.claude to shared location
if [ -e "$HOME/.claude" ] && [ ! -L "$HOME/.claude" ]; then
  BACKUP="$HOME/.claude.bak-$(date +%Y%m%d%H%M%S)"
  echo "Backing up existing ~/.claude to $BACKUP"
  mv "$HOME/.claude" "$BACKUP"
fi
ln -sfn "$CLAUDE_SHARED" "$HOME/.claude"

# Link Claude config files from dotfiles
if [ -f "$DOTFILES_DIR/claude/settings.json" ]; then
  ln -sf "$DOTFILES_DIR/claude/settings.json" "$CLAUDE_SHARED/settings.json"
fi

# Link slash commands
if [ -d "$DOTFILES_DIR/claude/commands" ]; then
  for cmd in "$DOTFILES_DIR/claude/commands"/*.md; do
    [ -f "$cmd" ] && ln -sf "$cmd" "$CLAUDE_SHARED/commands/$(basename "$cmd")"
  done
fi

echo "Claude setup complete: ~/.claude -> $CLAUDE_SHARED"

# ============================================================
# Summary
# ============================================================
echo ""
echo "Symlinks created:"
ls -l "$HOME/.zshrc" "$HOME/.p10k.zsh" 2>/dev/null || true
if [ "$OS" = "Darwin" ]; then
  ls -l "$HOME/Library/Application Support/com.mitchellh.ghostty/config" 2>/dev/null || true
fi
ls -l "$HOME/.claude" 2>/dev/null || true

echo ""
echo "Done. Open a new shell to pick up changes."
