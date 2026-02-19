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
# Early PATH setup (must run before binary resolution)
# =========================
# Homebrew PATH is normally set in .zprofile, but non-login shells (tmux
# panes, split terminals) skip .zprofile.  Bootstrap it here so the blackdot
# binary can be found regardless of shell type.
case "$OS" in
  Darwin)
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    ;;
  Linux)
    if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
    ;;
esac

# =========================
# Core Libraries (must load early for runtime feature guards)
# =========================
# Determine BLACKDOT_DIR if not set (this file is in zsh/zsh.d/)
_blackdot_dir="${BLACKDOT_DIR:-${${(%):-%x}:A:h:h:h}}"
_blackdot_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/blackdot"

# Resolve the Go binary by checking multiple candidate locations.
# Prefers a platform-specific binary (e.g. blackdot-linux-amd64) so that
# shared filesystems (Lima, NFS) don't pick up a binary built for the host OS.
_blackdot_can_exec() {
    # Verify a binary is executable AND built for this OS.
    # -x alone passes for a macOS Mach-O binary on Linux (permission bit is set)
    # but executing it produces "exec format error".
    [[ -x "$1" ]] || return 1
    # Use `file` to sniff the binary format when available
    if command -v file >/dev/null 2>&1; then
        case "$(uname -s)" in
            Linux)  file -b "$1" 2>/dev/null | grep -qi 'ELF' ;;
            Darwin) file -b "$1" 2>/dev/null | grep -qi 'Mach-O' ;;
            *)      return 0 ;;  # no format check on unknown OSes
        esac
        return $?
    fi
    return 0
}

_blackdot_resolve_bin() {
    local _os _arch _platform_bin
    _os="$(uname -s | tr '[:upper:]' '[:lower:]')"   # darwin, linux, …
    _arch="$(uname -m)"
    # Normalise architecture names to match Go conventions
    case "$_arch" in
        x86_64)  _arch="amd64" ;;
        aarch64) _arch="arm64" ;;
    esac
    _platform_bin="blackdot-${_os}-${_arch}"

    # 1. Platform-specific binary in repo bin directory
    _blackdot_can_exec "$_blackdot_dir/bin/$_platform_bin" && { echo "$_blackdot_dir/bin/$_platform_bin"; return 0; }
    # 2. Platform-specific binary in installer location
    _blackdot_can_exec "$HOME/.local/bin/$_platform_bin" && { echo "$HOME/.local/bin/$_platform_bin"; return 0; }
    # 3. Generic binary in repo bin directory
    _blackdot_can_exec "$_blackdot_dir/bin/blackdot" && { echo "$_blackdot_dir/bin/blackdot"; return 0; }
    # 4. Generic binary in installer location
    _blackdot_can_exec "$HOME/.local/bin/blackdot" && { echo "$HOME/.local/bin/blackdot"; return 0; }
    # 5. Anywhere in PATH (trust that PATH entries are native)
    command -v blackdot 2>/dev/null && return 0
    return 1
}

_blackdot_bin="$(_blackdot_resolve_bin)"

