# Session Context Notes

**Last Updated:** 2025-11-27
**Purpose:** Reconstruct Claude session context when claude.ai/code loses state

---

## Current State Summary

The dotfiles repo is fully functional with all features intact. Recent session work:
- Added lazy loading for nvm and sdkman (faster shell startup)
- Added zellij config to dotfiles (Elegant theme matching Ghostty)
- Added btop to Brewfile
- Added macOS settings discovery and apply scripts
- Decided NOT to modularize zshrc (well-organized as-is at ~820 lines)

### Recent Commits (most recent first)
```
879cced Revert: Remove Cyber Weapons Suite
9838dd5 Add Cyber Weapons Suite for terminal domination (REVERTED)
0896d62 status: use Joan Stark inspired city silhouette
582c8cb status: restore diagnostics with improved city skyline
e5f6d37 status: simplify to minimal wireframe skyline
```

---

## Features Currently Implemented

### 1. Status Dashboard (`status`)
- City skyline themed dashboard with Unicode art (Joan Stark inspired)
- Shows: zshrc symlink, claude symlink, /workspace symlink, SSH keys, AWS auth, Lima status
- Displays diagnostic info and suggested fixes
- Location: `zsh/zshrc` lines 191-273

### 2. Project Navigation (`j`)
- Fuzzy jump to any git project in /workspace using fzf
- Uses fd for speed when available, falls back to find
- Location: `zsh/zshrc` lines 279-305

### 3. Quick Notes (`note`, `notes`)
- `note <text>` - Save timestamped note to ~/workspace/.notes.md
- `notes` - View last 20 notes
- `notes all` - View all notes
- `notes edit` - Open in editor
- `notes search <term>` - Search notes
- Location: `zsh/zshrc` lines 311-359

### 4. AWS Profile Management
Commands with ASCII art banner via `awstools`:
- `awsprofiles` - List all profiles (* = active)
- `awsswitch` - Fuzzy-select profile with fzf + auto-login
- `awsset <profile>` - Set AWS_PROFILE
- `awsunset` - Clear AWS_PROFILE
- `awswho` - Show current identity
- `awslogin [profile]` - SSO login
- `awsassume <role-arn>` - Assume role for cross-account
- `awsclear` - Clear temporary credentials
- Location: `zsh/zshrc` lines 419-567

### 5. Modern CLI Tools (in Brewfile)
- `zoxide` - Smart cd that learns habits (`z` command)
- `glow` - Render markdown beautifully (`md`, `readme` aliases)
- `dust` - Visual disk usage (`du`, `dus`, `dud` aliases)
- `yazi` - Terminal file manager (`y`, `fm` aliases)
- `yq` - jq for YAML files
- `btop` - Beautiful system monitor (htop replacement)
- `eza` - Modern ls replacement (various `ll`, `la`, `lt` aliases)
- `fzf` - Fuzzy finder (Ctrl+R, Ctrl+T, Alt+C)
- `fd` - Fast find alternative
- `ripgrep` - Fast grep (`rg`)

### 6. Lazy Loading (Performance)
- NVM lazy loaded - only initializes when node/npm/nvm/yarn/pnpm called
- SDKMAN lazy loaded - only initializes when sdk/java/gradle/mvn called
- Saves 200-400ms on shell startup

### 7. Zellij Config
- Location: `zellij/config.kdl`
- Symlinked to `~/.config/zellij/config.kdl`
- Features: Alt+arrows for pane nav, Alt+n/p for tabs, Alt+1-9 for tab jump
- Scroll mode: arrows, PageUp/Down, Home/End

### 8. Cross-Platform Clipboard (`copy`, `paste`)
- Works on macOS, Linux X11/Wayland, WSL
- Aliases: `cb`, `cbp`
- Location: `zsh/zshrc` lines 717-754

### 9. Claude Routing Helpers
- `claude` - Wrapper that uses /workspace path for portable sessions
- `claude-bedrock` - Run via AWS Bedrock
- `claude-max` - Run via Max subscription
- `claude-run {bedrock|max}` - Unified interface
- Location: `zsh/zshrc` lines 572-681

### 10. Git Shortcuts
- Standard aliases: `gst`, `gss`, `ga`, `gaa`, `gco`, `gcb`, `gd`, `gds`, `gpl`, `gp`, `gpf`, `gcm`, `gca`, `gl1`, `glg`
- Location: `zsh/zshrc` lines 685-711

