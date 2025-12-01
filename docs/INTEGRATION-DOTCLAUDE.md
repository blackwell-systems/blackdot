# dotclaude Integration Plan

> **Goal:** Integrate dotclaude with dotfiles as complementary products in the Blackwell Systems ecosystem while maintaining loose coupling and independence.

**Version:** 1.0.0 (Draft)
**Status:** Planning Phase
**Last Updated:** 2025-11-30

---

## Executive Summary

This document outlines the integration strategy between **dotfiles** (shell configuration and secret management) and **dotclaude** (Claude Code profile management). The integration follows these principles:

1. **Loose Coupling** - Each product remains fully functional independently
2. **Optional Integration** - Users can adopt either product standalone
3. **No Hard Dependencies** - Neither product requires the other to function
4. **Complementary Features** - Together they provide enhanced developer experience
5. **Shared Ecosystem** - Common conventions, workspace patterns, and CLI design

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                  Blackwell Systems Ecosystem                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────┐         ┌──────────────────────┐      │
│  │     dotfiles         │         │     dotclaude        │      │
│  │  (Shell & Secrets)   │◄────────┤  (Claude Profiles)   │      │
│  │                      │ optional│                      │      │
│  │ • Zsh config         │         │ • Profile mgmt       │      │
│  │ • Vault sync         │         │ • Multi-backend      │      │
│  │ • Templates          │         │ • Session routing    │      │
│  │ • Health checks      │         │ • Config isolation   │      │
│  └──────────┬───────────┘         └──────────┬───────────┘      │
│             │                                │                  │
│             └────────────┬───────────────────┘                  │
│                          │                                      │
│                          ▼                                      │
│              ┌────────────────────────┐                         │
│              │  Shared Conventions    │                         │
│              ├────────────────────────┤                         │
│              │ • ~/workspace layout   │                         │
│              │ • ~/.claude location   │                         │
│              │ • CLI design patterns  │                         │
│              │ • Configuration style  │                         │
│              └────────────────────────┘                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Integration Levels

### Level 0: Independent (Current State)
**Status:** Implemented

Both products work completely independently:
- dotfiles manages shell config, no Claude-specific features
- dotclaude manages Claude profiles, no dotfiles awareness
- Users install and configure separately

**User Experience:**
```bash
# Separate installation
cd ~/workspace/dotfiles && ./bootstrap/bootstrap-mac.sh
cd ~/workspace/dotclaude && ./install.sh
```

### Level 1: Awareness (Minimal Integration)
**Status:** Proposed

dotfiles becomes aware of dotclaude but doesn't depend on it:
- dotfiles bootstrap can optionally install dotclaude
- dotfiles health checks detect dotclaude presence
- Shared conventions documented

**User Experience:**
```bash
# dotfiles bootstrap offers dotclaude installation
./bootstrap/bootstrap-mac.sh --with-dotclaude

# Health check shows dotclaude status
dotfiles doctor
# [OK] dotclaude: Installed (version 0.2.0)
# [OK] Active profile: work-bedrock
```

### Level 2: Integration (Recommended Target)
**Status:** Proposed (This Document)

dotfiles provides wrapper commands and shared configuration:
- `dotfiles claude` command wraps dotclaude
- Template system generates dotclaude configs
- Vault can store dotclaude profiles
- Health checks validate dotclaude setup

**User Experience:**
```bash
# Unified command interface
dotfiles claude status        # Wraps: dotclaude status
dotfiles claude switch work   # Wraps: dotclaude switch work

# Templates generate dotclaude configs
dotfiles template render      # Generates .claude.local

# Vault sync includes profiles
dotfiles vault sync --all     # Includes dotclaude profiles
```

### Level 3: Deep Integration (Future)
**Status:** Not Recommended (Violates Loose Coupling)

Full dependency and tight coupling:
- dotfiles hardcoded to require dotclaude
- Shared codebase between products
- Monolithic installation

**Why Not:** Violates independence principle, reduces flexibility.

---

## Proposed Integration Features

### 1. Bootstrap Integration

**Goal:** Optionally install dotclaude during dotfiles bootstrap

