# Roadmap & Future Improvements

This document outlines planned improvements and future work for the dotfiles system.

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

### 2. MCP Server for Claude Code Integration

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

### 3. Session Management Improvements

**Status:** Not Started

Improve Bitwarden session handling:
- Sessions cached in `.bw-session` file
- No automatic cleanup of stale sessions
- No session validation retry logic

---

### 4. API/Function Reference Documentation

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

### 7. Additional Tool Integrations

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

### 8. Lazy Loading for Heavy Modules

**Status:** Not Started

Only load modules when first used to improve shell startup time:

```bash
# Stub functions that trigger lazy load
awsswitch() { _load_aws_helpers; awsswitch "$@"; }
```

**Target:** Shell loads in <100ms even with all features enabled.

---

### 9. Developer Tools Meta-Feature

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

**Implementation Options:**

**Option A: Meta-feature in registry**
```bash
# In lib/_features.sh
["dev_tools"]="false|All developer tool integrations|meta|aws_helpers,cdk_tools,rust_tools,go_tools,python_tools,nvm_integration,sdkman_integration,modern_cli"
```
- New category: `meta` for feature groups
- Enabling/disabling propagates to all child features

**Option B: Feature groups**
```bash
# New array for feature groups
typeset -gA FEATURE_GROUPS=(
    ["dev_tools"]="aws_helpers cdk_tools rust_tools go_tools python_tools nvm_integration sdkman_integration modern_cli"
    ["cloud_tools"]="aws_helpers cdk_tools"
    ["lang_tools"]="rust_tools go_tools python_tools"
)

# New command
dotfiles features group enable dev_tools
dotfiles features group disable lang_tools
```

**Benefits:**
- Single toggle for all dev tooling
- Cleaner onboarding: "Want dev tools? `dotfiles features enable dev_tools`"
- Still allows individual feature control when needed
- Could extend to other groups: `cloud_tools`, `lang_tools`, etc.

---

### 10. Template Auto-Discovery

**Status:** Planned

Automatically detect variables from existing config files and generate templates.

**Discovery Command:**
```bash
dotfiles template discover [file]     # Analyze file(s) for variables
dotfiles template discover            # Analyze all known config locations
dotfiles template discover --apply    # Generate template + update variables
```

**Supported Config Formats:**
| Format | Files | Detection |
|--------|-------|-----------|
| Git config | `~/.gitconfig` | email, name, signingkey, github user |
| SSH config | `~/.ssh/config` | hosts → array, identity files |
| AWS config | `~/.aws/config` | profiles, regions, SSO settings |
| Shell rc | `~/.zshrc`, `~/.bashrc` | exports, paths |

**Pattern Detection:**
```bash
# Automatically detected patterns:
*@*.com, *@*.org           → {{ *_email }}
/home/$USER/*, /Users/*    → {{ home }}/...
[A-F0-9]{16,}              → {{ *_key }} (with secret warning)
192.168.*, 10.*            → {{ *_ip }}
github.com/username        → {{ github_user }}
```

**Safety Features:**
- Always prompts before writing
- Warns about potential secrets
- Creates backup before overwriting
- `--dry-run` flag for preview
- Shows diff before applying

---

### 11. Template-Vault Integration

**Status:** Planned

Store template variables in vault for cross-machine portability and backup.

**Problem:**
- `_variables.local.sh` is gitignored (good)
- But it's only stored locally (bad)
- Lost if machine dies, not synced across machines
- Contains sensitive data (emails, signing keys, tokens)

**Solution:** Vault as the source of truth for template variables.

**Commands:**
```bash
dotfiles template vault push          # Push _variables.local.sh to vault
dotfiles template vault pull          # Pull from vault to _variables.local.sh
dotfiles template vault sync          # Bidirectional sync with conflict detection
dotfiles template vault diff          # Show differences between local and vault
```

