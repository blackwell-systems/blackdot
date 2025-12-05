#!/usr/bin/env zsh
# CLI Feature Awareness - Show/hide commands based on Feature Registry state
# Integrates with lib/_features.sh to provide feature-aware CLI help
#
# Usage in 40-aliases.zsh:
#   source "$DOTFILES_DIR/lib/_cli_features.sh"
#   if cli_command_visible "vault"; then ... fi

set -euo pipefail

# ============================================================
# Command-to-Feature Mapping
# ============================================================
# Maps CLI commands to their required features
# Empty string = always visible (core command)

typeset -gA CLI_COMMAND_FEATURES=(
    # Core commands (always visible)
    ["status"]=""
    ["s"]=""
    ["doctor"]=""
    ["health"]=""
    ["help"]=""
    ["cd"]=""
    ["edit"]=""
    ["setup"]=""
    ["migrate"]=""
    ["uninstall"]=""
    ["upgrade"]=""
    ["update"]=""
    ["lint"]=""
    ["packages"]=""
    ["pkg"]=""

    # Feature management (always visible - needed to enable others)
    ["features"]=""
    ["feature"]=""
    ["feat"]=""

    # Configuration (config_layers feature)
    ["config"]="config_layers"
    ["cfg"]="config_layers"

    # Vault operations
    ["vault"]="vault"
    ["secrets"]="vault"
    ["sync"]="vault"
    ["drift"]="drift_check"
    ["diff"]="vault"

    # Backup operations
    ["backup"]="backup_auto"
    ["rollback"]="backup_auto"

    # Template system
    ["template"]="templates"
    ["tmpl"]="templates"

    # macOS settings
    ["macos"]="macos_settings"

    # Metrics
    ["metrics"]="health_metrics"
)

# ============================================================
# Subcommand-to-Feature Mapping
# ============================================================
# Maps specific subcommands to features (more granular than command level)
# Format: "command:subcommand" -> "feature"

typeset -gA CLI_SUBCOMMAND_FEATURES=(
    # Vault subcommands
    ["vault:setup"]="vault"
    ["vault:pull"]="vault"
    ["vault:push"]="vault"
    ["vault:sync"]="vault"
    ["vault:scan"]="vault"
    ["vault:list"]="vault"
    ["vault:status"]="vault"
    ["vault:validate"]="vault"

    # Config subcommands
    ["config:get"]="config_layers"
    ["config:set"]="config_layers"
    ["config:show"]="config_layers"
    ["config:list"]="config_layers"
    ["config:merged"]="config_layers"
    ["config:init"]="config_layers"
    ["config:edit"]="config_layers"
    ["config:source"]="config_layers"

    # Features subcommands (always visible)
    ["features:list"]=""
    ["features:enable"]=""
    ["features:disable"]=""
    ["features:preset"]=""
    ["features:check"]=""

    # Template subcommands
    ["template:init"]="templates"
    ["template:render"]="templates"
    ["template:link"]="templates"
    ["template:diff"]="templates"
    ["template:vars"]="templates"

    # Backup subcommands
    ["backup:create"]="backup_auto"
    ["backup:list"]="backup_auto"
    ["backup:restore"]="backup_auto"
)

# ============================================================
# Command Sections for Help Display
# ============================================================
# Groups commands into sections with their required feature

typeset -gA CLI_SECTIONS=(
    ["Setup & Health"]=""
    ["Vault Operations"]="vault"
    ["Backup & Safety"]="backup_auto"
    ["Feature Management"]=""
    ["Configuration"]="config_layers"
    ["Templates"]="templates"
    ["macOS Settings"]="macos_settings"
    ["Metrics"]="health_metrics"
    ["Other Commands"]=""
)

