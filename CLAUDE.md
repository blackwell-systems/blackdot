# Dotfiles

Vault-backed configuration management for macOS and Linux.

## Quick Reference

```bash
dotfiles status          # Visual dashboard
dotfiles doctor          # Health check
dotfiles doctor --fix    # Auto-fix permissions
dotfiles drift           # Compare local vs Bitwarden vault
dotfiles vault restore   # Restore secrets from Bitwarden
dotfiles vault sync      # Sync local to Bitwarden
dotfiles upgrade         # Pull latest and run bootstrap
```

## Project Structure

```
dotfiles/
├── zsh/zsh.d/*.zsh      # Shell config (numbered load order: 00-99)
├── vault/*.sh           # Bitwarden integration scripts
├── bootstrap-*.sh       # Platform setup (mac/linux)
├── dotfiles-*.sh        # CLI tools (doctor, drift)
├── claude/              # Claude Code config & commands
└── docs/                # Docsify documentation site
```

## Key Files

| File | Purpose |
|------|---------|
| `zsh/zsh.d/40-aliases.zsh` | The `dotfiles` command lives here |
| `zsh/zsh.d/50-functions.zsh` | Shell functions including `status` |
| `vault/_common.sh` | Shared vault functions, SSH_KEYS config |
| `dotfiles-doctor.sh` | Health check implementation |

## Conventions

- **Shell**: All scripts use zsh (not bash)
- **Secrets**: Never committed - stored in Bitwarden Secure Notes
- **Permissions**: SSH keys must be 600, configs 600
- **CLI**: All operations via unified `dotfiles` command
- **Docs**: Keep README.md and docs/README.md in sync

## Testing

```bash
dotfiles doctor              # Health check
dotfiles drift               # Vault sync status
./test/run_tests.sh          # BATS unit tests
zsh -n script.sh             # Syntax check
```

## Common Tasks

**Add new SSH key to vault system:**
1. Add to `SSH_KEYS` array in `vault/_common.sh`
2. Run `dotfiles vault sync SSH-NewKey`
3. Update `~/.ssh/config`

**Debug vault issues:**
1. `dotfiles vault check` - verify items exist
2. `dotfiles vault list` - see all items
3. `dotfiles drift` - compare local vs vault
