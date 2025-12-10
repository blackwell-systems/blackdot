# Template System Guide

The template system generates machine-specific configuration files from templates. This enables different configs for work vs personal machines, different OS configurations, and consistent settings across multiple machines.

**Version:** 1.0.0

---

## Quick Start

```bash
# 1. Initialize template variables
blackdot template init

# 2. Edit your configuration
blackdot template edit

# 3. Review detected values
blackdot template vars

# 4. Generate configuration files
blackdot template render

# 5. Create symlinks to destinations
blackdot template link
```

---

## Overview

### How It Works

1. **Templates** in `templates/configs/*.tmpl` contain placeholders like `{{ variable }}`
2. **Variables** are sourced from multiple locations with defined precedence
3. **Rendering** substitutes variables and processes conditionals
4. **Generated** files are saved to `generated/` directory
5. **Symlinks** connect generated files to their final destinations

### File Locations

```
dotfiles/
├── templates/
│   ├── _variables.sh           # Default variable definitions
│   ├── _variables.local.sh     # Your machine-specific overrides (gitignored)
│   ├── _variables.local.sh.example  # Example to copy from
│   ├── _arrays.local.json      # JSON arrays for {{#each}} loops (gitignored)
│   ├── _arrays.local.json.example  # Example JSON arrays
│   └── configs/                # Template files
│       ├── gitconfig.tmpl      # → ~/.gitconfig
│       ├── 99-local.zsh.tmpl   # → zsh/zsh.d/99-local.zsh
│       ├── ssh-config.tmpl     # → ~/.ssh/config
│       └── claude.local.tmpl   # → ~/.claude.local
│
├── generated/                  # Rendered output (gitignored)
│   ├── gitconfig
│   ├── 99-local.zsh
│   ├── ssh-config
│   └── claude.local
│
└── lib/
    └── _templates.sh           # Template engine
```

---

## Commands

### `blackdot template init`

Interactive setup wizard that:
1. Detects your system (hostname, OS, architecture)
2. Creates `_variables.local.sh` from the example
3. Opens the file in your editor

```bash
blackdot template init
```

### `blackdot template vars`

Display all template variables and their current values:

```bash
# Show all variables with values
blackdot template vars

# Show variable names only
blackdot template vars --quiet
```

Output example:
```
Template Variables
──────────────────────────────────────

Auto-detected:
  hostname             = macbook-pro
  os                   = macos
  arch                 = arm64
  user                 = john
  machine_type         = personal

User-configured:
  git_email            = john@example.com
  git_name             = John Doe
  aws_profile          = default
```

### `blackdot template render`

Render templates to the `generated/` directory:

```bash
# Render all templates
blackdot template render

# Preview without writing files
blackdot template render --dry-run

# Force re-render even if up to date
blackdot template render --force

# Render specific template
blackdot template render gitconfig
```

### `blackdot template link`

Create symlinks from generated files to their destinations:

```bash
# Create symlinks
blackdot template link

# Preview without creating
blackdot template link --dry-run
```

Destination mapping:
| Generated File | Destination |
|---------------|-------------|
| `gitconfig` | `~/.gitconfig` |
| `99-local.zsh` | `zsh/zsh.d/99-local.zsh` |
| `ssh-config` | `~/.ssh/config` |
| `claude.local` | `~/.claude.local` |

### `blackdot template check`

Validate template syntax without rendering:

```bash
blackdot template check
```

Checks for:
- Unmatched `{{#if}}`/`{{/if}}` blocks
- Unclosed variable tags
- Malformed syntax

### `blackdot template diff`

Show differences between templates and generated files:

```bash
# Quick check
blackdot template diff

# Show detailed diffs
blackdot template diff --verbose
```

### `blackdot template edit`

Open `_variables.local.sh` in your editor:

```bash
blackdot template edit
```

### `blackdot template list`

List available templates and their status:

```bash
blackdot template list
```

Output:
```
Available Templates
───────────────────────────────────────
  gitconfig                 ✓ up to date
  99-local.zsh              ○ stale
  ssh-config                ✗ not generated
```

### `blackdot template arrays`

Manage JSON/shell arrays for `{{#each}}` loops:

```bash
# View loaded arrays and their source
blackdot template arrays

# Validate JSON arrays file syntax
blackdot template arrays --validate

# Export shell arrays to JSON format
blackdot template arrays --export-json
```

