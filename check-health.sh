#!/usr/bin/env bash
# ============================================================
# FILE: check-health.sh
# Verifies dotfiles installation health
# ============================================================
set -uo pipefail

# Colors for output (if terminal supports it)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

ERRORS=0
WARNINGS=0

pass() {
    echo -e "${GREEN}[OK]${NC} $1"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((ERRORS++))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

# ============================================================
# SYMLINKS
# ============================================================
section "Symlinks"

check_symlink() {
    local link="$1"
    local expected_target="$2"
    local name="$3"

    if [[ -L "$link" ]]; then
        local actual_target
        actual_target="$(readlink "$link")"
        if [[ "$actual_target" == *"$expected_target"* ]]; then
            pass "$name -> $actual_target"
        else
            warn "$name points to $actual_target (expected $expected_target)"
        fi
    elif [[ -e "$link" ]]; then
        fail "$name exists but is not a symlink"
    else
        fail "$name does not exist"
    fi
}

check_symlink "$HOME/.zshrc" "dotfiles/zsh/zshrc" "~/.zshrc"
check_symlink "$HOME/.p10k.zsh" "dotfiles/zsh/p10k.zsh" "~/.p10k.zsh"

if [[ "$(uname -s)" == "Darwin" ]]; then
    check_symlink "$HOME/Library/Application Support/com.mitchellh.ghostty/config" "dotfiles/ghostty/config" "Ghostty config"
fi

# Claude workspace symlink
if [[ -L "$HOME/.claude" ]]; then
    pass "~/.claude symlink exists"
elif [[ -d "$HOME/.claude" ]]; then
    warn "~/.claude is a directory, not a symlink (may not share state with Lima)"
else
    info "~/.claude does not exist yet"
fi

# ============================================================
# REQUIRED COMMANDS
# ============================================================
section "Required Commands"

check_command() {
    local cmd="$1"
    local install_hint="${2:-}"

    if command -v "$cmd" >/dev/null 2>&1; then
        local version
        case "$cmd" in
            brew) version="$(brew --version 2>/dev/null | head -1)" ;;
            bw) version="$(bw --version 2>/dev/null)" ;;
            jq) version="$(jq --version 2>/dev/null)" ;;
            aws) version="$(aws --version 2>/dev/null | awk '{print $1}')" ;;
            git) version="$(git --version 2>/dev/null)" ;;
            zsh) version="$(zsh --version 2>/dev/null)" ;;
            node) version="node $(node --version 2>/dev/null)" ;;
            claude) version="$(claude --version 2>/dev/null | head -1)" ;;
            *) version="installed" ;;
        esac
        pass "$cmd ($version)"
    else
        if [[ -n "$install_hint" ]]; then
            fail "$cmd not found - $install_hint"
        else
            fail "$cmd not found"
        fi
    fi
}

check_command "brew" "Run bootstrap-mac.sh or bootstrap-lima.sh"
check_command "zsh" "brew install zsh"
check_command "git" "brew install git"
check_command "jq" "brew install jq"
check_command "bw" "brew install bitwarden-cli"
check_command "aws" "brew install awscli"

# Optional but useful
section "Optional Commands"
check_command "node" "brew install node" || true
check_command "claude" "brew install claude-code" || true
check_command "tmux" "brew install tmux" || true

# ============================================================
# SSH KEYS
# ============================================================
section "SSH Keys"

check_ssh_key() {
    local key_name="$1"
    local priv_path="$HOME/.ssh/$key_name"
    local pub_path="$HOME/.ssh/${key_name}.pub"

    if [[ -f "$priv_path" ]]; then
        # Check permissions
        local perms
        perms="$(stat -c '%a' "$priv_path" 2>/dev/null || stat -f '%A' "$priv_path" 2>/dev/null)"
        if [[ "$perms" == "600" ]]; then
            pass "$key_name (permissions: $perms)"
        else
            warn "$key_name exists but has wrong permissions: $perms (should be 600)"
        fi
    else
        info "$key_name not found (run bw-restore to restore from Bitwarden)"
    fi

    if [[ -f "$pub_path" ]]; then
        local perms
        perms="$(stat -c '%a' "$pub_path" 2>/dev/null || stat -f '%A' "$pub_path" 2>/dev/null)"
        if [[ "$perms" == "644" ]]; then
            pass "${key_name}.pub (permissions: $perms)"
        else
            warn "${key_name}.pub has permissions: $perms (should be 644)"
        fi
    fi
}

check_ssh_key "id_ed25519_enterprise_ghub"
check_ssh_key "id_ed25519_blackwell"

