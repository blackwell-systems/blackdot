# Claude Code Session Guidelines

This file contains important guidelines and reminders for Claude Code sessions working on this repository.

---

## 🚀 Quick Reference

For quick access to common commands and project structure:

```bash
dotfiles status          # Visual dashboard
dotfiles doctor          # Health check
dotfiles doctor --fix    # Auto-fix permissions
dotfiles drift           # Compare local vs Bitwarden vault
dotfiles vault restore   # Restore secrets from Bitwarden
dotfiles vault sync      # Sync local to Bitwarden
dotfiles lint            # Validate shell config syntax
dotfiles packages        # Check/install Brewfile packages
dotfiles template init   # Setup machine-specific configs
dotfiles template render # Generate configs from templates
dotfiles upgrade         # Pull latest and run bootstrap
```

### Project Structure

```
dotfiles/
├── bootstrap/           # Platform setup scripts
├── bin/                 # CLI tools (doctor, drift, backup, etc.)
├── vault/*.sh           # Bitwarden integration scripts
├── zsh/zsh.d/*.zsh      # Shell config (numbered load order: 00-99)
├── lib/                 # Shared libraries (_logging.sh, _templates.sh)
├── templates/           # Machine-specific config templates
│   ├── configs/*.tmpl   # Template files (gitconfig, ssh-config, etc.)
│   └── _variables*.sh   # Variable definitions
├── generated/           # Rendered templates (gitignored)
├── claude/              # Claude Code config & commands
└── docs/                # Docsify documentation site
```

### Key Files

| File | Purpose |
|------|---------|
| `zsh/zsh.d/40-aliases.zsh` | The `dotfiles` command lives here |
| `zsh/zsh.d/50-functions.zsh` | Shell functions including `status` |
| `vault/_common.sh` | Shared vault functions, SSH_KEYS config |
| `bin/dotfiles-doctor` | Health check implementation |
| `lib/_templates.sh` | Template engine for machine-specific configs |
| `templates/_variables.sh` | Default template variable definitions |
| `bin/dotfiles-template` | Template CLI tool |

---

## 📝 Documentation Updates

**⚠️ CRITICAL: Always update documentation in ALL locations**

When making changes that affect documentation, you MUST update all these files:

### Main Documentation
- **`README.md`** (root) - Primary documentation, shown on GitHub repo homepage

### GitHub Pages / Docsify Site (`docs/` directory)
- **`docs/README.md`** - Homepage for GitHub Pages documentation site
- **`docs/README-FULL.md`** - Comprehensive full documentation guide
- **`docs/templates.md`** - Template system documentation
- **`docs/vault-README.md`** - Vault system documentation
- **`docs/macos-settings.md`** - macOS settings guide (if macOS-related changes)

### Keep in Sync
Changes to features, prerequisites, installation instructions, or usage examples MUST be reflected across:
1. Root `README.md`
2. `docs/README.md`
3. `docs/README-FULL.md` (if applicable)

**Example areas that need multi-file updates:**
- Prerequisites / dependencies
- Installation instructions
- Feature descriptions
- Usage examples / quick start
- Environment variables / flags
- Troubleshooting steps

---

## 🧪 Testing Requirements

### Before Committing Code Changes

1. **Run shellcheck** (if available):
   ```bash
   shellcheck **/*.sh
   ```

2. **Run unit tests**:
   ```bash
   cd test && ./run_tests.sh
   ```

3. **Test on target platform** (if possible):
   - macOS changes: Test on macOS
   - Linux changes: Test on Linux/WSL2/Lima
   - Cross-platform: Test on both

### Pre-commit Hooks

The repository has pre-commit hooks that automatically:
- Check bash scripts with shellcheck (if installed)
- Validate ZSH syntax
- Scan for secrets
- Check repository structure

These run automatically on `git commit`.

---

## 📂 Repository Structure

### Key Directories

```
.
├── bootstrap-*.sh          # Platform bootstrap scripts
├── vault/                  # Bitwarden vault integration
│   ├── _common.sh          # Single source of truth (IMPORTANT!)
│   ├── restore-*.sh        # Restore scripts for each category
│   └── sync-to-bitwarden.sh
├── zsh/                    # Shell configuration
│   └── zsh.d/              # Modular zsh config (10 files)
├── macos/                  # macOS-specific configs
├── docs/                   # GitHub Pages documentation
├── test/                   # Unit tests (bats-core)
└── install.sh              # One-line installer
```

### Single Source of Truth Files

**`vault/_common.sh`** - Contains central data structures:
- `SSH_KEYS` - All SSH key mappings
- `DOTFILES_ITEMS` - Protected dotfiles items
- `SYNCABLE_ITEMS` - Items that can sync to Bitwarden

**When adding new vault items:** Update `_common.sh` FIRST, then other scripts will automatically pick up changes.

---

## 🎯 Coding Standards

### Shell Scripts

1. **Always use strict mode:**
   ```bash
   set -euo pipefail
   ```

2. **Source common functions:**
   ```bash
   source "$(dirname "$0")/_common.sh"
   ```

