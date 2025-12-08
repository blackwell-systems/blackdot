#!/usr/bin/env zsh
# ============================================================
# FILE: vault/status.sh
# Show comprehensive vault sync status and drift detection
# Usage: dotfiles vault status
# ============================================================
set -uo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${0:a}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
source "$DOTFILES_DIR/lib/_logging.sh"
source "$DOTFILES_DIR/lib/_vault.sh"
source "$DOTFILES_DIR/lib/_config.sh"

# ============================================================
# Banner
# ============================================================
echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║           Vault Status & Sync Summary                 ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================
# Section 1: Vault Backend Configuration
# ============================================================
section "Vault Backend"

# Initialize vault backend
if ! vault_init 2>/dev/null; then
    fail "No vault backend configured"
    echo ""
    echo -e "${DIM}Setup vault:${NC} ${GREEN}dotfiles vault setup${NC}"
    echo ""
    exit 1
fi

BACKEND_NAME=$(vault_name)
pass "Backend: $BACKEND_NAME"

# Check login status
if vault_login_check; then
    pass "Logged in: Yes"

    # Check if vault is unlocked (session available) - non-interactive check only
    SESSION=$(vault_check_session 2>/dev/null || echo "")
    if [[ -n "$SESSION" ]]; then
        pass "Vault unlocked: Yes"
    else
        warn "Vault locked (session expired)"
        echo ""
        case "$DOTFILES_VAULT_BACKEND" in
            bitwarden)
                echo -e "${DIM}Unlock:${NC} ${GREEN}dotfiles vault unlock${NC}"
                ;;
            1password)
                echo -e "${DIM}Unlock:${NC} ${GREEN}dotfiles vault unlock${NC}"
                ;;
            pass)
                echo -e "${DIM}Info:${NC} GPG agent handles unlocking automatically"
                ;;
        esac
        echo ""
        exit 1
    fi
else
    fail "Not logged in to $BACKEND_NAME"
    echo ""
    case "$DOTFILES_VAULT_BACKEND" in
        bitwarden)
            echo -e "${DIM}Login:${NC} ${GREEN}bw login && dotfiles vault unlock${NC}"
            ;;
        1password)
            echo -e "${DIM}Login:${NC} ${GREEN}dotfiles vault unlock${NC}"
            ;;
        pass)
            echo -e "${DIM}Setup:${NC} ${GREEN}pass init <gpg-id>${NC}"
            ;;
    esac
    echo ""
    exit 1
fi

# ============================================================
# Section 2: Vault Items Summary
# ============================================================
section "Vault Items"

# Load vault-items.json
VAULT_ITEMS_FILE="$HOME/.config/dotfiles/vault-items.json"
if [[ -f "$VAULT_ITEMS_FILE" ]]; then
    ITEM_COUNT=$(jq -r '.vault_items | length' "$VAULT_ITEMS_FILE" 2>/dev/null || echo "0")
    SSH_COUNT=$(jq -r '.ssh_keys | length' "$VAULT_ITEMS_FILE" 2>/dev/null || echo "0")

    pass "Config items: $ITEM_COUNT"
    pass "SSH keys: $SSH_COUNT"

    # List items
    echo ""
    echo -e "${DIM}  Configured vault items:${NC}"

    # Config items (object keys are the item names)
    if [[ $ITEM_COUNT -gt 0 ]]; then
        jq -r '.vault_items | keys[] | "    • \(.)"' "$VAULT_ITEMS_FILE" 2>/dev/null | head -10
        if [[ $ITEM_COUNT -gt 10 ]]; then
            echo -e "${DIM}    ... and $((ITEM_COUNT - 10)) more${NC}"
        fi
    fi

    # SSH keys (object: key=name, value=path)
    if [[ $SSH_COUNT -gt 0 ]]; then
        echo -e "${DIM}  SSH Keys:${NC}"
        jq -r '.ssh_keys | to_entries[] | "    • \(.key) → \(.value)"' "$VAULT_ITEMS_FILE" 2>/dev/null
    fi
else
    warn "No vault items configured"
    echo ""
    echo -e "${DIM}Scan for secrets:${NC} ${GREEN}dotfiles vault scan${NC}"
fi

# ============================================================
# Section 3: Last Sync Timestamp
# ============================================================
section "Sync History"

# Check for last sync timestamp in config.json
LAST_PULL=$(config_get "vault.last_pull" "")
LAST_PUSH=$(config_get "vault.last_push" "")

