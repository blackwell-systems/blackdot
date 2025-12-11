# Go CLI Migration - Complete

> **Status:** Phase 3 Complete - Go Binary is Primary CLI
> **Last Updated:** 2025-12-09

---

## Summary

The Go CLI rewrite is **complete**. All commands are now provided by the Go binary (`bin/blackdot`). Shell fallback has been removed. The Go binary is the sole CLI implementation.

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

- Renamed binary from `dotfiles-go` to `blackdot`
- Removed shell fallback (`DOTFILES_USE_GO` escape hatch)
- Deleted 19 deprecated `bin/blackdot-*` shell scripts (~7500 lines)
- Deleted 12 deprecated `lib/*.sh` libraries (~5500 lines)
- Simplified `40-aliases.zsh` (~550 lines removed)
- Updated CI workflows for Go-first testing
- Added `blackdot shell-init` command for shell function initialization
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
$ blackdot tools aws switch prod
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
├── 00-init.zsh          # PATH, BLACKDOT_DIR, instant prompt
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
BLACKDOT_VERSION=v3.1.0 ./install.sh --binary
```

**Features implemented:**
- [x] Platform detection (darwin/linux/windows, amd64/arm64)
- [x] Downloads from GitHub releases
- [x] Installs to `~/.local/bin/blackdot-go`
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

# Result: ~/.local/bin/blackdot-go
```

**Windows PowerShell:**
```powershell
# Just the CLI binary, no module, no profile changes
.\Install-Dotfiles.ps1 -BinaryOnly

# Result: ~/.local/bin/blackdot-go.exe
```

**Binary-only user experience:**
- User calls `dotfiles-go` directly (not `blackdot`)
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
irm https://raw.githubusercontent.com/blackwell-systems/blackdot/main/Install.ps1 | iex

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

- [x] Add checksum verification for downloaded binaries
- [x] Make `--binary` the default (now opt-out with `--no-binary`)

### 1.5 Windows `/workspace` Symlink Considerations

The `/workspace` symlink enables portable Claude Code sessions across machines. All sessions reference `/workspace/project` instead of platform-specific paths like `/Users/john/workspace/project`.

| Environment | `/workspace` Support | How to Create |
|-------------|---------------------|---------------|
| **macOS** | ✅ Full | `sudo ln -sf ~/workspace /workspace` |
| **Linux** | ✅ Full | `sudo ln -sf ~/workspace /workspace` |
| **WSL2** | ✅ Full | `sudo ln -sf ~/workspace /workspace` |
| **Git Bash + Admin** | ✅ Full | `mklink /D C:\workspace %USERPROFILE%\workspace` |
| **Git Bash (no Admin)** | ⚠️ Limited | Cannot create symlink; sessions use platform-specific paths |
| **Native PowerShell** | ⚠️ Limited | Needs `C:\workspace` junction (admin required) |

**Why it matters:**
- The `claude` wrapper in `zsh/zsh.d/70-claude.zsh` auto-redirects `~/workspace/*` to `/workspace/*`
- Without `/workspace`, sessions use platform-specific paths and aren't portable across machines
- dotclaude profile sync relies on consistent `/workspace/.claude` paths

**Recommendation for Windows users:**
1. **Use WSL2** (recommended) - full `/workspace` support
2. **Or run as admin once** to create the symlink:
   ```cmd
   mklink /D C:\workspace %USERPROFILE%\workspace
   ```
3. **Or accept non-portable sessions** - works fine for single-machine use

**Current behavior:** `bootstrap-windows.sh` prints instructions but doesn't auto-create (requires admin).

---

## Phase 2: Shell Switchover ✅

**Goal:** Make shell call Go binary instead of shell scripts

### 2.1 Update 40-aliases.zsh ✅

**Current state:** The `blackdot` function is a large dispatcher calling shell scripts

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
    if [[ -x "$BLACKDOT_DIR/bin/blackdot" ]]; then
        "$BLACKDOT_DIR/bin/blackdot" "$@"
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
- [x] Implement `blackdot shell-init zsh` command
- [x] Update shell modules to use Go binary (via shell-init)

### 2.4 Tool Group Aliases ✅

Expose `blackdot tools X` as convenient `Xtools` commands:

