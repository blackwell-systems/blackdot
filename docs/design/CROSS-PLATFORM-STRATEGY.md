# Cross-Platform Strategy: Go CLI Expansion

> **Date:** 2025-12-08
> **Status:** Implemented (Milestones 1-9 Complete)

---

## Problem Statement

The blackdot system has two layers:

1. **Control Plane** (Go CLI) - `blackdot setup`, `blackdot vault`, etc.
   - ✅ 100% Go, works anywhere Go compiles

2. **Developer Tools** (Shell Functions) - `awsswitch`, `go-new`, `sshtunnel`, etc.
   - ❌ Requires zsh, won't work on Windows/PowerShell

Windows users can install the Go binary but get none of the developer productivity tools.

---

## Proposed Solution: `blackdot tools` Subcommand

Extend the Go CLI with a `tools` subcommand that provides cross-platform versions of high-value shell functions.

```
blackdot tools aws [command]      # AWS profile management
blackdot tools ssh [command]      # SSH key/tunnel management
blackdot tools docker [command]   # Docker helpers
blackdot tools scaffold [lang]    # Project scaffolding
```

### Phase 1: SSH Tools (Highest Cross-Platform Value)

```
blackdot tools ssh list           # List SSH hosts from config
blackdot tools ssh keys           # List keys with fingerprints
blackdot tools ssh gen [name]     # Generate new key pair
blackdot tools ssh tunnel [spec]  # Create port forward tunnel
blackdot tools ssh agent          # Agent status and management
```

