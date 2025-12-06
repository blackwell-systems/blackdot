#!/usr/bin/env bash
# ============================================================
# Example Hook: post_vault_pull/30-restore-age-key.sh
# Restores age encryption key from vault after vault pull
#
# This hook runs after 'dotfiles vault pull' to restore your
# encryption private key from vault if it's missing locally.
#
# Installation:
#   mkdir -p ~/.config/dotfiles/hooks/post_vault_pull
#   cp this_file ~/.config/dotfiles/hooks/post_vault_pull/
#   chmod +x ~/.config/dotfiles/hooks/post_vault_pull/30-restore-age-key.sh
#
# Prerequisites:
#   - Age key must be stored in vault as "Age-Private-Key" item
#   - Push key first with: dotfiles encrypt push-key
# ============================================================

set -euo pipefail

ENCRYPTION_DIR="${HOME}/.config/dotfiles"
AGE_KEY_FILE="${ENCRYPTION_DIR}/age-key.txt"
AGE_RECIPIENTS_FILE="${ENCRYPTION_DIR}/age-recipients.txt"
VAULT_ITEM="Age-Private-Key"

# Skip if key already exists
if [[ -f "$AGE_KEY_FILE" ]]; then
    exit 0
fi

# Check if encryption library is available
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/workspace/dotfiles}"
if [[ -f "$DOTFILES_DIR/lib/_encryption.sh" ]]; then
    source "$DOTFILES_DIR/lib/_encryption.sh"

    # Try to restore from vault
    if encryption_hook_post_vault_pull 2>/dev/null; then
        echo "[hook] Restored age encryption key from vault"
    fi
fi

exit 0
