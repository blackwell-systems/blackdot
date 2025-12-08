# =========================
# 40-aliases.zsh
# =========================
# Shell aliases for navigation, vault, dotfiles, and utilities
# Convenient shortcuts for common operations

# Color definitions for CLI output
if [[ -t 1 ]]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    BOLD='' DIM='' RED='' GREEN='' YELLOW='' BLUE='' CYAN='' NC=''
fi

# Convenience navigation aliases
alias cws='cd "$WORKSPACE"'
alias ccode='cd "$WORKSPACE/code"'
alias cwhite='cd "$WORKSPACE/whitepapers"'
alias cpat='cd "$WORKSPACE/patent-pool"'

# Source CLI feature awareness if available
if [[ -f "$DOTFILES_DIR/lib/_cli_features.sh" ]]; then
    source "$DOTFILES_DIR/lib/_cli_features.sh" 2>/dev/null || true
fi

# Command-specific help information
typeset -gA CLI_COMMAND_HELP=(
    ["vault"]="vault|Vault Operations|Multi-vault secret management (Bitwarden/1Password/pass)|
  vault setup       Setup vault backend (first-time setup)
  vault pull        Pull secrets from vault
  vault push        Push secrets to vault
  vault sync        Bidirectional sync (smart direction)
  vault scan        Re-scan for new secrets
  vault list        List all vault items
  vault status      Show vault sync status"
    ["config"]="config_layers|Configuration|Hierarchical configuration resolution (env>project>machine>user)|
  config get <key>          Get config value with layer resolution
  config set <layer> <k> <v> Set config in specific layer
  config show <key>         Show where a config value comes from
  config list               Show configuration layer status
  config merged             Show merged config from all layers
  config init <type>        Initialize machine or project config
  config edit [layer]       Edit config in \$EDITOR"
    ["backup"]="backup_auto|Backup & Safety|Automatic backup before destructive operations|
  backup create     Create backup of current config
  backup list       List all backups
  backup restore    Restore specific backup
  rollback          Instant rollback to last backup"
    ["template"]="templates|Templates|Machine-specific configuration templates|
  template init     Initialize templates for this machine
  template render   Render all templates
  template link     Create symlinks from templates
  template diff     Show differences from rendered
  template vars     Show available template variables"
    ["features"]="core|Feature Management|Enable/disable dotfiles features|
  features          List all features and status
  features list     List features (optionally by category)
  features enable   Enable a feature
  features disable  Disable a feature
  features preset   Apply a preset (minimal/developer/claude/full)
  features check    Check if feature is enabled (for scripts)"
    ["doctor"]="core|Health Check|Comprehensive system health diagnostics|
  doctor            Run all health checks
  doctor --fix      Auto-fix common issues
  doctor --json     Output as JSON for automation"
    ["status"]="core|Status|Quick visual dashboard|
  status            Show quick status dashboard
  status --verbose  Show detailed status"
    ["metrics"]="health_metrics|Metrics|Health check metrics visualization|
  metrics           Show metrics dashboard
  metrics history   Show historical trends"
)

