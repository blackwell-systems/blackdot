# Go CLI Migration - Complete

> **Status:** Phase 3 Complete - Go Binary is Primary CLI
> **Last Updated:** 2025-12-09

---

## Summary

The Go CLI rewrite is **complete**. All commands are now provided by the Go binary (`bin/dotfiles`). Shell fallback has been removed. The Go binary is the sole CLI implementation.

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

### Migration Complete

```
┌────────────────────────────────────────────────────────────┐
│  Phase 1: Installation Integration        ✅ COMPLETE      │
│  Phase 2: Shell Switchover                ✅ COMPLETE      │
│  Phase 3: Deprecation & Cleanup           ✅ COMPLETE      │
│  Phase 4: Future Enhancements (optional)  ⏳               │
└────────────────────────────────────────────────────────────┘
```

### Phase 3 Changes (2025-12-09)

- Renamed binary from `dotfiles-go` to `dotfiles`
- Removed shell fallback (`DOTFILES_USE_GO` escape hatch)
- Deleted 19 deprecated `bin/dotfiles-*` shell scripts (~7500 lines)
- Deleted 12 deprecated `lib/*.sh` libraries (~5500 lines)
- Simplified `40-aliases.zsh` (~550 lines removed)
- Updated CI workflows for Go-first testing
- Added `dotfiles shell-init` command for shell function initialization
- Updated `00-init.zsh` to use Go binary for feature checks
- Total reduction: ~13,500 lines of shell code

---

## What MUST Stay in Shell (Cannot Be Go)

**This is fundamental.** Some things can NEVER move to Go because they require modifying the current shell process. A Go binary runs as a subprocess and cannot change the parent shell's state.

### Forever Shell (ZSH/PowerShell)

| Category | Examples | Why It Can't Be Go |
|----------|----------|-------------------|
| **Environment Variables** | `export PATH=...`, `export AWS_PROFILE=...` | Go subprocess can't modify parent's env |
| **Current Directory** | `cd`, `pushd`, `popd` | Go can't change parent's working directory |
| **Shell Aliases** | `alias ll='ls -la'` | Aliases are shell constructs |
| **Shell Functions** | `mkcd() { mkdir -p "$1" && cd "$1"; }` | Functions that use `cd` or `export` |
| **Prompt/Theme** | Starship, Powerlevel10k, oh-my-posh | Must run in shell context |
| **Completions** | Tab completion handlers | Run in shell context |
| **Shell Hooks** | `chpwd`, `precmd`, `$PROMPT_COMMAND` | Shell-native events |
| **Sourcing Files** | `source ~/.zshrc` | Shell operation |

### What This Means in Practice

**Commands that PRINT but can't APPLY:**
```bash
# Go binary can PRINT what to do...
$ dotfiles tools aws switch prod
export AWS_PROFILE=prod
export AWS_REGION=us-east-1

# ...but user must EVAL to apply it:
$ eval "$(dotfiles tools aws switch prod)"
```

**Shell wrapper pattern:**
```zsh
# ZSH wrapper that applies Go output
aws-switch() {
    eval "$(dotfiles tools aws switch "$@")"
}
```

```powershell
# PowerShell wrapper that applies Go output
function aws-switch {
    $output = dotfiles tools aws switch @args
    Invoke-Expression $output
}
```

### Files That Stay Forever

```
zsh/zsh.d/
├── 00-init.zsh          # PATH, DOTFILES_DIR, instant prompt
├── 10-plugins.zsh       # Zinit plugin loading
├── 20-env.zsh           # Environment variables
├── 30-tools.zsh         # Tool init (fzf, zoxide, starship)
├── 40-aliases.zsh       # Aliases + dotfiles wrapper
├── 50-functions.zsh     # Shell functions (mkcd, etc.)
├── 60-aws.zsh           # AWS env management (export)
├── 61-cdk.zsh           # CDK env management (export)
├── ...
└── p10k.zsh             # Prompt theme

powershell/
├── Dotfiles.psm1        # Module with wrappers
└── profile.ps1          # $PROFILE configuration
```

### What CAN Be Go (The CLI)

Everything that:
- Reads/writes files
- Calls external APIs
- Processes data
- Displays output
- Doesn't need to modify parent shell state

```
Go Binary Handles:
├── dotfiles features    # Read/write config.json
├── dotfiles vault       # API calls to vault backends
├── dotfiles doctor      # System checks, display results
├── dotfiles template    # File processing
├── dotfiles tools *     # Cross-platform utilities
└── ... all other commands
```

### The Bridge: Shell Wrappers Call Go

```
┌─────────────────────────────────────────────────────────────┐
│  User types: aws-switch prod                                │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Shell function (ZSH/PowerShell)                            │
│  aws-switch() { eval "$(dotfiles tools aws switch "$@")"; } │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Go binary outputs:                                         │
│  export AWS_PROFILE=prod                                    │
│  export AWS_REGION=us-east-1                                │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  eval applies it to current shell                           │
│  ✓ AWS_PROFILE is now "prod" in this shell                  │
└─────────────────────────────────────────────────────────────┘
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

### 1.2 Onboarding Experience by Platform

**Goal:** One command to get started, appropriate setup for each platform.

| Platform | Current | Ideal |
|----------|---------|-------|
| **macOS** | `curl \| bash` → zsh + Go binary | ✅ Works well |
| **Linux** | `curl \| bash` → zsh + Go binary | ✅ Works well |
| **WSL2** | `curl \| bash` → zsh + Go binary | ✅ Works well |
| **Windows (PowerShell)** | `irm \| iex` → clone + Go binary + module | ✅ Done |
| **Windows (Git Bash)** | `curl \| bash` → bash + PS prompt | ✅ Done |

### 1.3 Windows PowerShell Installer ✅

One-liner for native Windows users:

```powershell
# One command in PowerShell
irm https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/Install.ps1 | iex

