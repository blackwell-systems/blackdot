# Roadmap & Future Improvements

This document outlines planned improvements and future work for the dotfiles system.

---

## Recently Completed (v2.0)

### Unified Setup Wizard ✅

**Status:** Complete (v2.0.0)

Single command `dotfiles setup` with:
- Five-phase setup: symlinks → packages → vault → secrets → claude
- Persistent state in `~/.config/dotfiles/state.ini`
- Resume support if interrupted
- State inference from existing installations

### macOS CLI Integration ✅

**Status:** Complete (v2.0.0)

```bash
dotfiles macos apply              # Apply all settings
dotfiles macos preview            # Dry-run mode
dotfiles macos discover           # Capture current settings
```

---

## Next Up

### 1. Template JSON Arrays

**Status:** Planning Complete - Ready for Implementation
**Document:** [PLAN-TEMPLATE-JSON.md](PLAN-TEMPLATE-JSON.md)

Add JSON configuration support for template arrays (currently shell-only):

**Current (awkward):**
```zsh
SSH_HOSTS=("github|github.com|git|~/.ssh/id_ed25519|")
```

**Proposed (clear):**
```json
{
  "ssh_hosts": [
    {"name": "github", "hostname": "github.com", "user": "git", "identity": "~/.ssh/id_ed25519"}
  ]
}
```

**Approach:** Hybrid - shell for variables (comments useful), JSON for arrays (structure clearer). No new dependencies (jq already required).

---

## Backlog

### 2. MCP Server for Claude Code Integration

**Status:** Concept - Not Started

Create an MCP (Model Context Protocol) server that allows Claude Code to directly interact with dotfiles operations.

**Why:** Currently, Claude interacts with dotfiles via shell commands. An MCP server would provide:
- **Native tool integration** - Claude sees `dotfiles_health_check`, `dotfiles_vault_sync` as first-class tools
- **Structured responses** - JSON responses instead of parsing shell output
- **Proactive actions** - Claude could auto-fix issues during coding sessions

**Proposed MCP Tools:**
```typescript
dotfiles_health_check()     // Returns structured health report
dotfiles_status()           // Quick status with issues count
dotfiles_vault_restore()    // Restore secrets (with drift check)
dotfiles_vault_sync(item?)  // Sync specific or all items
dotfiles_doctor_fix()       // Auto-repair issues
```

**Related:** [MCP Protocol](https://modelcontextprotocol.io/)

---

### 3. Session Management Improvements

**Status:** Not Started

Improve Bitwarden session handling:
- Sessions cached in `.bw-session` file
- No automatic cleanup of stale sessions
- No session validation retry logic

---

### 4. API/Function Reference Documentation

**Status:** Not Started

Generate documentation for all exported functions:
- `vault/_common.sh` - 27 functions
- `lib/_logging.sh` - 8 functions
- `lib/_state.sh` - 10+ functions
- `lib/_vault.sh` - 15+ functions
- `zsh/zsh.d/50-functions.zsh` - 15+ functions

---

## Design Decisions

### Path Convention: `~/workspace/dotfiles`

The system is designed around `~/workspace/dotfiles` as the canonical location:

1. **`/workspace` symlink** enables Claude Code session portability
2. **Install script** clones to `$HOME/workspace/dotfiles`
3. **Documentation** assumes this path

This is intentional, not a limitation. The `/workspace` symlink is core to the portable sessions feature.

**If you need a different location:**
1. Clone to your preferred location
2. Create symlink: `ln -s /your/path /workspace`
3. Update `DOTFILES_DIR` in scripts (not recommended)

---

## Version History

| Version | Focus |
|---------|-------|
| 1.0.0 | Initial release with vault integration |
| 1.1.0 | CLI commands (backup, diff, init, uninstall) |
| 1.2.0 | Integration tests, architecture docs |
| 1.3.0 | Shared library consolidation, error tests |
| 1.4.0 | Bootstrap consolidation, drift check |
| 1.5.0 | Offline mode support |
| 1.6.0 | CLI reorganization (bin/ directory) |
| 1.7.0 | Root directory cleanup |
| 1.8.0 | Windows support, git safety hooks, dotclaude integration |
| **2.0.0** | **Unified setup wizard, state management, macOS CLI** |
| 2.0.1 | CLI help improvements, Docker container enhancements |

---

## Contributing

When implementing improvements from this roadmap:

1. **Create a feature branch** from `main`
2. **Update tests** for any behavioral changes
3. **Update documentation** (README, docs/, CHANGELOG)
4. **Follow commit conventions** (`feat:`, `fix:`, `refactor:`)
5. **Run full test suite** before PR

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

*Last updated: 2025-12-02*
