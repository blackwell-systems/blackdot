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

# Powerlevel10k theme config (only if p10k is installed or will be)
setup_p10k_config() {
  local use_bundled="y"

  # Check if existing config exists (and is not our symlink)
  if [ -f "$HOME/.p10k.zsh" ] && [ ! -L "$HOME/.p10k.zsh" ]; then
    echo ""
    echo "Existing .p10k.zsh found."
    read -p "Replace with bundled config? [y/N] " use_bundled
    use_bundled="${use_bundled:-n}"
  elif [ -L "$HOME/.p10k.zsh" ]; then
    # Already symlinked, skip prompt
    echo "Powerlevel10k config already linked"
    return 0
  else
    # No existing config - ask if they want bundled
    echo ""
    read -p "Use bundled Powerlevel10k theme config? [Y/n] " use_bundled
    use_bundled="${use_bundled:-y}"
  fi

  if [[ "$use_bundled" =~ ^[Yy] ]]; then
    safe_symlink "$DOTFILES_DIR/zsh/p10k.zsh" "$HOME/.p10k.zsh"
    echo "Powerlevel10k config linked (classic powerline theme)"
  else
    echo "Skipping p10k config. Run 'p10k configure' to set up your own theme."
  fi
}

# Only prompt for p10k if enhanced tier or p10k is installed
if command -v brew >/dev/null 2>&1 && [ -d "$(brew --prefix)/share/powerlevel10k" ] 2>/dev/null; then
  setup_p10k_config
elif [ -f "$HOME/.p10k.zsh" ]; then
  # Existing config but p10k not installed yet - still offer to set up
  setup_p10k_config
else
  echo "Powerlevel10k not installed. Skipping theme config."
  echo "Install with: brew install powerlevel10k"
fi

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

# Get workspace target (consistent with bootstrap/_common.sh)
_get_ws_target() {
    if [[ -n "${WORKSPACE_TARGET:-}" ]]; then
        echo "${WORKSPACE_TARGET/#\~/$HOME}"
    else
        echo "$HOME/workspace"
    fi
}

if [ "$SKIP_CLAUDE_SETUP" != "true" ]; then
  WORKSPACE_DIR="$(_get_ws_target)"
  CLAUDE_SHARED="$WORKSPACE_DIR/.claude"

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
ls -l "$HOME/.zshrc" 2>/dev/null || true
[ -L "$HOME/.p10k.zsh" ] && ls -l "$HOME/.p10k.zsh" 2>/dev/null || true
if [ "$OS" = "Darwin" ]; then
  ls -l "$HOME/Library/Application Support/com.mitchellh.ghostty/config" 2>/dev/null || true
fi
ls -l "$HOME/.config/zellij/config.kdl" 2>/dev/null || true
ls -l "$HOME/.claude" 2>/dev/null || true

echo ""
echo "Done. Open a new shell to pick up changes."
