# =========================
# 70-claude.zsh
# =========================
# Claude Code wrapper function and routing logic
# Provides portable session management and model routing (Bedrock vs Max)

# =========================
# Claude workspace wrapper
# =========================
# Automatically use /workspace path for portable session history.
# When in ~/workspace/*, transparently cd to /workspace/* before running claude.
# This ensures Claude Code sessions are portable across macOS, Lima, and WSL.
claude() {
  if [[ "$PWD" == "$HOME/workspace"* && -d "/workspace" ]]; then
    local canonical_path="/workspace${PWD#$HOME/workspace}"
    if [[ -d "$canonical_path" ]]; then
      # Educational message to teach the correct pattern
      echo "╭──────────────────────────────────────────────────────────────────╮"
      echo "│ 🤖 CLAUDE CODE PORTABLE SESSION REDIRECT                        │"
      echo "├──────────────────────────────────────────────────────────────────┤"
      echo "│                                                                  │"
      echo "│ You're in:  $PWD"
      echo "│ Redirecting to:  $canonical_path"
      echo "│                                                                  │"
      echo "│ WHY: Claude Code session paths must be identical across all     │"
      echo "│      machines for conversation history to sync properly.        │"
      echo "│                                                                  │"
      echo "│ ✅ BEST PRACTICE: Always use /workspace instead of ~/workspace  │"
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
# Claude routing helpers (shared)
# =========================

# Centralize Bedrock config here so you only edit in one place.
_CLAUDE_BEDROCK_PROFILE="dev-profile"            # SSO profile name
_CLAUDE_BEDROCK_REGION="us-west-2"               # Bedrock region
_CLAUDE_BEDROCK_MODEL="us.anthropic.claude-sonnet-4-5-20250929-v1:0"

# Optional fast model (leave as-is if you don't have this inference profile)
_CLAUDE_BEDROCK_FAST_MODEL="us.anthropic.claude-3-5-haiku-20241022-v1:0"

CLAUDE_CODE_MAX_OUTPUT_TOKENS=60000

# Helper: ensure AWS SSO session is valid
_ensure_aws_sso() {
    if ! aws sts get-caller-identity --profile "$_CLAUDE_BEDROCK_PROFILE" >/dev/null 2>&1; then
        echo "AWS SSO session expired. Logging in..." >&2
        aws sso login --profile "$_CLAUDE_BEDROCK_PROFILE" || return 1
    fi
}

# --- claude-bedrock ---
claude-bedrock() {
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
claude-max() {
    # kill Bedrock routing vars
    unset CLAUDE_CODE_USE_BEDROCK
    unset AWS_PROFILE
    unset AWS_REGION
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN

    # kill direct API overrides so it uses your logged-in Max session
    unset ANTHROPIC_API_KEY
    unset ANTHROPIC_BASE_URL
    unset ANTHROPIC_AUTH_TOKEN

    # don't leak Bedrock model IDs into Max mode
    unset ANTHROPIC_MODEL
    unset ANTHROPIC_SMALL_FAST_MODEL

    claude "$@"
}

# --- claude-run ---
claude-run() {
    local MODE="$1"
    shift

    if [ "$MODE" = "bedrock" ]; then
        _ensure_aws_sso || return 1

        AWS_PROFILE="$_CLAUDE_BEDROCK_PROFILE" \
        AWS_REGION="$_CLAUDE_BEDROCK_REGION" \
        CLAUDE_CODE_USE_BEDROCK=1 \
        ANTHROPIC_MODEL="$_CLAUDE_BEDROCK_MODEL" \
        ANTHROPIC_SMALL_FAST_MODEL="$_CLAUDE_BEDROCK_FAST_MODEL" \
        claude "$@"
    elif [ "$MODE" = "max" ]; then
        unset CLAUDE_CODE_USE_BEDROCK
        unset AWS_PROFILE
        unset AWS_REGION
        unset AWS_ACCESS_KEY_ID
        unset AWS_SECRET_ACCESS_KEY
        unset AWS_SESSION_TOKEN

        unset ANTHROPIC_API_KEY
        unset ANTHROPIC_BASE_URL
        unset ANTHROPIC_AUTH_TOKEN

        unset ANTHROPIC_MODEL
        unset ANTHROPIC_SMALL_FAST_MODEL

        claude "$@"
    else
        echo "usage: claude-run {bedrock|max} [args...]"
        return 1
    fi
}

# Convenience aliases
alias icode-bedrock='claude-bedrock'
alias icode-max='claude-max'
