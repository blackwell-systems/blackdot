# Roadmap & Future Improvements

This document outlines potential improvements and refactoring opportunities for the dotfiles system. These are not bugs - the current system works well - but represent opportunities for better code organization and maintainability.

---

## Current State (v1.5.0)

The dotfiles system is **production-ready** with:
- 80+ test cases across unit, integration, and error scenario tests
- CI/CD with 13 validation jobs (including error scenario tests)
- Comprehensive documentation (8,600+ lines)
- Cross-platform support (macOS, Linux, Windows, WSL2, Docker)
- Multi-vault integration (Bitwarden, 1Password, pass) with bidirectional sync
- Shared libraries for logging and bootstrap functions
- Pre-restore drift check for data safety
- Offline mode for air-gapped environments

---

## Completed Improvements

### ✅ Shared Library Adoption (v1.3.0)

**Status:** COMPLETED

**What:** Created `lib/_logging.sh` shared library to reduce code duplication (~15 lines per script).

**Updated scripts:**
- [x] `dotfiles-backup.sh`
- [x] `dotfiles-diff.sh`
- [x] `dotfiles-drift.sh`
- [x] `dotfiles-init.sh`
- [x] `show-metrics.sh`
- [x] `uninstall.sh`
- [x] `bootstrap-mac.sh`
- [x] `bootstrap-linux.sh`

**Intentionally not updated:**
- `install.sh` - Must remain standalone (runs via `curl | bash` before repo exists)

**Files:**
```
lib/
└── _logging.sh       # Bash-compatible shared library
```

---

### ✅ Error Scenario Test Coverage (v1.3.0)

**Status:** COMPLETED

**What:** Added comprehensive error scenario tests in `test/error_scenarios.bats`.

**Test categories covered:**
- [x] Permission denied errors (SSH directory, unreadable files)
- [x] Missing files/directories handling
- [x] Corrupted backup files
- [x] Invalid JSON data
- [x] Vault locked/session errors
- [x] Edge cases (special characters, long paths, symlink loops)
- [x] Concurrent execution safety
- [x] CLI argument validation

**Files:**
```
test/
├── error_scenarios.bats  # 20+ error handling tests
└── run_tests.sh          # Updated with 'error' mode
```

---

### ✅ Bootstrap Script Consolidation (v1.4.0)

**Status:** COMPLETED

**What:** Consolidated ~60% shared code between `bootstrap-mac.sh` and `bootstrap-linux.sh` into `bootstrap/_common.sh`.

**Consolidated functions:**
- [x] `parse_bootstrap_args()` - Argument parsing
- [x] `prompt_yes_no()` - Interactive prompts
- [x] `run_interactive_config()` - Interactive setup
- [x] `setup_workspace_layout()` - ~/workspace creation
- [x] `setup_workspace_symlink()` - /workspace symlink
- [x] `link_dotfiles()` - Dotfiles symlinking
- [x] `run_brew_bundle()` - Homebrew bundle
- [x] `add_brew_to_zprofile()` - Homebrew PATH setup

**Files:**
```
bootstrap/
└── _common.sh      # Shared bootstrap functions
bootstrap-mac.sh    # Sources bootstrap/_common.sh
bootstrap-linux.sh  # Sources bootstrap/_common.sh
```

---

### ✅ Pre-Restore Drift Check (v1.4.0)

**Status:** COMPLETED

**What:** Added safety check before `dotfiles vault restore` to detect local changes that would be overwritten.

**Better than auto-backup:** Instead of silently backing up and overwriting, we alert the user when local files have drifted from the vault, giving them the choice to:
1. Sync local changes to vault first (`dotfiles vault sync`)
2. Force overwrite (`dotfiles vault restore --force`)
3. Review differences (`dotfiles drift`)

**Implementation:**
- `check_item_drift()` - Check single item for drift
- `check_pre_restore_drift()` - Check all syncable items
- `skip_drift_check()` - Check DOTFILES_SKIP_DRIFT_CHECK env var

**Usage:**
```bash
# Normal restore (checks for drift)
dotfiles vault restore

# Skip drift check
dotfiles vault restore --force

# Skip drift check via env (for automation)
DOTFILES_SKIP_DRIFT_CHECK=1 dotfiles vault restore
```

---

## Suggested Improvements

### Priority: HIGH

*(All HIGH priority items completed)*

---

### ✅ Offline Mode Support (v1.5.0)

**Status:** COMPLETED

**What:** Run dotfiles without vault access for air-gapped environments, outages, or offline development.

**Implementation:**
- `is_offline()` - Check if DOTFILES_OFFLINE=1 is set
- `require_online()` - Skip vault operations gracefully in offline mode
- All vault scripts check offline mode before attempting vault operations

**Usage:**
```bash
# Skip vault operations during bootstrap
DOTFILES_OFFLINE=1 ./bootstrap/bootstrap-mac.sh

# Skip vault restore (keeps local files)
DOTFILES_OFFLINE=1 dotfiles vault restore

# Skip vault sync
DOTFILES_OFFLINE=1 dotfiles vault sync
```

