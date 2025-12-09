# Go CLI Migration - Remaining Work

> **Status:** Phase 2 Complete - Merged to Main (v3.2.0)
> **Last Updated:** 2025-12-09

---

## Summary

The Go CLI rewrite is **complete and merged to main**. All 19+ commands have been ported with full parity to the shell implementation. The Go binary is now the primary CLI with shell fallback available via `DOTFILES_USE_GO=0`.

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
│  Phase 1: Installation Integration        ✅ MERGED        │
│  Phase 2: Shell Switchover                ✅ MERGED (v3.2) │
│  Phase 3: Deprecation & Cleanup           ⏳ (next)        │
│  Phase 4: Future Enhancements (optional)  ⏳               │
└────────────────────────────────────────────────────────────┘
```

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

### 1.3 Binary-Only Installation ✅

For users who don't want shell integration (ZSH or PowerShell modules):

**Unix (macOS/Linux/WSL2):**
```bash
# Just the CLI binary, no repo, no shell config
curl -fsSL <url> | bash -s -- --binary-only

# Result: ~/.local/bin/dotfiles-go
```

**Windows PowerShell:**
```powershell
# Just the CLI binary, no module, no profile changes
.\Install-Dotfiles.ps1 -BinaryOnly

# Result: ~/.local/bin/dotfiles-go.exe
```

**Binary-only user experience:**
- User calls `dotfiles-go` directly (not `dotfiles`)
- Full CLI functionality: features, doctor, vault, tools, etc.
- No shell wrappers, no hook system, no auto-loading
- Can add their own alias if desired: `alias dotfiles=dotfiles-go`

**Use cases:**
- CI/CD pipelines
- Docker containers
- Users preferring minimal shell modifications
- Testing/development

### 1.4 Windows PowerShell Installer ✅

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
- [x] Update docs with platform-specific quick start

### 1.5 Other Remaining Tasks

- [ ] Add checksum verification for downloaded binaries
- [ ] Make `--binary` the default (currently opt-in)
- [ ] Update Makefile `install` target to build Go binary

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
- [ ] Audit all `feature_enabled` calls in zsh.d/*.zsh
- [ ] Implement `dotfiles shell-init zsh` command
- [ ] Update shell modules to use Go binary

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

## Phase 3: Production Release (v1.0 Target)

**Goal:** Clean, production-ready architecture where the Go binary is the primary interface.

### 3.1 Production Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     PRODUCTION TARGET (v1.0)                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ~/.local/bin/                                                       │
│  └── dotfiles              ← Go binary (THE CLI, renamed from        │
│                              dotfiles-go)                            │
│                                                                      │
│  ~/workspace/dotfiles/     ← Optional repo (for shell integration)   │
│  ├── zsh/zsh.d/                                                      │
│  │   ├── 00-init.zsh       PATH, DOTFILES_DIR, instant prompt        │
│  │   ├── 30-tools.zsh      Tool initializers (fzf, zoxide)           │
│  │   └── 40-aliases.zsh    MINIMAL: only env/cd wrappers             │
│  └── powershell/                                                     │
│      └── Dotfiles.psm1     MINIMAL: only env/cd wrappers             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Key changes from current state:**

| Current (Transition) | Production (v1.0) |
|---------------------|-------------------|
| Binary: `dotfiles-go` | Binary: `dotfiles` |
| ZSH function intercepts all commands | Binary called directly |
| Shell fallback exists (`DOTFILES_USE_GO=0`) | No shell fallback |
| `--binary-only` = special mode | Binary-first is default |
| Heavy shell wrappers | Minimal wrappers (env/cd only) |

### 3.2 What Shell Wrappers MUST Remain

These commands require shell wrappers because they modify the parent shell's environment:

```zsh
# ZSH wrappers that CANNOT be pure Go (must eval output)
aws-switch() { eval "$(dotfiles tools aws switch "$@")"; }
cdk-env()    { eval "$(dotfiles tools cdk env "$@")"; }
mkcd()       { mkdir -p "$1" && cd "$1"; }

# Everything else: call binary directly, no wrapper needed
# dotfiles doctor, dotfiles features, dotfiles vault, etc.
```

```powershell
# PowerShell equivalents
function aws-switch { Invoke-Expression (dotfiles tools aws switch @args) }
function cdk-env    { Invoke-Expression (dotfiles tools cdk env @args) }
```

### 3.3 Installation Modes (Production)

**Mode 1: Binary Only (default for CI/Docker/minimal users)**
```bash
# Unix
curl -fsSL <url> | bash -s -- --binary-only
# Result: ~/.local/bin/dotfiles (just works)

# Windows
.\Install-Dotfiles.ps1 -BinaryOnly
# Result: ~/.local/bin/dotfiles.exe (just works)
```

**Mode 2: Full (binary + shell integration)**
```bash
# Unix
curl -fsSL <url> | bash
# Result: Binary + repo + ZSH config + shell wrappers

