#!/usr/bin/env bash
# =============================================================================
# block-dangerous-git.sh - PreToolUse hook to block dangerous git commands
# =============================================================================
# This hook prevents Claude Code from executing potentially destructive git
# commands that could cause data loss or repository corruption.
#
# Blocked commands:
#   - git push --force / -f (can overwrite remote history)
#   - git push --force-with-lease (still dangerous without explicit approval)
#   - git reset --hard (discards uncommitted changes)
#   - git clean -fd (removes untracked files permanently)
#   - git checkout --force (discards local changes)
#   - git rebase without explicit approval
#
# Usage: This script is called by Claude Code's PreToolUse hook system
#        Input is passed via stdin as JSON
# =============================================================================

set -euo pipefail

# Read the tool input from stdin
INPUT=$(cat)

# Extract the command from the Bash tool input
# The input format is JSON with a "command" field
COMMAND=$(echo "$INPUT" | grep -oP '"command"\s*:\s*"\K[^"]+' 2>/dev/null || echo "$INPUT")

# Normalize: remove extra spaces, convert to lowercase for pattern matching
NORMALIZED=$(echo "$COMMAND" | tr '[:upper:]' '[:lower:]' | tr -s ' ')

# =============================================================================
# Dangerous command patterns
# =============================================================================

# Force push patterns
if echo "$NORMALIZED" | grep -qE 'git\s+push\s+.*(-f|--force)'; then
    echo "BLOCKED: Force push detected. This can overwrite remote history."
    echo "Command: $COMMAND"
    echo ""
    echo "If you really need to force push, ask the user for explicit approval."
    exit 2
fi

# Hard reset patterns
if echo "$NORMALIZED" | grep -qE 'git\s+reset\s+.*--hard'; then
    echo "BLOCKED: Hard reset detected. This discards uncommitted changes permanently."
    echo "Command: $COMMAND"
    echo ""
    echo "Consider using 'git stash' to save changes before resetting."
    exit 2
fi

# Clean with force patterns
if echo "$NORMALIZED" | grep -qE 'git\s+clean\s+.*-[a-z]*f'; then
    echo "BLOCKED: git clean -f detected. This removes untracked files permanently."
    echo "Command: $COMMAND"
    echo ""
    echo "Consider using 'git clean -n' (dry-run) first to see what would be removed."
    exit 2
fi

# Checkout with force on branches (could lose changes)
if echo "$NORMALIZED" | grep -qE 'git\s+checkout\s+.*--force'; then
    echo "BLOCKED: git checkout --force detected. This can discard local changes."
    echo "Command: $COMMAND"
    echo ""
    echo "Consider using 'git stash' to save changes first."
    exit 2
fi

# Interactive rebase (not supported in non-interactive environment anyway)
if echo "$NORMALIZED" | grep -qE 'git\s+rebase\s+.*-i'; then
    echo "BLOCKED: Interactive rebase (-i) is not supported in this environment."
    echo "Command: $COMMAND"
    exit 2
fi

# Branch deletion with force
if echo "$NORMALIZED" | grep -qE 'git\s+branch\s+.*-D'; then
    echo "WARNING: Force branch deletion (-D) detected."
    echo "Command: $COMMAND"
    echo ""
    echo "This will delete the branch even if not fully merged."
    # Don't block, just warn (exit 0)
fi

# Amend without checking authorship (warn only)
if echo "$NORMALIZED" | grep -qE 'git\s+commit\s+.*--amend'; then
    echo "WARNING: Commit amend detected. Ensure you're the author of the last commit."
    echo "Run 'git log -1 --format=\"%an %ae\"' to verify authorship."
    # Don't block, just warn (exit 0)
fi

# Command passed all checks
exit 0