**Conflict Resolution:**
```bash
$ dotfiles template vault sync

Comparing local vs vault...

Conflicts detected:
  git_email:
    local: "john@newcompany.com"
    vault: "john@oldcompany.com"

  [1] Keep local (push to vault)
  [2] Keep vault (pull to local)
  [3] Manual merge
  [4] Abort

Choice [1-4]:
```

---

### 12. Curl Tools Integration

**Status:** Planned

HTTP request shortcuts, JSON helpers, and API testing utilities.

**Feature:** `curl_tools` (integration category)
**File:** `zsh/zsh.d/67-curl.zsh`

**HTTP Method Shortcuts:**
```bash
GET <url>                     # curl -s <url>
POST <url> [data]             # curl -X POST -d <data>
PUT <url> [data]              # curl -X PUT -d <data>
PATCH <url> [data]            # curl -X PATCH -d <data>
DELETE <url>                  # curl -X DELETE
HEAD <url>                    # curl -I (headers only)
```

**JSON Helpers:**
```bash
jget <url>                    # GET with Accept: application/json | jq
jpost <url> <json>            # POST with Content-Type: application/json
jput <url> <json>             # PUT JSON
jpatch <url> <json>           # PATCH JSON
```

**API Presets:**
```bash
# Save common API configurations
curl-preset add <name> <base-url> [--header "..."]
curl-preset use <name> <path>
curl-preset list
curl-preset remove <name>
```

---

### 13. Lima Tools Integration

**Status:** Planned

Lima VM management for running Linux containers on macOS.

**Feature:** `lima_tools` (integration category)
**File:** `zsh/zsh.d/68-lima.zsh`

**VM Management:**
```bash
lls                    # limactl list
lstart [vm]            # limactl start (default: default)
lstop [vm]             # limactl stop
lrestart [vm]          # limactl stop && start
lrm [vm]               # limactl delete (with confirmation)
lsh [vm]               # limactl shell
```

**Quick Access:**
```bash
lima                   # Shell into default VM (built-in)
ldocker [cmd]          # lima nerdctl (containerd)
lk                     # Access k3s kubectl in VM
lnerd [cmd]            # lima nerdctl shortcut
```

---

### 14. Age Encryption for Non-Vault Secrets (Priority 1)

**Status:** Planned

Native file encryption using `age` for secrets not managed by vault backends.

**Problem:**
- Vault backends only manage vault items
- Arbitrary files with secrets can't be encrypted
- Files not in vault = unencrypted in repo
- chezmoi has this, we don't

**Feature:** `encryption` (optional category)
**File:** `lib/_encryption.sh`

**Commands:**
```bash
dotfiles encrypt <file>           # Encrypt file with age
dotfiles decrypt <file>           # Decrypt file
dotfiles encrypt-edit <file>      # Decrypt, edit, re-encrypt
dotfiles encrypt-list             # List encrypted files
dotfiles encrypt-init             # Generate age key pair
```

**How it works:**
```bash
# Initialize (one-time)
dotfiles encrypt-init
# Creates ~/.config/dotfiles/age-key.txt (private key, mode 600)
# Creates ~/.config/dotfiles/age-recipients.txt (public keys)

# Encrypt a file
dotfiles encrypt templates/_variables.local.sh
# Creates templates/_variables.local.sh.age
# Original deleted (or moved to .gitignore)

# Decrypt (on this machine or any with the private key)
dotfiles decrypt templates/_variables.local.sh.age
```

**Key Management:**
- Private key stored locally OR synced via vault backend
- Multiple recipients (public keys) for team sharing
- Key stored in Bitwarden/1Password as "Age-Private-Key" item

---

### 15. Shell Completions (Priority 1)

**Status:** Planned

Tab completion for `dotfiles` command and all subcommands.

**Problem:**
- `dotfiles <TAB>` does nothing
- Users must remember subcommand names
- chezmoi has completions, we don't

**Files:**
- `zsh/completions/_dotfiles` - ZSH completion script
- `bash/completions/dotfiles` - Bash completion script

