# CLI Feature Awareness Implementation

> **Status:** ✅ Implemented
> **Priority:** Medium
> **Complexity:** Low-Medium
> **Completed:** v2.3.0
> **Foundation:** [Feature Registry](../features.md) (v2.1.0)

## Overview

Enhance the `dotfiles` CLI to be feature-aware, showing and hiding commands based on Feature Registry state. This creates a cleaner user experience where only relevant commands are visible.

---

## Architecture Foundation

CLI Feature Awareness builds on the **Feature Registry** (`lib/_features.sh`) control plane:

```
┌─────────────────────────────────────────────┐
│         Feature Registry (v2.1.0)            │
│   - Central source of truth for features     │
│   - feature_enabled() API                    │
│   - Category metadata (core/optional/integ)  │
└─────────────────┬───────────────────────────┘
                  │ queries
                  ▼
┌─────────────────────────────────────────────┐
│       CLI Feature Awareness (this doc)       │
│   - Hides disabled feature commands          │
│   - Shows "disabled" indicators              │
│   - Prompts to enable on disabled command    │
└─────────────────────────────────────────────┘
```

**Key integration points:**
- CLI queries `feature_enabled()` before showing commands in help
- Disabled commands show helpful enable instructions
- `--all` flag shows all commands regardless of feature state
- Command metadata maps commands → features

---

## Goals

1. **Clean UX** - Users only see commands relevant to their enabled features
2. **Discoverability** - Easy to discover disabled features exist
3. **Helpful prompts** - Running disabled commands suggests how to enable
4. **Backward compatible** - `--all` flag shows everything, no breaking changes

---

## Current State

The `dotfiles` command in `zsh/zsh.d/40-aliases.zsh` shows all commands unconditionally:

```bash
# Current help output shows everything
dotfiles help
# Shows vault, template, macos, features, config...
# Even if vault feature is disabled
```

**Problems:**
- New users see overwhelming list of commands
- Commands for disabled features create confusion
- No indication which commands require feature enablement

---

## Proposed Design

### Command-to-Feature Mapping

Create a registry mapping CLI commands to their required features:

```bash
# lib/_cli_features.sh (new file)

# Map commands to required features
# Format: command -> feature_name (empty = always show)
typeset -gA CLI_COMMAND_FEATURES=(
    # Always visible (core)
    ["status"]=""
    ["doctor"]=""
    ["help"]=""
    ["cd"]=""
    ["edit"]=""

    # Feature-gated commands
    ["vault"]="vault"
    ["secrets"]="vault"
    ["template"]="templates"
    ["tmpl"]="templates"
    ["macos"]="macos_settings"
    ["config"]="config_layers"
    ["features"]=""  # Always show - needed to enable others
    ["backup"]="backup_auto"
    ["rollback"]="backup_auto"
    ["drift"]="drift_check"
    ["sync"]="vault"
    ["diff"]="vault"
    ["packages"]=""
    ["lint"]=""
    ["metrics"]="health_metrics"
    ["upgrade"]=""
    ["setup"]=""
    ["migrate"]=""
    ["uninstall"]=""
)

# Check if command should be visible
# Usage: cli_command_visible "vault"
cli_command_visible() {
    local cmd="$1"
    local feature="${CLI_COMMAND_FEATURES[$cmd]:-}"

    # No feature requirement = always visible
    if [[ -z "$feature" ]]; then
        return 0
    fi

    # Check feature state
    feature_enabled "$feature"
}

# Get feature for command
# Usage: cli_command_feature "vault" -> "vault"
cli_command_feature() {
    local cmd="$1"
    echo "${CLI_COMMAND_FEATURES[$cmd]:-}"
}
```

### Help Output Modes

#### Default Mode: Feature-Filtered

```bash
$ dotfiles help

dotfiles - Manage your dotfiles

Usage: dotfiles <command> [options]

Setup & Health:
  setup             Interactive setup wizard
  status, s         Quick visual dashboard
  doctor, health    Run comprehensive health check
  lint              Validate shell config syntax
  packages, pkg     Check/install Brewfile packages
  upgrade, update   Pull latest and run bootstrap

Feature Management:
  features          List all features and status
  features enable   Enable a feature
  features disable  Disable a feature

Configuration:
  config get        Get config value (with layer resolution)
  config set        Set config value in specific layer
  config list       Show configuration layer status

Other Commands:
  cd                Change to dotfiles directory
  edit              Open dotfiles in editor
  help              Show this help

─────────────────────────────────────────────────────
Some commands hidden. Run 'dotfiles help --all' to see all.
Disabled features: vault, templates, macos_settings
```

#### Full Mode: Show All with Indicators