# Commands in each section (space-separated)
typeset -gA CLI_SECTION_COMMANDS=(
    ["Setup & Health"]="setup status doctor lint packages upgrade"
    ["Vault Operations"]="vault secrets sync drift diff"
    ["Backup & Safety"]="backup rollback"
    ["Feature Management"]="features"
    ["Configuration"]="config"
    ["Templates"]="template"
    ["macOS Settings"]="macos"
    ["Metrics"]="metrics"
    ["Other Commands"]="cd edit migrate uninstall"
)

# ============================================================
# Environment Variable Overrides
# ============================================================
# DOTFILES_CLI_SHOW_ALL=true  - Always show all commands in help
# DOTFILES_FORCE=true         - Bypass all feature guards

# Check if show-all mode is enabled (env var or --all flag)
_cli_show_all_enabled() {
    [[ "${DOTFILES_CLI_SHOW_ALL:-}" == "true" || "${DOTFILES_CLI_SHOW_ALL:-}" == "1" ]]
}

# Check if force mode is enabled via env var
_cli_force_enabled() {
    [[ "${DOTFILES_FORCE:-}" == "true" || "${DOTFILES_FORCE:-}" == "1" ]]
}

# Check if CLI filtering is enabled (cli_feature_filter feature)
# When disabled, all commands are visible and guards are bypassed
_cli_filtering_enabled() {
    # Check if feature_enabled function exists
    if ! type feature_enabled &>/dev/null; then
        return 0  # Default to enabled if registry not loaded
    fi

    # Check the cli_feature_filter feature
    feature_enabled "cli_feature_filter" 2>/dev/null
}

# ============================================================
# Core Functions
# ============================================================

# Check if a command should be visible in help
# Usage: cli_command_visible "vault"
# Returns: 0 if visible, 1 if hidden
cli_command_visible() {
    local cmd="$1"
    local feature="${CLI_COMMAND_FEATURES[$cmd]:-}"

    # Environment override: show all
    if _cli_show_all_enabled; then
        return 0
    fi

    # Meta-feature: if cli_feature_filter disabled, show all
    if ! _cli_filtering_enabled; then
        return 0
    fi

    # No feature requirement = always visible
    if [[ -z "$feature" ]]; then
        return 0
    fi

    # Check if feature_enabled function exists
    if ! type feature_enabled &>/dev/null; then
        # Feature registry not loaded, show all commands
        return 0
    fi

    # Check feature state
    feature_enabled "$feature"
}

# Get the feature required for a command
# Usage: cli_command_feature "vault" -> "vault"
cli_command_feature() {
    local cmd="$1"
    echo "${CLI_COMMAND_FEATURES[$cmd]:-}"
}

# Get the feature required for a subcommand
# Usage: cli_subcommand_feature "vault" "pull" -> "vault"
cli_subcommand_feature() {
    local cmd="$1"
    local subcmd="$2"
    local key="${cmd}:${subcmd}"
    echo "${CLI_SUBCOMMAND_FEATURES[$key]:-}"
}

# Check if a subcommand should be visible
# Usage: cli_subcommand_visible "vault" "pull"
cli_subcommand_visible() {
    local cmd="$1"
    local subcmd="$2"
    local key="${cmd}:${subcmd}"
    local feature="${CLI_SUBCOMMAND_FEATURES[$key]:-}"

    # Environment override: show all
    if _cli_show_all_enabled; then
        return 0
    fi

    # Meta-feature: if cli_feature_filter disabled, show all
    if ! _cli_filtering_enabled; then
        return 0
    fi

    # Check if subcommand is mapped
    if [[ -z "${CLI_SUBCOMMAND_FEATURES[$key]+x}" ]]; then
        # Not mapped - fall back to parent command check
        cli_command_visible "$cmd"
        return $?
    fi

    # No feature requirement = always visible
    if [[ -z "$feature" ]]; then
        return 0
    fi

    # Check if feature_enabled function exists
    if ! type feature_enabled &>/dev/null; then
        return 0
    fi

    # Check feature state
    feature_enabled "$feature"
}

