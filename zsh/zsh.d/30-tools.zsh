# =========================
# 30-tools.zsh
# =========================
# Modern CLI tool configurations
# Sets up eza, fzf, dust, yazi, yq, bat, and other modern replacements
# Runtime guards allow enable/disable without shell reload

# =========================
# MODERN CLI TOOLS (eza, fzf, etc.)
# =========================
# These override basic coreutils with modern alternatives when available.
# Wrapped as functions for runtime feature guards.

# eza - modern ls replacement (cross-platform)
# Note: Using 'function' keyword to override existing aliases at parse time
# When modern_cli is disabled, falls back to coreutils equivalents
if command -v eza >/dev/null 2>&1; then
  unalias ls ll la lt l lm lr 2>/dev/null
  function ls  { if feature_enabled "modern_cli"; then eza --color=auto --group-directories-first "$@"; else command ls --color=auto "$@"; fi; }
  function ll  { if feature_enabled "modern_cli"; then eza -la --icons --group-directories-first --git "$@"; else command ls -lash --color=auto "$@"; fi; }
  function la  { if feature_enabled "modern_cli"; then eza -a --icons --group-directories-first "$@"; else command ls -Ah --color=auto "$@"; fi; }
  function lt  { if feature_enabled "modern_cli"; then eza -la --icons --tree --level=2 "$@"; else command ls -laR --color=auto "$@"; fi; }
  function l   { if feature_enabled "modern_cli"; then eza -1 "$@"; else command ls -CF --color=auto "$@"; fi; }
  function lm  { if feature_enabled "modern_cli"; then eza -la --icons --sort=modified "$@"; else command ls -lat --color=auto "$@"; fi; }
  function lr  { if feature_enabled "modern_cli"; then eza -la --icons --sort=size --reverse "$@"; else command ls -laS --color=auto "$@"; fi; }
fi

# fzf - fuzzy finder
if command -v fzf >/dev/null 2>&1; then
  # Use fd for fzf if available (faster, respects .gitignore)
  if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  fi

  # fzf appearance
  export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline'

  # Load fzf keybindings and completions
  if [[ -f "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh" ]]; then
    source "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
  fi
  if [[ -f "$BREW_PREFIX/opt/fzf/shell/completion.zsh" ]]; then
    source "$BREW_PREFIX/opt/fzf/shell/completion.zsh"
  fi
fi

# dust - intuitive disk usage (du replacement)
# When modern_cli is disabled, falls back to coreutils du
if command -v dust >/dev/null 2>&1; then
  unalias du dus dud 2>/dev/null
  function du  { if feature_enabled "modern_cli"; then dust "$@"; else command du -h "$@"; fi; }
  function dus { if feature_enabled "modern_cli"; then dust -s "$@"; else command du -sh "$@"; fi; }
  function dud { if feature_enabled "modern_cli"; then dust -d 1 "$@"; else command du -h --max-depth=1 "$@"; fi; }
fi

# yazi - terminal file manager (cd to directory on exit)
if command -v yazi >/dev/null 2>&1; then
  unalias y fm 2>/dev/null
  # y: launch yazi and cd to directory when you quit
  function y {
    require_feature "modern_cli" || return 1
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
      cd -- "$cwd"
    fi
    command rm -f -- "$tmp"
  }
  function fm { require_feature "modern_cli" || return 1; y "$@"; }
fi

# yq - YAML processor (like jq for YAML)
# Usage: yq '.spec.containers[0].image' deployment.yaml
#        cat config.yaml | yq '.database.host'
#        yq -i '.version = "2.0"' config.yaml  # in-place edit
