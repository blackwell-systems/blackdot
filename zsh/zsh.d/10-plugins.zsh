# =========================
# 10-plugins.zsh
# =========================
# Completions setup, plugin loading, and prompt configuration
# Manages zsh-autosuggestions, powerlevel10k, and completion system

# =========================
# COMPLETIONS
# =========================
# Load custom completions from blackdot
BLACKDOT_COMPLETIONS="$BLACKDOT_DIR/zsh/completions"
if [[ -d "$BLACKDOT_COMPLETIONS" ]]; then
  fpath=($BLACKDOT_COMPLETIONS $fpath)
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

  # zsh-you-should-use - Reminds you about aliases you have defined
  # Great for learning your own aliases (awstools, cdktools, etc.)
  if [ -f "$BREW_PREFIX/share/zsh-you-should-use/you-should-use.plugin.zsh" ]; then
    source "$BREW_PREFIX/share/zsh-you-should-use/you-should-use.plugin.zsh"
    # Show reminder BEFORE command output (default is after)
    export YSU_MESSAGE_POSITION="before"
    # Hardcore mode: prevent command from running if alias exists (disabled by default)
    # export YSU_HARDCORE=1
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