**Implementation:**
```bash
# bootstrap/bootstrap-mac.sh (additions)

# After main bootstrap completes
if [[ "${INSTALL_DOTCLAUDE:-false}" == "true" ]] || prompt_yes_no "Install dotclaude for Claude Code profile management?"; then
  info "Installing dotclaude..."

  # Check if already installed
  if command -v dotclaude &> /dev/null; then
    success "dotclaude already installed ($(dotclaude --version))"
  else
    # Install via Homebrew tap or curl installer
    if command -v brew &> /dev/null; then
      brew tap blackwell-systems/tap
      brew install dotclaude
    else
      curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotclaude/main/install.sh | bash
    fi
  fi

  # Run initial setup
  if command -v dotclaude &> /dev/null; then
    dotclaude setup
    success "dotclaude installed and configured"
  fi
fi
```

**Environment Variables:**
- `INSTALL_DOTCLAUDE=true` - Auto-install during bootstrap
- `SKIP_DOTCLAUDE=true` - Skip even if prompted

**Benefits:**
- One-command setup for complete Blackwell Systems environment
- Optional - users can decline
- Respects existing installations

### 2. Wrapper Commands

**Goal:** Provide `dotfiles claude` commands that wrap dotclaude

**Implementation:**
```bash
# bin/dotfiles-claude
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/workspace/dotfiles}"
source "$DOTFILES_DIR/lib/_logging.sh"

# Check if dotclaude is installed
if ! command -v dotclaude &> /dev/null; then
  error "dotclaude is not installed"
  echo ""
  echo "Install dotclaude:"
  echo "  brew tap blackwell-systems/tap && brew install dotclaude"
  echo "  OR"
  echo "  curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotclaude/main/install.sh | bash"
  exit 1
fi

# Pass all arguments directly to dotclaude
dotclaude "$@"
```

**Usage:**
```bash
dotfiles claude status         # → dotclaude status
dotfiles claude list           # → dotclaude list
dotfiles claude switch work    # → dotclaude switch work
dotfiles claude profile show   # → dotclaude profile show
```

**Add to dotfiles CLI:**
```bash
# zsh/zsh.d/40-aliases.zsh
alias dclaude='dotfiles claude'  # Shortcut
```

**Benefits:**
- Unified CLI interface under dotfiles
- Consistent command patterns
- Easy to remember for existing dotfiles users
- Falls back gracefully if dotclaude not installed

### 3. Health Check Integration

**Goal:** dotfiles doctor checks dotclaude installation and configuration

**Implementation:**
```bash
# bin/dotfiles-doctor (additions)

check_dotclaude() {
  echo ""
  echo "=== dotclaude (Optional) ==="

  # Check if installed
  if ! command -v dotclaude &> /dev/null; then
    info "dotclaude: Not installed (optional)"
    echo "  Install: brew tap blackwell-systems/tap && brew install dotclaude"
    return 0
  fi

  # Get version
  local version
  version=$(dotclaude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
  success "dotclaude: Installed (version $version)"

  # Check active profile
  local active_profile
  active_profile=$(dotclaude active 2>/dev/null || echo "none")
  if [[ "$active_profile" != "none" ]]; then
    success "Active profile: $active_profile"
  else
    warn "No active profile (run: dotclaude switch <profile>)"
  fi

  # Check profile count
  local profile_count
  profile_count=$(dotclaude list 2>/dev/null | grep -c '^\[' || echo "0")
  info "Profiles configured: $profile_count"

  # Check base directory
  local base_dir="$HOME/.claude"
  if [[ -d "$base_dir" ]]; then
    success "Claude base directory: $base_dir"
  else
    warn "Claude base directory not found"
  fi
}

# Add to main health check flow
check_dotclaude
```

**Output Example:**
```
=== dotclaude (Optional) ===
[OK] dotclaude: Installed (version 0.2.0)
[OK] Active profile: work-bedrock
[INFO] Profiles configured: 3
[OK] Claude base directory: /Users/user/.claude
```

### 4. Template Integration

**Goal:** Generate dotclaude configuration files via dotfiles templates

**Implementation:**

**Create Template:**
```bash
# templates/configs/claude-profiles.tmpl
# Generated by dotfiles template system
# Machine: {{ HOSTNAME }}
# Type: {{ MACHINE_TYPE }}

# Default backend for new sessions
{{ if MACHINE_TYPE == "work" }}
export CLAUDE_DEFAULT_BACKEND="bedrock"
export CLAUDE_BEDROCK_PROFILE="{{ AWS_PROFILE_WORK }}"
export CLAUDE_BEDROCK_REGION="{{ AWS_REGION }}"
{{ else }}
export CLAUDE_DEFAULT_BACKEND="max"
{{ endif }}

# Profile shortcuts
alias cwork='dotclaude switch work-bedrock'
alias cpersonal='dotclaude switch personal-max'
```

