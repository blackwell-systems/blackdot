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

# Load config management
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
CONFIG_FILE="$CONFIG_DIR/config.ini"

config_get() {
    local section="$1"
    local key="$2"
    local default="${3:-}"

    if [[ -f "$CONFIG_FILE" ]]; then
        awk -F= -v section="$section" -v key="$key" -v default="$default" '
            /^\[.*\]$/ { in_section = ($0 == "["section"]") }
            in_section && $1 == key { print $2; found=1; exit }
            END { if (!found) print default }
        ' "$CONFIG_FILE"
    else
        echo "$default"
    fi
}

config_set() {
    local section="$1"
    local key="$2"
    local value="$3"

    mkdir -p "$CONFIG_DIR"

    if [[ ! -f "$CONFIG_FILE" ]]; then
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
        info "Run 'dotfiles vault init' anytime to configure vault"
        exit 0
    else
        fail "Please install a vault CLI and run 'dotfiles vault init' again"
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
    info "Run 'dotfiles vault init' anytime to configure vault"
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

    # Create config directory
    mkdir -p "$(dirname "$vault_config")"

    # Copy example
    if [[ -f "$vault_example" ]]; then
        cp "$vault_example" "$vault_config"
        pass "Created $vault_config"
        echo ""
        info "Review and customize this file for your setup"
        echo "  Edit with: $EDITOR $vault_config"
    else
        fail "Example vault config not found: $vault_example"
        exit 1
    fi
else
    info "Vault items config already exists: $vault_config"
fi

echo ""
pass "Vault configuration complete!"
echo ""
echo "Next steps:"
echo "  1. Review vault items: $EDITOR $vault_config"
echo "  2. Restore secrets:    dotfiles vault restore"
echo "  3. List vault items:   dotfiles vault list"
echo ""
