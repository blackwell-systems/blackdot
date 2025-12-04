# Changelog

All notable changes to this dotfiles repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Vault Command Clarity** - Improved help text to clarify relationship between init and discover
  - Added workflow section showing: First time → init, Re-scan → discover
  - Highlighted that `vault init` includes auto-discovery as part of setup
  - Reduced confusion about command order and purpose
  - Addresses pain-point #1: "Do I run init first or discover first?"

### Added
- **Automatic Backup Before Restore** - Vault restore now auto-creates backup
  - Creates timestamped backup before overwriting any local secrets
  - Shows backup location and restore command
  - Added `dotfiles vault backup` command (exposed existing bin/dotfiles-backup)
  - Eliminates fear of losing local changes during restore
  - Addresses pain-point #2: "No rollback/undo" concern

- **Package Installation Progress** - Setup wizard now shows real-time progress
  - Displays package count before installation
  - Streams brew output with highlighted progress
  - Shows "(X installed)" counter during installation
  - Time estimate maintained: "~5-10 minutes"
  - Addresses pain-point #3: "Is it frozen?" confusion

## [2.3.0] - 2025-12-04

### Fixed
- **Dynamic Path Resolution** - Fixed hardcoded paths in zsh configuration
  - All `dotfiles` commands now work regardless of installation location
  - Introduced `$DOTFILES_DIR` environment variable (auto-detected from config location)
  - Replaced all hardcoded `$HOME/workspace/dotfiles` paths with `$DOTFILES_DIR`
  - Fixed initial path calculation bug (needed :h:h:h not :h:h for 3 directory levels)
  - Fixes issue where commands would fail if dotfiles weren't at exact expected path
  - Fixes "vault/discover-secrets.sh: no such file or directory" error
  - Affects: `40-aliases.zsh`, `50-functions.zsh`, `10-plugins.zsh`, `20-env.zsh`
  - Critical for users who clone dotfiles to custom locations

- **Vault Backend Permissions** - Fixed missing execute permissions on vault backends
  - `vault/backends/bitwarden.sh`, `1password.sh`, `pass.sh` now executable
  - Resolves potential execution failures when directly invoking backends
  - Audit finding: Critical issue resolved

- **Brew Bundle Resilience** - Bootstrap no longer fails on package link conflicts
  - Common issue: npm-installed packages (like `bw`) conflicting with Homebrew versions
  - Auto-detects unlinked packages and attempts to fix with `brew link --overwrite`
  - Bootstrap continues even if some packages have link issues (non-fatal)
  - Provides clear feedback about what was fixed vs what needs manual attention
  - Fixes #UX: "why should it fail just because something is installed already"

- **Homebrew Installation Resilience** - Retry logic for network failures
  - Homebrew installation now retries up to 3 times with exponential backoff (2s, 4s, 8s)
  - Provides helpful error messages on failure (network issues, rate limiting, requirements)
  - Offers option to continue without Homebrew or abort (user choice)
  - Prevents bootstrap failure due to temporary network hiccups
  - Applies to both macOS and Linux (Linuxbrew) installations

- **Brew Bundle Compatibility** - Removed deprecated `--no-lock` flag
  - Fixes "invalid option: --no-lock" error in setup wizard
  - Compatible with Homebrew 5.0+ which removed this flag
  - Setup wizard now works correctly on latest Homebrew versions

- **Homebrew Path Detection** - Use actual installation path after fresh install
  - macOS bootstrap now detects which Homebrew was just installed
  - Directly uses the installation path instead of checking all possible locations
  - Clearer logic: only checks paths after fresh installation
  - Handles Apple Silicon (/opt/homebrew) vs Intel (/usr/local) correctly

### Added
- **Vault Init Command** - New `dotfiles vault init` for easy vault configuration
  - Configure or reconfigure vault backend anytime
  - No need to reset setup state or run full wizard
  - Detects existing configuration and asks to reconfigure
  - Clear guidance when skipping vault setup
  - Accessible via `dotfiles vault init` or `dotfiles vault init --force`

- **Vault Auto-Discovery** - Automatically detect secrets in standard locations
  - New `dotfiles vault discover` command scans for existing secrets
  - Auto-detects SSH keys in ~/.ssh/ (all key types)
  - Discovers AWS configs, Git config, npm, pypi, docker configs
  - Supports custom paths: `--ssh-path` and `--config-path` options
  - Generates vault-items.json automatically with smart naming
  - **Intelligent Merge Logic** - Safely merges with existing config (non-destructive)
    - Preserves manual additions (items not auto-discovered)
    - Preserves manual customizations (e.g., `required: false`)
    - Creates automatic backup before merge
    - Use `--force` to skip merge and overwrite completely
    - Requires `jq` for merge (gracefully falls back if not available)
  - Integrated into `dotfiles vault init` with auto-discover option
  - No more manual JSON editing for standard setups
  - Preview mode with `--dry-run` flag
  - Eliminates biggest UX friction point in vault setup

### Documentation
- **Vault Discover Documentation** - Added comprehensive docs for auto-discovery
  - Documented in root README.md and docs/README-FULL.md
  - Usage examples and integration with vault init
  - Audit finding: Critical documentation gap resolved

- **Brewfile Tier Documentation** - Added BREWFILE_TIER environment variable docs
  - Documented in Prerequisites sections of README.md and README-FULL.md
  - Explains minimal/enhanced/full tier options
  - Shows how to set before bootstrap
  - Audit finding: High-priority documentation gap resolved

### Improved
- **Installation Flow** - Smoother onboarding experience
  - install.sh now prompts "Run setup wizard now? [Y/n]" after installation
  - Automatically loads new shell and runs setup if user confirms
  - No more manual "exec zsh" → "dotfiles setup" dance
  - Minimal mode shows numbered steps for manual configuration

