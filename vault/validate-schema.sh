#!/usr/bin/env zsh
# ============================================================
# FILE: vault/validate-schema.sh
# Validates Bitwarden vault items have correct schema
# ============================================================
set -euo pipefail

# Source common functions
source "$(dirname "$0")/_common.sh"

# Prerequisites
require_bw
require_jq
require_logged_in

# Get session
SESSION=$(get_session)
sync_vault "$SESSION"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Bitwarden Vault Schema Validation"
echo "════════════════════════════════════════════════════════════"
echo ""

# Run validation
if validate_all_items "$SESSION"; then
    echo ""
    echo "════════════════════════════════════════════════════════════"
    pass "✓ All vault items passed validation"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    exit 0
else
    echo ""
    echo "════════════════════════════════════════════════════════════"
    fail "✗ Vault validation failed"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Common issues:"
    echo "  • Item missing from vault"
    echo "  • Item has empty notes field"
    echo "  • SSH key missing private/public key blocks"
    echo "  • Item is wrong type (should be Secure Note)"
    echo ""
    echo "To fix:"
    echo "  1. Create missing items: vault/create-vault-item.sh"
    echo "  2. Sync local changes: vault/sync-to-bitwarden.sh"
    echo "  3. Verify item structure in Bitwarden web vault"
    echo ""
    exit 1
fi
