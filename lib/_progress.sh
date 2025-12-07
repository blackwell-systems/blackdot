#!/usr/bin/env zsh
# ============================================================
# FILE: lib/_progress.sh
# Progress indicators for long-running operations
#
# Provides spinners and progress bars for CLI feedback.
#
# Usage:
#   source "${DOTFILES_DIR:-$HOME/workspace/dotfiles}/lib/_progress.sh"
#
# Spinner (for unknown duration):
#   spinner_start "Installing packages"
#   some_long_command
#   spinner_stop
#
# Progress bar (for countable items):
#   for i in {1..10}; do
#       progress_bar $i 10 "Processing item $i"
#       do_something
#   done
#   progress_done "Completed 10 items"
#
# Run with command:
#   run_with_spinner "message" command args...
# ============================================================

# Prevent multiple sourcing
[[ -n "${_PROGRESS_SOURCED:-}" ]] && return 0
_PROGRESS_SOURCED=1

# Source colors if available
if [[ -f "${DOTFILES_DIR:-$HOME/workspace/dotfiles}/lib/_colors.sh" ]]; then
    source "${DOTFILES_DIR:-$HOME/workspace/dotfiles}/lib/_colors.sh"
else
    # Fallback colors
    CLR_PRIMARY='\033[0;36m'
    CLR_SUCCESS='\033[0;32m'
    CLR_MUTED='\033[2m'
    CLR_NC='\033[0m'
fi

# ============================================================
# Configuration
# ============================================================

# Check if we should show progress (TTY and not disabled)
_progress_enabled() {
    # Force mode for testing
    [[ "${DOTFILES_PROGRESS_FORCE:-}" == "true" ]] && return 0

    # Disabled via config
    [[ "${DOTFILES_PROGRESS:-true}" == "false" ]] && return 1

    # Not a terminal
    [[ ! -t 1 ]] && return 1

    # CI environment
    [[ -n "${CI:-}" ]] && return 1

    return 0
}

# Unicode or ASCII mode
_progress_unicode() {
    [[ "${DOTFILES_UNICODE:-true}" == "true" ]] && return 0
    return 1
}

# ============================================================
# Spinner
# ============================================================

# Spinner state
typeset -g _SPINNER_PID=""
typeset -g _SPINNER_MSG=""

# Spinner frames (braille dots animation)
# Set dynamically to avoid escaping issues at source time
_SPINNER_FRAMES=""

_get_spinner_frames() {
    if _progress_unicode; then
        echo '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    else
        echo '|/-\\'
    fi
}