- **Setup Completion** - Context-aware next steps after wizard completes
  - Shows dynamic recommendations based on what was configured
  - Vault configured → Suggests `dotfiles vault restore`
  - Templates configured → Suggests `dotfiles template render`
  - Always shows `dotfiles doctor` for health check
  - Helpful commands and documentation links

- **Setup Progress Indicators** - Shows "Step X of 6" for all wizard phases
  - Clear progress tracking throughout setup wizard
  - Time estimates for long operations (Packages: ~5-10 min)
  - Users always know how far along they are
  - Audit recommendation: High-priority UX improvement implemented

- **Shell Feature Discovery** - Highlights new ZSH features post-setup
  - Setup completion now shows useful shell aliases and tools
  - Conditionally displays features based on what's actually installed
  - Enhanced ls commands (ll, la, lt) with eza
  - Git shortcuts (gst, gd, gco, etc.)
  - Fuzzy search with fzf (Ctrl+R)
  - Smart directory navigation with zoxide (z command)
  - Terminal file manager with yazi (y command)
  - Adapts to minimal/enhanced/full Brewfile tiers
  - Helps users discover what they just installed

- **Vault Schema Validation** - Suggests running validation after vault configuration
  - Setup completion now recommends `dotfiles vault validate`
  - Catches schema errors before attempting restore
  - Audit recommendation: Proactive error prevention

- **Vault Setup UX** - Better experience for configuring and skipping vault
  - Setup wizard now asks "Reconfigure vault?" if already configured
  - Distinguishes between "skipped" vs "configured" in status display
  - Skipped vault shows `[⊘]` icon with hint: "run 'dotfiles vault init'"
  - Configured vault shows backend name in status
  - All skip paths mention how to configure later
  - Fixes UX issue where skipping vault permanently locked you out of configuration

- **macOS /workspace Symlink Handling** - Better guidance for read-only filesystem
  - Detects macOS read-only root filesystem (Catalina+)
  - Provides clear instructions for using synthetic.conf (Apple-approved method)
  - Shows exact commands to create persistent root-level symlink
  - Explains that ~/workspace still works without /workspace symlink
  - No longer shows confusing "fix manually" command that won't work on modern macOS

## [2.2.0] - 2025-12-03

### Added
- **Brewfile Tiers** - Tiered package management for flexible installation sizes
  - `Brewfile.minimal` (~15 packages) - Essentials only (git, zsh, jq, shell plugins)
  - `Brewfile.enhanced` (~40 packages) - Modern CLI tools without containers (fzf, ripgrep, bat, eza)
  - `Brewfile` (~80 packages) - Full install including Docker, Node, advanced tools
  - Control tier with `BREWFILE_TIER=minimal|enhanced|full` environment variable
  - Bootstrap scripts automatically select correct Brewfile based on tier
  - Default tier is "full" (maintains backwards compatibility)
  - Use cases:
    - `minimal` - CI/CD, servers, containers, resource-constrained environments
    - `enhanced` - Developer workstations without container needs
    - `full` - Complete toolkit including Docker/Lima for full-stack development
  - All tiers work on macOS (Homebrew) and Linux (Linuxbrew)
  - macOS-specific casks automatically skipped on Linux

- **Templates Onboarding** - Added interactive template setup to setup wizard
  - New STEP 6 in `dotfiles setup` guides users through template configuration
  - Explains use cases: work vs personal git email, different SSH keys, machine-specific env vars
  - Runs `dotfiles template init` interactively during onboarding
  - Defaults to "No" (opt-in) to keep setup fast for users who don't need templates
  - Shows how to enable later: `dotfiles template init`
  - Integrates with state management system (resume support)
  - Updated README hero section to show complete 6-step flow
  - Makes templates discoverable without forcing complexity

### Changed
- **Modularity Documentation** - Emphasized optional components throughout docs
  - Updated tagline: "Opinionated" → "Modular, batteries-included"
  - Added "Pick What You Want" section to README with Component Matrix
  - Multiple one-line install options shown upfront (Full/Minimal/Custom)
  - Added "Modular Architecture" section to docs/architecture.md
  - Added "Modular Design" section to docs/cli-reference.md
  - Enhanced install.sh help text with modular install instructions
  - Documented all SKIP_* environment variables prominently
  - Updated Docsify coverpage to emphasize modularity
  - Philosophy: "Everything is optional except shell config"

## [2.1.0] - 2025-12-03

### Added
- **Smart Secrets Onboarding** - Intelligent first-time setup for users with existing secrets
  - Detects local secrets (SSH keys, AWS creds, Git config) vs vault items
  - Categorizes as "local only", "vault only", or "synced"
  - Offers to PUSH local secrets to vault for new users migrating their setup
  - Offers to RESTORE from vault for users on new machines
  - Shows sync status for items that exist in both locations
  - `create-vault-item.sh` supports custom file paths for non-standard locations
  - Dramatically improves onboarding for users who already have local credentials
- **Vault Items Configuration File** - User-editable JSON config for vault items
  - `~/.config/dotfiles/vault-items.json` defines SSH keys, vault items, syncable items
  - No more hardcoded organization-specific values in source code
  - `vault/vault-items.example.json` provides template to customize
  - `dotfiles setup` creates config automatically during wizard
  - `require_vault_config()` ensures config exists before vault operations
- **Template CLI Help Improvements** - Better discoverability in `dotfiles template help`
  - Added `list` command to help output (shows available templates with status)
  - Added `{{#each}}` loop syntax to template syntax section
  - Added DOCUMENTATION section with links to docs/templates.md and online guide
