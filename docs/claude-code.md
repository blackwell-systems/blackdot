# Claude Code Integration

> **The first dotfiles designed for AI-assisted development.**

This repository includes native Claude Code integration for portable sessions across machines.

---

## Why This Matters

If you use Claude Code across multiple machines, you've experienced the pain:
- Sessions reference paths like `/Users/john/projects/myapp` on Mac
- Continue on Linux and paths don't match
- Conversation context breaks, productivity tanks

**This repo solves it.**

---

## Features

### 1. Portable Sessions via `/workspace`

The bootstrap creates a symlink:
```
/workspace → ~/workspace
```

All Claude sessions use `/workspace/project` instead of platform-specific paths. Start on Mac, continue on Linux—same paths, same conversation.

**How it works:**
```zsh
# ~/.zshrc loads this automatically
export WORKSPACE="${WORKSPACE:-$HOME/workspace}"

# Bootstrap creates the symlink
sudo ln -sf "$HOME/workspace" /workspace
```

### 2. Auto-Redirect

Work in `~/workspace/project`? Claude automatically resolves to `/workspace/project`.

```zsh
# In zsh/zsh.d/00-init.zsh
cd() {
  builtin cd "$@"
  # Auto-redirect ~/workspace paths to /workspace for Claude compatibility
  if [[ "$PWD" == "$HOME/workspace"* ]]; then
    builtin cd "/workspace${PWD#$HOME/workspace}"
  fi
}
```

### 3. Git Safety Hooks

Claude Code sessions can accidentally cause merge conflicts. This repo includes defensive hooks:

#### SessionStart Hook

Automatically runs when Claude Code starts a session:
- Fetches latest from remote
- Reports ahead/behind status
- Warns if branch has diverged
- Suggests resolution steps

```bash
# Runs automatically on session start
claude/hooks/git-sync-check.sh
```

#### PreToolUse Hook (Defensive)

Blocks dangerous git commands before Claude executes them:

| Command | Action | Reason |
|---------|--------|--------|
| `git push --force` / `-f` | **BLOCKED** | Can overwrite remote history |
| `git reset --hard` | **BLOCKED** | Discards uncommitted changes |
| `git clean -f` | **BLOCKED** | Removes untracked files permanently |
| `git checkout --force` | **BLOCKED** | Can discard local changes |
| `git rebase -i` | **BLOCKED** | Not supported in non-interactive env |
| `git branch -D` | WARNING | Force deletes unmerged branches |
| `git commit --amend` | WARNING | Check authorship first |

#### Hook Configuration

The hooks are configured in `claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "claude/hooks/block-dangerous-git.sh" }]
      }
    ],
    "SessionStart": [
      {
        "hooks": [{ "type": "command", "command": "claude/hooks/git-sync-check.sh" }]
      }
    ]
  }
}
```

### 4. CLAUDE.md Guidelines

Every Claude Code session has access to `CLAUDE.md` which contains:
- Project structure and key files
- Coding standards
- Git safety rules
- Documentation requirements
- Review checklist

This ensures consistent AI assistance across sessions.

### 5. Custom Slash Commands

The `claude/commands/` directory can contain custom slash commands for Claude Code.

---

## Setup

Claude Code integration is **automatic** when you run the bootstrap:

```bash
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash
```

To skip the `/workspace` symlink (not recommended for Claude users):
```bash
SKIP_WORKSPACE_SYMLINK=1 ./bootstrap-mac.sh
```

---

## Multi-Backend Support

Works with Claude via any provider:
- Anthropic Max (direct)
- AWS Bedrock
- Google Cloud Vertex AI
- Any Claude API endpoint

The `/workspace` symlink works regardless of how you access Claude.

---

## Comparison

| Feature | This Repo | chezmoi | yadm | dotbot |
|---------|-----------|---------|------|--------|
| Portable Claude sessions | Yes | No | No | No |
| Git safety hooks | Yes | No | No | No |
| CLAUDE.md guidelines | Yes | No | No | No |
| Auto-redirect paths | Yes | No | No | No |
| Session start validation | Yes | No | No | No |

---

## Customization

### Adding Custom Hooks

Edit `claude/hooks/block-dangerous-git.sh` to add patterns:

```bash
# Block a specific command pattern
if echo "$NORMALIZED" | grep -qE 'dangerous-pattern'; then
    echo "BLOCKED: Reason"
    exit 2
fi
```

### Disabling Hooks

Remove the hook configuration from `claude/settings.json` or comment out specific hooks.

### Custom Slash Commands

Create markdown files in `claude/commands/`:
```bash
# claude/commands/deploy.md
Deploy the current branch to staging environment.
Run: npm run deploy:staging
```

---

## Troubleshooting

### Sessions not syncing

