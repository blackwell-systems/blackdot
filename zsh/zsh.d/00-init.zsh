# =========================
# 00-init.zsh
# =========================
# Powerlevel10k instant prompt, OS detection, and OS-specific setup
# This module must load first for proper shell initialization

# =========================
# Powerlevel10k instant prompt (must stay near top)
# =========================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Detect OS
OS="$(uname -s)"

# =========================
# OS-SPECIFIC SETUP
# =========================
case "$OS" in
  Darwin)
    # ---------- macOS ----------
    # Homebrew shell environment (Apple Silicon or Intel)
    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi

    # Lima VM management (if lima is installed)
    if command -v limactl >/dev/null 2>&1; then
      alias lima-dev='limactl shell dev-ubuntu'
      alias lima-start='limactl start dev-ubuntu'
      alias lima-stop='limactl stop dev-ubuntu'
      alias lima-status='limactl list'
    fi
    ;;

  Linux)
    # ---------- Linux (Lima dev-ubuntu) ----------
    # Fix TERM so apps like nano don't choke on xterm-ghostty
    export TERM=xterm-256color

    # Lima recommendation: make sure system tools are in PATH
    PATH="$PATH:/usr/sbin:/sbin"
    export PATH

    # Homebrew (linuxbrew) bootstrap
    if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi

    # Enable ls colors on Linux
    if command -v dircolors >/dev/null 2>&1; then
      eval "$(dircolors -b)"
    fi
    alias ls='ls --color=auto'
    alias ll='ls -lash --color=auto'
    alias la='ls -Ah --color=auto'
    alias l='ls -CF --color=auto'

    # Snap (if present on Linux)
    if [ -d /snap/bin ]; then
      export PATH="/snap/bin:$PATH"
    fi
    ;;
esac
