# =========================
# 60-aws.zsh
# =========================
# AWS profile management, SSO authentication, and role assumption helpers
# Provides tools for managing AWS profiles, SSO login, and cross-account access

# =========================
# AWS Profile Management
# =========================

# List all configured AWS profiles
awsprofiles() {
  echo "Available AWS profiles:"
  aws configure list-profiles 2>/dev/null | while read -r profile; do
    if [[ "$profile" == "${AWS_PROFILE:-}" ]]; then
      echo "  * $profile (active)"
    else
      echo "    $profile"
    fi
  done
}

# Interactive profile selector (requires fzf)
awsswitch() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf not installed. Use: awsset <profile>" >&2
    return 1
  fi

  local profile
  profile=$(aws configure list-profiles 2>/dev/null | fzf --header="Select AWS profile")

  if [[ -n "$profile" ]]; then
    export AWS_PROFILE="$profile"
    echo "Switched to AWS_PROFILE=$profile"

    # Check if SSO login is needed
    if ! aws sts get-caller-identity &>/dev/null; then
      echo "Session expired. Logging in..."
      aws sso login --profile "$profile"
    fi
    awswho
  fi
}

# Set AWS profile for current shell
awsset() {
  if [[ -z "$1" ]]; then
    echo "Usage: awsset <profile>" >&2
    echo "Available profiles: $(aws configure list-profiles 2>/dev/null | tr '\n' ' ')" >&2
    return 1
  fi
  export AWS_PROFILE="$1"
  echo "Set AWS_PROFILE=$1"
}

# Unset AWS profile (return to default)
awsunset() {
  unset AWS_PROFILE
  echo "Cleared AWS_PROFILE (using default)"
}

# Show current AWS identity
awswho() {
  local profile="${AWS_PROFILE:-default}"
  echo "Profile: $profile"
  aws sts get-caller-identity --output table 2>/dev/null || echo "Not authenticated. Run: awslogin $profile"
}

# SSO login helper
awslogin() {
  local p="${1:-${AWS_PROFILE:-dev-profile}}"
  echo "Logging in to AWS SSO profile: $p"
  aws sso login --profile "$p"
  # Optionally set as active profile
  if [[ -z "$AWS_PROFILE" ]]; then
    export AWS_PROFILE="$p"
    echo "Set AWS_PROFILE=$p"
  fi
}

# Quick assume role (for cross-account access)
awsassume() {
  local role_arn="$1"
  local session_name="${2:-cli-session}"

  if [[ -z "$role_arn" ]]; then
    echo "Usage: awsassume <role-arn> [session-name]" >&2
    return 1
  fi

  local creds
  creds=$(aws sts assume-role --role-arn "$role_arn" --role-session-name "$session_name" --output json)

  if [[ $? -eq 0 ]]; then
    export AWS_ACCESS_KEY_ID=$(echo "$creds" | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$creds" | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$creds" | jq -r '.Credentials.SessionToken')
    echo "Assumed role: $role_arn"
    awswho
  else
    echo "Failed to assume role" >&2
    return 1
  fi
}

# Clear assumed role credentials
awsclear() {
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN
  echo "Cleared temporary credentials"
}

