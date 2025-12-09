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
_dotfiles_bin="$_dotfiles_dir/bin/dotfiles"
_dotfiles_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"

# Initialize feature functions from Go binary (with caching for faster startup)
# This provides: feature_enabled, require_feature, feature_exists, feature_status
_dotfiles_init_features() {
    local cache_file="$_dotfiles_cache_dir/shell-init.zsh"
    local binary_mtime cache_mtime

    # Create cache directory if needed
    [[ -d "$_dotfiles_cache_dir" ]] || mkdir -p "$_dotfiles_cache_dir"

    # Check if binary exists
    if [[ ! -x "$_dotfiles_bin" ]]; then
        export DOTFILES_FEATURE_MODE="degraded"
        # Provide minimal fallback functions
        feature_enabled() { return 1; }  # Features disabled when binary missing
        require_feature() {
            echo "Feature system unavailable (Go binary not found at $_dotfiles_bin)" >&2
            return 1
        }
        return 1
    fi

    # Use cache if it exists and is newer than binary
    if [[ -f "$cache_file" ]]; then
        binary_mtime=$(stat -c %Y "$_dotfiles_bin" 2>/dev/null || stat -f %m "$_dotfiles_bin" 2>/dev/null)
        cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)

        if [[ -n "$cache_mtime" && -n "$binary_mtime" && "$cache_mtime" -ge "$binary_mtime" ]]; then
            source "$cache_file" 2>/dev/null && {
                export DOTFILES_FEATURE_MODE="cached"
                return 0
            }
        fi
    fi

    # Generate fresh init and cache it
    local init_code
    if init_code=$("$_dotfiles_bin" shell-init zsh 2>&1); then
        echo "$init_code" > "$cache_file"
        eval "$init_code"
        export DOTFILES_FEATURE_MODE="live"
        return 0
    else
        export DOTFILES_FEATURE_MODE="error"
        echo "dotfiles: shell-init failed: $init_code" >&2
        # Provide safe fallback
        feature_enabled() { return 1; }
        require_feature() {
            echo "Feature system initialization failed" >&2
            return 1
        }
        return 1
    fi
}

_dotfiles_init_features
unset _dotfiles_dir _dotfiles_bin _dotfiles_cache_dir
unset -f _dotfiles_init_features

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
