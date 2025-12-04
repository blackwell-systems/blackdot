#!/usr/bin/env zsh
# ============================================================
# FILE: vault/validate-config.sh
# Validates vault-items.json configuration file schema
# Usage: ./validate-config.sh [path/to/vault-items.json]
# ============================================================
set -euo pipefail

# Source common functions
source "$(dirname "$0")/_common.sh"

# Source vault library
SCRIPT_DIR="$(cd "$(dirname "${0:a}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
source "$DOTFILES_DIR/lib/_vault.sh"

# Get vault-items.json path (default or from argument)
VAULT_ITEMS_FILE="${1:-$HOME/.config/dotfiles/vault-items.json}"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Vault Configuration Schema Validation"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Validating: $VAULT_ITEMS_FILE"
echo ""

# Run validation
if vault_validate_schema "$VAULT_ITEMS_FILE"; then
    echo ""
    echo "════════════════════════════════════════════════════════════"
    pass "✓ vault-items.json schema is valid"
    echo "════════════════════════════════════════════════════════════"
    echo ""

    # Show summary of configuration
    if [[ -f "$VAULT_ITEMS_FILE" ]] && command -v jq >/dev/null 2>&1; then
        local item_count=$(jq -r '.vault_items | length' "$VAULT_ITEMS_FILE" 2>/dev/null || echo "0")
        local ssh_count=$(jq -r '.ssh_keys | length' "$VAULT_ITEMS_FILE" 2>/dev/null || echo "0")
        local syncable_count=$(jq -r '.syncable_items | length' "$VAULT_ITEMS_FILE" 2>/dev/null || echo "0")

        echo "Configuration summary:"
        echo "  • $item_count vault items configured"
        echo "  • $ssh_count SSH keys configured"
        echo "  • $syncable_count syncable items configured"
        echo ""
    fi

    exit 0
else
    echo ""
    echo "════════════════════════════════════════════════════════════"
    fail "✗ vault-items.json validation failed"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "What this means:"
    echo "  Your vault-items.json file has invalid structure or missing required fields."
    echo "  This will cause vault sync operations to fail."
    echo ""
    echo "How to fix:"
    echo "  1. Review the validation errors above"
    echo "  2. Check example: $DOTFILES_DIR/vault/vault-items.example.json"
    echo "  3. Fix the JSON structure in: $VAULT_ITEMS_FILE"
    echo "  4. Re-run validation: dotfiles vault validate"
    echo ""
    echo "Common issues:"
    echo "  • Missing required fields (path, required, type)"
    echo "  • Invalid type value (must be 'file' or 'sshkey')"
    echo "  • Invalid item names (must start with capital letter)"
    echo "  • Invalid JSON syntax (run: jq . $VAULT_ITEMS_FILE)"
    echo ""
    exit 1
fi
