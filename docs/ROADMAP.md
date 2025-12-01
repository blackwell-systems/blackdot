# Roadmap & Future Improvements

This document outlines planned improvements and future work for the dotfiles system.

---

## Planned Future Work

The following items have detailed planning documents and are ready for implementation.

---

### 1. dotclaude Integration

**Status:** In Progress - Prerequisites Complete
**Document:** [INTEGRATION-DOTCLAUDE.md](INTEGRATION-DOTCLAUDE.md)

Integrate dotfiles with [dotclaude](https://dotclaude.dev) (Claude Code profile management) as complementary products:

- `dotfiles status` shows active Claude profile
- `dotfiles doctor` validates Claude setup
- `dotfiles vault restore` includes Claude profiles
- `dotfiles init` offers dotclaude installation
- No wrapper commands - dotclaude used directly

**Principle:** Loose coupling - each product remains fully independent.

**Progress:**
- ✅ dotclaude `active` command (machine-readable profile name)
- ✅ dotclaude `sync_profiles_json()` (auto-generates `~/.claude/profiles.json`)
- ✅ Auto-sync on `activate` and `create` commands
- ⏳ dotfiles status integration
- ⏳ dotfiles doctor integration
- ⏳ dotfiles vault integration

---

### 2. Template JSON Arrays

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

### 3. macOS CLI Integration

**Status:** Concept - Not Started

Currently, macOS settings are standalone scripts not exposed via the CLI:

```
macos/
├── settings.sh           # 60+ defaults write commands
├── apply-settings.sh     # Runner script
└── discover-settings.sh  # Snapshot tool
```

**Proposed CLI:**
```bash
dotfiles macos apply              # Apply all settings
dotfiles macos apply --dry-run    # Preview changes
dotfiles macos apply dock         # Apply dock settings only
dotfiles macos diff               # Compare current vs desired
dotfiles macos list               # List categories
```

**Benefits:**
- Consistent CLI experience
- Category-based apply
- Drift detection for macOS settings
- Integration with `dotfiles doctor`

**Considerations:**
- macOS-only feature (needs graceful skip on Linux)
- "Set once, forget" for most users - lower priority

---

## Other Ideas (Backlog)

The following are concepts that may be implemented in the future.

---

#### 4. MCP Server for Claude Code Integration

**Status:** Not started (Concept documented)

**What:** Create an MCP (Model Context Protocol) server that allows Claude Code to directly interact with dotfiles operations.

**Why:** Currently, Claude interacts with dotfiles via shell commands. An MCP server would provide:
- **Native tool integration** - Claude sees `dotfiles_health_check`, `dotfiles_vault_sync` as first-class tools
- **Structured responses** - JSON responses instead of parsing shell output
- **Proactive actions** - Claude could auto-fix issues during coding sessions
- **Real-time status** - Claude knows dotfiles health without running commands

**Proposed MCP Tools:**
```typescript
// Health & Status
dotfiles_health_check()     // Returns structured health report
dotfiles_status()           // Quick status with issues count
dotfiles_drift_check()      // Check vault drift

// Vault Operations
dotfiles_vault_restore()    // Restore secrets (with drift check)
dotfiles_vault_sync(item?)  // Sync specific or all items
dotfiles_vault_list()       // List vault items

// Configuration
dotfiles_template_render()  // Generate machine-specific configs
dotfiles_doctor_fix()       // Auto-repair issues
```

**Related:** [MCP Protocol](https://modelcontextprotocol.io/)

---

#### 5. Session Management Improvements

**Status:** Not started

**What:** Improve Bitwarden session handling.

**Current issues:**
- Sessions cached in `.bw-session` file
- No automatic cleanup of stale sessions
- No session validation retry logic

---

#### 6. API/Function Reference Documentation

**Status:** Not started

**What:** Generate documentation for all exported functions.

**Affected files:**
- `vault/_common.sh` - 27 functions
- `lib/_logging.sh` - 8 functions
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
| 1.8.0 | (Planned) Windows support, git safety hooks |
| 1.9.0 | (Planned) MCP server integration |

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

*Last updated: 2025-12-01*
