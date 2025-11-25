#!/usr/bin/env bash
# ============================================================
# FILE: vault/bootstrap-vault.sh
# Orchestrates Bitwarden-based restoration of secrets
# ============================================================
set -euo pipefail

# Dynamically determine script location
VAULT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_FILE="$VAULT_DIR/.bw-session"

echo "=== Bitwarden vault bootstrap starting ==="
echo "Vault directory: $VAULT_DIR"

# Verify Bitwarden CLI is available
if ! command -v bw >/dev/null 2>&1; then
    echo "ERROR: Bitwarden CLI (bw) is not installed." >&2
    echo "Install with: brew install bitwarden-cli" >&2
    exit 1
fi

# Check if logged in to Bitwarden
if ! bw login --check >/dev/null 2>&1; then
    echo "ERROR: Not logged in to Bitwarden." >&2
    echo "Please run: bw login" >&2
    exit 1
fi

# ============================================================
# Unlock Bitwarden and get session
# ============================================================
SESSION=""

# Try to reuse existing session file
if [[ -f "$SESSION_FILE" ]]; then
    SESSION="$(cat "$SESSION_FILE")"
    if ! bw unlock --check --session "$SESSION" >/dev/null 2>&1; then
        echo "Cached session expired, re-unlocking..."
        rm -f "$SESSION_FILE"
        SESSION=""
    else
        echo "Reusing cached Bitwarden session."
    fi
fi

# Unlock if we don't have a valid session
if [[ -z "$SESSION" ]]; then
    echo "Unlocking Bitwarden vault..."
    SESSION="$(bw unlock --raw)"

    # Write session file with secure permissions (atomic)
    (umask 077 && printf '%s' "$SESSION" > "$SESSION_FILE")

    echo "Vault unlocked and session cached."
fi

# Sync to ensure we have latest data
echo "Syncing Bitwarden vault..."
bw sync --session "$SESSION" >/dev/null

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
