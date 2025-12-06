#!/usr/bin/env bash
# ============================================================
# FILE: lib/_errors.sh
# Structured error handling with actionable fix commands
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/_errors.sh"
#
# Functions provided:
#   error_msg()          - Display structured error with fix commands
#   error_vault_locked() - Vault is locked error
#   error_missing_dep()  - Missing dependency error
#   error_git_not_configured() - Git not configured error
#   error_no_vault_backend() - No vault backend configured error
#   error_vault_item_not_found() - Vault item not found error
#   error_permission_denied() - Permission denied error
#   error_network_failed() - Network operation failed error
#
# All error functions return exit code 1
# ============================================================

# Prevent multiple sourcing
if [[ -n "${_ERRORS_SOURCED:-}" ]]; then
    return 0
fi
_ERRORS_SOURCED=1

# Source logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_logging.sh"

# ============================================================
# Core Error Display Function
# ============================================================

# Display structured error message with fix commands
# Usage: error_msg "ERROR_TITLE" "Why: explanation" "Impact: what this means" "Fix: command" ["Help: URL"]
error_msg() {
    local title="$1"
    local why="$2"
    local impact="$3"
    local fix="$4"
    local help="${5:-}"

    echo "" >&2
    echo -e "${RED}${BOLD}❌ ${title}${NC}" >&2
    echo "" >&2

    if [[ -n "$why" ]]; then
        echo -e "   ${BOLD}Why:${NC} ${why}" >&2
    fi

    if [[ -n "$impact" ]]; then
        echo -e "   ${BOLD}Impact:${NC} ${impact}" >&2
    fi

    echo "" >&2

    if [[ -n "$fix" ]]; then
        echo -e "   ${BOLD}Fix:${NC}" >&2
        # Handle multiline fix commands
        while IFS= read -r line; do
            if [[ "$line" == *"→"* ]]; then
                # Command line (starts with →)
                echo -e "   ${GREEN}${line}${NC}" >&2
            elif [[ "$line" =~ ^\ *Or: ]]; then
                # Alternative option
                echo "" >&2
                echo -e "   ${BOLD}${line}${NC}" >&2
            else
                # Description line
                echo -e "   ${line}" >&2
            fi
        done <<< "$fix"
    fi

    if [[ -n "$help" ]]; then
        echo "" >&2
        echo -e "   ${BOLD}Help:${NC} ${CYAN}${help}${NC}" >&2
    fi

    echo "" >&2
    return 1
}

# ============================================================
# Common Error Functions
# ============================================================

# Vault is locked (Bitwarden/1Password)
error_vault_locked() {
    local backend="${1:-Bitwarden}"
    local unlock_cmd=""
    local export_cmd=""

    case "$backend" in
        "bitwarden"|"bw")
            unlock_cmd="bw unlock"
            export_cmd='export BW_SESSION="$(bw unlock --raw)"'
            ;;
        "1password"|"op")
            unlock_cmd="op signin"
            export_cmd="# Session will be stored automatically"
            ;;
        *)
            unlock_cmd="Unlock your vault"
            export_cmd=""
            ;;
    esac

    error_msg \
        "Vault is locked" \
        "$backend session expired or not logged in" \
        "Cannot pull secrets from vault" \
        "Unlock your vault:
   → ${unlock_cmd}
   → ${export_cmd}

Or: Use different backend
   → dotfiles vault setup" \
        "https://github.com/blackwell-systems/dotfiles/blob/main/docs/vault-README.md#authentication"
}

# Missing dependency
error_missing_dep() {
    local dep="$1"
    local install_cmd="${2:-brew install $dep}"
    local purpose="${3:-Required for this operation}"

    error_msg \
        "$dep not found" \
        "$dep is not installed on your system" \
        "$purpose" \
        "Install $dep:
   → ${install_cmd}

Then retry this command" \
        "https://github.com/blackwell-systems/dotfiles/blob/main/README.md#prerequisites"
}