**ZSH (functions in 40-aliases.zsh):**
```zsh
# Tool group aliases - delegate to Go binary
sshtools()    { "$BLACKDOT_DIR/bin/blackdot-go" tools ssh "$@"; }
awstools()    { "$BLACKDOT_DIR/bin/blackdot-go" tools aws "$@"; }
cdktools()    { "$BLACKDOT_DIR/bin/blackdot-go" tools cdk "$@"; }
gotools()     { "$BLACKDOT_DIR/bin/blackdot-go" tools go "$@"; }
rusttools()   { "$BLACKDOT_DIR/bin/blackdot-go" tools rust "$@"; }
pytools()     { "$BLACKDOT_DIR/bin/blackdot-go" tools python "$@"; }
dockertools() { "$BLACKDOT_DIR/bin/blackdot-go" tools docker "$@"; }
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
- Short, memorable commands (`cdktools` vs `blackdot tools cdk`)
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
│  ~/workspace/blackdot/     ← Optional repo (for shell integration)   │
│  ├── zsh/zsh.d/                                                      │
│  │   ├── 00-init.zsh       PATH, BLACKDOT_DIR, instant prompt        │
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
| Binary: `dotfiles-go` | Binary: `blackdot` |
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
# blackdot doctor, dotfiles features, dotfiles vault, etc.
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
# Result: ~/.local/bin/blackdot (just works)

# Windows
.\Install-Dotfiles.ps1 -BinaryOnly
# Result: ~/.local/bin/blackdot.exe (just works)
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
- [ ] Change `dotfiles-go` → `blackdot` in install.sh
- [ ] Change `dotfiles-go` → `blackdot` in Install-Dotfiles.ps1
- [ ] Update GitHub Actions to produce `dotfiles-{os}-{arch}` (no `-go` suffix)
- [ ] Update Makefile: `make build` outputs `bin/blackdot`

**3.4.2 Simplify Shell Wrappers**
- [ ] Remove `dotfiles()` function that intercepts all commands
- [ ] Remove `_dotfiles_shell()` fallback function
- [ ] Remove `DOTFILES_USE_GO` environment variable
- [ ] Keep only env/cd wrappers in 40-aliases.zsh
- [ ] Keep only env/cd wrappers in Dotfiles.psm1

**3.4.3 Implement Setup Wizard in Go** ✅ DONE

~~The current `bin/blackdot-setup` is ZSH-only, which breaks Windows/binary-only users.~~

**IMPLEMENTED (2025-12-09):** Windows support added to `blackdot setup` command.

> **📋 Detailed Implementation Plan:** See [IMPL-setup-wizard-go.md](IMPL-setup-wizard-go.md)

**Phases implemented:**
- [x] `blackdot setup` - Main entry point with progress tracking ✅
- [x] Phase 1: Workspace configuration ✅ (`C:\workspace` on Windows)
- [x] Phase 2: Symlinks ✅ (PowerShell profile on Windows)
- [x] Phase 3: Packages ✅ (winget on Windows, Homebrew on Unix)
- [x] Phase 4: Vault configuration ✅
- [x] Phase 5: Secrets setup ✅
- [x] Phase 6: Claude configuration ✅
- [x] Phase 7: Template rendering ✅

**State management:** ✅
- Reuses existing `config.json` state tracking
- `blackdot setup --status` shows progress
- `blackdot setup --reset` clears state

**Platform-specific handling:** ✅
- Unix: Symlink `.zshrc`, prompt for p10k config
- Windows: PowerShell profile, prompt for Starship config
- Both: Platform-aware help text and paths

**3.4.4 Delete Deprecated Shell Scripts**
```
bin/blackdot-backup      → DELETE (Go: dotfiles backup)
bin/blackdot-config      → DELETE (Go: dotfiles config)
bin/blackdot-diff        → DELETE (Go: dotfiles diff)
bin/blackdot-doctor      → DELETE (Go: dotfiles doctor)
bin/blackdot-drift       → DELETE (Go: blackdot drift)
bin/blackdot-encrypt     → DELETE (Go: dotfiles encrypt)
bin/blackdot-features    → DELETE (Go: dotfiles features)
bin/blackdot-hook        → DELETE (Go: dotfiles hook)
bin/blackdot-lint        → DELETE (Go: dotfiles lint)
bin/blackdot-metrics     → DELETE (Go: dotfiles metrics)
bin/blackdot-migrate     → DELETE (Go: dotfiles migrate)
bin/blackdot-packages    → DELETE (Go: dotfiles packages)
bin/blackdot-setup       → DELETE (Go: dotfiles setup) ← NEW
bin/blackdot-status      → DELETE (Go: dotfiles status)
bin/blackdot-sync        → DELETE (Go: dotfiles sync)
bin/blackdot-template    → DELETE (Go: dotfiles template)
bin/blackdot-uninstall   → DELETE (Go: dotfiles uninstall)
bin/blackdot-vault       → DELETE (Go: dotfiles vault)
```

**3.4.5 Archive Shell Libraries**
```
lib/_features.sh   → Archive (Go handles feature registry)
lib/_config.sh     → Archive (Go handles config)
lib/_vault.sh      → Archive (Go handles vault via vaultmux)
lib/_templates.sh  → Archive (Go handles templates)
lib/_state.sh      → Archive (Go handles setup state)
lib/_logging.sh    → KEEP (used by bootstrap scripts)
lib/_hooks.sh      → KEEP (shell hook system)
lib/_colors.sh     → KEEP (used by bootstrap scripts)
```

**3.4.6 Update Documentation**
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
- [x] Run `blackdot template lint` to find old syntax usage (none found)
- [x] Migrate remaining templates to Handlebars syntax (already migrated)
- [x] Consider removing old syntax support from Go engine (none exists)

### 3.7 Cross-Platform CI Testing

Add GitHub Actions workflow for automated cross-platform testing.

**Tasks:**
- [ ] Create `.github/workflows/ci.yml` with matrix strategy
- [ ] Test on: `ubuntu-latest`, `macos-latest`, `windows-latest`
- [ ] Run `go build`, `go test`, and `go vet` on all platforms
- [ ] Add PowerShell script linting for Windows module
- [ ] Add shellcheck for bash/zsh scripts

**Example workflow:**
```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - run: go build ./...
      - run: go test ./...
      - run: go vet ./...
