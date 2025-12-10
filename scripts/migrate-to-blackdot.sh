#!/bin/bash
# =============================================================================
# migrate-to-blackdot.sh - Migrate from dotfiles to blackdot
# =============================================================================
# Usage: curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/scripts/migrate-to-blackdot.sh | bash
# Or:    ./scripts/migrate-to-blackdot.sh
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
pass()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
fail()  { echo -e "${RED}[✗]${NC} $*"; }

declare -a CHANGES=()
declare -a MANUAL_STEPS=()

echo ""
echo "=========================================="
echo "  Migrate: dotfiles → blackdot"
echo "=========================================="
echo ""

# 1. Config directory
info "Checking config directory..."
OLD_CONFIG="$HOME/.config/dotfiles"
NEW_CONFIG="$HOME/.config/blackdot"

if [[ -d "$OLD_CONFIG" && ! -d "$NEW_CONFIG" ]]; then
    mv "$OLD_CONFIG" "$NEW_CONFIG"
    pass "Moved ~/.config/dotfiles → ~/.config/blackdot"
    CHANGES+=("Config directory migrated")
elif [[ -d "$OLD_CONFIG" && -d "$NEW_CONFIG" ]]; then
    warn "Both configs exist - merging..."
    for file in "$OLD_CONFIG"/*; do
        [[ -e "$file" ]] || continue
        filename=$(basename "$file")
        [[ ! -e "$NEW_CONFIG/$filename" ]] && cp -r "$file" "$NEW_CONFIG/"
    done
    MANUAL_STEPS+=("Remove old config: rm -rf ~/.config/dotfiles")
elif [[ -d "$NEW_CONFIG" ]]; then
    pass "Config already at ~/.config/blackdot"
fi

# 2. Backup directory
info "Checking backup directory..."
OLD_BACKUPS="$HOME/.dotfiles-backups"
NEW_BACKUPS="$HOME/.blackdot-backups"

if [[ -d "$OLD_BACKUPS" && ! -d "$NEW_BACKUPS" ]]; then
    mv "$OLD_BACKUPS" "$NEW_BACKUPS"
    pass "Moved ~/.dotfiles-backups → ~/.blackdot-backups"
    CHANGES+=("Backup directory migrated")
elif [[ -d "$OLD_BACKUPS" && -d "$NEW_BACKUPS" ]]; then
    warn "Both backup directories exist"
    MANUAL_STEPS+=("Merge backups manually")
fi

# 3. Metrics file
info "Checking metrics file..."
OLD_METRICS="$HOME/.dotfiles-metrics.jsonl"
NEW_METRICS="$HOME/.blackdot-metrics.jsonl"

if [[ -f "$OLD_METRICS" && ! -f "$NEW_METRICS" ]]; then
    mv "$OLD_METRICS" "$NEW_METRICS"
    pass "Moved metrics file"
    CHANGES+=("Metrics migrated")
elif [[ -f "$OLD_METRICS" && -f "$NEW_METRICS" ]]; then
    cat "$OLD_METRICS" >> "$NEW_METRICS"
    rm "$OLD_METRICS"
    pass "Merged metrics files"
fi

# 4. Cache directory
info "Checking cache..."
OLD_CACHE="$HOME/.cache/dotfiles"
[[ -d "$OLD_CACHE" ]] && rm -rf "$OLD_CACHE" && pass "Removed old cache"

# 5. Update .zshrc
info "Checking ~/.zshrc..."
ZSHRC="$HOME/.zshrc"

if [[ -f "$ZSHRC" ]]; then
    if grep -qE "DOTFILES_DIR|dotfiles shell-init|\.dotfiles" "$ZSHRC" 2>/dev/null; then
        cp "$ZSHRC" "$HOME/.zshrc.pre-blackdot"
        pass "Backed up ~/.zshrc"
        
        sed -i.bak \
            -e 's/DOTFILES_DIR/BLACKDOT_DIR/g' \
            -e 's/dotfiles shell-init/blackdot shell-init/g' \
            -e 's/\.dotfiles/.blackdot/g' \
            -e 's|bin/dotfiles|bin/blackdot|g' \
            "$ZSHRC"
        rm -f "${ZSHRC}.bak"
        pass "Updated ~/.zshrc"
        CHANGES+=("~/.zshrc updated")
    else
        pass "~/.zshrc already updated"
    fi
fi

# 6. Project configs
info "Checking project configs..."
for dir in "$HOME/workspace" "$HOME/projects" "$HOME"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' config; do
        newconfig="${config%.dotfiles.json}.blackdot.json"
        if [[ ! -f "$newconfig" ]]; then
            mv "$config" "$newconfig"
            pass "Renamed: $config"
            CHANGES+=("Project config renamed")
        fi
    done < <(find "$dir" -maxdepth 3 -name ".dotfiles.json" -print0 2>/dev/null)
done

# 7. Clear completion cache
ZSH_COMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump"
[[ -f "$ZSH_COMPDUMP" ]] && rm -f "$ZSH_COMPDUMP"* && pass "Cleared completion cache"

# Summary
echo ""
echo "=========================================="
echo "  Migration Summary"
echo "=========================================="
echo ""

if [[ ${#CHANGES[@]} -gt 0 ]]; then
    echo -e "${GREEN}Changes made:${NC}"
    for c in "${CHANGES[@]}"; do echo "  ✓ $c"; done
    echo ""
fi

if [[ ${#MANUAL_STEPS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Manual steps:${NC}"
    for s in "${MANUAL_STEPS[@]}"; do echo "  → $s"; done
    echo ""
fi

echo -e "${BLUE}Next steps:${NC}"
echo "  1. Restart terminal: exec zsh"
echo "  2. Verify: blackdot doctor"
echo ""
