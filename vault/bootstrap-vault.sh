#!/usr/bin/env zsh
# ============================================================
# FILE: vault/bootstrap-vault.sh
# Orchestrates Bitwarden-based restoration of secrets
# Usage:
#   ./bootstrap-vault.sh              # Restore with drift check
#   ./bootstrap-vault.sh --force      # Restore without drift check
#   DOTFILES_OFFLINE=1 ./bootstrap-vault.sh  # Skip vault operations
# ============================================================
set -euo pipefail

# Source common functions
source "$(dirname "$0")/_common.sh"

# Parse arguments
FORCE=false
PREVIEW=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|-f)
            FORCE=true
            shift
            ;;
        --preview|--dry-run|-n)
            PREVIEW=true
            shift
            ;;
        --help|-h)
            echo "Restore secrets from Bitwarden vault"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force, -f       Skip drift check and overwrite local changes"
            echo "  --preview, -n     Show what would be restored without making changes"
            echo "  --help, -h        Show this help"
            echo ""
            echo "Environment variables:"
            echo "  DOTFILES_OFFLINE=1            Run in offline mode (skip vault operations)"
            echo "  DOTFILES_SKIP_DRIFT_CHECK=1   Skip drift check (for automation)"
            exit 0
            ;;
        *)
            fail "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ============================================================
# Offline mode - skip vault operations entirely
# ============================================================
if is_offline; then
    echo "=== Offline mode enabled ==="
    warn "DOTFILES_OFFLINE=1 - Skipping Bitwarden vault operations"
    echo ""
    echo "Vault restore skipped. Your existing local files are unchanged."
    echo ""
    echo "To restore from vault later:"
    echo "  unset DOTFILES_OFFLINE"
    echo "  dotfiles vault restore"
    exit 0
fi

echo "=== Bitwarden vault bootstrap starting ==="
echo "Vault directory: $VAULT_DIR"

# Verify prerequisites
require_bw
require_logged_in

# Get session and sync
SESSION=$(get_session)
echo "Vault unlocked and session cached."
sync_vault "$SESSION"

# ============================================================
# Pre-restore drift check (unless skipped)
# ============================================================
if ! skip_drift_check && [[ "$FORCE" != "true" ]]; then
    echo ""
    if ! check_pre_restore_drift "$SESSION" "$FORCE"; then
        echo ""
        echo "To force restore: dotfiles vault restore --force"
        exit 1
    fi
fi

# ============================================================
# Preview mode - show what would be restored
# ============================================================
if [[ "$PREVIEW" == "true" ]]; then
    echo ""
    echo "=== Preview Mode - No changes will be made ==="
    echo ""

    echo "Would restore the following:"
    echo ""

    # SSH keys
    echo "SSH Keys:"
    for key_item in "${(@k)SSH_KEYS}"; do
        local key_path="${SSH_KEYS[$key_item]}"
        if [[ -f "$key_path" ]]; then
            echo "  $key_item → $key_path (exists, would overwrite)"
        else
            echo "  $key_item → $key_path (new)"
        fi
    done
    echo ""

    # Dotfiles items
    echo "Dotfiles:"
    for item in "${(@k)DOTFILES_ITEMS}"; do
        local path="${DOTFILES_ITEMS[$item]}"
        if [[ -e "$path" ]]; then
            echo "  $item → $path (exists, would overwrite)"
        else
            echo "  $item → $path (new)"
        fi
    done
    echo ""

    echo "Run without --preview to perform restore."
    exit 0
fi

# ============================================================
# Run restoration scripts
# ============================================================
echo ""
echo "--- Restoring SSH keys ---"
"$VAULT_DIR/restore-ssh.sh" "$SESSION"

echo ""
echo "--- Restoring AWS credentials ---"
"$VAULT_DIR/restore-aws.sh" "$SESSION"

echo ""
echo "--- Restoring environment secrets ---"
"$VAULT_DIR/restore-env.sh" "$SESSION"

echo ""
echo "--- Restoring Git config ---"
"$VAULT_DIR/restore-git.sh" "$SESSION"

echo ""
echo "=== Bitwarden bootstrap complete ==="
echo "SSH keys, AWS profiles, environment secrets, and Git config are now restored."
