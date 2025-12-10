# Claude Code Hooks

This directory contains hook scripts for Claude Code that enforce safe git practices and prevent accidental data loss.

**Cross-Platform Support:** Both Bash (`.sh`) and PowerShell (`.ps1`) versions are provided.

## Available Hooks

### `block-dangerous-git.sh` / `block-dangerous-git.ps1`

**Type:** PreToolUse
**Platforms:** Unix (Bash), Windows (PowerShell)

Blocks potentially destructive git commands:

| Command | Action | Reason |
|---------|--------|--------|
| `git push --force` / `-f` | BLOCKED | Can overwrite remote history |
| `git push --force-with-lease` | BLOCKED | Still dangerous without approval |
| `git reset --hard` | BLOCKED | Discards uncommitted changes permanently |
| `git clean -f` | BLOCKED | Removes untracked files permanently |
| `git checkout --force` | BLOCKED | Can discard local changes |
| `git rebase -i` | BLOCKED | Not supported in non-interactive env |
| `git branch -D` | WARNING | Force deletes unmerged branches |
| `git commit --amend` | WARNING | Check authorship first |

### `git-sync-check.sh` / `git-sync-check.ps1`

**Type:** SessionStart
**Platforms:** Unix (Bash), Windows (PowerShell)

Checks git sync status at session start:

- Fetches latest from remote
- Reports ahead/behind status
- Warns if branch has diverged
- Suggests resolution steps

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | OK - command allowed / in sync |
| 1 | Warning - action allowed but noted |
| 2 | Blocked - command not allowed |

## Usage

These hooks are configured in `claude/settings.json` and run automatically.

To test manually:

**Unix (Bash):**
```bash
# Test block-dangerous-git with a command
echo '{"command": "git push --force"}' | ./block-dangerous-git.sh

# Test sync check
./git-sync-check.sh
```

**Windows (PowerShell):**
```powershell
# Test block-dangerous-git with a command
'{"command": "git push --force"}' | .\block-dangerous-git.ps1

# Test sync check
.\git-sync-check.ps1
```

## Customization

To add custom blocked commands, edit the appropriate script:

**Bash (`block-dangerous-git.sh`):**
```bash
if echo "$NORMALIZED" | grep -qE 'pattern-here'; then
    echo "BLOCKED: Reason"
    exit 2
fi
```

**PowerShell (`block-dangerous-git.ps1`):**
```powershell
if ($Normalized -match 'pattern-here') {
    Write-Host "BLOCKED: Reason"
    exit 2
}
```

## Related

- [Claude Code Hooks Documentation](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Git Safety Rules](../CLAUDE.md#-git-safety-rules)
