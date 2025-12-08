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
# Core Libraries (must load early for runtime feature guards)
# =========================
# Determine DOTFILES_DIR if not set (this file is in zsh/zsh.d/)
_dotfiles_dir="${DOTFILES_DIR:-${${(%):-%x}:A:h:h:h}}"
if [[ -f "$_dotfiles_dir/lib/_logging.sh" ]]; then
    source "$_dotfiles_dir/lib/_logging.sh" 2>/dev/null || true
fi
if [[ -f "$_dotfiles_dir/lib/_features.sh" ]]; then
    source "$_dotfiles_dir/lib/_features.sh" 2>/dev/null || true
fi
unset _dotfiles_dir

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

  MINGW*|MSYS*|CYGWIN*)
    # ---------- Windows (Git Bash / MSYS2 / Cygwin) ----------
    # Fix TERM for Windows terminals
    export TERM=xterm-256color

    # Add common Windows paths
    if [ -d "/c/Program Files/Git/bin" ]; then
      export PATH="/c/Program Files/Git/bin:$PATH"
    fi

    # Enable ls colors
    alias ls='ls --color=auto'
    alias ll='ls -lash --color=auto'
    alias la='ls -Ah --color=auto'
    alias l='ls -CF --color=auto'

    # Windows-specific utilities
    alias open='start'
    alias explorer='explorer.exe'

    # Clipboard integration
    if command -v clip.exe >/dev/null 2>&1; then
      alias pbcopy='clip.exe'
      alias pbpaste='powershell.exe -command "Get-Clipboard"'
    fi
    ;;
esac
