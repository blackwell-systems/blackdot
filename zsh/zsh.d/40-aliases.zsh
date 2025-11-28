# =========================
# 40-aliases.zsh
# =========================
# Shell aliases for navigation, bitwarden, dotfiles, and utilities
# Convenient shortcuts for common operations

# Convenience navigation aliases
alias cws='cd "$WORKSPACE"'
alias ccode='cd "$WORKSPACE/code"'
alias cwhite='cd "$WORKSPACE/whitepapers"'
alias cpat='cd "$WORKSPACE/patent-pool"'

# Bitwarden vault helpers
alias bw-restore='$HOME/workspace/dotfiles/vault/bootstrap-vault.sh'
alias bw-sync='$HOME/workspace/dotfiles/vault/sync-to-bitwarden.sh'
alias bw-create='$HOME/workspace/dotfiles/vault/create-vault-item.sh'
alias bw-validate='$HOME/workspace/dotfiles/vault/validate-schema.sh'
alias bw-delete='$HOME/workspace/dotfiles/vault/delete-vault-item.sh'
alias bw-list='$HOME/workspace/dotfiles/vault/list-vault-items.sh'
alias bw-check='$HOME/workspace/dotfiles/vault/check-vault-items.sh'

# Dotfiles management helpers
alias dotfiles-cd='cd $HOME/workspace/dotfiles'

# Unified dotfiles command with subcommands
dotfiles() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true

    case "$cmd" in
        doctor|health|check)
            "$HOME/workspace/dotfiles/dotfiles-doctor.sh" "$@"
            ;;
        upgrade|update)
            dotfiles-upgrade
            ;;
        cd)
            cd "$HOME/workspace/dotfiles"
            ;;
        edit)
            ${EDITOR:-vim} "$HOME/workspace/dotfiles"
            ;;
        help|--help|-h)
            echo "dotfiles - Manage your dotfiles"
            echo ""
            echo "Usage: dotfiles <command> [options]"
            echo ""
            echo "Commands:"
            echo "  doctor, health    Run comprehensive health check"
            echo "  upgrade, update   Pull latest and run bootstrap"
            echo "  cd                Change to dotfiles directory"
            echo "  edit              Open dotfiles in editor"
            echo "  help              Show this help"
            echo ""
            echo "Examples:"
            echo "  dotfiles doctor          # Run health check"
            echo "  dotfiles doctor --fix    # Auto-fix permissions"
            echo "  dotfiles upgrade         # Update dotfiles"
            ;;
        *)
            echo "Unknown command: $cmd"
            echo "Run 'dotfiles help' for usage"
            return 1
            ;;
    esac
}
