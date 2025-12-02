#!/usr/bin/env bash
# ============================================================
# One-line installer for dotfiles
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash
#
# Or with options:
#   curl -fsSL ... | bash -s -- --interactive
#   curl -fsSL ... | bash -s -- --minimal
#
# ============================================================
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
pass()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; }

# Configuration
REPO_URL="https://github.com/blackwell-systems/dotfiles.git"
REPO_SSH="git@github.com:blackwell-systems/dotfiles.git"
INSTALL_DIR="$HOME/workspace/dotfiles"

# Parse arguments
INTERACTIVE=false
MINIMAL=false
USE_SSH=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --interactive|-i)
            INTERACTIVE=true
            shift
            ;;
        --minimal|-m)
            MINIMAL=true
            shift
            ;;
        --ssh)
            USE_SSH=true
            shift
            ;;
        --help|-h)
            echo "Dotfiles Installer"
            echo ""
            echo "Usage: curl -fsSL <url> | bash -s -- [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --interactive, -i    Prompt for configuration options"
            echo "  --minimal, -m        Skip optional features (vault, Claude setup)"
            echo "  --ssh                Clone using SSH instead of HTTPS"
            echo "  --help, -h           Show this help"
            exit 0
            ;;
        *)
            warn "Unknown option: $1"
            shift
            ;;
    esac
done

# Banner
echo ""
echo -e "${CYAN}${BOLD}"
cat << 'EOF'
    ____        __  _____ __
   / __ \____  / /_/ __(_) /__  _____
  / / / / __ \/ __/ /_/ / / _ \/ ___/
 / /_/ / /_/ / /_/ __/ / /  __(__  )
/_____/\____/\__/_/ /_/_/\___/____/

EOF
echo -e "${NC}"
echo -e "${BOLD}Vault-backed configuration that travels with you${NC}"
echo ""

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Darwin)
        PLATFORM="macOS"
        BOOTSTRAP_SCRIPT="bootstrap/bootstrap-mac.sh"
        ;;
    Linux)
        PLATFORM="Linux"
        BOOTSTRAP_SCRIPT="bootstrap/bootstrap-linux.sh"
        # Detect WSL/Lima
        if grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
            PLATFORM="WSL2"
        elif [[ -n "${LIMA_INSTANCE:-}" ]]; then
            PLATFORM="Lima"
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        PLATFORM="Windows (Git Bash)"
        BOOTSTRAP_SCRIPT="bootstrap/bootstrap-windows.sh"
        ;;
    *)
        fail "Unsupported operating system: $OS"
        exit 1
        ;;
esac

info "Detected platform: $PLATFORM"

# Check for git
if ! command -v git >/dev/null 2>&1; then
    warn "Git not found. Installing prerequisites..."
    if [[ "$OS" == "Darwin" ]]; then
        xcode-select --install 2>/dev/null || true
        echo "Please rerun this script after Xcode tools finish installing."
        exit 0
    else
        sudo apt-get update && sudo apt-get install -y git
    fi
fi

# Create workspace directory
mkdir -p "$HOME/workspace"

# Clone or update repository
if [[ -d "$INSTALL_DIR/.git" ]]; then
    info "Dotfiles already installed at $INSTALL_DIR"
    info "Updating..."
    cd "$INSTALL_DIR"
    git pull --rebase origin main
    pass "Updated to latest version"
else
    info "Cloning dotfiles repository..."
    if $USE_SSH; then
        git clone "$REPO_SSH" "$INSTALL_DIR"
    else
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi
    pass "Cloned to $INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# Build bootstrap arguments
BOOTSTRAP_ARGS=""

if $MINIMAL; then
    export SKIP_WORKSPACE_SYMLINK=true
    export SKIP_CLAUDE_SETUP=true
    info "Minimal mode: skipping optional features"
fi

if $INTERACTIVE; then
    BOOTSTRAP_ARGS="--interactive"
fi

# Run bootstrap
info "Running bootstrap script..."
echo ""

# Note: BOOTSTRAP_ARGS is intentionally unquoted to allow word splitting for multiple flags
# shellcheck disable=SC2086
./"$BOOTSTRAP_SCRIPT" $BOOTSTRAP_ARGS

# If interactive mode, run the setup wizard
if $INTERACTIVE && ! $MINIMAL; then
    echo ""
    info "Running interactive setup wizard..."
    echo ""
    ./bin/dotfiles-init
    exit 0
fi

# Success message (non-interactive mode)
echo ""
echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║              Installation Complete!                        ║${NC}"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  1. Start a new shell session:"
echo -e "     ${CYAN}exec zsh${NC}"
echo ""

if ! $MINIMAL; then
    echo "  2. Complete setup with the interactive wizard:"
    echo -e "     ${CYAN}dotfiles init${NC}"
    echo ""
    echo "  Or manually restore secrets from vault:"
    echo -e "     ${CYAN}# Bitwarden: bw login && export BW_SESSION=\"\$(bw unlock --raw)\"${NC}"
    echo -e "     ${CYAN}# 1Password: op signin${NC}"
    echo -e "     ${CYAN}# pass: (uses GPG, no login needed)${NC}"
    echo -e "     ${CYAN}dotfiles vault restore${NC}"
    echo ""
    echo "  3. Verify installation:"
else
    echo "  2. Manually configure (minimal mode - vault skipped):"
    echo -e "     ${CYAN}~/.ssh/config and keys${NC}"
    echo -e "     ${CYAN}~/.aws/config and credentials${NC}"
    echo -e "     ${CYAN}~/.gitconfig${NC}"
    echo ""
    echo "  3. Verify installation:"
fi
echo -e "     ${CYAN}dotfiles doctor${NC}"
echo ""
echo -e "Documentation: ${BLUE}https://github.com/blackwell-systems/dotfiles${NC}"
echo ""
