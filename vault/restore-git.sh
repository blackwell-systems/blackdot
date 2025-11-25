#!/usr/bin/env bash
# ============================================================
# FILE: vault/restore-git.sh
# Restores Git config from Bitwarden Secure Note
# ============================================================
set -euo pipefail

# Accept session from argument or environment variable
SESSION="${1:-${BW_SESSION:-}}"

if [[ -z "$SESSION" ]]; then
    echo "restore-git.sh: BW_SESSION or session argument is required." >&2
    exit 1
fi

# Verify jq is available
if ! command -v jq >/dev/null 2>&1; then
    echo "restore-git.sh: 'jq' is required but not installed." >&2
    exit 1
fi

restore_git_config() {
    local item_name="Git-Config"
    local config_path="$HOME/.gitconfig"

    echo "Restoring Git config from Bitwarden item: $item_name"

    # Fetch item from Bitwarden (graceful failure if not found)
    local json notes
    if ! json="$(bw get item "$item_name" --session "$SESSION" 2>/dev/null)"; then
        echo "  [SKIP] Item '$item_name' not found in Bitwarden."
        return 0
    fi

    # Extract notes field
    notes="$(printf '%s\n' "$json" | jq -r '.notes // ""')"
    if [[ -z "$notes" || "$notes" == "null" ]]; then
        echo "  [SKIP] Item '$item_name' has empty notes."
        return 0
    fi

    # Backup existing config if present
    if [[ -f "$config_path" ]]; then
        cp "$config_path" "${config_path}.bak-$(date +%Y%m%d%H%M%S)"
        echo "  [INFO] Backed up existing config."
    fi

    # Write the config file
    printf '%s\n' "$notes" > "$config_path"
    chmod 644 "$config_path"

    echo "  [OK] Restored: $config_path"
}

restore_git_config

echo "Git config restore complete."