# Helper: Show help for a specific command
_dotfiles_help_command() {
    local cmd="$1"
    local info="${CLI_COMMAND_HELP[$cmd]:-}"

    if [[ -z "$info" ]]; then
        echo "No detailed help available for: $cmd"
        echo ""
        echo "Try: dotfiles help"
        return 1
    fi

    # Parse info - first line contains metadata, rest is subcommands
    local first_line="${info%%$'\n'*}"
    local subcommands="${info#*$'\n'}"

    # Parse first line: "feature|title|description"
    local feature="${first_line%%|*}"
    local rest="${first_line#*|}"
    local title="${rest%%|*}"
    local description="${rest#*|}"
    description="${description%%|*}"  # Remove trailing pipe if any

    # Show feature status
    local status_text="${GREEN}●${NC} enabled"
    local feature_status="enabled"
    if [[ -n "$feature" && "$feature" != "core" ]]; then
        if type feature_enabled &>/dev/null && ! feature_enabled "$feature" 2>/dev/null; then
            status_text="${DIM}○${NC} disabled"
            feature_status="disabled"
        fi
    else
        status_text="${CYAN}core${NC}"
        feature_status="core"
    fi

    echo "${BOLD}${CYAN}dotfiles $cmd${NC} - $title"
    echo ""
    echo "${BOLD}Feature:${NC} $feature ($status_text)"
    echo "${BOLD}Description:${NC} $description"
    echo ""
    echo "${BOLD}Commands:${NC}"
    echo "$subcommands"
    echo ""

    # Show enable hint if disabled
    if [[ "$feature_status" == "disabled" ]]; then
        echo "─────────────────────────────────────────────────────"
        echo "${YELLOW}⚠${NC} This feature is not enabled."
        echo "  Enable with: ${GREEN}dotfiles features enable $feature${NC}"
        echo "  Or use: ${DIM}dotfiles $cmd --force${NC}"
        echo ""
    fi
}

