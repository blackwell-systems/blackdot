# Changelog

All notable changes to this dotfiles repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [4.0.0-rc2] - 2025-12-10

### Added

- **Windows Support Enhancements**
  - PowerShell hook for blocking dangerous git operations (force push, hard reset)
  - PowerShell git sync check hook
  - Starship prompt configuration for Windows (119 lines)
  - Added Starship to Windows packages (enhanced tier)

- **Enhanced Go Setup Wizard** (internal/cli/setup.go)
  - Windows workspace junction support
  - Cross-platform prompt theme configuration
  - Improved state detection and inference
  - Better error handling and user feedback
  - Expanded from basic implementation to production-ready (356 lines of improvements)

- **Documentation**
  - Comprehensive rebranding strategy document (dotfiles → blackdot)
  - Complete Go setup wizard implementation plan (IMPL-setup-wizard-go.md, 618 lines)
  - Expanded Go refactor documentation with Windows support details
  - Updated hooks README with PowerShell examples

### Changed

- **install.sh** - Now prefers Go binary by default
- **bootstrap-dotfiles.sh** - Enhanced with better p10k handling
- **Brewfile.minimal** - Added age package for encryption support
- **PowerShell module** - Added Windows-specific utilities and helpers

### Fixed

- Release workflow validation now uses Go tests instead of deprecated BATS suite
- Added zsh dependency installation in CI validation step

## [4.0.0-rc1] - 2025-12-09

> **WARNING - Breaking Changes:** This is a major release. The Go binary is now the sole CLI implementation.
> Shell fallback (`DOTFILES_USE_GO=0`) has been removed. Direct calls to `bin/blackdot-*` scripts
> and sourcing `lib/*.sh` libraries will no longer work.

### Known Issues

- BATS test suite migration in progress - old shell script tests temporarily disabled
- Use Go test suite for validation: `go test ./...`
- Full test suite coverage will be restored in v4.0.0 final release

### Changed

- **Phase 3 Migration Complete** - Go binary is now the sole CLI implementation
  - Renamed binary from `dotfiles-go` to `blackdot`
  - Removed shell fallback (`DOTFILES_USE_GO` escape hatch no longer available)
  - Deleted 19 deprecated `bin/blackdot-*` shell scripts (~7,500 lines)
  - Deleted 12 deprecated `lib/*.sh` libraries (~5,500 lines)
  - Simplified `40-aliases.zsh` by removing fallback code (~550 lines)
  - Total reduction: ~13,500 lines of shell code

- **Binary Download Now Default** - `install.sh` downloads Go binary by default
  - No longer need `--binary` flag for recommended install
  - Use `--no-binary` to opt-out if needed
  - Simpler install: `curl -fsSL <url> | bash` now includes binary

### Added

- **Shell Init Command** - New `blackdot shell-init` for shell function initialization
  - Outputs `feature_enabled`, `require_feature`, `feature_exists`, `feature_status` functions
  - Supports zsh, bash, fish, and PowerShell
  - Usage: `eval "$(dotfiles shell-init zsh)"` in shell config
  - Replaces deleted `lib/_features.sh` with Go-backed implementation
  - Updated `00-init.zsh` to use shell-init instead of sourcing deleted libs

- **Cross-Platform CI** - New GitHub Actions workflow for Go testing
  - Tests on ubuntu-latest, macos-latest, windows-latest
  - Builds binaries for all platform/arch combinations
  - PowerShell script validation on Windows
  - Updated test.yml for Go-first testing

- **Checksum Verification** - Binary downloads now verified against SHA256 checksums
  - Automatically downloads `SHA256SUMS.txt` from release
  - Supports both `sha256sum` (Linux) and `shasum` (macOS)
  - Graceful fallback if checksums unavailable
  - Skip with `BLACKDOT_SKIP_CHECKSUM=true` if needed

### Removed

- `bin/blackdot-backup`, `bin/blackdot-config`, `bin/blackdot-diff`
- `bin/blackdot-doctor`, `bin/blackdot-drift`, `bin/blackdot-encrypt`
- `bin/blackdot-features`, `bin/blackdot-hook`, `bin/blackdot-lint`
- `bin/blackdot-metrics`, `bin/blackdot-migrate`, `bin/blackdot-packages`
- `bin/blackdot-setup`, `bin/blackdot-sync`, `bin/blackdot-template`
- `bin/blackdot-uninstall`, `bin/blackdot-vault`
- `lib/_cli_features.sh`, `lib/_config.sh`, `lib/_config_layers.sh`
- `lib/_drift.sh`, `lib/_encryption.sh`, `lib/_errors.sh`
- `lib/_features.sh`, `lib/_paths.sh`, `lib/_progress.sh`
- `lib/_state.sh`, `lib/_templates.sh`, `lib/_vault.sh`

## [3.2.0] - 2025-12-09

### Changed

