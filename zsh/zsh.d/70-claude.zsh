# =========================
# 70-claude.zsh
# =========================
# Claude Code wrapper function and routing logic
# Provides portable session management and model routing (Bedrock vs Max)
# Runtime guards allow enable/disable without shell reload
#
# Configuration: Set these in ~/.claude.local or your environment:
#   CLAUDE_BEDROCK_PROFILE  - AWS SSO profile name (required for Bedrock)
#   CLAUDE_BEDROCK_REGION   - AWS region (default: us-west-2)
#   CLAUDE_BEDROCK_MODEL    - Bedrock model ID (has default)
#   CLAUDE_BEDROCK_FAST_MODEL - Fast model for small tasks (has default)
#
# See ~/.claude.local.example for a template.

# =========================
# Configuration (env var overrides)
# =========================
# Users can override these via environment variables or ~/.claude.local

# Source local overrides if present (for personal settings)
[[ -f ~/.claude.local ]] && source ~/.claude.local

# AWS Bedrock settings (empty profile disables Bedrock features)
_CLAUDE_BEDROCK_PROFILE="${CLAUDE_BEDROCK_PROFILE:-}"
_CLAUDE_BEDROCK_REGION="${CLAUDE_BEDROCK_REGION:-us-west-2}"
_CLAUDE_BEDROCK_MODEL="${CLAUDE_BEDROCK_MODEL:-us.anthropic.claude-sonnet-4-5-20250929-v1:0}"
_CLAUDE_BEDROCK_FAST_MODEL="${CLAUDE_BEDROCK_FAST_MODEL:-us.anthropic.claude-3-5-haiku-20241022-v1:0}"

# Claude Code settings
export CLAUDE_CODE_MAX_OUTPUT_TOKENS="${CLAUDE_CODE_MAX_OUTPUT_TOKENS:-60000}"

# =========================
# Claude workspace wrapper
# =========================
# Automatically use /workspace path for portable session history.
# When in ~/workspace/*, transparently cd to /workspace/* before running claude.
# This ensures Claude Code sessions are portable across macOS, Lima, and WSL.
claude() {
  require_feature "claude_integration" || return 1
  if [[ "$PWD" == "$HOME/workspace"* && -d "/workspace" ]]; then
    local canonical_path="/workspace${PWD#$HOME/workspace}"
    if [[ -d "$canonical_path" ]]; then
      # Educational message to teach the correct pattern
      echo "╭──────────────────────────────────────────────────────────────────╮"
      echo "│  CLAUDE CODE PORTABLE SESSION REDIRECT                          │"
      echo "├──────────────────────────────────────────────────────────────────┤"
      echo "│                                                                  │"
      echo "│ You're in:  $PWD"
      echo "│ Redirecting to:  $canonical_path"
      echo "│                                                                  │"
      echo "│ WHY: Claude Code session paths must be identical across all     │"
      echo "│      machines for conversation history to sync properly.        │"
      echo "│                                                                  │"
      echo "│ TIP: Always use /workspace instead of ~/workspace               │"
      echo "│    Example: cd /workspace/dotfiles && claude                    │"
      echo "│                                                                  │"
      echo "│ This enables the same session on macOS, Lima, WSL, and Linux.   │"
      echo "╰──────────────────────────────────────────────────────────────────╯"
      echo ""

      ( cd "$canonical_path" && command claude "$@" )
      return $?
    fi
  fi
  command claude "$@"
}

# =========================
# Claude routing helpers
# =========================

# Helper: check if Bedrock is configured
_claude_bedrock_configured() {
  [[ -n "$_CLAUDE_BEDROCK_PROFILE" ]]
}

# Helper: ensure AWS SSO session is valid
_ensure_aws_sso() {
  if ! _claude_bedrock_configured; then
    echo "Error: Bedrock not configured. Set CLAUDE_BEDROCK_PROFILE in ~/.claude.local" >&2
    return 1
  fi
  if ! aws sts get-caller-identity --profile "$_CLAUDE_BEDROCK_PROFILE" >/dev/null 2>&1; then
    echo "AWS SSO session expired. Logging in..." >&2
    aws sso login --profile "$_CLAUDE_BEDROCK_PROFILE" || return 1
  fi
}