```

**Benefits:**
- Catch Windows-specific issues without needing Windows locally
- Verify cross-compilation works
- Test Go code on all target platforms automatically

### 3.8 Success Criteria

Phase 3 is complete when:
- [ ] `blackdot` command runs Go binary directly (no shell interception)
- [ ] All shell scripts in `bin/blackdot-*` deleted (except setup)
- [ ] Shell wrappers only exist for env/cd commands
- [ ] Binary-only installation is clean and documented
- [ ] All tests pass on all platforms (Linux, macOS, Windows)
- [ ] GitHub Actions CI passing
- [ ] Documentation updated

### 3.9 Cross-Platform Audit (2025-12-09)

Comprehensive audit of cross-platform support status:

#### Fully Cross-Platform (Go) ✅

| Component | Go Implementation | Notes |
|-----------|-------------------|-------|
| **CLI Commands** | `internal/cli/*.go` | 19+ commands, all cross-platform |
| **Feature Registry** | `internal/feature/` | Works on Unix & Windows |
| **Config System** | `internal/config/` | Uses `filepath.Join`, `os.UserHomeDir` |
| **Vault System** | `internal/cli/vault.go` | ~2000 lines, vaultmux integration |
| **Template Engine** | `internal/cli/template.go` | Handlebars syntax, cross-platform paths |
| **Claude Tools** | `internal/cli/tools_claude.go` | `claude init` copies files cross-platform |
| **Developer Tools** | `internal/cli/tools_*.go` | 50+ tools (SSH, AWS, CDK, Go, Rust, etc.) |

#### Platform-Specific Shell (Working) ✅

| Platform | Shell Config | Status |
|----------|--------------|--------|
| **Unix (ZSH)** | `zsh/zsh.d/*.zsh` | Full functionality |
| **Windows (PS)** | `powershell/Dotfiles.psm1` | 1365 lines, full parity |
| **Prompt (Unix)** | Powerlevel10k | Enhanced tier, config prompt ✅ |
| **Prompt (Win)** | Starship | Enhanced tier, config prompt ✅ |

#### Needs Go Implementation ⏳

| Component | Current | Needed | Plan |
|-----------|---------|--------|------|
| **Setup Wizard** | `bin/blackdot-setup` (ZSH) | `blackdot setup` (Go) | [IMPL-setup-wizard-go.md](IMPL-setup-wizard-go.md) |

#### Legacy (Will Be Deprecated) 📦

| Category | Files | Replacement |
|----------|-------|-------------|
| `bin/blackdot-*` | 20 shell scripts | Go CLI commands |
| `lib/*.sh` | 15 shell libraries | Go packages |
| `vault/*.sh` | 19 shell scripts | Go vault commands |

#### Known Limitations

1. ~~**Claude hooks** (`claude/hooks/*.sh`) - Shell scripts, need Windows `.ps1` equivalents~~
   - **RESOLVED**: PowerShell equivalents added (`*.ps1` alongside `*.sh`)
2. **Bootstrap** (`bootstrap-dotfiles.sh`) - Unix only, Windows uses `Install-Dotfiles.ps1`
3. **Package managers** - Homebrew (Unix) vs winget (Windows) - handled separately
4. **Workspace symlink** - Unix: `/workspace`, Windows: `C:\workspace` junction (both supported)

---

## Phase 4: Future Enhancements (Optional)

These are "nice to have" improvements after the migration is complete:

### 4.1 Community Features

- [ ] Community preset marketplace
- [ ] VS Code / IDE extensions
- [ ] Team sync features

### 4.2 Additional Backends

- [ ] HashiCorp Vault backend for vaultmux (unlikely - complexity vs. demand)
- [x] AWS Secrets Manager backend (supported via vaultmux)
- [x] Azure Key Vault backend (supported via vaultmux)

---

## Testing Checklist

Before each phase, verify:

```bash
# Build Go binary
make build

# Run Go tests
go test ./...

# Compare Go vs Shell output
diff <(dotfiles features list) <(./bin/blackdot features list)
diff <(dotfiles doctor) <(./bin/blackdot doctor)
diff <(dotfiles vault status) <(./bin/blackdot vault status)

# Verify on fresh shell
exec zsh
blackdot version  # Should show Go version
```

---

## Rollback Plan

If issues arise after switchover:

```bash
# Immediate: Set env var to use shell
export DOTFILES_USE_GO=0
exec zsh

# Or: Remove Go binary to force shell fallback
rm $BLACKDOT_DIR/bin/blackdot
exec zsh
```

Shell implementation remains intact until Phase 3 cleanup.

---

## Quick Reference

### Current Binary Location

```
$BLACKDOT_DIR/bin/blackdot     # Go binary (19 commands)
$BLACKDOT_DIR/bin/blackdot-*   # Shell scripts (deprecated)
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
