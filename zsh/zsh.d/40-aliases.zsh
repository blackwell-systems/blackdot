# =========================
# 40-aliases.zsh
# =========================
# Shell aliases for navigation, vault, dotfiles, and utilities
# Convenient shortcuts for common operations

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
    echo "${BOLD}Setup & Health:${NC}"
    echo "  setup             Interactive setup wizard (recommended)"
    echo "  status, s         Quick visual dashboard"
    echo "  doctor, health    Run comprehensive health check"
    echo "  lint              Validate shell config syntax"
    echo "  packages, pkg     Check/install Brewfile packages"
    echo "  upgrade, update   Pull latest and run bootstrap"
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
        echo "${BOLD}Vault Operations:${NC}${indicator}"
        echo "  vault setup       Setup vault backend (first-time setup)"
        echo "  vault pull        Pull secrets from vault"
        echo "  vault push        Push secrets to vault"
        echo "  vault sync        Bidirectional sync (smart direction)"
        echo "  vault scan        Re-scan for new secrets"
        echo "  vault list        List all vault items"
        echo "  drift             Compare local files vs vault"
        echo "  sync              Bidirectional vault sync (smart push/pull)"
        echo "  diff              Preview changes before sync/restore"
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
        echo "${BOLD}Backup & Safety:${NC}${indicator}"
        echo "  backup            Create backup of current config"
        echo "  backup list       List all backups"
        echo "  backup restore    Restore specific backup"
        echo "  rollback          Instant rollback to last backup"
        echo ""
    fi

    # Feature Management (always visible)
    echo "${BOLD}Feature Management:${NC}"
    echo "  features          List all features and status"
    echo "  features enable   Enable a feature"
    echo "  features disable  Disable a feature"
    echo "  features preset   Enable a preset (minimal/developer/claude/full)"
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
        echo "${BOLD}Configuration:${NC}${indicator}"
        echo "  config get        Get config value (with layer resolution)"
        echo "  config set        Set config value in specific layer"
        echo "  config show       Show where a config value comes from"
        echo "  config list       Show configuration layer status"
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
        echo "${BOLD}Templates:${NC}${indicator}"
        echo "  template, tmpl    Machine-specific config templates"
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
            echo "${BOLD}macOS Settings:${NC}${indicator}"
            echo "  macos <cmd>       macOS system settings"
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
        echo "${BOLD}Metrics:${NC}${indicator}"
        echo "  metrics           Visualize health check metrics over time"
        echo ""
    fi

    # Other Commands (always visible)
    echo "${BOLD}Other Commands:${NC}"
    echo "  migrate           Migrate config to v3.0 (INI→JSON, vault v2→v3)"
    echo "  uninstall         Remove dotfiles configuration"
    echo "  cd                Change to dotfiles directory"
    echo "  edit              Open dotfiles in editor"
    echo "  help              Show this help"
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
                    echo "dotfiles macos - macOS system settings"
                    echo ""
                    echo "Usage: dotfiles macos <command>"
                    echo ""
                    echo "Commands:"
                    echo "  apply       Apply settings from settings.sh"
                    echo "  preview     Show settings that would be applied (dry-run)"
                    echo "  discover    Discover/capture current macOS settings"
                    echo ""
                    echo "Examples:"
                    echo "  dotfiles macos preview    # See what would change"
                    echo "  dotfiles macos apply      # Apply settings"
                    ;;
                *)
                    echo "Unknown macos command: $subcmd"
                    echo "Run 'dotfiles macos help' for usage"
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
                help|--help|-h|"")
                    echo "${BOLD}${CYAN}dotfiles vault${NC} - Secret vault operations"
                    echo ""
                    echo "${BOLD}Usage:${NC} dotfiles vault <command> [options]"
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
                    echo "  ${GREEN}status${NC}           Show vault sync status"
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
                    echo "  ${DIM}Add secrets:${NC} dotfiles vault push  ${DIM}→ Push local changes to vault${NC}"
                    echo "  ${DIM}New machine:${NC} dotfiles vault pull  ${DIM}→ Pull secrets from vault${NC}"
                    echo "  ${DIM}Re-scan:${NC}     dotfiles vault scan  ${DIM}→ Find new SSH keys/configs${NC}"
                    echo ""
                    echo "${BOLD}Examples:${NC}"
                    echo "  dotfiles vault setup          # First-time setup"
                    echo "  dotfiles vault pull           # Pull all secrets"
                    echo "  dotfiles vault push --all     # Push all to vault"
                    echo "  dotfiles vault scan           # Re-scan for new items"
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
            "$DOTFILES_DIR/bin/dotfiles-features" "$@"
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
            echo "Unknown command: $cmd"
            echo "Run 'dotfiles help' for usage"
            return 1
            ;;
    esac
}