# Show all AWS commands with banner
awstools() {
  # Source theme colors
  source "${DOTFILES_DIR:-$HOME/workspace/dotfiles}/lib/_colors.sh"

  # Check auth status first to determine logo color
  local logo_color is_authenticated
  if aws sts get-caller-identity &>/dev/null; then
    logo_color="$CLR_AWS"
    is_authenticated=true
  else
    logo_color="$CLR_ERROR"
    is_authenticated=false
  fi

  echo ""
  echo -e "${logo_color}   █████╗ ██╗    ██╗███████╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗${CLR_NC}"
  echo -e "${logo_color}  ██╔══██╗██║    ██║██╔════╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝${CLR_NC}"
  echo -e "${logo_color}  ███████║██║ █╗ ██║███████╗       ██║   ██║   ██║██║   ██║██║     ███████╗${CLR_NC}"
  echo -e "${logo_color}  ██╔══██║██║███╗██║╚════██║       ██║   ██║   ██║██║   ██║██║     ╚════██║${CLR_NC}"
  echo -e "${logo_color}  ██║  ██║╚███╔███╔╝███████║       ██║   ╚██████╔╝╚██████╔╝███████╗███████║${CLR_NC}"
  echo -e "${logo_color}  ╚═╝  ╚═╝ ╚══╝╚══╝ ╚══════╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝${CLR_NC}"
  echo ""

  # Profile Management
  echo -e "  ${CLR_BOX}╭─────────────────────────────────────────────────────────────────╮${CLR_NC}"
  echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}PROFILE MANAGEMENT${CLR_NC}                                          ${CLR_BOX}│${CLR_NC}"
  echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
  echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}awsprofiles${CLR_NC}        ${CLR_MUTED}List all profiles (* = active)${CLR_NC}             ${CLR_BOX}│${CLR_NC}"
  echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}awsswitch${CLR_NC}          ${CLR_MUTED}Fuzzy-select profile (fzf) + auto-login${CLR_NC}    ${CLR_BOX}│${CLR_NC}"
  echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}awsset${CLR_NC} <profile>   ${CLR_MUTED}Set AWS_PROFILE for this shell${CLR_NC}             ${CLR_BOX}│${CLR_NC}"
  echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}awsunset${CLR_NC}           ${CLR_MUTED}Clear AWS_PROFILE${CLR_NC}                          ${CLR_BOX}│${CLR_NC}"
  echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
  echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}AUTHENTICATION${CLR_NC}                                              ${CLR_BOX}│${CLR_NC}"
  echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
  echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}awslogin${CLR_NC} [profile] ${CLR_MUTED}SSO login (defaults to current profile)${CLR_NC}    ${CLR_BOX}│${CLR_NC}"
  echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}awswho${CLR_NC}             ${CLR_MUTED}Show current identity (account/user/ARN)${CLR_NC}   ${CLR_BOX}│${CLR_NC}"
  echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
  echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}ROLE ASSUMPTION${CLR_NC}                                             ${CLR_BOX}│${CLR_NC}"
  echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
  echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}awsassume${CLR_NC} <arn>    ${CLR_MUTED}Assume role for cross-account access${CLR_NC}       ${CLR_BOX}│${CLR_NC}"
  echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}awsclear${CLR_NC}           ${CLR_MUTED}Clear temporary assumed-role credentials${CLR_NC}   ${CLR_BOX}│${CLR_NC}"
  echo -e "  ${CLR_BOX}╰─────────────────────────────────────────────────────────────────╯${CLR_NC}"
  echo ""

  # Current Status
  echo -e "  ${CLR_BOLD}Current Status${CLR_NC}"
  echo -e "  ${CLR_MUTED}───────────────────────────────────────${CLR_NC}"
  local profile="${AWS_PROFILE:-}"
  if [[ -n "$profile" ]]; then
    echo -e "    ${CLR_MUTED}Profile${CLR_NC}   ${CLR_PRIMARY}$profile${CLR_NC}"
  else
    echo -e "    ${CLR_MUTED}Profile${CLR_NC}   ${CLR_MUTED}<not set>${CLR_NC}"
  fi
  if [[ "$is_authenticated" == "true" ]]; then
    echo -e "    ${CLR_MUTED}Session${CLR_NC}   ${CLR_SUCCESS}✓ authenticated${CLR_NC}"
  else
    echo -e "    ${CLR_MUTED}Session${CLR_NC}   ${CLR_ERROR}✗ not authenticated${CLR_NC} ${CLR_MUTED}(run awslogin)${CLR_NC}"
  fi
  echo ""
}

# =========================
# Zsh Completions
# =========================

# Helper: get AWS profiles for completion
_aws_profiles() {
    local profiles
    profiles=(${(f)"$(aws configure list-profiles 2>/dev/null)"})
    _describe 'AWS profiles' profiles
}

# Completion for awsset
_awsset() {
    _arguments '1:profile:_aws_profiles'
}
compdef _awsset awsset

# Completion for awslogin
_awslogin() {
    _arguments '1:profile:_aws_profiles'
}
compdef _awslogin awslogin
