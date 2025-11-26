# Claude Code - Global Instructions

## Environment

- **Shell**: zsh (macOS default + Lima Linux)
- **Package Manager**: Homebrew (both platforms)
- **Secrets**: Bitwarden CLI (`bw`) with vault scripts in `~/workspace/dotfiles/vault/`

## Workspace Layout

```
~/workspace/
├── dotfiles/       # This dotfiles repo
├── code/           # Project repositories
└── .claude/        # Shared Claude state (symlinked from ~/.claude)
```

## Key Commands

| Command | Purpose |
|---------|---------|
| `bw-restore` | Restore all secrets from Bitwarden |
| `bw-sync` | Sync local changes to Bitwarden |
| `bw-check` | Verify vault items exist |
| `bw-list` | List vault items |
| `dotfiles-doctor` | Health check for dotfiles setup |
| `dotfiles-update` | Pull latest dotfiles and re-source |

## Claude Routing

| Command | Backend |
|---------|---------|
| `claude-bedrock` | AWS Bedrock (enterprise) |
| `claude-max` | Claude Max subscription |
| `claude-run bedrock/max` | Explicit routing |

## Preferences

- Use zsh syntax for shell scripts (not bash)
- Prefer `printf '%s'` over `echo` for piping content
- Use `typeset -A` for associative arrays (zsh idiom)
- Follow existing code style in each project
