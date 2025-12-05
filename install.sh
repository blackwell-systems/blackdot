#!/usr/bin/env bash
# ============================================================
# One-line installer for dotfiles
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash
#
# After installation, run 'dotfiles setup' to configure vault and secrets.
#
# Options:
#   --minimal    Skip optional features (vault, Claude setup)
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

# Workspace target (configurable via env var, defaults to ~/workspace)
WORKSPACE_TARGET="${WORKSPACE_TARGET:-$HOME/workspace}"
# Expand ~ if present
WORKSPACE_TARGET="${WORKSPACE_TARGET/#\~/$HOME}"

INSTALL_DIR="$WORKSPACE_TARGET/dotfiles"

# Parse arguments
MINIMAL=false
USE_SSH=false

while [[ $# -gt 0 ]]; do
    case "$1" in
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
            echo "Usage:"
            echo "  curl -fsSL <url> | bash                         # Full install (recommended)"
            echo "  curl -fsSL <url> -o install.sh && bash install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --minimal, -m        Shell config only (skip: Homebrew, vault, Claude, /workspace)"
            echo "  --ssh                Clone using SSH instead of HTTPS"
            echo "  --help, -h           Show this help"
            echo ""
            echo "Modular Install:"
            echo "  Everything is optional except shell config. Use --minimal for just ZSH,"
            echo "  or customize with environment variables:"
            echo ""
            echo "    WORKSPACE_TARGET=~/code ./install.sh             # Use ~/code instead of ~/workspace"
            echo "    SKIP_WORKSPACE_SYMLINK=true ./bootstrap-mac.sh   # Skip /workspace symlink"
            echo "    SKIP_CLAUDE_SETUP=true ./bootstrap-linux.sh      # Skip Claude integration"
            echo ""
            echo "After installation, run 'dotfiles setup' to configure your environment."
            echo "The setup wizard lets you enable/skip features interactively."
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
mkdir -p "$WORKSPACE_TARGET"

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

if $MINIMAL; then
    export SKIP_WORKSPACE_SYMLINK=true
    export SKIP_CLAUDE_SETUP=true
    info "Minimal mode: skipping optional features"
fi

# Run bootstrap
info "Running bootstrap script..."
echo ""

./"$BOOTSTRAP_SCRIPT"

# Success message
echo ""
echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║              Installation Complete!                        ║${NC}"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if ! $MINIMAL; then
    echo "Next step: Run the setup wizard to configure vault and restore secrets"
    echo ""
    echo -n "Run setup wizard now? [Y/n]: "
    read -r run_setup

    if [[ ! "${run_setup:-Y}" =~ ^[Nn]$ ]]; then
        echo ""
        echo -e "${CYAN}Starting setup wizard...${NC}"
        echo ""

        # Source zsh and run setup
        exec zsh -c "source $HOME/.zshrc 2>/dev/null; cd $INSTALL_DIR && $INSTALL_DIR/bin/dotfiles-setup"
    else
        echo ""
        echo "You can run the setup wizard later with:"
        echo -e "  ${CYAN}exec zsh${NC}"
        echo -e "  ${CYAN}dotfiles setup${NC}"
        echo ""
        echo "Then verify installation:"
        echo -e "  ${CYAN}dotfiles doctor${NC}"
    fi
else
    echo "Next steps (minimal mode):"
    echo ""
    echo "  1. Load your new shell:"
    echo -e "     ${CYAN}exec zsh${NC}"
    echo ""
    echo "  2. Manually configure:"
    echo -e "     ${CYAN}~/.ssh/config and keys${NC}"
    echo -e "     ${CYAN}~/.aws/config and credentials${NC}"
    echo -e "     ${CYAN}~/.gitconfig${NC}"
    echo ""
    echo "  3. Verify installation:"
    echo -e "     ${CYAN}dotfiles doctor${NC}"
fi
echo ""
echo -e "Documentation: ${BLUE}https://github.com/blackwell-systems/dotfiles${NC}"
echo ""