# Check if a section should be visible
# Usage: cli_section_visible "Vault Operations"
cli_section_visible() {
    local section="$1"
    local feature="${CLI_SECTIONS[$section]:-}"

    # Environment override: show all
    if _cli_show_all_enabled; then
        return 0
    fi

    # Meta-feature: if cli_feature_filter disabled, show all
    if ! _cli_filtering_enabled; then
        return 0
    fi

    # No feature requirement = always visible
    if [[ -z "$feature" ]]; then
        return 0
    fi

    # Check if feature_enabled function exists
    if ! type feature_enabled &>/dev/null; then
        return 0
    fi

    feature_enabled "$feature"
}

# ============================================================
# Feature Guard for Commands
# ============================================================

# Check if command can run, show helpful message if not
# Usage: cli_require_feature "vault" "vault pull" "$@"
# Returns: 0 if allowed, 1 if blocked (with message)
# Sets CLI_FILTERED_ARGS with --force removed if force was used
cli_require_feature() {
    local feature="$1"
    local command="$2"
    shift 2

    # Check for --force or -f flag anywhere in args
    local force=false
    local filtered_args=()
    for arg in "$@"; do
        if [[ "$arg" == "--force" || "$arg" == "-f" ]]; then
            force=true
            # Don't add --force to filtered args
        else
            filtered_args+=("$arg")
        fi
    done

    # Export filtered args for caller to use
    CLI_FILTERED_ARGS=("${filtered_args[@]}")

    # Environment override: DOTFILES_FORCE bypasses all guards
    if _cli_force_enabled; then
        return 0
    fi

    # If --force flag passed, allow execution
    if $force; then
        return 0
    fi

    # Meta-feature: if cli_feature_filter disabled, allow all
    if ! _cli_filtering_enabled; then
        return 0
    fi

    # Check if feature_enabled function exists
    if ! type feature_enabled &>/dev/null; then
        return 0
    fi

    # Check feature state
    if feature_enabled "$feature"; then
        return 0
    fi

    # Feature disabled - show helpful message
    _cli_feature_disabled_message "$feature" "$command"
    return 1
}

# Display message when trying to run disabled feature command
_cli_feature_disabled_message() {
    local feature="$1"
    local command="$2"

    echo ""
    echo -e "${YELLOW:-\033[0;33m}⚠${NC:-\033[0m} The '${CYAN:-\033[0;36m}$feature${NC:-\033[0m}' feature is not enabled."
    echo ""
    echo "To enable ${feature} support:"
    echo -e "  ${GREEN:-\033[0;32m}dotfiles features enable $feature${NC:-\033[0m}"
    echo ""
    echo "Or run with --force to execute anyway:"
    echo -e "  ${DIM:-\033[2m}dotfiles $command --force${NC:-\033[0m}"
    echo ""
}

# ============================================================
# Help Display Helpers
# ============================================================

# Get list of hidden features for footer
cli_hidden_features() {
    local hidden=()

    if ! type feature_enabled &>/dev/null; then
        return 0
    fi

    for feature in vault templates backup_auto health_metrics macos_settings drift_check; do
        if ! feature_enabled "$feature" 2>/dev/null; then
            hidden+=("$feature")
        fi
    done

    if [[ ${#hidden[@]} -gt 0 ]]; then
        echo "${hidden[*]}"
    fi
}

# Show feature indicator for --all mode
# Usage: cli_feature_indicator "vault" -> "● " or "○ "
cli_feature_indicator() {
    local feature="$1"

    if [[ -z "$feature" ]]; then
        echo ""
        return
    fi

    if ! type feature_enabled &>/dev/null; then
        echo ""
        return
    fi

    if feature_enabled "$feature" 2>/dev/null; then
        echo -e "${GREEN:-\033[0;32m}●${NC:-\033[0m}"
    else
        echo -e "${DIM:-\033[2m}○${NC:-\033[0m}"
    fi
}
