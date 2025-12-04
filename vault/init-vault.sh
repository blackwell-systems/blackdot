#!/usr/bin/env zsh
# ============================================================
# FILE: vault/init-vault.sh
# Initialize or reconfigure vault backend
# Usage: ./init-vault.sh [--force]
# ============================================================
set -euo pipefail

# Determine script location
SCRIPT_DIR="$(cd "$(dirname "${0:a}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# Source libraries
source "$DOTFILES_DIR/lib/_logging.sh"
source "$DOTFILES_DIR/lib/_vault.sh"

# Parse arguments
FORCE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE=true
fi

# Load config management (v3.0: use centralized JSON config)
source "$DOTFILES_DIR/lib/_config.sh"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"

# Wrapper functions for backward compatibility
config_get() {
    local section="$1"
    local key="$2"
    local default="${3:-}"

    # Convert to nested key format for v3.0
    local nested_key="${section}.${key}"
    command config_get "$nested_key" "$default"
}

config_set() {
    local section="$1"
    local key="$2"
    local value="$3"

    mkdir -p "$CONFIG_DIR"

    # Convert to nested key format for v3.0
    local nested_key="${section}.${key}"
    command config_set "$nested_key" "$value"

    # Keep INI compatibility (no-op for v3.0)
    if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
        echo "# Dotfiles Configuration" > "$CONFIG_FILE"
    fi

    # Check if section exists
    if ! grep -q "^\[$section\]" "$CONFIG_FILE" 2>/dev/null; then
        echo "" >> "$CONFIG_FILE"
        echo "[$section]" >> "$CONFIG_FILE"
    fi

    # Update or add key
    if grep -q "^$key=" "$CONFIG_FILE" 2>/dev/null; then
        sed -i.bak "s|^$key=.*|$key=$value|" "$CONFIG_FILE"
    else
        # Add after section header
        sed -i.bak "/^\[$section\]/a\\
$key=$value" "$CONFIG_FILE"
    fi
}

# Banner
echo ""
echo -e "${BOLD}${CYAN}Vault Configuration${NC}"
echo "═══════════════════════════════"
echo ""

# Check if already configured
current_backend=$(config_get "vault" "backend" "")
if [[ -n "$current_backend" ]] && [[ "$current_backend" != "none" ]] && ! $FORCE; then
    echo "Vault is already configured:"
    echo "  Backend: $current_backend"
    echo ""
    echo -n "Reconfigure vault? [y/N]: "
    read confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        info "Vault configuration unchanged"
        exit 0
    fi
    echo ""
fi

# Detect available vault backends
available=()
if command -v bw &>/dev/null; then
    available+=("bitwarden")
fi
if command -v op &>/dev/null; then
    available+=("1password")
fi
if command -v pass &>/dev/null; then
    available+=("pass")
fi

if [[ ${#available[@]} -eq 0 ]]; then
    echo "No vault CLI detected. Vault features are optional."
    echo ""
    echo "Supported vault backends:"
    echo "  • Bitwarden:  brew install bitwarden-cli"
    echo "  • 1Password:  brew install 1password-cli"
    echo "  • pass:       brew install pass"
    echo ""
    echo -n "Skip vault setup? [Y/n]: "
    read skip
    if [[ "${skip:-Y}" =~ ^[Yy]$ ]]; then
        warn "Vault setup skipped"
        config_set "vault" "backend" "none"
        echo ""
        info "Run 'dotfiles vault setup' anytime to configure vault"
        exit 0
    else
        fail "Please install a vault CLI and run 'dotfiles vault setup' again"
        exit 1
    fi
fi

echo "Available vault backends:"
for i in {1..${#available[@]}}; do
    echo "  $i) ${available[$i]}"
done
echo "  $((${#available[@]} + 1))) Skip (configure secrets manually)"
echo ""

echo -n "Select vault backend [1]: "
read choice
choice=${choice:-1}

# Check if user chose to skip
if [[ $choice -eq $((${#available[@]} + 1)) ]]; then
    warn "Vault setup skipped"
    config_set "vault" "backend" "none"
    echo ""
    info "Run 'dotfiles vault setup' anytime to configure vault"
    exit 0
fi

local selected="${available[$choice]}"
if [[ -z "$selected" ]]; then
    fail "Invalid selection"
    exit 1
fi

# Save preference
config_set "vault" "backend" "$selected"
export DOTFILES_VAULT_BACKEND="$selected"

pass "Vault backend set to: $selected"
echo ""

# Check/create vault items configuration
vault_config="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/vault-items.json"
vault_example="$DOTFILES_DIR/vault/vault-items.example.json"

if [[ ! -f "$vault_config" ]]; then
    echo "Vault items configuration needed."
    echo ""
    echo "This config defines which secrets to manage:"
    echo "  • SSH keys (names and paths)"
    echo "  • Config files (AWS, Git, etc.)"
    echo ""
    echo "Configuration options:"
    echo "  1) Auto-discover  - Scan standard locations (recommended)"
    echo "  2) Manual setup   - Copy example and edit manually"
    echo ""
    echo -n "Your choice [1]: "
    read config_choice
    config_choice=${config_choice:-1}

    # Create config directory
    mkdir -p "$(dirname "$vault_config")"

    if [[ "$config_choice" == "1" ]]; then
        # Auto-discovery
        echo ""
        info "Scanning for secrets in standard locations..."
        echo ""

        if "$SCRIPT_DIR/discover-secrets.sh"; then
            pass "Auto-discovery complete!"
            echo ""
            info "Review the generated config:"
            echo "  ${CYAN}cat $vault_config${NC}"
            echo ""
            echo -n "Edit config before syncing? [y/N]: "
            read edit_now
            if [[ "$edit_now" =~ ^[Yy]$ ]]; then
                ${EDITOR:-vim} "$vault_config"
            fi
        else
            warn "Auto-discovery found no items or failed"
            echo ""
            echo -n "Fall back to manual setup? [Y/n]: "
            read fallback
            if [[ ! "$fallback" =~ ^[Nn]$ ]]; then
                cp "$vault_example" "$vault_config"
                pass "Created $vault_config from example"
                echo ""
                info "Please customize the example file:"
                echo "  ${CYAN}\$EDITOR $vault_config${NC}"
            else
                fail "Vault items configuration not created"
                exit 1
            fi
        fi
    else
        # Manual setup
        if [[ -f "$vault_example" ]]; then
            cp "$vault_example" "$vault_config"
            pass "Created $vault_config"
            echo ""
            info "Please customize this file for your setup:"
            echo "  ${CYAN}\$EDITOR $vault_config${NC}"
            echo ""
            echo -n "Open editor now? [Y/n]: "
            read edit_now
            if [[ ! "$edit_now" =~ ^[Nn]$ ]]; then
                ${EDITOR:-vim} "$vault_config"
            fi
        else
            fail "Example vault config not found: $vault_example"
            exit 1
        fi
    fi
else
    info "Vault items config already exists: $vault_config"
fi

echo ""
pass "Vault configuration complete!"
echo ""
echo "Next steps:"
echo "  1. Review vault items: $EDITOR $vault_config"
echo "  2. Restore secrets:    dotfiles vault pull"
echo "  3. List vault items:   dotfiles vault list"
echo ""