**Completion Support:**
```bash
dotfiles <TAB>
# Shows: backup config doctor drift features hook ...

dotfiles features <TAB>
# Shows: enable disable list preset status

dotfiles features enable <TAB>
# Shows: vault templates hooks aws_helpers cdk_tools ...

dotfiles features preset <TAB>
# Shows: minimal developer claude full

dotfiles vault <TAB>
# Shows: init login logout status sync get list push pull
```

**Dynamic Completions:**
- `features enable/disable` - complete from available features
- `vault get` - complete from vault item names
- `hook run` - complete from registered hook points
- `config get/set` - complete from config keys

---

### 16. Progress Indicators (Priority 2)

**Status:** Planned

Visual progress feedback for long-running operations.

**Problem:**
- `dotfiles packages --install` shows nothing during brew install
- `dotfiles vault sync` gives no feedback during long syncs
- Users don't know if operation is stuck or working

**Implementation Options:**

**Option A: Spinner**
```bash
# lib/_progress.sh

spinner() {
    local pid=$1
    local msg="${2:-Working}"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}${spin:$i:1}${NC} %s..." "$msg"
        i=$(( (i + 1) % ${#spin} ))
        sleep 0.1
    done
    printf "\r"
}
```

**Option B: Progress bar (for countable operations)**
```bash
progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    printf "\r[%s%s] %3d%%" \
        "$(printf '█%.0s' $(seq 1 $filled))" \
        "$(printf '░%.0s' $(seq 1 $empty))" \
        "$percent"
}
```

**Commands to enhance:**
| Command | Progress Type |
|---------|---------------|
| `dotfiles packages --install` | Spinner + item count |
| `dotfiles vault sync` | Spinner |
| `dotfiles vault pull` | Progress bar (N items) |
| `dotfiles backup create` | Spinner + size |
| `dotfiles template render` | Progress bar (N templates) |

---

### 17. Config Schema Validation (Priority 2)

**Status:** Planned

Validate config.json structure with helpful error messages.

**Problem:**
- Typos in config keys silently ignored
- Wrong types cause cryptic failures
- No documentation of valid keys/values

**Validation Command:**
```bash
dotfiles config validate
# ✓ Config is valid

dotfiles config validate
# ✗ Invalid config:
#   - .vault.backend: "bitwarden_cli" is not valid (expected: bitwarden, 1password, pass)
#   - .packages.tier: "medium" is not valid (expected: minimal, enhanced, full)
#   - .features.valt: unknown feature (did you mean: vault?)
```

**Auto-validation:**
- Run on `dotfiles config set` (before saving)
- Run on `dotfiles doctor` (health check)
- Optional: run on shell init (warn only)

---

### 18. Aliases Command (Priority 2)

**Status:** Planned

Dedicated command to list and search aliases, grouped by category.

**Problem:**
- Built-in `alias` command shows raw list
- No grouping or categorization
- Hard to discover aliases for specific tools
- `zsh-you-should-use` helps learn, but need discovery too

**Command:**
```bash
dotfiles aliases                  # List all aliases by category
dotfiles aliases aws              # Show AWS-related aliases
dotfiles aliases search <term>    # Search aliases by name or expansion
dotfiles aliases --raw            # Plain list (for scripting)
```

**Output Format:**
```bash
$ dotfiles aliases

AWS (8 aliases)
  awsprofiles     List AWS profiles
  awsswitch       Switch AWS profile (fzf)
  awswho          Show current identity
  awslogin        SSO login
  ...

CDK (12 aliases)
  cdkd            cdk deploy
  cdks            cdk synth
  cdkdf           cdk diff
  ...

Docker (10 aliases)
  dps             docker ps
  dsh             Shell into container
  ...

Total: 70 aliases
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
| **3.0** | **Configuration Layers, CLI Feature Awareness, JSON config format, SSH/Docker Tools, Color Theming** |

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
