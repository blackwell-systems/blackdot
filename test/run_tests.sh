#!/usr/bin/env bash
# ============================================================
# Test runner for dotfiles unit and integration tests
# Usage: ./run_tests.sh [unit|integration|all]
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test mode (default: all)
TEST_MODE="${1:-all}"

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

echo "Dotfiles Test Runner"
echo "bats version: $(bats --version)"
echo ""

FAILED=0

# Run unit tests
run_unit_tests() {
  echo -e "${BLUE}=== Running Unit Tests ===${NC}"
  echo ""

  local unit_tests=()
  [[ -f "$SCRIPT_DIR/vault_common.bats" ]] && unit_tests+=("$SCRIPT_DIR/vault_common.bats")
  [[ -f "$SCRIPT_DIR/cli_commands.bats" ]] && unit_tests+=("$SCRIPT_DIR/cli_commands.bats")

  if [[ ${#unit_tests[@]} -eq 0 ]]; then
    echo "No unit tests found."
    return 0
  fi

  if bats --timing "${unit_tests[@]}"; then
    echo -e "${GREEN}✓ Unit tests passed${NC}"
    return 0
  else
    echo -e "${RED}✗ Unit tests failed${NC}"
    return 1
  fi
}

# Run integration tests
run_integration_tests() {
  echo -e "${BLUE}=== Running Integration Tests ===${NC}"
  echo ""

  if [[ ! -f "$SCRIPT_DIR/integration.bats" ]]; then
    echo "No integration tests found."
    return 0
  fi

  # Verify mock bw is executable
  if [[ ! -x "$SCRIPT_DIR/mocks/bw" ]]; then
    echo -e "${YELLOW}Warning: mock bw not executable, fixing...${NC}"
    chmod +x "$SCRIPT_DIR/mocks/bw" 2>/dev/null || true
  fi

  if bats --timing "$SCRIPT_DIR/integration.bats"; then
    echo -e "${GREEN}✓ Integration tests passed${NC}"
    return 0
  else
    echo -e "${RED}✗ Integration tests failed${NC}"
    return 1
  fi
}

case "$TEST_MODE" in
  unit)
    run_unit_tests || FAILED=1
    ;;
  integration)
    run_integration_tests || FAILED=1
    ;;
  all|"")
    run_unit_tests || FAILED=1
    echo ""
    run_integration_tests || FAILED=1
    ;;
  *)
    echo "Usage: $0 [unit|integration|all]"
    echo ""
    echo "Options:"
    echo "  unit         Run unit tests only"
    echo "  integration  Run integration tests only"
    echo "  all          Run all tests (default)"
    exit 1
    ;;
esac

echo ""
if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some tests failed.${NC}"
  exit 1
fi
