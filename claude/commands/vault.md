Help troubleshoot vault issues (Bitwarden, 1Password, or pass).

First, check the current state:

```bash
# Check configured backend
echo "Backend: ${BLACKDOT_VAULT_BACKEND:-bitwarden}"

# Bitwarden status
bw status 2>/dev/null | head -5

# 1Password status
op account get 2>/dev/null && echo "1Password: signed in" || echo "1Password: not signed in"

# pass status
[[ -d "$HOME/.password-store" ]] && echo "pass: initialized" || echo "pass: not initialized"
```

Common fixes by backend:

**Bitwarden:**
- Not logged in: `bw login`
- Session expired: `export BW_SESSION="$(bw unlock --raw)"`

**1Password:**
- Not signed in: `op signin`

**pass:**
- Not initialized: `pass init <gpg-id>`

**All backends:**
- Check items exist: `dotfiles vault check`
- Restore secrets: `dotfiles vault restore`
- Sync local changes: `dotfiles vault sync --all`
