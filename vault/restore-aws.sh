#!/usr/bin/env bash
# ============================================================
# FILE: vault/restore-aws.sh
# Restores AWS config and credentials from Bitwarden Secure Notes
# ============================================================
set -euo pipefail

# Accept session from argument or environment variable
SESSION="${1:-${BW_SESSION:-}}"

if [[ -z "$SESSION" ]]; then
  echo "restore-aws.sh: BW_SESSION or session argument is required." >&2
  exit 1
fi

# Verify jq is available
if ! command -v jq >/dev/null 2>&1; then
  echo "restore-aws.sh: 'jq' is required but not installed." >&2
  exit 1
fi

AWS_DIR="$HOME/.aws"
mkdir -p "$AWS_DIR"
chmod 700 "$AWS_DIR"

restore_aws_note() {
    local item_name="$1"
    local target_path="$2"

    echo "Restoring AWS file from Bitwarden item: $item_name"

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

    # Write to target file with secure permissions
    printf '%s\n' "$notes" > "$target_path"
    chmod 600 "$target_path"

    echo "  [OK] Restored: $target_path"
}

# ============================================================
# Restore AWS configuration files
# ============================================================

# ~/.aws/config (profiles, SSO settings, regions)
restore_aws_note "AWS-Config" "$AWS_DIR/config"

# ~/.aws/credentials (access keys, session tokens)
restore_aws_note "AWS-Credentials" "$AWS_DIR/credentials"

echo "AWS restore complete."