### 11. macOS System Settings
- Location: `macos/`
- `discover-settings.sh` - Capture current settings, diff changes, generate settings.sh
- `apply-settings.sh` - Apply settings from settings.sh
- `settings.sh` - The actual defaults commands to run
- Covers: trackpad, mouse, keyboard, dock, finder, screenshots

---

## Directory Structure
```
~/workspace/dotfiles/
├── Brewfile              # Shared packages (macOS + Lima)
├── README.md             # Full documentation
├── NOTES.md              # THIS FILE - session context
├── CHANGELOG.md          # Version history
├── bootstrap-dotfiles.sh # Symlink setup
├── bootstrap-lima.sh     # Lima-specific bootstrap
├── bootstrap-mac.sh      # macOS-specific bootstrap
├── check-health.sh       # Verify installation
├── claude/               # Claude Code settings + commands
├── ghostty/              # Ghostty terminal config
├── lima/                 # Lima VM config
├── macos/                # macOS system settings
│   ├── discover-settings.sh
│   ├── apply-settings.sh
│   └── settings.sh
├── vault/                # Bitwarden-based secret management
├── zellij/
│   └── config.kdl        # Zellij multiplexer config
└── zsh/
    ├── zshrc             # Main shell config (~820 lines)
    └── p10k.zsh          # Powerlevel10k theme
```

---

## What Was Rolled Back

The "Cyber Weapons Suite" (commit 9838dd5) was reverted. It included:
- Claude pipe functions (claude-review, claude-explain, claude-fix, etc.)
- Parallel execution helpers
- Git time machine
- Matrix mode (cmatrix)
- System pulse dashboard
- Self-healing alias suggestions

**Reason for rollback:** Too theatrical, didn't match desired workflow. User may want to revisit some features in a more practical form later.

---

## Architectural Decisions

### Canonical Workspace (`~/workspace`)
- All work lives in `~/workspace` regardless of OS/username
- `/workspace` symlink enables portable Claude sessions
- Lima mounts macOS `~/workspace` into the VM
- Shared history at `~/workspace/.zsh_history`

### Bitwarden Vault System
- SSH keys, AWS creds, git config stored in Bitwarden Secure Notes
- `vault/*.sh` scripts handle restore/sync
- `bw-restore` alias runs full bootstrap
- Required items: SSH-GitHub-Enterprise, SSH-GitHub-Blackwell, SSH-Config, AWS-Config, AWS-Credentials, Git-Config

### Cross-Platform Design
- Same zshrc works on macOS and Lima/Linux
- OS detection: `$OS` variable set from `uname -s`
- Conditional blocks for OS-specific config
- Brewfile uses `on_macos do` / `on_linux do` blocks

---

## Quick Reference Commands

```bash
# Status & Health
status              # Dashboard with city skyline art
dotfiles-doctor     # Run health check + vault validation
check-health.sh     # Detailed health verification

# Navigation
j                   # Fuzzy jump to git project
z <partial>         # Smart directory jump (zoxide)
cws / ccode         # Jump to workspace/code

# AWS
awstools            # Show all AWS commands with banner
awsswitch           # Interactive profile selector
awslogin            # SSO login

# Notes
note "text"         # Quick note
notes               # View recent notes

# Vault
bw-restore          # Restore all secrets from Bitwarden
bw-sync             # Sync local changes to Bitwarden

# Claude
claude-bedrock      # Use Bedrock backend
claude-max          # Use Max subscription
```

---

## Pending/Future Ideas

These were discussed but not implemented (or were reverted):
- [ ] More practical Claude pipe functions (piping output to Claude)
- [ ] Lazygit integration (in Brewfile but no aliases)
- [ ] Zellij-specific enhancements
- [ ] More subdued terminal aesthetics (vs. theatrical "cyber weapons")

---

## Troubleshooting Session Loss

When claude.ai/code loses session state:

1. **Check git log** - See what was actually committed
   ```bash
   git log --oneline -10
   ```

2. **Read this file** - Reconstruct context from NOTES.md

3. **Check zshrc** - Current functions are all in `zsh/zshrc`

4. **Tell Claude:**
   > "Read NOTES.md for session context. The interface lost our conversation history."

---

## Contact/Report Bug

The session persistence bug should be reported:
https://github.com/anthropics/claude-code/issues

---

*This file should be updated when significant changes are made to capture context for future sessions.*
