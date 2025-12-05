# =========================
# 90-integrations.zsh
# =========================
# Tool integrations and lazy loaders
# Manages SDKMAN, NVM, zoxide, glow, update checker, syntax highlighting, and local overrides

# Load your custom env block if it exists
if [ -f "$HOME/.local/bin/env" ]; then
  . "$HOME/.local/bin/env"
fi

# =========================
# SDKMAN (lazy loaded for faster shell startup)
# =========================
export SDKMAN_DIR="$HOME/.sdkman"

# Lazy load: only initialize SDKMAN when sdk/java/gradle/maven/kotlin are called
_lazy_load_sdkman() {
  unfunction sdk java gradle mvn kotlin groovy scala 2>/dev/null
  if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
  fi
}

# Create lazy wrapper functions
for cmd in sdk java gradle mvn kotlin groovy scala; do
  eval "$cmd() { _lazy_load_sdkman && $cmd \"\$@\" }"
done
unset cmd

# Best Western config
export ENV=prod
export BWH_CONFIG_DIR="$HOME/.config/bwh"

# =========================
# NVM (lazy loaded for faster shell startup)
# =========================
# NVM adds 200-400ms to shell startup. Lazy load it instead.
export NVM_DIR="$HOME/.nvm"

_lazy_load_nvm() {
  unfunction nvm node npm npx yarn pnpm corepack 2>/dev/null
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
    [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
  fi
}

# Create lazy wrapper functions for node ecosystem commands
for cmd in nvm node npm npx yarn pnpm corepack; do
  eval "$cmd() { _lazy_load_nvm && $cmd \"\$@\" }"
done
unset cmd

# Auto-switch node version when entering directory with .nvmrc
# (only triggers if nvm is needed)
_nvm_auto_switch() {
  if [[ -f .nvmrc ]] && command -v nvm &>/dev/null; then
    nvm use 2>/dev/null
  fi
}
add-zsh-hook chpwd _nvm_auto_switch 2>/dev/null

# =========================
# Zoxide (smarter cd)
# =========================
# Initialize zoxide if installed - use 'z' to jump to directories
# It learns your habits: z dot → ~/workspace/dotfiles
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# Glow alias for reading markdown
if command -v glow >/dev/null 2>&1; then
  alias readme='glow README.md'
  alias md='glow'
fi

# =========================
# Dotfiles Update Checker
# =========================
# Checks once per day if dotfiles repo has upstream updates
# Shows notification if updates are available
check_dotfiles_updates() {
  local cache="$HOME/.dotfiles-update-check"
  local dotfiles_dir="${HOME}/workspace/dotfiles"

  # Skip if not in a git repo
  [[ ! -d "$dotfiles_dir/.git" ]] && return 0

  # Get age of cache file
  local age=0
  if [[ -f "$cache" ]]; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
      # macOS: stat -f %m returns modification time
      age=$(($(date +%s) - $(stat -f %m "$cache" 2>/dev/null || echo 0)))
    else
      # Linux: stat -c %Y returns modification time
      age=$(($(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || echo 0)))
    fi
  else
    # No cache file - force check
    age=86401
  fi

  # Check once per day (86400 seconds)
  if [[ $age -gt 86400 ]]; then
    # Fetch updates in background (don't block shell startup)
    (
      cd "$dotfiles_dir" 2>/dev/null || exit 0
      git fetch --quiet origin 2>/dev/null || exit 0

      # Count commits behind upstream
      local behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)

      if [[ $behind -gt 0 ]]; then
        echo "⚠️  Dotfiles: $behind update(s) available (run: dotfiles-upgrade)"
      fi

      # Update cache timestamp
      touch "$cache"
    ) &
  fi
}

# Run update check on shell startup (non-blocking)
check_dotfiles_updates

# =========================
# Drift Detection (local vs vault)
# =========================
# Quick check if local config files have changed since last vault pull
# Runs in <50ms (local checksum comparison only, no vault access)
check_vault_drift() {
  local dotfiles_dir="${HOME}/workspace/dotfiles"
  local drift_lib="$dotfiles_dir/lib/_drift.sh"
  local state_file="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/vault-state.json"

  # Skip if disabled
  [[ "${DOTFILES_SKIP_DRIFT_CHECK:-}" == "1" ]] && return 0

  # Skip if no state file (user hasn't done vault pull yet)
  [[ ! -f "$state_file" ]] && return 0

  # Skip if drift library doesn't exist
  [[ ! -f "$drift_lib" ]] && return 0

  # Source drift library and run quick check
  source "$drift_lib"
  drift_check_quick false
}

# Run drift check on shell startup (fast, local-only)
check_vault_drift

# =========================
# Machine-specific local overrides
# =========================
# Load local customizations that shouldn't be in version control
# Use this for machine-specific aliases, env vars, or functions
# Example: Work laptop might need different AWS_PROFILE defaults
if [[ -f ~/.zshrc.local ]]; then
  source ~/.zshrc.local
fi

# =========================
# Hooks Integration
# =========================
# Source hooks library and run shell_init hooks
# Enables custom behavior at shell lifecycle points
_dotfiles_init_hooks() {
  local dotfiles_dir="${DOTFILES_DIR:-${HOME}/workspace/dotfiles}"
  local hooks_lib="$dotfiles_dir/lib/_hooks.sh"

  # Skip if hooks library doesn't exist
  [[ -f "$hooks_lib" ]] || return 0

  # Source hooks library
  source "$hooks_lib" 2>/dev/null || return 0

  # Run shell_init hooks
  hook_run "shell_init" 2>/dev/null || true

  # Set up directory change hook
  _dotfiles_directory_change_hook() {
    hook_run "directory_change" "$PWD" 2>/dev/null || true
  }
  add-zsh-hook chpwd _dotfiles_directory_change_hook 2>/dev/null

  # Set up shell exit hook
  zshexit() {
    hook_run "shell_exit" 2>/dev/null || true
  }
}

# Initialize hooks (silently)
_dotfiles_init_hooks

# =========================
# zsh-syntax-highlighting (must be at the end)
# =========================
if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="${BREW_PREFIX:-$(brew --prefix 2>/dev/null)}"
  if [ -n "$BREW_PREFIX" ] && [ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  fi
fi
