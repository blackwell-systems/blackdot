#!/usr/bin/env bash
# ============================================================
# FILE: lib/_logging.sh
# Shared logging functions and color definitions for dotfiles scripts
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/_logging.sh"
#   # or for scripts in root:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/_logging.sh"
#
# Functions provided:
#   info()  - Blue informational message
#   pass()  - Green success message
#   warn()  - Yellow warning message
#   fail()  - Red error message
#   dry()   - Cyan dry-run message
#   debug() - Debug message (only when DEBUG=1)
#
# Color variables provided:
#   $RED, $GREEN, $YELLOW, $BLUE, $CYAN, $MAGENTA, $NC (no color)
# ============================================================

# Prevent multiple sourcing
if [[ -n "${_LOGGING_SOURCED:-}" ]]; then
    return 0
fi
_LOGGING_SOURCED=1

# ============================================================
# Color Definitions
# Only set colors if outputting to a terminal (not a pipe/file)
# ============================================================
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'  # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    BOLD=''
    NC=''
fi

# Export for subshells
export RED GREEN YELLOW BLUE MAGENTA CYAN BOLD NC

# ============================================================
# Logging Functions
# ============================================================

# Informational message (blue)
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Success message (green)
pass() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# Warning message (yellow)
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Error message (red)
fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Dry-run message (cyan)
dry() {
    echo -e "${CYAN}[DRY-RUN]${NC} $1"
}

# Debug message (only when DEBUG=1)
debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${MAGENTA}[DEBUG]${NC} $1" >&2
    fi
}

# ============================================================
# Helper Functions
# ============================================================

# Print a section header
section() {
    echo ""
    echo -e "${BOLD}=== $1 ===${NC}"
    echo ""
}

# Print a separator line
separator() {
    echo "────────────────────────────────────────"
}

# Confirm yes/no prompt (returns 0 for yes, 1 for no)
# Usage: if confirm "Are you sure?"; then ... fi
confirm() {
    local prompt="${1:-Continue?}"
    local response

    echo -en "${YELLOW}${prompt}${NC} [y/N] "
    read -r response

    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}