3. **Use logging functions:**
   - `info()` - Informational messages (blue)
   - `pass()` - Success messages (green)
   - `warn()` - Warnings (yellow)
   - `fail()` - Errors (red)
   - `dry()` - Dry-run messages (cyan)

4. **Idempotent design:**
   - Scripts should be safe to run multiple times
   - Check if operation already done before doing it
   - Backup before destructive operations

5. **Graceful degradation:**
   - Handle missing optional dependencies
   - Provide helpful error messages
   - Suggest remediation steps

### ZSH Configuration

When modifying zsh config:
1. Use appropriate module in `zsh/zsh.d/`
2. Follow numbered prefix convention (00-90)
3. Test that modules load in correct order

---

## 🔧 Common Tasks

### Adding a New Vault Item

1. Update `vault/_common.sh`:
   ```zsh
   typeset -A SYNCABLE_ITEMS=(
       ["New-Item"]="$HOME/.config/newitem"
       # ... existing items
   )
   ```

2. Add restore logic (if needed) to appropriate `restore-*.sh`

3. Update documentation:
   - `vault/README.md`
   - `docs/vault-README.md`

4. Add tests in `test/vault_common.bats` if applicable

### Adding a New macOS Setting

1. Update `macos/settings.sh`
2. Group with related settings
3. Add comment explaining what it does
4. Update `docs/macos-settings.md` with description

### Adding a New Environment Variable Flag

1. Add to bootstrap script (`bootstrap-mac.sh` / `bootstrap-linux.sh`)
2. Document in:
   - Root `README.md` (Prerequisites or Optional Components section)
   - `docs/README.md`
   - `docs/README-FULL.md`
3. Update `install.sh` if it should work with `--minimal` or `--interactive`

---

## 🚨 What NOT to Do

1. **DON'T** commit secrets or credentials
2. **DON'T** hard-code user-specific paths (use `$HOME`, `$WORKSPACE`)
3. **DON'T** break idempotency (scripts must be re-runnable)
4. **DON'T** add dependencies without updating Brewfile
5. **DON'T** update README without updating docs/README.md
6. **DON'T** modify `_common.sh` without checking dependent scripts
7. **DON'T** skip tests (run `test/run_tests.sh` before committing)

---

## 📋 Commit Message Guidelines

Use conventional commits format:

```
<type>: <description>

[optional body]

[optional footer]
```

**Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only changes
- `refactor:` - Code refactoring (no behavior change)
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks

**Examples:**
```
feat: Add drift detection for vault items

docs: Clarify that Bitwarden vault is optional

fix: Handle missing SSH keys gracefully in restore script

refactor: Consolidate vault item definitions in _common.sh
```

---

## 🤝 Working with Users

### When User Asks for Changes

1. **Understand the goal** - Ask clarifying questions if needed
2. **Check existing implementation** - Feature might already exist but not documented
3. **Propose approach** - Explain what you'll change before doing it
4. **Update all affected files** - Don't forget docs/
5. **Test thoroughly** - Run tests, check on target platform if possible
6. **Commit with clear message** - Explain what and why

### When Feature Already Exists

If user asks for something that already works:
1. **Verify it actually works** - Read the code, don't assume
2. **Check if documentation is clear** - Maybe just needs better docs
3. **Improve documentation** if feature is hidden/unclear
4. **Show user how to use it** - Provide concrete examples

---

## 🔍 Review Checklist

Before completing work, verify:

- [ ] All affected documentation files updated (README.md, docs/README.md, docs/README-FULL.md)
- [ ] Code follows conventions (set -euo pipefail, logging functions, etc.)
- [ ] Tests pass (`test/run_tests.sh`)
- [ ] Changes are idempotent (safe to run multiple times)
- [ ] Error messages are helpful and suggest solutions
- [ ] Commit message follows conventional commits format
- [ ] No secrets or credentials committed
- [ ] Single source of truth files updated if applicable (_common.sh)

---

## 📚 Key Concepts

### Vault System
- Bitwarden-backed secret management
- Bidirectional sync (restore from vault, push to vault)
- Schema validation before operations
- Protected items (require explicit confirmation to delete)

### Portable Sessions
- `/workspace` symlink for consistent paths across machines
- Enables Claude Code session sync
- Optional feature (SKIP_WORKSPACE_SYMLINK)

### Health Checks
- `dotfiles doctor` - Comprehensive validation
- `dotfiles doctor --fix` - Auto-remediation
- `dotfiles drift` - Detect local vs vault differences

### Modularity
- 10 zsh modules instead of monolithic .zshrc
- Numbered prefixes control load order
- Each module is self-contained and documented

---

## 💡 Tips for Claude Code Sessions

1. **Read before writing** - Always read files before editing
2. **Search before creating** - Feature might already exist
3. **Test assumptions** - Verify code actually does what documentation claims
4. **Be thorough with docs** - Users rely on accurate documentation
5. **Explain your changes** - Help user understand what you did and why
6. **Commit incrementally** - Don't batch unrelated changes
7. **Keep context** - Reference file:line numbers when discussing code

---

**Last Updated:** 2025-11-29
**Version:** 1.7.0
