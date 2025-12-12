#!/bin/bash
# Blackdot Devcontainer Feature - Install Script
# This script is executed during container build to install blackdot
set -e

# Feature options (passed from devcontainer-feature.json)
PRESET="${PRESET:-developer}"
VERSION="${VERSION:-latest}"
SHELL_INTEGRATION="${SHELLINTEGRATION:-true}"

echo "==================================="
echo "Installing Blackdot"
echo "  Preset: $PRESET"
echo "  Version: $VERSION"
echo "  Shell Integration: $SHELL_INTEGRATION"
echo "==================================="

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    arm64)   ARCH="arm64" ;;
    *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
    linux)  OS="linux" ;;
    darwin) OS="darwin" ;;
    *)      echo "Unsupported OS: $OS"; exit 1 ;;
esac

# Build binary name
BINARY_NAME="blackdot-${OS}-${ARCH}"

# GitHub release URL
GITHUB_REPO="blackwell-systems/blackdot"
if [ "$VERSION" = "latest" ]; then
    DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${BINARY_NAME}"
else
    DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${VERSION}/${BINARY_NAME}"
fi

echo "Downloading blackdot from: $DOWNLOAD_URL"

# Create install directory
INSTALL_DIR="/usr/local/bin"
mkdir -p "$INSTALL_DIR"

# Download binary
if command -v curl &> /dev/null; then
    curl -fsSL "$DOWNLOAD_URL" -o "${INSTALL_DIR}/blackdot"
elif command -v wget &> /dev/null; then
    wget -q "$DOWNLOAD_URL" -O "${INSTALL_DIR}/blackdot"
else
    echo "Error: curl or wget required"
    exit 1
fi

# Make executable
chmod +x "${INSTALL_DIR}/blackdot"

# Verify installation
if ! "${INSTALL_DIR}/blackdot" version; then
    echo "Error: blackdot installation verification failed"
    exit 1
fi

echo "Blackdot installed successfully"

# Add shell integration if enabled
if [ "$SHELL_INTEGRATION" = "true" ]; then
    echo "Adding shell integration..."

    SHELL_INIT='eval "$(blackdot shell-init)"'

    # Add to bash profiles
    for profile in /etc/bash.bashrc /etc/profile.d/blackdot.sh; do
        if [ -d "$(dirname "$profile")" ]; then
            echo "" >> "$profile"
            echo "# Blackdot shell integration" >> "$profile"
            echo "$SHELL_INIT" >> "$profile"
            echo "Added shell integration to $profile"
        fi
    done

    # Add to zsh profiles
    for profile in /etc/zsh/zshrc /etc/zshrc; do
        if [ -f "$profile" ] || [ -d "$(dirname "$profile")" ]; then
            echo "" >> "$profile"
            echo "# Blackdot shell integration" >> "$profile"
            echo "$SHELL_INIT" >> "$profile"
            echo "Added shell integration to $profile"
        fi
    done
fi

# Create marker file for preset (used by postStartCommand)
echo "$PRESET" > /tmp/.blackdot-preset

echo ""
echo "==================================="
echo "Blackdot installation complete!"
echo ""
echo "Run 'blackdot setup' to configure"
echo "your vault-backed secrets."
echo "==================================="