if [[ -n "$LAST_PULL" ]]; then
    # Calculate time ago
    if command -v date >/dev/null 2>&1; then
        PULL_EPOCH=$(date -d "$LAST_PULL" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$LAST_PULL" +%s 2>/dev/null || echo "0")
        NOW_EPOCH=$(date +%s)
        SECONDS_AGO=$((NOW_EPOCH - PULL_EPOCH))

        if [[ $SECONDS_AGO -lt 3600 ]]; then
            MINUTES_AGO=$((SECONDS_AGO / 60))
            TIME_AGO="${MINUTES_AGO}m ago"
        elif [[ $SECONDS_AGO -lt 86400 ]]; then
            HOURS_AGO=$((SECONDS_AGO / 3600))
            TIME_AGO="${HOURS_AGO}h ago"
        else
            DAYS_AGO=$((SECONDS_AGO / 86400))
            TIME_AGO="${DAYS_AGO}d ago"
        fi

        pass "Last pull: $TIME_AGO ($LAST_PULL)"
    else
        pass "Last pull: $LAST_PULL"
    fi
else
    info "Last pull: Never (or not tracked)"
fi

if [[ -n "$LAST_PUSH" ]]; then
    if command -v date >/dev/null 2>&1; then
        PUSH_EPOCH=$(date -d "$LAST_PUSH" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$LAST_PUSH" +%s 2>/dev/null || echo "0")
        NOW_EPOCH=$(date +%s)
        SECONDS_AGO=$((NOW_EPOCH - PUSH_EPOCH))

        if [[ $SECONDS_AGO -lt 3600 ]]; then
            MINUTES_AGO=$((SECONDS_AGO / 60))
            TIME_AGO="${MINUTES_AGO}m ago"
        elif [[ $SECONDS_AGO -lt 86400 ]]; then
            HOURS_AGO=$((SECONDS_AGO / 3600))
            TIME_AGO="${HOURS_AGO}h ago"
        else
            DAYS_AGO=$((SECONDS_AGO / 86400))
            TIME_AGO="${DAYS_AGO}d ago"
        fi

        pass "Last push: $TIME_AGO ($LAST_PUSH)"
    else
        pass "Last push: $LAST_PUSH"
    fi
else
    info "Last push: Never (or not tracked)"
fi

# ============================================================
# Section 4: Drift Detection
# ============================================================
section "Drift Detection (Local vs Vault)"

# Items to check for drift
typeset -A DRIFT_ITEMS=(
    ["SSH-Config"]="$HOME/.ssh/config"
    ["AWS-Config"]="$HOME/.aws/config"
    ["AWS-Credentials"]="$HOME/.aws/credentials"
    ["Git-Config"]="$HOME/.gitconfig"
    ["Environment-Secrets"]="$HOME/.local/env.secrets"
    ["Claude-Profiles"]="$HOME/.claude/profiles.json"
)

DRIFT_COUNT=0
CHECKED_COUNT=0
MISSING_LOCAL=0
MISSING_VAULT=0

declare -a DRIFTED_ITEMS

for item_name in "${(@k)DRIFT_ITEMS}"; do
    local_file="${DRIFT_ITEMS[$item_name]}"

    # Check if local file exists
    if [[ ! -f "$local_file" ]]; then
        ((MISSING_LOCAL++))
        continue
    fi

    # Get vault content
    vault_content=$(vault_get_notes "$item_name" "$SESSION" 2>/dev/null || echo "")

    if [[ -z "$vault_content" ]]; then
        ((MISSING_VAULT++))
        warn "$item_name: exists locally but not in vault"
        DRIFTED_ITEMS+=("$item_name")
        continue
    fi

    ((CHECKED_COUNT++))

    # Compare content
    local_content=$(cat "$local_file")
    if [[ "$vault_content" == "$local_content" ]]; then
        pass "$item_name: ✓ in sync"
    else
        warn "$item_name: ⚠ DIFFERS from vault"
        ((DRIFT_COUNT++))
        DRIFTED_ITEMS+=("$item_name")
    fi
done

# ============================================================
# Section 5: Summary & Recommendations
# ============================================================
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
echo ""

if [[ $DRIFT_COUNT -eq 0 && $MISSING_VAULT -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}  ✓ All items in sync!${NC}"
    echo ""
    echo -e "  ${CHECKED_COUNT} items checked, no drift detected"
else
    if [[ $DRIFT_COUNT -gt 0 ]]; then
        echo -e "${YELLOW}${BOLD}  ⚠ Drift detected: $DRIFT_COUNT items differ${NC}"
    fi
    if [[ $MISSING_VAULT -gt 0 ]]; then
        echo -e "${YELLOW}${BOLD}  ⚠ Not in vault: $MISSING_VAULT items${NC}"
    fi
    echo ""

    echo -e "${BOLD}  Affected items:${NC}"
    for item in "${DRIFTED_ITEMS[@]}"; do
        echo -e "    • $item"
    done
fi

if [[ $MISSING_LOCAL -gt 0 ]]; then
    echo ""
    echo -e "${DIM}  $MISSING_LOCAL items not found locally (not installed yet)${NC}"
fi

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
echo ""

# ============================================================
# Next Actions
# ============================================================
if [[ $DRIFT_COUNT -gt 0 || $MISSING_VAULT -gt 0 ]]; then
    echo -e "${BOLD}Next Actions:${NC}"
    echo ""

    if [[ $DRIFT_COUNT -gt 0 ]]; then
        echo -e "  ${CYAN}Option 1:${NC} Save local changes to vault"
        echo -e "    ${GREEN}→${NC} dotfiles vault push --all"
        echo ""
    fi

    if [[ $MISSING_VAULT -gt 0 ]]; then
        echo -e "  ${CYAN}Option 2:${NC} Scan and push new items to vault"
        echo -e "    ${GREEN}→${NC} dotfiles vault scan"
        echo -e "    ${GREEN}→${NC} dotfiles vault push --all"
        echo ""
    fi

    if [[ $DRIFT_COUNT -gt 0 ]]; then
        echo -e "  ${CYAN}Option 3:${NC} Restore from vault (discard local changes)"
        echo -e "    ${GREEN}→${NC} dotfiles backup create ${DIM}# Safety first${NC}"
        echo -e "    ${GREEN}→${NC} dotfiles vault pull --force"
        echo ""
    fi

    echo -e "  ${CYAN}Option 4:${NC} View detailed diff"
    echo -e "    ${GREEN}→${NC} dotfiles drift"
    echo ""
fi

echo -e "${DIM}Full documentation: https://github.com/blackwell-systems/dotfiles/blob/main/docs/vault-README.md${NC}"
echo ""

# Exit with status code
if [[ $DRIFT_COUNT -gt 0 || $MISSING_VAULT -gt 0 ]]; then
    exit 1
else
    exit 0
fi
