# =============================================================================
# git-sync-check.ps1 - Check git sync status before operations
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

$ErrorActionPreference = 'SilentlyContinue'

# Get the current branch name
$Branch = git rev-parse --abbrev-ref HEAD 2>$null

if (-not $Branch) {
    Write-Host "Warning: Not in a git repository" -ForegroundColor Yellow
    exit 0
}

# Get the remote tracking branch
$Upstream = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null

if (-not $Upstream) {
    Write-Host "Info: Branch '$Branch' has no remote tracking branch" -ForegroundColor Blue
    exit 0
}

# Fetch latest from remote (quietly)
git fetch --quiet 2>$null

# Get ahead/behind counts
$Ahead = git rev-list --count '@{u}..HEAD' 2>$null
if (-not $Ahead) { $Ahead = 0 }

$Behind = git rev-list --count 'HEAD..@{u}' 2>$null
if (-not $Behind) { $Behind = 0 }

# Check status
if ($Ahead -eq 0 -and $Behind -eq 0) {
    Write-Host "✓ Branch '$Branch' is in sync with '$Upstream'" -ForegroundColor Green
    exit 0
}
elseif ($Ahead -gt 0 -and $Behind -eq 0) {
    Write-Host "Info: Branch '$Branch' is $Ahead commit(s) ahead of '$Upstream'" -ForegroundColor Blue
    Write-Host "  Consider pushing your changes: git push"
    exit 0
}
elseif ($Ahead -eq 0 -and $Behind -gt 0) {
    Write-Host "Warning: Branch '$Branch' is $Behind commit(s) behind '$Upstream'" -ForegroundColor Yellow
    Write-Host "  Run 'git pull --rebase' before making changes to avoid conflicts."
    exit 1
}
elseif ($Ahead -gt 0 -and $Behind -gt 0) {
    Write-Host "ERROR: Branch '$Branch' has DIVERGED from '$Upstream'" -ForegroundColor Red
    Write-Host "  Local is $Ahead commit(s) ahead and $Behind commit(s) behind."
    Write-Host ""
    Write-Host "  This requires manual intervention. Options:"
    Write-Host "    1. git pull --rebase  (rebase local commits on top of remote)"
    Write-Host "    2. git merge origin/$Branch  (create a merge commit)"
    Write-Host "    3. Ask the user how to proceed"
    Write-Host ""
    Write-Host "  DO NOT proceed with changes until this is resolved!"
    exit 2
}
