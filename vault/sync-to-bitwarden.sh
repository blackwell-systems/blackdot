#!/usr/bin/env bash
# ============================================================
# FILE: vault/sync-to-bitwarden.sh
# Syncs local config files back to Bitwarden (inverse of restore)
# Usage: ./sync-to-bitwarden.sh [--dry-run] [--all | item...]
# ============================================================
set -uo pipefail

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' NC=''
fi

VAULT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_FILE="$VAULT_DIR/.bw-session"
DRY_RUN=false
ITEMS_TO_SYNC=()

# Syncable items and their local file paths
declare -A ITEM_FILES=(
    ["SSH-Config"]="$HOME/.ssh/config"
    ["AWS-Config"]="$HOME/.aws/config"
    ["AWS-Credentials"]="$HOME/.aws/credentials"
    ["Git-Config"]="$HOME/.gitconfig"
    ["Environment-Secrets"]="$HOME/.local/env.secrets"
)

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [ITEMS...]

Syncs local config files back to Bitwarden.

OPTIONS:
    --dry-run, -n    Show what would be synced without making changes
    --all, -a        Sync all items
    --help, -h       Show this help

ITEMS:
    SSH-Config          ~/.ssh/config
    AWS-Config          ~/.aws/config
    AWS-Credentials     ~/.aws/credentials
    Git-Config          ~/.gitconfig
    Environment-Secrets ~/.local/env.secrets

EXAMPLES:
    $(basename "$0") --dry-run --all     # Preview all changes
    $(basename "$0") SSH-Config          # Sync just SSH config
    $(basename "$0") AWS-Config Git-Config  # Sync multiple items

EOF
    exit 0
}

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
pass() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
dry() { echo -e "${CYAN}[DRY-RUN]${NC} $1"; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --all|-a)
            ITEMS_TO_SYNC=("${!ITEM_FILES[@]}")
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
            if [[ -v "ITEM_FILES[$1]" ]]; then
                ITEMS_TO_SYNC+=("$1")
            else
                echo "Unknown item: $1" >&2
                echo "Valid items: ${!ITEM_FILES[*]}" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ ${#ITEMS_TO_SYNC[@]} -eq 0 ]]; then
    echo "No items specified. Use --all or specify items to sync."
    echo ""
    usage
fi

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

# Sync vault first
info "Syncing Bitwarden vault..."
bw sync --session "$SESSION" >/dev/null

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
    local local_file="${ITEM_FILES[$item_name]}"

    echo -e "${BLUE}--- $item_name ---${NC}"

    # Check if local file exists
    if [[ ! -f "$local_file" ]]; then
        warn "Local file not found: $local_file"
        ((SKIPPED++))
        return 0
    fi

    # Get current Bitwarden content
    local bw_json bw_notes item_id
    if ! bw_json="$(bw get item "$item_name" --session "$SESSION" 2>/dev/null)"; then
        warn "Item '$item_name' not found in Bitwarden"
        echo "    To create it, see README.md 'One-Time: Push Current Files into Bitwarden'"
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