# Windows
.\Install-Dotfiles.ps1
# Result: Binary + repo + PowerShell module
```

### 3.4 Migration Tasks

**3.4.1 Rename Binary**
- [ ] Change `dotfiles-go` → `dotfiles` in install.sh
- [ ] Change `dotfiles-go` → `dotfiles` in Install-Dotfiles.ps1
- [ ] Update GitHub Actions to produce `dotfiles-{os}-{arch}` (no `-go` suffix)
- [ ] Update Makefile: `make build` outputs `bin/dotfiles`

**3.4.2 Simplify Shell Wrappers**
- [ ] Remove `dotfiles()` function that intercepts all commands
- [ ] Remove `_dotfiles_shell()` fallback function
- [ ] Remove `DOTFILES_USE_GO` environment variable
- [ ] Keep only env/cd wrappers in 40-aliases.zsh
- [ ] Keep only env/cd wrappers in Dotfiles.psm1

**3.4.3 Delete Deprecated Shell Scripts**
```
bin/dotfiles-backup      → DELETE (Go: dotfiles backup)
bin/dotfiles-config      → DELETE (Go: dotfiles config)
bin/dotfiles-diff        → DELETE (Go: dotfiles diff)
bin/dotfiles-doctor      → DELETE (Go: dotfiles doctor)
bin/dotfiles-drift       → DELETE (Go: dotfiles drift)
bin/dotfiles-encrypt     → DELETE (Go: dotfiles encrypt)
bin/dotfiles-features    → DELETE (Go: dotfiles features)
bin/dotfiles-hook        → DELETE (Go: dotfiles hook)
bin/dotfiles-lint        → DELETE (Go: dotfiles lint)
bin/dotfiles-metrics     → DELETE (Go: dotfiles metrics)
bin/dotfiles-migrate     → DELETE (Go: dotfiles migrate)
bin/dotfiles-packages    → DELETE (Go: dotfiles packages)
bin/dotfiles-setup       → KEEP (interactive wizard, shell-native)
bin/dotfiles-status      → DELETE (Go: dotfiles status)
bin/dotfiles-sync        → DELETE (Go: dotfiles sync)
bin/dotfiles-template    → DELETE (Go: dotfiles template)
bin/dotfiles-uninstall   → DELETE (Go: dotfiles uninstall)
bin/dotfiles-vault       → DELETE (Go: dotfiles vault)
```

**3.4.4 Archive Shell Libraries**
```
lib/_features.sh   → Archive (Go handles feature registry)
lib/_config.sh     → Archive (Go handles config)
lib/_vault.sh      → Archive (Go handles vault via vaultmux)
lib/_templates.sh  → Archive (Go handles templates)
lib/_state.sh      → KEEP (setup wizard state, used by bin/dotfiles-setup)
lib/_logging.sh    → KEEP (used by remaining shell scripts)
lib/_hooks.sh      → KEEP (shell hook system)
lib/_colors.sh     → KEEP (used by remaining shell scripts)
```

**3.4.5 Update Documentation**
- [ ] Update README.md with new installation commands
- [ ] Update docs/getting-started.md
- [ ] Remove references to `dotfiles-go` binary name
- [ ] Document that shell integration is optional

### 3.5 Prompt Theming ✅

**Decision: User choice during install** - Both platforms now prompt for theme config.

| Platform | Prompt Theme | Tier | Config |
|----------|--------------|------|--------|
| Unix (ZSH) | Powerlevel10k | Enhanced | `~/.p10k.zsh` (symlinked) |
| Windows (PowerShell) | Starship | Enhanced | `~/.config/starship.toml` |

**Implementation (complete):**
- [x] Added `Starship.Starship` to Windows enhanced tier
- [x] Bundled `starship.toml` config (powerline theme)
- [x] `Initialize-Starship` function + auto-init in module
- [x] Install-Dotfiles.ps1 prompts for Starship config
- [x] bootstrap-dotfiles.sh prompts for p10k config
- [x] Respects existing user configs (asks before overwriting)

### 3.6 Template Syntax Cleanup (Optional)

The Go template engine supports both syntaxes:
- New: `{{#if (eq os "darwin")}}` (Handlebars)
- Old: `{{?OS_TYPE="darwin"}}` (legacy)

**Tasks:**
- [ ] Run `dotfiles template lint` to find old syntax usage
- [ ] Migrate remaining templates to Handlebars syntax
- [ ] Consider removing old syntax support from Go engine

### 3.7 Success Criteria

Phase 3 is complete when:
- [ ] `dotfiles` command runs Go binary directly (no shell interception)
- [ ] All shell scripts in `bin/dotfiles-*` deleted (except setup)
- [ ] Shell wrappers only exist for env/cd commands
- [ ] Binary-only installation is clean and documented
- [ ] All tests pass
- [ ] Documentation updated

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
