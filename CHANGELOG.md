# Changelog

All notable changes to this dotfiles repository will be documented in this file.

## [Unreleased]

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
- Refactored all vault scripts to use shared `_common.sh` library (~50 lines saved per script)
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
