#!/usr/bin/env zsh
# ============================================================
# FILE: vault/list-vault-items.sh
# Lists all Bitwarden items relevant to dotfiles restoration
# Usage: ./list-vault-items.sh [--verbose]
# ============================================================
set -uo pipefail

# Source common functions
source "$(dirname "$0")/_common.sh"

VERBOSE=false
[[ "${1:-}" == "--verbose" || "${1:-}" == "-v" ]] && VERBOSE=true

# Check prerequisites
require_vault_config || exit 1
require_bw
require_jq

# Get session and sync
SESSION=$(get_session)
sync_vault "$SESSION"

echo ""
echo "========================================"
echo "     BITWARDEN VAULT ITEMS"
echo "========================================"
echo ""

# Get all items
ALL_ITEMS=$(bw list items --session "$SESSION" 2>/dev/null)

echo -e "${CYAN}=== Expected Dotfiles Items ===${NC}"
echo ""

# Use DOTFILES_ITEMS from _common.sh
for item_name in "${(@k)DOTFILES_ITEMS}"; do
    # Find item (use printf to handle large JSON safely)
    item_json=$(printf '%s' "$ALL_ITEMS" | jq -r ".[] | select(.name == \"$item_name\")")

    if [[ -n "$item_json" ]]; then
        item_id=$(printf '%s' "$item_json" | jq -r '.id')
        item_type=$(printf '%s' "$item_json" | jq -r '.type')
        notes_length=$(printf '%s' "$item_json" | jq -r '.notes // "" | length')
        modified=$(printf '%s' "$item_json" | jq -r '.revisionDate // "unknown"' | cut -d'T' -f1)

        # Type name
        case "$item_type" in
            1) type_name="Login" ;;
            2) type_name="Secure Note" ;;
            3) type_name="Card" ;;
            4) type_name="Identity" ;;
            *) type_name="Unknown" ;;
        esac

        print "${GREEN}[FOUND]${NC} $item_name"
        print "        Type: $type_name | Notes: ${notes_length} chars | Modified: $modified"

        if $VERBOSE; then
            print "        ${DIM}ID: $item_id${NC}"
            # Show first 100 chars of notes
            notes_preview=$(printf '%s' "$item_json" | jq -r '.notes // ""' | head -c 100 | tr '\n' ' ')
            if [[ -n "$notes_preview" ]]; then
                print "        ${DIM}Preview: ${notes_preview}...${NC}"
            fi
        fi
    else
        print "${RED}[MISSING]${NC} $item_name"
    fi
    echo ""
done

echo -e "${CYAN}=== All Secure Notes in Vault ===${NC}"
echo ""

# List all secure notes (type 2)
printf '%s' "$ALL_ITEMS" | jq -r '.[] | select(.type == 2) | .name' | sort | while read -r name; do
    # Check if it's an expected item
    if is_protected_item "$name"; then
        echo -e "  ${GREEN}✓${NC} $name ${DIM}(dotfiles)${NC}"
    else
        echo -e "  ${DIM}○${NC} $name"
    fi
done

echo ""
echo "========================================"
echo -e "${BLUE}Tip:${NC} Use --verbose to see item IDs and content previews"
echo -e "${BLUE}Tip:${NC} To view full content: bw get notes \"Item-Name\" --session \"\$BW_SESSION\""
echo "========================================"