# --- claude-bedrock ---
# Run Claude Code via AWS Bedrock (requires CLAUDE_BEDROCK_PROFILE)
claude-bedrock() {
  require_feature "claude_integration" || return 1
  # Pre-flight: ensure SSO session is valid
  _ensure_aws_sso || return 1

  AWS_PROFILE="$_CLAUDE_BEDROCK_PROFILE" \
  AWS_REGION="$_CLAUDE_BEDROCK_REGION" \
  CLAUDE_CODE_USE_BEDROCK=1 \
  ANTHROPIC_MODEL="$_CLAUDE_BEDROCK_MODEL" \
  ANTHROPIC_SMALL_FAST_MODEL="$_CLAUDE_BEDROCK_FAST_MODEL" \
  claude "$@"
}

# --- claude-max ---
# Run Claude Code via Anthropic Max subscription (clears Bedrock env)
claude-max() {
  require_feature "claude_integration" || return 1
  # Clear Bedrock routing vars
  unset CLAUDE_CODE_USE_BEDROCK
  unset AWS_PROFILE
  unset AWS_REGION
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN

  # Clear direct API overrides so it uses your logged-in Max session
  unset ANTHROPIC_API_KEY
  unset ANTHROPIC_BASE_URL
  unset ANTHROPIC_AUTH_TOKEN

  # Don't leak Bedrock model IDs into Max mode
  unset ANTHROPIC_MODEL
  unset ANTHROPIC_SMALL_FAST_MODEL

  claude "$@"
}

# --- claude-run ---
# Unified command to run Claude with a specific backend
claude-run() {
  require_feature "claude_integration" || return 1
  local MODE="$1"
  shift

  case "$MODE" in
    bedrock)
      claude-bedrock "$@"
      ;;
    max)
      claude-max "$@"
      ;;
    *)
      echo "Usage: claude-run {bedrock|max} [args...]"
      echo ""
      echo "Backends:"
      echo "  bedrock  - AWS Bedrock (requires CLAUDE_BEDROCK_PROFILE)"
      echo "  max      - Anthropic Max subscription"
      echo ""
      echo "Configuration: ~/.claude.local"
      return 1
      ;;
  esac
}

# --- claude-status ---
# Show current Claude configuration
claude-status() {
  require_feature "claude_integration" || return 1
  echo "Claude Code Configuration"
  echo "========================="
  echo ""
  echo "Session portability: $([[ -d /workspace ]] && echo 'enabled (/workspace exists)' || echo 'disabled')"
  echo "Max output tokens:   ${CLAUDE_CODE_MAX_OUTPUT_TOKENS:-default}"
  echo ""
  echo "Bedrock Configuration:"
  if _claude_bedrock_configured; then
    echo "  Profile: $_CLAUDE_BEDROCK_PROFILE"
    echo "  Region:  $_CLAUDE_BEDROCK_REGION"
    echo "  Model:   $_CLAUDE_BEDROCK_MODEL"
    echo "  Fast:    $_CLAUDE_BEDROCK_FAST_MODEL"
    echo ""
    echo -n "  SSO Status: "
    if aws sts get-caller-identity --profile "$_CLAUDE_BEDROCK_PROFILE" >/dev/null 2>&1; then
      echo "authenticated"
    else
      echo "not authenticated (run: aws sso login --profile $_CLAUDE_BEDROCK_PROFILE)"
    fi
  else
    echo "  Not configured (set CLAUDE_BEDROCK_PROFILE in ~/.claude.local)"
  fi
}

# Convenience wrapper functions
# Note: Using 'function' keyword to override existing aliases at parse time
# Note: Using 'cbed' instead of 'cb' to avoid collision with Rust's cargo-build alias
unalias cbed cmax cm 2>/dev/null
function cbed { require_feature "claude_integration" || return 1; claude-bedrock "$@"; }
function cmax { require_feature "claude_integration" || return 1; claude-max "$@"; }
function cm   { require_feature "claude_integration" || return 1; claude-max "$@"; }  # Alias for cmax
