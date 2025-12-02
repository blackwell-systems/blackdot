#!/usr/bin/env zsh
# ============================================================
# FILE: vault/check-vault-items.sh
# Validates that all required Bitwarden items exist before restore
# Usage: ./check-vault-items.sh [--session SESSION]
# ============================================================
set -uo pipefail

# Source common functions
source "$(dirname "$0")/_common.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--session SESSION]

Validates that all required Bitwarden items exist.

Options:
  --session SESSION   Use provided session token
  -h, --help          Show this help

If no session is provided, uses BW_SESSION environment variable.
EOF
    exit 0
}

# Parse arguments
SESSION_ARG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --session)
            SESSION_ARG="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            fail "Unknown option: $1"
            usage
            ;;
    esac
done

# Check prerequisites
require_bw
require_jq

# Get session (use arg if provided, otherwise use common function)
if [[ -n "$SESSION_ARG" ]]; then
    SESSION="$SESSION_ARG"
    if ! bw unlock --check --session "$SESSION" >/dev/null 2>&1; then
        fail "Invalid session token provided"
        exit 1
    fi
else
    SESSION=$(get_session)
fi

# Sync vault
sync_vault "$SESSION"

# Get all item names
info "Fetching item list..."
ALL_ITEMS=$(bw list items --session "$SESSION" 2>/dev/null | jq -r '.[].name')

# Build required/optional lists from DOTFILES_ITEMS
REQUIRED_ITEMS=()
OPTIONAL_ITEMS=()
for item in "${(@k)DOTFILES_ITEMS}"; do
    spec="${DOTFILES_ITEMS[$item]}"
    if [[ "$spec" == *":required:"* ]]; then
        REQUIRED_ITEMS+=("$item")
    else
        OPTIONAL_ITEMS+=("$item")
    fi
done

echo ""
echo "=== Required Items ==="
MISSING=0
for item in "${REQUIRED_ITEMS[@]}"; do
    if echo "$ALL_ITEMS" | grep -qx "$item"; then
        pass "$item"
    else
        echo -e "${RED}[MISSING]${NC} $item"
        ((MISSING++))
    fi
done | sort

echo ""
echo "=== Optional Items ==="
for item in "${OPTIONAL_ITEMS[@]}"; do
    if echo "$ALL_ITEMS" | grep -qx "$item"; then
        pass "$item"
    else
        warn "$item - not found (this is optional)"
    fi
done | sort

echo ""
echo "========================================"
if [[ $MISSING -eq 0 ]]; then
    echo -e "${GREEN}All required vault items present!${NC}"
    echo "You can safely run: ./restore.sh"
    exit 0
else
    echo -e "${RED}Missing $MISSING required item(s)${NC}"
    echo ""
    echo "To create missing items:"
    echo "  dotfiles vault create ITEM-NAME"
    exit 1
fi
