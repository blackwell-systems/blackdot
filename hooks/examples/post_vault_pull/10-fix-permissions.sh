#!/usr/bin/env bash
# ============================================================
# Example Hook: post_vault_pull/10-fix-permissions.sh
# Ensures correct permissions on sensitive files after vault pull
#
# Installation:
#   mkdir -p ~/.config/blackdot/hooks/post_vault_pull
#   cp this_file ~/.config/blackdot/hooks/post_vault_pull/
#   chmod +x ~/.config/blackdot/hooks/post_vault_pull/10-fix-permissions.sh
# ============================================================

# SSH directory and keys
if [[ -d "$HOME/.ssh" ]]; then
    chmod 700 "$HOME/.ssh" 2>/dev/null

    # Private keys should be 600
    for key in "$HOME"/.ssh/id_*; do
        [[ -f "$key" && ! "$key" == *.pub ]] && chmod 600 "$key" 2>/dev/null
    done

    # Public keys should be 644
    for pubkey in "$HOME"/.ssh/*.pub; do
        [[ -f "$pubkey" ]] && chmod 644 "$pubkey" 2>/dev/null
    done

    # SSH config should be 600
    [[ -f "$HOME/.ssh/config" ]] && chmod 600 "$HOME/.ssh/config" 2>/dev/null
fi

# AWS credentials
if [[ -d "$HOME/.aws" ]]; then
    chmod 700 "$HOME/.aws" 2>/dev/null
    [[ -f "$HOME/.aws/credentials" ]] && chmod 600 "$HOME/.aws/credentials" 2>/dev/null
    [[ -f "$HOME/.aws/config" ]] && chmod 600 "$HOME/.aws/config" 2>/dev/null
fi

# GPG directory
if [[ -d "$HOME/.gnupg" ]]; then
    chmod 700 "$HOME/.gnupg" 2>/dev/null
    find "$HOME/.gnupg" -type f -exec chmod 600 {} \; 2>/dev/null
fi

exit 0
