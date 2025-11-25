#!/usr/bin/env bash
# ============================================================
# FILE: vault/check-vault-items.sh
# Validates that all required Bitwarden items exist before restore
# Usage: ./check-vault-items.sh [--session SESSION]
# ============================================================
set -uo pipefail

# Colors for output
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# Required Bitwarden items for vault restoration
REQUIRED_ITEMS=(
    "SSH-GitHub-Enterprise"
    "SSH-GitHub-Blackwell"
    "SSH-Config"
    "AWS-Config"
    "AWS-Credentials"
    "Git-Config"
)

# Optional items (warn if missing, don't fail)
OPTIONAL_ITEMS=(
    "Environment-Secrets"
)

pass() { echo -e "${GREEN}[OK]${NC} $1"; }
fail() { echo -e "${RED}[MISSING]${NC} $1"; }
warn() { echo -e "${YELLOW}[OPTIONAL]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

usage() {
    echo "Usage: $0 [--session SESSION]"
    echo ""
    echo "Validates that all required Bitwarden items exist."
    echo ""
    echo "Options:"
    echo "  --session SESSION   Use provided session token"
    echo "  -h, --help          Show this help"
    echo ""
    echo "If no session is provided, uses BW_SESSION environment variable."
    exit 0
}

# Parse arguments
SESSION="${BW_SESSION:-}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --session)
            SESSION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Check prerequisites
if ! command -v bw >/dev/null 2>&1; then
    echo "ERROR: Bitwarden CLI (bw) is not installed." >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is not installed." >&2
    exit 1
fi

# Get session if not provided
if [[ -z "$SESSION" ]]; then
    VAULT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SESSION_FILE="$VAULT_DIR/.bw-session"

    if [[ -f "$SESSION_FILE" ]]; then
        SESSION="$(cat "$SESSION_FILE")"
        if ! bw unlock --check --session "$SESSION" >/dev/null 2>&1; then
            echo "Cached session expired. Please unlock Bitwarden:" >&2
            SESSION="$(bw unlock --raw)"
        fi
    else
        echo "No session found. Please unlock Bitwarden:" >&2
        SESSION="$(bw unlock --raw)"
    fi
fi

# Verify session is valid
if ! bw unlock --check --session "$SESSION" >/dev/null 2>&1; then
    echo "ERROR: Invalid Bitwarden session." >&2
    exit 1
fi

# Sync vault
info "Syncing Bitwarden vault..."
bw sync --session "$SESSION" >/dev/null

# Get all item names
info "Fetching item list..."
ALL_ITEMS=$(bw list items --session "$SESSION" 2>/dev/null | jq -r '.[].name')

echo ""
echo "=== Required Items ==="
MISSING=0
for item in "${REQUIRED_ITEMS[@]}"; do
    if echo "$ALL_ITEMS" | grep -qx "$item"; then
        pass "$item"
    else
        fail "$item"
        ((MISSING++))
    fi
done

echo ""
echo "=== Optional Items ==="
for item in "${OPTIONAL_ITEMS[@]}"; do
    if echo "$ALL_ITEMS" | grep -qx "$item"; then
        pass "$item"
    else
        warn "$item - not found (this is optional)"
    fi
done

echo ""
echo "========================================"
if [[ $MISSING -eq 0 ]]; then
    echo -e "${GREEN}All required vault items present!${NC}"
    echo "You can safely run: ./bootstrap-vault.sh"
    exit 0
else
    echo -e "${RED}Missing $MISSING required item(s)${NC}"
    echo ""
    echo "To create missing items, see README.md section:"
    echo "  'One-Time: Push Current Files into Bitwarden'"
    exit 1
fi
