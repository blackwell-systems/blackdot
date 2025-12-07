#!/usr/bin/env zsh
# ============================================================
# FILE: lib/_colors.sh
# Centralized color theme for dotfiles
#
# This file provides consistent color definitions across all
# dotfiles modules. Source this file to use themed colors.
#
# Usage:
#   source "${DOTFILES_DIR:-$HOME/workspace/dotfiles}/lib/_colors.sh"
#
# Semantic colors:
#   $CLR_PRIMARY, $CLR_SECONDARY, $CLR_SUCCESS, $CLR_ERROR,
#   $CLR_WARNING, $CLR_INFO, $CLR_MUTED, $CLR_BOLD, $CLR_NC
#
# Tool brand colors:
#   $CLR_RUST, $CLR_GO, $CLR_PYTHON, $CLR_AWS, $CLR_CDK, $CLR_SSH
# ============================================================

# Prevent multiple sourcing
[[ -n "${_COLORS_SOURCED:-}" ]] && return 0
_COLORS_SOURCED=1

# ============================================================
# Terminal Detection
# Only set colors if outputting to a terminal
# ============================================================
if [[ -t 1 ]]; then
    _colors_enabled=true
else
    _colors_enabled=false
fi

# ============================================================
# User Theme Override
# Source user's custom theme if it exists
# ============================================================
_user_theme="${HOME}/.config/dotfiles/theme.sh"

# ============================================================
# Default Theme - Semantic Colors
# These describe WHAT the color means, not what it looks like
# ============================================================
if [[ "$_colors_enabled" == "true" ]]; then
    # Semantic colors (what the color represents)
    CLR_PRIMARY='\033[0;36m'      # Cyan - main accent, highlights
    CLR_SECONDARY='\033[0;33m'    # Yellow/Orange - secondary accent
    CLR_SUCCESS='\033[0;32m'      # Green - success, enabled, OK
    CLR_ERROR='\033[0;31m'        # Red - errors, failures, disabled
    CLR_WARNING='\033[0;33m'      # Yellow - warnings, caution
    CLR_INFO='\033[0;34m'         # Blue - informational
    CLR_MUTED='\033[2m'           # Dim - secondary text, less important
    CLR_BOLD='\033[1m'            # Bold - emphasis
    CLR_NC='\033[0m'              # No Color - reset

    # Tool-specific brand colors
    # These match the official brand colors of each tool
    CLR_RUST='\033[0;33m'         # Orange (Rust's brand color)
    CLR_GO='\033[0;36m'           # Cyan/Teal (Go's gopher blue)
    CLR_PYTHON='\033[0;34m'       # Blue (Python's blue)
    CLR_AWS='\033[0;33m'          # Orange (AWS's orange)
    CLR_CDK='\033[0;32m'          # Green (CDK/CloudFormation green)
    CLR_NODE='\033[0;32m'         # Green (Node.js green)
    CLR_JAVA='\033[0;31m'         # Red (Java red)
    CLR_SSH='\033[0;35m'          # Magenta (SSH/security purple)

    # Box drawing colors (for styled help output)
    CLR_BOX='\033[2m'             # Dim for box borders
    CLR_HEADER='\033[1;36m'       # Bold cyan for headers
else
    # No colors when not in terminal
    CLR_PRIMARY=''
    CLR_SECONDARY=''
    CLR_SUCCESS=''
    CLR_ERROR=''
    CLR_WARNING=''
    CLR_INFO=''
    CLR_MUTED=''
    CLR_BOLD=''
    CLR_NC=''
    CLR_RUST=''
    CLR_GO=''
    CLR_PYTHON=''
    CLR_AWS=''
    CLR_CDK=''
    CLR_NODE=''
    CLR_JAVA=''
    CLR_SSH=''
    CLR_BOX=''
    CLR_HEADER=''
fi

# ============================================================
# Load User Theme Override (if exists)
# User theme can override any of the above colors
# ============================================================
if [[ -f "$_user_theme" ]]; then
    source "$_user_theme"
fi

# ============================================================
# Export for subshells
# ============================================================
export CLR_PRIMARY CLR_SECONDARY CLR_SUCCESS CLR_ERROR
export CLR_WARNING CLR_INFO CLR_MUTED CLR_BOLD CLR_NC
export CLR_RUST CLR_GO CLR_PYTHON CLR_AWS CLR_CDK CLR_NODE CLR_JAVA CLR_SSH
export CLR_BOX CLR_HEADER

# ============================================================
# Backward Compatibility
# Map to legacy variable names from _logging.sh
# ============================================================
RED="$CLR_ERROR"
GREEN="$CLR_SUCCESS"
YELLOW="$CLR_WARNING"
BLUE="$CLR_INFO"
CYAN="$CLR_PRIMARY"
MAGENTA='\033[0;35m'
BOLD="$CLR_BOLD"
DIM="$CLR_MUTED"
NC="$CLR_NC"

export RED GREEN YELLOW BLUE CYAN MAGENTA BOLD DIM NC
