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

---

## Recently Completed (v3.0)

### Configuration Layers ✅

**Status:** Complete (v3.0)

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

**Status:** Complete (v3.0)

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

**Status:** Complete (v3.0)

See [Hooks Documentation](hooks.md) for full details.

---

### 8. CDK Integration

**Status:** ✅ Implemented (v3.0)

AWS CDK shell integration for infrastructure-as-code workflows.

**Feature:** `cdk_tools` (depends on `aws_helpers`)
**File:** `zsh/zsh.d/61-cdk.zsh`

**Aliases:**
```bash
cdkd          # cdk deploy
cdks          # cdk synth
cdkdf         # cdk diff
cdkw          # cdk watch
cdkls         # cdk list
cdkdst        # cdk destroy
cdkb          # cdk bootstrap
cdkda         # cdk deploy --all
cdkhs         # cdk deploy --hotswap
cdkhsf        # cdk deploy --hotswap-fallback
```

**Helper Functions:**
```bash
cdk-env [profile]    # Set CDK_DEFAULT_ACCOUNT/REGION from AWS profile
cdk-env-clear        # Clear CDK environment variables
cdkall               # Deploy all stacks with confirmation
cdkcheck [stack]     # Diff then prompt to deploy
cdkhotswap [stack]   # Fast deploy for Lambda/ECS updates
cdkoutputs <stack>   # Show CloudFormation stack outputs
cdkinit [lang]       # Initialize new CDK project (default: typescript)
cdkctx               # Show CDK context values
cdkctx-clear         # Clear CDK context cache
cdktools             # Show all CDK commands with status
```

**Status Display:**
- Logo color: green (in CDK project) / cyan (CDK installed) / red (not installed)
- Shows CDK version, project detection, language, and environment variables

**Integration:** Requires `aws_helpers` feature. Included in `developer` and `full` presets.

---

### 9. Additional Tool Integrations

**Status:** Consideration

Other integrations to evaluate:

| Tool | Type | Benefit | Status |
|------|------|---------|--------|
| `ssh` | Config + agent | SSH config, keys, tunnels | See §11 |
| `docker` | Aliases + networking | Container & network management | See §12 |
| `uv` | Aliases + hooks | Python packages, venvs, auto-activation | See §13 |
| `pyenv` | Lazy-load | Python version manager (~150ms startup) | |
| `kubectl` | Completions + aliases | k8s context/namespace helpers | |
| `terraform` | Completions + aliases | IaC workflows | |
| `direnv` | Auto-load | Per-directory `.envrc` files | |
| `gh` | Completions | GitHub CLI | |

**Decision:** Add as individual features (e.g., `kubectl_integration`, `pyenv_integration`) following the pattern of `nvm_integration` and `sdkman_integration`.

---

### 10. Lazy Loading for Heavy Modules

**Status:** Not Started

Only load modules when first used to improve shell startup time:

```bash
# Stub functions that trigger lazy load
awsswitch() { _load_aws_helpers; awsswitch "$@"; }
```

**Target:** Shell loads in <100ms even with all features enabled.

---

### 11. SSH Tools Integration

**Status:** ✅ Implemented (v3.0)

SSH configuration, key management, agent handling, and tunnel utilities.

**Feature:** `ssh_tools` (integration category)
**File:** `zsh/zsh.d/65-ssh.zsh`

**SSH Config Management:**
```bash
sshlist               # List all configured hosts from ~/.ssh/config
sshgo <host>          # Quick connect with host completion
sshedit               # Open SSH config in $EDITOR
sshadd-host <name>    # Interactive wizard to add new host config
```

**SSH Key Management:**
```bash
sshkeys               # List all keys with fingerprints and comments
sshgen <name>         # Generate new ED25519 key with proper permissions
sshcopy <host>        # Copy public key to remote host (ssh-copy-id wrapper)
sshfp [key]           # Show fingerprint(s) in multiple formats
```

**SSH Agent Commands:**
```bash
sshagent              # Start agent if not running, show loaded keys
sshload [key]         # Add key to agent (default: all keys or specific)
sshunload [key]       # Remove key from agent
sshclear              # Remove all keys from agent
```

**SSH Tunnel Helpers:**
```bash
sshtunnel <host> <local> <remote>  # Create port forward
sshsocks <host> [port]             # SOCKS5 proxy through host (default: 1080)
sshtunnels                         # List active SSH tunnels
```