**Update Template Engine:**
```bash
# lib/_templates.sh (additions)

# Add to TEMPLATE_CONFIGS array
declare -A TEMPLATE_CONFIGS=(
  ["gitconfig"]="$HOME/.gitconfig"
  ["99-local.zsh"]="$HOME/workspace/dotfiles/zsh/zsh.d/99-local.zsh"
  ["ssh-config"]="$HOME/.ssh/config"
  ["claude-profiles"]="$HOME/.claude.profiles"  # New
)
```

**Usage:**
```bash
# Setup templates
dotfiles template init
# Generates ~/.claude.profiles based on machine type

# Source in zshrc
source ~/.claude.profiles 2>/dev/null || true
```

### 5. Vault Integration

**Goal:** Store and sync dotclaude profiles via dotfiles vault

**Implementation:**

**Create New Vault Script:**
```bash
# vault/restore-claude.sh
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

SESSION="$1"

info "Restoring Claude profiles from vault..."

# Get profile data from vault
PROFILE_DATA=$(get_vault_item "Claude-Profiles" "$SESSION")

if [[ -z "$PROFILE_DATA" ]]; then
  warn "Claude-Profiles not found in vault (skipping)"
  return 0
fi

# Write to dotclaude base directory
CLAUDE_BASE="$HOME/.claude"
mkdir -p "$CLAUDE_BASE"

# Extract and restore profiles
echo "$PROFILE_DATA" > "$CLAUDE_BASE/profiles.json"
chmod 600 "$CLAUDE_BASE/profiles.json"

success "Claude profiles restored"

# Verify with dotclaude if installed
if command -v dotclaude &> /dev/null; then
  PROFILE_COUNT=$(dotclaude list 2>/dev/null | grep -c '^\[' || echo "0")
  info "Profiles available: $PROFILE_COUNT"
fi
```

**Add to Bootstrap:**
```bash
# vault/bootstrap-vault.sh (additions)

# After restore-env.sh
if [[ "${RESTORE_CLAUDE_PROFILES:-true}" == "true" ]]; then
  ./restore-claude.sh "$SESSION" || warn "Claude profile restore failed (continuing...)"
fi
```

**Sync Back to Vault:**
```bash
# vault/sync-to-vault.sh (additions)

# Add Claude-Profiles to syncable items
declare -A SYNCABLE_ITEMS=(
  ["SSH-Config"]="$HOME/.ssh/config"
  ["AWS-Config"]="$HOME/.aws/config"
  ["AWS-Credentials"]="$HOME/.aws/credentials"
  ["Git-Config"]="$HOME/.gitconfig"
  ["Environment-Secrets"]="$HOME/.local/env.secrets"
  ["Claude-Profiles"]="$HOME/.claude/profiles.json"  # New
)
```

**Usage:**
```bash
# Sync Claude profiles to vault
dotfiles vault sync Claude-Profiles

# Restore on new machine
dotfiles vault restore  # Includes Claude profiles
```

### 6. Shared Workspace Convention

**Goal:** Document and enforce shared workspace patterns

**Already Implemented:**
- Both use `~/workspace` as canonical location
- Both support `/workspace` symlink for portable paths
- dotclaude profiles stored in `~/.claude`
- dotfiles creates `~/.claude → ~/workspace/.claude` symlink

**Documentation Updates:**

**dotfiles docs:**
```markdown
## Claude Code Integration

dotfiles is designed to work seamlessly with dotclaude for Claude Code profile management.

**Shared Workspace:**
- Both use `~/workspace` as the canonical workspace location
- Both support `/workspace` symlink for session portability
- Claude base directory: `~/.claude` (symlinked to `~/workspace/.claude`)

**Integration:**
- Install dotclaude: `brew tap blackwell-systems/tap && brew install dotclaude`
- Use wrapper: `dotfiles claude <command>`
- Health checks: `dotfiles doctor` includes dotclaude status
- Vault sync: Store profiles with `dotfiles vault sync Claude-Profiles`

**Standalone Usage:**
dotclaude works independently - you don't need dotfiles to use dotclaude.
```

