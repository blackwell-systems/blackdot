#!/usr/bin/env zsh
# ============================================================
# FILE: vault/create-vault-item.sh
# Creates new Bitwarden Secure Note items from local files
# Usage: ./create-vault-item.sh [OPTIONS] ITEM-NAME [FILE-PATH]
# ============================================================
set -uo pipefail

# Source common functions
source "$(dirname "$0")/_common.sh"

DRY_RUN=false
FORCE=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] ITEM-NAME [FILE-PATH]

Creates a Bitwarden Secure Note from a local file.

OPTIONS:
    --dry-run, -n    Show what would be created without making changes
    --force, -f      Overwrite if item already exists
    --help, -h       Show this help

ARGUMENTS:
    ITEM-NAME        Name for the vault item (must match vault-items.json)
    FILE-PATH        Path to local file (optional if ITEM-NAME is in config)

CONFIGURATION:
    Item paths are loaded from ~/.config/dotfiles/vault-items.json
    Run without arguments to see configured items.

EXAMPLES:
    $(basename "$0") Git-Config                    # Uses path from config
    $(basename "$0") SSH-Config                    # Uses path from config
    $(basename "$0") My-Custom ~/path/to/file.txt  # Explicit path for unlisted item
    $(basename "$0") --dry-run Git-Config          # Preview creation
    $(basename "$0") --force Git-Config            # Overwrite existing

NOTES:
    - Items are created as Secure Notes with file content in the 'notes' field
    - For SSH keys, use the full key content (private + public) in a single file
    - Use 'list-vault-items.sh' to check what already exists

EOF
    exit 0
}

# Parse arguments
ITEM_NAME=""
FILE_PATH=""

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
        --help|-h)
            usage
            ;;
        -*)
            fail "Unknown option: $1"
            usage
            ;;
        *)
            if [[ -z "$ITEM_NAME" ]]; then
                ITEM_NAME="$1"
            elif [[ -z "$FILE_PATH" ]]; then
                FILE_PATH="$1"
            else
                fail "Too many arguments"
                usage
            fi
            shift
            ;;
    esac
done

# Validate item name
if [[ -z "$ITEM_NAME" ]]; then
    fail "Item name is required"
    echo ""
    usage
fi

# If no file path provided, try to get it from known items
if [[ -z "$FILE_PATH" ]]; then
    FILE_PATH=$(get_item_path "$ITEM_NAME")
    if [[ -z "$FILE_PATH" ]]; then
        fail "Unknown item '$ITEM_NAME' - please provide a file path"
        echo ""
        echo "Known items:"
        for item in "${(@k)SYNCABLE_ITEMS}"; do
            echo "  $item → ${SYNCABLE_ITEMS[$item]}"
        done | sort
        exit 1
    fi
    info "Using known path: $FILE_PATH"
fi

# Check prerequisites
require_vault_config || exit 1
require_bw
require_jq
require_logged_in

# Validate file exists
if [[ ! -f "$FILE_PATH" ]]; then
    fail "File not found: $FILE_PATH"
    exit 1
fi

# Get session and sync
SESSION=$(get_session)
sync_vault "$SESSION"

echo ""
echo "========================================"
echo "Create Bitwarden Item"
if $DRY_RUN; then
    echo -e "${CYAN}(DRY RUN - no changes will be made)${NC}"
fi
echo "========================================"
echo ""

# Check if item already exists
EXISTING_JSON=$(bw_get_item "$ITEM_NAME" "$SESSION")

if [[ -n "$EXISTING_JSON" ]]; then
    existing_id=$(printf '%s' "$EXISTING_JSON" | jq -r '.id')
    existing_notes_len=$(printf '%s' "$EXISTING_JSON" | jq -r '.notes // "" | length')

    warn "Item '$ITEM_NAME' already exists"
    echo "  ID: $existing_id"
    echo "  Current notes: $existing_notes_len chars"
    echo ""

    if ! $FORCE; then
        fail "Use --force to overwrite, or use 'dotfiles vault push' to update"
        exit 1
    fi

    info "Will overwrite existing item (--force)"
    MODE="update"
else
    info "Creating new item: $ITEM_NAME"
    MODE="create"
fi

# Read file content
FILE_CONTENT=$(cat "$FILE_PATH")
FILE_SIZE=$(wc -c < "$FILE_PATH" | tr -d ' ')
FILE_LINES=$(wc -l < "$FILE_PATH" | tr -d ' ')

echo "Source: $FILE_PATH"
echo "Size: $FILE_SIZE bytes ($FILE_LINES lines)"
echo ""

if $DRY_RUN; then
    if [[ "$MODE" == "create" ]]; then
        dry "Would create Secure Note '$ITEM_NAME' with content from $FILE_PATH"
    else
        dry "Would update '$ITEM_NAME' with content from $FILE_PATH"
    fi
    echo ""
    echo "Preview (first 5 lines):"
    echo "---"
    head -5 "$FILE_PATH"
    echo "---"
    exit 0
fi

if [[ "$MODE" == "create" ]]; then
    # Create new Secure Note (type 2)
    # Build the JSON template for a secure note
    NEW_ITEM_JSON=$(jq -n \
        --arg name "$ITEM_NAME" \
        --arg notes "$FILE_CONTENT" \
        '{
            type: 2,
            secureNote: { type: 0 },
            name: $name,
            notes: $notes,
            favorite: false
        }')

    if printf '%s' "$NEW_ITEM_JSON" | bw encode | bw create item --session "$SESSION" >/dev/null; then
        pass "Created '$ITEM_NAME'"
    else
        fail "Failed to create '$ITEM_NAME'"
        exit 1
    fi
else
    # Update existing item
    UPDATED_JSON=$(printf '%s' "$EXISTING_JSON" | jq --arg notes "$FILE_CONTENT" '.notes = $notes')

    if printf '%s' "$UPDATED_JSON" | bw encode | bw edit item "$existing_id" --session "$SESSION" >/dev/null; then
        pass "Updated '$ITEM_NAME'"
    else
        fail "Failed to update '$ITEM_NAME'"
        exit 1
    fi
fi

echo ""
echo "========================================"
echo "Done! Verify with:"
echo "  ./list-vault-items.sh"
echo "========================================"