- **License** - Changed from MIT License to Apache License 2.0
  - LICENSE file updated to Apache License 2.0
  - All documentation and badges updated (README.md, docs/*, CONTRIBUTING.md, etc.)
  - Provides additional patent protection and contributor license terms
  - Code remains free and open source
  - Effective starting with v3.2.0 and all future releases

### Added

- **Phase 2 Shell Switchover Complete** - Go binary is now the primary CLI
  - ZSH `blackdot` function delegates to Go binary when available
  - Shell-only commands (cd, edit) stay in shell
  - Features enable/disable updates both Go config and in-memory shell state
  - Escape hatch: `DOTFILES_USE_GO=0` forces shell implementation
  - Tool group aliases: `sshtools`, `awstools`, `cdktools`, `gotools`, `rusttools`, `pytools`, `dockertools`, `claudetools`
  - Individual hyphenated aliases: `ssh-keys`, `aws-profiles`, `cdk-status`, etc.

- **PowerShell Module Improvements** (v3.1.0)
  - Fixed `d` alias export (now properly exported via New-Alias)
  - Added tool group functions to manifest
  - Full parity with ZSH tool aliases
  - Hook system: 24 hook points, file/function/JSON hooks

- **Windows PowerShell One-Line Installer** - Native Windows onboarding experience
  - New `Install.ps1` bootstrap script for PowerShell users
  - Usage: `irm https://raw.githubusercontent.com/.../Install.ps1 | iex`
  - Features: repo clone, Go binary download, module setup, optional packages
  - Supports presets: `-Preset developer`, `-Preset minimal`, etc.
  - Supports options: `-SkipPackages`, `-SkipBinary`, `-WorkspaceTarget`
  - Matches the `curl | bash` experience for Unix users
  - Git Bash: `install.sh` now prompts to also set up PowerShell module

- **Rollback Command** - Instant rollback to last backup with safety confirmation
  - Go CLI: New `rollback` command with `--to`, `--list`, `-y/--yes` flags
  - ZSH: Fixed `rollback` to handle `--help`, `--list`, added confirmation prompt
  - Both versions now prompt `[y/N]` before restoring (only "y"/"yes" proceeds)
  - Use `-y` flag to skip confirmation for scripts/automation

- **Go CLI Help Styling** - All commands now match ZSH help output exactly
  - Custom `printXxxHelp()` functions for vault, features, doctor, tools, backup, config, encrypt
  - Consistent styling: bold cyan titles, yellow commands, dim descriptions
  - Unknown command error handling matches ZSH: "Unknown command: X" with help hint

- **ZSH encrypt command** - Age encryption now accessible via `blackdot encrypt`
  - Wired `bin/blackdot-encrypt` into the dotfiles() function
  - Added Security section to help output
  - Commands: init, encrypt, decrypt, edit, list, status, push-key

- **Runtime Feature Guards** - All shell tool modules now support instant enable/disable
  - No shell reload required when toggling features with `blackdot features enable/disable`
  - Converted modules: `aws_helpers`, `cdk_tools`, `rust_tools`, `go_tools`, `python_tools`, `docker_tools`, `ssh_tools`, `claude_integration`, `modern_cli`, `nvm_integration`, `sdkman_integration`
  - Pattern: Aliases converted to wrapper functions with `require_feature` guards
  - Blocked commands show helpful message: "Feature 'X' is disabled. Enable with: dotfiles features enable X"
  - Fixed: `set -euo pipefail` removed from `_features.sh` (was killing interactive shells)
  - Fixed: `_logging.sh` now sourced in `00-init.zsh` for `pass`/`fail`/`warn`/`info` functions

- **Cross-Platform Developer Tools** (`blackdot tools`)
  - New `tools` parent command with 8 tool categories
  - All tools work on Linux, macOS, and Windows
  - **Feature Flag Integration** - Tools respect their feature flags like ZSH:
    - `ssh` → `ssh_tools`, `aws` → `aws_helpers`, `cdk` → `cdk_tools`
    - `go` → `go_tools`, `rust` → `rust_tools`, `python` → `python_tools`
    - `docker` → `docker_tools`, `claude` → `claude_integration`
    - Disabled tools show helpful error with enable command
  - **SSH Tools** (`blackdot tools ssh`)
    - `keys` - List SSH keys with fingerprints
    - `gen` - Generate ED25519 key pairs
    - `list` - List configured SSH hosts
    - `agent` - Show SSH agent status
    - `fp` - Show fingerprints in SHA256/MD5 formats
    - `copy` - Copy public key to remote host
    - `tunnel` - Create SSH port forward tunnel
    - `socks` - Create SOCKS5 proxy
    - `status` - Color-coded ASCII art status banner
  - **AWS Tools** (`blackdot tools aws`)
    - `profiles` - List all AWS profiles
    - `who` - Show current AWS identity
    - `login` - SSO login to AWS profile
    - `switch` - Set AWS_PROFILE (prints export command)
    - `assume` - Assume IAM role for cross-account access
    - `clear` - Clear temporary credentials
    - `status` - Color-coded ASCII art status banner
  - **CDK Tools** (`blackdot tools cdk`)
    - `init` - Initialize new CDK project
    - `env` - Set CDK_DEFAULT_ACCOUNT/REGION from AWS profile
    - `env-clear` - Clear CDK environment variables
    - `outputs` - Show CloudFormation stack outputs
    - `context` - Show or clear CDK context
    - `status` - Color-coded ASCII art status banner
  - **Go Tools** (`blackdot tools go`)
    - `new` - Create new Go project with standard structure
    - `init` - Initialize Go module
    - `test` - Run tests with options
    - `cover` - Run tests with coverage report
    - `lint` - Run go vet and golangci-lint
    - `outdated` - Show outdated dependencies
    - `update` - Update all dependencies
    - `build-all` - Cross-compile for all platforms
    - `bench` - Run benchmarks
    - `info` - Show Go environment info
  - **Rust Tools** (`blackdot tools rust`)
    - `new` - Create new Rust project
    - `update` - Update Rust toolchain
    - `switch` - Switch Rust toolchain
    - `lint` - Run cargo check + clippy
    - `fix` - Format and auto-fix with clippy
    - `outdated` - Show outdated dependencies
    - `expand` - Expand macros (for debugging)
    - `info` - Show Rust environment info
  - **Python Tools** (`blackdot tools python`)
    - `new` - Create new Python project with uv
    - `clean` - Clean Python artifacts
    - `venv` - Create virtual environment
    - `test` - Run pytest
    - `cover` - Run pytest with coverage
    - `info` - Show Python environment info
  - **Docker Tools** (`blackdot tools docker`)
    - `ps` - List containers (with `-a` for all)
    - `images` - List Docker images
    - `ip` - Get container IP address
    - `env` - Show container environment variables
    - `ports` - Show all container ports
    - `stats` - Show resource usage (with `-f` for live)
    - `vols` - List volumes
    - `nets` - List networks (with `--inspect` for details)
    - `inspect` - Inspect container with JSON path filtering
    - `clean` - Remove stopped containers and dangling images
    - `prune` - System prune (with `-a` for aggressive)
    - `status` - Color-coded ASCII art status banner
  - **Claude Tools** (`blackdot tools claude`)
    - `status` - Show Claude Code configuration (Bedrock profile, SSO status, paths)
    - `bedrock` - Print export commands for AWS Bedrock backend
    - `max` - Print export commands for Anthropic Max backend
    - `switch` - Interactive backend switcher
    - `init` - Initialize ~/.claude/ from dotfiles templates (hooks, commands, settings)
    - `env` - Show all Claude-related environment variables
    - Full parity with ZSH claude integration (70-claude.zsh)

- **Binary Distribution** (GitHub Releases)
  - Pre-built Go CLI binaries for all platforms
  - Linux: amd64, arm64
  - macOS: amd64 (Intel), arm64 (Apple Silicon)
  - Windows: amd64, arm64
  - SHA256 checksums for all binaries
  - Automated via GitHub Actions on tag push

- **PowerShell Module v1.2.0** (`powershell/`)
  - **Claude tools integration** - Full parity with ZSH and Go CLI
    - `claude-status` - Show Claude Code configuration
    - `claude-bedrock` - Configure AWS Bedrock backend (`-Eval` to set env vars)
    - `claude-max` - Configure Anthropic Max backend (`-Eval` to clear vars)
    - `claude-switch` - Interactive backend switcher
    - `claude-init` - Initialize ~/.claude/ from templates
    - `claude-env` - Show Claude environment variables
    - Aliases: `cb` (claude-bedrock), `cm` (claude-max)

- **PowerShell Module v1.1.0** (`powershell/`)
  - Cross-platform Windows support with **complete ZSH hooks parity**
  - **Full Hook System** (24 hook points - identical to ZSH)
    - Lifecycle: `pre_install`, `post_install`, `pre_bootstrap`, `post_bootstrap`, `pre_upgrade`, `post_upgrade`
    - Vault: `pre_vault_pull`, `post_vault_pull`, `pre_vault_push`, `post_vault_push`
    - Doctor: `pre_doctor`, `post_doctor`, `doctor_check`
    - Shell: `shell_init`, `shell_exit`, `directory_change`
    - Setup: `pre_setup_phase`, `post_setup_phase`, `setup_complete`
    - Template: `pre_template_render`, `post_template_render`
    - Encryption: `pre_encrypt`, `post_decrypt`
  - **Hook Registration Methods**
    - File-based: `~/.config/blackdot/hooks/<point>/*.ps1`
    - Function-based: `Register-DotfilesHook -Point "..." -ScriptBlock {...}`
    - JSON config: Same `hooks.json` format as ZSH
  - **Hook Features**
    - Timeout support via PowerShell Jobs
    - Fail-fast option (`HOOKS_FAIL_FAST`)
    - Verbose mode (`HOOKS_VERBOSE`)
    - Feature gating (checks parent features)
  - **Hook Management Functions**
    - `Register-DotfilesHook` / `Unregister-DotfilesHook`
    - `Invoke-DotfilesHook` (hook_run equivalent)
    - `Get-DotfilesHook` / `Get-DotfilesHookPoints`
    - `Add-DotfilesHook` / `Remove-DotfilesHook` / `Test-DotfilesHook`
  - **Tool Aliases** - 50+ functions wrapping `blackdot tools` commands
    - SSH: `ssh-keys`, `ssh-gen`, `ssh-tunnel`, `ssh-status`
    - AWS: `aws-profiles`, `aws-who`, `aws-login`, `aws-switch`, `aws-status`
    - CDK: `cdk-init`, `cdk-env`, `cdk-outputs`, `cdk-status`
    - Go: `go-new`, `go-test`, `go-lint`, `go-info`
    - Rust: `rust-new`, `rust-lint`, `rust-info`
    - Python: `py-new`, `py-test`, `py-info`
  - **Environment Management** - Proper handling of env vars for `aws-switch`, `aws-assume`, `cdk-env`
  - **Installation Script** - `Install-Dotfiles.ps1` for easy setup
  - Short alias `d` for `blackdot` command

- **Windows Package Management** (`powershell/Install-Packages.ps1`)
  - winget-based package installer (equivalent to `brew bundle`)
  - Three tiers matching Brewfile: `minimal`, `enhanced`, `full`
  - Installs: bat, fd, ripgrep, fzf, eza, zoxide, glow, dust, jq
  - Development: Go, Rust, Python, fnm (Node.js)
  - Cloud: AWS CLI, Bitwarden CLI, 1Password CLI, age
  - Optional: Docker Desktop, VS Code, Windows Terminal
  - Dry-run mode with `-DryRun` flag

- **fnm Integration** (Cross-platform Node.js version manager)
  - Replaces NVM on Windows (NVM is Unix-only)
  - Functions: `fnm-install`, `fnm-use`, `fnm-list`, `Initialize-Fnm`
  - Auto-switches when entering directories with `.nvmrc` or `.node-version`
  - Auto-initialized on module load

- **Zoxide Integration** (Smart directory navigation)
  - Auto-initialized on module load
  - `z` command for jumping to directories
  - `Initialize-Zoxide` for manual init

- **Docker Tools for PowerShell**
  - 12 wrapper functions: `docker-ps`, `docker-images`, `docker-ip`, `docker-env`,
    `docker-ports`, `docker-stats`, `docker-vols`, `docker-nets`,
    `docker-inspect`, `docker-clean`, `docker-prune`, `docker-status`

- **Windows Documentation**
  - `docs/windows-setup.md` - Complete Windows setup guide
  - Updated `powershell/README.md` with all 85+ functions
  - Windows section added to main README

- **Go CLI Complete** - All 11 core commands ported with verified parity
  - `features` - Feature registry management (list, enable, disable, preset)
  - `doctor` - Health checks with ASCII banner
  - `lint` - Syntax validation (55 files)
  - `hook` - Full hook system (list, run, add, remove, test)
  - `encrypt` - Age encryption management
  - `template` - Template rendering with RaymondEngine
  - `vault` - All 8 vault subcommands
  - `diff`, `drift`, `sync` - Vault operations
  - `setup`, `uninstall`, `packages` - Setup wizard
  - Side-by-side testing confirms identical behavior

- **Chezmoi Import Tool** (`blackdot import chezmoi`)
  - Migrate from chezmoi repositories to blackwell-dotfiles
  - Converts Go template syntax to Handlebars automatically
  - Handles chezmoi prefixes: `dot_`, `private_`, `executable_`, `symlink_`, etc.
  - Converts `.chezmoi.os`, `.chezmoi.hostname`, etc. to standard variables
  - Parses chezmoi.toml config for template variables
  - Dry-run mode for previewing changes
  - Verbose mode for detailed progress

- **Vault Create/Delete Commands** (`blackdot vault create|delete`)
  - `vault create <item-name> [content]` - Create new vault items
    - Content from argument, file (`--file`), or stdin
    - Dry-run mode (`-n`) to preview without changes
    - Force mode (`-f`) to overwrite existing items
  - `vault delete <item-name>...` - Delete vault items
    - Bulk deletion of multiple items
    - Protected items (SSH-*, AWS-*, Git-Config) require confirmation
    - Dry-run mode for safe preview
    - Force mode skips confirmation (except protected items)

- **Standard Handlebars Template Syntax** (Phase B)
  - Templates now use standard Handlebars syntax: `{{#if}}`, `{{#unless}}`, `{{#each}}`, `{{/if}}`
  - Bash engine supports both legacy (`{% if %}`) and Handlebars syntax
  - Migrated 4 template files to standard syntax:
    - `templates/configs/99-local.zsh.tmpl`
    - `templates/configs/gitconfig.tmpl`
    - `templates/configs/ssh-config.tmpl`
    - `templates/configs/claude.local.tmpl`
  - All 364 tests passing with new syntax

- **Go Template Engine** (Phase C) (`internal/template/raymond_engine.go`)
  - Raymond-based Handlebars engine for proper AST parsing
  - 15 registered helpers: eq, ne, upper, lower, capitalize, trim, replace, append, prepend, quote, squote, truncate, length, basename, dirname, default
  - Preprocessor converts `{{#else}}` to `{{else}}` for bash template compatibility
  - Variable resolution with `DOTFILES_TMPL_*` environment override
  - Auto-detection of hostname, os, user, home, shell
  - 20 parity tests verifying Go output matches bash output
  - Both engines coexist for safe transition (strangler fig pattern)

- **Go Lint Command** (`internal/cli/lint.go`)
  - Checks ZSH syntax: `zsh/zsh.d/*.zsh`, `zshrc`, `p10k.zsh`
  - Checks Bash syntax: `bootstrap/*.sh`, `vault/*.sh`, `lib/*.sh`
  - Validates config files (Brewfile existence)
  - Runs shellcheck if available (on `bootstrap/*.sh`)
  - Matches bash `dotfiles-lint` output format (55 files checked)
  - `--verbose` and `--fix` flags supported

- **Go Backup Command** (`internal/cli/backup.go`)
  - Create, list, restore, clean subcommands
  - Uses tar.gz compression matching bash format
  - Backup naming: `backup-YYYYMMDD-HHMMSS.tar.gz` (matches bash)
  - Cross-compatible: Can restore bash-created backups
  - Supports both `backup-` and `backup_` naming conventions
  - Finds latest backup by modification time
  - Handles bash wrapper directory format in archives

- **Go Metrics Command** (`internal/cli/metrics.go`)
  - JSONL metrics visualization from `~/.blackdot-metrics.jsonl`
  - Three modes: summary (default), `--graph` (ASCII bar chart), `--all` (full list)
  - Statistics: average score, total errors/warnings/fixed, perfect runs %
  - Trend analysis: compares last 5 vs previous 5 health checks
  - Platform distribution display
  - Color-coded output matching bash behavior

- **Go Uninstall Command** (`internal/cli/uninstall.go`)
  - `--dry-run/-n`: Preview what would be removed
  - `--keep-secrets/-k`: Preserve SSH/AWS/Git configs
  - Removes symlinks: `.zshrc`, `.p10k.zsh`, ghostty config, `.claude`
  - Removes config files: metrics file, backups directory
  - Interactive confirmation for secrets and repository deletion
  - Output matches bash implementation exactly

- **Go Status Command** (`internal/cli/status.go`)
  - City skyline ASCII art visual dashboard
  - Checks symlink status (zshrc, claude, /workspace)
  - SSH keys loaded count
  - AWS authentication status
  - Lima VM status (macOS only)
  - Claude profile detection (dotclaude integration)
  - Suggested fixes for any detected issues

- **Go Packages Command** (`internal/cli/packages.go`)
  - `--check/-c`: Show what's missing from Brewfile
  - `--install/-i`: Install missing packages via brew bundle
  - `--outdated/-o`: Show outdated Homebrew packages
  - `--tier/-t`: Select tier (minimal/enhanced/full)
  - Tier priority: flag > config.json > BREWFILE_TIER env > default
  - Parses Brewfile for formulas and casks
  - Compares against installed packages

- **Go Drift Command** (`internal/cli/drift.go`)
  - `--quick/-q`: Fast check against cached state (no vault access)
  - Full mode: Connects to vault and compares current contents
  - SHA256 checksums for reliable drift detection
  - Reads cached state from `~/.cache/dotfiles/vault-state.json`
  - Tracks: SSH, AWS, Git configs, env secrets, template variables

- **Go Diff Command** (`internal/cli/diff.go`)
  - `--sync/-s`: Preview what sync would push to vault
  - `--restore/-r`: Preview what restore would change locally
  - Item-specific diff: `diff SSH-Config`, `diff Git-Config`, etc.
  - Color-coded unified diff output with line limits
  - Session validation with helpful unlock instructions

- **Go Hook Command** (`internal/cli/hook.go`)
  - Subcommands: list, run, add, remove, points, test
  - 7 hook categories: Lifecycle, Vault, Doctor, Shell, Setup, Template, Encryption
  - 23 hook points with descriptions
  - File-based hooks: `~/.config/blackdot/hooks/<point>/*.sh`
  - JSON-configured hooks: `~/.config/blackdot/hooks.json`
  - Timeout support and fail-fast option
  - Verbose mode for debugging hook execution

- **Go Encrypt Command** (`internal/cli/encrypt.go`)
  - Subcommands: init, file, decrypt, edit, list, status, push-key
  - Age encryption (age-keygen, age) for secure file storage
  - `--keep/-k`: Keep original when encrypting/decrypting
  - `--dry-run/-n`: Preview what would be done
  - `--force/-f`: Force key regeneration
  - Pattern matching for files that should be encrypted
  - Vault integration for key backup/recovery

- **Go Doctor Command** (`internal/cli/doctor.go`)
  - 10 check sections: Version, Core Components, Required Commands, SSH, AWS, Vault, Shell, Claude, Templates
  - Health score calculation (0-100) with color-coded interpretation
  - `--fix/-f`: Auto-fix permission issues (SSH keys, AWS credentials)
  - `--quick/-q`: Fast checks only (skip vault status)
  - Failed checks and warnings tracking with fix suggestions
  - Metrics saving to `~/.blackdot-metrics.jsonl`
  - Banner with ASCII art matching bash implementation

- **Go Sync Command** (`internal/cli/sync.go`)
  - Bidirectional vault sync with smart direction detection
  - `--dry-run/-n`: Preview changes without making them
  - `--force-local/-l`: Push all local changes to vault
  - `--force-vault/-v`: Pull all vault content to local
  - `--verbose`: Show detailed checksum comparison
  - SHA256 checksums for reliable change detection
  - Drift state tracking for baseline comparison
  - Updates config timestamps after successful sync

- **Go Setup Command** (`internal/cli/setup.go`)
  - Full 7-phase interactive setup wizard in Go
  - `--status/-s`: Show current setup status without running wizard
  - `--reset/-r`: Reset state and re-run setup from beginning
  - State inference: auto-detects existing installations from filesystem
  - Progress bars with Unicode visualization (█░)
  - Phase completion persistence to config.json
  - Feature preset selection (minimal/developer/claude/full)
  - Next steps guidance based on configuration
  - Vault backend detection (bitwarden, 1password, pass)
  - Claude/dotclaude integration detection
  - Template system detection

- **Interactive Template Setup** (`blackdot template init`)
  - Prompts for essential variables: git name, email, machine type, GitHub username
  - Auto-detects defaults from `git config --global`
  - Machine type choice menu with detected value highlighted
  - Generates `_variables.local.sh` with user's values pre-filled
  - Offers editor for advanced configuration after essentials
  - Replaces "copy example file and edit" workflow with guided setup

- **Template-Vault Integration** (`blackdot template vault`)
  - Push/pull template variables to/from vault for cross-machine portability
  - `vault push` - Backup local config to vault
  - `vault pull` - Restore config from vault on new machines
  - `vault diff` - Show differences between local and vault
  - `vault sync` - Bidirectional sync with conflict detection
  - `vault status` - Show sync status at a glance
  - Supports all vault backends (bitwarden, 1password, pass)
  - Automatic backup on pull, conflict resolution options

- **Short alias `d` for `blackdot` command**
  - Quick access: `d status`, `d doctor`, `d features`, etc.

- **macOS Settings Command** (`blackdot macos`) - Go CLI
  - Full parity with ZSH `blackdot macos` command
  - `apply` - Apply settings from macos/settings.sh
  - `preview` - Dry-run showing what would change
  - `discover` - Discover current macOS settings (with `--generate`, `--snapshot`, `--compare`)
  - Feature-gated: Requires `macos_settings` feature enabled
  - Only shows in help output on Darwin systems
  - Wraps existing shell scripts in `macos/` directory

### Fixed

- **Go CLI error handling** (`internal/cli/root.go`)
  - Fixed: All errors were showing "Unknown command: tools" instead of actual error message
  - Now correctly distinguishes between "unknown command/flag" errors and execution errors
  - Execution errors show the actual error message with `[ERROR]` prefix

- **Config get/show/source for arbitrary keys** (`internal/cli/config.go`)
  - Fixed: `config get test.key` returned empty even when `config set user test.key hello` succeeded
  - Root cause: Used `cfg.Get()` which only knew predefined keys (vault.*, features.*)
  - Fix: Use `getFromJSONFile()` to read arbitrary nested keys from config layers

- **Age encryption in minimal tier**
  - Added `age` to `Brewfile.minimal` - required for `blackdot encrypt` feature
  - Added `FiloSottile.age` to Windows `$MinimalPackages` in `Install-Packages.ps1`

- **PowerShell `d` alias not exported**
  - Fixed: Alias was created with `-Scope Global` which prevented export
  - Changed to `New-Alias` in module scope for proper export via `Export-ModuleMember`

- **Vault session caching** (`blackdot vault unlock/status`)
  - Fixed: `vault status` always showing "Not authenticated" even after successful unlock
  - Root cause: Bitwarden CLI's `--session` argument doesn't work reliably; must use `BW_SESSION` env var
  - Fix: Updated vaultmux v0.3.1 to use `BW_SESSION` environment variable instead of `--session` CLI argument
  - Session token now properly persisted to JSON cache file and validated on status check

- **Go CLI exit codes and flag validation** (edge case testing)
  - `diff`: Now returns non-zero exit code when vault is not unlocked
  - `diff`: Added mutual exclusion check - `--sync` and `--restore` cannot be used together
  - `encrypt status`: Now returns non-zero exit code when age is not installed or encryption not initialized

- **Nested `{{#if}}` block extraction bug** (`lib/_templates.sh`)
  - Fixed stray `}` character appearing in output when using nested conditionals
  - Root cause: Two bugs in `process_conditionals` function:
    1. Line 917: Extra `}` in pattern match was being concatenated as literal
    2. Lines 935-938: Missing `{{/if}}` preservation in elif branch
  - Templates like `A{{#if x}}B{{#if y}}C{{/if}}D{{/if}}E` now correctly produce `ABCDE`
  - All nested conditional test cases pass

- **Machine type preservation in template system**
  - User-set `TMPL_AUTO[machine_type]` in `_variables.local.sh` was being overwritten by auto-detection
  - Fixed variable loading order: now loads user files before auto-detection
  - `build_auto_vars()` now preserves existing user-set values

---

## [3.1.0] - 2025-12-06

### Added

- **Developer Tools Documentation** (`docs/developer-tools.md`)
  - Comprehensive 400+ line guide covering AWS, CDK, Rust, Go, NVM, SDKMAN integrations
  - All aliases and helper commands documented with examples
  - Example workflows for each tool suite
  - Feature flags for enabling/disabling tool integrations
  - Added to Docsify coverpage, sidebar, and README Quick Navigation

- **ZSH Hooks Documentation** (`docs/hooks.md`)
  - New "Understanding ZSH Hooks" section explaining native ZSH hook functions
  - Coverage of `precmd_functions`, `preexec_functions`, `chpwd_functions`, `zshexit_functions`, `periodic_functions`, `zshaddhistory_functions`
  - Common patterns: auto-venv activation, command timing, history filtering
  - How dotfiles hooks map to native ZSH mechanisms
  - Performance considerations and best practices
  - Using native ZSH hooks alongside dotfiles hooks

- **CDK Tools Integration** (`cdk_tools` feature)
  - Aliases: `cdkd`, `cdks`, `cdkdf`, `cdkw`, `cdkls`, `cdkdst`, `cdkb`, `cdkda`, `cdkhs`, `cdkhsf`
  - Helpers: `cdk-env`, `cdkall`, `cdkcheck`, `cdkhotswap`, `cdkoutputs`, `cdkinit`, `cdkctx`
  - `cdktools` command with styled help and status display
  - Tab completions for stack and profile arguments
  - Status color: green (in project), cyan (installed), red (not installed)

- **Rust Tools Integration** (`rust_tools` feature)
  - Aliases: `cb`, `cr`, `ct`, `cc`, `ccl`, `cf`, `cbr`, `cw`, `cba`, `cclean`
  - Helpers: `rust-update`, `rust-switch`, `rust-new`, `rust-lint`, `rust-fix`, `rust-outdated`, `rust-expand`
  - `rusttools` command with styled help and status display
  - Tab completions for toolchain switching

- **Go Tools Integration** (`go_tools` feature)
  - Aliases: `gob`, `gor`, `got`, `gotv`, `gof`, `gom`, `gov`, `gog`, `goi`
  - Helpers: `gocover`, `goinit`, `go-new`, `go-lint`, `go-update`, `go-outdated`, `go-bench`, `go-build-all`
  - `gotools` command with styled help and status display
  - Shows module name and Go version requirements

- **Python Tools Integration** (`python_tools` feature)
  - Powered by [uv](https://github.com/astral-sh/uv) for fast Python package management
  - uv aliases: `uvs`, `uvr`, `uva`, `uvad`, `uvrm`, `uvl`, `uvu`, `uvt`, `uvv`, `uvpy`
  - pytest aliases: `pt`, `ptv`, `ptx`, `ptxv`, `ptc`, `ptl`, `pts`, `ptk`
  - Auto-venv: Prompts to activate venv on `cd` (configurable: notify/auto/off)
  - Helpers: `uv-new`, `uv-clean`, `uv-info`, `uv-python-setup`, `pt-watch`, `pt-cov`
  - `pythontools` command with styled help and status display
  - Tab completions for project templates and Python versions

- **AWS Tools Tab Completions**
  - `awsset <TAB>` and `awslogin <TAB>` complete with AWS profiles

- **CLI Color Styling**
  - Consistent color scheme across all dotfiles help commands
  - Bold+Cyan headers, Yellow commands, Dim descriptions
  - Styled: `blackdot help`, `blackdot macos`, `blackdot vault`, `blackdot template`
  - Styled: `dotfiles-backup`, `dotfiles-drift`, `dotfiles-lint`, `dotfiles-packages`, `dotfiles-migrate`

### Changed

- **Feature categories reorganized** - All third-party tool integrations now consistently in `integration` category
  - Moved `aws_helpers` and `cdk_tools` from `optional` to `integration`
  - `optional` category now only for dotfiles-specific features (vault, templates, hooks, etc.)
  - `integration` category for all external tool helpers (aws, cdk, rust, go, nvm, sdkman, etc.)

### Fixed

- **Hook command early loop exit** (`bin/blackdot-hook`)
  - Fixed `((i++))` returning falsy value when i=0, causing loop to exit prematurely
  - Changed to safe increment pattern: `i=$((i + 1))` and `count=$((count + 1))`
  - `blackdot hook list` now correctly shows all hooks and categories

- **Missing Template & Encryption hook categories** (`bin/blackdot-hook`)
  - Added Template hooks (`pre_template_render`, `post_template_render`) to list and points
  - Added Encryption hooks (`pre_encrypt`, `post_decrypt`) to list and points
  - Updated usage help text with all 7 hook categories

- **Metrics now saved after `blackdot doctor`** - Health scores written to `~/.blackdot-metrics.jsonl`
- **Vault unlock errexit issues** - Fixed silent exit on `((attempts++))` and session caching
- **Vault session persistence** - Use `BW_SESSION` env var instead of `--session` flag

---

## [3.0.0] - 2024-12-05

**🎨 MAJOR RELEASE - v3.0 Framework Architecture**

This is a comprehensive framework redesign that transforms dotfiles from a collection of scripts into a modular, feature-driven system. All breaking changes, new features, and improvements from the v3 development cycle are included in this single release.

### Added - Framework Core

- **Hook System** - Extensible event-driven hook system (`lib/_hooks.sh`)
  - Event-based hook triggers at 8 lifecycle points: `shell_init`, `directory_change`, `pre_vault_pull`, `post_vault_pull`, `pre_vault_push`, `post_vault_push`, `doctor_check`, `pre_uninstall`
  - `blackdot hook` command for managing hooks
  - `blackdot hook list` - Show all available hooks and their status
  - `blackdot hook run <event> [--dry-run]` - Manually trigger hooks
  - `blackdot hook enable <path>` - Enable hook script
  - `blackdot hook disable <path>` - Disable hook script
  - `blackdot hook validate [path]` - Validate hook scripts
  - Automatic hook discovery from `~/hooks/` and `$BLACKDOT_DIR/hooks/`
  - Per-directory hook support via `.dotfiles-hooks/`
  - Hook script naming convention: `[priority]-descriptive-name.{sh,zsh}`
  - Priority-based execution (00-99, lower runs first)
  - Hook environment with context variables ($DOTFILES_HOOK_*, $DOTFILES_*)
  - Safety features: timeouts, error isolation, validation
  - Shell integration hooks automatically loaded
  - Example hooks provided for common use cases
  - Comprehensive documentation at `docs/hooks.md`
  - 874 test cases covering all hook functionality

- **Template Pipeline Filters** - Transform variables during template rendering
  - `{{ variable | upper }}` - Convert to uppercase
  - `{{ variable | lower }}` - Convert to lowercase
  - `{{ variable | trim }}` - Remove leading/trailing whitespace
  - `{{ variable | replace:old:new }}` - String replacement
  - `{{ variable | default:fallback }}` - Provide default value
  - `{{ variable | sanitize_path }}` - Sanitize for safe path usage
  - Chain multiple filters: `{{ email | lower | trim }}`
  - Works in `{{#if}}` conditions and `{{#each}}` loops
  - Documented in `docs/templates.md`
  - 206 test cases for template functionality

- **CLI Feature Awareness** - Smart CLI that adapts to enabled features (`lib/_cli_features.sh`)
  - `blackdot help` only shows commands for enabled features (cleaner UX)
  - `blackdot help --all` shows all commands with enabled/disabled indicators (● / ○)
  - Feature guards prevent running disabled commands with helpful enable message
  - `--force` flag bypasses feature guard for any command
  - Command-to-feature mapping: vault→vault, config→config_layers, backup→backup_auto, etc.
  - Section-level filtering in help output (Vault Operations, Backup & Safety, etc.)
  - Footer shows hidden features when commands are filtered
  - `DOTFILES_CLI_SHOW_ALL=true` env var - Always show all commands in help
  - `DOTFILES_FORCE=true` env var - Bypass all feature guards (for scripting/CI)
  - `cli_feature_filter` meta-feature - Disable to show all commands, bypass all guards
  - Subcommand awareness - `vault:pull`, `config:get` have granular feature mappings
  - Per-command help - `blackdot help <cmd>` shows feature status and subcommands

- **Configuration Layers System** - Hierarchical config resolution (`lib/_config_layers.sh`)
  - 5-layer priority: env > project > machine > user > defaults
  - `blackdot config get <key> [default]` - Get value with layer resolution
  - `blackdot config set <layer> <key> <value>` - Set in specific layer
  - `blackdot config show <key>` - Display value from all layers
  - `blackdot config source <key>` - Get value with source info (JSON)
  - `blackdot config list` - Show layer locations and status
  - `blackdot config merged` - Show merged config from all layers
  - `blackdot config init machine|project` - Initialize layer configs
  - Project config (`.blackdot.json`) travels with repos
  - Machine config (`~/.config/blackdot/machine.json`) stays local
  - Environment variable override: `DOTFILES_<KEY>` (e.g., `BLACKDOT_VAULT_BACKEND`)

- **Feature Registry** - Centralized control for all optional features (`lib/_features.sh`)
  - `blackdot features` - List all features with enabled/disabled status
  - `blackdot features enable <name> [--persist]` - Enable a feature (optionally persist to config)
  - `blackdot features disable <name> [--persist]` - Disable a feature
  - `blackdot features preset <name> [--persist]` - Apply a preset (minimal, developer, claude, full)
  - `blackdot features check <name>` - Check if enabled (for scripts, returns exit code)
  - `blackdot features --json` - JSON output for automation
  - Three categories: core (always enabled), optional, integration
  - Dependency resolution: enabling `claude_integration` auto-enables `workspace_symlink`
  - Backward compatible with `SKIP_*` environment variables
  - State persisted to `config.json` features object

- **Vault Setup Wizard v2** - Complete redesign of vault onboarding flow
  - Educational phase explains how vault storage works before any configuration
  - Three setup modes: Existing (import from vault), Fresh (create new), Manual (configure yourself)
  - User guides system to their secrets location (folder/vault/directory) instead of random scanning
  - Backend-specific location support:
    - Bitwarden: folders
    - 1Password: vaults and tags (planned)
    - pass: directories
  - Respects existing naming conventions in vault
  - Works on new machines (vault-first discovery)
  - See: `docs/design/vault-setup-wizard-v2.md` for full design rationale

- **Vault Location Management** - Unified location handling across backends
  - `vault_location` field in vault-items.json schema
  - `vault_get_location()`, `vault_set_location()` in abstraction layer
  - `vault_list_locations()`, `vault_list_items_in_location()`, `vault_create_location()`
  - Backward compatible: no `vault_location` = legacy behavior (global search)

- **Bitwarden Folder Support** - Organize vault items in Bitwarden folders
  - `vault_backend_list_locations()` - List all folders
  - `vault_backend_location_exists()` - Check if folder exists
  - `vault_backend_create_location()` - Create new folder
  - `vault_backend_list_items_in_location()` - List items in folder or by prefix
  - `vault_backend_create_item_in_location()` - Create item in specific folder

- **pass Directory Support** - Location-aware operations for pass backend
  - `vault_backend_list_locations()` - List top-level directories
  - `vault_backend_location_exists()` - Check if directory exists
  - `vault_backend_create_location()` - Create new directory
  - `vault_backend_list_items_in_location()` - List items in directory
  - `vault_backend_create_item_in_location()` - Create item in specific directory

- **Input Validation & Sanitization** - Defensive input handling in setup wizard
  - `sanitize_input()` - Remove control characters, null bytes, trim whitespace
  - `validate_location_name()` - Validate folder/vault/directory names (no path traversal)
  - `validate_file_path()` - Validate local file paths
  - `validate_item_name()` - Validate vault item names match naming convention
  - `prompt_location_name()` - Validated prompt for location names
  - `prompt_file_path()` - Validated prompt for file paths

### Fixed
- **Missing feature guard on config command** - `blackdot config` now properly respects `config_layers` feature state
  - Shows helpful "feature not enabled" message when disabled
  - Consistent with other feature-gated commands (vault, backup, template)
  - Use `--force` to bypass if needed

- **Missing feature guard on Claude shell module** - `70-claude.zsh` now respects `claude_integration` feature
  - Shell functions (`claude()`, `claude-bedrock()`, etc.) only load when feature enabled
  - Consistent with feature-first architecture

- **Underscore in vault item names** - Regex now allows underscores in item names
  - Pattern changed from `^[A-Z][A-Za-z0-9-]*$` to `^[A-Z][A-Za-z0-9_-]*$`
  - Fixes validation error for items like `SSH-Enterprise_Ghub`
  - Updated both `lib/_vault.sh` and `vault/vault-items.schema.json`

- **Recursive dependency collection in feature enable** - Transitive dependencies now correctly listed
  - `dep` variable in for loop wasn't `local`, causing nested deps to be lost in recursion
  - Before: `blackdot features enable dotclaude` showed "Enabling: workspace_symlink"
  - After: Shows "Enabling: workspace_symlink claude_integration" (full chain)
  - Affects `bin/blackdot-features` dependency collection

- **Missing color variables in CLI help** - `blackdot help` now works without errors
  - `$BOLD`, `$CYAN`, `$NC` weren't defined in shell context
  - Added color definitions to `40-aliases.zsh` with TTY detection
  - Fixes "parameter not set" error when running help commands

- **`blackdot vault status` hanging** - Status command no longer prompts for password
  - Changed from `vault_get_session()` (interactive) to `vault_check_session()` (non-interactive)
  - Shows "Vault locked" with unlock instructions instead of hanging
  - Introduced `vault_check_session()` function for non-interactive session validation

- **Vault unlock password prompt invisible** - Now shows clear "Master password: " prompt
  - Uses `read -s` for hidden input from `/dev/tty`
  - Shows retry count on incorrect password
  - 1Password shows info about biometric/password auth
  - Fixed stdin consumption by adding `</dev/null` to `bw` commands

- **Vault unlock silent exit** - Fixed script exiting before password prompt (two issues)
  - `vault_read_cached_session` failure triggered errexit from sourced `_config.sh`
  - Now uses `|| session=""` pattern to handle expected failures gracefully
  - `((attempts++))` with attempts=0 returns exit status 1, triggering errexit
  - Changed to `((++attempts))` (pre-increment) to return success on first iteration

- **Color escape codes showing raw** - Fixed across multiple commands
  - `blackdot config list` - Changed printf to echo -e
  - `blackdot config help` - Changed heredoc to echo -e statements
  - `blackdot hook help` - Changed heredoc to echo -e statements

- **`blackdot lint` path detection** - Fixed "Could not find dotfiles directory" error
  - Simplified path detection to match other scripts
  - Added shebang-aware syntax checking (zsh files use `zsh -n`, bash use `bash -n`)

- **Features not persisting after setup** - Setup phases now enable and persist features
  - Added `feature_persist()` calls for workspace, vault, claude, templates phases
  - Features are now saved to config.json when setup completes

### Added - CLI Improvements

- **`blackdot vault` CLI** - Unified vault management command wrapping all vault operations
  - `blackdot vault unlock` - Unlock vault with clear password prompt (hidden input)
  - `blackdot vault lock` - Lock vault and clear cached session
  - `blackdot vault status` - Full status with drift detection
  - `blackdot vault quick` - Quick status check (login/unlock only)
  - `blackdot vault restore/pull` - Restore secrets from vault
  - `blackdot vault push` - Push local secrets to vault
  - `blackdot vault list` - List vault items
  - `blackdot vault scan` - Scan for local secrets
  - Provides clearer UX than raw `bw` commands

- **Feature preset selection in setup wizard** - Choose feature presets during setup
  - Offers minimal, developer, claude, and full presets at end of setup
  - Persists selected features to config.json

### Changed
- **Schema relaxed** - `vault_items` no longer required in vault-items.json
  - Allows minimal config with just `vault_location` during initial setup
  - Added support for `$schema` and `$comment` fields in JSON

### Documentation
- **Vault Setup Wizard v2 Design Document** - Comprehensive design at `docs/design/vault-setup-wizard-v2.md`
  - Problem statement and design principles
  - User flow diagrams for all three setup modes
  - Backend-specific implementation plans
  - Schema changes and migration paths
  - Risk assessment and success criteria

### Planned
- **1Password Backend Location Support** - Vault and tag-based organization
  - `vault_backend_list_locations()` for vaults
  - Tag support as alternative location type
  - Migration from `ONEPASSWORD_VAULT` env var to config
  - See `docs/design/vault-setup-wizard-v2.md` for implementation plan

### Added - v3.0 Core Features (consolidated from earlier releases)
- **Vault Schema Validation** (Pain Point #4) - Prevent invalid configurations
  - JSON schema for vault-items.json with comprehensive validation rules
  - `vault_validate_schema()` function in `lib/_vault.sh` validates required fields, types, naming conventions
  - Automatic validation before all vault sync operations (push/pull)
  - Standalone `blackdot vault validate` command for manual validation
  - Clear error messages showing exactly what's wrong and how to fix it
  - Graceful degradation when jq is not installed (warning instead of failure)
  - Schema file: `vault/vault-items.schema.json` with JSON Schema Draft 2020-12
  - Validates: required fields (path, required, type), enum values (file/sshkey), item name patterns

- **Setup Wizard Progress Bar** (Pain Point #8) - Visual feedback for setup progress
  - Unicode progress bar with 20-character visualization (█ filled, ░ empty)
  - `show_progress()` function displays current step (e.g., "Step 3 of 7: Packages")
  - `show_steps_overview()` function shows all 7 steps upfront with descriptions
  - Beautiful bordered sections using box drawing characters (╔═╗║╠╣╚═╝)
  - Progress percentage calculation (14%, 29%, 43%, etc.)
  - All 7 setup phases: workspace, symlinks, packages, vault, secrets, claude, template
  - Overview shown at wizard start with safety reminder ("Safe to exit anytime")

- **Structured Error Handling Library** (Pain Point #6) - Actionable error messages
  - `lib/_errors.sh` - Comprehensive error handling with 15 pre-built error functions
  - Structured format: What / Why / Impact / Fix / Help URL
  - Error functions: error_vault_locked, error_missing_dep, error_git_not_configured, etc.
  - All errors include specific fix commands and documentation links
  - Multiline fix command support with color-coded output
  - Export functions for use in subshells

- **Health Score Interpretation** (Pain Point #7) - Understand your dotfiles health
  - Color-coded health status: 🟢 Healthy (80-100), 🟡 Minor (60-79), 🟠 Needs Work (40-59), 🔴 Critical (0-39)
  - "Quick Fixes" section lists each failed check with exact fix command
  - Tracks failures and warnings with associated fixes
  - Shows potential score improvement: "95/100 if all issues fixed"
  - Auto-fix suggestions for permission-related issues
  - Celebrates perfect scores with emoji and encouragement
  - Enhanced `bin/blackdot-doctor` with comprehensive summary section

- **Vault Status Command** (Pain Point #12) - Full visibility into vault sync state
  - `blackdot vault status` - Comprehensive vault status dashboard
  - Shows backend configuration (type, login status, unlock status)
  - Lists all vault items with counts (config items, SSH keys)
  - Sync history with human-readable timestamps ("2h ago", "3d ago")
  - Comprehensive drift detection comparing 6 key config files
  - Actionable recommendations based on drift status
  - Beautiful formatted output with sections and emojis
  - Timestamp tracking: saves vault.last_pull and vault.last_push to config.json
  - ISO 8601 format timestamps in UTC

- **Template System Documentation** (Pain Point #10) - Hidden gem now visible
  - Massively enhanced template documentation in main README (8 lines → 132 lines)
  - 3 real-world examples: Git config, SSH config, environment variables
  - Clear problem/solution framing for multi-machine use cases
  - Quick start 5-step workflow
  - Auto-detected variables documentation (HOSTNAME, OS, USER, etc.)
  - Use cases: work vs personal, multi-cloud, team onboarding
  - Template syntax examples with conditionals and loops

- **v3.0 Command Namespace** - Git-inspired command names (BREAKING CHANGE)
  - NEW commands: `vault setup`, `vault scan`, `vault pull`, `vault push`, `vault status`
  - Git-inspired naming: pull/push instead of restore/sync
  - Clearer intent: setup (not init), scan (not discover)
  - See: vault/README.md for complete command reference

- **Top-Level Backup & Rollback Commands** - Safety features promoted to first-class
  - `blackdot backup` - Create backup of current configuration
  - `blackdot backup list` - List all available backups
  - `blackdot backup restore <name>` - Restore specific backup
  - `blackdot rollback` - Instant rollback to last backup
  - `blackdot rollback --to <name>` - Rollback to specific backup
  - Backup moved out of vault namespace for clearer separation
  - Implements v3.0 design goal: mandatory safety features

- **Enhanced Help Text** - Clean, focused CLI help
  - Main help (`blackdot help`) shows complete command structure
  - Vault help (`blackdot vault help`) with clear command categories
  - Color-coded sections for better readability
  - Removed version labels and migration noise

- **JSON Config System** (v3.0) - Modern configuration format with nested structure
  - `lib/_config.sh` - JSON config abstraction layer with type-safe functions
  - config_get, config_set, config_get_bool, config_set_bool
  - config_array_add, config_array_remove for array management
  - config_get_array for retrieving array values
  - Nested configuration: vault.backend, setup.completed[], paths.*
  - Validation and backup functions built-in
  - Uses jq for JSON manipulation (already a dependency)
  - Default config with sensible defaults for all v3.0 settings

- **Migration Tools** (v3.0) - Automated migration from v2.x to v3.0
  - `bin/blackdot-migrate` - Unified migration orchestrator
  - `bin/blackdot-migrate-config` - INI→JSON config migration
  - `bin/blackdot-migrate-vault-schema` - v2→v3 vault schema migration
  - `blackdot migrate` - Top-level command in main CLI
  - Interactive confirmation with --yes flag to skip
  - Timestamped backups before all migrations
  - Detects if migration is needed (idempotent)
  - Shows migration summary with before/after comparison

- **Vault Schema v3.0** - Simplified, consistent vault item structure
  - Single secrets[] array replaces separate ssh_keys/vault_items/syncable_items
  - Eliminates duplication between ssh_keys and vault_items
  - Per-item control: sync (always/manual), backup (true/false), required (true/false)
  - Consistent schema: name, path, type, required, sync, backup
  - Migration preserves all existing items and metadata
  - version field indicates schema version

- **Configurable Workspace Target** - Customize where /workspace points
  - New setup wizard step (Step 1 of 7): Interactive workspace configuration
  - New `WORKSPACE_TARGET` environment variable to specify custom directory
  - New `paths.workspace_target` config option in config.json
  - `/workspace` symlink name stays constant (for Claude Code portability)
  - Only the TARGET directory is configurable (default: `~/workspace`)
  - Priority order: env var > config.json > default
  - New `lib/_paths.sh` helper with `get_workspace_target()` and `get_dotfiles_dir()`
  - All CLI tools updated to use configurable paths
  - Usage: `WORKSPACE_TARGET=~/code ./install.sh` or configure via wizard
  - Supports users with existing project layouts (`~/code`, `~/projects`, `~/dev`)
  - Zero breaking changes - default behavior unchanged

### Changed
- **BREAKING: Vault commands renamed** - Old commands removed entirely
  - `vault init` → `vault setup`
  - `vault discover` → `vault scan`
  - `vault restore` → `vault pull`
  - `vault sync` → `vault push`
  - `vault backup` → top-level `backup` command
  - No migration period - clean break for greenfield deployment

- **State Management Backend** (v3.0) - Now uses JSON config instead of INI files
  - `lib/_state.sh` refactored to use JSON config as backend
  - State stored in setup.completed[] array instead of INI sections
  - API unchanged: state_completed(), state_complete(), state_reset() still work
  - Backward compatible: existing scripts don't need changes
  - Config stored in ~/.config/blackdot/config.json (v3 format)

- **v3.0 Breaking Changes Design** - Comprehensive redesign proposal (DESIGN-v3.md)
  - Git-inspired command names: setup, scan, pull, push (replaces init, discover, restore, sync)
  - Config format migration: INI → JSON (consistent with vault-items.json, native jq support)
  - Mandatory auto-backup before all destructive operations
  - Package tier selection in setup wizard (minimal/enhanced/full)
  - Enhanced error messages with fix commands and documentation links
  - Health score interpretation with auto-fix command
  - Simplified vault schema (eliminates duplication)
  - 4-week implementation timeline with auto-migration strategy
  - See DESIGN-v3.md for full details

- **Pain-Point Analysis Refactoring** - Updated pain-point-analysis.md with v3.0 solutions
  - All 23 pain points now include v3.0 solutions
  - Cross-referenced with DESIGN-v3.md sections
  - v2.3 solutions documented alongside v3.0 enhancements
  - Updated executive summary with v3.0 vision
  - Phased implementation roadmap (4 weeks)
  - Success criteria and next steps

### Fixed
- **Critical Bug Fixes** - Comprehensive code audit identified and fixed 4 critical/high severity issues
  - **Progress bar division by zero** (CRITICAL): Added guards to prevent crash if total=0 or current>total
    - `show_progress()` now validates inputs and clamps values to safe ranges
    - Prevents overflow when current step exceeds total steps
    - File: `bin/blackdot-setup` lines 75-95
  - **Lost package installation exit status** (CRITICAL): Fixed exit code capture in brew bundle
    - Changed from `$?` (captures while loop status) to `${pipestatus[1]}` (captures brew status)
    - Prevents false "success" reports when package installation actually failed
    - File: `bin/blackdot-setup` line 370
  - **Missing schema validation in setup wizard** (HIGH): Added validation to vault configuration phase
    - Setup wizard now validates `vault-items.json` immediately after creation/editing
    - Interactive fix flow: detects errors → opens editor → re-validates → confirms before continuing
    - Prevents proceeding with invalid config that would fail mysteriously during vault operations
    - File: `bin/blackdot-setup` lines 513-544
  - **Test environment stderr pollution** (HIGH): Fixed unit test failure in CI
    - Config initialization messages were leaking into test output (4 lines instead of expected 2)
    - Suppressed stderr during _common.sh sourcing in test helper functions
    - File: `test/vault_common.bats` line 83
  - All 119 tests now pass reliably in both local and CI environments

- **v3.0 Consistency Audit** - Eliminated all v2.x command and config references (23 instances)
  - Updated 7 vault scripts to use v3.0 commands (setup/scan/pull/push)
  - Updated 9 documentation files with correct v3.0 command examples
  - `vault/init-vault.sh` now uses centralized `lib/_config.sh` instead of inline INI parsing
  - All config file references updated: state.ini/config.ini → config.json
  - File Locations tables updated to reflect v3.0 JSON format
  - State Management documentation sections rewritten for v3.0
  - Complete codebase now consistent with v3.0 command namespace
  - Affects: vault scripts, bootstrap, docs (17 files total)

- **Documentation Quick Wins** - Improved clarity on common pain points (#5, #9, #14, #15)
  - **CLAUDE.md placement** (#14): Added prominent header explaining it's for AI agents, not users
  - **Workspace symlink purpose** (#15): Expanded explanation of `/workspace` symlink benefits
    - Clear problem/solution format showing why it enables Claude Code session portability
    - Explains different paths = different sessions = lost history without symlink
    - Updated in README.md and docs/README.md
  - **Multi-vault clarification** (#9): Clarified "multi-vault" means one backend at a time
    - Added note explaining system supports multiple backends but you use one active backend
    - Documented switching process with `blackdot vault setup`
    - Updated docs/vault-README.md
  - **Vault merge preview** (#5): Improved confusing "manual items" terminology
    - Changed "Preserved manual items" → "Preserved items in config but not discovered"
    - Added explanation: "may be custom paths, moved files, or items from other machines"
    - Updated merge/replace prompts with clearer recommendations (existing vs. fresh machines)
    - Added tip explaining what merge preserves
    - Updated vault/discover-secrets.sh

- **Documentation v3.0 Audit** - Updated all documentation for tier selection feature
  - Fixed outdated package counts in README.md, docs/README-FULL.md, docs/architecture.md, docs/cli-reference.md
  - Updated BREWFILE_TIER documentation to reflect interactive wizard (was env var only)
  - Corrected package counts: 18/43/61 (was incorrectly documented as 15/40/80 or 40/80/120+)
  - Added "How it works" sections explaining config.json persistence
  - Emphasized interactive setup wizard over environment variable approach
  - Affects: README.md (3 sections), docs/README-FULL.md, docs/architecture.md, docs/cli-reference.md

- **Unit Test Compatibility** - Fixed 47 failing tests caused by export -f statements
  - Removed bash-specific `export -f` statements from lib/_config.sh
  - Functions sourced from library files don't need explicit export
  - Improves cross-shell compatibility (bash/zsh/sh)
  - Tests now pass: 75/76 unit tests, 21/21 integration tests, 22/22 error scenarios
  - Only 1 minor test remains (SSH key count environmental issue)

- **Vault Command Clarity** - Improved help text to clarify relationship between init and discover
  - Added workflow section showing: First time → init, Re-scan → discover
  - Highlighted that `vault init` includes auto-discovery as part of setup
  - Reduced confusion about command order and purpose
  - Addresses pain-point #1: "Do I run init first or discover first?"

### Added
- **Automatic Backup Before Restore** - Vault restore now auto-creates backup
  - Creates timestamped backup before overwriting any local secrets
  - Shows backup location and restore command
  - Added `blackdot vault backup` command (exposed existing bin/blackdot-backup)
  - Eliminates fear of losing local changes during restore
  - Addresses pain-point #2: "No rollback/undo" concern

- **Package Tier Selection** (#3) - Interactive tier selection in setup wizard
  - Presents 3 tiers with package counts and time estimates:
    - Minimal: 18 packages (~2 min) - Essentials only
    - Enhanced: 43 packages (~5 min) - Modern tools, no containers (RECOMMENDED)
    - Full: 61 packages (~10 min) - Everything (Docker, etc.)
  - Saves tier preference in config.json (packages.tier)
  - Uses saved preference if re-running setup
  - Shows accurate package count and progress during installation
  - Makes invisible tier options visible (was hidden env variable)
  - Addresses pain-point #3: "Brewfile tier selection invisible"

- **Package Installation Progress** - Setup wizard now shows real-time progress
  - Displays package count before installation
  - Streams brew output with highlighted progress
  - Shows "(X installed)" counter during installation
  - Time estimate maintained: "~5-10 minutes"
  - Addresses pain-point #3: "Is it frozen?" confusion

## [2.3.0] - 2025-12-04

### Fixed
- **Dynamic Path Resolution** - Fixed hardcoded paths in zsh configuration
  - All `blackdot` commands now work regardless of installation location
  - Introduced `$BLACKDOT_DIR` environment variable (auto-detected from config location)
  - Replaced all hardcoded `$HOME/workspace/dotfiles` paths with `$BLACKDOT_DIR`
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
- **Vault Init Command** - New `blackdot vault init` for easy vault configuration
  - Configure or reconfigure vault backend anytime
  - No need to reset setup state or run full wizard
  - Detects existing configuration and asks to reconfigure
  - Clear guidance when skipping vault setup
  - Accessible via `blackdot vault init` or `blackdot vault init --force`

- **Vault Auto-Discovery** - Automatically detect secrets in standard locations
  - New `blackdot vault discover` command scans for existing secrets
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
  - Integrated into `blackdot vault init` with auto-discover option
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
  - Vault configured → Suggests `blackdot vault restore`
  - Templates configured → Suggests `blackdot template render`
  - Always shows `blackdot doctor` for health check
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
  - Setup completion now recommends `blackdot vault validate`
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
  - New STEP 6 in `blackdot setup` guides users through template configuration
  - Explains use cases: work vs personal git email, different SSH keys, machine-specific env vars
  - Runs `blackdot template init` interactively during onboarding
  - Defaults to "No" (opt-in) to keep setup fast for users who don't need templates
  - Shows how to enable later: `blackdot template init`
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
  - `~/.config/blackdot/vault-items.json` defines SSH keys, vault items, syncable items
  - No more hardcoded organization-specific values in source code
  - `vault/vault-items.example.json` provides template to customize
  - `blackdot setup` creates config automatically during wizard
  - `require_vault_config()` ensures config exists before vault operations
- **Template CLI Help Improvements** - Better discoverability in `blackdot template help`
  - Added `list` command to help output (shows available templates with status)
  - Added `{{#each}}` loop syntax to template syntax section
  - Added DOCUMENTATION section with links to docs/templates.md and online guide
- **Template JSON Arrays** - `{{#each}}` loops now support JSON configuration
  - New `templates/_arrays.local.json` for cleaner array definitions
  - `blackdot template arrays` command to view/manage arrays
  - `blackdot template arrays --export-json` exports shell arrays to JSON format
  - `blackdot template arrays --validate` validates JSON syntax
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
  - Works with `pass` backend (`export BLACKDOT_VAULT_BACKEND=pass`)
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
- **Help hint for subcommand options** - Main `blackdot help` now shows: "Run 'dotfiles <command> --help' for detailed options"
- **State Management in Quick Navigation** - Added link to `state-management.md` in docsify homepage

## [2.0.0] - 2025-12-02

### Breaking Changes
- **Removed `blackdot init` command** - Now use `blackdot setup` instead
- **Removed `install.sh --interactive` flag** - Bootstrap now prompts to run `blackdot setup`
- **Renamed `vault/bootstrap-vault.sh`** to `vault/restore.sh` for clarity

### Added
- **Unified Setup Wizard** (`blackdot setup`) - New interactive setup with persistent state
  - Five-phase setup: symlinks → packages → vault → secrets → claude
  - Progress persistence in `~/.config/blackdot/state.ini` and `~/.config/blackdot/config.ini`
  - Resume support: continue where you left off if interrupted
  - State inference: auto-detects existing installations from filesystem
  - Visual status dashboard with checkmarks (`blackdot setup --status`)
  - Reset capability (`blackdot setup --reset`)
- **State Management Library** (`lib/_state.sh`) - Pure zsh INI file parsing
  - Functions: `state_init`, `state_completed`, `state_complete`, `state_needs_setup`
  - Config API: `config_get`, `config_set` for persistent preferences
  - State inference: `state_infer` detects symlinks, packages, vault, secrets, Claude
  - Files: `~/.config/blackdot/state.ini` (phase completion), `~/.config/blackdot/config.ini` (user prefs)
- **macOS Settings Command** (`blackdot macos`) - Expose macOS settings management
  - `blackdot macos apply` - Apply settings from settings.sh
  - `blackdot macos preview` - Dry-run mode
  - `blackdot macos discover` - Capture current settings
- **Vault Restore Preview** - `blackdot vault restore --preview` shows what would be restored without making changes
- **Documentation Updates**
  - New `docs/state-management.md` - Dedicated state system documentation
  - State Management section in `docs/cli-reference.md` with INI file format examples
  - `blackdot macos` command reference with all subcommands and options
  - Updated all references from `blackdot init` to `blackdot setup`
  - Added `macos` command to architecture diagram

### Changed
- **Renamed `bootstrap-vault.sh` to `restore.sh`** - Clearer naming for vault orchestrator
- **Removed `blackdot init`** - Replaced by `blackdot setup` with better state management
- **Vault Backend Persistence** - Backend choice now saved to config file
  - Priority: config file → environment variable → default (bitwarden)
  - Persists across sessions without needing to export env var
- **Simplified `install.sh`** - Removed `--interactive` flag
  - Bootstrap scripts now tell user to run `blackdot setup`
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
- **Vault-Agnostic `blackdot init`** - Major refactor of interactive setup wizard
  - Auto-detects all vault backends (Bitwarden, 1Password, pass)
  - Prompts user to choose vault (never auto-selects)
  - Option to skip vault setup entirely
  - Backend-specific login/unlock flows
  - Fixes Alpine/Linux issue where pass was auto-selected
- **Integrated `install.sh` with `blackdot init`** - `install.sh --interactive` now calls the wizard automatically
- **Simplified Quick Start** - Reduced from 4 manual steps to 2 (clone → dotfiles init)
- **Reordered README Sections** - End sections now: Acknowledgments → Trademarks → License
- **Updated Project Structure** - Added lib/_vault.sh and test/fixtures/ subdirectory
- **Removed Bitwarden Bias** - All documentation now vault-agnostic

### Documentation
- Updated README.md, docs/README.md, docs/README-FULL.md with simplified install flow
- Updated docs/cli-reference.md with comprehensive `blackdot init` documentation
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
  - `blackdot status` shows active Claude profile (if dotclaude installed)
  - `blackdot doctor` validates Claude/dotclaude setup with install hints
  - `blackdot vault` syncs `~/.claude/profiles.json` to vault
  - `blackdot drift` detects Claude profile changes vs vault
  - `blackdot packages` suggests dotclaude for Claude users
  - `blackdot init` offers dotclaude installation during setup wizard
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
- **`BLACKDOT_VAULT_BACKEND`** - Environment variable to select backend (defaults to `bitwarden`)

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
- Bootstrap scripts updated to find BLACKDOT_DIR from parent directory
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
  - `blackdot-metrics` - Metrics visualization (renamed from show-metrics.sh)
  - `dotfiles-uninstall` - Clean removal (renamed from uninstall.sh)

### Changed
- Scripts now source `lib/_logging.sh` from `$BLACKDOT_DIR/lib/` (parent of bin/)
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
- **Safety feature** - Prevents accidental data loss during `blackdot vault restore`
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
- Help text updated for `blackdot vault restore --force`
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

#### Unified `blackdot` Command Expansion
- **`blackdot diff`** - Preview changes before sync or restore
  - `blackdot diff --sync` - Show what would be synced to vault
  - `blackdot diff --restore` - Show what restore would change
  - Unified diff output with color coding

- **`blackdot backup`** - Backup and restore configuration
  - Creates timestamped tar.gz archives in `~/.blackdot-backups/`
  - `blackdot backup` - Create new backup
  - `blackdot backup --list` - List available backups
  - `blackdot backup restore` - Interactive restore from backup
  - Auto-cleanup keeps only 10 most recent backups

- **`blackdot init`** - First-time setup wizard
  - Interactive walkthrough for new installations
  - Guides through bootstrap, Bitwarden setup, secret restoration
  - ASCII art banner and step-by-step progress

- **`blackdot uninstall`** - Clean removal script
  - `blackdot uninstall --dry-run` - Preview what would be removed
  - `blackdot uninstall --keep-secrets` - Remove dotfiles but keep SSH/AWS/Git
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
- Expanded `blackdot help` output with all new commands

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
  - Records health check results to `~/.blackdot-metrics.jsonl`
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
- Added `.blackdot-metrics.jsonl` metrics file

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