**dotclaude docs:**
```markdown
## dotfiles Integration

dotclaude is part of the Blackwell Systems ecosystem and integrates with dotfiles.

**Benefits of Using Together:**
- Unified bootstrap: Install both with one command
- Vault sync: Store profiles securely with dotfiles vault system
- Templates: Generate Claude configs per machine
- Health checks: Validate Claude setup with `dotfiles doctor`

**Wrapper Commands:**
If you use dotfiles, you can use the wrapper:
```bash
dotfiles claude status    # → dotclaude status
dotfiles claude switch work
```

**Standalone Usage:**
dotclaude works independently - you don't need dotfiles to use dotclaude.
```

---

## Implementation Phases

### Phase 1: Documentation & Awareness (Week 1)
**Goal:** Make users aware of both products

- [ ] Add "Related Projects" section to both READMEs
- [ ] Document shared workspace conventions
- [ ] Create this integration plan document
- [ ] Add cross-links between documentation sites

### Phase 2: Optional Installation (Week 2)
**Goal:** Bootstrap integration

- [ ] Add `--with-dotclaude` flag to dotfiles bootstrap
- [ ] Add environment variable `INSTALL_DOTCLAUDE`
- [ ] Test bootstrap on clean macOS and Linux
- [ ] Update bootstrap documentation

### Phase 3: Wrapper Commands (Week 3)
**Goal:** Unified CLI

- [ ] Create `bin/dotfiles-claude` wrapper script
- [ ] Add to dotfiles CLI help output
- [ ] Add tab completion for `dotfiles claude`
- [ ] Test all dotclaude commands through wrapper

### Phase 4: Health Check Integration (Week 3)
**Goal:** Validate dotclaude in health checks

- [ ] Add `check_dotclaude()` to `bin/dotfiles-doctor`
- [ ] Test with dotclaude installed and not installed
- [ ] Add to CI tests (mock dotclaude)
- [ ] Update health check documentation

### Phase 5: Template Integration (Week 4)
**Goal:** Generate dotclaude configs

- [ ] Create `templates/configs/claude-profiles.tmpl`
- [ ] Add to template engine
- [ ] Test rendering on work and personal machines
- [ ] Document template variables for Claude

### Phase 6: Vault Integration (Week 5)
**Goal:** Store profiles in vault

- [ ] Create `vault/restore-claude.sh`
- [ ] Add to `vault/bootstrap-vault.sh`
- [ ] Update `vault/sync-to-vault.sh`
- [ ] Test with Bitwarden, 1Password, and pass
- [ ] Update vault documentation

### Phase 7: Testing & Documentation (Week 6)
**Goal:** Comprehensive validation

- [ ] Add bats tests for integration features
- [ ] Test all integration levels
- [ ] Update all documentation
- [ ] Create integration examples
- [ ] Record demo video

### Phase 8: Release (Week 7)
**Goal:** Public release

- [ ] dotfiles v1.8.0 with dotclaude integration
- [ ] dotclaude v0.3.0 with dotfiles awareness
- [ ] Blog post about integration
- [ ] Update marketing materials

---

## Testing Strategy

### Unit Tests (bats-core)

```bash
# test/dotclaude_integration.bats

@test "dotfiles bootstrap installs dotclaude when flag set" {
  export INSTALL_DOTCLAUDE=true
  run ./bootstrap/bootstrap-mac.sh
  [ "$status" -eq 0 ]
  command -v dotclaude
}

@test "dotfiles claude wrapper requires dotclaude" {
  # Mock dotclaude not installed
  PATH="/tmp/empty:$PATH"
  run ./bin/dotfiles-claude status
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not installed" ]]
}

@test "dotfiles doctor detects dotclaude" {
  # Mock dotclaude installed
  function dotclaude() { echo "0.2.0"; }
  export -f dotclaude

  run ./bin/dotfiles-doctor
  [ "$status" -eq 0 ]
  [[ "$output" =~ "dotclaude: Installed" ]]
}

@test "template system generates claude profiles" {
  export MACHINE_TYPE=work
  run ./bin/dotfiles-template render claude-profiles
  [ "$status" -eq 0 ]
  [ -f "$HOME/.claude.profiles" ]
  grep -q "CLAUDE_DEFAULT_BACKEND=\"bedrock\"" "$HOME/.claude.profiles"
}

@test "vault sync includes claude profiles" {
  # Mock profile data
  mkdir -p "$HOME/.claude"
  echo '{"profiles":[]}' > "$HOME/.claude/profiles.json"

  run ./bin/dotfiles-vault sync Claude-Profiles --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Claude-Profiles" ]]
}
```

