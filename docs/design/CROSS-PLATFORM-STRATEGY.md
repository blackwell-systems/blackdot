# Cross-Platform Strategy: Go CLI Expansion

> **Date:** 2025-12-08
> **Status:** Proposal

---

## Problem Statement

The dotfiles system has two layers:

1. **Control Plane** (Go CLI) - `dotfiles setup`, `dotfiles vault`, etc.
   - ✅ 100% Go, works anywhere Go compiles

2. **Developer Tools** (Shell Functions) - `awsswitch`, `go-new`, `sshtunnel`, etc.
   - ❌ Requires zsh, won't work on Windows/PowerShell

Windows users can install the Go binary but get none of the developer productivity tools.

---

## Proposed Solution: `dotfiles tools` Subcommand

Extend the Go CLI with a `tools` subcommand that provides cross-platform versions of high-value shell functions.

```
dotfiles tools aws [command]      # AWS profile management
dotfiles tools ssh [command]      # SSH key/tunnel management
dotfiles tools docker [command]   # Docker helpers
dotfiles tools scaffold [lang]    # Project scaffolding
```

### Phase 1: SSH Tools (Highest Cross-Platform Value)

```
dotfiles tools ssh list           # List SSH hosts from config
dotfiles tools ssh keys           # List keys with fingerprints
dotfiles tools ssh gen [name]     # Generate new key pair
dotfiles tools ssh tunnel [spec]  # Create port forward tunnel
dotfiles tools ssh agent          # Agent status and management
```

**Why SSH first:**
- No external dependencies (just Go's crypto/ssh)
- High value on Windows where ssh-agent UX is poor
- Clear, bounded scope

### Phase 2: AWS Tools

```
dotfiles tools aws profiles       # List configured profiles
dotfiles tools aws switch [name]  # Switch active profile
dotfiles tools aws who            # Show current identity
dotfiles tools aws login [prof]   # SSO login flow
```

**Why AWS second:**
- Depends on AWS CLI being installed
- High value for multi-account users
- Complex but well-defined

### Phase 3: Scaffolding

```
dotfiles tools scaffold go [name]     # Go project with standard layout
dotfiles tools scaffold rust [name]   # Rust project
dotfiles tools scaffold python [name] # Python/uv project
```

**Why scaffolding:**
- Pure Go implementation (just file creation)
- High value for consistency across machines
- Templates can be embedded in binary

### Phase 4: Docker Tools (Optional)

```
dotfiles tools docker ps          # Enhanced container list
dotfiles tools docker ip [name]   # Get container IP
dotfiles tools docker clean       # Prune unused resources
dotfiles tools docker stats       # Live resource usage
```

---

## Architecture

### Option A: Monolithic Binary (Recommended)

Add all tools to the existing `dotfiles-go` binary:

```
cmd/dotfiles/
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

Create `dotfiles-tools` as separate binary:

```
cmd/
├── dotfiles/             # Core CLI
└── dotfiles-tools/       # Developer tools
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
  if command -v dotfiles-go &>/dev/null; then
    dotfiles-go tools aws switch "$@"
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
- [ ] Windows testing

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

---

## Success Metrics

1. **Windows Usability**: Can a Windows user use all core productivity features?
2. **Binary Size**: Keep under 15MB
3. **Shell Parity**: No regression for zsh/bash users
4. **Maintenance**: Shell functions become thin wrappers, not duplicated logic

---

## Open Questions

1. **Should Windows get PowerShell aliases?** Could generate `.ps1` with aliases that call the Go binary.

2. **How to handle shell-specific features?** Some tools (like `j` project jumper) need shell integration for directory changing.

3. **Configuration sharing?** Should `tools aws` read from same config as shell functions?

4. **Feature flags?** Should tools be feature-gated like other dotfiles features?

---

## Summary

| Layer | Current | Proposed |
|-------|---------|----------|
| Core CLI | 100% Go | 100% Go |
| Dev Tools | 100% Shell | Go + Shell wrappers |
| Aliases | Shell | Shell (keep) |
| Hooks | Shell | Shell (keep) |

The goal is **additive** - Windows users gain functionality, shell users lose nothing.