# Helper function for feature-aware help display
_dotfiles_help() {
    local show_all=false
    local show_cmd=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all|-a) show_all=true ;;
            -*) ;;  # ignore other flags
            *) show_cmd="$1" ;;
        esac
        shift
    done

    # If command specified, show command-specific help
    if [[ -n "$show_cmd" ]]; then
        _dotfiles_help_command "$show_cmd"
        return $?
    fi

    echo "${BOLD}${CYAN}dotfiles${NC} - Manage your dotfiles"
    echo ""
    echo "${BOLD}Usage:${NC} dotfiles <command> [options]"
    echo ""

    # Setup & Health (always visible)
    echo "${BOLD}${CYAN}Setup & Health:${NC}"
    echo "  ${YELLOW}setup${NC}             ${DIM}Interactive setup wizard (recommended)${NC}"
    echo "  ${YELLOW}status${NC}, s         ${DIM}Quick visual dashboard${NC}"
    echo "  ${YELLOW}doctor${NC}, health    ${DIM}Run comprehensive health check${NC}"
    echo "  ${YELLOW}lint${NC}              ${DIM}Validate shell config syntax${NC}"
    echo "  ${YELLOW}packages${NC}, pkg     ${DIM}Check/install Brewfile packages${NC}"
    echo "  ${YELLOW}upgrade${NC}, update   ${DIM}Pull latest and run bootstrap${NC}"
    echo ""

    # Vault Operations (feature: vault)
    local vault_visible=true
    if type cli_section_visible &>/dev/null && ! cli_section_visible "Vault Operations"; then
        vault_visible=false
    fi
    if $show_all || $vault_visible; then
        local indicator=""
        if $show_all && type cli_feature_indicator &>/dev/null; then
            indicator=" $(cli_feature_indicator vault)"
        fi
        echo "${BOLD}${CYAN}Vault Operations:${NC}${indicator}"
        echo "  ${YELLOW}vault setup${NC}       ${DIM}Setup vault backend (first-time setup)${NC}"
        echo "  ${YELLOW}vault pull${NC}        ${DIM}Pull secrets from vault${NC}"
        echo "  ${YELLOW}vault push${NC}        ${DIM}Push secrets to vault${NC}"
        echo "  ${YELLOW}vault sync${NC}        ${DIM}Bidirectional sync (smart direction)${NC}"
        echo "  ${YELLOW}vault scan${NC}        ${DIM}Re-scan for new secrets${NC}"
        echo "  ${YELLOW}vault list${NC}        ${DIM}List all vault items${NC}"
        echo "  ${YELLOW}drift${NC}             ${DIM}Compare local files vs vault${NC}"
        echo "  ${YELLOW}sync${NC}              ${DIM}Bidirectional vault sync (smart push/pull)${NC}"
        echo "  ${YELLOW}diff${NC}              ${DIM}Preview changes before sync/restore${NC}"
        echo ""
    fi

    # Backup & Safety (feature: backup_auto)
    local backup_visible=true
    if type cli_section_visible &>/dev/null && ! cli_section_visible "Backup & Safety"; then
        backup_visible=false
    fi
    if $show_all || $backup_visible; then
        local indicator=""
        if $show_all && type cli_feature_indicator &>/dev/null; then
            indicator=" $(cli_feature_indicator backup_auto)"
        fi
        echo "${BOLD}${CYAN}Backup & Safety:${NC}${indicator}"
        echo "  ${YELLOW}backup${NC}            ${DIM}Create backup of current config${NC}"
        echo "  ${YELLOW}backup list${NC}       ${DIM}List all backups${NC}"
        echo "  ${YELLOW}backup restore${NC}    ${DIM}Restore specific backup${NC}"
        echo "  ${YELLOW}rollback${NC}          ${DIM}Instant rollback to last backup${NC}"
        echo ""
    fi

    # Feature Management (always visible)
    echo "${BOLD}${CYAN}Feature Management:${NC}"
    echo "  ${YELLOW}features${NC}          ${DIM}List all features and status${NC}"
    echo "  ${YELLOW}features enable${NC}   ${DIM}Enable a feature${NC}"
    echo "  ${YELLOW}features disable${NC}  ${DIM}Disable a feature${NC}"
    echo "  ${YELLOW}features preset${NC}   ${DIM}Enable a preset (minimal/developer/claude/full)${NC}"
    echo ""

    # Configuration (feature: config_layers)
    local config_visible=true
    if type cli_section_visible &>/dev/null && ! cli_section_visible "Configuration"; then
        config_visible=false
    fi
    if $show_all || $config_visible; then
        local indicator=""
        if $show_all && type cli_feature_indicator &>/dev/null; then
            indicator=" $(cli_feature_indicator config_layers)"
        fi
        echo "${BOLD}${CYAN}Configuration:${NC}${indicator}"
        echo "  ${YELLOW}config get${NC}        ${DIM}Get config value (with layer resolution)${NC}"
        echo "  ${YELLOW}config set${NC}        ${DIM}Set config value in specific layer${NC}"
        echo "  ${YELLOW}config show${NC}       ${DIM}Show where a config value comes from${NC}"
        echo "  ${YELLOW}config list${NC}       ${DIM}Show configuration layer status${NC}"
        echo ""
    fi

    # Templates (feature: templates)
    local templates_visible=true
    if type cli_section_visible &>/dev/null && ! cli_section_visible "Templates"; then
        templates_visible=false
    fi
    if $show_all || $templates_visible; then
        local indicator=""
        if $show_all && type cli_feature_indicator &>/dev/null; then
            indicator=" $(cli_feature_indicator templates)"
        fi
        echo "${BOLD}${CYAN}Templates:${NC}${indicator}"
        echo "  ${YELLOW}template${NC}, tmpl    ${DIM}Machine-specific config templates${NC}"
        echo ""
    fi

    # macOS Settings (feature: macos_settings, macOS only)
    if [[ "$(uname -s)" == "Darwin" ]]; then
        local macos_visible=true
        if type cli_section_visible &>/dev/null && ! cli_section_visible "macOS Settings"; then
            macos_visible=false
        fi
        if $show_all || $macos_visible; then
            local indicator=""
            if $show_all && type cli_feature_indicator &>/dev/null; then
                indicator=" $(cli_feature_indicator macos_settings)"
            fi
            echo "${BOLD}${CYAN}macOS Settings:${NC}${indicator}"
            echo "  ${YELLOW}macos${NC} <cmd>       ${DIM}macOS system settings${NC}"
            echo ""
        fi
    fi

    # Metrics (feature: health_metrics)
    local metrics_visible=true
    if type cli_section_visible &>/dev/null && ! cli_section_visible "Metrics"; then
        metrics_visible=false
    fi
    if $show_all || $metrics_visible; then
        local indicator=""
        if $show_all && type cli_feature_indicator &>/dev/null; then
            indicator=" $(cli_feature_indicator health_metrics)"
        fi
        echo "${BOLD}${CYAN}Metrics:${NC}${indicator}"
        echo "  ${YELLOW}metrics${NC}           ${DIM}Visualize health check metrics over time${NC}"
        echo ""
    fi

    # Other Commands (always visible)
    echo "${BOLD}${CYAN}Other Commands:${NC}"
    echo "  ${YELLOW}migrate${NC}           ${DIM}Migrate config to v3.0 (INI→JSON, vault v2→v3)${NC}"
    echo "  ${YELLOW}uninstall${NC}         ${DIM}Remove dotfiles configuration${NC}"
    echo "  ${YELLOW}cd${NC}                ${DIM}Change to dotfiles directory${NC}"
    echo "  ${YELLOW}edit${NC}              ${DIM}Open dotfiles in editor${NC}"
    echo "  ${YELLOW}help${NC}              ${DIM}Show this help${NC}"
    echo ""

    # Footer
    if ! $show_all; then
        # Check for hidden features
        local hidden=""
        if type cli_hidden_features &>/dev/null; then
            hidden=$(cli_hidden_features)
        fi
        if [[ -n "$hidden" ]]; then
            echo "─────────────────────────────────────────────────────"
            echo "${DIM}Some commands hidden. Run 'dotfiles help --all' to see all.${NC}"
            echo "${DIM}Disabled features: ${hidden}${NC}"
            echo ""
        fi
    else
        echo "─────────────────────────────────────────────────────"
        echo "${DIM}Legend: ${GREEN}●${NC}${DIM} enabled  ${NC}○${DIM} disabled${NC}"
        echo "${DIM}Enable features: dotfiles features enable <name>${NC}"
        echo ""
    fi

    echo "${DIM}Run 'dotfiles <command> --help' for detailed options.${NC}"
}

