# Roadmap & Future Improvements

This document outlines planned improvements and future work for the dotfiles system.

---

## Recently Completed (v2.0)

### Unified Setup Wizard ✅

**Status:** Complete (v2.0.0)

Single command `dotfiles setup` with:
- Five-phase setup: symlinks → packages → vault → secrets → claude
- Persistent state in `~/.config/dotfiles/config.json` (v3.0 JSON format)
- Resume support if interrupted
- State inference from existing installations

### macOS CLI Integration ✅

**Status:** Complete (v2.0.0)

```bash
dotfiles macos apply              # Apply all settings
dotfiles macos preview            # Dry-run mode
dotfiles macos discover           # Capture current settings
```

---

## Recently Completed (v2.1.0)

### Smart Secrets Onboarding ✅

**Status:** Complete (v2.1.0)

Interactive vault item setup wizard:
```bash
dotfiles vault setup  # Guides first-time vault users
```
- Detects existing local secrets (SSH keys, AWS config, Git config)
- Offers to create vault items for each detected secret
- Validates vault item schema before creation
- Works with any vault backend (Bitwarden, 1Password, pass)

### Vault Items Configuration File ✅

**Status:** Complete (v2.1.0)

User-editable JSON configuration for vault items:
- `~/.config/dotfiles/vault-items.json` for customization
- No need to edit source code to add/remove items
- Created automatically by `dotfiles vault setup`

### Template JSON Arrays ✅

**Status:** Complete (v2.1.0)

JSON configuration support for template arrays:
- `templates/_arrays.local.json` for cleaner SSH host definitions
- `dotfiles template arrays` command to view/manage
- Falls back to shell arrays if no JSON file
- Export existing shell arrays to JSON with `--export-json`

### Docker Container Taxonomy ✅

**Status:** Complete (v2.1.0)

Four container sizes for different use cases:
| Container | Size | Use Case |
|-----------|------|----------|
| `extralite` | ~50MB | Quick CLI exploration |
| `lite` | ~200MB | Vault command testing |
| `medium` | ~400MB | Full CLI + Homebrew |
| `full` | ~800MB+ | Complete environment |

### Mock Vault for Testing ✅

**Status:** Complete (v2.1.0)

Test vault functionality without real credentials:
```bash
./test/mocks/setup-mock-vault.sh --no-pass
```

### Feature Registry ✅

**Status:** Complete (v2.1.0)

Centralized control for all optional features:
```bash
dotfiles features                    # List all features
dotfiles features enable vault       # Enable a feature
dotfiles features disable vault      # Disable a feature
dotfiles features preset developer   # Apply preset (developer, claude, full)
```

- Categories: core, optional, integration
- Dependency resolution (e.g., claude_integration → workspace_symlink)
- Runtime and persistent state via `--persist` flag
- Backward compatible with SKIP_* environment variables

See [Feature Registry](features.md) for full documentation.

### Configuration Layers ✅

**Status:** Complete (v2.1.0)

5-layer priority system for configuration:

```bash
dotfiles config layers           # Show effective config with sources
config_get_layered "vault.backend"  # Layer-aware config access
```

**Layers (highest to lowest priority):**
1. Environment Variables (`$DOTFILES_*`)
2. Project Config (`.dotfiles.local` in project dir)
3. Machine Config (`~/.config/dotfiles/machine.json`)
4. User Config (`~/.config/dotfiles/config.json`)
5. Defaults (built-in)

**Features:**
- `config_get_layered()` function for layer-aware access
- Machine-specific config without editing main config
- Project-level overrides for repository-specific settings
- `dotfiles config layers` shows where each setting comes from

### CLI Feature Awareness ✅

**Status:** Complete (v2.1.0)

Adaptive CLI that adjusts based on enabled features:

```bash
dotfiles help    # Shows only commands for enabled features
dotfiles vault   # Shows enable hint if vault feature disabled
```

**Features:**
- Commands for disabled features hidden from help
- Tab completion excludes disabled feature commands
- Running disabled command shows enable hint
- Feature-to-command mapping in `lib/_cli_features.sh`

---

## Backlog

### 1. Interactive Template Setup

**Status:** Consideration

Add an interactive mode to `dotfiles template init` that prompts for common variables:

```bash
dotfiles template init --interactive
# or make init more interactive by default
```

**Potential prompts:**
- Git name and email
- Machine type (work/personal)
- GitHub username
- AWS profile

**Tradeoffs:**
- **Pro:** Lower barrier for first-time users, no need to understand shell syntax
- **Pro:** Consistent with `dotfiles setup` wizard pattern
- **Con:** Current `init` already opens editor with well-commented example
- **Con:** Most dotfiles users are comfortable editing files

**Decision:** Consider implementing as lightweight prompts for essentials only, then open editor for advanced customization.

---

### 3. MCP Server for Claude Code Integration

**Status:** Concept - Not Started

Create an MCP (Model Context Protocol) server that allows Claude Code to directly interact with dotfiles operations.

