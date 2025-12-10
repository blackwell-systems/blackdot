# Rebranding Strategy: dotfiles → blackdot

> Analysis Date: 2025-12-10
> Target: Rename framework from "dotfiles" to "blackdot"

---

## Executive Summary

| Metric | Value |
|--------|-------|
| Total files affected | 500+ |
| GitHub URL references | 129 |
| Environment variable refs | 67 files |
| CLI command references | 400+ |
| Estimated effort | 35-40 hours |
| Breaking changes | Yes (manageable) |
| Recommended approach | Phased migration |

**Verdict:** Moderately complex but straightforward. Mostly find-and-replace with some structural changes. The main challenge is user migration, not code changes.

---

## Table of Contents

1. [File & Directory Changes](#1-file--directory-changes)
2. [Go Package Changes](#2-go-package-changes)
3. [Environment Variables](#3-environment-variables)
4. [Configuration Paths](#4-configuration-paths)
5. [CLI Command References](#5-cli-command-references)
6. [Shell Integration](#6-shell-integration)
7. [PowerShell Module](#7-powershell-module)
8. [GitHub URLs](#8-github-urls)
9. [CI/CD Workflows](#9-cicd-workflows)
10. [Documentation](#10-documentation)
11. [Migration Strategy](#11-migration-strategy)
12. [Breaking Changes](#12-breaking-changes)
13. [Implementation Plan](#13-implementation-plan)

---

## 1. File & Directory Changes

### Files to Rename (12 files)

| Current | New | Impact |
|---------|-----|--------|
| `cmd/dotfiles/` | `cmd/blackdot/` | Go package directory |
| `bin/dotfiles` | `bin/blackdot` | CLI binary |
| `bootstrap/bootstrap-dotfiles.sh` | `bootstrap/bootstrap-blackdot.sh` | Setup script |
| `zsh/completions/_dotfiles` | `zsh/completions/_blackdot` | Zsh completion |
| `zsh/completions/_dotfiles-doctor` | `zsh/completions/_blackdot-doctor` | Zsh completion |
| `powershell/Dotfiles.psm1` | `powershell/Blackdot.psm1` | PS module |
| `powershell/Dotfiles.psd1` | `powershell/Blackdot.psd1` | PS manifest |
| `powershell/Install-Dotfiles.ps1` | `powershell/Install-Blackdot.ps1` | PS installer |

### Test Fixtures (5 files)

```
test/fixtures/vault-items/dotfiles-*.json → blackdot-*.json
```

### Complexity: LOW
Simple file renames with `git mv`.

---

## 2. Go Package Changes

### Module Declaration

**`go.mod` (Line 1):**
```go
// OLD
module github.com/blackwell-systems/dotfiles

// NEW
module github.com/blackwell-systems/blackdot
```

### Import Statements (40+ files)

All files in:
- `cmd/dotfiles/main.go`
- `internal/cli/*.go` (37 files)
- `internal/config/*.go`
- `internal/feature/*.go`
- `internal/template/*.go`
- `internal/shell/*.go`

**Pattern:**
```go
// OLD
import "github.com/blackwell-systems/dotfiles/internal/cli"

// NEW
import "github.com/blackwell-systems/blackdot/internal/cli"
```

### Struct Field Names

**`internal/config/config.go`:**
```go
// OLD
type Manager struct {
    configDir   string
    dotfilesDir string  // → blackdotDir
}

// OLD
ProjectConfigFile = ".dotfiles.json"  // → ".blackdot.json"
```

**`internal/cli/root.go`:**
```go
// OLD
Use:   "dotfiles",
Short: "Manage your dotfiles",

// NEW
Use:   "blackdot",
Short: "Manage your configuration",
```

### Complexity: LOW
Automated find-and-replace, then `go build` to verify.

---

## 3. Environment Variables

### Variables to Rename

| Current | New | Files | Breaking |
|---------|-----|-------|----------|
| `DOTFILES_DIR` | `BLACKDOT_DIR` | 67 | YES |
| `DOTFILES_VERSION` | `BLACKDOT_VERSION` | 2 | YES |
| `DOTFILES_SKIP_CHECKSUM` | `BLACKDOT_SKIP_CHECKSUM` | 1 | YES |
| `DOTFILES_USE_GO` | (removed in v4) | - | N/A |
| `DOTFILES_FEATURE_MODE` | `BLACKDOT_FEATURE_MODE` | 3 | YES |
| `DOTFILES_VAULT_BACKEND` | `BLACKDOT_VAULT_BACKEND` | 5 | YES |

### Migration Strategy

**Recommended: Support both during transition**

```go
// In config.go
func getDotfilesDir() string {
    // Check new name first
    if dir := os.Getenv("BLACKDOT_DIR"); dir != "" {
        return dir
    }
    // Fall back to old name (deprecated)
    if dir := os.Getenv("DOTFILES_DIR"); dir != "" {
        fmt.Fprintln(os.Stderr, "Warning: DOTFILES_DIR is deprecated, use BLACKDOT_DIR")
        return dir
    }
    return defaultDir()
}
```

### Key Files

- `internal/cli/root.go` (Lines 126-153)
- `internal/cli/shell_init.go` (Lines 59-65)
- `bootstrap/_common.sh` (Lines 18-44)
- `zsh/zsh.d/40-aliases.zsh` (60+ refs)
- `install.sh` (Lines 55-56)

### Complexity: MEDIUM
Need backwards compatibility layer for existing users.

---

## 4. Configuration Paths

### Paths to Change

| Current | New | Purpose |
|---------|-----|---------|
| `~/.config/dotfiles/` | `~/.config/blackdot/` | Config directory |
| `~/.dotfiles` | `~/.blackdot` | Default install location |
| `~/.dotfiles-backups/` | `~/.blackdot-backups/` | Backup storage |
| `~/.dotfiles-metrics.jsonl` | `~/.blackdot-metrics.jsonl` | Usage metrics |
| `.dotfiles.json` | `.blackdot.json` | Project config file |

### Code Locations

**`internal/config/config.go`:**
```go
// Line 30
ProjectConfigFile = ".dotfiles.json"  // → ".blackdot.json"

// Line 90
configDir = filepath.Join(configDir, "dotfiles")  // → "blackdot"
```

**`internal/cli/root.go`:**
```go
// Line 146-153 (ConfigDir function)
filepath.Join(home, ".config", "dotfiles")  // → "blackdot"
```

### Migration Script Needed

```bash
# Auto-migrate on first run of new version
if [[ -d ~/.config/dotfiles && ! -d ~/.config/blackdot ]]; then
    mv ~/.config/dotfiles ~/.config/blackdot
    echo "Migrated config to ~/.config/blackdot"
fi
```

### Complexity: MEDIUM
Requires migration logic for existing users.

---

## 5. CLI Command References

### Total: 400+ occurrences

### Command Name Change

```bash
# OLD
dotfiles setup
dotfiles sync
dotfiles vault pull
dotfiles features enable vault

# NEW
blackdot setup
blackdot sync
blackdot vault pull
blackdot features enable vault
```

### Key Files

| File | References | Type |
|------|------------|------|
| `zsh/zsh.d/40-aliases.zsh` | 140+ | Shell functions |
| `internal/cli/*.go` | 50+ | Help text, examples |
| `docs/*.md` | 200+ | Documentation |
| `test/*.bats` | 50+ | Test assertions |
| `bootstrap/*.sh` | 20+ | Output messages |

### Shell Alias

```zsh
# OLD (40-aliases.zsh)
alias d='dotfiles'

# NEW
alias d='blackdot'
# Optional: alias dotfiles='blackdot'  # backwards compat
```

### Complexity: LOW
Mostly find-and-replace. High volume but simple.

---

## 6. Shell Integration

### Zsh Files to Update

**`zsh/zsh.d/00-init.zsh`:**
```zsh
# References to DOTFILES_DIR, binary path
_dotfiles_bin="$_dotfiles_dir/bin/dotfiles"  # → blackdot
```

**`zsh/zsh.d/40-aliases.zsh`:**
```zsh
# Main function
dotfiles() { ... }  # → blackdot()

# Helper functions
_dotfiles_go_bin()  # → _blackdot_go_bin()
_dotfiles_help()    # → _blackdot_help()
```

**`zsh/completions/_dotfiles`:**
- Rename file to `_blackdot`
- Update internal references

### Fish/Bash Support

**`internal/cli/shell_init.go`:**
- Update generated shell code
- Change binary path references
- Update function names in output

### Complexity: MEDIUM
Function renames + completion updates.

---

## 7. PowerShell Module

### Files to Rename

| Current | New |
|---------|-----|
| `Dotfiles.psm1` | `Blackdot.psm1` |
| `Dotfiles.psd1` | `Blackdot.psd1` |
| `Install-Dotfiles.ps1` | `Install-Blackdot.ps1` |

### Functions to Rename

```powershell
# In Dotfiles.psm1
Install-DotfilesBinary    → Install-BlackdotBinary
Install-DotfilesModule    → Install-BlackdotModule
Install-DotfilesPackages  → Install-BlackdotPackages
```

### Module Manifest (`Dotfiles.psd1`)

```powershell
# Line 5
RootModule = 'Dotfiles.psm1'  # → 'Blackdot.psm1'

# Line 118-121: GitHub URLs
```

### Complexity: MEDIUM
File renames + internal function renames.

---

## 8. GitHub URLs

### Total: 129 references across 40+ files

### URL Pattern Change

```
OLD: https://github.com/blackwell-systems/dotfiles
NEW: https://github.com/blackwell-systems/blackdot
```

### Critical Files

| File | Count | Impact |
|------|-------|--------|
| `README.md` | 8 | User-facing |
| `install.sh` | 4 | Installation |
| `go.mod` | 1 | Module |
| `.github/workflows/*.yml` | 15 | CI/CD |
| `docs/*.md` | 50+ | Documentation |

### Badge Updates (README)

```markdown
<!-- OLD -->
[![Test](https://github.com/blackwell-systems/dotfiles/workflows/Test/badge.svg)]
[![Version](https://img.shields.io/github/v/release/blackwell-systems/dotfiles)]

<!-- NEW -->
[![Test](https://github.com/blackwell-systems/blackdot/workflows/Test/badge.svg)]
[![Version](https://img.shields.io/github/v/release/blackwell-systems/blackdot)]
```

### Complexity: LOW
Straightforward find-and-replace.

---

## 9. CI/CD Workflows

### Files

- `.github/workflows/ci.yml`
- `.github/workflows/release.yml`
- `.github/workflows/test.yml`

### Changes Needed

**Build Commands:**
```yaml
# OLD
run: go build -o dotfiles ./cmd/dotfiles/

# NEW
run: go build -o blackdot ./cmd/blackdot/
```

**Binary Naming:**
```yaml
# OLD
BINARY_NAME: "dotfiles-${{ matrix.goos }}-${{ matrix.goarch }}"

# NEW
BINARY_NAME: "blackdot-${{ matrix.goos }}-${{ matrix.goarch }}"
```

**Release Artifacts:**
```yaml
# OLD
path: bin/dotfiles*

# NEW
path: bin/blackdot*
```

### Complexity: LOW
Path and name updates.

---

## 10. Documentation

### Files (80+)

All markdown files in:
- `docs/`
- `docs/design/`
- Root (`README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`)
- `.github/ISSUE_TEMPLATE/`

### Changes Per File

| Type | Example | Count |
|------|---------|-------|
| Command examples | `dotfiles setup` → `blackdot setup` | 200+ |
| GitHub URLs | Repository links | 50+ |
| Path references | `~/.config/dotfiles` | 30+ |
| Env var refs | `DOTFILES_DIR` | 20+ |

### CHANGELOG Special Case

Historical entries should remain as-is (they describe what happened at that time). Only add note at top:

```markdown
> Note: This project was renamed from "dotfiles" to "blackdot" in v5.0.0.
> Historical entries below reference the old name.
```

### Complexity: LOW
High volume but simple replacement.

---

## 11. Migration Strategy

### Recommended: Phased Approach

#### Phase 1: Dual Support (v4.1.0)

- Add `BLACKDOT_DIR` (prefer over `DOTFILES_DIR`)
- Add `blackdot` command (symlink or alias)
- Support both `~/.config/dotfiles` and `~/.config/blackdot`
- Show deprecation warnings

```go
// Example deprecation warning
if os.Getenv("DOTFILES_DIR") != "" {
    fmt.Fprintln(os.Stderr, "DEPRECATED: DOTFILES_DIR will be removed in v5.0. Use BLACKDOT_DIR")
}
```

#### Phase 2: Primary Rebrand (v5.0.0)

- `blackdot` is the primary command
- `dotfiles` becomes alias (backwards compat)
- Auto-migrate config paths on first run
- Update all documentation

#### Phase 3: Full Removal (v6.0.0)

- Remove `DOTFILES_*` env var support
- Remove `dotfiles` command alias
- Remove old path support

### User Migration Script

```bash
#!/bin/bash
# blackdot-migrate.sh

echo "Migrating from dotfiles to blackdot..."

# Config directory
if [[ -d ~/.config/dotfiles ]]; then
    mv ~/.config/dotfiles ~/.config/blackdot
    echo "  ✓ Moved ~/.config/dotfiles → ~/.config/blackdot"
fi

# Backups
if [[ -d ~/.dotfiles-backups ]]; then
    mv ~/.dotfiles-backups ~/.blackdot-backups
    echo "  ✓ Moved ~/.dotfiles-backups → ~/.blackdot-backups"
fi

# Metrics
if [[ -f ~/.dotfiles-metrics.jsonl ]]; then
    mv ~/.dotfiles-metrics.jsonl ~/.blackdot-metrics.jsonl
    echo "  ✓ Moved metrics file"
fi

# Update shell config
if grep -q "DOTFILES_DIR" ~/.zshrc 2>/dev/null; then
    echo "  ! Update DOTFILES_DIR → BLACKDOT_DIR in ~/.zshrc"
fi

if grep -q "dotfiles shell-init" ~/.zshrc 2>/dev/null; then
    echo "  ! Update 'dotfiles shell-init' → 'blackdot shell-init' in ~/.zshrc"
fi

echo "Migration complete!"
```

---

## 12. Breaking Changes

### High Impact

| Change | Impact | Mitigation |
|--------|--------|------------|
| Command name `dotfiles` → `blackdot` | All scripts using `dotfiles` break | Alias during transition |
| `DOTFILES_DIR` → `BLACKDOT_DIR` | CI/CD, custom scripts break | Support both for 2 releases |
| Config path change | User settings location moves | Auto-migrate |
| GitHub URL change | Existing clones point to old repo | Document re-clone process |

### Medium Impact

| Change | Impact | Mitigation |
|--------|--------|------------|
| PowerShell module name | Windows users need to re-import | Document in release notes |
| Shell completions | Tab completion breaks until updated | Auto-update in shell-init |
| `.dotfiles.json` → `.blackdot.json` | Project configs need renaming | Auto-detect both |

### Low Impact

| Change | Impact | Mitigation |
|--------|--------|------------|
| Binary name | CI/CD download paths change | Version-specific docs |
| Documentation | Old tutorials become outdated | Redirect / update |

---

## 13. Implementation Plan

### Week 1: Preparation

- [ ] Create `blackwell-systems/blackdot` repository
- [ ] Set up branch protection, CI/CD
- [ ] Draft user communication / blog post
- [ ] Create migration script

### Week 2: Core Changes

- [ ] Rename Go module in `go.mod`
- [ ] Update all Go imports (40+ files)
- [ ] Rename `cmd/dotfiles/` → `cmd/blackdot/`
- [ ] Update struct fields and variable names
- [ ] Add env var compatibility layer

### Week 3: Integration Changes

- [ ] Rename shell files and update contents
- [ ] Rename PowerShell module files
- [ ] Update `install.sh`
- [ ] Update CI/CD workflows
- [ ] Update all GitHub URLs

### Week 4: Documentation & Testing

- [ ] Update all documentation
- [ ] Update README badges
- [ ] Cross-platform testing (macOS, Linux, Windows)
- [ ] Test fresh install
- [ ] Test migration from existing install

### Week 5: Release

- [ ] Release v4.1.0-rc.1 (dual support)
- [ ] Community testing period
- [ ] Fix issues
- [ ] Release v4.1.0 final

---

## Effort Summary

| Category | Hours | Complexity |
|----------|-------|------------|
| Go module/imports | 2 | Low |
| Environment variables | 4 | Medium |
| Config paths | 3 | Medium |
| CLI references | 5 | Low |
| Shell integration | 4 | Medium |
| PowerShell | 2 | Medium |
| GitHub URLs | 2 | Low |
| Documentation | 3 | Low |
| CI/CD | 2 | Low |
| Testing | 6 | Medium |
| Migration tools | 3 | Medium |
| **Total** | **36** | **Medium** |

---

## Recommendation

**Do it in v5.0.0** after v4.0.0 stabilizes.

The rebrand is straightforward technically but has user impact. Recommend:

1. **Release v4.0.0** as planned (current work)
2. **v4.1.0**: Add deprecation warnings, document upcoming change
3. **v5.0.0**: Full rebrand with migration support
4. **v6.0.0**: Remove backwards compatibility

This gives users ~3-6 months notice and a smooth migration path.

---

## Quick Reference: Search Patterns

```bash
# Find all occurrences
grep -r "dotfiles" --include="*.go" --include="*.sh" --include="*.md" --include="*.ps1" --include="*.yml"

# Specific patterns
grep -r "DOTFILES_" .                    # Environment variables
grep -r "github.com/blackwell-systems/dotfiles" .  # Go imports
grep -r "\.dotfiles" .                   # Config paths
grep -r "bin/dotfiles" .                 # Binary references
```

---

*Last updated: 2025-12-10*
