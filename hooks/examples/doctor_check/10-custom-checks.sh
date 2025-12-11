#!/usr/bin/env bash
# ============================================================
# Example Hook: doctor_check/10-custom-checks.sh
# Add custom health checks to 'blackdot doctor'
#
# Installation:
#   mkdir -p ~/.config/blackdot/hooks/doctor_check
#   cp this_file ~/.config/blackdot/hooks/doctor_check/
#   chmod +x ~/.config/blackdot/hooks/doctor_check/10-custom-checks.sh
#
# Output format: Your output will appear in the doctor results
# ============================================================

# Colors (match doctor output style)
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }

echo ""
echo -e "\033[1m\033[0;36m── Custom Checks ──\033[0m"

# Example: Check if work VPN is connected
# if ping -c1 -W1 internal.company.com &>/dev/null; then
#     pass "Work VPN connected"
# else
#     warn "Work VPN not connected"
# fi

# Example: Check for required environment variables
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    pass "GITHUB_TOKEN is set"
else
    warn "GITHUB_TOKEN not set (needed for private repos)"
fi

# Example: Check for local config file
if [[ -f "$HOME/.zshrc.local" ]]; then
    pass "Local zsh config exists (~/.zshrc.local)"
else
    warn "No local zsh config (~/.zshrc.local)"
fi

# Example: Check disk space
disk_usage=$(df -h "$HOME" | awk 'NR==2 {print $5}' | tr -d '%')
if [[ "$disk_usage" -lt 80 ]]; then
    pass "Disk usage OK (${disk_usage}%)"
elif [[ "$disk_usage" -lt 90 ]]; then
    warn "Disk usage high (${disk_usage}%)"
else
    fail "Disk usage critical (${disk_usage}%)"
fi

exit 0
