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
    local VAULT_DIR="$HOME/workspace/dotfiles/vault"

    case "$cmd" in
        # Status & Health
        status|s)
            status "$@"
            ;;
        doctor|health)
            "$HOME/workspace/dotfiles/bin/dotfiles-doctor" "$@"
            ;;
        drift)
            "$HOME/workspace/dotfiles/bin/dotfiles-drift"
            ;;
        diff)
            "$HOME/workspace/dotfiles/bin/dotfiles-diff" "$@"
            ;;
        backup)
            "$HOME/workspace/dotfiles/bin/dotfiles-backup" "$@"
            ;;

        # Vault operations
        vault)
            local subcmd="${1:-help}"
            shift 2>/dev/null || true
            case "$subcmd" in
                restore)
                    "$VAULT_DIR/bootstrap-vault.sh" "$@"
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
                    echo "  restore          Restore all secrets from vault"
                    echo "                   --force: Skip drift check, overwrite local changes"
                    echo "  sync [item]      Sync local files to vault (--all for all)"
                    echo "  list             List vault items"
                    echo "  check            Validate vault items exist"
                    echo "  validate         Validate vault item schema"
                    echo "  create           Create new vault item"
                    echo "  delete           Delete vault item"
                    echo ""
                    echo "Examples:"
                    echo "  dotfiles vault restore        # Restore all secrets"
                    echo "  dotfiles vault sync --all     # Sync all to vault"
                    echo "  dotfiles vault sync Git-Config"
                    ;;
                *)
                    echo "Unknown vault command: $subcmd"
                    echo "Run 'dotfiles vault help' for usage"
                    return 1
                    ;;
            esac
            ;;

        # Setup & Maintenance
        init)
            "$HOME/workspace/dotfiles/bin/dotfiles-init" "$@"
            ;;
        uninstall)
            "$HOME/workspace/dotfiles/bin/dotfiles-uninstall" "$@"
            ;;
        upgrade|update)
            dotfiles-upgrade
            ;;
        lint)
            "$HOME/workspace/dotfiles/bin/dotfiles-lint" "$@"
            ;;
        packages|pkg)
            "$HOME/workspace/dotfiles/bin/dotfiles-packages" "$@"
            ;;
        template|tmpl)
            "$HOME/workspace/dotfiles/bin/dotfiles-template" "$@"
            ;;
        metrics)
            "$HOME/workspace/dotfiles/bin/dotfiles-metrics" "$@"
            ;;
        cd)
            cd "$HOME/workspace/dotfiles"
            ;;
        edit)
            ${EDITOR:-vim} "$HOME/workspace/dotfiles"
            ;;

        # Help
        help|--help|-h)
            echo "dotfiles - Manage your dotfiles"
            echo ""
            echo "Usage: dotfiles <command> [options]"
            echo ""
            echo "Commands:"
            echo "  status, s         Quick visual dashboard"
            echo "  doctor, health    Run comprehensive health check"
            echo "  drift             Compare local files vs vault"
            echo "  diff              Preview changes before sync/restore"
            echo "  backup            Backup and restore configuration"
            echo "  vault <cmd>       Secret vault operations (restore, sync, list...)"
            echo "  template, tmpl    Machine-specific config templates"
            echo "  lint              Validate shell config syntax"
            echo "  packages, pkg     Check/install Brewfile packages"
            echo "  metrics           Visualize health check metrics over time"
            echo "  init              First-time setup wizard"
            echo "  upgrade, update   Pull latest and run bootstrap"
            echo "  uninstall         Remove dotfiles configuration"
            echo "  cd                Change to dotfiles directory"
            echo "  edit              Open dotfiles in editor"
            echo "  help              Show this help"
            echo ""
            echo "Examples:"
            echo "  dotfiles status              # Visual dashboard"
            echo "  dotfiles doctor --fix        # Health check with auto-fix"
            echo "  dotfiles lint --fix          # Check syntax, fix permissions"
            echo "  dotfiles packages --check    # Show missing packages"
            echo "  dotfiles packages --install  # Install from Brewfile"
            echo "  dotfiles template init       # Setup machine-specific config"
            echo "  dotfiles template render     # Generate configs from templates"
            echo "  dotfiles vault restore       # Restore secrets from vault"
            echo "  dotfiles vault sync --all    # Sync local to vault"
            ;;
        *)
            echo "Unknown command: $cmd"
            echo "Run 'dotfiles help' for usage"
            return 1
            ;;
    esac
}
