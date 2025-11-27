# =========================
# 30-tools.zsh
# =========================
# Modern CLI tool configurations
# Sets up eza, fzf, dust, yazi, yq, bat, and other modern replacements

# =========================
# MODERN CLI TOOLS (eza, fzf, etc.)
# =========================
# These override basic coreutils with modern alternatives when available.

# eza - modern ls replacement (cross-platform)
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --color=auto --group-directories-first'
  alias ll='eza -la --icons --group-directories-first --git'
  alias la='eza -a --icons --group-directories-first'
  alias lt='eza -la --icons --tree --level=2'
  alias l='eza -1'
  alias lm='eza -la --icons --sort=modified'
  alias lr='eza -la --icons --sort=size --reverse'
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
if command -v dust >/dev/null 2>&1; then
  alias du='dust'
  alias dus='dust -s'      # summary only
  alias dud='dust -d 1'    # depth 1
fi

# yazi - terminal file manager (cd to directory on exit)
if command -v yazi >/dev/null 2>&1; then
  # y: launch yazi and cd to directory when you quit
  y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
      cd -- "$cwd"
    fi
    rm -f -- "$tmp"
  }
  alias fm='y'  # muscle memory alias
fi

# yq - YAML processor (like jq for YAML)
# Usage: yq '.spec.containers[0].image' deployment.yaml
#        cat config.yaml | yq '.database.host'
#        yq -i '.version = "2.0"' config.yaml  # in-place edit
