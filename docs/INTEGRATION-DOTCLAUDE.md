# dotclaude Integration Plan

> **Goal:** Integrate dotclaude with dotfiles as complementary products in the Blackwell Systems ecosystem while maintaining loose coupling and independence.

**Version:** 2.0.0
**Status:** Approved
**Last Updated:** 2025-12-01

---

## Executive Summary

This document outlines the **approved** integration strategy between **dotfiles** (shell configuration and secret management) and **dotclaude** (Claude Code profile management).

### Core Principles

1. **Loose Coupling** - Each product remains fully functional independently
2. **Invisible Integration** - dotfiles becomes "aware" of dotclaude without wrapping it
3. **No New Commands** - Users run `dotclaude` directly; dotfiles just enhances existing commands
4. **One-Command Restore** - `dotfiles vault restore` includes Claude profiles

---

## Architecture: Two Tools, Loosely Connected

```
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│           dotfiles              │     │           dotclaude             │
│  (shell config, secrets, etc)   │     │   (Claude profile management)   │
├─────────────────────────────────┤     ├─────────────────────────────────┤
│                                 │     │                                 │
│  dotfiles status    ───────────────────► shows Claude profile status   │
│  dotfiles doctor    ───────────────────► checks Claude health          │
│  dotfiles vault restore ───────────────► restores profiles.json        │
│                                 │     │                                 │
└─────────────────────────────────┘     └─────────────────────────────────┘
                                              ▲
                                              │
                                        User runs directly:

                                        dotclaude list
                                        dotclaude switch work
                                        dotclaude create personal
                                        dotclaude delete old-profile
                                        (full functionality)
```

### Key Points

- **dotclaude is NOT wrapped or hidden** - users run it directly for all profile management
- **dotfiles just "knows about" dotclaude** - shows status, validates health, syncs profiles
- **No new commands to learn** - existing dotfiles commands just become smarter
- **Full dotclaude access** - all dotclaude functionality remains via `dotclaude` command

---

## What Users Actually Type

| Task | Command | Notes |
|------|---------|-------|
| See overall health | `dotfiles status` | Shows Claude status too |
| Validate setup | `dotfiles doctor` | Checks Claude too |
| Restore on new machine | `dotfiles vault restore` | Restores Claude profiles too |
| **List Claude profiles** | `dotclaude list` | Direct - full access |
| **Switch profiles** | `dotclaude switch work` | Direct - full access |
| **Create profile** | `dotclaude create foo` | Direct - full access |
| **Any dotclaude feature** | `dotclaude <whatever>` | Direct - full access |

---

## Implementation Details

### 1. Enhance `dotfiles status` (50-functions.zsh)

Add Claude profile status with gentle hint if dotclaude not installed:

```bash
# In status() function
local s_profile="${d}·${n}" s_profile_info=""
if command -v dotclaude &>/dev/null; then
  local profile=$(dotclaude active 2>/dev/null)
  if [[ -n "$profile" ]]; then
    s_profile="${g}◆${n}"; s_profile_info="$profile"
  else
    s_profile="${r}◇${n}"; s_profile_info="${d}no active profile${n}"
  fi
elif command -v claude &>/dev/null; then
  # Claude installed but no dotclaude - gentle hint
  s_profile="${d}·${n}"; s_profile_info="${d}try: brew install dotclaude${n}"
fi

# Only show if Claude-related tools present
if [[ -n "$s_profile_info" ]]; then
  echo "  profile    $s_profile  $s_profile_info"
fi
```

**Behavior:**
- Users with dotclaude see their active profile
- Users with Claude but no dotclaude see a gentle install hint
- Users with neither see nothing (no noise)

### 2. Add `dotfiles doctor` section (bin/dotfiles-doctor)