Output example:
```
Template Arrays
──────────────────────────────────────
Source: json (templates/_arrays.local.json)

ssh_hosts (3 items):
  • github | github.com | git | ~/.ssh/id_ed25519
  • gitlab | gitlab.com | git | ~/.ssh/id_ed25519
  • work-server | server.company.com | deploy | ~/.ssh/id_work | ProxyJump bastion
```

### `blackdot template vault`

Sync template variables with your vault for cross-machine portability:

```bash
# Push local variables to vault
blackdot template vault push

# Pull from vault to local
blackdot template vault pull

# Show differences between local and vault
blackdot template vault diff

# Bidirectional sync with conflict detection
blackdot template vault sync

# Check sync status
blackdot template vault status
```

**Options:**

| Option | Description |
|--------|-------------|
| `--force`, `-f` | Force overwrite without confirmation |
| `--prefer-local` | On conflict, use local file |
| `--prefer-vault` | On conflict, use vault item |
| `--no-backup` | Don't backup local file on pull |

**Example workflow:**

```bash
# First machine: backup your config to vault
blackdot template init
blackdot template vault push

# New machine: restore from vault
blackdot vault pull           # Get vault access
blackdot template vault pull  # Pull template variables
blackdot template render      # Generate configs
```

---

## Template Syntax

### Variable Substitution

Use `{{ variable }}` to insert a variable value:

```
[user]
    name = {{ git_name }}
    email = {{ git_email }}
```

Both `{{ var }}` (with spaces) and `{{var}}` (without spaces) work.

### Pipeline Filters

Transform variable values using filters with the pipe (`|`) syntax:

```
{{ variable | filter }}
{{ variable | filter "argument" }}
{{ variable | filter1 | filter2 }}
```

#### Available Filters

| Filter | Description | Example |
|--------|-------------|---------|
| `upper` | Convert to UPPERCASE | `{{ hostname \| upper }}` → `MACBOOK-PRO` |
| `lower` | Convert to lowercase | `{{ hostname \| lower }}` → `macbook-pro` |
| `capitalize` | Capitalize first letter | `{{ name \| capitalize }}` → `John` |
| `trim` | Remove leading/trailing whitespace | `{{ value \| trim }}` |
| `default "value"` | Use fallback if variable is empty | `{{ editor \| default "vim" }}` |
| `replace "old,new"` | Replace all occurrences | `{{ email \| replace "@,_at_" }}` → `user_at_example.com` |
| `append "text"` | Append text to value | `{{ name \| append ".local" }}` |
| `prepend "text"` | Prepend text to value | `{{ name \| prepend "user-" }}` |
| `quote` | Wrap in double quotes | `{{ path \| quote }}` → `"/path/to/file"` |
| `squote` | Wrap in single quotes | `{{ path \| squote }}` → `'/path/to/file'` |
| `truncate N` | Truncate to N characters | `{{ hostname \| truncate 5 }}` → `macbo` |
| `length` | Return string length | `{{ name \| length }}` → `4` |
| `basename` | Extract filename from path | `{{ home \| basename }}` → `john` |
| `dirname` | Extract directory from path | `{{ home \| dirname }}` → `/Users` |

#### Chained Filters

Apply multiple filters in sequence:

```
# Uppercase hostname truncated to 8 characters
Host: {{ hostname | upper | truncate 8 }}

# Default value, then uppercase
Editor: {{ VISUAL | default "vim" | upper }}
```

#### Common Use Cases

**Default values for optional settings:**
```
export EDITOR="{{ editor | default "vim" }}"
export AWS_PROFILE="{{ aws_profile | default "default" }}"
```

**Path manipulation:**
```
# Extract just the username from home path
User: {{ home | basename }}
# → john

# Get parent directory
Parent: {{ workspace | dirname }}
# → /Users/john
```

**Consistent formatting:**
```
# Hostname as uppercase identifier
export MACHINE_ID="{{ hostname | upper | replace "-,_" }}"
# → MACBOOK_PRO

# Email obfuscation in comments
# Contact: {{ git_email | replace "@, [at] " }}
# → john [at] example.com
```

**String wrapping:**
```
# For shell safety
alias home='cd {{ home | squote }}'
```

#### Viewing Available Filters

```bash
# Show all filters with descriptions
blackdot template filters
```

### Conditional Blocks

#### Simple Truthy Check

Include content only if a variable has a non-empty value:

```
{{#if git_signing_key }}
[commit]
    gpgsign = true
{{/if}}
```

#### Comparison

Check if a variable equals a specific value:

```
{{#if machine_type == "work" }}
# Work-specific configuration
export WORK_EMAIL="{{ git_email }}"
{{/if}}
```

