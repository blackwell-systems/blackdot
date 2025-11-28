#!/usr/bin/env zsh
# ============================================================
# FILE: dotfiles-drift.sh
# Compare local configuration files against Bitwarden vault
# Usage: ./dotfiles-drift.sh
#        dotfiles drift
# ============================================================
set -uo pipefail

# Colors for output (if terminal supports it)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

pass() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

echo ""
echo -e "${BLUE}=== Drift Detection (Local vs Bitwarden) ===${NC}"
echo ""

# Get Bitwarden session
VAULT_DIR="$HOME/workspace/dotfiles/vault"
SESSION="${BW_SESSION:-}"

if [[ -z "$SESSION" && -f "$VAULT_DIR/.bw-session" ]]; then
    SESSION="$(cat "$VAULT_DIR/.bw-session")"
fi

if [[ -z "$SESSION" ]] || ! bw unlock --check --session "$SESSION" >/dev/null 2>&1; then
    warn "Bitwarden not unlocked - cannot check drift"
    echo ""
    info "Run: export BW_SESSION=\"\$(bw unlock --raw)\""
    exit 1
fi

# Sync first
info "Syncing Bitwarden vault..."
bw sync --session "$SESSION" >/dev/null 2>&1

# Items to check for drift
typeset -A DRIFT_ITEMS=(
    ["SSH-Config"]="$HOME/.ssh/config"
    ["AWS-Config"]="$HOME/.aws/config"
    ["AWS-Credentials"]="$HOME/.aws/credentials"
    ["Git-Config"]="$HOME/.gitconfig"
    ["Environment-Secrets"]="$HOME/.local/env.secrets"
)

DRIFT_COUNT=0
CHECKED_COUNT=0

for item_name in "${(k)DRIFT_ITEMS[@]}"; do
    local_file="${DRIFT_ITEMS[$item_name]}"

    # Skip if local file doesn't exist
    if [[ ! -f "$local_file" ]]; then
        info "$item_name: local file not found ($local_file)"
        continue
    fi

    # Get Bitwarden content
    bw_content=$(bw get notes "$item_name" --session "$SESSION" 2>/dev/null || echo "")

    if [[ -z "$bw_content" ]]; then
        info "$item_name: not found in Bitwarden"
        continue
    fi

    ((CHECKED_COUNT++))

    # Compare
    local_content=$(cat "$local_file")
    if [[ "$bw_content" == "$local_content" ]]; then
        pass "$item_name: in sync"
    else
        warn "$item_name: LOCAL DIFFERS from Bitwarden"
        ((DRIFT_COUNT++))
    fi
done

echo ""
echo "========================================"
if [[ $DRIFT_COUNT -eq 0 ]]; then
    echo -e "${GREEN}All $CHECKED_COUNT checked items are in sync${NC}"
else
    echo -e "${YELLOW}$DRIFT_COUNT of $CHECKED_COUNT items have drifted${NC}"
    echo ""
    info "To sync local changes to Bitwarden:"
    echo "  ./vault/sync-to-bitwarden.sh --all"
    echo ""
    info "To restore from Bitwarden (overwrite local):"
    echo "  bw-restore"
fi
echo "========================================"
