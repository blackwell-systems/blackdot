#!/usr/bin/env bash
set -euo pipefail

SESSION="${1:-${BW_SESSION:-}}"

if [[ -z "$SESSION" ]]; then
  echo "❌ restore-ssh.sh: BW_SESSION or session arg is required."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "❌ 'jq' is required."
  exit 1
fi

SSH_DIR="$HOME/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

restore_ssh_item() {
  local ITEM_NAME="$1"
  local PRIV_PATH="$2"
  local PUB_PATH="$3"

  echo "🔐 Restoring SSH keys from Bitwarden item: $ITEM_NAME"

  local JSON NOTES
  if ! JSON="$(bw get item "$ITEM_NAME" --session "$SESSION" 2>/dev/null)"; then
    echo "⚠️  Item '$ITEM_NAME' not found. Skipping."
    return 0
  fi

  NOTES="$(printf '%s\n' "$JSON" | jq -r '.notes // ""')"
  if [[ -z "$NOTES" || "$NOTES" == "null" ]]; then
    echo "⚠️  Item '$ITEM_NAME' has empty notes. Skipping."
    return 0
  fi

  # Extract private key block
  if ! printf '%s\n' "$NOTES" \
      | awk '/BEGIN OPENSSH PRIVATE KEY/{flag=1} flag{print} /END OPENSSH PRIVATE KEY/{flag=0}' \
      > "$PRIV_PATH"; then
    echo "❌ Failed to extract private key for '$ITEM_NAME'."
    return 1
  fi

  # Extract first ssh-ed25519 line as public key (if present)
  if ! printf '%s\n' "$NOTES" \
      | awk '/^ssh-ed25519 /{print; exit}' \
      > "$PUB_PATH"; then
    echo "⚠️  No ssh-ed25519 public key found in '$ITEM_NAME' notes. Leaving '$PUB_PATH' empty."
  fi

  chmod 600 "$PRIV_PATH"
  chmod 644 "$PUB_PATH" 2>/dev/null || true

  echo "✅ Restored:"
  echo "   - $PRIV_PATH"
  echo "   - $PUB_PATH"
}

# GitHub Enterprise (BWH SSO)
restore_ssh_item \
  "SSH-GitHub-Enterprise" \
  "$SSH_DIR/id_ed25519_enterprise_ghub" \
  "$SSH_DIR/id_ed25519_enterprise_ghub.pub"

# GitHub - Blackwell Systems
restore_ssh_item \
  "SSH-GitHub-Blackwell" \
  "$SSH_DIR/id_ed25519_blackwell" \
  "$SSH_DIR/id_ed25519_blackwell.pub"

echo "🔑 SSH restore complete."

