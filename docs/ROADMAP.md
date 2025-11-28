# Roadmap & Future Improvements

This document outlines potential improvements and refactoring opportunities for the dotfiles system. These are not bugs - the current system works well - but represent opportunities for better code organization and maintainability.

---

## Current State (v1.2.x)

The dotfiles system is **production-ready** with:
- 60+ test cases across unit and integration tests
- CI/CD with 12 validation jobs
- Comprehensive documentation (8,600+ lines)
- Cross-platform support (macOS, Linux, Windows, WSL2, Docker)
- Bitwarden vault integration with bidirectional sync

---

## Suggested Improvements

### Priority: HIGH

#### 1. Complete Shared Library Adoption

**Status:** Partially complete

**What:** The `lib/_logging.sh` shared library was created to reduce code duplication. Some scripts have been updated, others still have inline definitions.

**Scripts still needing update:**
- [ ] `install.sh` - Has inline color/logging definitions
- [ ] `uninstall.sh` - Has inline color/logging definitions
- [ ] `show-metrics.sh` - Has inline color definitions
- [ ] `bootstrap-mac.sh` - Has inline logging (but needs bash compatibility)
- [ ] `bootstrap-linux.sh` - Has inline logging (but needs bash compatibility)

**Note:** Bootstrap scripts use `/bin/bash` shebang for maximum compatibility during initial setup when zsh may not be installed. Consider creating `lib/_logging_bash.sh` for bash-only scripts.

**Files:**
```
lib/
├── _logging.sh       # ZSH-compatible (exists)
└── _logging_bash.sh  # Bash-compatible (to create)
```

---

#### 2. Error Scenario Test Coverage

**Status:** Not started

**What:** Current tests cover happy paths well but lack error scenario coverage.

**Missing test scenarios:**
- [ ] Permission denied errors during restore
- [ ] Network failures during Bitwarden sync
- [ ] Corrupted vault items (invalid JSON)
- [ ] Session expiration mid-operation
- [ ] Missing required files during backup
- [ ] Disk full scenarios
- [ ] Concurrent execution safety

**Implementation:**
```bash
# Example: test/error_scenarios.bats
@test "restore: handles permission denied gracefully" {
    chmod 000 "$TEST_HOME/.ssh"
    run restore_ssh
    [ "$status" -ne 0 ]
    [[ "$output" =~ "permission denied" ]]
}
```

---

### Priority: MEDIUM

#### 3. Bootstrap Script Consolidation

**Status:** Not started

**What:** `bootstrap-mac.sh` and `bootstrap-linux.sh` share ~60% identical code.

**Duplicated code:**
- Argument parsing (`--help`, `--interactive`, `--minimal`)
- `prompt_yes_no()` function
- Help text formatting
- Homebrew bundle installation
- Post-install messages

**Proposed structure:**
```
bootstrap/
├── _common.sh      # Shared functions (argument parsing, prompts)
├── macos.sh        # macOS-specific (Xcode tools, paths)
├── linux.sh        # Linux-specific (apt, linuxbrew paths)
└── docker.sh       # Docker-specific (non-interactive)
```

**Current structure (keep working):**
```
bootstrap-mac.sh    # Calls bootstrap/_common.sh + macos-specific
bootstrap-linux.sh  # Calls bootstrap/_common.sh + linux-specific
```

---

#### 4. Auto-Backup Before Restore

**Status:** Not started

**What:** Vault restore operations overwrite local files without automatic backup.

**Risk:** User loses local changes if they forgot to sync first.

**Proposed solution:**
```bash
# In restore-*.sh scripts, before overwriting:
backup_before_restore() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.bak-$(date +%Y%m%d-%H%M%S)"
        cp "$file" "$backup"
        info "Backed up $file to $backup"
    fi
}
```

**Configuration:**
```bash
# Environment variable to control behavior
DOTFILES_BACKUP_BEFORE_RESTORE=1  # Default: enabled
```

---

#### 5. Offline Mode Support

**Status:** Not started

**What:** Document and support running without Bitwarden access.

**Use cases:**
- Air-gapped environments
- Bitwarden service outages
- Development without vault access

**Proposed implementation:**
```bash
# New environment variable
DOTFILES_OFFLINE=1

# In vault scripts:
if [[ "${DOTFILES_OFFLINE:-0}" == "1" ]]; then
    warn "Running in offline mode - vault operations skipped"
    return 0
fi
```

---

### Priority: LOW (Nice-to-have)

#### 6. CLI Script Reorganization

**Status:** Not started (optional)

**What:** Move CLI scripts to `bin/` directory for cleaner root.

**Current:**
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

**Proposed:**
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

**Impact:** Would require updating:
- `zsh/zsh.d/40-aliases.zsh` (dotfiles command)
- Documentation paths
- CI/CD workflow paths

**Decision:** Keep current structure unless actively refactoring. Works fine as-is.

---

#### 7. Session Management Improvements

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
| 1.3.0 | (Planned) Shared library consolidation, error tests |

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
