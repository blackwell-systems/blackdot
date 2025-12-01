# =========================
# 50-functions.zsh
# =========================
# Shell functions for status checks, project navigation, notes, and system management
# Includes status dashboard, project jumper, notes system, dotfiles upgrade, and SSH helpers

# Quick status dashboard - city skyline theme
status() {
  local fixes=()

  # Colors
  local g=$'\e[32m'  # green
  local r=$'\e[31m'  # red
  local d=$'\e[2m'   # dim
  local n=$'\e[0m'   # reset

  # Gather detailed status
  local s_zshrc="${r}◇${n}" s_zshrc_info="not linked"
  if [[ -L ~/.zshrc ]]; then
    s_zshrc="${g}◆${n}"; s_zshrc_info="${d}→ dotfiles/zsh/zshrc${n}"
  else
    fixes+=("zshrc: bootstrap-dotfiles.sh")
  fi

  local s_claude="${r}◇${n}" s_claude_info="not linked"
  if [[ -L ~/.claude ]]; then
    s_claude="${g}◆${n}"; s_claude_info="${d}→ workspace/.claude${n}"
  else
    fixes+=("claude: bootstrap-dotfiles.sh")
  fi

  local s_workspace="${r}◇${n}" s_workspace_info="missing"
  if [[ -L /workspace ]]; then
    s_workspace="${g}◆${n}"; s_workspace_info="${d}→ $(readlink /workspace)${n}"
  else
    fixes+=("/workspace: sudo ln -sfn \$HOME/workspace /workspace")
  fi

  local ssh_count=$(ssh-add -l 2>/dev/null | wc -l | tr -d ' ')
  local s_ssh="${r}◇${n}" s_ssh_info="${r}no keys${n}"
  if [[ "$ssh_count" -gt 0 ]]; then
    s_ssh="${g}◆${n}"; s_ssh_info="${g}$ssh_count keys loaded${n}"
  else
    fixes+=("ssh: dotfiles vault restore")
  fi

  local s_aws="${r}◇${n}" s_aws_info="${d}not authenticated${n}"
  if aws sts get-caller-identity --profile "${_CLAUDE_BEDROCK_PROFILE:-}" &>/dev/null 2>&1; then
    s_aws="${g}◆${n}"; s_aws_info="${g}authenticated${n}"
  else
    [[ -n "${_CLAUDE_BEDROCK_PROFILE:-}" ]] && fixes+=("aws: aws sso login --profile $_CLAUDE_BEDROCK_PROFILE")
  fi

  local s_lima="${d}·${n}" s_lima_info=""
  if [[ "$OSTYPE" == darwin* ]] && command -v limactl &>/dev/null; then
    if limactl list 2>/dev/null | grep -q Running; then
      s_lima="${g}◆${n}"; s_lima_info="${g}running${n}"
    else
      s_lima="${r}◇${n}"; s_lima_info="${d}stopped${n}"
      fixes+=("lima: limactl start")
    fi
  fi

  # Claude profile (only show if Claude-related tools present)
  local s_profile="${d}·${n}" s_profile_info=""
  if command -v dotclaude &>/dev/null; then
    local profile=$(dotclaude active 2>/dev/null)
    if [[ -n "$profile" && "$profile" != "none" ]]; then
      s_profile="${g}◆${n}"; s_profile_info="${g}$profile${n}"
    else
      s_profile="${r}◇${n}"; s_profile_info="${d}no active profile${n}"
      fixes+=("profile: dotclaude switch <profile>")
    fi
  elif command -v claude &>/dev/null; then
    s_profile="${d}·${n}"; s_profile_info="${d}try: dotclaude.dev${n}"
  fi

  # City silhouette (inspired by Joan Stark)
  echo ""
  echo "                          .│"
  echo "                          │${s_aws}│            ._____"
  echo "              ___         │ │            │${s_workspace}    │"
  echo "    _    _.-\"   \"-._      │ │    _.--\"│  │     │"
  echo " .-\"│  _.│ ${s_zshrc}│${s_claude}│ │   ._-\"  │  │  ${s_lima}  │"
  echo " │  │ │  │  │  │ │   -.__ │    │     │"
  echo " │${s_ssh}│ \"-\"    \"    \"\"    \"-\"  \"-.\"   \"\`     │____"
  echo "▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
  echo ""

  # Diagnostic details
  echo "  zshrc      $s_zshrc  $s_zshrc_info"
  echo "  claude     $s_claude  $s_claude_info"
  echo "  /workspace $s_workspace  $s_workspace_info"
  echo "  ssh        $s_ssh  $s_ssh_info"
  echo "  aws        $s_aws  $s_aws_info"
  [[ -n "$s_lima_info" ]] && echo "  lima       $s_lima  $s_lima_info"
  [[ -n "$s_profile_info" ]] && echo "  profile    $s_profile  $s_profile_info"
  echo ""

  # Fixes if needed
  if [[ ${#fixes[@]} -gt 0 ]]; then
    echo "  ${d}┌─ fixes ────────────────────────────────${n}"
    for fix in "${fixes[@]}"; do
      echo "  ${d}│${n} $fix"
    done
    echo "  ${d}└─────────────────────────────────────────${n}"
    echo ""
  fi
}

# =========================
# PROJECT NAVIGATION (fzf-powered)
# =========================
# Jump to any project by fuzzy search on git repos in /workspace
j() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf not installed. Install with: brew install fzf" >&2
    return 1
  fi

  local base_dir="${1:-/workspace}"
  local dir

  if command -v fd >/dev/null 2>&1; then
    # fd is faster and respects .gitignore
    dir=$(fd -H -t d '^\.git$' "$base_dir" --max-depth 4 2>/dev/null |
      xargs -I{} dirname {} |
      fzf --preview 'ls -la {} 2>/dev/null | head -20' \
          --preview-window=right:40% \
          --header="Jump to project (ESC to cancel)")
  else
    # Fallback to find
    dir=$(find "$base_dir" -maxdepth 4 -type d -name ".git" 2>/dev/null |
      xargs -I{} dirname {} |
      fzf --preview 'ls -la {} 2>/dev/null | head -20' \
          --preview-window=right:40% \
          --header="Jump to project (ESC to cancel)")
  fi

  [[ -n "$dir" ]] && cd "$dir"
}

# =========================
# QUICK NOTES (timestamped markdown)
# =========================
# Capture thoughts, commands, ideas instantly
note() {
  local notes_file="$HOME/workspace/.notes.md"

  # Create file with header if it doesn't exist
  if [[ ! -f "$notes_file" ]]; then
    echo "# Quick Notes" > "$notes_file"
    echo "" >> "$notes_file"
  fi

  if [[ $# -eq 0 ]]; then
    echo "Usage: note <your note text>" >&2
    echo "       notes           # view recent notes" >&2
    echo "       notes all       # view all notes" >&2
    echo "       notes edit      # open notes file" >&2
    return 1
  fi

  echo "- **$(date +%Y-%m-%d\ %H:%M)** | $*" >> "$notes_file"
  echo "✓ Note saved"
}

# View notes
notes() {
  local notes_file="$HOME/workspace/.notes.md"

  if [[ ! -f "$notes_file" ]]; then
    echo "No notes yet. Create one with: note <your note>" >&2
    return 1
  fi

  case "${1:-}" in
    all)
      cat "$notes_file"
      ;;
    edit)
      ${EDITOR:-nano} "$notes_file"
      ;;
    search)
      shift
      grep -i "$*" "$notes_file"
      ;;
    *)
      echo "═══ Recent Notes (last 20) ═══"
      tail -20 "$notes_file"
      echo ""
      echo "Tip: notes all | notes edit | notes search <term>"
      ;;
  esac
}

