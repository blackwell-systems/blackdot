# Roadmap & Future Improvements

This document outlines planned improvements and future work for the dotfiles system.

---

## Backlog

### 1. MCP Server for Claude Code Integration

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

### 2. Session Management Improvements

**Status:** Not Started

Improve Bitwarden session handling:
- Sessions cached in `.bw-session` file
- No automatic cleanup of stale sessions
- No session validation retry logic

---

### 3. API/Function Reference Documentation

**Status:** Not Started

Generate documentation for all exported functions:
- `vault/_common.sh` - 27 functions
- `lib/_logging.sh` - 8 functions
- `lib/_state.sh` - 10+ functions
- `lib/_vault.sh` - 15+ functions
- `zsh/zsh.d/50-functions.zsh` - 15+ functions

---

### 4. Plugin System

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

### 5. Module System Refactor

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

### 6. Additional Tool Integrations

**Status:** Consideration

Other integrations to evaluate:

| Tool | Type | Benefit | Status |
|------|------|---------|--------|
| `pyenv` | Lazy-load | Python version manager (~150ms startup) | |
| `kubectl` | Completions + aliases | k8s context/namespace helpers | |
| `terraform` | Completions + aliases | IaC workflows | |
| `direnv` | Auto-load | Per-directory `.envrc` files | |
| `gh` | Completions | GitHub CLI | |

**Decision:** Add as individual features (e.g., `kubectl_integration`, `pyenv_integration`) following the pattern of `nvm_integration` and `sdkman_integration`.

---

### 7. Lazy Loading for Heavy Modules

**Status:** Not Started

Only load modules when first used to improve shell startup time:

```bash
# Stub functions that trigger lazy load
awsswitch() { _load_aws_helpers; awsswitch "$@"; }
```

**Target:** Shell loads in <100ms even with all features enabled.

---

### 8. Developer Tools Meta-Feature

**Status:** Planned

Group all developer tool integrations as a single `dev_tools` meta-feature for easier enable/disable.

**Problem:**
- Users must enable/disable each tool individually (rust_tools, go_tools, python_tools, etc.)
- No single command to enable/disable all developer tooling
- Presets help but don't provide granular "all dev tools" control

**Proposed Feature:** `dev_tools` (meta-feature)

**Commands:**
```bash
dotfiles features enable dev_tools      # Enable all developer tool integrations
dotfiles features disable dev_tools     # Disable all developer tool integrations
```

**Included Features:**
- `aws_helpers`
- `cdk_tools`
- `rust_tools`
- `go_tools`
- `python_tools`
- `ssh_tools`
- `docker_tools`
- `nvm_integration`
- `sdkman_integration`
- `modern_cli`

---

### 9. Template Auto-Discovery

**Status:** Planned

Automatically detect variables from existing config files and generate templates.

**Discovery Command:**
```bash
dotfiles template discover [file]     # Analyze file(s) for variables
dotfiles template discover            # Analyze all known config locations
dotfiles template discover --apply    # Generate template + update variables
```

**Safety Features:**
- Always prompts before writing
- Warns about potential secrets
- Creates backup before overwriting
- `--dry-run` flag for preview
- Shows diff before applying

---

### 10. Template-Vault Integration

**Status:** Planned

Store template variables in vault for cross-machine portability and backup.

**Commands:**
```bash
dotfiles template vault push          # Push _variables.local.sh to vault
dotfiles template vault pull          # Pull from vault to _variables.local.sh
dotfiles template vault sync          # Bidirectional sync with conflict detection
dotfiles template vault diff          # Show differences between local and vault
```

---

### 11. Curl Tools Integration

**Status:** Planned

HTTP request shortcuts, JSON helpers, and API testing utilities.

**Feature:** `curl_tools` (integration category)
**File:** `zsh/zsh.d/67-curl.zsh`

**HTTP Method Shortcuts:**
```bash
GET <url>                     # curl -s <url>
POST <url> [data]             # curl -X POST -d <data>
jget <url>                    # GET with Accept: application/json | jq
jpost <url> <json>            # POST with Content-Type: application/json
```

**API Presets:**
```bash
curl-preset add <name> <base-url> [--header "..."]
curl-preset use <name> <path>
curl-preset list
```

---

### 12. Lima Tools Integration

**Status:** Planned

Lima VM management for running Linux containers on macOS.

**Feature:** `lima_tools` (integration category)
**File:** `zsh/zsh.d/68-lima.zsh`

**VM Management:**
```bash
lls                    # limactl list
lstart [vm]            # limactl start (default: default)
lstop [vm]             # limactl stop
lsh [vm]               # limactl shell
ldocker [cmd]          # lima nerdctl (containerd)
```

---

### 13. Config Schema Validation

**Status:** Planned

Validate config.json structure with helpful error messages.

**Validation Command:**
```bash
dotfiles config validate
# ✓ Config is valid

dotfiles config validate
# ✗ Invalid config:
#   - .vault.backend: "bitwarden_cli" is not valid (expected: bitwarden, 1password, pass)
#   - .features.valt: unknown feature (did you mean: vault?)
```

**Auto-validation:**
- Run on `dotfiles config set` (before saving)
- Run on `dotfiles doctor` (health check)

---

### 14. Aliases Command

**Status:** Planned

Dedicated command to list and search aliases, grouped by category.

**Command:**
```bash
dotfiles aliases                  # List all aliases by category
dotfiles aliases aws              # Show AWS-related aliases
dotfiles aliases search <term>    # Search aliases by name or expansion
```

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
| **2.1.0** | **Smart secrets onboarding, vault config file, Docker taxonomy, Feature Registry** |
| **3.0** | **Configuration Layers, CLI Feature Awareness, JSON config, SSH/Docker Tools, Age Encryption, Shell Completions, Progress Indicators** |

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

*Last updated: 2025-12-07*