```bash
# Section: Claude Code (Optional)
if command -v claude &>/dev/null; then
  section "Claude Code"
  pass "Claude CLI installed"

  if command -v dotclaude &>/dev/null; then
    pass "dotclaude installed"
    local profile=$(dotclaude active 2>/dev/null)
    if [[ -n "$profile" ]]; then
      pass "Active profile: $profile"
    else
      warn "No active profile - run: dotclaude switch <profile>"
    fi
  else
    info "dotclaude not installed (optional)"
    echo "     Manage Claude profiles across machines with dotclaude:"
    echo "     brew tap blackwell-systems/tap && brew install dotclaude"
  fi
fi
```

This gently suggests dotclaude to Claude users without being pushy.

### 3. Vault includes profiles (vault/_common.sh)

```bash
# Add to SYNCABLE_ITEMS
["Claude-Profiles"]="$HOME/.claude/profiles.json"
```

This enables:
- `dotfiles vault sync Claude-Profiles` - push profiles to vault
- `dotfiles vault restore` - restore profiles on new machine

### 4. Templates set environment variables (templates/configs/99-local.zsh.tmpl)

```bash
{{ if MACHINE_TYPE == "work" }}
export CLAUDE_DEFAULT_BACKEND="bedrock"
export CLAUDE_BEDROCK_PROFILE="{{ AWS_PROFILE_WORK }}"
{{ else }}
export CLAUDE_DEFAULT_BACKEND="max"
{{ endif }}
```

dotclaude reads these environment variables natively. No intermediate config file needed.

---

## Why This Works

| Benefit | How |
|---------|-----|
| **Zero friction** | Users don't learn new commands |
| **Full power** | dotclaude remains fully accessible |
| **Graceful degradation** | Works fine if dotclaude isn't installed |
| **One-command restore** | `dotfiles vault restore` gets complete environment |
| **Invisible when working** | Users just run `claude` and it works |

---

## User Personas

### Persona 1: dotfiles User (No Claude)

- Bootstrap completes normally
- No Claude-specific features visible
- No impact on existing workflow

### Persona 2: Claude User (No dotclaude)

- `dotfiles status` shows gentle hint: `try: brew install dotclaude`
- `dotfiles doctor` suggests dotclaude with install instructions
- Can continue without it - completely optional

### Persona 3: Full Ecosystem User

- `dotfiles status` shows active Claude profile
- `dotfiles doctor` validates Claude setup
- `dotfiles vault restore` restores Claude profiles
- Uses `dotclaude` directly for profile management
- Seamless experience

### Persona 4: New Developer Onboarding

```bash
# One command gets everything
curl -fsSL .../install.sh | bash

# Unlock vault and restore secrets (including Claude profiles)
bw login
export BW_SESSION="$(bw unlock --raw)"
dotfiles vault restore

# Verify setup
dotfiles doctor
# All systems green, including Claude

# Ready to work
dotclaude list
# Shows restored profiles
```

---

## Implementation Summary

| Area | Approach |
|------|----------|
| CLI Pattern | No wrapper - dotclaude used directly |
| Status | Enhanced to show Claude profile |
| Doctor | Enhanced to validate Claude setup |
| Vault | Store/restore `profiles.json` |
| Template | Env vars in `99-local.zsh` |

---

## Alternative Approaches (Rejected)

### Wrapper Commands (`dotfiles claude <cmd>`)

**Rejected because:**
- Creates confusion: "which command do I use?"
- Two ways to do the same thing
- Adds cognitive load

### Plugin Architecture

**Rejected because:**
- Complex plugin infrastructure
- dotclaude loses independence

### Monorepo

**Rejected because:**
- Loss of modularity
- Forced coupling

### No Integration

**Rejected because:**
- Missed opportunity for ecosystem value
- Users must piece together config manually

---

## Backward Compatibility

| User Type | Impact |
|-----------|--------|
| Existing dotfiles users | None - integration is additive |
| Existing dotclaude users | None - no dependency on dotfiles |
| New users | Enhanced experience if using both |

---

**Document Status:** Approved
**Owner:** Blackwell Systems Team