# Git not configured
error_git_not_configured() {
    error_msg \
        "Git config not found" \
        "Git user.name or user.email not configured" \
        "This is expected on fresh machines. Git commits will fail without this." \
        "Configure Git identity:
   → git config --global user.name \"Your Name\"
   → git config --global user.email \"your@email.com\"

Or: Use templates for machine-specific config
   → dotfiles template init" \
        "https://github.com/blackwell-systems/dotfiles/blob/main/docs/templates.md"
}

# No vault backend configured
error_no_vault_backend() {
    error_msg \
        "No vault backend configured" \
        "Vault integration not set up yet" \
        "Cannot sync secrets without a vault backend" \
        "Configure vault backend:
   → dotfiles vault setup

Choose: Bitwarden, 1Password, or pass" \
        "https://github.com/blackwell-systems/dotfiles/blob/main/docs/vault-README.md"
}

# Vault item not found
error_vault_item_not_found() {
    local item="$1"

    error_msg \
        "Vault item not found: $item" \
        "Item does not exist in vault or has not been synced" \
        "Cannot restore this item" \
        "Scan for secrets and sync to vault:
   → dotfiles vault scan
   → dotfiles vault push

Then retry restore:
   → dotfiles vault pull" \
        "https://github.com/blackwell-systems/dotfiles/blob/main/docs/vault-README.md#workflow"
}

# Permission denied
error_permission_denied() {
    local path="$1"
    local expected_perms="${2:-0600}"

    error_msg \
        "Permission denied: $path" \
        "File/directory has incorrect permissions or ownership" \
        "Cannot read or write to this location" \
        "Fix permissions:
   → chmod ${expected_perms} \"${path}\"

Or: Check ownership
   → ls -la \"${path}\"
   → sudo chown \$USER \"${path}\"

Or: Run health check with auto-fix
   → dotfiles doctor --fix" \
        "https://github.com/blackwell-systems/dotfiles/blob/main/docs/README-FULL.md#troubleshooting"
}

# Network operation failed
error_network_failed() {
    local operation="${1:-Network operation}"

    error_msg \
        "$operation failed" \
        "Unable to reach remote server (DNS, firewall, or connection issue)" \
        "Cannot sync or download data" \
        "Check network connection:
   → ping github.com
   → curl -I https://github.com

Check VPN/proxy settings if applicable

Retry with debug output:
   → DEBUG=1 dotfiles [your command]" \
        "https://github.com/blackwell-systems/dotfiles/blob/main/docs/README-FULL.md#troubleshooting"
}

