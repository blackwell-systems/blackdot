#!/usr/bin/env bash
# ============================================================
# FILE: vault/list-vault-items.sh
# Lists all Bitwarden items relevant to dotfiles restoration
# Usage: ./list-vault-items.sh [--verbose]
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

VERBOSE=false
[[ "${1:-}" == "--verbose" || "${1:-}" == "-v" ]] && VERBOSE=true

VAULT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Expected items for dotfiles
EXPECTED_ITEMS=(
    "SSH-GitHub-Enterprise"
    "SSH-GitHub-Blackwell"
    "SSH-Config"
    "AWS-Config"
    "AWS-Credentials"
    "Git-Config"
    "Environment-Secrets"
)

# Get session
SESSION="${BW_SESSION:-}"
if [[ -z "$SESSION" && -f "$VAULT_DIR/.bw-session" ]]; then
    SESSION="$(cat "$VAULT_DIR/.bw-session")"
fi

if [[ -z "$SESSION" ]] || ! bw unlock --check --session "$SESSION" >/dev/null 2>&1; then
    echo -e "${YELLOW}Bitwarden locked. Unlocking...${NC}"
    SESSION="$(bw unlock --raw)"
    if [[ -z "$SESSION" ]]; then
        echo -e "${RED}Failed to unlock Bitwarden${NC}"
        exit 1
    fi
fi

# Sync
echo -e "${BLUE}Syncing Bitwarden vault...${NC}"
bw sync --session "$SESSION" >/dev/null

echo ""
echo "========================================"
echo "     BITWARDEN VAULT ITEMS"
echo "========================================"
echo ""

# Get all items
ALL_ITEMS=$(bw list items --session "$SESSION" 2>/dev/null)

echo -e "${CYAN}=== Expected Dotfiles Items ===${NC}"
echo ""

for item_name in "${EXPECTED_ITEMS[@]}"; do
    # Find item
    item_json=$(echo "$ALL_ITEMS" | jq -r ".[] | select(.name == \"$item_name\")")

    if [[ -n "$item_json" ]]; then
        item_id=$(echo "$item_json" | jq -r '.id')
        item_type=$(echo "$item_json" | jq -r '.type')
        notes_length=$(echo "$item_json" | jq -r '.notes // "" | length')
        modified=$(echo "$item_json" | jq -r '.revisionDate // "unknown"' | cut -d'T' -f1)

        # Type name
        case "$item_type" in
            1) type_name="Login" ;;
            2) type_name="Secure Note" ;;
            3) type_name="Card" ;;
            4) type_name="Identity" ;;
            *) type_name="Unknown" ;;
        esac

        echo -e "${GREEN}[FOUND]${NC} $item_name"
        echo -e "        Type: $type_name | Notes: ${notes_length} chars | Modified: $modified"

        if $VERBOSE; then
            echo -e "        ${DIM}ID: $item_id${NC}"
            # Show first 100 chars of notes
            notes_preview=$(echo "$item_json" | jq -r '.notes // ""' | head -c 100 | tr '\n' ' ')
            if [[ -n "$notes_preview" ]]; then
                echo -e "        ${DIM}Preview: ${notes_preview}...${NC}"
            fi
        fi
    else
        echo -e "${RED}[MISSING]${NC} $item_name"
    fi
    echo ""
done

echo -e "${CYAN}=== All Secure Notes in Vault ===${NC}"
echo ""

# List all secure notes (type 2)
echo "$ALL_ITEMS" | jq -r '.[] | select(.type == 2) | .name' | sort | while read -r name; do
    # Check if it's an expected item
    is_expected=false
    for expected in "${EXPECTED_ITEMS[@]}"; do
        [[ "$name" == "$expected" ]] && is_expected=true && break
    done

    if $is_expected; then
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
