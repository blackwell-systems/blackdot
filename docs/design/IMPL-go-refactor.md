# Go CLI Migration - Remaining Work

> **Status:** Phase 9 Complete - Ready for Cutover
> **Last Updated:** 2025-12-09

---

## Summary

The Go CLI rewrite is **essentially complete**. All 19+ commands have been ported with full parity to the shell implementation. This document tracks the remaining steps to complete the migration.

### What's Done

| Phase | Status | Description |
|-------|--------|-------------|
| Foundation | ✅ | Go project structure, Cobra CLI framework |
| Color System | ✅ | Exact parity with `lib/_colors.sh` |
| Feature Registry | ✅ | 25 features, 4 presets, env overrides |
| Config System | ✅ | Layered config, cross-compatible JSON |
| Vault Integration | ✅ | vaultmux v0.3.3, all 3 backends |
| Template Engine | ✅ | Raymond-based, full Handlebars syntax |
| All Commands | ✅ | features, vault, template, doctor, lint, hook, encrypt, diff, drift, sync, backup, metrics, status, packages, uninstall, tools, rollback |
| Developer Tools | ✅ | 50+ cross-platform tools (SSH, AWS, CDK, Go, Rust, Python, Docker) |
| Chezmoi Import | ✅ | Migration tool for chezmoi users |
| GitHub Actions | ✅ | Multi-platform builds (darwin/linux, amd64/arm64) |
| Unit Tests | ✅ | 112+ tests, feature: 89%, config: 74% |

### What's Remaining

```
┌────────────────────────────────────────────────────────────┐
│  Phase 1: Installation Integration        ✅ (mostly done) │
│  Phase 2: Shell Switchover                ⏳ (next)        │
│  Phase 3: Deprecation & Cleanup           ⏳               │
│  Phase 4: Future Enhancements (optional)  ⏳               │
└────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Installation Integration ✅ COMPLETE

**Goal:** Make Go binary the default for new installs

### 1.1 Bootstrap Script ✅

`install.sh` already supports binary download:

```bash
# Install with Go binary (recommended)
curl -fsSL <url> | bash -s -- --binary

# Binary-only mode (just the CLI, no repo)
curl -fsSL <url> | bash -s -- --binary-only

# Specific version
DOTFILES_VERSION=v3.1.0 ./install.sh --binary
```

**Features implemented:**
- [x] Platform detection (darwin/linux/windows, amd64/arm64)
- [x] Downloads from GitHub releases
- [x] Installs to `~/.local/bin/dotfiles-go`
- [x] Fallback to shell if binary download fails

### 1.2 Remaining Tasks

- [ ] Add checksum verification for downloaded binaries
- [ ] Make `--binary` the default (currently opt-in)
- [ ] Update Makefile `install` target to build Go binary
- [ ] **Windows/PowerShell gap:** `install.sh` doesn't auto-setup PowerShell
  - Currently Windows users must manually run `powershell/Install-Dotfiles.ps1`
  - Consider: PowerShell-native installer or prompt after bash bootstrap

---

## Phase 2: Shell Switchover

**Goal:** Make shell call Go binary instead of shell scripts

### 2.1 Update 40-aliases.zsh

**Current state:** The `dotfiles` function is a large dispatcher calling shell scripts

**Target state:** Thin wrapper calling Go binary

```zsh
# Before: 750-line dispatcher
dotfiles() {
    case "$1" in
        vault) ... 100 lines ... ;;
        features) ... 80 lines ... ;;
        # etc
    esac
}

# After: 10-line wrapper
dotfiles() {
    if [[ -x "$DOTFILES_DIR/bin/dotfiles" ]]; then
        "$DOTFILES_DIR/bin/dotfiles" "$@"
    else
        # Fallback to shell (temporary)
        _dotfiles_shell "$@"
    fi
}
```

**Tasks:**
- [ ] Rename current `dotfiles()` function to `_dotfiles_shell()`
- [ ] Add new `dotfiles()` that calls Go binary
- [ ] Add `DOTFILES_USE_GO=0` escape hatch for shell fallback
- [ ] Test all commands through the new wrapper

### 2.2 Feature Flag for Gradual Rollout

```zsh
# Allow users to opt-out if issues arise
if [[ "${DOTFILES_USE_GO:-1}" == "0" ]]; then
    # Use shell implementation
    alias dotfiles=_dotfiles_shell