**Help Command:**
```bash
sshtools              # Show all SSH commands with styled help banner
                      # Logo color: green (agent running) / yellow (no keys) / red (no agent)
```

**Tab Completions:**
- `sshgo`: Complete from `~/.ssh/config` hosts
- `sshcopy`: Complete from `~/.ssh/config` hosts
- `sshload`: Complete from `~/.ssh/*.pub` key names
- `sshtunnel`: Complete hosts

**Status Display:**
- Shows SSH agent status (running/stopped, PID)
- Lists loaded keys count
- Shows `~/.ssh/config` host count
- Detects common SSH issues (no keys, agent not running)

**SSH Hooks (Future Enhancement):**

Host-specific pre/post connection hooks for automation and security.

```bash
# Hook management commands
sshhook-add <host> <pre|post> <command>   # Add hook for host
sshhook-list [host]                        # List hooks (all or per-host)
sshhook-remove <host> <pre|post>           # Remove hook
```

**Pre-connect hooks** (run before SSH connection):
- Auto-load specific SSH keys for specific hosts
- VPN connectivity checks (e.g., require VPN for prod servers)
- Environment variable setup
- Notifications/logging for production access

**Post-disconnect hooks** (run after SSH disconnects):
- Clean up port forwards
- Clear sensitive environment variables
- Log session duration for auditing
- Notifications

**Configuration file:** `~/.config/dotfiles/ssh-hooks.json`
```json
{
  "prod-*": {
    "pre": ["vpn-check", "notify 'Connecting to production'"],
    "post": ["notify 'Disconnected from production'"],
    "keys": ["id_ed25519_prod"],
    "tunnels": [{"local": 5432, "remote": 5432}]
  },
  "bastion": {
    "pre": ["sshload id_bastion"],
    "post": ["sshunload id_bastion"]
  }
}
```

**Integration with dotfiles hooks system:**
- `ssh.pre_connect` hook type
- `ssh.post_disconnect` hook type
- Pattern matching for host names (glob support)

---

### 12. Docker Tools Integration

**Status:** ✅ Implemented (v3.0)

Docker container management, compose workflows, and network utilities.

**Feature:** `docker_tools` (integration category)
**File:** `zsh/zsh.d/66-docker.zsh`

**Container Aliases:**
```bash
dps               # docker ps
dpsa              # docker ps -a
di                # docker images
dex               # docker exec -it <container> sh
dl                # docker logs
dlf               # docker logs -f (follow)
dstop             # docker stop
drm               # docker rm
drmi              # docker rmi
```

**Docker Compose:**
```bash
dc                # docker compose
dcu               # docker compose up
dcud              # docker compose up -d
dcd               # docker compose down
dcr               # docker compose restart
dcl               # docker compose logs -f
dcps              # docker compose ps
dcb               # docker compose build
dcex              # docker compose exec
```

**Container Helpers:**
```bash
dsh <container>           # Shell into container (bash → sh fallback)
dip <container>           # Get container IP address
denv <container>          # Show container environment variables
dports                    # Show all containers with exposed ports
dstats                    # Pretty docker stats
dvols                     # List volumes with sizes
dinspect <c> [jq-path]    # Inspect with optional jq filtering
```

**Cleanup Commands:**
```bash
dclean                    # Remove stopped containers + dangling images
dprune                    # docker system prune (interactive)
dprune-all                # Aggressive cleanup (with confirmation)
dnuke                     # Remove ALL containers/images (--confirm required)
```

**Network Commands:**
```bash
dnets                     # List networks with container counts
dnetips                   # Show all container IPs grouped by network
dnetmap                   # Visual map: networks → containers
dnet <network>            # Inspect network (containers, IPs, gateway)
dnetfind <container>      # Which networks is this container on?
dnetcreate <name>         # Create bridge network
dnetconnect <net> <ctr>   # Connect container to network
dnetdisconnect <net> <ctr> # Disconnect container from network
dnetprune                 # Remove unused networks
```

**Network Troubleshooting:**
```bash
dnetping <ctr1> <ctr2>    # Test connectivity between containers
dnetdns                   # Show container DNS resolution
dnetports                 # Show all port mappings across containers
```

