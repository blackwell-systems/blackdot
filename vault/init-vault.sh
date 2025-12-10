#!/usr/bin/env zsh
# ============================================================
# FILE: vault/init-vault.sh
# Vault Setup Wizard v2
# Improved onboarding with location awareness and vault-first discovery
# Usage: ./init-vault.sh [--force] [--reconfigure]
#
# IDEMPOTENCY:
# - Safe to run multiple times
# - Detects existing config and offers: add items / reconfigure / cancel
# - Creates timestamped backups before any destructive operation
# - Never overwrites without explicit user confirmation
#
# INPUT VALIDATION:
# - All user inputs are sanitized (control chars, null bytes removed)
# - Location names validated (no path traversal, valid chars only)
# - File paths validated (must start with ~, /, or $)
# ============================================================
set -euo pipefail

# Determine script location
SCRIPT_DIR="$(cd "$(dirname "${0:a}")" && pwd)"
BLACKDOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source libraries
source "$BLACKDOT_DIR/lib/_logging.sh"
source "$BLACKDOT_DIR/lib/_vault.sh"
source "$BLACKDOT_DIR/lib/_config.sh"

# Configuration
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
VAULT_CONFIG="$CONFIG_DIR/vault-items.json"

# Parse arguments
FORCE=false
RECONFIGURE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|-f) FORCE=true; shift ;;
        --reconfigure|-r) RECONFIGURE=true; shift ;;
        --help|-h)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force, -f       Skip confirmation prompts"
            echo "  --reconfigure     Start fresh (backup existing config)"
            echo "  --help, -h        Show this help"
            exit 0
            ;;
        *) shift ;;
    esac
done

# ============================================================
# Helper Functions
# ============================================================

print_box() {
    local title="$1"
    local width=60
    echo ""
    echo -e "${BOLD}${CYAN}╔$(printf '═%.0s' {1..58})╗${NC}"
    printf "${BOLD}${CYAN}║${NC} %-56s ${BOLD}${CYAN}║${NC}\n" "$title"
    echo -e "${BOLD}${CYAN}╚$(printf '═%.0s' {1..58})╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BOLD}$1${NC}"
    echo -e "${DIM}$(printf '─%.0s' {1..50})${NC}"
}

# ============================================================
# Input Validation & Sanitization
# ============================================================

