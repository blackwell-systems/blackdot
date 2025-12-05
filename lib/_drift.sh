#!/usr/bin/env zsh
# ============================================================
# FILE: lib/_drift.sh
# Fast drift detection for shell startup
# Compares local files against cached checksums (no vault access needed)
# ============================================================

# Prevent multiple sourcing
[[ -n "${_DRIFT_LOADED:-}" ]] && return 0
_DRIFT_LOADED=1

# ============================================================
# Configuration
# ============================================================

DRIFT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
DRIFT_STATE_FILE="$DRIFT_CACHE_DIR/vault-state.json"

# Items to track for drift (matches DRIFT_ITEMS in dotfiles-drift)
typeset -A DRIFT_TRACKED_FILES=(
    ["SSH-Config"]="$HOME/.ssh/config"
    ["AWS-Config"]="$HOME/.aws/config"
    ["AWS-Credentials"]="$HOME/.aws/credentials"
    ["Git-Config"]="$HOME/.gitconfig"
    ["Environment-Secrets"]="$HOME/.local/env.secrets"
    ["Template-Variables"]="$HOME/.config/dotfiles/template-variables.sh"
)

# ============================================================
# Checksum Functions
# ============================================================

# Get SHA256 checksum of a file (portable across macOS/Linux)
_drift_checksum() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "MISSING"
        return
    fi

    # Use shasum (macOS) or sha256sum (Linux)
    if command -v shasum &>/dev/null; then
        shasum -a 256 "$file" 2>/dev/null | cut -d' ' -f1
    elif command -v sha256sum &>/dev/null; then
        sha256sum "$file" 2>/dev/null | cut -d' ' -f1
    else
        # Fallback to md5
        if command -v md5 &>/dev/null; then
            md5 -q "$file" 2>/dev/null
        elif command -v md5sum &>/dev/null; then
            md5sum "$file" 2>/dev/null | cut -d' ' -f1
        else
            echo "NO_HASH_TOOL"
        fi
    fi
}

# ============================================================
# State Management
# ============================================================

# Save current state of all tracked files
# Called after vault pull to record "known good" state
drift_save_state() {
    mkdir -p "$DRIFT_CACHE_DIR"

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S")
    local hostname=$(hostname 2>/dev/null || echo "unknown")

    # Build JSON with checksums
    local json="{\n"
    json+="  \"timestamp\": \"$timestamp\",\n"
    json+="  \"hostname\": \"$hostname\",\n"
    json+="  \"files\": {\n"

    local first=true
    for item_name in "${(@k)DRIFT_TRACKED_FILES}"; do
        local file_path="${DRIFT_TRACKED_FILES[$item_name]}"
        local checksum=$(_drift_checksum "$file_path")

        [[ "$first" == "true" ]] || json+=",\n"
        first=false
        json+="    \"$item_name\": {\n"
        json+="      \"path\": \"$file_path\",\n"
        json+="      \"checksum\": \"$checksum\"\n"
        json+="    }"
    done

    json+="\n  }\n}"

    echo -e "$json" > "$DRIFT_STATE_FILE"
    chmod 600 "$DRIFT_STATE_FILE"
}

# Check if state file exists and is recent
drift_has_state() {
    [[ -f "$DRIFT_STATE_FILE" ]]
}

# Get timestamp of last saved state
drift_state_age() {
    if [[ ! -f "$DRIFT_STATE_FILE" ]]; then
        echo "never"
        return
    fi

    if command -v jq &>/dev/null; then
        jq -r '.timestamp // "unknown"' "$DRIFT_STATE_FILE" 2>/dev/null
    else
        echo "unknown"
    fi
}

# ============================================================
# Quick Drift Check (for shell startup)
# ============================================================

# Fast drift check - compares local files against cached state
# Returns 0 if in sync, 1 if drift detected, 2 if no state available
# Output: prints warning messages for drifted files
drift_check_quick() {
    local silent="${1:-false}"

    # No state file = nothing to compare against
    if [[ ! -f "$DRIFT_STATE_FILE" ]]; then
        return 2
    fi

    # Need jq to read state
    if ! command -v jq &>/dev/null; then
        return 2
    fi

    local drift_count=0
    local drifted_items=()

    for item_name in "${(@k)DRIFT_TRACKED_FILES}"; do
        local file_path="${DRIFT_TRACKED_FILES[$item_name]}"

        # Get cached checksum
        local cached_checksum=$(jq -r ".files[\"$item_name\"].checksum // empty" "$DRIFT_STATE_FILE" 2>/dev/null)

        # Skip if no cached checksum for this item
        [[ -z "$cached_checksum" ]] && continue

        # Get current checksum
        local current_checksum=$(_drift_checksum "$file_path")

        # Compare
        if [[ "$cached_checksum" != "$current_checksum" ]]; then
            drift_count=$((drift_count + 1))
            drifted_items+=("$item_name")
        fi
    done

    # Report drift
    if [[ $drift_count -gt 0 ]]; then
        if [[ "$silent" != "true" ]]; then
            echo ""
            echo -e "\033[0;33m⚠ Drift detected:\033[0m ${drifted_items[*]}"
            echo -e "  \033[2mRun: dotfiles drift (to compare) or dotfiles vault pull (to restore)\033[0m"
        fi
        return 1
    fi

    return 0
}

# Verbose drift check with details
drift_check_verbose() {
    if [[ ! -f "$DRIFT_STATE_FILE" ]]; then
        echo "No drift state available. Run 'dotfiles vault pull' first."
        return 2
    fi

    echo "Drift Check (local vs last vault pull)"
    echo "======================================="
    echo "Last sync: $(drift_state_age)"
    echo ""

    local drift_count=0
    local checked_count=0

    for item_name in "${(@k)DRIFT_TRACKED_FILES}"; do
        local file_path="${DRIFT_TRACKED_FILES[$item_name]}"

        local cached_checksum=$(jq -r ".files[\"$item_name\"].checksum // empty" "$DRIFT_STATE_FILE" 2>/dev/null)
        [[ -z "$cached_checksum" ]] && continue

        checked_count=$((checked_count + 1))
        local current_checksum=$(_drift_checksum "$file_path")

        if [[ "$cached_checksum" == "$current_checksum" ]]; then
            echo -e "\033[0;32m✓\033[0m $item_name: in sync"
        elif [[ "$current_checksum" == "MISSING" ]]; then
            echo -e "\033[0;33m!\033[0m $item_name: file missing (was synced)"
            drift_count=$((drift_count + 1))
        else
            echo -e "\033[0;33m✗\033[0m $item_name: CHANGED locally"
            drift_count=$((drift_count + 1))
        fi
    done

    echo ""
    if [[ $drift_count -eq 0 ]]; then
        echo -e "\033[0;32mAll $checked_count items in sync with last vault pull\033[0m"
    else
        echo -e "\033[0;33m$drift_count of $checked_count items have local changes\033[0m"
        echo ""
        echo "Options:"
        echo "  dotfiles vault push --all  # Push local changes to vault"
        echo "  dotfiles vault pull        # Overwrite local with vault"
    fi

    return $drift_count
}

# ============================================================
# Shell Startup Integration
# ============================================================

# Quick check for shell startup - minimal output, fast
# Usage: drift_startup_check
drift_startup_check() {
    # Skip if disabled
    if [[ "${DOTFILES_SKIP_DRIFT_CHECK:-}" == "1" ]]; then
        return 0
    fi

    # Skip if no state (user hasn't done vault pull yet)
    if ! drift_has_state; then
        return 0
    fi

    # Run quick check (will print warning if drift detected)
    drift_check_quick false
    return 0  # Don't fail shell startup
}
