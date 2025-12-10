# Claude Code Session Guidelines

> For user documentation, see [README.md](README.md) or [docs/](docs/)

---

## Architecture Overview

The **Feature Registry** (`lib/_features.sh`) is the control plane for the entire system. Everything flows through it.

```
┌─────────────────────────────────────────────────────────────┐
│                    Feature Registry                          │
│                   (lib/_features.sh)                         │
│                                                              │
│  - Controls what's enabled/disabled                          │
│  - Resolves dependencies between features                    │
│  - Persists state to config.json                            │
│  - Provides presets (minimal, developer, claude, full)       │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
   ┌───────────┐       ┌───────────┐       ┌───────────┐
   │   Shell   │       │   Vault   │       │  Plugins  │
   │  Modules  │       │  System   │       │  (future) │
   └───────────┘       └───────────┘       └───────────┘
```

**Key principle:** New functionality registers as a feature. The registry controls loading.

---

## Adding a New Feature

### 1. Register the feature

In `lib/_features.sh`, add to the `FEATURES` array:

```zsh
FEATURES[my_feature]="optional:My Feature Description:dependency1,dependency2"
#        ^name       ^category ^description          ^dependencies (optional)
```

Categories: `core` (always on), `optional` (user choice), `integration` (external tools)

### 2. Create the feature code

```bash
# lib/_my_feature.sh or bin/blackdot-myfeature

# Guard: only run if feature is enabled
feature_enabled "my_feature" || return 0

# Your feature code here
```

### 3. Add CLI command (if needed)

```bash
# bin/blackdot-myfeature
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../lib/_features.sh"

feature_enabled "my_feature" || {
    echo "Feature 'my_feature' is not enabled"
    echo "Run: blackdot features enable my_feature"
    exit 1
}

# Command implementation
```

### 4. Wire into shell (if needed)

Add to appropriate `zsh/zsh.d/*.zsh` file:

```zsh
# Only load if feature enabled
if feature_enabled "my_feature"; then
    source "${BLACKDOT_DIR}/lib/_my_feature.sh"
fi
```

### 5. Update documentation

- `docs/features.md` - Add feature description
- `docs/cli-reference.md` - Add CLI command (if applicable)

**That's it.** No core changes needed. The registry handles enable/disable, persistence, and presets.

---

## Project Structure

```
dotfiles/
├── lib/                      # Core libraries
│   ├── _features.sh          # Feature Registry (IMPORTANT)
│   ├── _config.sh            # JSON config access
│   ├── _state.sh             # Setup wizard state
│   ├── _logging.sh           # info(), pass(), warn(), fail()
│   └── _vault.sh             # Vault abstraction
├── bin/                      # CLI commands (blackdot-*)
├── zsh/zsh.d/                # Shell modules (00-99 load order)
├── vault/                    # Multi-vault integration
├── templates/                # Machine-specific configs
└── docs/                     # Docsify documentation
```

### Key Files

| File | Purpose |
|------|---------|
| `lib/_features.sh` | Feature Registry - the control plane |
| `lib/_config.sh` | JSON config read/write |
| `lib/_state.sh` | Setup wizard state management |
| `bin/blackdot-features` | Features CLI command |
| `zsh/zsh.d/40-aliases.zsh` | The `dotfiles` command |

---

## Quick Commands

```bash
blackdot features              # List all features
blackdot features enable X     # Enable feature
blackdot features disable X    # Disable feature
blackdot features preset Y     # Apply preset (minimal/developer/claude/full)
blackdot doctor                # Health check
blackdot doctor --fix          # Auto-fix issues
blackdot status                # Visual dashboard
```

---

## Two Config Access Patterns

**Direct access** - For state management (what happened on this machine):
```bash
config_get "setup.completed"   # lib/_config.sh
state_completed "packages"     # lib/_state.sh
```

**Layered access** (future) - For preferences that can vary:
```bash
config_get_layered "vault.backend"  # Checks: env → project → machine → user
```

State management always uses direct access. It tracks machine reality, not preferences.

---

## Coding Standards

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source what you need
source "${BLACKDOT_DIR}/lib/_logging.sh"
source "${BLACKDOT_DIR}/lib/_features.sh"

# Check feature before doing anything
feature_enabled "my_feature" || exit 0

# Use logging functions
info "Starting operation..."
pass "Success"
warn "Warning message"
fail "Error message"
```

---

## Testing

**IMPORTANT:** Before running tests, ensure these tools are available:

```bash
# Check/install zsh (scripts are zsh-based)
which zsh || apt-get install -y zsh

# Check/install shellcheck (static analysis)
which shellcheck || apt-get install -y shellcheck

# Check/install jq (JSON processing)
which jq || apt-get install -y jq

# Install bats (test framework) - use the setup script!
./test/setup_bats.sh
# This installs bats to ~/.local/bin/bats
export PATH="$HOME/.local/bin:$PATH"
```

**Run tests:**
```bash
# All tests
bats test/

# Specific test files
bats test/feature_registry.bats      # 38 tests
bats test/cli_feature_awareness.bats # 30 tests
bats test/config_layers.bats         # 28 tests

# Quick syntax check (no zsh needed)
shellcheck --shell=bash bin/blackdot-*
```

**Test counts (as of 2025-12-05):**
- Feature Registry: 38 tests
- CLI Feature Awareness: 30 tests
- Config Layers: 28 tests
- Total: 140+ tests across all suites

---

## Documentation Updates

When changing features, update:
1. `README.md` - Root documentation
2. `docs/README.md` - Docsify homepage
3. `docs/features.md` - Feature registry docs
4. `docs/cli-reference.md` - CLI commands

---

## Git Rules

- Always `git fetch && git status` before working
- Never `git push --force`
- Use conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`

The repository has hooks that block dangerous git commands.

---

## Design Documents

For planned features, see `docs/design/`:
- `IMPL-plugin-system.md` - Plugin architecture
- `IMPL-hook-system.md` - Lifecycle hooks
- `IMPL-configuration-layers.md` - Layered config

All planned features build on the Feature Registry as their foundation.

---

*Last Updated: 2025-12-05*