```bash
$ dotfiles help --all

dotfiles - Manage your dotfiles

Usage: dotfiles <command> [options]

Setup & Health:
  setup             Interactive setup wizard
  status, s         Quick visual dashboard
  doctor, health    Run comprehensive health check
  drift             Compare local files vs vault          [requires: vault]
  sync              Bidirectional vault sync              [requires: vault]
  diff              Preview changes before sync           [requires: vault]
  ...

Vault Operations:                                         [feature: vault ○]
  vault setup       Setup vault backend
  vault pull        Pull secrets from vault
  vault push        Push secrets to vault
  ...

Backup & Safety:                                          [feature: backup_auto ○]
  backup            Create backup of current config
  backup list       List all backups
  rollback          Instant rollback to last backup

Template System:                                          [feature: templates ○]
  template, tmpl    Machine-specific config templates

macOS Settings:                                           [feature: macos_settings ○]
  macos <cmd>       macOS system settings

─────────────────────────────────────────────────────
Legend: ● enabled  ○ disabled
Enable features: dotfiles features enable <name>
```

### Running Disabled Commands

When user runs a command for a disabled feature:

```bash
$ dotfiles vault pull

⚠ The 'vault' feature is not enabled.

To enable vault support:
  dotfiles features enable vault

Or run with --force to execute anyway:
  dotfiles vault pull --force
```

Implementation:

```bash
# In dotfiles() function
vault)
    if ! feature_enabled "vault"; then
        if [[ "$1" == "--force" ]]; then
            shift
            # Continue with command
        else
            _cli_feature_disabled_message "vault" "vault"
            return 1
        fi
    fi
    # ... rest of vault handling
    ;;
```

Helper function:

```bash
# lib/_cli_features.sh

_cli_feature_disabled_message() {
    local feature="$1"
    local command="$2"

    echo ""
    echo -e "${YELLOW}⚠${NC} The '${CYAN}$feature${NC}' feature is not enabled."
    echo ""
    echo "To enable ${feature} support:"
    echo -e "  ${GREEN}dotfiles features enable $feature${NC}"
    echo ""
    echo "Or run with --force to execute anyway:"
    echo -e "  ${DIM}dotfiles $command --force${NC}"
    echo ""
}
```

---

## Implementation Plan

### Phase 1: Command Mapping (Week 1)

1. Create `lib/_cli_features.sh` with command→feature mapping
2. Add `cli_command_visible()` function
3. Source in `40-aliases.zsh`

```bash
# 40-aliases.zsh
source "$DOTFILES_DIR/lib/_features.sh"
source "$DOTFILES_DIR/lib/_cli_features.sh"  # New
```

### Phase 2: Help Filtering (Week 1-2)

1. Refactor help output to use helper functions
2. Add `--all` flag support
3. Add section headers with feature indicators
4. Add footer showing hidden commands

```bash
# New help implementation structure
_dotfiles_help() {
    local show_all=false
    [[ "$1" == "--all" || "$1" == "-a" ]] && show_all=true

    echo "${BOLD}${CYAN}dotfiles${NC} - Manage your dotfiles"
    echo ""

    _help_section "Setup & Health" "" "$show_all"
    _help_section "Vault Operations" "vault" "$show_all"
    _help_section "Backup & Safety" "backup_auto" "$show_all"
    # ...

    if ! $show_all; then
        _help_footer_hidden_features
    fi
}

_help_section() {
    local title="$1"
    local feature="$2"
    local show_all="$3"

    # Skip section if feature disabled and not showing all
    if [[ -n "$feature" ]] && ! $show_all && ! feature_enabled "$feature"; then
        return 0
    fi

    # Show section with indicator if showing all
    if [[ -n "$feature" ]]; then
        local indicator="●"
        feature_enabled "$feature" || indicator="○"
        echo -e "${BOLD}$title:${NC}  ${DIM}[feature: $feature $indicator]${NC}"
    else
        echo -e "${BOLD}$title:${NC}"
    fi

    # ... print commands
}
```

### Phase 3: Disabled Command Handling (Week 2)

1. Add feature guards to each command case
2. Implement `--force` bypass flag
3. Add helpful enable messages

```bash
# Pattern for feature-gated commands
vault)
    if ! _cli_require_feature "vault" "$@"; then
        return 1
    fi
    # ... command implementation
    ;;
```

### Phase 4: Subcommand Awareness (Week 3)

Handle nested commands like `dotfiles vault setup`:

```bash
# lib/_cli_features.sh

# Subcommand mapping for nested help
typeset -gA CLI_SUBCOMMAND_FEATURES=(
    ["vault:setup"]="vault"
    ["vault:pull"]="vault"
    ["vault:push"]="vault"
    ["template:init"]="templates"
    ["template:render"]="templates"
    ["macos:apply"]="macos_settings"
    ["config:get"]="config_layers"
    ["config:set"]="config_layers"
)
```