# File already exists (for operations that don't want to overwrite)
error_file_exists() {
    local path="$1"

    error_msg \
        "File already exists: $path" \
        "Target file exists and would be overwritten" \
        "Operation cancelled to prevent data loss" \
        "Backup existing file first:
   → mv \"${path}\" \"${path}.backup\"

Or: View diff before overwriting
   → dotfiles drift

Or: Force overwrite (if you're sure)
   → dotfiles [command] --force" \
        "https://github.com/blackwell-systems/dotfiles/blob/main/docs/README-FULL.md#safety"
}

# Config file is invalid/corrupt
error_invalid_config() {
    local config_path="${1:-~/.config/dotfiles/config.json}"

    error_msg \
        "Invalid config file" \
        "Config file is corrupt or has invalid JSON syntax" \
        "Commands may fail or behave unexpectedly" \
        "Validate config syntax:
   → cat \"${config_path}\" | jq .

Restore from backup:
   → dotfiles backup list
   → dotfiles backup restore [timestamp]

Or: Reset to defaults (CAUTION: loses settings)
   → rm \"${config_path}\"
   → dotfiles setup" \
        "https://github.com/blackwell-systems/dotfiles/blob/main/docs/architecture.md#configuration"
}

# Drift detected (local changes will be lost)
error_drift_detected() {
    local num_changed="${1:-1}"

    error_msg \
        "Local changes detected ($num_changed files)" \
        "Files have been modified locally and differ from vault" \
        "Restoring will overwrite your local changes" \
        "Review changes first:
   → dotfiles drift

Save local changes to vault:
   → dotfiles vault push

Or: Create backup before restoring
   → dotfiles backup create
   → dotfiles vault pull

Or: Force restore (CAUTION: loses local changes)
   → dotfiles vault pull --force" \
        "https://github.com/blackwell-systems/dotfiles/blob/main/docs/vault-README.md#drift-detection"
}

# SSH key already exists
error_ssh_key_exists() {
    local key_path="${1:-~/.ssh/id_ed25519}"

    error_msg \
        "SSH key already exists: $key_path" \
        "Found existing SSH key at this location" \
        "Restoring from vault would overwrite your existing key" \
        "Backup existing key first:
   → mv \"${key_path}\" \"${key_path}.backup\"
   → mv \"${key_path}.pub\" \"${key_path}.pub.backup\"

Or: Compare keys
   → diff \"${key_path}\" <(dotfiles vault show SSH-Key)

Or: Skip SSH key restore
   → dotfiles vault pull --skip-ssh" \
        "https://github.com/blackwell-systems/dotfiles/blob/main/docs/vault-README.md#ssh-keys"
}

# Brewfile tier not specified or invalid
error_invalid_brewfile_tier() {
    local tier="${1:-}"

    error_msg \
        "Invalid Brewfile tier: $tier" \
        "Tier must be: minimal, enhanced, or full" \
        "Package installation cannot proceed" \
        "Use interactive setup:
   → dotfiles setup

Or: Set valid tier
   → export BREWFILE_TIER=enhanced
   → ./bootstrap/bootstrap-mac.sh

Available tiers:
   • minimal  - 18 packages (~2 min)
   • enhanced - 43 packages (~5 min) [recommended]
   • full     - 61 packages (~10 min)" \
        "https://github.com/blackwell-systems/dotfiles/blob/main/README.md#brewfile-tiers"
}

# Template variable not defined
error_template_var_undefined() {
    local var_name="$1"
    local template_file="${2:-}"

    error_msg \
        "Template variable undefined: $var_name" \
        "Template requires variable that is not defined in _variables.sh" \
        "Template rendering will fail or produce incorrect output" \
        "Define variable in templates/_variables.sh:
   → echo 'export ${var_name}=\"value\"' >> templates/_variables.sh

Or: Use machine-specific variables
   → cp templates/_variables.sh templates/_variables_\$(hostname).sh
   → dotfiles template init

Then re-render:
   → dotfiles template render" \
        "https://github.com/blackwell-systems/dotfiles/blob/main/docs/templates.md"
}

# Health check failed
error_health_check_failed() {
    local score="${1:-0}"
    local num_failures="${2:-unknown}"

    error_msg \
        "Health check failed (score: $score/100)" \
        "System has $num_failures critical issues" \
        "Dotfiles may not function correctly" \
        "View detailed report:
   → dotfiles doctor

Auto-fix common issues:
   → dotfiles doctor --fix

Manual troubleshooting:
   → dotfiles doctor --verbose" \
        "https://github.com/blackwell-systems/dotfiles/blob/main/docs/cli-reference.md#doctor"
}

# Backup failed
error_backup_failed() {
    local reason="${1:-Unknown error}"

    error_msg \
        "Backup creation failed" \
        "$reason" \
        "Cannot create safety backup before operation" \
        "Check disk space:
   → df -h ~/.config/dotfiles/backups

Check permissions:
   → ls -la ~/.config/dotfiles

Clear old backups:
   → dotfiles backup clean

Then retry operation" \
        "https://github.com/blackwell-systems/dotfiles/blob/main/docs/README-FULL.md#backups"
}

# ============================================================
# Export functions (for subshells)
# ============================================================
export -f error_msg
export -f error_vault_locked
export -f error_missing_dep
export -f error_git_not_configured
export -f error_no_vault_backend
export -f error_vault_item_not_found
export -f error_permission_denied
export -f error_network_failed
export -f error_file_exists
export -f error_invalid_config
export -f error_drift_detected
export -f error_ssh_key_exists
export -f error_invalid_brewfile_tier
export -f error_template_var_undefined
export -f error_health_check_failed
export -f error_backup_failed
