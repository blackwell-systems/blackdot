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
  # Colors
  local green='\033[0;32m'
  local red='\033[0;31m'
  local yellow='\033[0;33m'
  local cyan='\033[0;36m'
  local bold='\033[1m'
  local dim='\033[2m'
  local nc='\033[0m'

  # Check auth status first to determine logo color
  local logo_color is_authenticated
  if aws sts get-caller-identity &>/dev/null; then
    logo_color="$green"
    is_authenticated=true
  else
    logo_color="$red"
    is_authenticated=false
  fi

  echo ""
  echo -e "${logo_color}   █████╗ ██╗    ██╗███████╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗${nc}"
  echo -e "${logo_color}  ██╔══██╗██║    ██║██╔════╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝${nc}"
  echo -e "${logo_color}  ███████║██║ █╗ ██║███████╗       ██║   ██║   ██║██║   ██║██║     ███████╗${nc}"
  echo -e "${logo_color}  ██╔══██║██║███╗██║╚════██║       ██║   ██║   ██║██║   ██║██║     ╚════██║${nc}"
  echo -e "${logo_color}  ██║  ██║╚███╔███╔╝███████║       ██║   ╚██████╔╝╚██████╔╝███████╗███████║${nc}"
  echo -e "${logo_color}  ╚═╝  ╚═╝ ╚══╝╚══╝ ╚══════╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝${nc}"
  echo ""

  # Profile Management
  echo -e "  ${dim}╭─────────────────────────────────────────────────────────────────╮${nc}"
  echo -e "  ${dim}│${nc}  ${bold}${cyan}PROFILE MANAGEMENT${nc}                                          ${dim}│${nc}"
  echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
  echo -e "  ${dim}│${nc}  ${yellow}awsprofiles${nc}        ${dim}List all profiles (* = active)${nc}             ${dim}│${nc}"
  echo -e "  ${dim}│${nc}  ${yellow}awsswitch${nc}          ${dim}Fuzzy-select profile (fzf) + auto-login${nc}    ${dim}│${nc}"
  echo -e "  ${dim}│${nc}  ${yellow}awsset${nc} <profile>   ${dim}Set AWS_PROFILE for this shell${nc}             ${dim}│${nc}"
  echo -e "  ${dim}│${nc}  ${yellow}awsunset${nc}           ${dim}Clear AWS_PROFILE${nc}                          ${dim}│${nc}"
  echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
  echo -e "  ${dim}│${nc}  ${bold}${cyan}AUTHENTICATION${nc}                                              ${dim}│${nc}"
  echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
  echo -e "  ${dim}│${nc}  ${yellow}awslogin${nc} [profile] ${dim}SSO login (defaults to current profile)${nc}    ${dim}│${nc}"
  echo -e "  ${dim}│${nc}  ${yellow}awswho${nc}             ${dim}Show current identity (account/user/ARN)${nc}   ${dim}│${nc}"
  echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
  echo -e "  ${dim}│${nc}  ${bold}${cyan}ROLE ASSUMPTION${nc}                                             ${dim}│${nc}"
  echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
  echo -e "  ${dim}│${nc}  ${yellow}awsassume${nc} <arn>    ${dim}Assume role for cross-account access${nc}       ${dim}│${nc}"
  echo -e "  ${dim}│${nc}  ${yellow}awsclear${nc}           ${dim}Clear temporary assumed-role credentials${nc}   ${dim}│${nc}"
  echo -e "  ${dim}╰─────────────────────────────────────────────────────────────────╯${nc}"
  echo ""

  # Current Status
  echo -e "  ${bold}Current Status${nc}"
  echo -e "  ${dim}───────────────────────────────────────${nc}"
  local profile="${AWS_PROFILE:-}"
  if [[ -n "$profile" ]]; then
    echo -e "    ${dim}Profile${nc}   ${cyan}$profile${nc}"
  else
    echo -e "    ${dim}Profile${nc}   ${dim}<not set>${nc}"
  fi
  if [[ "$is_authenticated" == "true" ]]; then
    echo -e "    ${dim}Session${nc}   ${green}✓ authenticated${nc}"
  else
    echo -e "    ${dim}Session${nc}   ${red}✗ not authenticated${nc} ${dim}(run awslogin)${nc}"
  fi
  echo ""
}
