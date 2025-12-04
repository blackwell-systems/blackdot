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

# Unified dotfiles command with subcommands
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
            "$DOTFILES_DIR/bin/dotfiles-drift"
            ;;
        diff)
            "$DOTFILES_DIR/bin/dotfiles-diff" "$@"
            ;;
        backup)
            "$DOTFILES_DIR/bin/dotfiles-backup" "$@"
            ;;

        # macOS settings (macOS only)
        macos)
            if [[ "$(uname -s)" != "Darwin" ]]; then
                echo "macOS settings only available on macOS"
                return 1
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
                    "$VAULT_DIR/validate-schema.sh" "$@"
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
        template|tmpl)
            "$DOTFILES_DIR/bin/dotfiles-template" "$@"
            ;;
        metrics)
            "$DOTFILES_DIR/bin/dotfiles-metrics" "$@"
            ;;

        # Backup & Rollback (v3.0 top-level commands)
        backup)
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
            echo "${BOLD}${CYAN}dotfiles${NC} - Manage your dotfiles"
            echo ""
            echo "${BOLD}Usage:${NC} dotfiles <command> [options]"
            echo ""
            echo "${BOLD}Setup & Health:${NC}"
            echo "  setup             Interactive setup wizard (recommended)"
            echo "  migrate           Migrate config to v3.0 (INI→JSON, vault v2→v3)"
            echo "  status, s         Quick visual dashboard"
            echo "  doctor, health    Run comprehensive health check"
            echo "  drift             Compare local files vs vault"
            echo "  diff              Preview changes before sync/restore"
            echo ""
            echo "${BOLD}Vault Operations:${NC}"
            echo "  vault setup       Setup vault backend (first-time setup)"
            echo "  vault pull        Pull secrets from vault"
            echo "  vault push        Push secrets to vault"
            echo "  vault scan        Re-scan for new secrets"
            echo "  vault list        List all vault items"
            echo "  vault help        Show all vault commands"
            echo ""
            echo "${BOLD}Backup & Safety:${NC}"
            echo "  backup            Create backup of current config"
            echo "  backup list       List all backups"
            echo "  backup restore    Restore specific backup"
            echo "  rollback          Instant rollback to last backup"
            echo ""
            echo "${BOLD}Other Commands:${NC}"
            echo "  secrets <cmd>     Alias for vault commands"
            echo "  macos <cmd>       macOS system settings (macOS only)"
            echo "  template, tmpl    Machine-specific config templates"
            echo "  lint              Validate shell config syntax"
            echo "  packages, pkg     Check/install Brewfile packages"
            echo "  metrics           Visualize health check metrics over time"
            echo "  upgrade, update   Pull latest and run bootstrap"
            echo "  uninstall         Remove dotfiles configuration"
            echo "  cd                Change to dotfiles directory"
            echo "  edit              Open dotfiles in editor"
            echo "  help              Show this help"
            echo ""
            echo "${DIM}Run 'dotfiles <command> --help' for detailed options.${NC}"
            echo ""
            echo "${BOLD}Examples:${NC}"
            echo "  dotfiles setup                # Interactive setup wizard"
            echo "  dotfiles status               # Visual dashboard"
            echo "  dotfiles doctor --fix         # Health check with auto-fix"
            echo "  dotfiles vault pull           # Pull secrets from vault"
            echo "  dotfiles vault push --all     # Push all to vault"
            echo "  dotfiles backup               # Create backup"
            echo "  dotfiles rollback             # Rollback to last backup"
            ;;
        *)
            echo "Unknown command: $cmd"
            echo "Run 'dotfiles help' for usage"
            return 1
            ;;
    esac
}
