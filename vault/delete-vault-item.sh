#!/usr/bin/env zsh
# ============================================================
# FILE: vault/delete-vault-item.sh
# Deletes items from Bitwarden vault
# Usage: ./delete-vault-item.sh [--dry-run] [--force] ITEM-NAME...
# ============================================================
set -uo pipefail

# Source common functions
source "$(dirname "$0")/_common.sh"

DRY_RUN=false
FORCE=false
ITEMS_TO_DELETE=()
LIST_MODE=false

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
            LIST_MODE=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        -*)
            fail "Unknown option: $1"
            usage
            ;;
        *)
            ITEMS_TO_DELETE+=("$1")
            shift
            ;;
    esac
done

# Verify prerequisites
require_bw
require_jq

# Get session and sync
SESSION=$(get_session)
sync_vault "$SESSION"

# Handle list mode
if $LIST_MODE; then
    echo ""
    echo "=== All Items in Vault ==="
    echo ""
    bw list items --session "$SESSION" 2>/dev/null | jq -r '.[] | "\(.name) (\(.type | if . == 1 then "Login" elif . == 2 then "Secure Note" elif . == 3 then "Card" else "Other" end))"' | sort
    echo ""
    exit 0
fi

# Check we have items to delete
if [[ ${#ITEMS_TO_DELETE[@]} -eq 0 ]]; then
    warn "No items specified."
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
    item_json=$(bw_get_item "$item_name" "$SESSION")
    if [[ -z "$item_json" ]]; then
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

    # Handle protected items (use is_protected_item from _common.sh)
    if is_protected_item "$item_name"; then
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
