# Changelog

All notable changes to this dotfiles repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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

### Planned
- Blog posts on dotfiles architecture and Claude session portability
- Open source vault system as standalone project

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
