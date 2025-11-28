Help troubleshoot Bitwarden vault issues.

First, check the current state:

```bash
# Check if logged in
bw status 2>/dev/null | head -5

# Check if session is valid
if [[ -n "$BW_SESSION" ]]; then
  bw unlock --check --session "$BW_SESSION" 2>/dev/null && echo "Session valid" || echo "Session expired"
else
  echo "No BW_SESSION set"
fi
```

Common fixes:
- **Not logged in**: `bw login`
- **Session expired**: `export BW_SESSION="$(bw unlock --raw)"`
- **Check items exist**: `dotfiles vault check`
- **Restore secrets**: `dotfiles vault restore`
- **Sync local changes**: `dotfiles vault sync --all`
