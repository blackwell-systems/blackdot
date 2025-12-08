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
#   --binary     Download pre-built Go binary (faster, no build required)
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

# Run hook via zsh (requires repo to be cloned first)
run_hook() {
    local hook_point="$1"
    local dotfiles_dir="${INSTALL_DIR:-}"

    # Skip if repo not cloned yet
    [[ -z "$dotfiles_dir" || ! -d "$dotfiles_dir" ]] && return 0

    # Skip if zsh not available
    command -v zsh &>/dev/null || return 0

    # Skip if hooks library doesn't exist
    [[ -f "$dotfiles_dir/lib/_hooks.sh" ]] || return 0

    # Run hooks via zsh (silently fail if hooks disabled)
    zsh -c "
        source '$dotfiles_dir/lib/_hooks.sh' 2>/dev/null || exit 0
        hook_run '$hook_point'
    " 2>/dev/null || true
}

# Download Go binary from GitHub releases
install_go_binary() {
    local install_dir="${1:-$HOME/.local/bin}"
    local version="${DOTFILES_VERSION:-latest}"

    # Detect OS
    local os=""
    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux)  os="linux" ;;
        MINGW*|MSYS*|CYGWIN*) os="windows" ;;
        *) fail "Unsupported OS for binary download"; return 1 ;;
    esac

    # Detect architecture
    local arch=""
    case "$(uname -m)" in
        x86_64|amd64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) fail "Unsupported architecture: $(uname -m)"; return 1 ;;
    esac

    # Build binary name
    local suffix=""
    [[ "$os" == "windows" ]] && suffix=".exe"
    local binary_name="dotfiles-${os}-${arch}${suffix}"

    # GitHub release URL
    local base_url="https://github.com/blackwell-systems/dotfiles/releases"
    local download_url=""

    if [[ "$version" == "latest" ]]; then
        download_url="${base_url}/latest/download/${binary_name}"
    else
        download_url="${base_url}/download/${version}/${binary_name}"
    fi

    info "Downloading Go binary: $binary_name"
    info "From: $download_url"

    # Create install directory
    mkdir -p "$install_dir"

    # Download binary
    local target="${install_dir}/dotfiles${suffix}"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$download_url" -o "$target" || {
            fail "Failed to download binary. Release may not exist yet."
            fail "Try without --binary flag, or check: ${base_url}"
            return 1
        }
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$download_url" -O "$target" || {
            fail "Failed to download binary"
            return 1
        }
    else
        fail "Neither curl nor wget found"
        return 1
    fi

    # Make executable
    chmod +x "$target"

    # Verify it works
    if "$target" version >/dev/null 2>&1; then
        pass "Installed dotfiles binary to: $target"

        # Add to PATH hint if needed
        if ! echo "$PATH" | grep -q "$install_dir"; then
            warn "Add to your PATH: export PATH=\"$install_dir:\$PATH\""
        fi
        return 0
    else
        fail "Binary verification failed"
        rm -f "$target"
        return 1
    fi
}

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
INSTALL_BINARY=false
BINARY_ONLY=false

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
        --binary|-b)
            INSTALL_BINARY=true
            shift
            ;;
        --binary-only)
            BINARY_ONLY=true
            INSTALL_BINARY=true
            shift
            ;;
        --help|-h)
            echo "Dotfiles Installer"
            echo ""
            echo "Usage:"
            echo "  curl -fsSL <url> | bash                         # Full install (recommended)"
            echo "  curl -fsSL <url> | bash -s -- --binary          # Install with Go binary"
            echo "  curl -fsSL <url> | bash -s -- --binary-only     # Just download Go binary"
            echo ""
            echo "Options:"
            echo "  --minimal, -m        Shell config only (skip: Homebrew, vault, Claude, /workspace)"
            echo "  --binary, -b         Download pre-built Go binary (recommended)"
            echo "  --binary-only        Just download the Go binary, skip repo clone"
            echo "  --ssh                Clone using SSH instead of HTTPS"
            echo "  --help, -h           Show this help"
            echo ""
            echo "Environment Variables:"
            echo "  WORKSPACE_TARGET     Clone location (default: ~/workspace)"
            echo "  DOTFILES_VERSION     Binary version to download (default: latest)"
            echo "  DOTFILES_BIN_DIR     Where to install binary (default: ~/.local/bin)"
            echo ""
            echo "Examples:"
            echo "  curl -fsSL <url> | bash -s -- --binary          # Full install with binary"
            echo "  DOTFILES_VERSION=v3.1.0 ./install.sh --binary   # Specific version"
            echo ""
            echo "After installation, run 'dotfiles setup' to configure your environment."
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

# Binary-only mode: just download the binary and exit
if $BINARY_ONLY; then
    install_go_binary "${DOTFILES_BIN_DIR:-$HOME/.local/bin}"
    echo ""
    echo -e "${GREEN}${BOLD}Binary installation complete!${NC}"
    echo ""
    echo "Run 'dotfiles version' to verify the installation."
    exit 0
fi

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

# Run pre-install hooks
run_hook "pre_install"

# Run bootstrap
info "Running bootstrap script..."
echo ""

./"$BOOTSTRAP_SCRIPT"

# Install Go binary if requested
if $INSTALL_BINARY; then
    echo ""
    info "Installing Go binary..."
    install_go_binary "${DOTFILES_BIN_DIR:-$HOME/.local/bin}" || warn "Binary installation failed, shell scripts will be used"
fi

# Run post-install hooks
run_hook "post_install"

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

        # Run setup directly without sourcing zshrc (avoids shell config issues)
        # Setup script handles its own environment
        cd "$INSTALL_DIR" && "$INSTALL_DIR/bin/dotfiles-setup"

        echo ""
        echo "To load your new shell configuration:"
        echo -e "  ${CYAN}exec zsh${NC}"
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