### Integration Tests

```bash
# Manual test plan
1. Clean macOS install
2. Run dotfiles bootstrap with --with-dotclaude
3. Verify both products installed
4. Create dotclaude profile
5. Sync to vault with dotfiles
6. Clean Linux install
7. Run dotfiles bootstrap
8. Restore from vault
9. Verify profiles restored
10. Test wrapper commands
```

---

## User Personas & Use Cases

### Persona 1: dotfiles User (No dotclaude)
**Use Case:** Uses dotfiles for shell config, doesn't use Claude Code

**Experience:**
- Bootstrap completes without dotclaude
- No Claude-specific features visible
- Health checks skip dotclaude (shows as optional)
- No impact on existing workflow

**Validation:** Product remains fully functional without dotclaude.

### Persona 2: dotclaude User (No dotfiles)
**Use Case:** Uses dotclaude for Claude profiles, has custom shell setup

**Experience:**
- Installs dotclaude standalone
- Manages profiles with `dotclaude` commands
- No dependency on dotfiles
- Can optionally adopt dotfiles later

**Validation:** dotclaude remains fully functional without dotfiles.

### Persona 3: Full Blackwell Ecosystem User
**Use Case:** Uses both products together

**Experience:**
- Single bootstrap command installs both
- Unified `dotfiles claude` commands
- Profiles stored in vault, synced across machines
- Templates generate Claude configs per machine
- Health checks validate complete setup
- Seamless experience

**Validation:** Integration provides enhanced value without forced coupling.

### Persona 4: New Developer Onboarding
**Use Case:** New team member setting up development environment

**Experience:**
```bash
# One command gets everything
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash -s -- --with-dotclaude

# Unlock vault and restore secrets (including Claude profiles)
bw login
export BW_SESSION="$(bw unlock --raw)"
dotfiles vault restore

# Verify setup
dotfiles doctor
# All systems green, including dotclaude

# Ready to work
dotfiles claude status
# Active profile: work-bedrock
```

**Validation:** New developers productive in <10 minutes.

---

## Configuration File Locations

### Current State
```
~/workspace/dotfiles/         # dotfiles repo
~/.zshrc                      # → ~/workspace/dotfiles/zsh/zshrc
~/.ssh/config                 # → vault
~/.aws/config                 # → vault
~/.gitconfig                  # → vault or template

~/workspace/dotclaude/        # dotclaude repo
~/.claude/                    # Claude base directory
~/.claude/profiles.json       # dotclaude profiles
~/.claude/active              # Active profile symlink
```

### With Integration
```
~/workspace/dotfiles/         # dotfiles repo
~/workspace/dotclaude/        # dotclaude repo (optional)

~/.zshrc                      # → ~/workspace/dotfiles/zsh/zshrc
~/.ssh/config                 # → vault
~/.aws/config                 # → vault
~/.gitconfig                  # → vault or template
~/.claude.profiles            # → template (NEW)

~/.claude/                    # Claude base directory
~/.claude/profiles.json       # → vault (NEW)
~/.claude/active              # dotclaude managed
```

**Key Changes:**
- `~/.claude/profiles.json` synced via dotfiles vault
- `~/.claude.profiles` shell config generated by dotfiles templates
- All other locations unchanged

---

## Backward Compatibility

### dotfiles Users (Existing)
**Impact:** None

- No breaking changes to existing functionality
- dotclaude integration is opt-in
- Health checks gracefully handle missing dotclaude
- Existing workflows unaffected

**Migration:** None required.

### dotclaude Users (Existing)
**Impact:** None

- dotclaude continues to work standalone
- No dependency on dotfiles
- Existing profiles remain in `~/.claude/`
- Commands remain unchanged

**Migration:** Optional - can adopt dotfiles integration if desired.

### New Users
**Impact:** Enhanced Experience

- Can choose standalone or integrated installation
- Integration provides additional features
- Standalone remains fully supported

---

## Success Metrics

### Technical Metrics
- [ ] 0 hard dependencies between products
- [ ] Both products pass tests independently
- [ ] Integration tests pass for all levels
- [ ] No performance degradation
- [ ] 100% backward compatibility

### User Experience Metrics
- [ ] <10 minute onboarding time (integrated)
- [ ] <2 minute profile sync time
- [ ] Single command bootstrap success rate >95%
- [ ] User documentation clarity score >4.5/5