**Help Command:**
```bash
dockertools               # Show all Docker commands with styled help
                          # Logo color: green (daemon running) / red (not running)
```

**Status Display:**
- Docker daemon status (running/stopped)
- Running containers count
- Total images and disk usage
- Docker Compose version
- Active networks count

**Tab Completions:**
- `dsh`: Complete from running container names
- `dex`: Complete from running container names
- `dl/dlf`: Complete from container names
- `dnet*`: Complete from network names
- `dnetconnect/dnetdisconnect`: Complete networks and containers

**Example `dnetmap` output:**
```
bridge (default)
  ├── nginx-proxy     172.17.0.2
  └── redis           172.17.0.3

app-network
  ├── api             172.18.0.2
  ├── worker          172.18.0.3
  └── postgres        172.18.0.4

host
  └── monitoring      (host network)
```

---

### 13. UV Tools Integration

**Status:** ✅ Implemented (v3.0) as `python_tools`

Fast Python package manager, project manager, and Python version manager.

**Feature:** `python_tools` (integration category)
**File:** `zsh/zsh.d/64-python.zsh`

See [Developer Tools Documentation](developer-tools.md#python-tools) for full details.

**Implemented:**
- uv aliases: `uvs`, `uvr`, `uva`, `uvad`, `uvrm`, `uvl`, `uvu`, `uvt`, `uvv`, `uvpy`
- pytest aliases: `pt`, `ptv`, `ptx`, `ptxv`, `ptc`, `ptl`, `pts`, `ptk`
- Auto-venv activation on `cd` (configurable: notify/auto/off)
- Helper functions: `uv-new`, `uv-clean`, `uv-info`, `uv-python-setup`, `pt-watch`, `pt-cov`
- `pythontools` command with styled help and status display
- Tab completions for project templates and Python versions

---

### 14. Developer Tools Meta-Feature

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

### 15. Template Auto-Discovery

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

**Example Output:**
```bash
$ dotfiles template discover ~/.gitconfig

Analyzing ~/.gitconfig...

Detected variables:
  [user] email = "john@acme.com"
         └── Suggested: {{ git_email }}
  [user] name = "John Smith"
         └── Suggested: {{ git_name }}
  [user] signingkey = "ABC123DEF456"
         └── Suggested: {{ git_signing_key }}
  [github] user = "johnsmith"
         └── Suggested: {{ github_user }}

Actions:
  [1] Generate template → templates/configs/gitconfig.tmpl
  [2] Add variables → templates/_variables.local.sh
  [3] Preview template
  [4] Skip

Choice [1-4]:
```

**SSH Config Discovery:**
```bash
$ dotfiles template discover ~/.ssh/config

Analyzing ~/.ssh/config...

Detected 5 hosts:
  github       → github.com (git)
  work-server  → server.company.com (deploy)
  bastion      → bastion.company.com (admin)
  prod-db      → db.prod.internal (ubuntu) [via bastion]
  personal-vps → 123.45.67.89 (root)

Actions:
  [1] Generate ssh_hosts array → templates/_arrays.local.json
  [2] Generate template → templates/configs/ssh-config.tmpl
  [3] Preview
  [4] Skip

Choice [1-4]:
```

**Heuristics for Variable Detection:**
- Contains `@` with domain → email
- Path starts with `/home/` or `/Users/` → user-specific path
- Matches hostname of current machine → machine-specific
- Long hex/base64 string → key/token (warn about secrets)
- IP address or internal domain → environment-specific

**Safety Features:**
- Always prompts before writing
- Warns about potential secrets
- Creates backup before overwriting
- `--dry-run` flag for preview
- Shows diff before applying

**Cross-Machine Analysis (Future):**
```bash
# Compare configs from multiple machines
dotfiles template diff-configs work.gitconfig personal.gitconfig

# Output shows which values differ → should be variables
# and which are the same → can be constants
```

---

### 15. Template-Vault Integration

**Status:** Planned

Store template variables in vault for cross-machine portability and backup.

**Problem:**
- `_variables.local.sh` is gitignored (good)
- But it's only stored locally (bad)
- Lost if machine dies, not synced across machines
- Contains sensitive data (emails, signing keys, tokens)

**Solution:** Vault as the source of truth for template variables.

**Vault Item Structure:**
```json
{
  "name": "dotfiles-template-vars",
  "type": "secureNote",
  "notes": {
    "git_name": "John Smith",
    "git_email": "john@acme.com",
    "git_signing_key": "ABC123DEF456",
    "github_user": "johnsmith",
    "machine_type": "work",
    "aws_profile_default": "company-sso"
  }
}
```

**Commands:**
```bash
dotfiles template vault push          # Push _variables.local.sh to vault
dotfiles template vault pull          # Pull from vault to _variables.local.sh
dotfiles template vault sync          # Bidirectional sync with conflict detection
dotfiles template vault diff          # Show differences between local and vault
```

**Workflow Options:**

**Option A: Manual sync (explicit)**
```bash
# After editing variables locally
dotfiles template vault push

# On new machine
dotfiles template vault pull
dotfiles template render
dotfiles template link
```

**Option B: Auto-sync (transparent)**
```bash
# Template render automatically pulls latest from vault
dotfiles template render              # Pulls vars from vault first

# Template edit automatically pushes
dotfiles template edit                # Opens editor, pushes on save
```

**Option C: Vault as direct source (no local file)**
```bash
# Variables resolved directly from vault at render time
# No _variables.local.sh needed
# Requires vault to be unlocked for template operations
```

**Arrays Support:**
```bash
# ssh_hosts array also synced to vault
dotfiles template vault push --include-arrays
dotfiles template vault pull --include-arrays
```

**Vault Item:** `dotfiles-template-arrays`
```json
{
  "ssh_hosts": [
    {"name": "github", "hostname": "github.com", "user": "git"},
    {"name": "work-server", "hostname": "server.company.com", "user": "deploy"}
  ]
}
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

**Integration with existing vault commands:**
```bash
dotfiles vault status
# Shows:
#   Template variables: ✓ synced (last: 2h ago)
#   Template arrays: ✓ synced
#   SSH keys: ✓ synced
#   ...
```

**Security Considerations:**
- Variables with `_key`, `_token`, `_secret` suffix get extra warning
- Option to encrypt sensitive variables separately
- Audit log of variable changes

---

### 16. Curl Tools Integration

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

**Response Formatting:**
```bash
curl-pretty <url>             # Auto-detect JSON/XML, format nicely
curl-headers <url>            # Show response headers only
curl-status <url>             # Show just HTTP status code
curl-time <url>               # Show timing breakdown (DNS, connect, transfer)
```

**Authentication Helpers:**
```bash
curl-bearer <token> <url>     # Authorization: Bearer <token>
curl-basic <user:pass> <url>  # Basic auth
curl-aws <url>                # Use current AWS credentials (sigv4)
```

**Debug & Development:**
```bash
curl-verbose <url>            # Full request/response with timing
curl-save <url> <file>        # Save response body to file
curl-follow <url>             # Follow redirects, show redirect chain
curl-retry <url> [n]          # Retry with exponential backoff (default: 3)
```

**API Presets:**
```bash
# Save common API configurations
curl-preset add <name> <base-url> [--header "..."]
curl-preset use <name> <path>
curl-preset list
curl-preset remove <name>
```

**Example preset usage:**
```bash
# Define preset
curl-preset add github "https://api.github.com" \
    --header "Authorization: token $GITHUB_TOKEN" \
    --header "Accept: application/vnd.github.v3+json"

# Use preset
curl-preset use github /user/repos
curl-preset use github /repos/owner/repo/issues
```

**Preset storage:** `~/.config/dotfiles/curl-presets.json`
```json
{
  "github": {
    "base_url": "https://api.github.com",
    "headers": {
      "Authorization": "token ${GITHUB_TOKEN}",
      "Accept": "application/vnd.github.v3+json"
    }
  },
  "internal-api": {
    "base_url": "https://api.internal.company.com",
    "headers": {
      "X-API-Key": "${INTERNAL_API_KEY}"
    }
  }
}
```

**Help Command:**
```bash
curltools                     # Show all curl commands with styled help
```

**Tab Completions:**
- `curl-preset use`: Complete from saved preset names
- `curl-preset remove`: Complete from saved preset names

---

### 17. Lima Tools Integration

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

**VM Info & Debug:**
```bash
linfo [vm]             # Show VM details (CPU, memory, disk, mounts)
llogs [vm]             # Show VM logs
lip [vm]               # Get VM IP address
lmounts [vm]           # Show mounted directories
ldisk [vm]             # Show disk usage
```

**VM Creation:**
```bash
lnew <name> [template] # Create VM from template
ltemplates             # List available templates
lclone <src> <dst>     # Clone existing VM
```

**Common Templates:**
- `default` - Basic Ubuntu with containerd
- `docker` - Docker CE on Ubuntu
- `k3s` - Lightweight Kubernetes
- `podman` - Podman on Fedora
- `archlinux` - Arch Linux

**Bulk Operations:**
```bash
lstartall              # Start all stopped VMs
lstopall               # Stop all running VMs
lprune                 # Remove stopped VMs (with confirmation)
```

**Help Command:**
```bash
limatools              # Show all Lima commands with styled help
                       # Logo color: green (VM running) / yellow (stopped) / red (not installed)
```

**Status Display:**
- Lima version
- Running VMs count / total
- Default VM status and IP
- Docker/containerd availability in VM
- Mounted directories

**Tab Completions:**
- `lstart/lstop/lsh`: Complete from VM names
- `lrm`: Complete from VM names
- `lnew`: Complete from template names
- `ldocker/lnerd`: Complete docker/nerdctl subcommands

**Integration with Docker tools:**
```bash
# If lima_tools and docker_tools both enabled:
# Auto-detect if Docker is via Lima and adjust commands
docker() {
    if limactl list -q 2>/dev/null | grep -q "^docker$"; then
        lima nerdctl "$@"
    else
        command docker "$@"
    fi
}
```

---

### 18. Age Encryption for Non-Vault Secrets

**Status:** Planned (Priority 1)

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

**Integration:**
```bash
# Auto-decrypt before template rendering
dotfiles template render          # Decrypts .age files first

# Auto-decrypt on vault pull (if key is in vault)
dotfiles vault pull               # Includes age key restoration
```

**Files encrypted by default (suggestions):**
- `templates/_variables.local.sh` → contains emails, signing keys
- `templates/_arrays.local.json` → may contain hostnames/IPs
- Any file matching `*.secret`, `*.private`, `*credentials*`

---

### 19. Shell Completions

**Status:** Planned (Priority 1)

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

dotfiles template <TAB>
# Shows: init render vars arrays validate diff link
```

**Dynamic Completions:**
- `features enable/disable` - complete from available features
- `vault get` - complete from vault item names
- `hook run` - complete from registered hook points
- `config get/set` - complete from config keys

**Installation:**
```bash
# ZSH (automatic if fpath includes zsh/completions)
# Bash
source $DOTFILES_DIR/bash/completions/dotfiles

# Or via package manager integration
brew install dotfiles --with-completions  # future
```

**Implementation:**
```zsh
#compdef dotfiles

_dotfiles() {
    local -a commands
    commands=(
        'backup:Backup and restore operations'
        'config:Configuration management'
        'doctor:Health checks and repairs'
        'features:Feature registry management'
        'hook:Hook management'
        'setup:Interactive setup wizard'
        'status:Show system status'
        'sync:Sync with remote'
        'template:Template operations'
        'vault:Vault operations'
    )

    # Filter by enabled features
    if ! feature_enabled vault 2>/dev/null; then
        commands=("${commands[@]:#vault:*}")
    fi
    # ... etc

    _describe 'command' commands
}
```

---

### 20. Feature Registry Improvements

**Status:** ✅ Implemented (v3.0)

Circular dependency detection and conflict prevention.

**Problem:**
- Circular dependencies could cause infinite loops
- No warning when feature A depends on B depends on A
- No conflict detection (mutually exclusive features)

**Circular Dependency Detection:**
```bash
# In lib/_features.sh, add to dependency resolution:

_detect_circular_deps() {
    local feature="$1"
    local -a visited=("${@:2}")

    # Check if already in visit path = cycle
    if [[ " ${visited[*]} " == *" $feature "* ]]; then
        fail "Circular dependency detected: ${visited[*]} → $feature"
        return 1
    fi

    # Add to path and check deps
    visited+=("$feature")
    local deps="${FEATURE_DEPS[$feature]:-}"
    for dep in ${(s:,:)deps}; do
        _detect_circular_deps "$dep" "${visited[@]}" || return 1
    done
}
```

**Conflict Detection:**
```bash
# New array for mutual exclusions
declare -A FEATURE_CONFLICTS=(
    [pass_vault]="bitwarden_vault,onepassword_vault"
    [bitwarden_vault]="pass_vault,onepassword_vault"
    # etc
)

# Check before enabling
feature_enable() {
    local feature="$1"
    local conflicts="${FEATURE_CONFLICTS[$feature]:-}"
    for conflict in ${(s:,:)conflicts}; do
        if feature_enabled "$conflict"; then
            fail "Cannot enable '$feature': conflicts with enabled feature '$conflict'"
            return 1
        fi
    done
    # ... proceed with enable
}
```

**Validation Command:**
```bash
dotfiles features validate        # Check for cycles and conflicts
dotfiles features graph           # Show dependency graph (ASCII art)
```

---

### 21. Progress Indicators

**Status:** Planned (Priority 2)

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

# Usage
some_long_command &
spinner $! "Installing packages"
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

# Usage
for i in {1..50}; do
    progress_bar $i 50
    do_something
done
```

**Commands to enhance:**
| Command | Progress Type |
|---------|---------------|
| `dotfiles packages --install` | Spinner + item count |
| `dotfiles vault sync` | Spinner |
| `dotfiles vault pull` | Progress bar (N items) |
| `dotfiles backup create` | Spinner + size |
| `dotfiles template render` | Progress bar (N templates) |

**Configuration:**
```json
{
  "ui": {
    "progress": true,
    "colors": true,
    "unicode": true
  }
}
```

---

### 22. Config Schema Validation

**Status:** Planned (Priority 2)

Validate config.json structure with helpful error messages.

**Problem:**
- Typos in config keys silently ignored
- Wrong types cause cryptic failures
- No documentation of valid keys/values

**Schema Definition:**
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "version": { "type": "integer", "minimum": 3 },
    "vault": {
      "type": "object",
      "properties": {
        "backend": { "enum": ["bitwarden", "1password", "pass", null] },
        "auto_sync": { "type": "boolean" },
        "auto_backup": { "type": "boolean" }
      }
    },
    "packages": {
      "type": "object",
      "properties": {
        "tier": { "enum": ["minimal", "enhanced", "full"] }
      }
    },
    "features": {
      "type": "object",
      "additionalProperties": { "type": "boolean" }
    }
  }
}
```

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

**Implementation:**
```bash
# Using ajv-cli or jq-based validation
config_validate() {
    local config="${1:-$CONFIG_FILE}"
    local schema="$DOTFILES_DIR/lib/config-schema.json"

    if command -v ajv >/dev/null 2>&1; then
        ajv validate -s "$schema" -d "$config"
    else
        # Fallback: basic jq-based checks
        _validate_with_jq "$config"
    fi
}
```

**Auto-validation:**
- Run on `dotfiles config set` (before saving)
- Run on `dotfiles doctor` (health check)
- Optional: run on shell init (warn only)

---

### 23. Aliases Command

**Status:** Planned (Priority 2)

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

Rust (15 aliases)
  cb              cargo build
  cbr             cargo build --release
  ct              cargo test
  ...

Go (12 aliases)
  gob             go build
  got             go test
  gomod           go mod tidy
  ...

Git (8 aliases)
  gst             git status
  gco             git checkout
  ...

Docker (10 aliases)
  dps             docker ps
  dsh             Shell into container
  ...

General (5 aliases)
  ll              eza -la
  ...

Total: 70 aliases
```

**Implementation:**
```bash
# bin/dotfiles-aliases

show_aliases() {
    local category="${1:-all}"

    # Source category definitions
    local -A ALIAS_CATEGORIES=(
        [aws]="awsprofiles|awsswitch|awswho|awslogin|awsset|awsunset"
        [cdk]="cdk*"
        [rust]="cb|cbr|ct|cc|cf|cw*|cargo-*"
        [go]="gob|got|gom*|gocover|goinit"
        [docker]="dps|dsh|dex|dl*|drm|dc*|dnet*"
        [git]="gst|gco|gcm|gaa|gp|gl"
    )

    # Get aliases and group
    alias | while read line; do
        # Parse and categorize
        ...
    done
}
```

**Search Feature:**
```bash
$ dotfiles aliases search build
  cb       cargo build
  cbr      cargo build --release
  gob      go build
  dcb      docker compose build
```

**Integration with zsh-you-should-use:**
```bash
$ dotfiles aliases --ysu-stats
# Shows which aliases you use most/least
# Based on zsh-you-should-use reminder frequency
```

---

### 24. Color Theming System

**Status:** ✅ Implemented (v3.0)

Centralized color definitions for consistent theming across all terminal output.

**Problem:**
- Colors hardcoded in 28+ files with local variables
- Each module (awstools, cdktools, rusttools, etc.) defines its own colors
- No single place to change the color scheme
- Inconsistent color usage across commands

**Current State:**
```zsh
# Each module does this independently:
rusttools() {
    local orange='\033[0;33m'
    local red='\033[0;31m'
    local green='\033[0;32m'
    ...
}

gotools() {
    local cyan='\033[0;36m'
    local red='\033[0;31m'
    local green='\033[0;32m'
    ...
}
```

**Solution:** Centralized color theme library.

**File:** `lib/_colors.sh`
```zsh
# ============================================================
# Dotfiles Color Theme
# Source this file to use consistent colors across all modules
# ============================================================

# Semantic colors (what the color means)
export DOTFILES_COLOR_PRIMARY='\033[0;36m'    # cyan - main accent
export DOTFILES_COLOR_SECONDARY='\033[0;33m'  # yellow/orange - secondary accent
export DOTFILES_COLOR_SUCCESS='\033[0;32m'    # green - success/enabled
export DOTFILES_COLOR_ERROR='\033[0;31m'      # red - errors/disabled
export DOTFILES_COLOR_WARNING='\033[0;33m'    # yellow - warnings
export DOTFILES_COLOR_INFO='\033[0;34m'       # blue - informational
export DOTFILES_COLOR_MUTED='\033[2m'         # dim - secondary text
export DOTFILES_COLOR_BOLD='\033[1m'
export DOTFILES_COLOR_NC='\033[0m'            # no color (reset)

# Tool-specific brand colors (optional overrides)
export DOTFILES_COLOR_RUST='\033[0;33m'       # orange (Rust brand)
export DOTFILES_COLOR_GO='\033[0;36m'         # cyan (Go brand)
export DOTFILES_COLOR_PYTHON='\033[0;34m'     # blue (Python brand)
export DOTFILES_COLOR_AWS='\033[0;33m'        # orange (AWS brand)
export DOTFILES_COLOR_CDK='\033[0;32m'        # green (CDK brand)
```

**Usage in modules:**
```zsh
# Before (current)
rusttools() {
    local orange='\033[0;33m'
    local red='\033[0;31m'
    ...
}

# After (themed)
rusttools() {
    source "$DOTFILES_DIR/lib/_colors.sh"
    local logo_color="$DOTFILES_COLOR_RUST"
    local error="$DOTFILES_COLOR_ERROR"
    ...
}
```

**Theme Presets:**
```bash
dotfiles theme                    # Show current theme
dotfiles theme list               # List available themes
dotfiles theme set <name>         # Apply a theme
dotfiles theme preview <name>     # Preview theme colors
```

**Built-in Themes:**
| Theme | Description |
|-------|-------------|
| `default` | Current colors (cyan/green/red/yellow) |
| `nord` | Nord color palette |
| `dracula` | Dracula color palette |
| `solarized` | Solarized dark |
| `monokai` | Monokai colors |
| `minimal` | Muted, low-contrast |

**Custom Themes:**
```bash
# User theme file: ~/.config/dotfiles/theme.sh
DOTFILES_COLOR_PRIMARY='\033[38;5;135m'   # Custom purple
DOTFILES_COLOR_SUCCESS='\033[38;5;114m'   # Custom green
# ... etc
```

**Configuration:**
```json
{
  "ui": {
    "theme": "default",
    "colors": true,
    "unicode": true
  }
}
```

**Migration Path:**
1. Create `lib/_colors.sh` with default colors
2. Update modules to source `_colors.sh` instead of local definitions
3. Add `dotfiles theme` command
4. Document custom theme creation

**Benefits:**
- Single file to change all colors
- Consistent look across all commands
- User-customizable themes
- Brand colors for tool integrations
- Supports 256-color and true color terminals

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
| **3.0** | **Configuration Layers, CLI Feature Awareness, JSON config format** |

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

*Last updated: 2025-12-06*
