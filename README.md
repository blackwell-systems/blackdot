# Dotfiles Management Framework

[![Blackwell Systems™](https://raw.githubusercontent.com/blackwell-systems/blackwell-docs-theme/main/badge-trademark.svg)](https://github.com/blackwell-systems)
[![Shell](https://img.shields.io/badge/Shell-Zsh-89e051?logo=zsh&logoColor=white)](https://www.zsh.org/)
[![Claude Code](https://img.shields.io/badge/Built_for-Claude_Code-8A2BE2?logo=anthropic)](https://claude.ai/claude-code)
[![dotclaude](https://img.shields.io/badge/Integrates-dotclaude-8A2BE2?logo=anthropic)](https://github.com/blackwell-systems/dotclaude)
[![Secrets](https://img.shields.io/badge/Secrets-Multi--Vault-ff4081)](https://github.com/blackwell-systems/dotfiles#vault--secrets)
[![Version](https://img.shields.io/github/v/release/blackwell-systems/dotfiles)](https://github.com/blackwell-systems/dotfiles/releases)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows%20%7C%20WSL2%20%7C%20Docker-blue)](https://github.com/blackwell-systems/dotfiles)
[![Test Status](https://github.com/blackwell-systems/dotfiles/workflows/Test%20Dotfiles/badge.svg)](https://github.com/blackwell-systems/dotfiles/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> A dotfiles management framework built on **Feature Registry** (modular control plane), **Configuration Layers** (multi-machine settings), and **Claude Code Integration** (portable AI-assisted development). Designed for developers who work across machines. Everything is optional except shell config.

[Changelog](CHANGELOG.md) | [Full Documentation](docs/README-FULL.md)

---

## One-Line Install

Choose your install level:

```bash
# Full: Everything (recommended for Claude Code users)
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash && dotfiles setup

# Minimal: Just shell config (skip Homebrew, vault, Claude, /workspace)
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash -s -- --minimal

# Custom workspace: Install to ~/code instead of ~/workspace
WORKSPACE_TARGET=~/code curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash

# Custom: Pick components in the interactive wizard
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash && dotfiles setup
# (wizard lets you skip vault, Claude, packages, etc.)
```

### What "Full Install" Does

**For users with existing credentials (SSH keys, AWS config, Git config):**

```console
$ curl -fsSL ... | bash && dotfiles setup

    ____        __  _____ __
   / __ \____  / /_/ __(_) /__  _____
  / / / / __ \/ __/ /_/ / / _ \/ ___/
 / /_/ / /_/ / /_/ __/ / /  __(__  )
/_____/\____/\__/_/ /_/_/\___/____/

              Setup Wizard

Current Status:
───────────────
  [ ] Workspace  (Workspace directory)
  [ ] Symlinks   (Shell config linked)
  [ ] Packages   (Homebrew packages)
  [ ] Vault      (Vault backend)
  [ ] Secrets    (SSH keys, AWS, Git)
  [ ] Claude     (Claude Code integration)
  [ ] Templates  (Machine-specific configs)

═══════════════════════════════════════════════════════════════
                    Setup Wizard Overview
═══════════════════════════════════════════════════════════════

This wizard will guide you through 7 steps:

  1. Workspace    - Configure workspace directory
     Default: ~/workspace (target for /workspace symlink)

  2. Symlinks     - Link shell config files
     ~/.zshrc, ~/.p10k.zsh, ~/.claude

  3. Packages     - Install Homebrew packages
     Choose: minimal (18) | enhanced (43) | full (61)

  4. Vault        - Configure secret backend
     Bitwarden, 1Password, or pass

  5. Secrets      - Manage SSH keys, AWS, Git config
     Auto-discover and sync to vault

  6. Claude Code  - AI assistant integration
     Optional: dotclaude + portable sessions

  7. Templates    - Machine-specific configs
     Optional: work vs personal configs

✓ Safe to exit anytime - Progress is saved automatically
✓ Resume anytime - Just run 'dotfiles setup' again

═══════════════════════════════════════════════════════════════

╔═══════════════════════════════════════════════════════════════╗
║ Step 3 of 7: Packages
╠═══════════════════════════════════════════════════════════════╣
║ ████████░░░░░░░░░░░░ 43%
╚═══════════════════════════════════════════════════════════════╝

Which package tier would you like?

  1) minimal    18 packages (~2 min)   # Essentials only
  2) enhanced   43 packages (~5 min)   # Modern tools ← RECOMMENDED
  3) full       61 packages (~10 min)  # Everything (Docker, etc.)

Your choice [2]: 2

→ Installing fzf... (1/43)
→ Installing ripgrep... (2/43)
...
✓ Packages installed successfully (enhanced tier)

╔═══════════════════════════════════════════════════════════════╗
║ Step 5 of 7: Secrets Management
╠═══════════════════════════════════════════════════════════════╣
║ ██████████████░░░░░░ 71%
╚═══════════════════════════════════════════════════════════════╝

Scanning secrets...

Secrets Status:
  Local only (not in vault):
    • SSH-GitHub-Personal → ~/.ssh/id_ed25519_personal
    • AWS-Config → ~/.aws/config
    • Git-Config → ~/.gitconfig

Found 3 local secret(s) not in vault.
Push these to bitwarden so you can restore on other machines.

Push local secrets to vault? [Y/n]: y

  Creating SSH-GitHub-Personal... done
  Creating AWS-Config... done
  Creating Git-Config... done

✓ Pushed 3 secret(s) to vault

═══════════════════════════════════════════════════════════════
╔════════════════════════════════════════════════════════════╗
║              Setup Complete!                               ║
╚════════════════════════════════════════════════════════════╝

Next steps based on your configuration:

  ✓ Vault configured (bitwarden)
    → dotfiles vault validate    # Validate vault schema
    → dotfiles vault pull        # Restore your secrets

  ✓ Templates configured
    → dotfiles template render   # Generate configs

  ℹ Health check:
    → dotfiles doctor            # Verify everything works

  ℹ Explore commands:
    → dotfiles status            # Visual dashboard
    → dotfiles sync              # Smart bidirectional vault sync
    → dotfiles help              # See all commands

  ℹ Your new shell features:
    → ll, la, lt                 # Enhanced ls (eza with icons)
    → gst, gd, gco               # Git shortcuts
    → Ctrl+R                     # Fuzzy history search (fzf)
    → z [directory]              # Smart cd (learns your habits)
```

**What you get:**
- **Fully modular** - Everything optional except shell config. Use `--minimal` for just ZSH, or pick exactly what you need
- **Tiered packages** - Choose minimal (18), enhanced (43), or full (61) - or skip with `--minimal`
- **Smart credential onboarding** - Detects existing SSH/AWS/Git, offers to vault them
- **Smart bidirectional sync** - `dotfiles sync` auto-detects push/pull direction per file
- **Claude Code + dotclaude integration** - Profile sync, git safety hooks, portable sessions. Built for AI-assisted development
- **Resume support** - Interrupted? Just run `dotfiles setup` again

**5-minute setup. Works on macOS, Linux, WSL2, Docker.**

### Alternative: Try Before Installing

Test in a disposable Docker container (no installation):

```bash
docker run -it --rm ghcr.io/blackwell-systems/dotfiles:lite
```

See [Docker Guide](docs/docker.md) for container options.

---

## Claude Code + dotclaude

**These dotfiles integrate with [dotclaude](https://github.com/blackwell-systems/dotclaude)** - a profile manager for Claude Code that syncs your AI assistant configurations across machines.

**What dotclaude adds:**
- **Profile sync** - Work/personal/client profiles follow you everywhere
- **Git safety hooks** - Prevents dangerous commands (force push, hard reset) before Claude runs them
- **Session portability** - `/workspace` paths work identically on macOS/Linux/WSL2 (target is configurable)
- **Context isolation** - Keep work and personal projects separate

**Automatically installed during `dotfiles setup` (STEP 5).** Or install standalone:

```bash
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotclaude/main/install.sh | bash
```

**Learn more:** [github.com/blackwell-systems/dotclaude](https://github.com/blackwell-systems/dotclaude)

---

## Pick What You Want

**Everything is optional except shell config.** Use only the parts you need.

### Quick Install Options

```bash
# Full install (recommended for Claude Code users)
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash && dotfiles setup

# Minimal: Shell config only (no vault, no Claude integration, no packages)
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash -s -- --minimal

# Custom: Skip specific components with environment variables
SKIP_WORKSPACE_SYMLINK=true ./bootstrap/bootstrap-mac.sh  # Shell + packages, no /workspace
SKIP_CLAUDE_SETUP=true ./bootstrap/bootstrap-linux.sh     # Everything except Claude

# Custom workspace location (default: ~/workspace)
WORKSPACE_TARGET=~/code ./bootstrap/bootstrap-mac.sh      # Use ~/code as workspace
```

### Component Matrix

| Component | What It Does | How to Skip | Still Works Without It? |
|-----------|--------------|-------------|-------------------------|
| **Shell Config** | ZSH + plugins, prompt, aliases | **Cannot skip** (core) | N/A (required) |
| **Homebrew + Packages** | 18-61 CLI tools (tier selection in wizard) | `--minimal` flag or select tier in wizard | Yes - install tools manually |
| **Vault System** | Multi-backend secrets (Bitwarden/1Password/pass) | Select "Skip" in wizard or `--minimal` | Yes - manage secrets manually |
| **Portable Sessions** | `/workspace` symlink for Claude sync | `SKIP_WORKSPACE_SYMLINK=true` | Yes - use OS-specific paths |
| **Workspace Target** | Directory `/workspace` points to | `WORKSPACE_TARGET=~/code` | N/A (uses ~/workspace by default) |
| **Claude Integration** | dotclaude + hooks + settings | `SKIP_CLAUDE_SETUP=true` or `--minimal` | Yes - works without Claude |
| **Template Engine** | Machine-specific configs | Don't run `dotfiles template` | Yes - use static configs |

#### Brewfile Tiers (Choose Your Package Level)

The `dotfiles setup` wizard presents three package tiers **interactively** with real-time counts:

| Tier | Packages | Time | What's Included |
|------|----------|------|-----------------|
| **Minimal** | 18 packages | ~2 min | Essentials only (git, zsh, jq, shell plugins) |
| **Enhanced** | 43 packages | ~5 min | Modern CLI tools (fzf, ripgrep, bat, eza, etc.) **← RECOMMENDED** |
| **Full** | 61 packages | ~10 min | Everything including Docker, Node, advanced tools |

**How it works:**
- Setup wizard shows this menu with current package counts
- Your selection is saved in `~/.config/dotfiles/config.json`
- Re-running setup reuses your saved preference

**Advanced:** Bypass wizard with environment variable:
```bash
BREWFILE_TIER=enhanced ./bootstrap/bootstrap-mac.sh
```

### Modular By Design

**The feature registry controls all optional components:**

```bash
# See what's available and enabled
dotfiles features                         # List all features and status

# Enable/disable features
dotfiles features enable vault --persist  # Enable vault support
dotfiles features disable drift_check     # Turn off drift checking

# Apply presets for quick setup
dotfiles features preset minimal          # Just shell (fastest)
dotfiles features preset developer        # vault, aws_helpers, git_hooks, modern_cli
dotfiles features preset claude           # Claude Code optimized
dotfiles features preset full --persist   # Everything, saved to config
```

**Enable features later if you change your mind:**

```bash
# Started with --minimal? Add vault later:
dotfiles setup                    # Run wizard, select vault backend

# Want portable sessions now?
sudo ln -sfn ~/workspace /workspace  # Or use WORKSPACE_TARGET=~/code for custom location

# Install missing packages:
dotfiles packages --install       # Uses Brewfile

# Setup templates:
dotfiles template init            # Configure machine variables
dotfiles template render          # Generate configs
```

**Use in offline/air-gapped environments:**

```bash
DOTFILES_OFFLINE=1 ./bootstrap/bootstrap-linux.sh    # Skips all vault operations
DOTFILES_SKIP_DRIFT_CHECK=1 dotfiles vault pull   # No drift check (for CI/automation)
```

**All setup wizard steps are optional.** The wizard detects your choices and adjusts:
- No vault CLI? Offers to skip vault entirely
- Vault configured but want to skip secrets? Just say no
- Don't want Claude integration? Skip that step

**Philosophy:** Start minimal, add what you need, when you need it.

---

## Framework Architecture

**Three core systems provide the foundation:**

```
┌─────────────────────────────────────────────────────────────┐
│                    Feature Registry                          │
│                   (lib/_features.sh)                         │
│  Controls what's enabled/disabled, resolves dependencies,   │
│  persists state, provides presets                           │
└─────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌─────────────────────────┐   ┌───────────────────────────┐
│  Configuration Layers   │   │  Claude Code Integration  │
│ (lib/_config_layers.sh) │   │  (claude/, /workspace)    │
│  5-layer priority for   │   │  Portable sessions,       │
│  all settings           │   │  dotclaude, git hooks     │
└─────────────────────────┘   └───────────────────────────┘
```

**1. Feature Registry** – Central control plane for all functionality. Enable/disable features, resolve dependencies, apply presets (minimal, developer, claude, full).

**2. Configuration Layers** – 5-layer priority system: Environment → Project → Machine → User → Defaults. Settings come from the right place automatically.

**3. Claude Code Integration** – Portable sessions via `/workspace` symlink, vault-synced profiles with [dotclaude](https://github.com/blackwell-systems/dotclaude), git safety hooks, multi-backend support (Anthropic Max, AWS Bedrock, Google Vertex).

**Additional capabilities:**

- **Hook System** – 19 lifecycle hooks for custom behavior (vault sync, shell init, doctor checks)
- **Multi-Vault Backend** – Bitwarden, 1Password, or pass with unified API
- **Self-Healing** – `dotfiles doctor --fix` repairs permissions and symlinks
- **Machine Templates** – Generate machine-specific configs from templates
- **Adaptive CLI** – Help and tab completion adjust based on enabled features

---

## Features

<details>
<summary><b>View All Features (24)</b></summary>

### Framework Systems

<details>
<summary><b>Feature Registry</b> - Central control plane for all functionality</summary>

```bash
dotfiles features              # List all features with status
dotfiles features enable X     # Enable a feature
dotfiles features preset Y     # Apply preset (minimal/developer/claude/full)
```

The Feature Registry (`lib/_features.sh`) controls what's enabled/disabled across the system. Features can depend on other features (e.g., `claude_integration` requires `workspace_symlink`). Dependencies are resolved automatically.

**Presets:**
- `minimal` - Shell config only
- `developer` - Shell + vault + AWS helpers + git hooks + modern CLI
- `claude` - Developer preset + Claude Code integration
- `full` - All features enabled

**Persistence:** Use `--persist` flag to save settings across shell restarts.

</details>

<details>
<summary><b>Configuration Layers</b> - 5-layer priority hierarchy for settings</summary>

```bash
dotfiles config layers         # Show all config with sources
dotfiles config get vault.backend
```

Settings resolve through 5 layers (highest to lowest priority):

1. **Environment** - `$DOTFILES_*` variables (CI/CD, temporary overrides)
2. **Project** - `.dotfiles.local` in current directory
3. **Machine** - `~/.config/dotfiles/machine.json` (per-machine settings)
4. **User** - `~/.config/dotfiles/config.json` (user preferences)
5. **Defaults** - Built-in fallbacks

This allows machine-specific overrides without editing the main config, project-level settings for repositories, and environment-based CI/CD configuration.

</details>

<details>
<summary><b>Claude Code Integration</b> - Portable AI-assisted development</summary>

```bash
dotfiles setup     # Step 6: Claude Code integration
dotfiles doctor    # Validates Claude setup
```

**Portable sessions:** `/workspace` symlink provides consistent paths across machines, so Claude Code conversations continue seamlessly between macOS, Linux, and WSL2.

**Profile management:** Integrates with [dotclaude](https://github.com/blackwell-systems/dotclaude) for managing multiple Claude contexts (work, personal, client projects). Profiles sync via vault.

**Git safety hooks:** PreToolUse hook blocks dangerous commands like `git push --force`. SessionStart hook validates branch sync status.

**Multi-backend:** Works with Anthropic Max, AWS Bedrock, and Google Vertex AI.

</details>

<details>
<summary><b>Hook System</b> - Custom behavior at lifecycle points</summary>

```bash
dotfiles hook list              # Show all available hook points
dotfiles hook list post_vault_pull  # Show hooks for specific point
dotfiles hook test post_vault_pull  # Dry-run hooks
```

**19 lifecycle hooks** let you inject custom scripts at key moments:

| Hook Point | When | Example Use |
|------------|------|-------------|
| `post_vault_pull` | After secrets restored | Fix SSH permissions, run ssh-add |
| `post_install` | After bootstrap | Install extra packages |
| `pre_doctor` | Before health check | Custom validations |
| `shell_init` | Shell startup | Load project-specific env |

**Creating a hook:**
```bash
mkdir -p ~/.config/dotfiles/hooks/post_vault_pull
cat > ~/.config/dotfiles/hooks/post_vault_pull/10-ssh-agent.sh << 'EOF'
#!/bin/bash
ssh-add ~/.ssh/id_ed25519 2>/dev/null
EOF
chmod +x ~/.config/dotfiles/hooks/post_vault_pull/10-ssh-agent.sh
```

Hooks run in numeric order (10-*, 20-*, etc.). [Full documentation](docs/hooks.md)

</details>

<details>
<summary><b>Portable Workspace</b> - Consistent paths across machines</summary>

```bash
# Default setup
/workspace → ~/workspace

# Custom target directory
WORKSPACE_TARGET=~/code ./install.sh
# Result: /workspace → ~/code
```

**The problem:** Claude Code session folders are based on absolute paths:
- macOS: `/Users/you/projects/app` → session `Users-you-projects-app`
- Linux: `/home/you/projects/app` → session `home-you-projects-app`

Different paths = different sessions = lost conversation history.

**The solution:** `/workspace` symlink provides the same absolute path everywhere:
- All machines: `/workspace/app` → session `workspace-app` ✨

**Customization:** Set `WORKSPACE_TARGET=~/code` to point the symlink at a different directory. The `/workspace` path stays consistent for portability.

**Skip if:** Single-machine setup or no Claude Code: `SKIP_WORKSPACE_SYMLINK=true`

</details>

### Core Features

<details>
<summary><b>Interactive Setup Wizard</b> - One command, complete setup</summary>

```bash
dotfiles setup  # Guides you through everything
```

Auto-detects your platform (macOS, Linux, WSL2), detects available vault CLIs (Bitwarden, 1Password, pass), prompts you to choose. Option to skip vault entirely for minimal setups. One command handles bootstrap, vault selection, secret restoration, and health validation. Progress is saved—resume anytime if interrupted.

**Visual progress tracking (v3.0+):** Unicode progress bars show your current step with percentage completion:
```
╔═══════════════════════════════════════════════════════════════╗
║ Step 4 of 7: Vault Configuration
╠═══════════════════════════════════════════════════════════════╣
║ ██████████░░░░░░░░░░ 57%
╚═══════════════════════════════════════════════════════════════╝
```

**State persistence:** If interrupted, just run `dotfiles setup` again—it picks up where you left off.

</details>

<details>
<summary><b>Smart Secrets Onboarding</b> - Auto-discovery & guided vault setup</summary>

```bash
dotfiles vault setup       # Configure vault backend
dotfiles vault scan   # Auto-detect existing secrets
```

**Auto-Discovery** - Automatically finds your existing secrets:
- Scans `~/.ssh/` for SSH keys (all types: rsa, ed25519, ecdsa)
- Discovers AWS configs (`~/.aws/config`, `~/.aws/credentials`)
- Finds Git config (`~/.gitconfig`)
- Detects other secrets (npm, pypi, docker configs)
- Generates `vault-items.json` with smart naming (e.g., `id_ed25519_github` → `SSH-GitHub`)
- Supports custom paths: `--ssh-path` and `--config-path` options

**Manual Setup** - For non-standard configurations:
- Copy example: `cp vault/vault-items.example.json ~/.config/dotfiles/vault-items.json`
- Edit to match your setup
- Validates schema before sync

Perfect for users with existing credentials who want to sync them across machines with zero manual JSON editing.

</details>

<details>
<summary><b>Multi-Vault Secrets</b> - Choose your vault backend</summary>

```bash
export DOTFILES_VAULT_BACKEND=bitwarden  # or 1password, pass
dotfiles sync              # Smart bidirectional sync (auto push/pull)
dotfiles vault push --all  # Push local secrets to vault
dotfiles vault pull        # Pull secrets on new machine
dotfiles vault validate    # Validate configuration schema (v3.0+)
```

Unified API across Bitwarden, 1Password, and pass. Syncs SSH keys, AWS credentials, Git config, environment secrets. **Smart bidirectional sync** automatically detects which direction each item needs (local→vault or vault→local). Drift detection warns before overwrites.

**Schema validation (v3.0+):** Automatic validation before all sync operations catches configuration errors early. Validates JSON syntax, required fields, type values, and naming conventions. Interactive error recovery offers to open your editor for immediate fixes.

**What credentials can I store?**

All credential types are stored as vault items (secure notes):

- **SSH Keys** - Private/public key pairs with optional passphrases, SSH config file
- **Cloud Credentials** - AWS config and credentials (extensible to GCP, Azure)
- **Development Tools** - Git configuration (name, email, signing keys), environment secrets (API keys, tokens)
- **AI Tools** - Claude Code profiles (optional)

[Complete list and vault item formats →](vault/README.md#vault-items-complete-list)

</details>

<details>
<summary><b>Age Encryption</b> - Encrypt non-vault secrets</summary>

```bash
dotfiles encrypt init              # Generate age key pair
dotfiles encrypt <file>            # Encrypt a file
dotfiles encrypt decrypt <file>    # Decrypt a file
dotfiles encrypt edit <file>       # Decrypt, edit, re-encrypt
dotfiles encrypt push-key          # Backup key to vault
```

**The problem:** Vault stores secrets remotely, but some files need to be committed to git (template variables, local configs with emails/signing keys).

**The solution:** `age` encryption for files that live in your repo:
- Template variables (`_variables.local.sh`) with emails, signing keys
- Local config files with hostnames, IPs
- Any `*.secret` or `*.private` files

**Workflow:**
```bash
# Encrypt and commit
dotfiles encrypt templates/_variables.local.sh
git add templates/_variables.local.sh.age
git commit -m "Add encrypted template vars"

# On new machine
dotfiles vault pull          # Restores age key via hook
dotfiles template render     # Auto-decrypts via hook
```

**Key insight:** Vault is for secrets that live remotely. Encryption is for secrets that live in git.

</details>

<details>
<summary><b>Claude Code Integration</b> - Resume conversations anywhere</summary>

```bash
# On macOS
cd /workspace/my-project && claude
# ... work, exit ...

# On Linux - SAME conversation!
cd /workspace/my-project && claude
```

The `/workspace` symlink creates identical paths across platforms. Claude Code session folders match everywhere. Start on Mac, continue on Linux, full history intact. Multiple backends: Anthropic Max (consumer) or AWS Bedrock (enterprise SSO). No other dotfiles does this.

**Custom workspace:** Set `WORKSPACE_TARGET=~/code` to use a different directory (symlink still points to `/workspace`).

**Auto-redirect:** The `claude` wrapper detects `~/workspace/*` and automatically redirects to `/workspace/*` with an educational message.

</details>

### Safety & Reliability

<details>
<summary><b>Self-Healing Configuration</b> - Never breaks</summary>

```bash
dotfiles doctor           # Validate everything
dotfiles doctor --fix     # Auto-repair issues
dotfiles drift            # Check local vs vault
```

Validates symlinks, SSH keys (permissions 600/644), AWS config, vault status, shell setup. Auto-repair fixes permissions, broken symlinks, missing dependencies. Drift detection catches unsync'd changes before switching machines.

**Metrics collection:** Tracks health over time in `~/.dotfiles-metrics.jsonl` for trend analysis.

</details>

<details>
<summary><b>Git Safety Hooks</b> - Prevent disasters</summary>

**Blocked commands:**
- `git push --force origin main`
- `git reset --hard` (without confirmation)
- `git clean -f` (removes untracked files)
- `git rebase -i` (not supported in non-interactive environments)

**SessionStart hook:** Fetches latest from remote and warns if branch has diverged.

Pre-commit and pre-push hooks catch accidents before they happen. Configurable per-repository. [Setup guide](docs/claude-code.md)

</details>

<details>
<summary><b>Comprehensive Testing</b> - 124 tests and counting</summary>

```bash
./test/run_tests.sh          # All tests
./test/run_tests.sh unit     # Unit tests only
./test/run_tests.sh error    # Error scenarios
```

**Test coverage:**
- 32 dotclaude integration tests
- 23 vault function tests
- 22 error scenarios (permissions, missing files, edge cases)
- 21 integration tests (mock Bitwarden, backup cycles)
- 16 CLI command tests
- 10 template engine tests

CI runs shellcheck, zsh validation, all tests on every push. Code coverage via kcov + Codecov.

</details>

### Advanced Features

<details>
<summary><b>Machine-Specific Templates</b> - One config, many machines</summary>

```bash
dotfiles template init    # Setup machine variables
dotfiles template render  # Generate configs from templates
dotfiles template link    # Symlink generated configs to destinations
```

**The Problem:** You have work laptop, personal desktop, home server. Each needs different:
- Git email (`work@company.com` vs `personal@gmail.com`)
- SSH config (different keys per machine)
- Environment variables (dev vs prod API keys)
- Shell aliases (work-specific commands)

**The Solution:** One template file → Multiple machine-specific configs

### Real-World Examples

**Example 1: Git Config Per Machine**

Template file: `templates/configs/gitconfig.tmpl`
```ini
[user]
    name = {{ GIT_USER_NAME }}
    email = {{ GIT_EMAIL }}
{{#if GIT_SIGNING_KEY}}
    signingkey = {{ GIT_SIGNING_KEY }}
{{/if}}

[core]
    editor = {{ EDITOR | default="vim" }}

{{#if IS_WORK_MACHINE}}
[includeIf "gitdir:~/work/"]
    path = ~/.gitconfig-work
{{/if}}
```

Variables file: `templates/_variables_work-laptop.sh`
```bash
export GIT_USER_NAME="John Doe"
export GIT_EMAIL="john.doe@company.com"
export GIT_SIGNING_KEY="ABC123DEF456"
export IS_WORK_MACHINE="true"
export EDITOR="code"
```

Result: `generated/gitconfig` (different per machine)

**Example 2: SSH Config With Per-Machine Keys**

Template: `templates/configs/ssh-config.tmpl`
```
{{#each SSH_HOSTS}}
Host {{ this.name }}
    HostName {{ this.hostname }}
    User {{ this.user }}
    IdentityFile {{ this.key }}
{{/each}}
```

Variables: `templates/_variables_personal.sh`
```bash
export SSH_HOSTS='[
    {"name": "github", "hostname": "github.com", "user": "git", "key": "~/.ssh/id_ed25519_personal"},
    {"name": "homelab", "hostname": "192.168.1.100", "user": "admin", "key": "~/.ssh/id_rsa_homelab"}
]'
```

**Example 3: Machine-Specific Environment Variables**

Template: `templates/configs/env.secrets.tmpl`
```bash
# API Keys (different per environment)
export OPENAI_API_KEY="{{ OPENAI_API_KEY }}"
export ANTHROPIC_API_KEY="{{ ANTHROPIC_API_KEY }}"

{{#if IS_WORK_MACHINE}}
# Work-specific secrets
export COMPANY_VPN_TOKEN="{{ COMPANY_VPN_TOKEN }}"
export AWS_PROFILE="work"
{{else}}
# Personal secrets
export AWS_PROFILE="personal"
{{/if}}
```

### Quick Start

```bash
# 1. Initialize template system (creates _variables.local.sh)
dotfiles template init

# 2. Edit your variables
vim ~/.config/dotfiles/templates/_variables.local.sh

# 3. Generate configs from templates
dotfiles template render

# 4. Link generated configs to their destinations
dotfiles template link

# 5. Check for stale templates (template newer than generated file)
dotfiles doctor  # Shows: "3 templates need re-rendering"
```

### Auto-Detected Variables

Available in all templates without manual definition:
- `{{ HOSTNAME }}` - Machine hostname
- `{{ OS }}` - `macos`, `linux`, or `windows`
- `{{ USER }}` - Current username
- `{{ HOME }}` - Home directory path
- `{{ WORKSPACE }}` - Workspace directory

### Use Cases

**Work vs Personal:**
- Different git emails, SSH keys, AWS profiles
- Work machine has VPN config, personal doesn't
- Different editor settings

**Multi-Cloud:**
- Dev machine: staging AWS keys
- Prod machine: production AWS keys (via separate template variables)

**Team Onboarding:**
- New developer clones dotfiles
- Runs `dotfiles template init` with their name/email
- All configs generate with their info

[Complete Template Guide →](docs/templates.md)

</details>

<details>
<summary><b>dotclaude Integration</b> - Profile management meets secrets management</summary>

```bash
# Switch Claude contexts while keeping secrets synced
dotclaude activate client-work
dotfiles vault pull     # Secrets follow your profile

# Profiles managed by dotclaude, secrets by dotfiles
# Both use /workspace for portability
```

Seamless integration with [dotclaude](https://github.com/blackwell-systems/dotclaude). dotclaude manages Claude profiles (CLAUDE.md, agents, standards). dotfiles manages secrets (SSH, AWS, Git). Switch between OSS, client, and work contexts while vault secrets stay synced. Both respect `/workspace` paths for portable sessions (target directory is configurable via `WORKSPACE_TARGET`).

[Integration Guide](docs/DOTCLAUDE-INTEGRATION.md)

</details>

<details>
<summary><b>Backup & Restore</b> - Time-travel for your dotfiles</summary>

```bash
dotfiles backup           # Create timestamped backup
dotfiles backup --list    # Show available backups
dotfiles backup restore   # Interactive restore
```

Timestamped tar.gz archives in `~/.dotfiles-backups/`. Includes all dotfiles, configs, optional secrets. Interactive restore with preview. Auto-cleanup keeps only 10 most recent.

</details>

### Tools & Utilities

<details>
<summary><b>Unified CLI Interface</b> - Everything under one command</summary>

```bash
dotfiles status    # Visual dashboard
dotfiles doctor    # Health check
dotfiles vault     # Secret management
dotfiles template  # Config generation
dotfiles backup    # Backup/restore
dotfiles packages  # Package management
dotfiles help      # Full command list
```

Consistent flags across all subcommands. Full tab completion for commands, flags, and context-aware arguments.

[CLI Reference](docs/cli-reference.md)

</details>

<details>
<summary><b>Modern CLI Stack</b> - Batteries included</summary>

```bash
eza      # Modern ls with icons, git status
fzf      # Fuzzy finder (Ctrl+R, Ctrl+T, Alt+C)
rg       # ripgrep - fast grep
z        # zoxide - smart cd
bat      # cat with syntax highlighting
yazi     # Terminal file manager
glow     # Markdown renderer
dust     # Visual disk usage
```

All configured and ready. Lazy-loaded for fast shell startup (< 100ms). Unified keybindings work out of the box.

</details>

<details>
<summary><b>AWS Workflow Helpers</b> - SSO made simple</summary>

```bash
awsswitch     # Interactive profile picker (auto-login)
awsprofiles   # List all profiles
awswho        # Current identity (account, user, ARN)
awsassume     # Assume role
```

`awsswitch` detects expired SSO and runs `aws sso login` automatically. Fuzzy search profiles, auto-login if expired. Makes multi-account workflows painless.

</details>

<details>
<summary><b>Package Management</b> - Keep tools in sync</summary>

```bash
dotfiles packages            # Check Brewfile status
dotfiles packages --install  # Install missing packages
```

Shows which Brewfile packages are installed, missing, or outdated. Works across macOS (Homebrew) and Linux (Linuxbrew). Unified Brewfile means same tools everywhere. Supports conditional packages (macOS-only casks, Linux-only tools).

</details>

<details>
<summary><b>Developer Tools Integrations</b> - 90+ aliases across all major toolchains</summary>

Comprehensive productivity integrations for AWS, CDK, Rust, Go, Python, Node.js (NVM), and Java (SDKMAN). All features are opt-in via Feature Registry.

**AWS Tools** (`aws_helpers`):
```bash
awsswitch      # Interactive profile picker with auto-login
awsprofiles    # List all profiles
awswho         # Current identity (account, user, ARN)
awsassume      # Assume role
awslogin       # SSO login with profile picker
```

**CDK Tools** (`cdk_tools`): 10 aliases + helpers for AWS CDK deployments (`cdkd`, `cdks`, `cdkdf`, `cdkw`), stack management, hotswap deploys

**Rust Tools** (`rust_tools`): 10 aliases for cargo workflows (`cb`, `cr`, `ct`, `cc`, `cf`), toolchain switching, expand macros, outdated checks

**Go Tools** (`go_tools`): 9 aliases for Go development (`gob`, `gor`, `got`, `gof`, `gom`), coverage, benchmarks, linting

**Python Tools** (`python_tools`):
- **uv** integration: 10 aliases for fast package management (`uvs`, `uvr`, `uva`, `uvl`, `uvu`)
- **pytest** integration: 8 aliases (`pt`, `ptv`, `ptx`, `ptc`, `pts`)
- **Auto-venv**: Prompts to activate virtualenv on `cd` (configurable: notify/auto/off)

**NVM** (`nvm_integration`): Lazy-loaded Node.js version management, auto-switches based on `.nvmrc`

**SDKMAN** (`sdkman_integration`): Lazy-loaded Java SDK management (Java, Gradle, Maven, Kotlin, Scala, etc.)

All tools include shell completions and helper functions. See [Developer Tools Documentation](docs/developer-tools.md) for full reference.

Enable individual tools:
```bash
dotfiles features enable rust_tools
dotfiles features enable python_tools
# Or use presets:
dotfiles features preset developer  # Enables all dev tools
```

</details>

### Additional Features

<details>
<summary><b>Modular Shell Config</b> - Organized, not monolithic</summary>

```
zsh.d/
├── 00-init.zsh          # Powerlevel10k, OS detection
├── 10-plugins.zsh       # Plugin loading
├── 20-env.zsh           # Environment variables
├── 30-tools.zsh         # CLI tool configs
├── 40-aliases.zsh       # Aliases
├── 50-functions.zsh     # Shell functions
├── 60-aws.zsh           # AWS helpers
├── 70-claude.zsh        # Claude wrapper
├── 80-git.zsh           # Git shortcuts
├── 90-integrations.zsh  # Tool integrations
└── 99-local.zsh         # Machine-specific (gitignored)
```

Each module < 150 lines, focused, testable. Easy to enable/disable or customize per-machine.

</details>

<details>
<summary><b>Cross-Platform Portability</b> - 90% shared, 10% platform-specific</summary>

**Supported platforms:** macOS, Linux, Windows (Git Bash/MSYS2), WSL2, Lima, Docker

Platform detection auto-adapts (macOS uses `pbcopy`, Linux uses `xclip`/`wl-copy`). Brewfile works on both Homebrew and Linuxbrew. One codebase, many platforms. Vault system, health checks, CLI tools—all platform-independent. Adding a new platform takes ~30 lines.

</details>

<details>
<summary><b>Metrics & Observability</b> - Track health over time</summary>

```bash
dotfiles doctor    # Auto-collects metrics
dotfiles metrics   # Visualize trends
```

Writes to `~/.dotfiles-metrics.jsonl`: timestamp, hostname, OS, errors, warnings, fixes, health score (0-100), git branch/commit. ASCII graphs show health trends. Track average score, total errors/warnings, perfect run percentage.

</details>

<details>
<summary><b>Clean Uninstall</b> - Leave no trace</summary>

```bash
dotfiles uninstall                # Full removal
dotfiles uninstall --dry-run      # Preview only
dotfiles uninstall --keep-secrets # Keep SSH/AWS/Git
```

Removes all dotfiles, symlinks, configurations. Interactive confirmation prevents accidents. Dry-run shows exactly what would be deleted.

</details>

<details>
<summary><b>Idempotent Design</b> - Safe to run anytime</summary>

Bootstrap scripts check current state before changes. Already symlinked? Skip. Already installed? Skip. Wrong target? Fix it. Safe to re-run after updates, failed installs, or manual changes. No destructive operations without confirmation.

</details>

---

**→ [View detailed feature documentation](docs/README-FULL.md#features)**

</details>

---

## Use Cases

**Perfect for:**

- **Claude Code users** working across macOS, Linux, and WSL2 with session portability
- **Team onboarding** - New developer setup in < 5 minutes with vault-backed credentials
- **Multi-cloud workflows** - AWS SSO, multiple profiles, automatic credential rotation
- **Security-conscious developers** - Multi-vault backends, schema validation, drift detection
- **CI/CD environments** - Docker containers, offline mode, state management

**Also great for:**

- Developers tired of manually copying SSH keys between machines
- Teams that need consistent tooling across heterogeneous environments
- Anyone managing multiple AWS accounts with SSO
- DevOps engineers who need reproducible, testable configurations

---

## Prerequisites

**Required:**
- A computer running macOS, Linux, Windows (Git Bash/MSYS2), or WSL2
- Internet access (for installing packages)

**Auto-installed:**
- Git (via Xcode tools on macOS or apt on Linux)
- Homebrew/Linuxbrew (bootstrap will install)
- Modern CLI tools (eza, fzf, ripgrep, etc. via Brewfile)

**Optional (for vault features only):**
- **Vault CLI** - Bitwarden (`bw`), 1Password (`op`), or pass for automated secret sync
  - Skip with `--minimal` flag (or just don't run `dotfiles vault` commands)
  - Without vault: manually configure `~/.ssh`, `~/.aws`, `~/.gitconfig`

**Optional (for Claude Code portable sessions):**
- **Claude Code installed** - For cross-machine session sync
  - Skip with `SKIP_CLAUDE_SETUP=true`

**Optional (Brewfile package tiers):**
The `dotfiles setup` wizard presents three package tiers interactively:
  - `minimal` - Essential tools only (18 packages, ~2 min)
  - `enhanced` - Modern CLI tools without containers (43 packages, ~5 min) **← RECOMMENDED**
  - `full` - Everything including Docker/Kubernetes (61 packages, ~10 min) [default]

Your selection is saved in `~/.config/dotfiles/config.json` and reused if you re-run setup.

**Advanced users:** Set `BREWFILE_TIER` environment variable to bypass interactive selection.

To clone via SSH (recommended), you'll also want an SSH key configured with GitHub. If you don't have Git yet, the bootstrap scripts will install it automatically.

---

## Quick Start

### One-Line Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash && dotfiles setup
```

The install script clones the repository and runs bootstrap. Then `dotfiles setup` guides you through:
- Platform detection and configuration
- Vault selection (Bitwarden, 1Password, pass, or skip)
- Secret restoration (SSH keys, AWS, Git config)
- Claude Code integration

Progress is saved—resume anytime if interrupted.

### Minimal Mode (No Vault)

Shell config only, no secrets integration:

```bash
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash -s -- --minimal
```

**You still get:** Zsh + Powerlevel10k, all CLI tools (eza, fzf, ripgrep, etc.), aliases, functions, and the `dotfiles` command.

**To enable vault later:** Run `dotfiles setup`

### Manual Clone

```bash
# 1. Clone (to your workspace directory - defaults to ~/workspace)
git clone git@github.com:blackwell-systems/dotfiles.git ~/workspace/dotfiles
cd ~/workspace/dotfiles

# Or use a custom workspace location
WORKSPACE_TARGET=~/code git clone git@github.com:blackwell-systems/dotfiles.git ~/code/dotfiles

# 2. Run platform bootstrap
./bootstrap/bootstrap-mac.sh   # macOS
./bootstrap/bootstrap-linux.sh # Linux/WSL

# 3. Run interactive setup wizard
dotfiles setup
```

> **💡 Why `/workspace` symlink?**
>
> Bootstrap creates `/workspace → ~/workspace` symlink to enable **Claude Code session portability** across machines.
>
> **The problem:** Claude Code uses absolute paths for session folders. Without the symlink:
> - macOS: `/Users/you/workspace/dotfiles` → session `Users-you-workspace-dotfiles`
> - Linux: `/home/you/workspace/dotfiles` → session `home-you-workspace-dotfiles`
> - Different paths = different sessions = **lost conversation history** when switching machines
>
> **The solution:** `/workspace` is the same absolute path everywhere:
> - All machines: `/workspace/dotfiles` → session `workspace-dotfiles` ✨
> - Same session folder across macOS, Linux, WSL2 = **full history syncs**
>
> **Customization:** The target directory is configurable via `WORKSPACE_TARGET=~/code` - the `/workspace` symlink name stays the same for portability.
>
> **Skip if:** You only use one machine or don't use Claude Code (`SKIP_WORKSPACE_SYMLINK=true`)
>
> [Learn more](docs/README-FULL.md#canonical-workspace-workspace)

---

## What Gets Installed

### Shell & Prompt
- Zsh with Powerlevel10k theme
- Auto-suggestions and syntax highlighting
- Modern CLI replacements (eza, bat, fd, ripgrep)

### Development Tools
- Homebrew package manager
- Git, GitHub CLI, Node.js
- Docker, Lima (Linux VM)
- AWS CLI, Vault CLI (Bitwarden/1Password/pass)

### Configurations
- SSH keys and config (from vault)
- AWS credentials and config (from vault)
- Git configuration (from vault)
- Environment secrets (from vault)
- Claude Code settings (shared workspace)

See [Brewfile](Brewfile) for complete package list.

---

## Documentation

- **[Complete Guide](docs/README-FULL.md)** - Everything in detail (2,300+ lines)
- **[Vault System](docs/vault-README.md)** - Multi-backend secrets management
- **[Backup System](docs/backup.md)** - Snapshot and restore configuration
- **[Hook System](docs/hooks.md)** - Lifecycle hooks for custom behavior
- **[Developer Tools](docs/developer-tools.md)** - AWS, CDK, Rust, Go, Python, NVM, SDKMAN integrations
- **[Configuration Layers](docs/configuration-layers.md)** - Hierarchical config resolution
- **[Templates](docs/templates.md)** - Machine-specific configuration
- **[Architecture](docs/architecture.md)** - System design and components
- **[CLI Reference](docs/cli-reference.md)** - All commands and flags
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions
- **[Test Drive Guide](docs/TESTDRIVE.md)** - Try in Docker before installing
- **[dotclaude Integration](docs/DOTCLAUDE-INTEGRATION.md)** - Profile management
- **[State Management](docs/state-management.md)** - Setup wizard internals

**GitHub Pages:** [https://blackwell-systems.github.io/dotfiles/](https://blackwell-systems.github.io/dotfiles/)

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| macOS (Apple Silicon) | Fully tested | Primary development environment |
| macOS (Intel) | Fully tested | Auto-detects architecture |
| Lima (Ubuntu 24.04) | Fully tested | Recommended Linux VM for macOS |
| WSL2 (Windows) | Auto-detected | Uses Linux bootstrap |
| Windows (Git Bash/MSYS2) | Native support | Uses Windows bootstrap |
| Ubuntu/Debian | Compatible | Tested on Ubuntu 24.04 |
| Arch/Fedora/BSD | Experimental | 15-30 min adaptation needed |

---

## How This Compares

<details>
<summary><b>Comparison vs chezmoi, thoughtbot, holman, and other dotfiles</b></summary>

### Quick Comparison: This Repo vs Typical Dotfiles

| Capability           | This Repo                                      | Typical Dotfiles                 |
|----------------------|-----------------------------------------------|----------------------------------|
| **Feature Registry** | Central control plane with presets              | None                             |
| **Configuration Layers** | 5-layer priority (env/project/machine/user/defaults) | Single config file        |
| **Claude Code Integration** | Portable sessions, dotclaude, git hooks   | None                             |
| **Secrets management** | Multi-vault (Bitwarden, 1Password, pass)      | Manual copy between machines     |
| **Health validation**  | Checker with `--fix`                          | None                             |
| **Drift detection**    | Compare local vs vault state                  | None                             |
| **Schema validation**  | Validates SSH keys & config structure         | None                             |
| **Unit tests**         | 124+ bats-core tests                          | Rare                             |
| **Docker support**     | 4 container sizes for testing                 | Rare                             |
| **Modular shell config** | 10 modules in `zsh.d/`                      | Single monolithic file           |
| **Optional components** | Feature Registry with presets                | All-or-nothing                   |
| **Cross-platform**     | macOS, Linux, Windows, WSL2, Docker           | Usually single-platform          |

### Why This Repo vs chezmoi?

chezmoi is the most popular dotfiles manager. Here's how we compare:

| Feature | This Repo | chezmoi |
|---------|-----------|---------|
| **Feature Registry** | Central control plane with presets | None |
| **Configuration Layers** | 5-layer priority system | `.chezmoi.toml` only |
| **Claude Code Integration** | Portable sessions, dotclaude, git hooks | None |
| **Secret Management** | 3 vault backends (bw/op/pass) with unified API | External tools only (no unified API) |
| **Bidirectional Sync** | Local ↔ Vault | Templates only (one-way) |
| **Health Checks** | Yes, with auto-fix | None |
| **Drift Detection** | Local vs Vault comparison | `chezmoi diff` (files only) |
| **Schema Validation** | SSH keys, configs | None |
| **Machine Templates** | Custom engine | Go templates |
| **Cross-Platform** | 5 platforms + Docker | Excellent |
| **Learning Curve** | Shell scripts | YAML + Go templates |

### Detailed Comparison vs Popular Dotfiles

| Feature | This Repo | thoughtbot | holman | mathiasbynens | YADR |
|---------|-----------|------------|--------|---------------|------|
| **Feature Registry** | Central control plane | No | No | No | No |
| **Configuration Layers** | 5-layer priority | No | No | No | No |
| **Claude Code Integration** | Portable sessions, dotclaude, git hooks | No | No | No | No |
| **Secrets Management** | Multi-vault (bw/op/pass) | Manual | Manual | Manual | Manual |
| **Bidirectional Sync** | Local ↔ Vault | No | No | No | No |
| **Cross-Platform** | macOS, Linux, Windows, WSL2, Docker | Limited | macOS only | macOS only | Limited |
| **Health Checks** | Yes, with auto-fix | No | No | No | No |
| **Drift Detection** | Local vs Vault | No | No | No | No |
| **Schema Validation** | SSH keys, configs | No | No | No | No |
| **Unit Tests** | 124+ bats tests | No | No | No | No |
| **CI/CD Integration** | GitHub Actions | Basic | No | No | No |
| **Modular Shell Config** | 10 modules | Monolithic | Monolithic | Monolithic | Partial |
| **Docker Bootstrap** | 4 container sizes | No | No | No | No |
| **One-Line Installer** | Interactive mode | Basic | No | No | Yes |
| **Documentation Site** | Docsify (searchable) | README only | README only | README only | Wiki |
| **Active Maintenance** | 2025 | Sporadic | Archived | Sporadic | Minimal |

### What Makes This Unique

1. **Only dotfiles built for Claude Code** - Portable sessions, dotclaude profiles, git safety hooks, multi-backend support
2. **Only dotfiles with Feature Registry architecture** - Central control plane with presets and dependency resolution
3. **Only dotfiles with Configuration Layers** - 5-layer priority system (env → project → machine → user → defaults)
4. **Only dotfiles with multi-vault backend support** - Bitwarden, 1Password, or pass with unified API
5. **Only dotfiles with comprehensive health checks** - Validator with auto-fix
6. **Only dotfiles with drift detection** - Compare local vs vault state
7. **Only dotfiles with schema validation** - Ensures SSH keys/configs are valid before restore
8. **Only dotfiles with Docker bootstrap testing** - Reproducible CI/CD environments
9. **Only dotfiles with machine-specific templates** - Auto-generate configs for work vs personal machines

</details>

---

## Common Tasks

### Update Dotfiles

```bash
dotfiles upgrade  # Pull latest, run bootstrap, check health
```

### Sync Secrets

```bash
# Update SSH config locally, then sync to vault
vim ~/.ssh/config
dotfiles vault push SSH-Config

# View what would be synced (dry run)
dotfiles vault push --dry-run --all
```

### Add New SSH Key

```bash
# 1. Generate key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_newkey

# 2. Add to vault config
vim ~/.config/dotfiles/vault-items.json

# 3. Sync to vault
dotfiles vault push SSH-GitHub-NewKey

# 4. Update SSH config
vim ~/.ssh/config
dotfiles vault push SSH-Config
```

See [Maintenance Checklists](docs/README-FULL.md#maintenance-checklists) for more.

---

## Troubleshooting

<details>
<summary><b>Quick Fixes & Common Issues</b></summary>

### Quick Fixes

```bash
# Run diagnostics
dotfiles doctor          # Check all systems
dotfiles doctor --fix    # Auto-repair issues
dotfiles status          # Visual dashboard
```

### Common Issues

**SSH keys not working:**
```bash
dotfiles doctor --fix    # Fix permissions
ssh-add -l               # Verify keys loaded
ssh -T git@github.com    # Test connection
```

**Vault session expired:**
```bash
# Bitwarden
export BW_SESSION="$(bw unlock --raw)"

# 1Password - re-sign in
op signin
```

**Tab completion not working:**
```bash
rm -f ~/.zcompdump*      # Clear completion cache
exec zsh                 # Reload shell
```

See **[Troubleshooting Guide](docs/troubleshooting.md)** for complete solutions.

</details>

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development workflow
- Testing requirements
- Commit conventions
- Pull request process

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community guidelines.

---

## Security

- All secrets stored in vault (encrypted)
- Session caching with 600 permissions
- Pre-commit hooks prevent secret leaks
- Regular security audits (see [SECURITY.md](SECURITY.md))

**Report vulnerabilities:** Use [GitHub Security Advisories](https://github.com/blackwell-systems/dotfiles/security/advisories)

---

## Acknowledgments

<details>
<summary><b>Credits & Inspiration</b></summary>

**AI & Development:**
- [Anthropic](https://anthropic.com/) - Claude AI and Claude Code
- [Claude Code](https://claude.ai/code) - AI-assisted development

**Tools:**
- [Bitwarden](https://bitwarden.com/) - Secret management
- [Homebrew](https://brew.sh/) - Package management
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k) - Zsh theme
- [Modern CLI Tools](https://github.com/ibraheemdev/modern-unix) - eza, fzf, ripgrep, etc.

**Inspiration:**
- [holman/dotfiles](https://github.com/holman/dotfiles) - Topic-based organization
- [thoughtbot/dotfiles](https://github.com/thoughtbot/dotfiles) - rcm tool
- [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles) - macOS defaults

</details>

---

## Trademarks

Blackwell Systems™ and the Blackwell Systems logo are trademarks of Dayna Blackwell.
You may use the name "Blackwell Systems" to refer to this project, but you may not
use the name or logo in a way that suggests endorsement or official affiliation
without prior written permission. See [BRAND.md](BRAND.md) for usage guidelines.

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

**Questions?** Open an [issue](https://github.com/blackwell-systems/dotfiles/issues) or check the [full documentation](docs/README-FULL.md).
