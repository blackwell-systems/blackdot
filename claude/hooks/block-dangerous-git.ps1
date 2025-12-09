# =============================================================================
# block-dangerous-git.ps1 - PreToolUse hook to block dangerous git commands
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

$ErrorActionPreference = 'Stop'

# Read the tool input from stdin
$Input = $input | Out-String

# Extract the command from the Bash tool input
# The input format is JSON with a "command" field
try {
    $Json = $Input | ConvertFrom-Json
    $Command = $Json.command
} catch {
    $Command = $Input
}

if (-not $Command) {
    exit 0
}

# Normalize: convert to lowercase for pattern matching
$Normalized = $Command.ToLower() -replace '\s+', ' '

# =============================================================================
# Dangerous command patterns
# =============================================================================

# Force push patterns
if ($Normalized -match 'git\s+push\s+.*(-f|--force)') {
    Write-Host "BLOCKED: Force push detected. This can overwrite remote history."
    Write-Host "Command: $Command"
    Write-Host ""
    Write-Host "If you really need to force push, ask the user for explicit approval."
    exit 2
}

# Hard reset patterns
if ($Normalized -match 'git\s+reset\s+.*--hard') {
    Write-Host "BLOCKED: Hard reset detected. This discards uncommitted changes permanently."
    Write-Host "Command: $Command"
    Write-Host ""
    Write-Host "Consider using 'git stash' to save changes before resetting."
    exit 2
}

# Clean with force patterns
if ($Normalized -match 'git\s+clean\s+.*-[a-z]*f') {
    Write-Host "BLOCKED: git clean -f detected. This removes untracked files permanently."
    Write-Host "Command: $Command"
    Write-Host ""
    Write-Host "Consider using 'git clean -n' (dry-run) first to see what would be removed."
    exit 2
}

# Checkout with force on branches (could lose changes)
if ($Normalized -match 'git\s+checkout\s+.*--force') {
    Write-Host "BLOCKED: git checkout --force detected. This can discard local changes."
    Write-Host "Command: $Command"
    Write-Host ""
    Write-Host "Consider using 'git stash' to save changes first."
    exit 2
}

# Interactive rebase (not supported in non-interactive environment anyway)
if ($Normalized -match 'git\s+rebase\s+.*-i') {
    Write-Host "BLOCKED: Interactive rebase (-i) is not supported in this environment."
    Write-Host "Command: $Command"
    exit 2
}

# Branch deletion with force
if ($Normalized -match 'git\s+branch\s+.*-D') {
    Write-Host "WARNING: Force branch deletion (-D) detected."
    Write-Host "Command: $Command"
    Write-Host ""
    Write-Host "This will delete the branch even if not fully merged."
    # Don't block, just warn (exit 0)
}

# Amend without checking authorship (warn only)
if ($Normalized -match 'git\s+commit\s+.*--amend') {
    Write-Host "WARNING: Commit amend detected. Ensure you're the author of the last commit."
    Write-Host "Run 'git log -1 --format=`"%an %ae`"' to verify authorship."
    # Don't block, just warn (exit 0)
}

# Command passed all checks
exit 0