**Use cases:**
- Air-gapped environments
- Vault service outages
- Development without vault access
- CI/CD without secrets

---

## Suggested Improvements

### Priority: HIGH

*(All HIGH priority items completed)*

---

### Priority: MEDIUM

*(All MEDIUM priority items completed)*

---

### ✅ CLI Script Reorganization (v1.6.0)

**Status:** COMPLETED

**What:** Moved CLI scripts to `bin/` directory for cleaner root.

**Before:**
```
dotfiles/
├── dotfiles-doctor.sh
├── dotfiles-drift.sh
├── dotfiles-backup.sh
├── dotfiles-diff.sh
├── dotfiles-init.sh
├── uninstall.sh
└── show-metrics.sh
```

**After:**
```
dotfiles/
└── bin/
    ├── dotfiles-doctor
    ├── dotfiles-drift
    ├── dotfiles-backup
    ├── dotfiles-diff
    ├── dotfiles-init
    ├── dotfiles-uninstall
    └── dotfiles-metrics
```

**Updated:**
- [x] `zsh/zsh.d/40-aliases.zsh` - dotfiles command paths
- [x] `test/cli_commands.bats` - Test paths
- [x] `test/integration.bats` - Test paths
- [x] `test/error_scenarios.bats` - Test paths
- [x] `.github/workflows/test.yml` - CI workflow paths
- [x] Documentation (README.md, docs/README.md, ROADMAP.md)

---

### Priority: LOW (Nice-to-have)

---

#### 7. MCP Server for Claude Code Integration

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

**Example MCP Server Architecture:**
```
mcp-server-dotfiles/
├── src/
│   ├── index.ts            # MCP server entry point
│   ├── tools/
│   │   ├── health.ts       # Health check tool
│   │   ├── vault.ts        # Vault operations
│   │   └── template.ts     # Template tools
│   └── utils/
│       └── shell.ts        # Execute dotfiles commands
├── package.json
└── README.md
```

**Implementation Approach:**
1. Create TypeScript MCP server using `@modelcontextprotocol/sdk`
2. Wrap existing shell scripts with structured JSON output
3. Add to Claude Code config: `"mcpServers": { "dotfiles": {...} }`
4. Claude gains native dotfiles tools

**Benefits:**
- Claude can proactively check/fix dotfiles health during sessions
- No need to remember `dotfiles doctor` commands
- Structured data flow between Claude and dotfiles
- Opens door for Claude-assisted dotfiles management

**Risk Mitigation:**
- MCP server is additive (existing CLI continues to work)
- Read-only operations by default, mutations require confirmation
- Session authentication passes through to vault

**Related:** [MCP Protocol](https://modelcontextprotocol.io/)

---

#### 8. Session Management Improvements

**Status:** Not started

**What:** Improve Bitwarden session handling.

**Current issues:**
- Sessions cached in `.bw-session` file
- No automatic cleanup of stale sessions
- No session validation retry logic

**Proposed improvements:**
```bash
# Session validation with retry
validate_session() {
    local session="$1"
    local retries=3

    for ((i=1; i<=retries; i++)); do
        if bw unlock --check --session "$session" 2>/dev/null; then
            return 0
        fi
        warn "Session validation failed (attempt $i/$retries)"
        sleep 1
    done
    return 1
}

# Session TTL check
is_session_expired() {
    local session_file="$1"
    local max_age=3600  # 1 hour

    if [[ -f "$session_file" ]]; then
        local age=$(($(date +%s) - $(stat -f %m "$session_file" 2>/dev/null || stat -c %Y "$session_file")))
        [[ $age -gt $max_age ]]
    else
        return 0  # No file = expired
    fi
}
```

---

#### 8. API/Function Reference Documentation

**Status:** Not started

**What:** Generate documentation for all exported functions.

**Affected files:**
- `vault/_common.sh` - 27 functions
- `lib/_logging.sh` - 8 functions
- `zsh/zsh.d/50-functions.zsh` - 15+ functions

**Format:**
```markdown
## vault/_common.sh

### get_ssh_key_paths()
Returns all SSH key paths as newline-separated list.

**Usage:**
```bash
paths=$(get_ssh_key_paths)
```

**Returns:** Newline-separated absolute paths
```

---

## Design Decisions (Not Bugs)

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
| 1.1.0 | Added CLI commands (backup, diff, init, uninstall) |
| 1.2.0 | Integration tests, architecture docs, release workflow |
| 1.2.1 | Mock Bitwarden CLI, comprehensive integration tests |
| 1.2.2 | Codecov integration, kcov coverage |
| 1.3.0 | Shared library consolidation, error scenario tests |
| 1.4.0 | Bootstrap consolidation, pre-restore drift check |
| 1.5.0 | Offline mode support |
| 1.6.0 | CLI reorganization (bin/ directory) |
| 1.7.0 | Root directory cleanup (bootstrap/, docs/) | ✓ Released |
| 1.8.0 | (Planned) Native Windows support, git safety hooks, marketing refresh |
| 1.9.0 | (Planned) MCP server for Claude Code integration |

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

*Last updated: 2025-11-28*
