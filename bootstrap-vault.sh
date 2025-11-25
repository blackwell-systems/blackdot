#!/usr/bin/env bash
set -euo pipefail

# Bitwarden vault bootstrap: restores SSH, AWS, and env secrets
# from Bitwarden Secure Note items.
#
# Expected Bitwarden items (type: Secure Note):
#   - SSH-GitHub-Enterprise
#   - SSH-GitHub-Blackwell
#   - AWS-Config
#   - AWS-Credentials
#   - Environment-Secrets   (optional)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_DIR="$SCRIPT_DIR"

echo "🔐 Bitwarden bootstrap starting..."

# --- Ensure Bitwarden CLI and jq exist ---------------------------------
if ! command -v bw >/dev/null 2>&1; then
  echo "❌ 'bw' (Bitwarden CLI) not found. Install it first."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "❌ 'jq' not found. Install it (brew install jq)."
  exit 1
fi

# --- Get / ensure BW_SESSION -------------------------------------------
if [[ -z "${BW_SESSION:-}" ]]; then
  echo "🔓 Unlocking Bitwarden..."
  export BW_SESSION="$(bw unlock --raw)"
else
  echo "🔓 Using existing BW_SESSION."
fi

# Sanity check
if ! bw status --session "$BW_SESSION" | grep -q '"status": "unlocked"'; then
  echo "❌ Bitwarden vault is not unlocked (BW_SESSION invalid)."
  exit 1
fi

# --- Run restore steps --------------------------------------------------
"$VAULT_DIR/restore-ssh.sh" "$BW_SESSION"
"$VAULT_DIR/restore-aws.sh" "$BW_SESSION"
"$VAULT_DIR/restore-env.sh" "$BW_SESSION" || true

echo "🎉 Bitwarden bootstrap complete."
echo "   SSH keys, AWS config/credentials, and env secrets (if present) restored."

