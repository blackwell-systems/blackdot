# Changelog

All notable changes to this dotfiles repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Blog posts on dotfiles architecture and Claude session portability
- Open source vault system as standalone project
- Additional ZSH completions for more commands

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
  - Updated Table of Contents

### Changed

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
