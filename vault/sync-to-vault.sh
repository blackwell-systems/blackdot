#!/usr/bin/env zsh
# ============================================================
# FILE: vault/sync-to-vault.sh
# Syncs local config files back to vault (inverse of restore)
# Usage: ./sync-to-vault.sh [--dry-run] [--all | item...]
# ============================================================
set -uo pipefail

# Source common functions
source "$(dirname "$0")/_common.sh"

DRY_RUN=false
ITEMS_TO_SYNC=()

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [ITEMS...]

Syncs local config files back to vault.

OPTIONS:
    --dry-run, -n    Show what would be synced without making changes
    --all, -a        Sync all items
    --help, -h       Show this help

ITEMS:
EOF
    for item in "${(@k)SYNCABLE_ITEMS}"; do
        printf "    %-20s %s\n" "$item" "${SYNCABLE_ITEMS[$item]}"
    done | sort
    cat <<EOF

EXAMPLES:
    $(basename "$0") --dry-run --all     # Preview all changes
    $(basename "$0") SSH-Config          # Sync just SSH config
    $(basename "$0") AWS-Config Git-Config  # Sync multiple items

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
        --all|-a)
            ITEMS_TO_SYNC=("${(@k)SYNCABLE_ITEMS}")
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
            if (( ${+SYNCABLE_ITEMS[$1]} )); then
                ITEMS_TO_SYNC+=("$1")
            else
                fail "Unknown item: $1"
                echo "Valid items: ${(k)SYNCABLE_ITEMS[*]}" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ ${#ITEMS_TO_SYNC[@]} -eq 0 ]]; then
    warn "No items specified. Use --all or specify items to sync."
    echo ""
    usage
fi

# Check offline mode
if is_offline; then
    warn "DOTFILES_OFFLINE=1 - Cannot sync to Bitwarden in offline mode"
    echo ""
    echo "To sync later:"
    echo "  unset DOTFILES_OFFLINE"
    echo "  dotfiles vault sync --all"
    exit 0
fi

# Verify prerequisites
require_vault_config || exit 1
require_bw
require_jq

# Get session and sync
SESSION=$(get_session)
sync_vault "$SESSION"

echo ""
echo "========================================"
echo "Sync to Bitwarden"
if $DRY_RUN; then
    echo -e "${CYAN}(DRY RUN - no changes will be made)${NC}"
fi
echo "========================================"
echo ""

SYNCED=0
SKIPPED=0
FAILED=0

sync_item() {
    local item_name="$1"
    local local_file="${SYNCABLE_ITEMS[$item_name]}"

    echo -e "${BLUE}--- $item_name ---${NC}"

    # Check if local file exists
    if [[ ! -f "$local_file" ]]; then
        warn "Local file not found: $local_file"
        ((SKIPPED++))
        return 0
    fi

    # Get current Bitwarden content
    local bw_json bw_notes item_id
    bw_json=$(bw_get_item "$item_name" "$SESSION")
    if [[ -z "$bw_json" ]]; then
        warn "Item '$item_name' not found in Bitwarden"
        echo "    To create it: dotfiles vault create $item_name"
        ((SKIPPED++))
        return 0
    fi

    item_id="$(printf '%s' "$bw_json" | jq -r '.id')"
    bw_notes="$(printf '%s' "$bw_json" | jq -r '.notes // ""')"

    # Get local content
    local local_content
    local_content="$(cat "$local_file")"

    # Compare
    if [[ "$bw_notes" == "$local_content" ]]; then
        pass "Already in sync: $local_file"
        ((SKIPPED++))
        return 0
    fi

    # Show diff summary
    local bw_lines local_lines
    bw_lines=$(printf '%s' "$bw_notes" | wc -l | tr -d ' ')
    local_lines=$(printf '%s' "$local_content" | wc -l | tr -d ' ')
    info "Changes detected: Bitwarden has $bw_lines lines, local has $local_lines lines"

    if $DRY_RUN; then
        dry "Would update '$item_name' from $local_file"
        ((SYNCED++))
        return 0
    fi

    # Update Bitwarden
    local new_json
    new_json=$(printf '%s' "$bw_json" | jq --arg notes "$local_content" '.notes = $notes')

    if printf '%s' "$new_json" | bw encode | bw edit item "$item_id" --session "$SESSION" >/dev/null; then
        pass "Updated '$item_name' from $local_file"
        ((SYNCED++))
    else
        fail "Failed to update '$item_name'"
        ((FAILED++))
    fi
}

# Process each item
for item in "${ITEMS_TO_SYNC[@]}"; do
    sync_item "$item"
    echo ""
done

# Summary
echo "========================================"
if $DRY_RUN; then
    echo -e "${CYAN}DRY RUN SUMMARY:${NC}"
    echo "  Would sync: $SYNCED"
else
    echo "SUMMARY:"
    echo "  Synced: $SYNCED"
fi
echo "  Skipped (no changes): $SKIPPED"
if [[ $FAILED -gt 0 ]]; then
    echo -e "  ${RED}Failed: $FAILED${NC}"
fi
echo "========================================"

if $DRY_RUN && [[ $SYNCED -gt 0 ]]; then
    echo ""
    echo "Run without --dry-run to apply changes:"
    echo "  $(basename "$0") ${ITEMS_TO_SYNC[*]}"
fi

exit $FAILED
