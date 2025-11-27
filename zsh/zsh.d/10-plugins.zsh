# =========================
# 10-plugins.zsh
# =========================
# Completions setup, plugin loading, and prompt configuration
# Manages zsh-autosuggestions, powerlevel10k, and completion system

# =========================
# COMPLETIONS
# =========================
# Load custom completions from dotfiles
DOTFILES_COMPLETIONS="$HOME/workspace/dotfiles/zsh/completions"
if [[ -d "$DOTFILES_COMPLETIONS" ]]; then
  fpath=($DOTFILES_COMPLETIONS $fpath)
fi

# Initialize completion system
autoload -Uz compinit
compinit

# =========================
# SHARED PLUGIN LOADING (brew-managed)
# =========================
# Unified approach: both macOS and Linux use brew-installed plugins directly.
# No Oh-My-Zsh dependency - faster startup, simpler config.

if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="$(brew --prefix)"

  # zsh-autosuggestions
  if [ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  fi

  # Powerlevel10k theme
  if [ -f "$BREW_PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme" ]; then
    source "$BREW_PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme"
  fi
fi

# =========================
# SHARED PROMPT CONFIG
# =========================
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
