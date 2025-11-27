#!/usr/bin/env bash
# ============================================================
# Setup bats-core for unit testing
# ============================================================
set -euo pipefail

BATS_VERSION="v1.11.0"
BATS_INSTALL_DIR="${HOME}/.local/lib/bats-core"

echo "Checking for bats-core..."

if command -v bats >/dev/null 2>&1; then
  echo "✓ bats-core is already installed: $(which bats)"
  bats --version
  exit 0
fi

echo "bats-core not found. Installing version $BATS_VERSION..."

# Create installation directory
mkdir -p "$(dirname "$BATS_INSTALL_DIR")"

# Clone bats-core
if [ -d "$BATS_INSTALL_DIR" ]; then
  echo "Updating existing installation..."
  cd "$BATS_INSTALL_DIR"
  git fetch --tags
  git checkout "$BATS_VERSION"
else
  echo "Cloning bats-core..."
  git clone --depth 1 --branch "$BATS_VERSION" \
    https://github.com/bats-core/bats-core.git \
    "$BATS_INSTALL_DIR"
fi

# Install to ~/.local/bin (should be in PATH)
cd "$BATS_INSTALL_DIR"
./install.sh "$HOME/.local"

echo ""
echo "✓ bats-core installed successfully!"
echo ""
echo "Installation location: $HOME/.local/bin/bats"
echo ""
echo "Make sure ~/.local/bin is in your PATH:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
echo ""
echo "Run tests with:"
echo "  bats test/"