**Why SSH first:**
- No external dependencies (just Go's crypto/ssh)
- High value on Windows where ssh-agent UX is poor
- Clear, bounded scope

### Phase 2: AWS Tools

```
blackdot tools aws profiles       # List configured profiles
blackdot tools aws switch [name]  # Switch active profile
blackdot tools aws who            # Show current identity
blackdot tools aws login [prof]   # SSO login flow
```

**Why AWS second:**
- Depends on AWS CLI being installed
- High value for multi-account users
- Complex but well-defined

### Phase 3: Scaffolding

```
blackdot tools scaffold go [name]     # Go project with standard layout
blackdot tools scaffold rust [name]   # Rust project
blackdot tools scaffold python [name] # Python/uv project
```

**Why scaffolding:**
- Pure Go implementation (just file creation)
- High value for consistency across machines
- Templates can be embedded in binary

### Phase 4: Docker Tools (Optional)

```
blackdot tools docker ps          # Enhanced container list
blackdot tools docker ip [name]   # Get container IP
blackdot tools docker clean       # Prune unused resources
blackdot tools docker stats       # Live resource usage
```

---

## Architecture

### Option A: Monolithic Binary (Recommended)

Add all tools to the existing `blackdot-go` binary:

```
cmd/blackdot/
├── main.go
├── root.go
└── tools/
    ├── tools.go          # Parent command
    ├── ssh.go            # SSH subcommands
    ├── aws.go            # AWS subcommands
    ├── scaffold.go       # Project templates
    └── docker.go         # Docker subcommands
```

**Pros:**
- Single binary to distribute
- Shared infrastructure (config, logging)
- Consistent UX

**Cons:**
- Larger binary size (~10-15MB total)

### Option B: Separate Binaries

Create `blackdot-tools` as separate binary:

```
cmd/
├── dotfiles/             # Core CLI
└── blackdot-tools/       # Developer tools
```

**Pros:**
- Smaller core binary
- Optional installation

**Cons:**
- Two binaries to manage
- Duplicated infrastructure

---

## Shell Integration Strategy

For zsh/bash users, the shell functions can remain as thin wrappers:

```bash
# zsh/zsh.d/60-aws.zsh
awsswitch() {
  if command -v blackdot-go &>/dev/null; then
    blackdot-go tools aws switch "$@"
  else
    # Fallback to shell implementation
    _awsswitch_shell "$@"
  fi
}
```

This provides:
- Backward compatibility for existing users
- Gradual migration path
- Shell-specific features (completion, hooks) still work

---

## What Stays in Shell

Some functionality is inherently shell-specific:

| Feature | Reason |
|---------|--------|
| Aliases (`gst`, `cb`) | Just type shortcuts, no logic |
| Auto-venv activation | Requires `chpwd` hook |
| `y` (yazi wrapper) | Needs to change shell's cwd |
| Prompt integration | Shell-specific |
| Completion scripts | Shell-specific |

These should remain in shell config files.

---

## Implementation Roadmap

### Milestone 1: Foundation ✅ COMPLETE
- [x] Create `tools` parent command
- [x] Implement `tools ssh keys` (list keys with fingerprints)
- [x] Implement `tools ssh gen` (key generation)
- [ ] Add shell wrapper pattern to ssh.zsh as example

### Milestone 2: SSH Complete ✅ COMPLETE
- [x] `tools ssh list` (parse ~/.ssh/config)
- [x] `tools ssh tunnel` (port forwarding)
- [x] `tools ssh agent` (status, load, unload)
- [x] `tools ssh fp` (fingerprints in SHA256/MD5)
- [x] `tools ssh copy` (copy key to remote)
- [x] `tools ssh socks` (SOCKS5 proxy)
- [x] Windows testing (PowerShell wrappers verified)

### Milestone 3: AWS Tools ✅ COMPLETE
- [x] `tools aws profiles`
- [x] `tools aws switch`
- [x] `tools aws who`
- [x] `tools aws login` (SSO flow)
- [x] `tools aws assume` (role assumption)
- [x] `tools aws clear` (clear temp creds)
- [x] `tools aws status` (ASCII art banner)

### Milestone 4: Language Tools ✅ COMPLETE
- [x] `tools go new/init/test/cover/lint/update/outdated/build-all/bench/info`
- [x] `tools rust new/update/switch/lint/fix/outdated/expand/info`
- [x] `tools python new/clean/venv/test/cover/info`

### Milestone 5: CDK Tools ✅ COMPLETE
- [x] `tools cdk init` (initialize project)
- [x] `tools cdk env` (set CDK environment from AWS profile)
- [x] `tools cdk env-clear` (clear CDK environment)
- [x] `tools cdk outputs` (show CloudFormation outputs)
- [x] `tools cdk context` (show/clear context)
- [x] `tools cdk status` (ASCII art banner)

### Milestone 6: PowerShell Hooks ✅ COMPLETE
- [x] Create `powershell/` directory with profile module
- [x] Implement `prompt` hook (like ZSH `precmd`)
- [x] Implement directory change hook (like ZSH `chpwd`)
- [x] Implement shell exit hook (like ZSH `zshexit`)
- [x] Wire hooks to call `blackdot hook run <point>`
- [x] Generate aliases for all `blackdot tools` commands
- [x] Installation script for PowerShell profile
- [x] Documentation for Windows users
- [x] Full parity: all 24 hook points, file/function/JSON hooks
- [x] Timeout support, fail-fast, feature gating

### Milestone 7: Feature Flag Integration ✅ COMPLETE
- [x] Add feature flag checking to Go tools (matches ZSH patterns)
- [x] Map tool names to feature names:
  - `ssh` → `ssh_tools`, `aws` → `aws_helpers`, `cdk` → `cdk_tools`
  - `go` → `go_tools`, `rust` → `rust_tools`, `python` → `python_tools`
- [x] Wrap all tool commands with feature check
- [x] Show helpful error message when feature disabled
- [x] Verify template system parity (RaymondEngine - 20 tests)

**PowerShell Hook Mapping:**

| ZSH Hook | PowerShell Equivalent | Implementation |
|----------|----------------------|----------------|
| `shell_init` | Profile script | Source module in `$PROFILE` |
| `precmd` | `prompt` function | Override `$function:prompt` |
| `chpwd` | `Set-Location` wrapper | Intercept `cd`/`Set-Location` |
| `zshexit` | `Register-EngineEvent PowerShell.Exiting` | Native event |
| `preexec` | `PSReadLine` PreExecutionHandler | ReadLine hook |

---

## Success Metrics

1. **Windows Usability**: Can a Windows user use all core productivity features?
2. **Binary Size**: Keep under 15MB
3. **Shell Parity**: No regression for zsh/bash users
4. **Maintenance**: Shell functions become thin wrappers, not duplicated logic

---

## Open Questions

1. ~~**Should Windows get PowerShell aliases?**~~ ✅ Yes - Milestone 6 addresses this

2. **How to handle shell-specific features?** Some tools (like `j` project jumper) need shell integration for directory changing.

3. **Configuration sharing?** Should `tools aws` read from same config as shell functions?

4. ~~**Feature flags?** Should tools be feature-gated like other blackdot features?~~ ✅ Yes - Milestone 7 implements this

---

## Summary

| Layer | Current | Proposed | Status |
|-------|---------|----------|--------|
| Core CLI | 100% Go | 100% Go | ✅ Complete |
| Dev Tools | 100% Shell | Go + Shell wrappers | ✅ Complete (50+ tools) |
| Aliases | Shell | Shell + PowerShell | ✅ Complete (85+ functions) |
| Hooks | Shell only | Shell + PowerShell | ✅ Complete (24 hook points) |
| Feature Flags | Shell only | Go + Shell | ✅ Complete (7 tool categories) |
| Templates | Shell only | Go + Shell | ✅ Complete (RaymondEngine, 20 tests) |
| Migration | N/A | `import chezmoi` | ✅ Complete (Go template → Handlebars) |
| Package Mgmt | Homebrew | Homebrew + winget | ✅ Complete (Install-Packages.ps1) |
| Node.js | NVM | NVM + fnm | ✅ Complete (cross-platform) |

The goal is **additive** - Windows users gain functionality, shell users lose nothing.

---

## What's Next

### Remaining Open Questions
1. **Shell-specific features** - Tools like `j` (project jumper) need directory changing
2. ~~**Configuration sharing**~~ ✅ RESOLVED - Both Go and shell use same `config.json` format

### Milestone 8: Docker Tools ✅ COMPLETE
- [x] `tools docker ps` (list containers)
- [x] `tools docker images` (list images)
- [x] `tools docker ip` (get container IP)
- [x] `tools docker env` (show container env vars)
- [x] `tools docker ports` (show exposed ports)
- [x] `tools docker stats` (resource usage)
- [x] `tools docker vols` (list volumes)
- [x] `tools docker nets` (list networks)
- [x] `tools docker inspect` (with JSON path filtering)
- [x] `tools docker clean` (remove stopped + dangling)
- [x] `tools docker prune` (system prune)
- [x] `tools docker status` (ASCII art status banner)

### Milestone 9: Windows Package Management ✅ COMPLETE
- [x] `Install-Packages.ps1` - winget-based package installer (like `brew bundle`)
- [x] `packages.json` - Declarative package manifest
- [x] Three tiers: minimal, enhanced, full (matching Brewfile)
- [x] fnm integration (cross-platform NVM alternative)
- [x] zoxide integration (smart navigation)
- [x] Docker wrapper functions (12 commands)
- [x] Comprehensive Windows documentation
- [x] PowerShell tested on Linux via PowerShell Core 7.5

### Potential Future Milestones
- **Milestone 10: Shell Wrappers** - Thin ZSH wrappers that delegate to Go tools
- **Milestone 11: jabba Integration** - Cross-platform JDK version manager (SDKMAN alternative)