### Adoption Metrics
- [ ] 50% of dotfiles users adopt dotclaude
- [ ] 70% of dotclaude users adopt dotfiles
- [ ] Positive feedback on integration
- [ ] Community requests for deeper integration

---

## Risks & Mitigations

### Risk 1: Tight Coupling Creep
**Risk:** Over time, products become tightly coupled

**Mitigation:**
- Enforce "independent functionality" tests in CI
- Regular reviews of dependencies
- Architectural reviews before new integrations
- Document coupling boundaries

### Risk 2: User Confusion
**Risk:** Users don't understand when to use which product

**Mitigation:**
- Clear documentation on standalone vs integrated use
- Visual diagrams showing relationships
- Persona-based use case examples
- Prominent "Works Without" messaging

### Risk 3: Maintenance Burden
**Risk:** Integration code becomes maintenance bottleneck

**Mitigation:**
- Keep integration layer thin
- Use wrapper pattern (minimal custom logic)
- Comprehensive test coverage
- Clear ownership (dotfiles team owns integration)

### Risk 4: Version Skew
**Risk:** dotfiles and dotclaude versions become incompatible

**Mitigation:**
- Semantic versioning for both products
- Integration tests across version combinations
- Version compatibility matrix in docs
- Graceful degradation for older versions

---

## Review Feedback & Refinements

> **Review Date:** 2025-12-01
> **Status:** Under Consideration

### Concern 1: Nested Command Pattern Feels Subordinate

The proposed `dotfiles claude status` pattern makes dotclaude feel like a subcommand rather than a unified experience:

```bash
# Current proposal - feels nested
dotfiles claude status    # dotclaude is subordinate
dotclaude status          # the "real" command
```

**Issue:** Users will ask "which one do I use?" This creates confusion, not unity.

### Recommendation: Alias-Based Extension

Instead of a wrapper script (`bin/dotfiles-claude`), extend the dotfiles CLI directly with native-feeling subcommands:

```bash
# In zsh/zsh.d/40-aliases.zsh
dotfiles() {
    case "$1" in
        # Existing commands...

        # Claude profile commands (delegate to dotclaude if installed)
        profile|profiles|pswitch)
            if command -v dotclaude &>/dev/null; then
                case "$1" in
                    profile)  dotclaude "${@:2}" ;;
                    profiles) dotclaude list ;;
                    pswitch)  dotclaude switch "${@:2}" ;;
                esac
            else
                echo "dotclaude not installed. Install with:"
                echo "  brew tap blackwell-systems/tap && brew install dotclaude"
            fi
            ;;
    esac
}
```

**Result:**
```bash
dotfiles profile list     # Feels native, not nested
dotfiles pswitch work     # Quick profile switching
dotfiles profiles         # List all profiles
```

### Alternative: Unified Meta-Command

For stronger brand unity, consider a meta-command for the ecosystem:

```bash
bws status          # Shows both dotfiles + dotclaude status
bws profile work    # → dotclaude switch work
bws doctor          # → dotfiles doctor (includes dotclaude checks)
bws vault sync      # → dotfiles vault sync
```

**Pros:**
- Single entry point for entire Blackwell ecosystem
- Room for future products
- Clear branding

**Cons:**
- Another command to learn
- May confuse users who know `dotfiles` already

**Decision:** Defer to v2.0 after validating alias approach.

### Concern 2: Template Integration Complexity

The proposed `claude-profiles.tmpl` generating `~/.claude.profiles` adds unnecessary indirection.

**Simpler approach:** Set environment variables directly in `99-local.zsh`:

```bash
# templates/configs/99-local.zsh.tmpl
{{ if MACHINE_TYPE == "work" }}
export CLAUDE_DEFAULT_BACKEND="bedrock"
export CLAUDE_BEDROCK_PROFILE="{{ AWS_PROFILE_WORK }}"
{{ else }}
export CLAUDE_DEFAULT_BACKEND="max"
{{ endif }}
```

Then dotclaude reads these environment variables natively. No intermediate config file needed.

### Concern 3: Vault Storage for Profiles is Overkill

Storing `profiles.json` in vault adds complexity for minimal benefit:
- Profiles aren't secrets—they're configuration
- Vault sync requires unlocking, which adds friction
- Profiles are machine-specific anyway