# Initialize feature functions from Go binary (with caching for faster startup)
# This provides: feature_enabled, require_feature, feature_exists, feature_status
_blackdot_init_features() {
    # Platform-specific cache so shared filesystems (Lima, NFS) don't
    # cross-contaminate between macOS and Linux.
    local _ci_os _ci_arch
    _ci_os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    _ci_arch="$(uname -m)"
    case "$_ci_arch" in x86_64) _ci_arch="amd64";; aarch64) _ci_arch="arm64";; esac
    local cache_file="$_blackdot_cache_dir/shell-init-${_ci_os}-${_ci_arch}.zsh"
    local binary_mtime cache_mtime

    # Create cache directory if needed
    [[ -d "$_blackdot_cache_dir" ]] || mkdir -p "$_blackdot_cache_dir"

    # Check if binary exists
    if [[ -z "$_blackdot_bin" || ! -x "$_blackdot_bin" ]]; then
        local _p_os _p_arch _p_bin
        _p_os="$(uname -s | tr '[:upper:]' '[:lower:]')"
        _p_arch="$(uname -m)"
        case "$_p_arch" in x86_64) _p_arch="amd64";; aarch64) _p_arch="arm64";; esac
        _p_bin="blackdot-${_p_os}-${_p_arch}"

        # In interactive shells, offer to install automatically
        if [[ -o interactive ]]; then
            echo ""
            echo "[blackdot] No compatible binary found for ${_p_os}-${_p_arch}."
            echo -n "           Install now? [y/N] "
            local _answer=""
            read -r _answer
            if [[ "$_answer" =~ ^[Yy]$ ]]; then
                echo "[blackdot] Installing ${_p_bin}..."
                local _install_script="$_blackdot_dir/install.sh"
                if [[ -x "$_install_script" ]]; then
                    # Use --binary-only to just download the binary without re-cloning
                    bash "$_install_script" --binary-only && {
                        # Re-resolve now that the binary is installed
                        _blackdot_bin="$(_blackdot_resolve_bin)"
                        if [[ -n "$_blackdot_bin" && -x "$_blackdot_bin" ]]; then
                            echo "[blackdot] Installed. Continuing..."
                            echo ""
                            # Fall through to normal init below
                        fi
                    } || {
                        echo "[blackdot] Installation failed." >&2
                    }
                else
                    # Fallback: download directly from GitHub releases
                    local _bin_dir="$HOME/.local/bin"
                    local _url="https://github.com/blackwell-systems/blackdot/releases/latest/download/${_p_bin}"
                    mkdir -p "$_bin_dir"
                    if command -v curl >/dev/null 2>&1; then
                        curl -fsSL "$_url" -o "$_bin_dir/$_p_bin" && chmod +x "$_bin_dir/$_p_bin" && ln -sf "$_p_bin" "$_bin_dir/blackdot"
                    elif command -v wget >/dev/null 2>&1; then
                        wget -q "$_url" -O "$_bin_dir/$_p_bin" && chmod +x "$_bin_dir/$_p_bin" && ln -sf "$_p_bin" "$_bin_dir/blackdot"
                    fi
                    _blackdot_bin="$(_blackdot_resolve_bin)"
                    if [[ -n "$_blackdot_bin" && -x "$_blackdot_bin" ]]; then
                        echo "[blackdot] Installed. Continuing..."
                        echo ""
                    fi
                fi
            else
                echo "[blackdot] Skipping. Running in degraded mode (no features, no vault, aliases only)."
                echo "           Run 'install.sh --binary-only' to install later."
                echo ""
            fi
        fi

        # If still no binary after possible install attempt, enter degraded mode
        if [[ -z "$_blackdot_bin" || ! -x "$_blackdot_bin" ]]; then
            export BLACKDOT_FEATURE_MODE="degraded"
            feature_enabled() { return 1; }
            require_feature() {
                echo "Feature system unavailable (no compatible binary for ${_p_os}-${_p_arch})" >&2
                echo "  Run: install.sh --binary-only" >&2
                return 1
            }
            return 1
        fi
    fi

    # Use cache if it exists and is newer than binary
    if [[ -f "$cache_file" ]]; then
        binary_mtime=$(stat -c %Y "$_blackdot_bin" 2>/dev/null || stat -f %m "$_blackdot_bin" 2>/dev/null)
        cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)

        if [[ -n "$cache_mtime" && -n "$binary_mtime" && "$cache_mtime" -ge "$binary_mtime" ]]; then
            source "$cache_file" 2>/dev/null && {
                # Override _BLACKDOT_BIN with locally resolved path — the cached
                # value comes from os.Executable() on the machine that generated
                # the cache, which may be a different OS on shared filesystems.
                _BLACKDOT_BIN="$_blackdot_bin"
                export BLACKDOT_FEATURE_MODE="cached"
                return 0
            }
        fi
    fi

    # Generate fresh init and cache it
    local init_code
    if init_code=$("$_blackdot_bin" shell-init zsh 2>&1); then
        echo "$init_code" > "$cache_file"
        eval "$init_code"
        # Override _BLACKDOT_BIN with locally resolved path (same reason as above)
        _BLACKDOT_BIN="$_blackdot_bin"
        export BLACKDOT_FEATURE_MODE="live"
        return 0
    else
        export BLACKDOT_FEATURE_MODE="error"
        echo "blackdot: shell-init failed: $init_code" >&2
        # Provide safe fallback
        feature_enabled() { return 1; }
        require_feature() {
            echo "Feature system initialization failed" >&2
            return 1
        }
        return 1
    fi
}

_blackdot_init_features
unset _blackdot_dir _blackdot_bin _blackdot_cache_dir
unset -f _blackdot_init_features _blackdot_resolve_bin _blackdot_can_exec

# =========================
# OS-SPECIFIC SETUP
# =========================
case "$OS" in
  Darwin)
    # ---------- macOS ----------
    # Homebrew shellenv already loaded in Early PATH setup above

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

    # Homebrew shellenv already loaded in Early PATH setup above

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

    # Notify on container/VM entry when blackdot is not fully available
    if [[ -o interactive ]] && [[ "$BLACKDOT_FEATURE_MODE" == "degraded" || "$BLACKDOT_FEATURE_MODE" == "error" ]]; then
      echo ""
      echo "  \033[33m⚠  blackdot is not installed in this environment\033[0m"
      echo "     Features, vault, and CLI commands are unavailable."
      echo "     Run: \033[1m./install.sh --binary-only\033[0m"
      echo ""
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
