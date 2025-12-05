#!/usr/bin/env bash
# ============================================================
# Example Hook: post_vault_pull/20-ssh-add.sh
# Adds SSH keys to the agent after vault pull
#
# Installation:
#   mkdir -p ~/.config/dotfiles/hooks/post_vault_pull
#   cp this_file ~/.config/dotfiles/hooks/post_vault_pull/
#   chmod +x ~/.config/dotfiles/hooks/post_vault_pull/20-ssh-add.sh
#
# Note: Runs after 10-fix-permissions.sh (alphabetical order)
# ============================================================

# Start ssh-agent if not running
if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
    eval "$(ssh-agent -s)" >/dev/null 2>&1
fi

# Add keys to agent (common key names)
for key in "$HOME"/.ssh/id_ed25519 "$HOME"/.ssh/id_rsa "$HOME"/.ssh/id_ecdsa; do
    if [[ -f "$key" ]]; then
        # Add key silently (will prompt for passphrase if needed)
        ssh-add "$key" 2>/dev/null || true
    fi
done

exit 0
