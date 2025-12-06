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

**Status:** Planned

SSH configuration, key management, agent handling, and tunnel utilities.

**Feature:** `ssh_tools` (integration category)
**File:** `zsh/zsh.d/64-ssh.zsh`

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

**Status:** Planned

Docker container management, compose workflows, and network utilities.

**Feature:** `docker_tools` (integration category)
**File:** `zsh/zsh.d/65-docker.zsh`

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

**Status:** Planned

Fast Python package manager, project manager, and Python version manager.

**Feature:** `uv_tools` (integration category)
**File:** `zsh/zsh.d/66-uv.zsh`

**Package Aliases:**
```bash
uvi <pkg>             # uv pip install
uviu <pkg>            # uv pip install --upgrade
uva <pkg>             # uv add (to pyproject.toml)
uvad <pkg>            # uv add --dev
uvrm <pkg>            # uv remove
uvs                   # uv sync
uvl                   # uv lock
```

**Run Commands:**
```bash
uvr <script>          # uv run
uvx <tool>            # uv tool run (like npx for Python)
```

**Virtual Environment:**
```bash
uvv [python]          # uv venv (optionally specify Python version)
uvact                 # Activate .venv in current directory
uvdeact               # Deactivate current venv
```

**Python Version Management:**
```bash
uvpy                  # uv python list (show installed)
uvpy-install <ver>    # uv python install 3.12
uvpy-rm <ver>         # uv python uninstall
uvpy-pin <ver>        # uv python pin (set .python-version)
```

**Project Commands:**
```bash
uvinit [name]         # uv init (new project)
uvbuild               # uv build
uvpublish             # uv publish
```

**Tool Management:**
```bash
uvtool <name>         # uv tool install (global CLI tools)
uvtools               # uv tool list
uvtool-up <name>      # uv tool upgrade
uvtool-rm <name>      # uv tool uninstall
```

**Utility Commands:**
```bash
uv-outdated           # Check for outdated dependencies
uv-upgrade            # Upgrade all packages in project
uvcache               # Show cache size and location
uvclean               # uv cache clean
```

**Help Command:**
```bash
uvhelp                # Show all UV commands with styled help
                      # Logo color: green (in venv) / yellow (uv installed) / red (not installed)
```

**Status Display:**
- uv version
- Active virtual environment (if any)
- Python version in use
- Project detection (pyproject.toml present)
- Locked dependencies status

**Tab Completions:**
- `uva/uvrm`: Complete from pyproject.toml dependencies
- `uvpy-install`: Complete from available Python versions
- `uvtool/uvtool-rm`: Complete from installed tools
- `uvr`: Complete from project scripts

**UV Hooks (Auto-activation):**

Automatic virtual environment management when navigating directories.

```bash
# Hook configuration in ~/.config/dotfiles/uv-hooks.json
{
  "auto_activate": true,
  "auto_deactivate": true,
  "create_if_missing": false,
  "show_notifications": true
}
```

**Directory Enter Hook** (`uv.dir_enter`):
- Auto-activate `.venv` when entering directory with `pyproject.toml`
- Optionally create venv if missing (`create_if_missing: true`)
- Show notification: "Activated: myproject (.venv)"

**Directory Leave Hook** (`uv.dir_leave`):
- Auto-deactivate when leaving project directory
- Only if the venv was auto-activated (not manually)

**Post-sync Hook** (`uv.post_sync`):
- Run custom commands after `uv sync`
- Example: regenerate IDE stubs, update pre-commit

**Post-add Hook** (`uv.post_add`):
- Auto-run `uv lock` after `uv add`
- Auto-run `uv sync` to install new dependency

**Configuration file:** `~/.config/dotfiles/uv-hooks.json`
```json
{
  "auto_activate": true,
  "auto_deactivate": true,
  "create_if_missing": false,
  "post_sync": ["pre-commit install --install-hooks"],
  "post_add": ["uv lock", "uv sync"],
  "excluded_dirs": ["~/tmp", "~/Downloads"]
}
```

**Integration with dotfiles hooks system:**
- `uv.dir_enter` - triggered by chpwd hook
- `uv.dir_leave` - triggered by chpwd hook
- `uv.post_sync` - wraps `uv sync` command
- `uv.post_add` - wraps `uv add` command

---

### 14. Template Auto-Discovery

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