# Deprecated: use dotfiles-upgrade instead
dotfiles-update() {
    warn "dotfiles-update is deprecated, use dotfiles-upgrade instead"
    dotfiles-upgrade
}

# One-command upgrade flow with health check
dotfiles-upgrade() {
    local DOTFILES_DIR="$HOME/workspace/dotfiles"
    echo "🚀 Upgrading dotfiles..."

    # Pull latest changes
    local branch
    branch="$(cd "$DOTFILES_DIR" && git rev-parse --abbrev-ref HEAD)"
    echo "   Pulling from $branch..."
    (cd "$DOTFILES_DIR" && git pull --rebase origin "$branch")

    # Re-run bootstrap to update symlinks
    echo "   Re-bootstrapping..."
    "$DOTFILES_DIR/bootstrap-dotfiles.sh"

    # Update Homebrew packages
    if command -v brew >/dev/null 2>&1; then
        echo "   Updating Homebrew packages..."
        brew bundle --file="$DOTFILES_DIR/Brewfile" --quiet
    fi

    # Run health check with auto-fix
    echo "   Running health check..."
    "$DOTFILES_DIR/bin/dotfiles-doctor" --fix

    echo "✅ Upgrade complete! Restart shell to apply all changes."
    echo "   Or run: source ~/.zshrc"
}

