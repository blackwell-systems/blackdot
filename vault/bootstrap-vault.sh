#!/usr/bin/env zsh
# ============================================================
# FILE: vault/bootstrap-vault.sh
# Orchestrates Bitwarden-based restoration of secrets
# ============================================================
set -euo pipefail

# Source common functions
source "$(dirname "$0")/_common.sh"

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