fi
```

### 2.3 Shell Functions That Need Go

Some shell modules query feature state. Update to call Go:

```zsh
# 60-aws.zsh - Update to use Go
if dotfiles features check aws_helpers 2>/dev/null; then
    # load aws stuff
fi
```

Or use the shell-init helper:

```zsh
# In 00-init.zsh
eval "$(dotfiles shell-init zsh)"
```

**Tasks:**
- [ ] Audit all `feature_enabled` calls in zsh.d/*.zsh
- [ ] Implement `dotfiles shell-init zsh` command
- [ ] Update shell modules to use Go binary

---

## Phase 3: Deprecation & Cleanup

**Goal:** Remove shell implementation after Go is proven stable

### 3.1 Deprecation Timeline

| Week | Action |
|------|--------|
| 0 | Deploy Go binary as default |
| 1-2 | Monitor for issues, keep shell fallback |
| 3-4 | Remove shell fallback from 40-aliases.zsh |
| 5+ | Archive/delete bin/dotfiles-* shell scripts |

### 3.2 Files to Archive/Delete

```
# Shell scripts to remove after Go is stable
bin/dotfiles-backup
bin/dotfiles-config
bin/dotfiles-diff
bin/dotfiles-doctor
bin/dotfiles-drift
bin/dotfiles-encrypt
bin/dotfiles-features
bin/dotfiles-hook
bin/dotfiles-lint
bin/dotfiles-metrics
bin/dotfiles-migrate
bin/dotfiles-packages
bin/dotfiles-setup     # Keep - interactive wizard better in shell
bin/dotfiles-status
bin/dotfiles-sync
bin/dotfiles-template
bin/dotfiles-uninstall
bin/dotfiles-vault

# Libraries to archive
lib/_features.sh
lib/_config.sh
lib/_vault.sh
lib/_templates.sh
lib/_state.sh
```

### 3.3 Template Syntax Cleanup (Phase 8D)

**Optional:** Deprecate old template syntax

The bash template engine currently supports both:
- New: `{{#if (eq os "darwin")}}` (Handlebars)
- Old: `{{?OS_TYPE="darwin"}}` (legacy)

**Tasks:**
- [ ] Run `dotfiles template lint` to find old syntax usage
- [ ] Migrate remaining templates to Handlebars syntax
- [ ] Consider removing old syntax support from Go engine

---

## Phase 4: Future Enhancements (Optional)

These are "nice to have" improvements after the migration is complete:

### 4.1 Community Features

- [ ] Community preset marketplace
- [ ] VS Code / IDE extensions
- [ ] Team sync features

### 4.2 Additional Backends

- [ ] HashiCorp Vault backend for vaultmux
- [ ] AWS Secrets Manager backend
- [ ] Azure Key Vault backend

### 4.3 Advanced Features

- [ ] GUI companion app
- [ ] Cloud sync (optional)
- [ ] Dotfile analytics/insights

---

## Testing Checklist

Before each phase, verify:

```bash
# Build Go binary
make build

# Run Go tests
go test ./...

# Compare Go vs Shell output
diff <(dotfiles features list) <(./bin/dotfiles features list)
diff <(dotfiles doctor) <(./bin/dotfiles doctor)
diff <(dotfiles vault status) <(./bin/dotfiles vault status)

# Verify on fresh shell
exec zsh
dotfiles version  # Should show Go version
```

---

## Rollback Plan

If issues arise after switchover:

```bash
# Immediate: Set env var to use shell
export DOTFILES_USE_GO=0
exec zsh

# Or: Remove Go binary to force shell fallback
rm $DOTFILES_DIR/bin/dotfiles
exec zsh
```

Shell implementation remains intact until Phase 3 cleanup.

---

## Quick Reference

### Current Binary Location

```
$DOTFILES_DIR/bin/dotfiles     # Go binary (19 commands)
$DOTFILES_DIR/bin/dotfiles-*   # Shell scripts (deprecated)
```

### Release Workflow

GitHub Actions (`.github/workflows/release.yml`) automatically builds:
- `dotfiles-darwin-amd64`
- `dotfiles-darwin-arm64`
- `dotfiles-linux-amd64`
- `dotfiles-linux-arm64`
- `dotfiles-windows-amd64.exe`

Releases triggered by pushing a `v*` tag.

### Test Coverage

```bash
# Run with coverage
go test -cover ./...

# Current coverage (2025-12-09):
# - internal/feature: 89.1%
# - internal/config: 74.1%
# - internal/cli: 7.9%
```

---

*For historical implementation details, see git history or archived documentation.*