- **Template JSON Arrays** - `{{#each}}` loops now support JSON configuration
  - New `templates/_arrays.local.json` for cleaner array definitions
  - `dotfiles template arrays` command to view/manage arrays
  - `dotfiles template arrays --export-json` exports shell arrays to JSON format
  - `dotfiles template arrays --validate` validates JSON syntax
  - Falls back to shell arrays if no JSON file present
- **Docker Container Taxonomy** - Multiple container sizes for different needs
  - `Dockerfile.extralite` (~50MB) - Ultra-minimal for quick exploration
  - `Dockerfile.lite` (~250MB) - Lightweight with vault CLI support (Bitwarden, 1Password, pass)
  - `Dockerfile.medium` (~400MB) - Ubuntu with Homebrew for full dotfiles functionality
  - Added Powerlevel10k shell theme to lite container
  - New `docs/docker.md` documenting all container options
  - Welcome messages on container startup with quick start instructions
- **Mock Vault for Testing** - Test vault commands without real credentials
  - `test/mocks/setup-mock-vault.sh` creates fake GPG key + pass store
  - Populates all expected vault items with mock credentials
  - Works with `pass` backend (`export DOTFILES_VAULT_BACKEND=pass`)
  - Options: `--no-pass` (no passphrase), `--clean` (reset)
- **Minimal Mode Documentation** - Clarified what `--minimal` skips and how to enable features later

### Fixed
- **Bitwarden CLI in Alpine** - Switched to standalone binary to fix ESM compatibility issues
- **Container bootstrap directory** - Fixed missing bootstrap/ in Docker containers
- **Test Suite Compatibility** - Fixed all 76 tests to work with config-based vault items
  - Made `VAULT_CONFIG_FILE` environment variable override-able for tests
  - Installed `jq` in all CI test jobs (was missing)
  - Used absolute paths `/usr/bin/sort` and `/usr/bin/jq` to fix PATH issues in `zsh -c` contexts
  - Fixed zsh PATH variable corruption: renamed `path` → `item_path` in DOTFILES_ITEMS loop
  - Tests now pass: 76/76 (100% pass rate)

## [2.0.1] - 2025-12-02

### Added
- **Help hint for subcommand options** - Main `dotfiles help` now shows: "Run 'dotfiles <command> --help' for detailed options"
- **State Management in Quick Navigation** - Added link to `state-management.md` in docsify homepage

## [2.0.0] - 2025-12-02

### Breaking Changes
- **Removed `dotfiles init` command** - Now use `dotfiles setup` instead
- **Removed `install.sh --interactive` flag** - Bootstrap now prompts to run `dotfiles setup`
- **Renamed `vault/bootstrap-vault.sh`** to `vault/restore.sh` for clarity

### Added
- **Unified Setup Wizard** (`dotfiles setup`) - New interactive setup with persistent state
  - Five-phase setup: symlinks → packages → vault → secrets → claude
  - Progress persistence in `~/.config/dotfiles/state.ini` and `~/.config/dotfiles/config.ini`
  - Resume support: continue where you left off if interrupted
  - State inference: auto-detects existing installations from filesystem
  - Visual status dashboard with checkmarks (`dotfiles setup --status`)
  - Reset capability (`dotfiles setup --reset`)
- **State Management Library** (`lib/_state.sh`) - Pure zsh INI file parsing
  - Functions: `state_init`, `state_completed`, `state_complete`, `state_needs_setup`
  - Config API: `config_get`, `config_set` for persistent preferences
  - State inference: `state_infer` detects symlinks, packages, vault, secrets, Claude
  - Files: `~/.config/dotfiles/state.ini` (phase completion), `~/.config/dotfiles/config.ini` (user prefs)
- **macOS Settings Command** (`dotfiles macos`) - Expose macOS settings management
  - `dotfiles macos apply` - Apply settings from settings.sh
  - `dotfiles macos preview` - Dry-run mode
  - `dotfiles macos discover` - Capture current settings
- **Vault Restore Preview** - `dotfiles vault restore --preview` shows what would be restored without making changes
- **Documentation Updates**
  - New `docs/state-management.md` - Dedicated state system documentation
  - State Management section in `docs/cli-reference.md` with INI file format examples
  - `dotfiles macos` command reference with all subcommands and options
  - Updated all references from `dotfiles init` to `dotfiles setup`
  - Added `macos` command to architecture diagram

### Changed
- **Renamed `bootstrap-vault.sh` to `restore.sh`** - Clearer naming for vault orchestrator
- **Removed `dotfiles init`** - Replaced by `dotfiles setup` with better state management
- **Vault Backend Persistence** - Backend choice now saved to config file
  - Priority: config file → environment variable → default (bitwarden)
  - Persists across sessions without needing to export env var
- **Simplified `install.sh`** - Removed `--interactive` flag
  - Bootstrap scripts now tell user to run `dotfiles setup`
  - Cleaner separation: install.sh handles clone/bootstrap, setup handles configuration
- **dotfiles-drift Multi-Backend Support** - Now works with all vault backends (Bitwarden, 1Password, pass)
  - Uses `lib/_vault.sh` abstraction instead of hardcoded Bitwarden commands
  - Dynamic backend name in messages
  - Backend-specific login hints
- **dotclaude Install URL** - Updated to GitHub raw URL (`raw.githubusercontent.com/blackwell-systems/dotclaude/main/install.sh`)
- **Status Dashboard** - Simplified ASCII art header (dimmed city skyline, no embedded indicators)
- **Post-Install Prompt** - Made `exec zsh` prompt more prominent with yellow highlight