# Check ~/.ssh directory permissions
if [[ -d "$HOME/.ssh" ]]; then
    ssh_perms="$(stat -c '%a' "$HOME/.ssh" 2>/dev/null || stat -f '%A' "$HOME/.ssh" 2>/dev/null)"
    if [[ "$ssh_perms" == "700" ]]; then
        pass "~/.ssh directory (permissions: $ssh_perms)"
    else
        warn "~/.ssh has permissions: $ssh_perms (should be 700)"
    fi
fi

# ============================================================
# AWS CONFIGURATION
# ============================================================
section "AWS Configuration"

if [[ -f "$HOME/.aws/config" ]]; then
    aws_perms="$(stat -c '%a' "$HOME/.aws/config" 2>/dev/null || stat -f '%A' "$HOME/.aws/config" 2>/dev/null)"
    if [[ "$aws_perms" == "600" ]]; then
        pass "~/.aws/config (permissions: $aws_perms)"
    else
        warn "~/.aws/config has permissions: $aws_perms (should be 600)"
    fi

    # Check for expected profiles
    for profile in dev-profile prod-profile; do
        if grep -q "\[profile $profile\]" "$HOME/.aws/config" 2>/dev/null; then
            pass "AWS profile '$profile' configured"
        else
            info "AWS profile '$profile' not found in config"
        fi
    done
else
    info "~/.aws/config not found (run bw-restore to restore from Bitwarden)"
fi

if [[ -f "$HOME/.aws/credentials" ]]; then
    creds_perms="$(stat -c '%a' "$HOME/.aws/credentials" 2>/dev/null || stat -f '%A' "$HOME/.aws/credentials" 2>/dev/null)"
    if [[ "$creds_perms" == "600" ]]; then
        pass "~/.aws/credentials (permissions: $creds_perms)"
    else
        warn "~/.aws/credentials has permissions: $creds_perms (should be 600)"
    fi
else
    info "~/.aws/credentials not found"
fi

# ============================================================
# ENVIRONMENT SECRETS
# ============================================================
section "Environment Secrets"

if [[ -f "$HOME/.local/env.secrets" ]]; then
    env_perms="$(stat -c '%a' "$HOME/.local/env.secrets" 2>/dev/null || stat -f '%A' "$HOME/.local/env.secrets" 2>/dev/null)"
    if [[ "$env_perms" == "600" ]]; then
        pass "~/.local/env.secrets (permissions: $env_perms)"
    else
        warn "~/.local/env.secrets has permissions: $env_perms (should be 600)"
    fi
else
    info "~/.local/env.secrets not found (optional)"
fi

if [[ -f "$HOME/.local/load-env.sh" ]]; then
    pass "~/.local/load-env.sh exists"
else
    info "~/.local/load-env.sh not found (created by bw-restore)"
fi

# ============================================================
# BITWARDEN STATUS
# ============================================================
section "Bitwarden Status"

if command -v bw >/dev/null 2>&1; then
    if bw login --check >/dev/null 2>&1; then
        pass "Bitwarden CLI logged in"

        # Check if unlocked
        if [[ -n "${BW_SESSION:-}" ]]; then
            if bw unlock --check --session "$BW_SESSION" >/dev/null 2>&1; then
                pass "Bitwarden vault unlocked (BW_SESSION valid)"
            else
                info "BW_SESSION set but expired"
            fi
        else
            info "Bitwarden vault locked (BW_SESSION not set)"
        fi
    else
        info "Bitwarden CLI not logged in (run: bw login)"
    fi
fi

# ============================================================
# SHELL CONFIGURATION
# ============================================================
section "Shell Configuration"

# Check default shell
current_shell="$(basename "$SHELL")"
if [[ "$current_shell" == "zsh" ]]; then
    pass "Default shell is zsh"
else
    warn "Default shell is $current_shell (expected zsh)"
fi

# Check if zsh plugins are loadable
if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX="$(brew --prefix)"

    if [[ -f "$BREW_PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
        pass "Powerlevel10k installed"
    else
        fail "Powerlevel10k not found"
    fi

    if [[ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
        pass "zsh-autosuggestions installed"
    else
        fail "zsh-autosuggestions not found"
    fi

    if [[ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
        pass "zsh-syntax-highlighting installed"
    else
        fail "zsh-syntax-highlighting not found"
    fi
fi

# ============================================================
# WORKSPACE LAYOUT
# ============================================================
section "Workspace Layout"

for dir in "$HOME/workspace" "$HOME/workspace/code"; do
    if [[ -d "$dir" ]]; then
        pass "$dir exists"
    else
        info "$dir does not exist"
    fi
done

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "========================================"
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}Health check passed!${NC}"
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}Health check passed with $WARNINGS warning(s)${NC}"
else
    echo -e "${RED}Health check found $ERRORS error(s) and $WARNINGS warning(s)${NC}"
fi
echo "========================================"

exit $ERRORS
