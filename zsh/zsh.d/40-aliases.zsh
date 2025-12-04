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
                init)
                    "$VAULT_DIR/init-vault.sh" "$@"
                    ;;
                discover)
                    "$VAULT_DIR/discover-secrets.sh" "$@"
                    ;;
                restore)
                    "$VAULT_DIR/restore.sh" "$@"
                    ;;
                backup)
                    "$DOTFILES_DIR/bin/dotfiles-backup" "$@"
                    ;;
                sync)
                    "$VAULT_DIR/sync-to-vault.sh" "$@"
                    ;;
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
                    echo "dotfiles vault - Secret vault operations"
                    echo ""
                    echo "Usage: dotfiles vault <command> [options]"
                    echo ""
                    echo "Commands:"
                    echo "  ${GREEN}init${NC}             ${DIM}Setup vault backend (includes auto-discovery)${NC}"
                    echo "  ${CYAN}discover${NC}         ${DIM}Re-scan for new secrets (updates existing config)${NC}"
                    echo "                   --dry-run: Preview without saving"
                    echo "  restore          Restore all secrets from vault"
                    echo "                   --force: Skip drift check, overwrite local"
                    echo "  backup           Create backup of current secrets (auto before restore)"
                    echo "  sync [item]      Sync local files to vault (--all for all)"
                    echo "  list             List vault items"
                    echo "  check            Validate vault items exist"
                    echo "  validate         Validate vault item schema"
                    echo "  create           Create new vault item"
                    echo "  delete           Delete vault item"
                    echo ""
                    echo "Workflow:"
                    echo "  ${DIM}First time:${NC}  dotfiles vault init     ${DIM}→ Choose backend & discover secrets${NC}"
                    echo "  ${DIM}Add secrets:${NC} dotfiles vault sync     ${DIM}→ Push local changes to vault${NC}"
                    echo "  ${DIM}New machine:${NC} dotfiles vault restore  ${DIM}→ Pull secrets from vault${NC}"
                    echo "  ${DIM}Re-scan:${NC}     dotfiles vault discover ${DIM}→ Find new SSH keys/configs${NC}"
                    echo ""
                    echo "Examples:"
                    echo "  dotfiles vault init           # First-time setup (recommended)"
                    echo "  dotfiles vault restore        # Restore all secrets"
                    echo "  dotfiles vault sync --all     # Sync all to vault"
                    echo "  dotfiles vault discover       # Re-scan for new items"
                    ;;
                *)
                    echo "Unknown vault command: $subcmd"
                    echo "Run 'dotfiles vault help' for usage"
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
        cd)
            cd "$DOTFILES_DIR"
            ;;
        edit)
            ${EDITOR:-vim} "$DOTFILES_DIR"
            ;;

        # Help
        help|--help|-h)
            echo "dotfiles - Manage your dotfiles"
            echo ""
            echo "Usage: dotfiles <command> [options]"
            echo ""
            echo "Commands:"
            echo "  setup             Interactive setup wizard (recommended)"
            echo "  status, s         Quick visual dashboard"
            echo "  doctor, health    Run comprehensive health check"
            echo "  drift             Compare local files vs vault"
            echo "  diff              Preview changes before sync/restore"
            echo "  backup            Backup and restore configuration"
            echo "  vault <cmd>       Secret vault operations (restore, sync, list...)"
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
            echo "Run 'dotfiles <command> --help' for detailed options."
            echo ""
            echo "Examples:"
            echo "  dotfiles setup               # Interactive setup wizard"
            echo "  dotfiles setup --status      # Show setup progress"
            echo "  dotfiles status              # Visual dashboard"
            echo "  dotfiles doctor --fix        # Health check with auto-fix"
            echo "  dotfiles vault restore       # Restore secrets from vault"
            echo "  dotfiles secrets sync --all  # Sync local to vault"
            ;;
        *)
            echo "Unknown command: $cmd"
            echo "Run 'dotfiles help' for usage"
            return 1
            ;;
    esac
}
