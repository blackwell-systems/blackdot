#!/usr/bin/env bash
# ============================================================
# Example Hook: pre_template_render/10-decrypt-secrets.sh
# Auto-decrypts .age files in templates directory before rendering
#
# This hook runs before 'blackdot template render' to ensure
# encrypted template variables and arrays are decrypted.
#
# Installation:
#   mkdir -p ~/.config/blackdot/hooks/pre_template_render
#   cp this_file ~/.config/blackdot/hooks/pre_template_render/
#   chmod +x ~/.config/blackdot/hooks/pre_template_render/10-decrypt-secrets.sh
#
# What it does:
#   - Decrypts templates/_variables.local.sh.age if present
#   - Decrypts templates/_arrays.local.json.age if present
#   - Only decrypts if age key is available
# ============================================================

set -euo pipefail

BLACKDOT_DIR="${BLACKDOT_DIR:-$HOME/workspace/blackdot}"
TEMPLATES_DIR="$BLACKDOT_DIR/templates"
ENCRYPTION_DIR="${HOME}/.config/blackdot"
AGE_KEY_FILE="${ENCRYPTION_DIR}/age-key.txt"

# Skip if encryption not initialized
if [[ ! -f "$AGE_KEY_FILE" ]]; then
    exit 0
fi

# Skip if age not installed
if ! command -v age >/dev/null 2>&1; then
    exit 0
fi

# Source encryption library if available
if [[ -f "$BLACKDOT_DIR/lib/_encryption.sh" ]]; then
    source "$BLACKDOT_DIR/lib/_encryption.sh"
    encryption_hook_pre_template
    exit 0
fi

# Fallback: manual decryption
for encrypted_file in "$TEMPLATES_DIR"/*.age; do
    [[ -f "$encrypted_file" ]] || continue

    decrypted_file="${encrypted_file%.age}"

    # Only decrypt if encrypted file is newer or decrypted doesn't exist
    if [[ ! -f "$decrypted_file" ]] || [[ "$encrypted_file" -nt "$decrypted_file" ]]; then
        echo "[hook] Decrypting: $(basename "$encrypted_file")"
        age -d -i "$AGE_KEY_FILE" -o "$decrypted_file" "$encrypted_file"
    fi
done

exit 0