**Why:** Currently, Claude interacts with dotfiles via shell commands. An MCP server would provide:
- **Native tool integration** - Claude sees `dotfiles_health_check`, `dotfiles_vault_sync` as first-class tools
- **Structured responses** - JSON responses instead of parsing shell output
- **Proactive actions** - Claude could auto-fix issues during coding sessions

**Proposed MCP Tools:**
```typescript
dotfiles_health_check()     // Returns structured health report
dotfiles_status()           // Quick status with issues count
dotfiles_vault_restore()    // Restore secrets (with drift check)
dotfiles_vault_sync(item?)  // Sync specific or all items
dotfiles_doctor_fix()       // Auto-repair issues
```

**Related:** [MCP Protocol](https://modelcontextprotocol.io/)

---

### 4. Session Management Improvements

**Status:** Not Started

Improve Bitwarden session handling:
- Sessions cached in `.bw-session` file
- No automatic cleanup of stale sessions
- No session validation retry logic

---

### 5. API/Function Reference Documentation

**Status:** Not Started

Generate documentation for all exported functions:
- `vault/_common.sh` - 27 functions
- `lib/_logging.sh` - 8 functions
- `lib/_state.sh` - 10+ functions
- `lib/_vault.sh` - 15+ functions
- `zsh/zsh.d/50-functions.zsh` - 15+ functions

---

### 5. Plugin System

**Status:** Not Started

Allow users to add custom functionality without forking:

```
plugins/
├── available/           # All available plugins
│   └── docker-helpers/
│       ├── plugin.json  # Metadata and dependencies
│       └── docker.zsh   # ZSH module
└── enabled/             # Symlinks to enabled plugins
```

**Commands:**
```bash
dotfiles plugin list              # List available plugins
dotfiles plugin enable <name>     # Enable a plugin
dotfiles plugin disable <name>    # Disable a plugin
dotfiles plugin create <name>     # Scaffold new plugin
```

---

### 6. Module System Refactor

**Status:** Not Started

Refactor ZSH config into independent modules with metadata:

```
modules/
├── core/                # Always loaded
├── optional/            # Loaded if feature enabled
│   └── aws/
│       ├── module.json  # Feature mapping, load order, lazy flag
│       └── aws.zsh
└── local/               # User's custom modules (gitignored)
```

**Features:**
- Module manifests (`module.json`) for metadata
- Feature-to-module mapping
- `dotfiles module` subcommand

---

### 7. Hook System

**Status:** Not Started

Allow users to inject behavior at key lifecycle points:

```bash
# Hook points
HOOK_POINTS=(
    "pre_install" "post_install"
    "pre_bootstrap" "post_bootstrap"
    "pre_vault_pull" "post_vault_pull"
    "pre_doctor" "post_doctor"
    "shell_init" "shell_exit"
)

# User registration (~/.config/dotfiles/hooks.zsh)
hook_register "post_vault_pull" "my_custom_function"
```

---

### 8. Lazy Loading for Heavy Modules

**Status:** Not Started

Only load modules when first used to improve shell startup time:

```bash
# Stub functions that trigger lazy load
awsswitch() { _load_aws_helpers; awsswitch "$@"; }
```

**Target:** Shell loads in <100ms even with all features enabled.

---

## Design Decisions

### Path Convention: `~/workspace/dotfiles`

The system is designed around `~/workspace/dotfiles` as the canonical location:

1. **`/workspace` symlink** enables Claude Code session portability
2. **Install script** clones to `$HOME/workspace/dotfiles`
3. **Documentation** assumes this path

This is intentional, not a limitation. The `/workspace` symlink is core to the portable sessions feature.

**If you need a different location:**
1. Clone to your preferred location
2. Create symlink: `ln -s /your/path /workspace`
3. Update `DOTFILES_DIR` in scripts (not recommended)

---

## Version History

| Version | Focus |
|---------|-------|
| 1.0.0 | Initial release with vault integration |
| 1.1.0 | CLI commands (backup, diff, init, uninstall) |
| 1.2.0 | Integration tests, architecture docs |
| 1.3.0 | Shared library consolidation, error tests |
| 1.4.0 | Bootstrap consolidation, drift check |
| 1.5.0 | Offline mode support |
| 1.6.0 | CLI reorganization (bin/ directory) |
| 1.7.0 | Root directory cleanup |
| 1.8.0 | Windows support, git safety hooks, dotclaude integration |
| **2.0.0** | **Unified setup wizard, state management, macOS CLI** |
| 2.0.1 | CLI help improvements, Docker container enhancements |
| **2.1.0** | **Smart secrets onboarding, vault config file, Docker taxonomy, Feature Registry, Configuration Layers, CLI Feature Awareness** |

---

## Contributing

When implementing improvements from this roadmap:

1. **Create a feature branch** from `main`
2. **Update tests** for any behavioral changes
3. **Update documentation** (README, docs/, CHANGELOG)
4. **Follow commit conventions** (`feat:`, `fix:`, `refactor:`)
5. **Run full test suite** before PR

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

*Last updated: 2025-12-05*
