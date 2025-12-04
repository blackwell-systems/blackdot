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
                    "$HOME/workspace/dotfiles/macos/apply-settings.sh" "$@"
                    ;;
                preview|dry-run)
                    "$HOME/workspace/dotfiles/macos/apply-settings.sh" --dry-run
                    ;;
                discover)
                    "$HOME/workspace/dotfiles/macos/discover-settings.sh" "$@"
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
                    echo "  init             Configure vault backend (run anytime)"
                    echo "  discover         Auto-detect secrets in standard locations"
                    echo "                   --dry-run: Preview without creating config"
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
                    echo "  dotfiles vault init           # Configure/reconfigure vault"
                    echo "  dotfiles vault discover       # Auto-find SSH keys, AWS, Git"
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

        # Secrets (alias for vault)
        secrets)
            # Alias for vault commands with clearer terminology
            dotfiles vault "$@"
            ;;

        # Setup & Maintenance
        setup)
            "$HOME/workspace/dotfiles/bin/dotfiles-setup" "$@"
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