#### Else Blocks

Provide alternative content:

```
{{#if bedrock_profile }}
export CLAUDE_USE_BEDROCK=1
{{#else}}
# Using default Anthropic API
{{/if}}
```

#### Negative Conditionals

Include content only if a variable is empty:

```
{{#unless git_signing_key }}
# GPG signing not configured
{{/unless}}
```

### Array Loops

Use `{{#each}}` to iterate over arrays with named fields:

```
{{#each ssh_hosts}}
Host {{ name }}
    HostName {{ hostname }}
    User {{ user }}
    IdentityFile {{ identity }}
{{#if extra }}    {{ extra }}
{{/if}}
{{/each}}
```

**Available arrays:**

| Array | Fields | Defined In |
|-------|--------|------------|
| `ssh_hosts` | `name`, `hostname`, `user`, `identity`, `extra` | `_variables.local.sh` |

**Defining arrays:**

```zsh
# In _variables.local.sh
# Format: name|hostname|user|identity_file|extra_options
SSH_HOSTS=(
    "github|github.com|git|~/.ssh/id_ed25519|"
    "work-server|server.company.com|deploy|~/.ssh/id_work|ProxyJump bastion"
)
```

Conditionals work inside loops - use `{{#if extra }}` to include optional fields only when set.

### JSON Arrays (Recommended)

For cleaner array definitions, use JSON format instead of shell arrays:

**Create `templates/_arrays.local.json`:**

```json
{
  "ssh_hosts": [
    {
      "name": "github",
      "hostname": "github.com",
      "user": "git",
      "identity": "~/.ssh/id_ed25519"
    },
    {
      "name": "gitlab",
      "hostname": "gitlab.com",
      "user": "git",
      "identity": "~/.ssh/id_ed25519"
    },
    {
      "name": "work-server",
      "hostname": "server.company.com",
      "user": "deploy",
      "identity": "~/.ssh/id_work",
      "extra": "ProxyJump bastion"
    }
  ]
}
```

**Benefits of JSON arrays:**
- Easier to read and maintain
- No shell escaping issues
- Can be validated with standard JSON tools
- Optional fields can be omitted entirely

**Managing arrays:**

```bash
# View loaded arrays (shows source: JSON or shell)
blackdot template arrays

# Validate JSON syntax
blackdot template arrays --validate

# Export existing shell arrays to JSON format
blackdot template arrays --export-json
```

The template system automatically prefers JSON arrays if `_arrays.local.json` exists and `jq` is available. Falls back to shell arrays otherwise.

### Available Variables

#### Auto-Detected (set automatically)

| Variable | Description | Example |
|----------|-------------|---------|
| `hostname` | Short hostname | `macbook-pro` |
| `hostname_full` | Full hostname | `macbook-pro.local` |
| `os` | Operating system | `macos`, `linux`, `wsl` |
| `os_family` | OS family | `Darwin`, `Linux` |
| `arch` | Architecture | `arm64`, `amd64` |
| `user` | Username | `john` |
| `home` | Home directory | `/Users/john` |
| `workspace` | Workspace path | `/Users/john/workspace` |
| `machine_type` | Detected type | `work`, `personal`, `unknown` |
| `date` | Current date | `2024-01-15` |
| `datetime` | Current datetime | `2024-01-15 14:30:00` |

#### User-Configured (set in `_variables.local.sh`)

| Variable | Description | Default |
|----------|-------------|---------|
| `git_name` | Git author name | (empty) |
| `git_email` | Git author email | (empty) |
| `git_signing_key` | GPG key ID | (empty) |
| `git_default_branch` | Default branch | `main` |
| `git_editor` | Git editor | `nvim` |
| `aws_profile` | Default AWS profile | `default` |
| `aws_region` | Default AWS region | `us-east-1` |
| `bedrock_profile` | AWS Bedrock profile | (empty) |
| `bedrock_region` | Bedrock region | `us-west-2` |
| `editor` | Default editor | `nvim` |
| `visual` | Visual editor | `code` |
| `github_user` | GitHub username | (empty) |
| `github_enterprise_host` | GHE hostname | (empty) |
| `enable_nvm` | Enable NVM | `true` |
| `enable_pyenv` | Enable pyenv | `false` |
| `enable_k8s_prompt` | K8s in prompt | `false` |

---

## Variable Precedence

Variables are resolved in this order (highest priority first):

1. **Environment variables** (`BLACKDOT_TMPL_*`)
   ```bash
   BLACKDOT_TMPL_GIT_EMAIL="other@example.com" blackdot template render
   ```