---

## CLI File Structure

```
lib/
├── _features.sh          # Feature Registry (existing)
├── _config_layers.sh     # Config Layers (existing)
└── _cli_features.sh      # NEW: CLI feature awareness

zsh/zsh.d/
└── 40-aliases.zsh        # MODIFIED: Use cli feature helpers
```

---

## Feature Registration

Register as an optional feature:

```bash
# lib/_features.sh
typeset -gA FEATURE_REGISTRY=(
    # ...existing features...
    ["cli_feature_filter"]="true|Filter CLI help based on enabled features|optional|"
)
```

This allows users to disable the filtering if they prefer seeing all commands:

```bash
# Show all commands always
dotfiles features disable cli_feature_filter
```

---

## Environment Variable Override

For scripting and advanced users:

```bash
# Always show all commands (ignore feature filtering)
export DOTFILES_CLI_SHOW_ALL=true

# Force command execution without feature check
DOTFILES_FORCE=true dotfiles vault pull
```

---

## Help Command Enhancements

### Feature-Specific Help

```bash
$ dotfiles help vault

dotfiles vault - Secret vault operations

Status: ○ DISABLED (feature: vault)
Enable: dotfiles features enable vault

Commands (run with --force to use while disabled):
  setup       Setup vault backend (first-time setup)
  scan        Re-scan for new secrets
  pull        Pull secrets FROM vault to local machine
  push        Push secrets TO vault
  sync        Bidirectional sync
  status      Show vault sync status
  ...
```

### What's Available

```bash
$ dotfiles help --available

Enabled Features & Commands:

● shell (core)
  → status, doctor, lint, packages, upgrade

● config_layers
  → config get, config set, config show, config list

● features (always enabled)
  → features list, features enable, features disable

Disabled Features:

○ vault
  → vault, secrets, sync, drift, diff
  Enable: dotfiles features enable vault

○ templates
  → template, tmpl
  Enable: dotfiles features enable templates

○ macos_settings
  → macos
  Enable: dotfiles features enable macos_settings
```

---

## Backward Compatibility

1. **No breaking changes** - Commands still work, just with prompts
2. **--force flag** - Execute disabled commands if needed
3. **--all flag** - See all commands in help
4. **Environment override** - `DOTFILES_CLI_SHOW_ALL=true`
5. **Feature toggle** - Disable filtering entirely with `cli_feature_filter`

---

## Testing

### Unit Tests

```bash
# test/cli_features.bats

@test "cli_command_visible returns true for core commands" {
    run zsh -c "source lib/_cli_features.sh; cli_command_visible 'status'"
    [ "$status" -eq 0 ]
}

@test "cli_command_visible returns false for disabled feature" {
    run zsh -c "
        source lib/_features.sh
        source lib/_cli_features.sh
        feature_disable 'vault'
        cli_command_visible 'vault'
    "
    [ "$status" -eq 1 ]
}

@test "help --all shows disabled commands" {
    run zsh -c "source 40-aliases.zsh; dotfiles help --all"
    [[ "$output" == *"[feature: vault"* ]]
}

@test "disabled command shows enable message" {
    run zsh -c "
        source lib/_features.sh
        feature_disable 'vault'
        source 40-aliases.zsh
        dotfiles vault pull
    "
    [[ "$output" == *"feature is not enabled"* ]]
    [[ "$output" == *"features enable vault"* ]]
}
```

### Integration Tests

```bash
@test "help output changes when feature enabled/disabled" {
    # Disable vault
    dotfiles features disable vault
    output1=$(dotfiles help)

    # Enable vault
    dotfiles features enable vault
    output2=$(dotfiles help)

    # Vault commands should appear in output2 but not output1
    [[ "$output1" != *"vault setup"* ]]
    [[ "$output2" == *"vault setup"* ]]
}
```

---

## Documentation Updates

1. Update `docs/cli-reference.md` with feature filtering info
2. Add "Feature-Aware CLI" section to main README
3. Update `docs/features.md` with CLI integration details
4. Add `cli_feature_filter` to feature list docs

---

## Success Metrics

1. **Reduced cognitive load** - New users see fewer, more relevant commands
2. **Better discoverability** - Users learn about features through help prompts
3. **No confusion** - Clear indication why commands are hidden/disabled
4. **Power user friendly** - Easy overrides for advanced usage

---

## Future Enhancements

1. **Tab completion awareness** - Only complete enabled commands
2. **Contextual suggestions** - "You might want to enable vault for this"
3. **Feature bundles in help** - "Enable developer preset for all dev tools"
4. **Command aliases** - Map short commands to features automatically