# Check for dotfiles updates (once per day)
_check_dotfiles_updates() {
    local dotfiles_dir="$HOME/workspace/dotfiles"
    local cache_file="$HOME/.dotfiles-update-check"

    # Skip if checked recently (within last day)
    if [[ -f "$cache_file" ]]; then
        # Check if cache is less than 1 day old
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS
            local cache_age=$(( $(date +%s) - $(stat -f %m "$cache_file") ))
        else
            # Linux
            local cache_age=$(( $(date +%s) - $(stat -c %Y "$cache_file") ))
        fi
        # 86400 seconds = 1 day
        [[ $cache_age -lt 86400 ]] && return
    fi

    # Fetch and compare (silently)
    (cd "$dotfiles_dir" && git fetch origin -q 2>/dev/null) || return
    local current_branch=$(cd "$dotfiles_dir" && git rev-parse --abbrev-ref HEAD 2>/dev/null)
    local behind=$(cd "$dotfiles_dir" && git rev-list --count HEAD..origin/"$current_branch" 2>/dev/null)

    if [[ -n "$behind" && "$behind" -gt 0 ]]; then
        echo ""
        echo "📦 Dotfiles update available ($behind commit(s) behind origin/$current_branch)"
        echo "   Run: dotfiles-upgrade"
        echo ""
    fi

    # Update cache
    touch "$cache_file"
}

# Auto-check on shell startup
_check_dotfiles_updates

# =========================
# SSH Agent (lazy start + auto-add keys)
# =========================
# Auto-start ssh-agent if not running (common on Lima/Linux)
# macOS uses Keychain, so SSH_AUTH_SOCK is usually set by launchd
if [[ -z "$SSH_AUTH_SOCK" ]]; then
  eval "$(ssh-agent -s)" > /dev/null
fi

# Add keys if not already added (silent, only if key exists)
_ssh_add_if_missing() {
  local key="$1"
  [[ ! -f "$key" ]] && return 0

  # Get fingerprint of the key file
  local fp
  fp="$(ssh-keygen -lf "$key" 2>/dev/null | awk '{print $2}')" || return 0

  # Check if already loaded
  if ! ssh-add -l 2>/dev/null | grep -qF "$fp"; then
    ssh-add -q "$key" 2>/dev/null
  fi
}

# SSH keys to auto-add (canonical list in vault/_common.sh SSH_KEYS array)
_ssh_add_if_missing ~/.ssh/id_ed25519_enterprise_ghub
_ssh_add_if_missing ~/.ssh/id_ed25519_blackwell
