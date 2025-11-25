# Changelog

All notable changes to this dotfiles repository will be documented in this file.

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
- Comprehensive maintenance checklists in README
- Architecture diagram

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