# Unified dotfiles command with subcommands
# Remove any pre-existing alias (from .zshrc.local, etc.)
unalias dotfiles 2>/dev/null || true
dotfiles() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true
    local VAULT_DIR="$DOTFILES_DIR/vault"

    case "$cmd" in
        # Status & Health
        status|s)
            status "$@"
            ;;
        doctor|health)
            "$DOTFILES_DIR/bin/dotfiles-doctor" "$@"
            ;;
        drift)
            # Feature guard (requires drift_check)
            if type cli_require_feature &>/dev/null; then
                if ! cli_require_feature "drift_check" "drift $*" "$@"; then
                    return 1
                fi
                set -- "${CLI_FILTERED_ARGS[@]}"
            fi
            "$DOTFILES_DIR/bin/dotfiles-drift" "$@"
            ;;
        sync)
            # Feature guard (requires vault)
            if type cli_require_feature &>/dev/null; then
                if ! cli_require_feature "vault" "sync $*" "$@"; then
                    return 1
                fi
                set -- "${CLI_FILTERED_ARGS[@]}"
            fi
            "$DOTFILES_DIR/bin/dotfiles-sync" "$@"
            ;;
        diff)
            # Feature guard (requires vault)
            if type cli_require_feature &>/dev/null; then
                if ! cli_require_feature "vault" "diff $*" "$@"; then
                    return 1
                fi
                set -- "${CLI_FILTERED_ARGS[@]}"
            fi
            "$DOTFILES_DIR/bin/dotfiles-diff" "$@"
            ;;

        # macOS settings (macOS only)
        macos)
            if [[ "$(uname -s)" != "Darwin" ]]; then
                echo "macOS settings only available on macOS"
                return 1
            fi
            # Feature guard
            if type cli_require_feature &>/dev/null; then
                if ! cli_require_feature "macos_settings" "macos $*" "$@"; then
                    return 1
                fi
                set -- "${CLI_FILTERED_ARGS[@]}"
            fi
            local subcmd="${1:-help}"
            shift 2>/dev/null || true
            case "$subcmd" in
                apply)
                    "$DOTFILES_DIR/macos/apply-settings.sh" "$@"
                    ;;
                preview|dry-run)
                    "$DOTFILES_DIR/macos/apply-settings.sh" --dry-run
                    ;;
                discover)
                    "$DOTFILES_DIR/macos/discover-settings.sh" "$@"
                    ;;
                help|--help|-h|"")
                    echo ""
                    echo -e "${BOLD}${CYAN}dotfiles macos${NC} - ${DIM}macOS system settings${NC}"
                    echo ""
                    echo -e "${BOLD}Usage:${NC} dotfiles macos <command>"
                    echo ""
                    echo -e "${BOLD}${CYAN}Commands:${NC}"
                    echo -e "  ${YELLOW}apply${NC}       ${DIM}Apply settings from settings.sh${NC}"
                    echo -e "  ${YELLOW}preview${NC}     ${DIM}Show settings that would be applied (dry-run)${NC}"
                    echo -e "  ${YELLOW}discover${NC}    ${DIM}Discover/capture current macOS settings${NC}"
                    echo ""
                    echo -e "${BOLD}Examples:${NC}"
                    echo -e "  dotfiles macos preview    ${DIM}# See what would change${NC}"
                    echo -e "  dotfiles macos apply      ${DIM}# Apply settings${NC}"
                    echo ""
                    ;;
                *)
                    echo -e "${RED}Unknown macos command:${NC} $subcmd"
                    echo -e "Run ${CYAN}dotfiles macos help${NC} for usage"
                    return 1
                    ;;
            esac
            ;;

        # Vault operations
        vault)
            # Feature guard (allow --force to bypass, filters out --force from args)
            if type cli_require_feature &>/dev/null; then
                if ! cli_require_feature "vault" "vault $*" "$@"; then
                    return 1
                fi
                # Use filtered args (--force removed)
                set -- "${CLI_FILTERED_ARGS[@]}"
            fi
            local subcmd="${1:-help}"
            shift 2>/dev/null || true
            case "$subcmd" in
                # v3.0 commands
                setup)
                    "$VAULT_DIR/init-vault.sh" "$@"
                    ;;
                scan)
                    "$VAULT_DIR/discover-secrets.sh" "$@"
                    ;;
                pull)
                    "$VAULT_DIR/restore.sh" "$@"
                    ;;
                push)
                    "$VAULT_DIR/sync-to-vault.sh" "$@"
                    ;;
                sync)
                    "$DOTFILES_DIR/bin/dotfiles-sync" "$@"
                    ;;
                status)
                    "$VAULT_DIR/status.sh" "$@"
                    ;;

                # Management commands
                list)
                    "$VAULT_DIR/list-vault-items.sh" "$@"
                    ;;
                check)
                    "$VAULT_DIR/check-vault-items.sh" "$@"
                    ;;
                validate)
                    "$VAULT_DIR/validate-config.sh" "$@"
                    ;;
                create)
                    "$VAULT_DIR/create-vault-item.sh" "$@"
                    ;;
                delete)
                    "$VAULT_DIR/delete-vault-item.sh" "$@"
                    ;;
                # Session management (delegates to dotfiles-vault)
                unlock)
                    "$DOTFILES_DIR/bin/dotfiles-vault" unlock "$@"
                    ;;
                lock)
                    "$DOTFILES_DIR/bin/dotfiles-vault" lock "$@"
                    ;;
                quick)
                    "$DOTFILES_DIR/bin/dotfiles-vault" quick "$@"
                    ;;
                backend)
                    "$DOTFILES_DIR/bin/dotfiles-vault" backend "$@"
                    ;;

                help|--help|-h|"")
                    echo "${BOLD}${CYAN}dotfiles vault${NC} - Secret vault operations"
                    echo ""
                    echo "${BOLD}Usage:${NC} dotfiles vault <command> [options]"
                    echo ""
                    echo "${BOLD}Session:${NC}"
                    echo "  ${GREEN}unlock${NC}           Unlock vault and cache session"
                    echo "  ${GREEN}lock${NC}             Lock vault (clear cached session)"
                    echo "  ${GREEN}quick${NC}            Quick status check (login/unlock only)"
                    echo "  ${GREEN}backend${NC}          Show or set vault backend"
                    echo ""
                    echo "${BOLD}Setup & Sync:${NC}"
                    echo "  ${GREEN}setup${NC}            Setup vault backend (first-time setup)"
                    echo "  ${GREEN}scan${NC}             Re-scan for new secrets (updates config)"
                    echo "                   ${DIM}--dry-run: Preview without saving${NC}"
                    echo "  ${GREEN}pull${NC}             Pull secrets FROM vault to local machine"
                    echo "                   ${DIM}--force: Skip drift check, overwrite local${NC}"
                    echo "  ${GREEN}push${NC} [item]      Push secrets TO vault"
                    echo "                   ${DIM}--all: Push all items${NC}"
                    echo "  ${GREEN}sync${NC}             Bidirectional sync (smart push/pull)"
                    echo "                   ${DIM}--force-local: Push all local to vault${NC}"
                    echo "                   ${DIM}--force-vault: Pull all vault to local${NC}"
                    echo "  ${GREEN}status${NC}           Show vault sync status with drift detection"
                    echo ""
                    echo "${BOLD}Management:${NC}"
                    echo "  list             List all vault items"
                    echo "  check            Validate vault items exist"
                    echo "  validate         Validate vault item schema"
                    echo "  create           Create new vault item"
                    echo "  delete           Delete vault item"
                    echo ""
                    echo "${BOLD}Typical Workflow:${NC}"
                    echo "  ${DIM}First time:${NC}  dotfiles vault setup ${DIM}→ Choose backend & discover secrets${NC}"
                    echo "  ${DIM}Unlock:${NC}      dotfiles vault unlock ${DIM}→ Unlock vault for operations${NC}"
                    echo "  ${DIM}Add secrets:${NC} dotfiles vault push  ${DIM}→ Push local changes to vault${NC}"
                    echo "  ${DIM}New machine:${NC} dotfiles vault pull  ${DIM}→ Pull secrets from vault${NC}"
                    echo "  ${DIM}Re-scan:${NC}     dotfiles vault scan  ${DIM}→ Find new SSH keys/configs${NC}"
                    echo ""
                    echo "${BOLD}Examples:${NC}"
                    echo "  dotfiles vault unlock         # Unlock vault"
                    echo "  dotfiles vault status         # Full status with drift"
                    echo "  dotfiles vault pull           # Pull all secrets"
                    echo "  dotfiles vault push --all     # Push all to vault"
                    echo ""
                    echo "${DIM}Backup/restore: ${GREEN}dotfiles backup --help${NC}"
                    ;;
                *)
                    echo "${RED}Unknown vault command:${NC} $subcmd"
                    echo "Run ${CYAN}dotfiles vault help${NC} for usage"
                    return 1
                    ;;
            esac
            ;;

        # Secrets (alias for vault)
        secrets)
            # Alias for vault commands with clearer terminology
            dotfiles vault "$@"
            ;;

        # Template system
        template|tmpl)
            # Feature guard
            if type cli_require_feature &>/dev/null; then
                if ! cli_require_feature "templates" "template $*" "$@"; then
                    return 1
                fi
                set -- "${CLI_FILTERED_ARGS[@]}"
            fi
            local subcmd="${1:-help}"
            shift 2>/dev/null || true
            case "$subcmd" in
                # Core commands
                init)
                    "$DOTFILES_DIR/bin/dotfiles-template" init "$@"
                    ;;
                render)
                    "$DOTFILES_DIR/bin/dotfiles-template" render "$@"
                    ;;
                link)
                    "$DOTFILES_DIR/bin/dotfiles-template" link "$@"
                    ;;
                diff)
                    "$DOTFILES_DIR/bin/dotfiles-template" diff "$@"
                    ;;
                check|validate)
                    "$DOTFILES_DIR/bin/dotfiles-template" check "$@"
                    ;;

                # Variable management
                vars)
                    "$DOTFILES_DIR/bin/dotfiles-template" vars "$@"
                    ;;
                edit)
                    "$DOTFILES_DIR/bin/dotfiles-template" edit "$@"
                    ;;
                arrays)
                    "$DOTFILES_DIR/bin/dotfiles-template" arrays "$@"
                    ;;

                # Utility
                list)
                    "$DOTFILES_DIR/bin/dotfiles-template" list "$@"
                    ;;
                help|--help|-h|"")
                    echo "${BOLD}${CYAN}dotfiles template${NC} - Machine-specific config management"
                    echo ""
                    echo "${BOLD}Usage:${NC} dotfiles template <command> [options]"
                    echo ""
                    echo "${BOLD}Setup & Generate:${NC}"
                    echo "  ${GREEN}init${NC}             Interactive setup (creates _variables.local.sh)"
                    echo "  ${GREEN}render${NC} [file]    Render templates → generated/"
                    echo "                   ${DIM}--dry-run: Preview without writing${NC}"
                    echo "                   ${DIM}--force: Re-render even if up to date${NC}"
                    echo "  ${GREEN}link${NC}             Create symlinks: generated/ → destinations"
                    echo "  ${GREEN}diff${NC}             Show template vs generated differences"
                    echo "  check            Validate template syntax"
                    echo ""
                    echo "${BOLD}Variables:${NC}"
                    echo "  vars             List all template variables & values"
                    echo "  edit             Open _variables.local.sh in editor"
                    echo "  arrays           Manage JSON/shell arrays for {{#each}} loops"
                    echo "                   ${DIM}--export-json: Convert shell → JSON${NC}"
                    echo "                   ${DIM}--validate: Check JSON syntax${NC}"
                    echo ""
                    echo "${BOLD}Info:${NC}"
                    echo "  list             Show available templates & status"
                    echo ""
                    echo "${BOLD}Typical Workflow:${NC}"
                    echo "  ${DIM}First time:${NC}  dotfiles template init   ${DIM}→ Set up machine variables${NC}"
                    echo "  ${DIM}Configure:${NC}   dotfiles template edit   ${DIM}→ Edit variables${NC}"
                    echo "  ${DIM}Generate:${NC}    dotfiles template render ${DIM}→ Create configs${NC}"
                    echo "  ${DIM}Deploy:${NC}      dotfiles template link   ${DIM}→ Symlink to destinations${NC}"
                    echo ""
                    echo "${BOLD}Examples:${NC}"
                    echo "  dotfiles template init                  # Interactive setup"
                    echo "  dotfiles template vars                  # See current values"
                    echo "  dotfiles template render --dry-run      # Preview generation"
                    echo "  dotfiles template render && \\           # Render & link"
                    echo "    dotfiles template link"
                    echo "  DOTFILES_TMPL_GIT_EMAIL=\"work@co.com\" \\"
                    echo "    dotfiles template render              # Override variable"
                    echo ""
                    echo "${DIM}Learn more: ${GREEN}dotfiles template --help${NC}"
                    ;;
                *)
                    echo "${RED}Unknown template command:${NC} $subcmd"
                    echo "Run ${CYAN}dotfiles template help${NC} for usage"
                    return 1
                    ;;
            esac
            ;;

        # Feature management
        features|feature|feat)
            local subcmd="${1:-}"
            "$DOTFILES_DIR/bin/dotfiles-features" "$@"
            local ret=$?
            # Auto-reload shell after enable/disable/preset to apply changes
            if [[ $ret -eq 0 && "$subcmd" =~ ^(enable|disable|preset)$ ]]; then
                echo ""
                echo "${YELLOW}Reloading shell to apply feature changes...${NC}"
                exec zsh
            fi
            return $ret
            ;;

        # Configuration layers management
        config|cfg)
            # Feature guard
            if type cli_require_feature &>/dev/null; then
                if ! cli_require_feature "config_layers" "config $*" "$@"; then
                    return 1
                fi
                set -- "${CLI_FILTERED_ARGS[@]}"
            fi
            "$DOTFILES_DIR/bin/dotfiles-config" "$@"
            ;;

        # Setup & Maintenance
        setup)
            "$DOTFILES_DIR/bin/dotfiles-setup" "$@"
            ;;
        migrate)
            "$DOTFILES_DIR/bin/dotfiles-migrate" "$@"
            ;;
        uninstall)
            "$DOTFILES_DIR/bin/dotfiles-uninstall" "$@"
            ;;
        upgrade|update)
            dotfiles-upgrade
            ;;
        lint)
            "$DOTFILES_DIR/bin/dotfiles-lint" "$@"
            ;;
        packages|pkg)
            "$DOTFILES_DIR/bin/dotfiles-packages" "$@"
            ;;
        metrics)
            # Feature guard
            if type cli_require_feature &>/dev/null; then
                if ! cli_require_feature "health_metrics" "metrics $*" "$@"; then
                    return 1
                fi
                set -- "${CLI_FILTERED_ARGS[@]}"
            fi
            "$DOTFILES_DIR/bin/dotfiles-metrics" "$@"
            ;;

        # Backup & Rollback (v3.0 top-level commands)
        backup)
            # Feature guard
            if type cli_require_feature &>/dev/null; then
                if ! cli_require_feature "backup_auto" "backup $*" "$@"; then
                    return 1
                fi
                set -- "${CLI_FILTERED_ARGS[@]}"
            fi
            local backup_cmd="${1:-help}"
            case "$backup_cmd" in
                create|list|restore|clean|help|--help|-h|"")
                    "$DOTFILES_DIR/bin/dotfiles-backup" "$@"
                    ;;
                *)
                    # Default: create backup
                    "$DOTFILES_DIR/bin/dotfiles-backup" create "$@"
                    ;;
            esac
            ;;
        rollback)
            # Feature guard (same as backup)
            if type cli_require_feature &>/dev/null; then
                if ! cli_require_feature "backup_auto" "rollback $*" "$@"; then
                    return 1
                fi
                set -- "${CLI_FILTERED_ARGS[@]}"
            fi
            # Quick rollback to last backup
            local backup_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/backups"
            if [[ ! -d "$backup_dir" ]]; then
                echo "${RED}[ERROR]${NC} No backups found at: $backup_dir"
                echo "${CYAN}[INFO]${NC} Create a backup first: ${GREEN}dotfiles backup${NC}"
                return 1
            fi

            local latest_backup=$(ls -t "$backup_dir" 2>/dev/null | head -1)
            if [[ -z "$latest_backup" ]]; then
                echo "${RED}[ERROR]${NC} No backups found in: $backup_dir"
                echo "${CYAN}[INFO]${NC} Create a backup first: ${GREEN}dotfiles backup${NC}"
                return 1
            fi

            # Check if --to flag specified
            if [[ "$1" == "--to" && -n "$2" ]]; then
                latest_backup="$2"
                if [[ ! -d "$backup_dir/$latest_backup" ]]; then
                    echo "${RED}[ERROR]${NC} Backup not found: $latest_backup"
                    echo ""
                    echo "Available backups:"
                    ls -t "$backup_dir" 2>/dev/null | head -5
                    return 1
                fi
            fi

            echo "${CYAN}[INFO]${NC} Rolling back to: $latest_backup"
            "$DOTFILES_DIR/bin/dotfiles-backup" restore "$latest_backup"
            ;;

        cd)
            cd "$DOTFILES_DIR"
            ;;
        edit)
            ${EDITOR:-vim} "$DOTFILES_DIR"
            ;;

        # Help
        help|--help|-h)
            _dotfiles_help "$@"
            ;;
        *)
            echo -e "${RED}Unknown command:${NC} $cmd"
            echo -e "Run ${CYAN}dotfiles help${NC} for usage"
            return 1
            ;;
    esac
}

# Short alias for dotfiles command
alias d=dotfiles
