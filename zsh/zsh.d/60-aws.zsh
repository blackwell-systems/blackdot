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
  # Check auth status first to determine logo color
  local logo_color
  if aws sts get-caller-identity &>/dev/null; then
    logo_color='\033[0;32m'  # Green - authenticated
    local is_authenticated=true
  else
    logo_color='\033[0;31m'  # Red - not authenticated
    local is_authenticated=false
  fi
  local nc='\033[0m'  # No color

  echo ""
  echo -e "${logo_color}   █████╗ ██╗    ██╗███████╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗${nc}"
  echo -e "${logo_color}  ██╔══██╗██║    ██║██╔════╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝${nc}"
  echo -e "${logo_color}  ███████║██║ █╗ ██║███████╗       ██║   ██║   ██║██║   ██║██║     ███████╗${nc}"
  echo -e "${logo_color}  ██╔══██║██║███╗██║╚════██║       ██║   ██║   ██║██║   ██║██║     ╚════██║${nc}"
  echo -e "${logo_color}  ██║  ██║╚███╔███╔╝███████║       ██║   ╚██████╔╝╚██████╔╝███████╗███████║${nc}"
  echo -e "${logo_color}  ╚═╝  ╚═╝ ╚══╝╚══╝ ╚══════╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝${nc}"
  echo ""

  echo "  ╭─────────────────────────────────────────────────────────────────╮"
  echo "  │                    PROFILE MANAGEMENT                          │"
  echo "  ├─────────────────────────────────────────────────────────────────┤"
  echo "  │  awsprofiles        List all profiles (* = active)             │"
  echo "  │  awsswitch          Fuzzy-select profile (fzf) + auto-login    │"
  echo "  │  awsset <profile>   Set AWS_PROFILE for this shell             │"
  echo "  │  awsunset           Clear AWS_PROFILE                          │"
  echo "  ├─────────────────────────────────────────────────────────────────┤"
  echo "  │                    AUTHENTICATION                              │"
  echo "  ├─────────────────────────────────────────────────────────────────┤"
  echo "  │  awslogin [profile] SSO login (defaults to current profile)    │"
  echo "  │  awswho             Show current identity (account/user/ARN)   │"
  echo "  ├─────────────────────────────────────────────────────────────────┤"
  echo "  │                    ROLE ASSUMPTION                             │"
  echo "  ├─────────────────────────────────────────────────────────────────┤"
  echo "  │  awsassume <arn>    Assume role for cross-account access       │"
  echo "  │  awsclear           Clear temporary assumed-role credentials   │"
  echo "  ╰─────────────────────────────────────────────────────────────────╯"
  echo ""
  echo "  Current status:"
  local profile="${AWS_PROFILE:-<not set>}"
  echo "    AWS_PROFILE = $profile"
  if [[ "$is_authenticated" == "true" ]]; then
    echo -e "    Session     = \033[0;32m✓ authenticated\033[0m"
  else
    echo -e "    Session     = \033[0;31m✗ not authenticated\033[0m (run awslogin)"
  fi
  echo ""
}
