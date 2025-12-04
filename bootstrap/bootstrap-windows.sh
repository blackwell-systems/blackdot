#!/usr/bin/env bash
# ============================================================
# FILE: bootstrap-windows.sh
# Windows bootstrap (Git Bash / MSYS2 / Cygwin)
# Usage:
#   ./bootstrap-windows.sh              # Standard bootstrap
#   ./bootstrap-windows.sh --interactive  # Prompt for options
#   ./bootstrap-windows.sh --help       # Show help
# ============================================================
set -euo pipefail

# DOTFILES_DIR is parent of bootstrap/
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ============================================================
# Detect Windows environment
# ============================================================
IS_GITBASH=false
IS_MSYS2=false
IS_CYGWIN=false
export PLATFORM_NAME="Windows"

case "$(uname -s)" in
    MINGW*)
        IS_GITBASH=true
        export PLATFORM_NAME="Git Bash"
        ;;
    MSYS*)
        IS_MSYS2=true
        export PLATFORM_NAME="MSYS2"
        ;;
    CYGWIN*)
        IS_CYGWIN=true
        export PLATFORM_NAME="Cygwin"
        ;;
esac

# Source shared bootstrap functions
# shellcheck source=bootstrap/_common.sh
source "$DOTFILES_DIR/bootstrap/_common.sh"

# Parse arguments (sets INTERACTIVE flag)
parse_bootstrap_args "$@"

# Run interactive configuration if --interactive
run_interactive_config

echo "=== Windows bootstrap starting ($PLATFORM_NAME) ==="

# ============================================================
# 1. Check prerequisites
# ============================================================
echo "Checking prerequisites..."

if ! command -v git >/dev/null 2>&1; then
    fail "Git is required. Please install Git for Windows first."
    exit 1
fi

if ! command -v zsh >/dev/null 2>&1; then
    warn "Zsh not found. Some features may not work."
    if $IS_MSYS2; then
        echo "Install zsh with: pacman -S zsh"
    elif $IS_GITBASH; then
        echo "For full zsh support, consider using MSYS2 or WSL2 instead."
    fi
fi

# ============================================================
# 2. MSYS2-specific package installation
# ============================================================
if $IS_MSYS2 && command -v pacman >/dev/null 2>&1; then
    echo "Installing packages via pacman..."
    pacman -Syu --noconfirm --needed \
        git zsh curl wget \
        2>/dev/null || warn "Some packages may not have installed"
fi

# ============================================================
# 3. Workspace layout (shared)
# ============================================================
setup_workspace_layout

# ============================================================
# 4. Skip /workspace symlink on Windows (requires admin)
# ============================================================
if [[ "${SKIP_WORKSPACE_SYMLINK:-}" != "true" ]]; then
    echo "Note: /workspace symlink requires administrator privileges on Windows."
    echo "Skipping automatic creation. To create manually (as admin):"
    echo "  mklink /D C:\\workspace %USERPROFILE%\\workspace"
    echo ""
    echo "Or set SKIP_WORKSPACE_SYMLINK=true to suppress this message."
fi

# ============================================================
# 5. Dotfiles symlinks (shared)
# ============================================================
link_dotfiles

# ============================================================
# 6. Shell configuration
# ============================================================
if command -v zsh >/dev/null 2>&1; then
    if [[ "$SHELL" != "$(command -v zsh)" ]]; then
        echo "Note: To use zsh as default shell on Windows:"
        if $IS_MSYS2; then
            echo "  Add to ~/.bashrc: exec zsh"
        elif $IS_GITBASH; then
            echo "  Add to ~/.bashrc: exec zsh (if zsh is installed)"
        fi
    fi
fi

# ============================================================
# Done - Platform-specific tips
# ============================================================
echo "=== Windows bootstrap complete ($PLATFORM_NAME) ==="
echo ""
echo "Next steps:"
echo "  - Open a new shell to use the dotfiles configuration"
echo "  - Some features (Homebrew, Lima) are not available on Windows"
echo ""

if $IS_GITBASH; then
    echo "Git Bash notes:"
    echo "  - Consider using WSL2 for full Linux compatibility"
    echo "  - Homebrew is not available; use chocolatey or scoop for packages"
    echo ""
elif $IS_MSYS2; then
    echo "MSYS2 notes:"
    echo "  - Use 'pacman -S <package>' to install packages"
    echo "  - Some tools may need to be installed separately"
    echo ""
fi

echo "To restore secrets from vault:"
echo "  # Bitwarden: bw login && export BW_SESSION=\"\$(bw unlock --raw)\""
echo "  # 1Password: op signin"
echo "  # pass: (uses GPG, ensure gpg is configured)"
echo "  dotfiles vault pull"