**Alternatives:**
1. Keep profiles in `~/.claude/` (git-ignored, local only)
2. Store in dotfiles repo under `claude/profiles/` (versioned)
3. Generate from templates based on machine type

**Recommendation:** Remove vault integration for profiles. Keep vault for actual secrets.

### Concern 4: Implementation Phases Have Timelines

The phases reference week numbers which may not be realistic. Focus on:
- **What** needs to be done (concrete tasks)
- **Dependencies** between tasks
- Let scheduling happen organically

### Summary: Recommended Refinements

| Area | Current Plan | Recommendation |
|------|--------------|----------------|
| CLI Pattern | `dotfiles claude <cmd>` | `dotfiles profile <cmd>` (native feel) |
| Implementation | Wrapper script | Alias in 40-aliases.zsh |
| Template | Separate `.claude.profiles` | Env vars in `99-local.zsh` |
| Vault | Store `profiles.json` | Remove (profiles aren't secrets) |
| Meta-command | Not planned | Consider `bws` for v2.0 |

---

## Alternative Approaches Considered

### Alternative 1: Plugin Architecture
**Approach:** dotfiles has plugin system, dotclaude is a plugin

**Pros:**
- Clean separation
- Easy to add more plugins

**Cons:**
- Complex plugin infrastructure
- dotclaude loses independence
- Higher development overhead

**Decision:** Rejected - violates independence principle.

### Alternative 2: Monorepo
**Approach:** Merge both projects into single repository

**Pros:**
- Simplified development
- Single installation

**Cons:**
- Loss of modularity
- Forced coupling
- Harder for users who want only one product

**Decision:** Rejected - violates loose coupling.

### Alternative 3: No Integration
**Approach:** Keep products completely separate

**Pros:**
- Maximum independence
- No integration maintenance

**Cons:**
- Users must manage separately
- Missed opportunity for ecosystem value
- Duplicate configuration

**Decision:** Rejected - leaves value on the table.

### Alternative 4: Wrapper-Based Integration (Chosen)
**Approach:** dotfiles provides thin wrapper layer, both remain independent

**Pros:**
- Loose coupling maintained
- Optional integration
- Enhanced user experience
- Low maintenance overhead

**Cons:**
- Requires some coordination
- Documentation must explain both modes

**Decision:** Selected - best balance of independence and integration.

---

## Open Questions

1. **Should dotfiles bootstrap automatically detect dotclaude installation?**
   - Proposed: Yes, with opt-out flag
   - Rationale: Better user experience, still optional

2. **Should vault sync be automatic or explicit for Claude profiles?**
   - Proposed: Explicit (must specify `Claude-Profiles`)
   - Rationale: Users may not want profiles in vault

3. **Should dotclaude document dotfiles integration in main README or separate page?**
   - Proposed: Brief mention in main README, detailed page for integration
   - Rationale: Keeps main README focused on dotclaude features

4. **Should we create a `blackwell` meta-package that installs both?**
   - Proposed: Future consideration (v2.0)
   - Rationale: Proves value first with wrapper approach

---

## Next Steps

**Immediate Actions (Week 1):**
1. Review this integration plan with stakeholders
2. Get feedback on proposed architecture
3. Make decision on open questions
4. Create GitHub issues for Phase 1 tasks

**Short-term (Weeks 2-4):**
1. Implement Phase 1-3 (awareness, bootstrap, wrappers)
2. Test on multiple platforms
3. Update documentation
4. Gather user feedback

**Medium-term (Weeks 5-8):**
1. Implement Phase 4-6 (health, templates, vault)
2. Comprehensive testing
3. Beta release to early adopters
4. Iterate based on feedback

**Long-term (3-6 months):**
1. Stable release
2. Monitor adoption metrics
3. Gather feature requests
4. Plan potential enhancements

---

## Conclusion

This integration plan provides a clear path to unite dotfiles and dotclaude as complementary products in the Blackwell Systems ecosystem while maintaining their independence. The wrapper-based approach offers:

- **User Value:** Enhanced experience when used together
- **Flexibility:** Both products remain fully functional standalone
- **Maintainability:** Thin integration layer, low overhead
- **Extensibility:** Foundation for future ecosystem products

**Recommendation:** Proceed with implementation starting at Phase 1, validate with users after each phase, and iterate based on feedback.

---

**Document Status:** Draft for Review
**Next Review:** After stakeholder feedback
**Owner:** Blackwell Systems Team