# Start a spinner in the background
# Usage: spinner_start "message"
spinner_start() {
    local msg="${1:-Working}"
    _SPINNER_MSG="$msg"

    # Don't start if progress is disabled
    _progress_enabled || return 0

    # Kill any existing spinner
    spinner_stop 2>/dev/null

    # Start spinner in background subshell
    (
        local frames="$(_get_spinner_frames)"
        local frame_count=${#frames}
        local i=0

        # Hide cursor
        printf '\033[?25l'

        while true; do
            local frame="${frames:$i:1}"
            printf "\r${CLR_PRIMARY}%s${CLR_NC} %s..." "$frame" "$msg"
            i=$(( (i + 1) % frame_count ))
            sleep 0.1
        done
    ) &
    _SPINNER_PID=$!

    # Ensure spinner is killed on script exit
    trap 'spinner_stop 2>/dev/null' EXIT INT TERM
}

# Stop the spinner
# Usage: spinner_stop [success_message]
spinner_stop() {
    local success_msg="${1:-}"

    # Kill spinner process if running
    if [[ -n "${_SPINNER_PID:-}" ]] && kill -0 "$_SPINNER_PID" 2>/dev/null; then
        kill "$_SPINNER_PID" 2>/dev/null
        wait "$_SPINNER_PID" 2>/dev/null
    fi
    _SPINNER_PID=""

    # Only clear if progress was enabled
    _progress_enabled || return 0

    # Show cursor
    printf '\033[?25h'

    # Clear the line
    printf "\r\033[K"

    # Show success message if provided
    if [[ -n "$success_msg" ]]; then
        printf "${CLR_SUCCESS}✓${CLR_NC} %s\n" "$success_msg"
    fi
}

# Run a command with a spinner
# Usage: run_with_spinner "message" command [args...]
# Returns: exit code of command
run_with_spinner() {
    local msg="$1"
    shift

    spinner_start "$msg"

    # Run command, capture exit code
    local output
    local exit_code
    output=$("$@" 2>&1)
    exit_code=$?

    spinner_stop

    # On failure, show output
    if [[ $exit_code -ne 0 ]]; then
        printf "${CLR_ERROR:-\033[0;31m}✗${CLR_NC} %s failed\n" "$msg"
        [[ -n "$output" ]] && printf "%s\n" "$output"
    fi

    return $exit_code
}

# ============================================================
# Progress Bar
# ============================================================

# Progress bar state
typeset -g _PROGRESS_START_TIME=""
typeset -g _PROGRESS_LAST_UPDATE=0

# Draw a progress bar
# Usage: progress_bar current total [label]
# Example: progress_bar 5 10 "Processing files"
progress_bar() {
    local current="${1:-0}"
    local total="${2:-100}"
    local label="${3:-}"

    # Don't show if progress is disabled
    _progress_enabled || return 0

    # Avoid division by zero
    [[ $total -eq 0 ]] && total=1

    # Calculate percentage
    local percent=$((current * 100 / total))
    [[ $percent -gt 100 ]] && percent=100

    # Bar dimensions
    local width=30
    local filled=$((current * width / total))
    [[ $filled -gt $width ]] && filled=$width
    local empty=$((width - filled))

    # Build the bar
    local bar_filled=""
    local bar_empty=""

    if _progress_unicode; then
        # Unicode blocks
        local i
        for ((i=0; i<filled; i++)); do bar_filled+="█"; done
        for ((i=0; i<empty; i++)); do bar_empty+="░"; done
    else
        # ASCII fallback
        local i
        for ((i=0; i<filled; i++)); do bar_filled+="="; done
        for ((i=0; i<empty; i++)); do bar_empty+=" "; done
    fi

    # Calculate ETA if we have timing info
    local eta=""
    if [[ -n "$_PROGRESS_START_TIME" ]] && [[ $current -gt 0 ]]; then
        local elapsed=$((SECONDS - _PROGRESS_START_TIME))
        local rate=$((elapsed * 1000 / current))  # ms per item
        local remaining=$(( (total - current) * rate / 1000 ))
        if [[ $remaining -gt 0 ]]; then
            if [[ $remaining -gt 60 ]]; then
                eta=" ETA: $((remaining / 60))m$((remaining % 60))s"
            else
                eta=" ETA: ${remaining}s"
            fi
        fi
    fi

    # Hide cursor and print
    printf '\033[?25l'
    printf "\r${CLR_MUTED}[${CLR_NC}${CLR_PRIMARY}%s${CLR_NC}${CLR_MUTED}%s${CLR_NC}${CLR_MUTED}]${CLR_NC} %3d%% %s%s" \
        "$bar_filled" "$bar_empty" "$percent" "$label" "$eta"
}

# Initialize progress tracking (call before first progress_bar)
# Usage: progress_init
progress_init() {
    _PROGRESS_START_TIME=$SECONDS
    _PROGRESS_LAST_UPDATE=0

    # Hide cursor
    _progress_enabled && printf '\033[?25l'
}

# Complete progress bar with final message
# Usage: progress_done "Completed N items"
progress_done() {
    local msg="${1:-Done}"

    _progress_enabled || {
        printf "%s\n" "$msg"
        return 0
    }

    # Show cursor
    printf '\033[?25h'

    # Clear line and show completion
    printf "\r\033[K${CLR_SUCCESS}✓${CLR_NC} %s\n" "$msg"

    # Reset state
    _PROGRESS_START_TIME=""
}

# ============================================================
# Stepped Progress (for multi-phase operations)
# ============================================================

typeset -g _STEP_CURRENT=0
typeset -g _STEP_TOTAL=0

# Initialize stepped progress
# Usage: steps_init 5 "Installing"
steps_init() {
    _STEP_TOTAL="${1:-1}"
    _STEP_CURRENT=0
    local title="${2:-Progress}"

    _progress_enabled || return 0

    printf "${CLR_MUTED}── %s ──${CLR_NC}\n" "$title"
}

# Show current step
# Usage: step "Downloading packages"
step() {
    local msg="$1"
    ((_STEP_CURRENT++))

    _progress_enabled || {
        printf "[%d/%d] %s\n" "$_STEP_CURRENT" "$_STEP_TOTAL" "$msg"
        return 0
    }

    printf "${CLR_MUTED}[%d/%d]${CLR_NC} %s\n" "$_STEP_CURRENT" "$_STEP_TOTAL" "$msg"
}

# Mark step as done
# Usage: step_done "Downloaded 5 packages"
step_done() {
    local msg="${1:-Done}"

    _progress_enabled || {
        printf "  ✓ %s\n" "$msg"
        return 0
    }

    printf "  ${CLR_SUCCESS}✓${CLR_NC} %s\n" "$msg"
}

# Mark step as failed
# Usage: step_fail "Download failed"
step_fail() {
    local msg="${1:-Failed}"

    _progress_enabled || {
        printf "  ✗ %s\n" "$msg"
        return 0
    }

    printf "  ${CLR_ERROR:-\033[0;31m}✗${CLR_NC} %s\n" "$msg"
}

# Complete all steps
# Usage: steps_done "Installation complete"
steps_done() {
    local msg="${1:-Complete}"

    _progress_enabled || {
        printf "── %s ──\n" "$msg"
        return 0
    }

    printf "${CLR_MUTED}──${CLR_NC} ${CLR_SUCCESS}%s${CLR_NC} ${CLR_MUTED}──${CLR_NC}\n" "$msg"
}

# ============================================================
# Cleanup
# ============================================================

# Ensure cursor is shown on exit
_progress_cleanup() {
    spinner_stop 2>/dev/null
    printf '\033[?25h' 2>/dev/null
}

trap '_progress_cleanup' EXIT

# ============================================================
# Export functions
# ============================================================

export -f spinner_start spinner_stop run_with_spinner 2>/dev/null || true
export -f progress_bar progress_init progress_done 2>/dev/null || true
export -f steps_init step step_done step_fail steps_done 2>/dev/null || true
