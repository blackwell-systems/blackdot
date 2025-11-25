#!/usr/bin/env bash
set -euo pipefail

SESSION="$1"
SSH_DIR="$HOME/.ssh"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

restore_key_note() {
    local item_name="$1"
    local priv_path="$2"
    local pub_path="$3"

    echo "🔐 Restoring $item_name ->"
    echo "    private: $priv_path"
    echo "    public : $pub_path"

    # Grab the notes block into a temp file
    local tmp
    tmp="$(mktemp)"
    bw get item "$item_name" --session "$SESSION" | jq -r '.notes' > "$tmp"

    # Split on the first blank line:
    # - everything before the blank line  => private key
    # - everything after                 => public key
    awk '
      BEGIN { out = "priv" }
      /^$/  { out = "pub"; next }
      {
        if (out == "priv") print > priv;
        else               print > pub;
      }
    ' priv="$priv_path" pub="$pub_path" "$tmp"

    rm -f "$tmp"

    chmod 600 "$priv_path"
    chmod 644 "$pub_path"

    echo "✅ $item_name restored."
    echo
}

# Matches your ~/.ssh/config:
#   Host github-sso      -> id_ed25519_enterprise_ghub
#   Host github-blackwell -> id_ed25519_blackwell

restore_key_note \
  "SSH-GitHub-Enterprise" \
  "$SSH_DIR/id_ed25519_enterprise_ghub" \
  "$SSH_DIR/id_ed25519_enterprise_ghub.pub"

restore_key_note \
  "SSH-GitHub-Blackwell" \
  "$SSH_DIR/id_ed25519_blackwell" \
  "$SSH_DIR/id_ed25519_blackwell.pub"

echo "🎉 SSH key restore complete."