2. **Local overrides** (`templates/_variables.local.sh`)
   ```zsh
   TMPL_DEFAULTS[git_email]="john@example.com"
   ```

3. **Machine-type defaults** (`TMPL_WORK` or `TMPL_PERSONAL`)
   ```zsh
   TMPL_WORK[git_email]="john@company.com"
   TMPL_PERSONAL[git_email]="john@personal.com"
   ```

4. **Global defaults** (`templates/_variables.sh`)
   ```zsh
   TMPL_DEFAULTS[git_editor]="nvim"
   ```

5. **Auto-detected values** (hostname, OS, etc.)

---

## Machine Type Detection

The template system automatically detects your machine type based on:

1. **Environment variable**: `BLACKDOT_MACHINE_TYPE`
2. **Hostname patterns**:
   - Contains `work`, `corp`, `office` → `work`
   - Contains `personal`, `home`, `macbook`, `imac` → `personal`
3. **Directory indicators**:
   - `~/work` or `~/corp` exists → `work`
   - `~/personal` or `~/.personal-machine` exists → `personal`

Override detection in `_variables.local.sh`:
```zsh
TMPL_AUTO[machine_type]="work"
```

---

## Configuration Example

### Minimal Setup

```zsh
# templates/_variables.local.sh
TMPL_DEFAULTS[git_name]="John Doe"
TMPL_DEFAULTS[git_email]="john@example.com"
```

### Work/Personal Split

```zsh
# templates/_variables.local.sh

# Shared settings
TMPL_DEFAULTS[git_name]="John Doe"
TMPL_DEFAULTS[github_user]="johndoe"

# Work overrides (applied when machine_type == "work")
TMPL_WORK[git_email]="john.doe@company.com"
TMPL_WORK[aws_profile]="work-sso"
TMPL_WORK[github_enterprise_host]="github.company.com"

# Personal overrides (applied when machine_type == "personal")
TMPL_PERSONAL[git_email]="john@personal.com"
TMPL_PERSONAL[aws_profile]="personal"
```

### Full Configuration

```zsh
# templates/_variables.local.sh

# Force machine type (optional)
# TMPL_AUTO[machine_type]="work"

# Git
TMPL_DEFAULTS[git_name]="John Doe"
TMPL_DEFAULTS[git_email]="john@example.com"
TMPL_DEFAULTS[git_signing_key]="ABC123DEF456"

# AWS
TMPL_DEFAULTS[aws_profile]="default"
TMPL_DEFAULTS[aws_region]="us-west-2"

# AWS Bedrock (for Claude Code)
TMPL_DEFAULTS[bedrock_profile]="bedrock-profile"
TMPL_DEFAULTS[bedrock_region]="us-west-2"

# GitHub
TMPL_DEFAULTS[github_user]="johndoe"

# Work machine overrides
TMPL_WORK[git_email]="john.doe@company.com"
TMPL_WORK[aws_profile]="work-sso"
TMPL_WORK[github_enterprise_host]="github.company.com"
TMPL_WORK[github_enterprise_user]="jdoe"

# Feature toggles
TMPL_DEFAULTS[enable_nvm]="true"
TMPL_DEFAULTS[enable_pyenv]="true"
TMPL_DEFAULTS[enable_k8s_prompt]="true"
```

---

## Available Templates

### gitconfig.tmpl

Generates `~/.gitconfig` with:
- User identity (name, email)
- GPG signing (if `git_signing_key` set)
- Editor configuration
- Delta diff viewer settings
- Git aliases
- GitHub Enterprise URL rewriting (if configured)
- Work-specific includes (if `machine_type == "work"`)

### 99-local.zsh.tmpl

Generates machine-specific shell configuration:
- Machine type exports
- Work/personal-specific aliases
- AWS profile configuration
- Bedrock settings (for Claude Code)
- Editor exports
- Custom path aliases
- Feature toggles (NVM, pyenv, rbenv, SDKMAN)

### ssh-config.tmpl

Generates SSH configuration:
- Global defaults (keepalive, keychain)
- GitHub host configuration
- GitHub Enterprise (if configured)
- Work-specific hosts (if work machine)
- Include for local overrides

### claude.local.tmpl

Generates Claude Code local settings:
- AWS Bedrock configuration (if profile set)
- Anthropic API fallback
- Machine identification

---

## Integration with Bootstrap

The template system integrates with the bootstrap process:

