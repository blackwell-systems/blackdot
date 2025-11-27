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
alias dotfiles='cd $HOME/workspace/dotfiles'
alias dotfiles-doctor='$HOME/workspace/dotfiles/check-health.sh && bw-check 2>/dev/null'
