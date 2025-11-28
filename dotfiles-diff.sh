#!/usr/bin/env zsh
# ============================================================
# FILE: dotfiles-diff.sh
# Preview changes before sync or restore operations
# Usage:
#   dotfiles diff                # Show all diffs
#   dotfiles diff --sync         # What sync would push
#   dotfiles diff --restore      # What restore would change
#   dotfiles diff SSH-Config     # Diff specific item
# ============================================================
set -uo pipefail

# Colors
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN='' YELLOW='' BLUE='' RED='' CYAN='' BOLD='' NC=''
fi

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
pass()  { echo -e "${GREEN}[SYNC]${NC} $1"; }
warn()  { echo -e "${YELLOW}[DIFF]${NC} $1"; }

# Items to compare
typeset -A DIFF_ITEMS=(
    ["SSH-Config"]="$HOME/.ssh/config"
    ["AWS-Config"]="$HOME/.aws/config"
    ["AWS-Credentials"]="$HOME/.aws/credentials"
    ["Git-Config"]="$HOME/.gitconfig"
    ["Environment-Secrets"]="$HOME/.local/env.secrets"
)

get_vault_content() {
    local item_name="$1"
    local session="${BW_SESSION:-}"
    local vault_dir="$HOME/workspace/dotfiles/vault"

    if [[ -z "$session" && -f "$vault_dir/.bw-session" ]]; then
        session=$(cat "$vault_dir/.bw-session")
    fi

    if [[ -z "$session" ]]; then
        return 1
    fi

    bw get notes "$item_name" --session "$session" 2>/dev/null
}

show_diff() {
    local item_name="$1"
    local local_file="${DIFF_ITEMS[$item_name]}"

    if [[ ! -f "$local_file" ]]; then
        echo -e "${YELLOW}$item_name${NC}: Local file not found ($local_file)"
        return 0
    fi

    local vault_content
    vault_content=$(get_vault_content "$item_name" 2>/dev/null)

    if [[ -z "$vault_content" ]]; then
        echo -e "${YELLOW}$item_name${NC}: Not found in Bitwarden"
        return 0
    fi

    local local_content=$(cat "$local_file")

    if [[ "$vault_content" == "$local_content" ]]; then
        echo -e "${GREEN}$item_name${NC}: In sync ✓"
        return 0
    fi

    echo ""
    echo -e "${BOLD}${CYAN}═══ $item_name ═══${NC}"
    echo -e "${YELLOW}Local file:${NC} $local_file"
    echo ""

    # Create temp files for diff
    local temp_local=$(mktemp)
    local temp_vault=$(mktemp)
    echo "$local_content" > "$temp_local"
    echo "$vault_content" > "$temp_vault"

    # Show diff with colors if available
    if command -v diff &>/dev/null; then
        echo -e "${RED}--- Bitwarden (vault)${NC}"
        echo -e "${GREEN}+++ Local (file)${NC}"
        diff -u "$temp_vault" "$temp_local" | tail -n +3 | head -50

        local diff_lines=$(diff -u "$temp_vault" "$temp_local" | wc -l)
        if [[ $diff_lines -gt 53 ]]; then
            echo -e "${YELLOW}... ($(($diff_lines - 53)) more lines)${NC}"
        fi
    fi

    rm -f "$temp_local" "$temp_vault"
    echo ""
}

show_sync_preview() {
    echo -e "${BOLD}Preview: What 'dotfiles vault sync' would push to Bitwarden${NC}"
    echo ""

    for item_name in "${(k)DIFF_ITEMS[@]}"; do
        local local_file="${DIFF_ITEMS[$item_name]}"
        if [[ -f "$local_file" ]]; then
            local vault_content=$(get_vault_content "$item_name" 2>/dev/null)
            local local_content=$(cat "$local_file")

            if [[ -z "$vault_content" ]]; then
                echo -e "  ${GREEN}+${NC} $item_name: Would CREATE in vault"
            elif [[ "$vault_content" != "$local_content" ]]; then
                echo -e "  ${YELLOW}~${NC} $item_name: Would UPDATE in vault"
            else
                echo -e "  ${BLUE}=${NC} $item_name: No changes"
            fi
        fi
    done
}

show_restore_preview() {
    echo -e "${BOLD}Preview: What 'dotfiles vault restore' would change locally${NC}"
    echo ""

    for item_name in "${(k)DIFF_ITEMS[@]}"; do
        local local_file="${DIFF_ITEMS[$item_name]}"
        local vault_content=$(get_vault_content "$item_name" 2>/dev/null)

        if [[ -z "$vault_content" ]]; then
            echo -e "  ${YELLOW}!${NC} $item_name: Not in vault (skip)"
            continue
        fi

        if [[ ! -f "$local_file" ]]; then
            echo -e "  ${GREEN}+${NC} $item_name: Would CREATE $local_file"
        else
            local local_content=$(cat "$local_file")
            if [[ "$vault_content" != "$local_content" ]]; then
                echo -e "  ${YELLOW}~${NC} $item_name: Would OVERWRITE $local_file"
            else
                echo -e "  ${BLUE}=${NC} $item_name: No changes"
            fi
        fi
    done
}

# Check Bitwarden session
check_session() {
    local session="${BW_SESSION:-}"
    local vault_dir="$HOME/workspace/dotfiles/vault"

    if [[ -z "$session" && -f "$vault_dir/.bw-session" ]]; then
        session=$(cat "$vault_dir/.bw-session")
    fi

    if [[ -z "$session" ]] || ! bw unlock --check --session "$session" &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Bitwarden not unlocked"
        echo ""
        echo "Run: export BW_SESSION=\"\$(bw unlock --raw)\""
        exit 1
    fi
}

# Main
echo ""
echo -e "${BOLD}${BLUE}Dotfiles Diff${NC}"
echo ""

case "${1:-}" in
    --sync|-s)
        check_session
        show_sync_preview
        ;;
    --restore|-r)
        check_session
        show_restore_preview
        ;;
    --help|-h|help)
        echo "dotfiles diff - Preview changes before sync/restore"
        echo ""
        echo "Usage:"
        echo "  dotfiles diff              Show all differences"
        echo "  dotfiles diff --sync       Preview what sync would push"
        echo "  dotfiles diff --restore    Preview what restore would change"
        echo "  dotfiles diff ITEM         Show diff for specific item"
        echo ""
        echo "Items: ${(k)DIFF_ITEMS[@]}"
        ;;
    "")
        check_session
        for item_name in "${(k)DIFF_ITEMS[@]}"; do
            show_diff "$item_name"
        done
        ;;
    *)
        check_session
        if [[ -n "${DIFF_ITEMS[$1]:-}" ]]; then
            show_diff "$1"
        else
            echo -e "${RED}Unknown item: $1${NC}"
            echo "Available: ${(k)DIFF_ITEMS[@]}"
            exit 1
        fi
        ;;
esac

echo ""