# Sanitize input: remove dangerous characters, trim whitespace
sanitize_input() {
    local input="$1"
    # Remove leading/trailing whitespace
    input="${input#"${input%%[![:space:]]*}"}"
    input="${input%"${input##*[![:space:]]}"}"
    # Remove null bytes and control characters (except newline/tab)
    input=$(printf '%s' "$input" | tr -d '\000-\010\013\014\016-\037')
    echo "$input"
}

# Validate vault location name (folder, vault, directory name)
# Allows: alphanumeric, hyphens, underscores, forward slashes (for paths)
validate_location_name() {
    local name="$1"
    local max_length="${2:-100}"

    # Check length
    if [[ ${#name} -gt $max_length ]]; then
        warn "Name too long (max $max_length characters)"
        return 1
    fi

    # Check for empty
    if [[ -z "$name" ]]; then
        warn "Name cannot be empty"
        return 1
    fi

    # Check for valid characters (alphanumeric, hyphen, underscore, slash, dot)
    if [[ ! "$name" =~ ^[A-Za-z0-9._/-]+$ ]]; then
        warn "Invalid characters in name. Use only: letters, numbers, hyphens, underscores, dots, slashes"
        return 1
    fi

    # Prevent path traversal
    if [[ "$name" == *".."* ]]; then
        warn "Path traversal (..) not allowed"
        return 1
    fi

    # Prevent absolute paths (should be relative to vault)
    if [[ "$name" == /* ]]; then
        warn "Absolute paths not allowed. Use relative path."
        return 1
    fi

    return 0
}

# Validate file path for local file mapping
validate_file_path() {
    local path="$1"

    # Allow ~ or absolute paths starting with /
    if [[ ! "$path" =~ ^[~/$] ]]; then
        warn "Path must start with ~, /, or \$"
        return 1
    fi

    # Prevent null bytes
    if [[ "$path" == *$'\0'* ]]; then
        warn "Invalid path"
        return 1
    fi

    return 0
}

# Validate item name matches our naming convention
validate_item_name() {
    local name="$1"

    if [[ ! "$name" =~ ^[A-Z][A-Za-z0-9_-]*$ ]]; then
        warn "Item name must start with capital letter, contain only alphanumeric, hyphens, underscores"
        return 1
    fi

    return 0
}

prompt_choice() {
    local prompt="$1"
    local default="$2"
    local result

    echo -n -e "${CYAN}?${NC} $prompt ${DIM}[$default]${NC}: "
    read result
    result=$(sanitize_input "${result:-$default}")
    echo "$result"
}

# Prompt for location name with validation
prompt_location_name() {
    local prompt="$1"
    local default="$2"
    local result

    while true; do
        echo -n -e "${CYAN}?${NC} $prompt ${DIM}[$default]${NC}: "
        read result
        result=$(sanitize_input "${result:-$default}")

        if validate_location_name "$result"; then
            echo "$result"
            return 0
        fi
        echo "  Please try again."
    done
}

# Prompt for file path with validation
prompt_file_path() {
    local prompt="$1"
    local default="$2"
    local result

    while true; do
        echo -n -e "${CYAN}?${NC} $prompt ${DIM}[$default]${NC}: "
        read result
        result=$(sanitize_input "${result:-$default}")

        if validate_file_path "$result"; then
            echo "$result"
            return 0
        fi
        echo "  Please try again."
    done
}

prompt_yesno() {
    local prompt="$1"
    local default="${2:-y}"
    local result

    if [[ "$default" == "y" ]]; then
        echo -n -e "${CYAN}?${NC} $prompt ${DIM}[Y/n]${NC}: "
    else
        echo -n -e "${CYAN}?${NC} $prompt ${DIM}[y/N]${NC}: "
    fi
    read result
    result=$(sanitize_input "${result:-$default}")
    [[ "$result" =~ ^[Yy] ]]
}

# ============================================================
# Phase 1: Education
# ============================================================

show_education() {
    print_box "How Vault Storage Works"

    cat <<EOF
This system stores your secrets as individual items in your
password vault. Each file (SSH key, config) becomes one item.

  ${DIM}┌─────────────────┐         ┌─────────────────────┐${NC}
  ${DIM}│ Local Machine   │  sync   │ Your Vault          │${NC}
  ${DIM}├─────────────────┤ ◄─────► ├─────────────────────┤${NC}
  ${DIM}│ ~/.ssh/key      │         │ "SSH-MyKey"         │${NC}
  ${DIM}│ ~/.aws/creds    │         │ "AWS-Credentials"   │${NC}
  ${DIM}│ ~/.gitconfig    │         │ "Git-Config"        │${NC}
  ${DIM}└─────────────────┘         └─────────────────────┘${NC}

${BOLD}Key points:${NC}
  • Item names can be anything you choose
  • We recommend organizing items in a dedicated folder
  • You control where items are stored and what they're named

EOF
}

# ============================================================
# Phase 2: Backend Selection
# ============================================================

select_backend() {
    print_section "Step 1: Select Vault Backend"

    # Detect available backends
    local -a available=()
    local -A backend_names=(
        [bitwarden]="Bitwarden"
        [1password]="1Password"
        [pass]="pass (GPG-based)"
    )

    command -v bw &>/dev/null && available+=(bitwarden)
    command -v op &>/dev/null && available+=(1password)
    command -v pass &>/dev/null && available+=(pass)

    if [[ ${#available[@]} -eq 0 ]]; then
        echo ""
        warn "No vault CLI detected."
        echo ""
        echo "Supported vault backends:"
        echo "  • Bitwarden:  ${GREEN}brew install bitwarden-cli${NC}"
        echo "  • 1Password:  ${GREEN}brew install 1password-cli${NC}"
        echo "  • pass:       ${GREEN}brew install pass${NC}"
        echo ""

        if prompt_yesno "Skip vault setup for now?" "y"; then
            config_set "vault.backend" "none"
            info "Vault setup skipped. Run 'dotfiles vault setup' anytime."
            exit 0
        else
            fail "Please install a vault CLI and try again"
            exit 1
        fi
    fi

    echo ""
    echo "Available vault backends:"
    local i=1
    for backend in "${available[@]}"; do
        echo "  ${GREEN}$i)${NC} ${backend_names[$backend]}"
        ((i++))
    done
    echo "  ${DIM}$i) Skip (configure later)${NC}"
    echo ""

    local choice
    choice=$(prompt_choice "Select backend" "1")

    # Validate choice
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        if [[ $choice -eq $i ]]; then
            config_set "vault.backend" "none"
            info "Vault setup skipped. Run 'dotfiles vault setup' anytime."
            exit 0
        elif [[ $choice -ge 1 && $choice -lt $i ]]; then
            SELECTED_BACKEND="${available[$choice]}"
            config_set "vault.backend" "$SELECTED_BACKEND"
            export BLACKDOT_VAULT_BACKEND="$SELECTED_BACKEND"
            pass "Backend set to: ${backend_names[$SELECTED_BACKEND]}"
        else
            fail "Invalid selection"
            exit 1
        fi
    else
        fail "Invalid selection"
        exit 1
    fi
}

# ============================================================
# Phase 3: Authentication Check
# ============================================================

check_authentication() {
    print_section "Step 2: Authentication"

    # Initialize backend
    if ! vault_init 2>/dev/null; then
        fail "Failed to initialize $SELECTED_BACKEND backend"
        exit 1
    fi

    # Check login status
    if ! vault_login_check; then
        echo ""
        warn "Not logged in to $(vault_name)"
        echo ""

        case "$SELECTED_BACKEND" in
            bitwarden)
                echo "Please log in first:"
                echo "  ${GREEN}bw login${NC}"
                echo ""
                echo "Then run setup again:"
                echo "  ${GREEN}dotfiles vault setup${NC}"
                ;;
            1password)
                echo "Please sign in first:"
                echo "  ${GREEN}op signin${NC}"
                ;;
            pass)
                echo "Please initialize pass:"
                echo "  ${GREEN}pass init <gpg-id>${NC}"
                ;;
        esac
        exit 1
    fi

    pass "Logged in to $(vault_name)"

    # Get session
    SESSION=$(vault_get_session 2>/dev/null || echo "")
    if [[ -z "$SESSION" && "$SELECTED_BACKEND" == "bitwarden" ]]; then
        warn "Vault is locked. Unlocking..."
        SESSION=$(vault_get_session)
    fi

    # Sync vault
    vault_sync "$SESSION" 2>/dev/null || true
}

# ============================================================
# Phase 4: Determine Starting Point
# ============================================================

determine_starting_point() {
    print_section "Step 3: Setup Type"

    echo ""
    echo "How would you like to set up vault integration?"
    echo ""
    echo "  ${GREEN}e)${NC} ${BOLD}Existing${NC}  - I have items in my vault already"
    echo "                ${DIM}(Import existing secrets, keep your naming)${NC}"
    echo ""
    echo "  ${GREEN}f)${NC} ${BOLD}Fresh${NC}     - I'm starting new, create from local files"
    echo "                ${DIM}(Scan local machine, push to vault)${NC}"
    echo ""
    echo "  ${GREEN}m)${NC} ${BOLD}Manual${NC}    - I'll configure everything myself"
    echo "                ${DIM}(Create template config, edit manually)${NC}"
    echo ""

    local choice
    choice=$(prompt_choice "Your choice" "e")

    case "${choice:0:1}" in
        e|E) SETUP_MODE="existing" ;;
        f|F) SETUP_MODE="fresh" ;;
        m|M) SETUP_MODE="manual" ;;
        *)
            warn "Invalid choice, defaulting to 'existing'"
            SETUP_MODE="existing"
            ;;
    esac
}

# ============================================================
# Phase 5A: Existing Items Flow
# ============================================================

setup_existing() {
    print_section "Import Existing Vault Items"

    # Ask where to look
    echo ""
    echo "Where are your dotfiles secrets stored?"
    echo ""

    case "$SELECTED_BACKEND" in
        bitwarden)
            echo "  ${GREEN}1)${NC} In a folder      ${DIM}(e.g., 'dotfiles' folder)${NC}"
            echo "  ${GREEN}2)${NC} By name prefix   ${DIM}(e.g., items starting with 'SSH-')${NC}"
            echo "  ${GREEN}3)${NC} Let me list them ${DIM}(type item names manually)${NC}"
            ;;
        1password)
            echo "  ${GREEN}1)${NC} In a vault       ${DIM}(e.g., 'Dotfiles' vault)${NC}"
            echo "  ${GREEN}2)${NC} By tag           ${DIM}(e.g., 'dotfiles' tag)${NC}"
            echo "  ${GREEN}3)${NC} Let me list them ${DIM}(type item names manually)${NC}"
            ;;
        pass)
            echo "  ${GREEN}1)${NC} In a directory   ${DIM}(e.g., 'dotfiles/' path)${NC}"
            echo "  ${GREEN}2)${NC} Let me list them ${DIM}(type item names manually)${NC}"
            ;;
    esac
    echo ""

    local loc_choice
    loc_choice=$(prompt_choice "Your choice" "1")

    local loc_type=""
    local loc_value=""
    local items_json="[]"

    case "$loc_choice" in
        1)
            # Folder/vault/directory based
            case "$SELECTED_BACKEND" in
                bitwarden)
                    loc_type="folder"
                    # List available folders
                    echo ""
                    echo "Available folders:"
                    local folders
                    folders=$(vault_list_locations "$SESSION")
                    if [[ "$folders" == "[]" || -z "$folders" ]]; then
                        echo "  ${DIM}(no folders found)${NC}"
                        echo ""
                        loc_value=$(prompt_location_name "Enter folder name to create" "dotfiles")
                    else
                        echo "$folders" | jq -r '.[]' | while read -r f; do
                            echo "  • $f"
                        done
                        echo ""
                        loc_value=$(prompt_location_name "Enter folder name" "dotfiles")
                    fi
                    ;;
                1password)
                    loc_type="vault"
                    loc_value=$(prompt_location_name "Enter vault name" "Personal")
                    ;;
                pass)
                    loc_type="directory"
                    loc_value=$(prompt_location_name "Enter directory path" "dotfiles")
                    ;;
            esac

            # Save location preference
            vault_set_location "$loc_type" "$loc_value" "$VAULT_CONFIG"
            pass "Location set: $loc_type = $loc_value"

            # List items in location
            echo ""
            info "Scanning $loc_type '$loc_value'..."
            items_json=$(vault_list_items_in_location "$loc_type" "$loc_value" "$SESSION" 2>/dev/null || echo "[]")
            ;;

        2)
            if [[ "$SELECTED_BACKEND" == "pass" ]]; then
                # pass doesn't support prefix, treat as manual
                setup_manual_item_list
                return
            fi

            # Prefix-based
            loc_type="prefix"
            echo ""
            loc_value=$(prompt_location_name "Enter name prefix" "SSH-")
            vault_set_location "$loc_type" "$loc_value" "$VAULT_CONFIG"

            echo ""
            info "Scanning for items starting with '$loc_value'..."
            items_json=$(vault_list_items_in_location "$loc_type" "$loc_value" "$SESSION" 2>/dev/null || echo "[]")
            ;;

        3|*)
            setup_manual_item_list
            return
            ;;
    esac

    # Process found items
    process_found_items "$items_json"
}

setup_manual_item_list() {
    echo ""
    echo "Enter the names of vault items to import (one per line)."
    echo "Press Enter on empty line when done."
    echo ""

    local -a item_names=()
    while true; do
        local name
        echo -n "  Item name: "
        read name
        [[ -z "$name" ]] && break
        item_names+=("$name")
    done

    if [[ ${#item_names[@]} -eq 0 ]]; then
        warn "No items specified"
        return
    fi

    # Build items JSON from names (using jq for proper escaping)
    local items_json="[]"
    for name in "${item_names[@]}"; do
        items_json=$(echo "$items_json" | jq --arg name "$name" '. + [{name: $name}]')
    done

    # No location preference for manual
    vault_set_location "none" "" "$VAULT_CONFIG"

    process_found_items "$items_json"
}

process_found_items() {
    local items_json="$1"
    local item_count

    item_count=$(echo "$items_json" | jq 'length')

    if [[ "$item_count" == "0" ]]; then
        echo ""
        warn "No items found in specified location."
        echo ""
        echo "Options:"
        echo "  ${GREEN}1)${NC} Scan local files instead (create new items)"
        echo "  ${GREEN}2)${NC} Try a different location"
        echo "  ${GREEN}3)${NC} Cancel"
        echo ""

        local choice
        choice=$(prompt_choice "Your choice" "1")

        case "$choice" in
            1) setup_fresh ;;
            2) setup_existing ;;
            *)
                info "Setup cancelled"
                exit 0
                ;;
        esac
        return
    fi

    echo ""
    echo "Found ${GREEN}$item_count${NC} items:"
    echo ""

    # Display items (read from array to avoid subshell)
    local -a item_names=()
    while IFS= read -r name; do
        [[ -n "$name" ]] && item_names+=("$name")
    done < <(echo "$items_json" | jq -r '.[].name')

    for name in "${item_names[@]}"; do
        echo "  • $name"
    done

    echo ""
    if ! prompt_yesno "Import these items?" "y"; then
        info "Setup cancelled"
        exit 0
    fi

    # Map items to local paths
    print_section "Map Items to Local Paths"

    echo ""
    echo "For each item, specify where it should be saved locally."
    echo "Press Enter to accept the suggested path."
    echo ""

    # Build vault_items JSON object
    local vault_items="{}"

    for name in "${item_names[@]}"; do
        local suggested_path=""
        local item_type="file"

        # Suggest paths based on name patterns
        case "$name" in
            SSH-Config|ssh-config)
                suggested_path="~/.ssh/config"
                ;;
            SSH-*)
                suggested_path="~/.ssh/id_ed25519_$(echo "$name" | sed 's/SSH-//' | tr '[:upper:]' '[:lower:]')"
                item_type="sshkey"
                ;;
            AWS-Credentials|aws-credentials)
                suggested_path="~/.aws/credentials"
                ;;
            AWS-Config|aws-config)
                suggested_path="~/.aws/config"
                ;;
            Git-Config|git-config)
                suggested_path="~/.gitconfig"
                ;;
            *)
                suggested_path="~/.config/$name"
                ;;
        esac

        echo -e "  ${BOLD}$name${NC}"
        local path
        path=$(prompt_file_path "    Local path" "$suggested_path")

        # Add to vault_items JSON (using jq for proper escaping)
        vault_items=$(echo "$vault_items" | jq \
            --arg name "$name" \
            --arg path "$path" \
            --arg type "$item_type" \
            '.[$name] = {path: $path, required: false, type: $type}')

        echo "    → $path ($item_type)"
        echo ""
    done

    # Finalize config with collected mappings
    finalize_config "$vault_items"
}

# ============================================================
# Phase 5B: Fresh Start Flow
# ============================================================

setup_fresh() {
    print_section "Create Items from Local Files"

    # Ask where to store
    echo ""
    echo "Where should we store your secrets?"
    echo ""

    local loc_type=""
    local loc_value=""

    case "$SELECTED_BACKEND" in
        bitwarden)
            echo "  ${GREEN}1)${NC} Create new folder 'dotfiles' ${DIM}(recommended)${NC}"
            echo "  ${GREEN}2)${NC} Use existing folder"
            echo "  ${GREEN}3)${NC} No folder (root level)"
            ;;
        1password)
            echo "  ${GREEN}1)${NC} Use 'Personal' vault ${DIM}(recommended)${NC}"
            echo "  ${GREEN}2)${NC} Use different vault"
            ;;
        pass)
            echo "  ${GREEN}1)${NC} Use 'dotfiles' directory ${DIM}(recommended)${NC}"
            echo "  ${GREEN}2)${NC} Use different directory"
            ;;
    esac
    echo ""

    local choice
    choice=$(prompt_choice "Your choice" "1")

    case "$choice" in
        1)
            case "$SELECTED_BACKEND" in
                bitwarden)
                    loc_type="folder"
                    loc_value="dotfiles"
                    # Create folder if needed
                    vault_create_location "$loc_value" "$SESSION" 2>/dev/null || true
                    ;;
                1password)
                    loc_type="vault"
                    loc_value="Personal"
                    ;;
                pass)
                    loc_type="directory"
                    loc_value="dotfiles"
                    ;;
            esac
            ;;
        2)
            case "$SELECTED_BACKEND" in
                bitwarden)
                    loc_type="folder"
                    loc_value=$(prompt_location_name "Enter folder name" "dotfiles")
                    ;;
                1password)
                    loc_type="vault"
                    loc_value=$(prompt_location_name "Enter vault name" "Personal")
                    ;;
                pass)
                    loc_type="directory"
                    loc_value=$(prompt_location_name "Enter directory path" "dotfiles")
                    ;;
            esac
            ;;
        3)
            loc_type="none"
            loc_value=""
            ;;
    esac

    # Save location preference
    vault_set_location "$loc_type" "$loc_value" "$VAULT_CONFIG"
    if [[ -n "$loc_value" ]]; then
        pass "Location set: $loc_type = $loc_value"
    fi

    # Scan local files
    echo ""
    info "Scanning for secrets in standard locations..."
    echo ""

    # Run discovery script
    "$SCRIPT_DIR/discover-secrets.sh" --location "$loc_type:$loc_value"
}

# ============================================================
# Phase 5C: Manual Flow
# ============================================================

setup_manual() {
    print_section "Manual Configuration"

    # Create template config
    mkdir -p "$CONFIG_DIR"

    if [[ -f "$VAULT_CONFIG" ]] && ! $FORCE; then
        warn "Config already exists: $VAULT_CONFIG"
        if ! prompt_yesno "Overwrite?" "n"; then
            info "Keeping existing config"
            exit 0
        fi
    fi

    # Copy example
    local example_file="$BLACKDOT_DIR/vault/vault-items.example.json"
    if [[ -f "$example_file" ]]; then
        cp "$example_file" "$VAULT_CONFIG"
        pass "Created config from template"
    else
        # Create minimal config
        vault_set_location "folder" "dotfiles" "$VAULT_CONFIG"
        pass "Created minimal config"
    fi

    echo ""
    echo "Configuration created at:"
    echo "  ${CYAN}$VAULT_CONFIG${NC}"
    echo ""
    echo "Edit this file to define your vault items:"
    echo "  ${GREEN}\$EDITOR $VAULT_CONFIG${NC}"
    echo ""
    echo "When ready, run:"
    echo "  ${GREEN}dotfiles vault pull${NC}    # Restore from vault"
    echo "  ${GREEN}dotfiles vault push${NC}    # Backup to vault"
}

# ============================================================
# Finalize Configuration
# ============================================================

finalize_config() {
    local vault_items_obj="${1:-{}}"

    # Write vault_items to config file
    if [[ -f "$VAULT_CONFIG" ]]; then
        # Update existing config with new vault_items
        local tmp_file="$VAULT_CONFIG.tmp"
        jq --argjson items "$vault_items_obj" '.vault_items = $items' \
            "$VAULT_CONFIG" > "$tmp_file" && mv "$tmp_file" "$VAULT_CONFIG"
    else
        # Create new config (should already exist from vault_set_location, but just in case)
        mkdir -p "$(dirname "$VAULT_CONFIG")"
        cat > "$VAULT_CONFIG" <<EOF
{
  "\$schema": "https://json-schema.org/draft/2020-12/schema",
  "\$comment": "Generated by vault setup wizard",
  "vault_location": {"type": "none", "value": null},
  "vault_items": $vault_items_obj,
  "ssh_keys": {},
  "syncable_items": {}
}
EOF
    fi

    print_section "Setup Complete"

    echo ""
    pass "Vault configuration saved!"
    echo ""
    echo "Configuration: ${CYAN}$VAULT_CONFIG${NC}"
    echo ""
    echo "Next steps:"
    echo "  ${GREEN}dotfiles vault pull${NC}    Pull secrets from vault"
    echo "  ${GREEN}dotfiles vault status${NC}  Check sync status"
    echo "  ${GREEN}dotfiles vault list${NC}    List all vault items"
    echo ""
}

# ============================================================
# Handle Reconfiguration
# ============================================================

handle_existing_config() {
    if [[ ! -f "$VAULT_CONFIG" ]]; then
        return 0  # No existing config
    fi

    if $RECONFIGURE; then
        # Backup and proceed
        local backup="$VAULT_CONFIG.backup-$(date +%Y%m%d%H%M%S)"
        cp "$VAULT_CONFIG" "$backup"
        info "Backed up existing config to: $backup"
        return 0
    fi

    if $FORCE; then
        return 0  # Skip check
    fi

    # Existing config found
    print_section "Existing Configuration Found"

    local backend loc_type loc_value
    backend=$(config_get "vault.backend" "unknown")
    loc_type=$(vault_get_location_type "$VAULT_CONFIG")
    loc_value=$(vault_get_location_value "$VAULT_CONFIG")

    echo ""
    echo "Current configuration:"
    echo "  Backend:  ${GREEN}$backend${NC}"
    if [[ -n "$loc_value" ]]; then
        echo "  Location: ${GREEN}$loc_type = $loc_value${NC}"
    fi
    echo ""

    echo "What would you like to do?"
    echo ""
    echo "  ${GREEN}1)${NC} Add new items   ${DIM}(keep existing, scan for more)${NC}"
    echo "  ${GREEN}2)${NC} Reconfigure     ${DIM}(backup current, start fresh)${NC}"
    echo "  ${GREEN}3)${NC} Cancel          ${DIM}(keep current config)${NC}"
    echo ""

    local choice
    choice=$(prompt_choice "Your choice" "1")

    case "$choice" in
        1)
            # Add new items - run discovery with merge
            "$SCRIPT_DIR/discover-secrets.sh" --merge
            exit $?
            ;;
        2)
            # Reconfigure
            local backup="$VAULT_CONFIG.backup-$(date +%Y%m%d%H%M%S)"
            cp "$VAULT_CONFIG" "$backup"
            info "Backed up to: $backup"
            rm "$VAULT_CONFIG"
            ;;
        *)
            info "Keeping current configuration"
            exit 0
            ;;
    esac
}

# ============================================================
# Main Flow
# ============================================================

main() {
    print_box "Vault Setup Wizard"

    # Check for existing config
    handle_existing_config

    # Show education
    show_education

    if ! prompt_yesno "Ready to continue?" "y"; then
        info "Setup cancelled"
        exit 0
    fi

    # Select backend
    select_backend

    # Check auth
    check_authentication

    # Determine setup type
    determine_starting_point

    # Run appropriate flow
    case "$SETUP_MODE" in
        existing) setup_existing ;;
        fresh)    setup_fresh ;;
        manual)   setup_manual ;;
    esac
}

# Run
main "$@"