# With options
.\Install.ps1 -Preset developer -SkipPackages
```

**Features:**
- [x] Clone repo to `$HOME\workspace\dotfiles`
- [x] Download Go binary for Windows (amd64)
- [x] Run `Install-Dotfiles.ps1` (PowerShell module)
- [x] Optional `Install-Packages.ps1` (winget packages)
- [x] Preset support: `-Preset minimal|developer|claude|full`

**Remaining:**
- [x] Add to install.sh: detect Windows + prompt for PowerShell setup
- [ ] Update docs with platform-specific quick start

### 1.4 Other Remaining Tasks

- [x] Add checksum verification for downloaded binaries
- [ ] Make `--binary` the default (currently opt-in)

---

## Phase 2: Shell Switchover ✅

**Goal:** Make shell call Go binary instead of shell scripts

### 2.1 Update 40-aliases.zsh ✅

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
- [x] Rename current `dotfiles()` function to `_dotfiles_shell()`
- [x] Add new `dotfiles()` that calls Go binary
- [x] Add `DOTFILES_USE_GO=0` escape hatch for shell fallback
- [x] Test all commands through the new wrapper

### 2.2 Feature Flag for Gradual Rollout ✅

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
- [x] Audit all `feature_enabled` calls in zsh.d/*.zsh
- [x] Implement `dotfiles shell-init zsh` command
- [x] Update shell modules to use Go binary (via shell-init)

### 2.4 Tool Group Aliases ✅

Expose `dotfiles tools X` as convenient `Xtools` commands:

**ZSH (functions in 40-aliases.zsh):**
```zsh
# Tool group aliases - delegate to Go binary
sshtools()    { "$DOTFILES_DIR/bin/dotfiles-go" tools ssh "$@"; }
awstools()    { "$DOTFILES_DIR/bin/dotfiles-go" tools aws "$@"; }
cdktools()    { "$DOTFILES_DIR/bin/dotfiles-go" tools cdk "$@"; }
gotools()     { "$DOTFILES_DIR/bin/dotfiles-go" tools go "$@"; }
rusttools()   { "$DOTFILES_DIR/bin/dotfiles-go" tools rust "$@"; }
pytools()     { "$DOTFILES_DIR/bin/dotfiles-go" tools python "$@"; }
dockertools() { "$DOTFILES_DIR/bin/dotfiles-go" tools docker "$@"; }
```

**PowerShell (functions in Dotfiles.psm1):**
```powershell
function sshtools    { dotfiles tools ssh @args }
function awstools    { dotfiles tools aws @args }
function cdktools    { dotfiles tools cdk @args }
function gotools     { dotfiles tools go @args }
function rusttools   { dotfiles tools rust @args }
function pytools     { dotfiles tools python @args }
function dockertools { dotfiles tools docker @args }
```

**Usage (identical on both platforms):**
```bash
cdktools              # Shows CDK help
cdktools status       # Shows CDK status banner
cdktools init         # Initialize CDK project

awstools              # Shows AWS help
awstools profiles     # List AWS profiles
awstools login dev    # SSO login

sshtools              # Shows SSH help
sshtools keys         # List SSH keys
sshtools gen mykey    # Generate key
```

**Benefits:**
- Short, memorable commands (`cdktools` vs `dotfiles tools cdk`)
- Consistent across ZSH and PowerShell
- Both call same Go binary = identical behavior
- Works alongside individual aliases (`ssh-keys`, `aws-profiles`, etc.)

**Tasks:**
- [x] Add tool group functions to `zsh/zsh.d/40-aliases.zsh` ✅
- [x] Add tool group functions to `powershell/Dotfiles.psm1` ✅
- [x] Update individual aliases (`ssh-keys`, etc.) to call Go binary ✅

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

## Migration Assessment

### Why This Migration Was Worthwhile

| Aspect | Before (Shell) | After (Go) |
|--------|---------------|------------|
| **Lines of code** | ~20,000+ shell | ~6,500 Go + ~6,500 shell |
| **Cross-platform** | Linux/macOS only, bash/zsh quirks | Linux/macOS/Windows native |
| **Type safety** | Runtime errors, cryptic failures | Compile-time checks |
| **Testing** | Bats (awkward) | Go testing (112+ tests, 89% coverage on feature module) |
| **Error handling** | Inconsistent, often silent | Explicit, structured |
| **Duplication** | Logic split across shell scripts | Single source of truth |

### The Shell-Init Bridge

The `shell-init` command elegantly solves a fundamental constraint: Go cannot modify the parent shell's environment. Instead of fighting this, we:

1. **Keep env management in shell** (where it must be)
2. **Delegate logic to Go** (where it's testable)
3. **Bridge with eval**: `eval "$(dotfiles shell-init zsh)"`

This provides `feature_enabled`, `require_feature`, `feature_exists`, and `feature_status` as shell functions that call the Go binary for actual feature state.

### Performance Consideration

Each `require_feature` call spawns a subprocess (the Go binary). In practice this is negligible:

- Go binaries start in ~5ms
- Feature checks only happen when commands run, not at shell startup
- Much faster than sourcing a 660-line `lib/_features.sh` on every check

### Bottom Line

The project went from "works on my Mac with zsh" to "works everywhere with tests." The migration reduced complexity while adding cross-platform support and proper testing infrastructure.

---

*For historical implementation details, see git history or archived documentation.*