Ensure `/workspace` symlink exists:
```bash
ls -la /workspace
# Should show: /workspace -> /home/user/workspace
```

If missing:
```bash
sudo ln -sf "$HOME/workspace" /workspace
```

### Hooks not running

Check `claude/settings.json` exists and has correct format:
```bash
cat claude/settings.json | jq .
```

Verify hook scripts are executable:
```bash
ls -la claude/hooks/
# Should show: -rwxr-xr-x for .sh files
```

### Permission denied on /workspace

On some systems you need sudo:
```bash
sudo ln -sf "$HOME/workspace" /workspace
```

Or use a user-writable location:
```bash
WORKSPACE="$HOME/.workspace" ./bootstrap-mac.sh
```

---

## dotclaude Integration

This repo integrates with [dotclaude](https://github.com/blackwell-systems/dotclaude) for Claude Code profile management across machines.

### Architecture: Two Tools, Loosely Connected

```
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│           dotfiles              │     │           dotclaude             │
│  (shell config, secrets, etc)   │     │   (Claude profile management)   │
├─────────────────────────────────┤     ├─────────────────────────────────┤
│                                 │     │                                 │
│  dotfiles status    ───────────────────► shows Claude profile status   │
│  dotfiles doctor    ───────────────────► checks Claude health          │
│  dotfiles drift     ───────────────────► detects profile changes       │
│  dotfiles vault pull ───────────────► restores profiles.json        │
│  dotfiles packages  ───────────────────► suggests dotclaude install    │
│  dotfiles setup     ───────────────────► offers dotclaude setup        │
│                                 │     │                                 │
└─────────────────────────────────┘     └─────────────────────────────────┘
                                              ▲
                                              │
                                        User runs directly:
                                        dotclaude list
                                        dotclaude switch work
                                        dotclaude create personal
```

**Key principle:** dotclaude is NOT wrapped or hidden. Users run it directly for all profile management. dotfiles just "knows about" dotclaude to enhance existing commands.

### What's Integrated

| Command | Claude Integration |
|---------|-------------------|
| `dotfiles status` | Shows active Claude profile |
| `dotfiles doctor` | Validates Claude/dotclaude setup |
| `dotfiles vault pull` | Restores Claude profiles.json |
| `dotfiles drift` | Detects profile changes vs vault |
| `dotfiles packages` | Suggests dotclaude for Claude users |
| `dotfiles setup` | Offers dotclaude installation |

### How It Works

1. **dotclaude** manages profiles in `~/code/dotclaude/profiles/`
2. **dotclaude** auto-generates `~/.claude/profiles.json` on activate/create
3. **dotfiles vault** syncs `profiles.json` to your password manager
4. **dotfiles vault pull** restores it on new machines

The `profiles.json` format:
```json
{
  "active": "work-bedrock",
  "profiles": {
    "work-bedrock": {"backend": "bedrock", "created": "2025-11-30"},
    "personal-max": {"backend": "max", "created": "2025-11-28"}
  }
}
```

### Quick Setup

```bash
# Install dotclaude (if not already)
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotclaude/main/install.sh | bash

# Create and activate a profile
dotclaude create my-project
dotclaude activate my-project

# Sync to vault
dotfiles vault push Claude-Profiles

# On new machine, restore everything including Claude profiles
dotfiles vault pull
```

### New Developer Onboarding

```bash
# One command gets everything
curl -fsSL .../install.sh | bash

# Unlock vault and restore secrets (including Claude profiles)
bw login
export BW_SESSION="$(bw unlock --raw)"
dotfiles vault pull

# Verify setup
dotfiles doctor
# All systems green, including Claude

# Ready to work
dotclaude list
# Shows restored profiles
```

### Without dotclaude

If you use Claude Code without dotclaude:
- `dotfiles status` shows a gentle hint: `try: dotclaude`
- `dotfiles doctor` suggests installation with instructions
- `dotfiles packages` mentions dotclaude availability
- No impact on other dotfiles functionality - completely optional

---

## Future: MCP Server Integration

We're exploring deeper Claude integration via [Model Context Protocol (MCP)](https://modelcontextprotocol.io/). See [Roadmap](ROADMAP.md#mcp-server-concept) for details.

Potential capabilities:
- `dotfiles://status` - Health dashboard
- `dotfiles://secrets/restore` - Trigger vault restore
- `dotfiles://doctor` - Run health checks
- Native tool integration without shell commands

---

## Related Documentation

- [CLAUDE.md](https://github.com/blackwell-systems/dotfiles/blob/main/CLAUDE.md) - Session guidelines
- [claude/hooks/README.md](https://github.com/blackwell-systems/dotfiles/blob/main/claude/hooks/README.md) - Hook customization
- [Roadmap](ROADMAP.md) - Future plans including MCP