1. **First bootstrap**: Templates are not rendered (no `_variables.local.sh` yet)
2. **After `blackdot template init`**: Bootstrap will render templates
3. **Subsequent bootstraps**: Templates re-render if configured

Bootstrap calls `render_templates()` which:
- Checks if `_variables.local.sh` exists
- Renders all templates with `--force`
- Skips gracefully if not configured

---

## Health Checks

`blackdot doctor` includes template system checks:

```
── Template System ──
✓ Template variables configured
✓ Found 4 generated config(s)
✓ All generated configs up to date
```

Warnings shown for:
- Missing `_variables.local.sh` (info only)
- No generated configs
- Stale templates (source newer than generated)

---

## Troubleshooting

### Templates Not Rendering

**Check variables file exists:**
```bash
ls -la templates/_variables.local.sh
```

**If missing, initialize:**
```bash
blackdot template init
```

### Wrong Variable Values

**Check current values:**
```bash
blackdot template vars
```

**Check precedence:**
```bash
DEBUG=1 dotfiles template render --dry-run
```

### Stale Generated Files

**Check status:**
```bash
blackdot template diff
```

**Force re-render:**
```bash
blackdot template render --force
```

### Unresolved Variables

Templates warn about unresolved `{{ variable }}` placeholders. Check:
1. Variable name spelling in template
2. Variable defined in `_variables.sh` or `_variables.local.sh`
3. No typos in array key names

### Machine Type Detection Wrong

**Check current detection:**
```bash
blackdot template vars | grep machine_type
```

**Force machine type:**
```zsh
# In _variables.local.sh
TMPL_AUTO[machine_type]="work"
```

---

## Best Practices

1. **Always run `blackdot template vars`** after editing `_variables.local.sh` to verify values

2. **Use `--dry-run`** first when testing template changes

3. **Keep sensitive values out of templates** - use vault system for secrets

4. **Test on a fresh machine** by temporarily renaming `_variables.local.sh`

5. **Commit template changes, not generated files** - `generated/` is gitignored

6. **Document custom variables** in your `_variables.local.sh` with comments

---

## Vault Integration

Template variables can be stored in your vault for portable restoration across machines. This enables a seamless new-machine workflow.

### Quick Commands

The template system has built-in vault commands:

```bash
blackdot template vault push      # Backup to vault
blackdot template vault pull      # Restore from vault
blackdot template vault diff      # Compare local vs vault
blackdot template vault sync      # Bidirectional sync
blackdot template vault status    # Show sync status
```

### Variable File Location

The template vault commands sync `templates/_variables.local.sh`:

| File | Purpose |
|------|---------|
| `templates/_variables.local.sh` | Your machine-specific template variables |
| Vault: `Template-Variables` | Backup in vault (all backends supported) |

### Storing Template Variables in Vault

```bash
# After running `blackdot template init`
blackdot template vault push      # Push to vault

# Or check status first
blackdot template vault status    # Shows sync state
```

### Restoring on a New Machine

```bash
# 1. Pull template variables from vault
blackdot template vault pull

# 2. Render templates - uses variables from vault
blackdot template render

# 3. Create symlinks
blackdot template link
```

### Discovery

The `blackdot vault scan` (discover-secrets.sh) command automatically detects template variables:

```bash
# Preview what would be discovered
blackdot vault scan --dry-run

# Output includes:
# [OK]   Found: ~/.config/blackdot/template-variables.sh
```

### Configuration in vault-items.json

Template variables are stored like any other syncable item:

```json
{
  "vault_items": {
    "Template-Variables": {
      "path": "~/.config/blackdot/template-variables.sh",
      "required": false,
      "type": "file"
    }
  },
  "syncable_items": {
    "Template-Variables": "~/.config/blackdot/template-variables.sh"
  }
}
```

### New Machine Workflow (Complete)

With template variables in vault, setting up a new machine becomes:

```bash
# 1. Clone dotfiles
git clone https://github.com/you/dotfiles ~/dotfiles

# 2. Bootstrap (installs dependencies, sets up vault)
cd ~/dotfiles && ./install.sh

# 3. Pull SSH keys, AWS config, etc from vault
blackdot vault pull

# 4. Pull template variables from vault
blackdot template vault pull

# 5. Render all templates
blackdot template render

# 6. Create symlinks
blackdot template link

# Done! All configs are now in place
```

---

## Related Documentation

- [Main README](README.md) - Overview
- [Full Documentation](README-FULL.md) - Complete guide
- [Vault System](vault-README.md) - Secret management
- [Architecture](architecture.md) - System design
