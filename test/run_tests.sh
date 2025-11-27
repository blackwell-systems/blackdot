#!/usr/bin/env bash
# ============================================================
# Test runner for dotfiles unit tests
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if bats is installed
if ! command -v bats >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠ bats-core is not installed.${NC}"
  echo ""
  echo "Install options:"
  echo "  1. Via package manager:"
  echo "     • macOS:  brew install bats-core"
  echo "     • Linux:  sudo apt-get install bats"
  echo ""
  echo "  2. Via setup script (installs to ~/.local):"
  echo "     ./test/setup_bats.sh"
  echo ""
  exit 1
fi

echo "Running unit tests with bats-core..."
echo "bats version: $(bats --version)"
echo ""

# Run tests
if bats --timing "$SCRIPT_DIR"/*.bats; then
  echo ""
  echo -e "${GREEN}✓ All tests passed!${NC}"
  exit 0
else
  echo ""
  echo -e "${RED}✗ Some tests failed.${NC}"
  exit 1
fi
