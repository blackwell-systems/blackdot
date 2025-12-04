#!/usr/bin/env bash
set -euo pipefail

# DOTFILES_DIR is parent of bootstrap/
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS="$(uname -s)"

echo "Dotfiles repo: $DOTFILES_DIR"
echo "Detected OS: $OS"

# Helper: safely create symlink, backing up existing real files
# Usage: safe_symlink <source> <target>
safe_symlink() {
  local src="$1"
  local tgt="$2"

  # If target exists and is NOT a symlink, back it up
  if [ -e "$tgt" ] && [ ! -L "$tgt" ]; then
    local backup
    backup="${tgt}.bak-$(date +%Y%m%d%H%M%S)"
    echo "Backing up existing $tgt to $backup"
    mv "$tgt" "$backup"
  fi

  ln -sf "$src" "$tgt"
}

# Zsh config (shared)
safe_symlink "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
safe_symlink "$DOTFILES_DIR/zsh/p10k.zsh" "$HOME/.p10k.zsh"

# Ghostty config (macOS only)
if [ "$OS" = "Darwin" ]; then
  GHOSTTY_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
  mkdir -p "$GHOSTTY_DIR"
  if [ -f "$DOTFILES_DIR/ghostty/config" ]; then
    safe_symlink "$DOTFILES_DIR/ghostty/config" "$GHOSTTY_DIR/config"
  fi
fi

# Zellij config (cross-platform)
ZELLIJ_DIR="$HOME/.config/zellij"
mkdir -p "$ZELLIJ_DIR"
if [ -f "$DOTFILES_DIR/zellij/config.kdl" ]; then
  safe_symlink "$DOTFILES_DIR/zellij/config.kdl" "$ZELLIJ_DIR/config.kdl"
  echo "Zellij config linked: ~/.config/zellij/config.kdl"
fi

# ============================================================
# Claude Code setup
# ============================================================
SKIP_CLAUDE_SETUP="${SKIP_CLAUDE_SETUP:-false}"

if [ "$SKIP_CLAUDE_SETUP" != "true" ]; then
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
    safe_symlink "$DOTFILES_DIR/claude/settings.json" "$CLAUDE_SHARED/settings.json"
  fi

  # Link slash commands
  if [ -d "$DOTFILES_DIR/claude/commands" ]; then
    for cmd in "$DOTFILES_DIR/claude/commands"/*.md; do
      [ -f "$cmd" ] && safe_symlink "$cmd" "$CLAUDE_SHARED/commands/$(basename "$cmd")"
    done
  fi

  echo "Claude setup complete: ~/.claude -> $CLAUDE_SHARED"
else
  echo "Skipping Claude setup (SKIP_CLAUDE_SETUP=true)"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "Symlinks created:"
ls -l "$HOME/.zshrc" "$HOME/.p10k.zsh" 2>/dev/null || true
if [ "$OS" = "Darwin" ]; then
  ls -l "$HOME/Library/Application Support/com.mitchellh.ghostty/config" 2>/dev/null || true
fi
ls -l "$HOME/.config/zellij/config.kdl" 2>/dev/null || true
ls -l "$HOME/.claude" 2>/dev/null || true

echo ""
echo "Done. Open a new shell to pick up changes."
