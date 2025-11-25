#!/usr/bin/env bash
# ============================================================
# FILE: vault/delete-vault-item.sh
# Deletes items from Bitwarden vault
# Usage: ./delete-vault-item.sh [--dry-run] [--force] ITEM-NAME...
# ============================================================
set -uo pipefail

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' DIM='' NC=''
fi

VAULT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_FILE="$VAULT_DIR/.bw-session"
DRY_RUN=false
FORCE=false
ITEMS_TO_DELETE=()

# Protected items that require extra confirmation
PROTECTED_ITEMS=(
    "SSH-GitHub-Enterprise"
    "SSH-GitHub-Blackwell"
    "SSH-Config"
    "AWS-Config"
    "AWS-Credentials"
    "Git-Config"
    "Environment-Secrets"
)

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] ITEM-NAME...

Deletes items from Bitwarden vault.

OPTIONS:
    --dry-run, -n    Show what would be deleted without making changes
    --force, -f      Skip confirmation prompts
    --list, -l       List all items in vault (helper)
    --help, -h       Show this help

EXAMPLES:
    $(basename "$0") TEST-NOTE                    # Delete with confirmation
    $(basename "$0") --dry-run TEST-NOTE          # Preview deletion
    $(basename "$0") --force OLD-KEY OTHER-ITEM   # Delete without prompts
    $(basename "$0") --list                       # List all items

NOTES:
    - Protected dotfiles items (SSH-*, AWS-*, Git-Config, etc.) require
      typing the item name to confirm deletion, even with --force
    - Deletion is permanent and cannot be undone
    - Use --dry-run first to verify you're deleting the right item

EOF
    exit 0
}

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
pass() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
dry() { echo -e "${CYAN}[DRY-RUN]${NC} $1"; }

is_protected() {
    local name="$1"
    for protected in "${PROTECTED_ITEMS[@]}"; do
        [[ "$name" == "$protected" ]] && return 0
    done
    return 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --list|-l)
            # Quick list mode - handled after session setup
            LIST_MODE=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            ;;
        *)
            ITEMS_TO_DELETE+=("$1")
            shift
            ;;
    esac
done

# Verify prerequisites
if ! command -v bw >/dev/null 2>&1; then
    fail "Bitwarden CLI (bw) is not installed."
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    fail "jq is not installed."
    exit 1
fi

# Get session
SESSION="${BW_SESSION:-}"
if [[ -z "$SESSION" && -f "$SESSION_FILE" ]]; then
    SESSION="$(cat "$SESSION_FILE")"
fi

if [[ -z "$SESSION" ]] || ! bw unlock --check --session "$SESSION" >/dev/null 2>&1; then
    info "Unlocking Bitwarden vault..."
    SESSION="$(bw unlock --raw)"
    if [[ -z "$SESSION" ]]; then
        fail "Failed to unlock Bitwarden vault."
        exit 1
    fi
fi

# Sync vault
info "Syncing Bitwarden vault..."
bw sync --session "$SESSION" >/dev/null

# Handle list mode
if [[ "${LIST_MODE:-false}" == "true" ]]; then
    echo ""
    echo "=== All Items in Vault ==="
    echo ""
    bw list items --session "$SESSION" 2>/dev/null | jq -r '.[] | "\(.name) (\(.type | if . == 1 then "Login" elif . == 2 then "Secure Note" elif . == 3 then "Card" else "Other" end))"' | sort
    echo ""
    exit 0
fi

# Check we have items to delete
if [[ ${#ITEMS_TO_DELETE[@]} -eq 0 ]]; then
    echo "No items specified."
    echo ""
    usage
fi

echo ""
echo "========================================"
echo "Delete from Bitwarden"
if $DRY_RUN; then
    echo -e "${CYAN}(DRY RUN - no changes will be made)${NC}"
fi
echo "========================================"
echo ""

DELETED=0
SKIPPED=0
FAILED=0

delete_item() {
    local item_name="$1"

    echo -e "${BLUE}--- $item_name ---${NC}"

    # Get item details
    local item_json
    if ! item_json="$(bw get item "$item_name" --session "$SESSION" 2>/dev/null)"; then
        warn "Item '$item_name' not found in Bitwarden"
        ((SKIPPED++))
        return 0
    fi

    local item_id item_type notes_length modified type_name
    item_id="$(printf '%s' "$item_json" | jq -r '.id')"
    item_type="$(printf '%s' "$item_json" | jq -r '.type')"
    notes_length="$(printf '%s' "$item_json" | jq -r '.notes // "" | length')"
    modified="$(printf '%s' "$item_json" | jq -r '.revisionDate // "unknown"' | cut -d'T' -f1)"

    case "$item_type" in
        1) type_name="Login" ;;
        2) type_name="Secure Note" ;;
        3) type_name="Card" ;;
        4) type_name="Identity" ;;
        *) type_name="Unknown" ;;
    esac

    echo "  Type: $type_name"
    echo "  Notes: $notes_length chars"
    echo "  Modified: $modified"
    echo -e "  ${DIM}ID: $item_id${NC}"
    echo ""

    # Handle protected items
    if is_protected "$item_name"; then
        echo -e "${RED}⚠ WARNING: This is a protected dotfiles item!${NC}"
        echo "Deleting this will break your dotfiles restore."
        echo ""

        if $DRY_RUN; then
            dry "Would delete protected item '$item_name'"
            ((DELETED++))
            return 0
        fi

        # Always require typing the name for protected items
        echo -n "Type the item name to confirm deletion: "
        read -r confirm
        if [[ "$confirm" != "$item_name" ]]; then
            warn "Confirmation failed - skipping"
            ((SKIPPED++))
            return 0
        fi
    else
        # Non-protected: respect --force flag
        if $DRY_RUN; then
            dry "Would delete '$item_name'"
            ((DELETED++))
            return 0
        fi

        if ! $FORCE; then
            echo -n "Delete '$item_name'? [y/N] "
            read -r confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                warn "Cancelled"
                ((SKIPPED++))
                return 0
            fi
        fi
    fi

    # Perform deletion
    if bw delete item "$item_id" --session "$SESSION" >/dev/null 2>&1; then
        pass "Deleted '$item_name'"
        ((DELETED++))
    else
        fail "Failed to delete '$item_name'"
        ((FAILED++))
    fi
}

# Process each item
for item in "${ITEMS_TO_DELETE[@]}"; do
    delete_item "$item"
    echo ""
done

# Summary
echo "========================================"
if $DRY_RUN; then
    echo -e "${CYAN}DRY RUN SUMMARY:${NC}"
    echo "  Would delete: $DELETED"
else
    echo "SUMMARY:"
    echo "  Deleted: $DELETED"
fi
echo "  Skipped: $SKIPPED"
if [[ $FAILED -gt 0 ]]; then
    echo -e "  ${RED}Failed: $FAILED${NC}"
fi
echo "========================================"

if $DRY_RUN && [[ $DELETED -gt 0 ]]; then
    echo ""
    echo "Run without --dry-run to delete:"
    echo "  $(basename "$0") ${ITEMS_TO_DELETE[*]}"
fi

exit $FAILED