### Fixed
- **Template Engine: `{{#if}}` inside `{{#each}}`** - Conditionals now work correctly inside loops
  - Added `process_loop_conditionals()` function to evaluate loop variables
- **Template Engine: Nested `{{#else}}`** - Fixed stray `{{/if}}` tags in output
  - Properly matches `{{#else}}` at correct nesting depth
- **`pass` Function Name Collision** - Fixed conflict in `dotfiles-setup` between pass CLI and logging function
  - Uses `command pass` to explicitly call the CLI
- **Test: Doctor Claude Detection** - Fixed test failing when real claude installed
  - Test now isolates PATH to exclude system claude

## [1.8.4] - 2025-12-02

### Added
- **dotclaude Integration Documentation** - Comprehensive integration guide (`docs/DOTCLAUDE-INTEGRATION.md`)
  - Architecture diagrams showing system boundaries and data flow
  - Division of responsibilities (dotclaude: profiles, dotfiles: secrets)
  - Usage workflows for multi-client, OSS vs work, multi-machine, and secrets rotation
  - Configuration, troubleshooting, and security best practices
- **Mermaid Diagram Support** - Dark mode compatible diagrams throughout documentation
  - Configured dark theme for better contrast in docs
  - Converted ASCII diagrams to Mermaid in README-FULL
  - Architecture diagrams for multi-platform, workspace, and organizational structure

### Changed
- **Installation Command Pattern** - Replaced confusing `bash -s --` pattern with familiar download-first approach
  - All documentation now uses: `curl -fsSL ... -o install.sh && bash install.sh --interactive`
  - Updated install.sh header comments and --help text
  - Consistent pattern across README, docs, and CLI reference
- **Badge Reorganization** - Improved visual hierarchy in README
  - Moved Zsh badge to row 1 (after Blackwell Systems)
  - Removed duplicate Tests count badge
  - Added dotclaude integration badge
- **Comparison Tables** - Made collapsible for better readability
  - "Quick Comparison: This Repo vs Typical Dotfiles" now collapsible
  - "Why This Repo vs chezmoi?" now collapsible
- **README-FULL Modernization** - Updated architecture diagrams and removed outdated claims
  - Removed "Key Innovation: Portable Claude Code Sessions" marketing language
  - Simplified diagrams for better resolution and readability
  - Directory structure now collapsible with full ASCII tree

### Documentation
- Added dotclaude integration links throughout documentation ecosystem
- Added comprehensive badge set to README-FULL
- Cross-linked dotfiles and dotclaude documentation sites
- Improved feature presentation with code blocks and collapsible sections
- Updated coverpage formatting and Development & Testing section

## [1.8.3] - 2025-12-01

### Added
- **GitHub Sponsors Support** - Added `github: blackwell-systems` to FUNDING.yml
- **Collapsible README Sections** - Made Acknowledgments, Troubleshooting, The dotfiles Command, and Project Structure collapsible for better readability
- **DOTFILES_SKIP_DRIFT_CHECK** documentation - Added missing environment variable to Optional Components

### Changed
- **Vault-Agnostic `dotfiles init`** - Major refactor of interactive setup wizard
  - Auto-detects all vault backends (Bitwarden, 1Password, pass)
  - Prompts user to choose vault (never auto-selects)
  - Option to skip vault setup entirely
  - Backend-specific login/unlock flows
  - Fixes Alpine/Linux issue where pass was auto-selected
- **Integrated `install.sh` with `dotfiles init`** - `install.sh --interactive` now calls the wizard automatically
- **Simplified Quick Start** - Reduced from 4 manual steps to 2 (clone → dotfiles init)
- **Reordered README Sections** - End sections now: Acknowledgments → Trademarks → License
- **Updated Project Structure** - Added lib/_vault.sh and test/fixtures/ subdirectory
- **Removed Bitwarden Bias** - All documentation now vault-agnostic

### Documentation
- Updated README.md, docs/README.md, docs/README-FULL.md with simplified install flow
- Updated docs/cli-reference.md with comprehensive `dotfiles init` documentation
- All install documentation now consistently promotes 2-step flow

## [1.8.2] - 2025-12-01

### Added
- **Test Drive Guide** (`docs/TESTDRIVE.md`) - Comprehensive Docker exploration guide
  - Sample workflows for safe testing
  - dotclaude integration examples
  - FAQ and troubleshooting
- Added "Try Before Installing" section to README with Docker instructions

### Fixed
- Improved template validation tests for better error handling

## [1.8.1] - 2025-12-01

### Fixed
- Template tests now correctly source `_logging.sh` (fixes 3 failing tests)
- Removed misleading codecov badge (shell coverage tracking is unreliable)

## [1.8.0] - 2025-12-01

