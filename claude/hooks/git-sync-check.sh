#!/usr/bin/env bash
# =============================================================================
# git-sync-check.sh - Check git sync status before operations
# =============================================================================
# This script checks if the local branch is in sync with its remote tracking
# branch and warns about divergence that could cause conflicts.
#
# Exit codes:
#   0 - OK to proceed (in sync or no remote tracking)
#   1 - Warning: behind remote (should pull first)
#   2 - Error: diverged (needs user intervention)
#
# Usage: Called by SessionStart hook or manually before git operations
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the current branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [[ -z "$BRANCH" ]]; then
    echo -e "${YELLOW}Warning: Not in a git repository${NC}"
    exit 0
fi

# Get the remote tracking branch
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "")

if [[ -z "$UPSTREAM" ]]; then
    echo -e "${BLUE}Info: Branch '$BRANCH' has no remote tracking branch${NC}"
    exit 0
fi

# Fetch latest from remote (quietly)
git fetch --quiet 2>/dev/null || true

# Get ahead/behind counts
AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")

# Check status
if [[ "$AHEAD" -eq 0 && "$BEHIND" -eq 0 ]]; then
    echo -e "${GREEN}✓ Branch '$BRANCH' is in sync with '$UPSTREAM'${NC}"
    exit 0
elif [[ "$AHEAD" -gt 0 && "$BEHIND" -eq 0 ]]; then
    echo -e "${BLUE}Info: Branch '$BRANCH' is $AHEAD commit(s) ahead of '$UPSTREAM'${NC}"
    echo "  Consider pushing your changes: git push"
    exit 0
elif [[ "$AHEAD" -eq 0 && "$BEHIND" -gt 0 ]]; then
    echo -e "${YELLOW}Warning: Branch '$BRANCH' is $BEHIND commit(s) behind '$UPSTREAM'${NC}"
    echo "  Run 'git pull --rebase' before making changes to avoid conflicts."
    exit 1
elif [[ "$AHEAD" -gt 0 && "$BEHIND" -gt 0 ]]; then
    echo -e "${RED}ERROR: Branch '$BRANCH' has DIVERGED from '$UPSTREAM'${NC}"
    echo "  Local is $AHEAD commit(s) ahead and $BEHIND commit(s) behind."
    echo ""
    echo "  This requires manual intervention. Options:"
    echo "    1. git pull --rebase  (rebase local commits on top of remote)"
    echo "    2. git merge origin/$BRANCH  (create a merge commit)"
    echo "    3. Ask the user how to proceed"
    echo ""
    echo "  DO NOT proceed with changes until this is resolved!"
    exit 2
fi
