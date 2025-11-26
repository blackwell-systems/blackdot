#!/usr/bin/env zsh
# ============================================================
# FILE: vault/restore-ssh.sh
# Restores SSH keys and config from Bitwarden Secure Notes
# ============================================================
set -euo pipefail

# Source common functions
source "$(dirname "$0")/_common.sh"

# Accept session from argument or environment variable
SESSION="${1:-${BW_SESSION:-}}"

if [[ -z "$SESSION" ]]; then
    fail "restore-ssh.sh: BW_SESSION or session argument is required."
    exit 1
fi

# Verify jq is available
require_jq

SSH_DIR="$HOME/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

restore_key_note() {
    local item_name="$1"
    local priv_path="$2"
    local pub_path="$3"

    echo "Restoring SSH keys from Bitwarden item: $item_name"

    # Fetch item from Bitwarden (graceful failure if not found)
    local json notes
    json=$(bw_get_item "$item_name" "$SESSION")
    if [[ -z "$json" ]]; then
        echo "  [SKIP] Item '$item_name' not found in Bitwarden."
        return 0
    fi

    # Extract notes field
    notes="$(printf '%s\n' "$json" | jq -r '.notes // ""')"
    if [[ -z "$notes" || "$notes" == "null" ]]; then
        echo "  [SKIP] Item '$item_name' has empty notes."
        return 0
    fi

    # Backup existing keys if present
    if [[ -f "$priv_path" ]]; then
        cp "$priv_path" "${priv_path}.bak-$(date +%Y%m%d%H%M%S)"
        info "Backed up existing private key."
    fi
    if [[ -f "$pub_path" ]]; then
        cp "$pub_path" "${pub_path}.bak-$(date +%Y%m%d%H%M%S)"
        info "Backed up existing public key."
    fi

    # Extract private key block (BEGIN to END OPENSSH PRIVATE KEY)
    if ! printf '%s\n' "$notes" \
        | awk '/BEGIN OPENSSH PRIVATE KEY/{flag=1} flag{print} /END OPENSSH PRIVATE KEY/{flag=0}' \
        > "$priv_path"; then
        echo "  [ERROR] Failed to extract private key for '$item_name'." >&2
        return 1
    fi

    # Verify private key was extracted
    if [[ ! -s "$priv_path" ]]; then
        echo "  [ERROR] Private key file is empty for '$item_name'." >&2
        return 1
    fi

    # Extract public key line (ssh-ed25519 or ssh-rsa)
    printf '%s\n' "$notes" \
        | awk '/^ssh-(ed25519|rsa) /{print; exit}' \
        > "$pub_path"

    # Set secure permissions
    chmod 600 "$priv_path"
    chmod 644 "$pub_path" 2>/dev/null || true

    pass "Restored:"
    echo "       - $priv_path"
    echo "       - $pub_path"
}

# Restore SSH config file from Bitwarden Secure Note
restore_ssh_config() {
    local item_name="SSH-Config"
    local config_path="$SSH_DIR/config"

    echo "Restoring SSH config from Bitwarden item: $item_name"

    # Fetch item from Bitwarden (graceful failure if not found)
    local json notes
    json=$(bw_get_item "$item_name" "$SESSION")
    if [[ -z "$json" ]]; then
        echo "  [SKIP] Item '$item_name' not found in Bitwarden."
        return 0
    fi

    # Extract notes field (the entire config is stored as notes)
    notes="$(printf '%s\n' "$json" | jq -r '.notes // ""')"
    if [[ -z "$notes" || "$notes" == "null" ]]; then
        echo "  [SKIP] Item '$item_name' has empty notes."
        return 0
    fi

    # Backup existing config if present
    if [[ -f "$config_path" ]]; then
        cp "$config_path" "${config_path}.bak-$(date +%Y%m%d%H%M%S)"
        info "Backed up existing config."
    fi

    # Write the config file
    printf '%s\n' "$notes" > "$config_path"
    chmod 600 "$config_path"

    pass "Restored: $config_path"
}

# ============================================================
# Restore configured SSH identities (from SSH_KEYS in _common.sh)
# ============================================================

for item_name in "${(k)SSH_KEYS[@]}"; do
    key_path="${SSH_KEYS[$item_name]}"
    restore_key_note \
        "$item_name" \
        "$key_path" \
        "${key_path}.pub"
done

# ============================================================
# Restore SSH config
# ============================================================
restore_ssh_config

echo "SSH restore complete."