### Added
- **dotclaude Integration** - Claude Code profile management across machines
  - `dotfiles status` shows active Claude profile (if dotclaude installed)
  - `dotfiles doctor` validates Claude/dotclaude setup with install hints
  - `dotfiles vault` syncs `~/.claude/profiles.json` to vault
  - `dotfiles drift` detects Claude profile changes vs vault
  - `dotfiles packages` suggests dotclaude for Claude users
  - `dotfiles init` offers dotclaude installation during setup wizard
  - See [docs/claude-code.md](docs/claude-code.md#dotclaude-integration) for details
- **Dockerfile.lite** - Lightweight Alpine container for CLI exploration
- **`{{#each}}` Template Loops** - Iterate over arrays with named fields
  - Define `SSH_HOSTS` array in `_variables.local.sh`
  - Use `{{#each ssh_hosts}}...{{/each}}` in templates
  - Access fields: `{{ name }}`, `{{ hostname }}`, `{{ user }}`, `{{ identity }}`, `{{ extra }}`
  - Conditionals work inside loops for optional fields
  - ssh-config.tmpl now generates hosts from SSH_HOSTS array
- **Template Tests** (`test/templates.bats`) - Unit tests for template engine
- **Vault Backend Guide** (`docs/extending-backends.md`) - How to add new vault providers

### Fixed
- **Template Engine: `{{#if}}` inside `{{#each}}`** - Conditionals now work correctly inside loops
  - `{{#if extra}}...{{/if}}` now evaluates loop variables properly
  - Added `process_loop_conditionals()` function to handle loop-scoped conditions
- **Template Engine: Nested `{{#else}}` handling** - Fixed stray `{{/if}}` tags in output
  - Properly matches `{{#else}}` at the correct nesting level
  - No longer grabs nested conditionals' else blocks

## [1.7.0] - 2025-11-29

### Added - Multi-Vault Backend Support

#### Vault Abstraction Layer
- **Multi-vault support** - Choose your preferred secret management backend:
  - **Bitwarden** (`bw`) - Default, full-featured, cloud-synced
  - **1Password** (`op`) - v2 CLI with biometric auth
  - **pass** (`pass`) - GPG-based, git-synced, local-first
- **`lib/_vault.sh`** - Unified vault API with pluggable backends
- **`vault/backends/`** - Backend implementations
  - `bitwarden.sh` - Bitwarden CLI backend
  - `1password.sh` - 1Password CLI v2 backend
  - `pass.sh` - pass (GPG) backend
  - `_interface.md` - Interface specification for backend implementations
- **`DOTFILES_VAULT_BACKEND`** - Environment variable to select backend (defaults to `bitwarden`)

#### Backward Compatibility
- Legacy `bw_*` functions still work (aliased to new `vault_*` API)
- Existing vault items and workflows unchanged
- Session caching unified across backends (`.vault-session`)

### Added - Root Directory Cleanup

#### Consolidated bootstrap/ Directory
- **Moved bootstrap scripts to `bootstrap/`** for cleaner repository root
  - `bootstrap/bootstrap-mac.sh` - macOS setup
  - `bootstrap/bootstrap-linux.sh` - Linux/WSL2/Lima setup
  - `bootstrap/bootstrap-dotfiles.sh` - Symlink creation
  - `bootstrap/_common.sh` - Shared bootstrap functions (already here)

#### Relocated Configuration Files
- **Moved `codecov.yml` to `.github/`** - CI configuration with other GitHub files
- **Moved `claude.local.example` to `claude/`** - Example config with Claude settings
- **Moved `NOTES.md` and `BRAND.md` to `docs/`** - Documentation in docs directory

### Removed
- **`VERSION` file** - Redundant with CHANGELOG.md as source of truth
- **`bootstrap-lima.sh` symlink** - Deprecated alias for bootstrap-linux.sh

### Changed
- Bootstrap scripts updated to find DOTFILES_DIR from parent directory
- `install.sh` updated with new bootstrap script paths
- `Dockerfile` updated with new bootstrap script path
- All CI workflow paths updated for new locations
- Updated all documentation with new paths and project structure

### Documentation
- Updated project structure in README.md, docs/README.md, CLAUDE.md
- Updated Quick Start instructions with new bootstrap paths
- Updated claude.local.example path references

## [1.6.0] - 2025-11-28

### Added - CLI Reorganization

#### bin/ Directory Structure
- **Moved CLI scripts to `bin/`** for cleaner repository root
  - `dotfiles-doctor` - Health validation
  - `dotfiles-drift` - Drift detection
  - `dotfiles-backup` - Backup/restore
  - `dotfiles-diff` - Preview changes
  - `dotfiles-init` - Setup wizard
  - `dotfiles-metrics` - Metrics visualization (renamed from show-metrics.sh)
  - `dotfiles-uninstall` - Clean removal (renamed from uninstall.sh)

### Changed
- Scripts now source `lib/_logging.sh` from `$DOTFILES_DIR/lib/` (parent of bin/)
- `zsh/zsh.d/40-aliases.zsh` updated to reference `bin/` paths
- All test files updated with new paths
- CI/CD workflow updated with new paths
- Removed `.sh` extensions from CLI scripts for cleaner invocation

### Documentation
- Updated project structure in README.md and docs/README.md
- Updated ROADMAP.md to mark CLI reorganization as completed
- Updated CHANGELOG.md with v1.6.0 entry

## [1.5.0] - 2025-11-28

### Added - Offline Mode Support

#### Offline Mode
- **`DOTFILES_OFFLINE=1`** - Skip all Bitwarden vault operations gracefully
  - `is_offline()` - Check if offline mode is enabled
  - `require_online()` - Helper to skip vault operations in offline mode
  - `require_bw()` and `require_logged_in()` - Skip checks in offline mode

#### Use Cases
- Air-gapped environments without Bitwarden access
- Bitwarden service outages
- Development/testing without vault connectivity
- CI/CD pipelines without secrets

### Changed
- `vault/bootstrap-vault.sh` - Exits gracefully with helpful message in offline mode
- `vault/sync-to-bitwarden.sh` - Skips sync with explanation in offline mode
- Updated all documentation with offline mode usage

### Documentation
- Added offline mode to README.md and docs/README.md environment flags
- Added "Air-gapped/Offline" use case to both READMEs
- Updated vault documentation with offline mode examples
- Updated ROADMAP.md - marked offline mode as completed

## [1.4.0] - 2025-11-28

### Added - Bootstrap Consolidation & Safety Features

#### Bootstrap Shared Library
- **`bootstrap/_common.sh`** - Shared bootstrap functions
  - `parse_bootstrap_args()` - Argument parsing (--interactive, --help)
  - `prompt_yes_no()` - Interactive yes/no prompts
  - `run_interactive_config()` - Interactive setup wizard
  - `setup_workspace_layout()` - ~/workspace directory creation
  - `setup_workspace_symlink()` - /workspace symlink setup
  - `link_dotfiles()` - Dotfiles symlinking
  - `run_brew_bundle()` - Homebrew bundle installation
  - `add_brew_to_zprofile()` - Homebrew PATH setup

#### Pre-Restore Drift Check
- **Safety feature** - Prevents accidental data loss during `dotfiles vault restore`
  - Detects when local files have changed since last vault sync
  - Warns user and suggests options: sync first, force restore, or review diff
  - `check_item_drift()` - Check single item for drift
  - `check_pre_restore_drift()` - Check all syncable items
  - `skip_drift_check()` - Check DOTFILES_SKIP_DRIFT_CHECK env var
  - `--force` flag to skip drift check when needed

### Changed
- `bootstrap-mac.sh` - Now sources `bootstrap/_common.sh` for shared functions
- `bootstrap-linux.sh` - Now sources `bootstrap/_common.sh` for shared functions
- `vault/bootstrap-vault.sh` - Added drift check before restore
- Help text updated for `dotfiles vault restore --force`
- Reduced code duplication by ~60% in bootstrap scripts

### Documentation
- Updated `docs/ROADMAP.md` with completed v1.4.0 improvements
- Updated README.md and docs/README.md with new vault restore options
- Added bootstrap/ directory to project structure documentation

## [1.3.0] - 2025-11-28

### Added - Shared Library & Error Tests

#### Shared Logging Library
- **`lib/_logging.sh`** - Centralized logging and color functions
  - Color definitions (RED, GREEN, YELLOW, BLUE, CYAN, MAGENTA, BOLD, NC)
  - Logging functions: `info()`, `pass()`, `warn()`, `fail()`, `dry()`, `debug()`
  - Helper functions: `section()`, `separator()`, `confirm()`
  - Guard against multiple sourcing
  - Works with both bash and zsh

#### Error Scenario Tests
- **`test/error_scenarios.bats`** - 20+ error handling tests
  - Permission denied scenarios
  - Missing file/directory handling
  - Invalid data (corrupted backups, invalid JSON)
  - Vault/session error states
  - Edge cases (empty directories, special characters, symlink loops)
  - CLI argument validation
  - Concurrent operation safety

### Changed
- Scripts now use shared `lib/_logging.sh` instead of inline definitions:
  - `dotfiles-backup.sh`
  - `dotfiles-diff.sh`
  - `dotfiles-drift.sh`
  - `dotfiles-init.sh`
  - `show-metrics.sh`
  - `uninstall.sh`
  - `bootstrap-mac.sh`
  - `bootstrap-linux.sh`
- CI/CD workflow now includes error scenario tests
- Test runner supports `error` mode: `./run_tests.sh error`
- Documentation updated with Windows platform support

### Documentation
- **`docs/ROADMAP.md`** - Future improvements roadmap
  - Prioritized improvement list
  - Design decisions documentation
  - Contributing guidelines for roadmap items

## [1.2.2] - 2025-11-28

### Added - Code Coverage

#### Codecov Integration
- **`codecov.yml`** - Codecov configuration file
  - 60% target coverage for project
  - 50% target coverage for patches
  - Ignores test files, docs, and configs from coverage
  - PR comments with coverage diffs
  - Flags for unit and integration tests

#### CI/CD Coverage Job
- **`.github/workflows/test.yml`** - Added coverage job
  - kcov for shell script coverage collection
  - Separate unit and integration coverage runs
  - Merged coverage reports
  - Automatic upload to Codecov
  - Coverage badge in README

### Changed
- Added Codecov badge to README.md and docs/README.md

## [1.2.1] - 2025-11-28

### Added - Integration Tests

#### Mock Bitwarden CLI
- **`test/mocks/bw`** - Mock Bitwarden CLI for testing
  - Simulates all bw commands (status, get, list, create, etc.)
  - Configurable vault state (locked/unlocked)
  - Uses file-based mock data for predictable results

#### Test Fixtures
- **`test/fixtures/vault-items/`** - Sample vault items
  - SSH-Config, Git-Config, AWS-Config, AWS-Credentials
  - Environment-Secrets
  - Realistic JSON structure matching real Bitwarden items

#### Integration Test Suite
- **`test/integration.bats`** - 20+ integration tests
  - Mock bw CLI validation tests
  - Backup create/list/restore cycle tests
  - Diff preview tests
  - Uninstall dry-run tests
  - Error handling tests
  - End-to-end workflow tests

### Changed
- **`test/run_tests.sh`** - Enhanced test runner
  - Supports `unit`, `integration`, or `all` modes
  - Separate execution of unit vs integration tests
  - Colored output with clear status

- **`.github/workflows/test.yml`** - Added integration test job
  - Separate CI job for integration tests
  - Mock bw CLI setup in CI environment

## [1.2.0] - 2025-11-28

### Added - CLI Commands

#### Unified `dotfiles` Command Expansion
- **`dotfiles diff`** - Preview changes before sync or restore
  - `dotfiles diff --sync` - Show what would be synced to vault
  - `dotfiles diff --restore` - Show what restore would change
  - Unified diff output with color coding

- **`dotfiles backup`** - Backup and restore configuration
  - Creates timestamped tar.gz archives in `~/.dotfiles-backups/`
  - `dotfiles backup` - Create new backup
  - `dotfiles backup --list` - List available backups
  - `dotfiles backup restore` - Interactive restore from backup
  - Auto-cleanup keeps only 10 most recent backups

- **`dotfiles init`** - First-time setup wizard
  - Interactive walkthrough for new installations
  - Guides through bootstrap, Bitwarden setup, secret restoration
  - ASCII art banner and step-by-step progress

- **`dotfiles uninstall`** - Clean removal script
  - `dotfiles uninstall --dry-run` - Preview what would be removed
  - `dotfiles uninstall --keep-secrets` - Remove dotfiles but keep SSH/AWS/Git
  - Safe removal with confirmation prompts

#### Tab Completion
- **`_dotfiles` completion** - Full tab completion for dotfiles command
  - All subcommands with descriptions
  - Vault subcommands with item names
  - Flag completions for all options

### Added - New Scripts
- `dotfiles-backup.sh` - Backup and restore functionality
- `dotfiles-diff.sh` - Preview changes before sync/restore
- `dotfiles-init.sh` - First-time setup wizard
- `uninstall.sh` - Clean removal script

### Added - Documentation
- **Architecture page** (`docs/architecture.md`)
  - Mermaid diagrams for system overview
  - Component architecture diagrams
  - ZSH module load order diagram
  - Vault system sequence diagram
  - Data flow summary table

- **Troubleshooting guide** (`docs/troubleshooting.md`)
  - Quick diagnostics section
  - Installation issues and fixes
  - Shell issues (prompt, completions)
  - Bitwarden/vault issues
  - Permission fixes
  - Platform-specific issues
  - Backup/restore issues

### Added - CI/CD
- **Release workflow** (`.github/workflows/release.yml`)
  - Automated releases on git tag push
  - Changelog generation from commits
  - Archive creation (tar.gz and zip)
  - SHA256 checksums
  - GitHub release with notes

- **Enhanced test coverage**
  - `test/cli_commands.bats` - Tests for all CLI scripts
  - Syntax validation for all new scripts
  - Help flag tests for all commands

### Changed
- Updated `40-aliases.zsh` with new commands (diff, backup, init, uninstall)
- Updated test workflow to validate new scripts
- Updated documentation with new commands and features
- Expanded `dotfiles help` output with all new commands

### Infrastructure
- New scripts made executable with proper permissions
- Tab completion file added to `zsh/completions/`
- Documentation sidebar updated with new pages

## [1.1.0] - 2025-11-27

### Added - Automation & Quality

#### CI/CD Pipeline
- **GitHub Actions Workflow** (`.github/workflows/test.yml`)
  - ShellCheck validation on all scripts (macOS + Linux)
  - Markdown linting for documentation quality
  - Repository structure validation
  - Secrets scanning to prevent accidental commits
  - Cross-platform compatibility testing
  - Documentation completeness checks

#### Pre-commit Hooks
- **ShellCheck Pre-commit Hook** (`.git/hooks/pre-commit`)
  - Automatic validation of all shell scripts before commit
  - Clear error messages with suggestions
  - Prevents broken scripts from being committed

### Added - Metrics & Observability

#### Health Metrics System
- **Automatic Metrics Collection** in `check-health.sh`
  - Records health check results to `~/.dotfiles-metrics.jsonl`
  - Tracks: errors, warnings, fixes, health score (0-100)
  - Includes git branch, commit hash, hostname, OS
  - Timestamped entries for trend analysis

- **Metrics Visualization** (`show-metrics.sh`)
  - Summary view with statistics and recent trend
  - Graph view with ASCII bar chart of health scores
  - All-entries view for detailed history
  - Color-coded health indicators (green/yellow/red)
  - Calculates averages, totals, perfect run percentage

### Added - Developer Experience

#### Improved Upgrade Flow
- **`dotfiles-upgrade` Command** (replaces `dotfiles-update`)
  - One-command upgrade with comprehensive steps:
    1. Pull latest changes from current branch
    2. Re-run bootstrap to update symlinks
    3. Update Homebrew packages from Brewfile
    4. Run health check with auto-fix
  - Clear progress indicators
  - Suggests shell restart after completion

#### Update Notifications
- **Daily Update Checker** in `zshrc`
  - Checks for dotfiles updates once per day
  - Caches check result to avoid slowdown
  - Shows notification with commit count if behind
  - Cross-platform (macOS and Linux)

#### Local Customizations
- **`.zshrc.local` Support**
  - Machine-specific overrides without modifying tracked files
  - Perfect for work laptop vs personal machine differences
  - Automatically sourced if present
  - Added to `.gitignore`

#### Tab Completions
- **ZSH Completion Scripts** (`zsh/completions/`)
  - `_awsswitch` - AWS profile switching with tab completion
  - `_awsset` - AWS profile setting
  - `_awslogin` - AWS SSO login
  - `_bw-sync` - Bitwarden sync with item suggestions
  - `_dotfiles-doctor` - Health check flags
  - `_show-metrics` - Metrics display modes
- Completions automatically loaded on shell startup

### Added - Documentation

- **Multi-Platform Architecture Documentation**
  - Comprehensive "Multi-Platform Architecture" section in README
  - Platform support matrix (macOS, Lima, WSL2, Ubuntu/Debian)
  - Architecture layers diagram (10% platform-specific + 90% shared)
  - Platform-independent components breakdown
  - Guide for adding new platforms (15-30 minutes each)
  - WSL2 auto-detection and Windows interop tools support
  - Renamed `bootstrap-lima.sh` → `bootstrap-linux.sh` (with backward-compatible symlink)
  - Platform detection examples showing auto-detection of WSL/Lima/bare Linux

- **REVIEW.md** (8,700 words)
  - Comprehensive architecture analysis
  - Professional comparison vs FAANG companies
  - Security audit and recommendations
  - Innovation highlights (Claude session portability, vault SSoT)
  - Grade: A+ (96/100)

- **RECOMMENDATIONS.md** (2,500 words)
  - Executive summary and assessment
  - 5 Quick Wins (< 1 hour each)
  - 3 Weekend Projects (CI/CD, metrics, completions)
  - Long-term goals and 30-day action plan
  - Comparison cheatsheet

- **README.md Updates**
  - New "What's New" section
  - "Metrics & Observability" section
  - "CI/CD & Testing" section
  - "Multi-Platform Architecture" section
  - Updated Table of Contents

### Changed

#### Multi-Platform Improvements
- **Renamed `bootstrap-lima.sh` → `bootstrap-linux.sh`** for clarity
  - Now detects WSL2, Lima, or bare Linux automatically
  - Platform-specific setup (WSL: Windows interop tools, Lima: integration notes)
  - Backward-compatible symlink maintained for existing scripts/docs
- **Updated all references** throughout codebase (CI/CD, docs, health checks)
- **Enhanced platform detection** in bootstrap-linux.sh:
  - Detects WSL2 via `/proc/version`
  - Detects Lima via `$LIMA_INSTANCE` environment variable
  - Provides platform-specific tips after installation

#### Refactored Components
- Vault scripts now use shared `_common.sh` library (~50 lines saved per script)
- `dotfiles-update` deprecated in favor of `dotfiles-upgrade`
- Completion system initialization moved earlier in `zshrc`

#### Improved Functionality
- `check-health.sh` now tracks metrics automatically
- `dotfiles-update` shows deprecation warning
- Update checker uses cross-platform date calculation

### Fixed

- SSH key names no longer hardcoded in multiple files
- AWS profile names no longer hardcoded in check-health.sh
- Completion system properly initialized before plugins

### Infrastructure

#### .gitignore Updates
- Added `*.local` to exclude machine-specific overrides
- Added `.dotfiles-update-check` cache file
- Added `.dotfiles-metrics.jsonl` metrics file

#### New Scripts
- `show-metrics.sh` - Health metrics visualization (183 lines)
- `.git/hooks/pre-commit` - ShellCheck validation (54 lines)
- `.github/workflows/test.yml` - CI/CD pipeline (230 lines)

#### Directory Structure
- Created `zsh/completions/` for tab completion scripts
- Created `.github/workflows/` for GitHub Actions

### Security

- Pre-commit hooks prevent committing broken scripts
- GitHub Actions prevents secrets from being committed
- All validation automated and enforced

### Performance

- Completion system optimized (single `compinit` call)
- Update checker runs max once per 24 hours
- Metrics collection is fast and unobtrusive

---

## [1.0.1] - 2024-12-01

### Added
- `vault/_common.sh` - Shared library for all vault scripts (colors, logging, session management)
- `vault/create-vault-item.sh` - Create new Bitwarden secure notes
- `vault/delete-vault-item.sh` - Delete Bitwarden items with safety guards
- `vault/list-vault-items.sh` - List vault items with metadata
- Shell aliases: `bw-restore`, `bw-sync`, `bw-create`, `bw-delete`, `bw-list`, `bw-check`
- Centralized SSH_KEYS and AWS_EXPECTED_PROFILES in `_common.sh` (single source of truth)
- `.gitignore` to exclude `.bw-session` and editor files
- KEY=VALUE validation in `restore-env.sh`

### Changed
- Refactored all vault scripts to use shared `_common.sh` library
- `dotfiles-update` now detects current branch instead of assuming `main`
- `check-health.sh` now sources `_common.sh` for SSH keys and AWS profiles
- Updated `vault/README.md` with comprehensive script documentation

### Fixed
- SSH key names no longer hardcoded in multiple files
- AWS profile names no longer hardcoded in check-health.sh

## [1.0.0] - 2024-11-25

### Added

#### Core Infrastructure
- Cross-platform bootstrap scripts for macOS and Lima (Linux)
- Unified Brewfile for both platforms
- Idempotent bootstrap (safe to run multiple times)

#### Bitwarden Vault System
- `bootstrap-vault.sh` - Orchestrates secret restoration
- `restore-ssh.sh` - Restores SSH keys and config from Bitwarden
- `restore-aws.sh` - Restores AWS config and credentials
- `restore-env.sh` - Restores environment secrets
- `restore-git.sh` - Restores Git config
- `sync-to-bitwarden.sh` - Syncs local changes back to Bitwarden
- `check-vault-items.sh` - Pre-flight validation of vault items

#### Shell Configuration
- Unified zshrc for macOS and Linux (no Oh-My-Zsh dependency)
- Powerlevel10k theme with plugins via Homebrew
- SSH agent auto-start and key auto-loading
- Cross-platform clipboard functions (`copy`/`paste`)
- Claude CLI routing helpers (Bedrock/Max) with SSO pre-flight

#### Health & Maintenance
- `check-health.sh` with `--fix` flag for auto-repairs
- `check-health.sh` with `--drift` flag for local vs Bitwarden comparison
- Comprehensive maintenance checklists in README
- Architecture diagram

#### Modern CLI Tools
- `fzf` - Fuzzy finder with Ctrl+R history search, Ctrl+T file picker
- `eza` - Modern ls replacement with icons, git status, tree view
- `fd` - Fast find alternative (integrates with fzf)
- `ripgrep` - Fast grep alternative (rg)

#### Documentation
- Complete README with all workflows documented
- Table of Contents
- Troubleshooting guide

### Security
- All secret files restored with correct permissions (600/644)
- Atomic session file creation with umask
- Bitwarden session caching with validation

---

## Version History

- **1.0.0** - Initial stable release with full Bitwarden integration
