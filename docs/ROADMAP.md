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

## Recently Completed (v2.1.0)

### Smart Secrets Onboarding ✅

**Status:** Complete (v2.1.0)

Interactive vault item setup wizard:
```bash
dotfiles vault setup  # Guides first-time vault users
```
- Detects existing local secrets (SSH keys, AWS config, Git config)
- Offers to create vault items for each detected secret
- Validates vault item schema before creation
- Works with any vault backend (Bitwarden, 1Password, pass)

### Vault Items Configuration File ✅

**Status:** Complete (v2.1.0)

User-editable JSON configuration for vault items:
- `~/.config/dotfiles/vault-items.json` for customization
- No need to edit source code to add/remove items
- Created automatically by `dotfiles vault setup`

### Template JSON Arrays ✅

**Status:** Complete (v2.1.0)

JSON configuration support for template arrays:
- `templates/_arrays.local.json` for cleaner SSH host definitions
- `dotfiles template arrays` command to view/manage
- Falls back to shell arrays if no JSON file
- Export existing shell arrays to JSON with `--export-json`

### Docker Container Taxonomy ✅

**Status:** Complete (v2.1.0)

Four container sizes for different use cases:
| Container | Size | Use Case |
|-----------|------|----------|
| `extralite` | ~50MB | Quick CLI exploration |
| `lite` | ~200MB | Vault command testing |
| `medium` | ~400MB | Full CLI + Homebrew |
| `full` | ~800MB+ | Complete environment |

### Mock Vault for Testing ✅

**Status:** Complete (v2.1.0)

Test vault functionality without real credentials:
```bash
./test/mocks/setup-mock-vault.sh --no-pass
```

---

## Backlog

### 1. Interactive Template Setup

**Status:** Consideration

Add an interactive mode to `dotfiles template init` that prompts for common variables:

```bash
dotfiles template init --interactive
# or make init more interactive by default
```

**Potential prompts:**
- Git name and email
- Machine type (work/personal)
- GitHub username
- AWS profile

**Tradeoffs:**
- **Pro:** Lower barrier for first-time users, no need to understand shell syntax
- **Pro:** Consistent with `dotfiles setup` wizard pattern
- **Con:** Current `init` already opens editor with well-commented example
- **Con:** Most dotfiles users are comfortable editing files

**Decision:** Consider implementing as lightweight prompts for essentials only, then open editor for advanced customization.

---

### 3. MCP Server for Claude Code Integration

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

### 4. Session Management Improvements

**Status:** Not Started

Improve Bitwarden session handling:
- Sessions cached in `.bw-session` file
- No automatic cleanup of stale sessions
- No session validation retry logic

---

### 5. API/Function Reference Documentation

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
| **2.1.0** | **Smart secrets onboarding, vault config file, Docker taxonomy** |

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

*Last updated: 2025-12-04*
