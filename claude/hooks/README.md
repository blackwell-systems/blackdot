# Claude Code Hooks

This directory contains hook scripts for Claude Code that enforce safe git practices and prevent accidental data loss.

## Available Hooks

### `block-dangerous-git.sh`

**Type:** PreToolUse (Bash)

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

### `git-sync-check.sh`

**Type:** SessionStart

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
```bash
# Test block-dangerous-git with a command
echo '{"command": "git push --force"}' | ./block-dangerous-git.sh

# Test sync check
./git-sync-check.sh
```

## Customization

To add custom blocked commands, edit `block-dangerous-git.sh` and add patterns:

```bash
if echo "$NORMALIZED" | grep -qE 'pattern-here'; then
    echo "BLOCKED: Reason"
    exit 2
fi
```

## Related

- [Claude Code Hooks Documentation](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Git Safety Rules](../CLAUDE.md#-git-safety-rules)
