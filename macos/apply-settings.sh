#!/usr/bin/env bash
#
# apply-settings.sh - Apply macOS system settings
#
# Usage:
#   ./apply-settings.sh           # Apply settings from settings.sh
#   ./apply-settings.sh --dry-run # Show what would be applied
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_FILE="$SCRIPT_DIR/settings.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check we're on macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${RED}Error: This script only runs on macOS${NC}"
    exit 1
fi

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run    Show settings that would be applied"
    echo "  --backup     Create snapshot before applying"
    echo "  -h, --help   Show this help"
    echo ""
    echo "This script applies macOS settings from settings.sh"
    echo ""
    echo "To generate settings.sh from your current preferences:"
    echo "  ./discover-settings.sh --generate"
}

dry_run() {
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        echo -e "${RED}Error: $SETTINGS_FILE not found${NC}"
        echo "Generate it with: ./discover-settings.sh --generate"
        exit 1
    fi

    echo -e "${BLUE}Settings that would be applied:${NC}"
    echo ""
    grep -E "^defaults write" "$SETTINGS_FILE" | while read -r line; do
        echo "  $line"
    done
    echo ""
    echo -e "${YELLOW}Run without --dry-run to apply these settings.${NC}"
}

backup() {
    echo -e "${BLUE}Creating backup snapshot...${NC}"
    "$SCRIPT_DIR/discover-settings.sh" --snapshot
}

apply() {
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        echo -e "${RED}Error: $SETTINGS_FILE not found${NC}"
        echo ""
        echo "Generate it with: ./discover-settings.sh --generate"
        echo ""
        echo "Or create it manually. Example:"
        echo '  defaults write com.apple.dock autohide -bool true'
        exit 1
    fi

    echo -e "${BLUE}Applying macOS settings...${NC}"
    echo ""

    # Source the settings file to apply
    source "$SETTINGS_FILE"

    echo ""
    echo -e "${GREEN}Settings applied!${NC}"
    echo ""
    echo "Note: Some settings require logout or restart to take effect."
}

# Main
case "${1:-}" in
    --dry-run)
        dry_run
        ;;
    --backup)
        backup
        apply
        ;;
    -h|--help)
        usage
        ;;
    "")
        apply
        ;;
    *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
esac
