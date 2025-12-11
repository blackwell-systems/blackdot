# =========================
# 40-aliases.zsh
# =========================
# Shell aliases for navigation, vault, blackdot, and utilities
# Convenient shortcuts for common operations

# Color definitions for CLI output
if [[ -t 1 ]]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    BOLD='' DIM='' RED='' GREEN='' YELLOW='' BLUE='' CYAN='' NC=''
fi

# Convenience navigation aliases
alias cws='cd "$WORKSPACE"'
alias ccode='cd "$WORKSPACE/code"'
alias cwhite='cd "$WORKSPACE/whitepapers"'
alias cpat='cd "$WORKSPACE/patent-pool"'

# Source CLI feature awareness if available
if [[ -f "$BLACKDOT_DIR/lib/_cli_features.sh" ]]; then
    source "$BLACKDOT_DIR/lib/_cli_features.sh" 2>/dev/null || true
fi

# Command-specific help information
typeset -gA CLI_COMMAND_HELP=(
    ["vault"]="vault|Vault Operations|Multi-vault secret management (Bitwarden/1Password/pass)|
  vault setup       Setup vault backend (first-time setup)
  vault pull        Pull secrets from vault
  vault push        Push secrets to vault
  vault sync        Bidirectional sync (smart direction)
  vault scan        Re-scan for new secrets
  vault list        List all vault items
  vault status      Show vault sync status"
    ["config"]="config_layers|Configuration|Hierarchical configuration resolution (env>project>machine>user)|
  config get <key>          Get config value with layer resolution
  config set <layer> <k> <v> Set config in specific layer
  config show <key>         Show where a config value comes from
  config list               Show configuration layer status
  config merged             Show merged config from all layers
  config init <type>        Initialize machine or project config
  config edit [layer]       Edit config in \$EDITOR"
    ["backup"]="backup_auto|Backup & Safety|Automatic backup before destructive operations|
  backup create     Create backup of current config
  backup list       List all backups
  backup restore    Restore specific backup
  rollback          Instant rollback to last backup"
    ["template"]="templates|Templates|Machine-specific configuration templates|
  template init     Initialize templates for this machine
  template render   Render all templates
  template link     Create symlinks from templates
  template diff     Show differences from rendered
  template vars     Show available template variables"
    ["features"]="core|Feature Management|Enable/disable blackdot features|
  features          List all features and status
  features list     List features (optionally by category)
  features enable   Enable a feature
  features disable  Disable a feature
  features preset   Apply a preset (minimal/developer/claude/full)
  features check    Check if feature is enabled (for scripts)"
    ["doctor"]="core|Health Check|Comprehensive system health diagnostics|
  doctor            Run all health checks
  doctor --fix      Auto-fix common issues
  doctor --json     Output as JSON for automation"
    ["status"]="core|Status|Quick visual dashboard|
  status            Show quick status dashboard
  status --verbose  Show detailed status"
    ["metrics"]="health_metrics|Metrics|Health check metrics visualization|
  metrics           Show metrics dashboard
  metrics history   Show historical trends"
    ["encrypt"]="core|Security|Age encryption for sensitive files|
  encrypt init        Initialize encryption (generate key pair)
  encrypt <file>      Encrypt a file
  encrypt decrypt     Decrypt an .age file
  encrypt edit        Decrypt, edit, re-encrypt
  encrypt list        List encrypted/unencrypted files
  encrypt status      Show encryption status and key info
  encrypt push-key    Backup private key to vault"
)

# Helper: Show help for a specific command
_blackdot_help_command() {
    local cmd="$1"
    local info="${CLI_COMMAND_HELP[$cmd]:-}"

    if [[ -z "$info" ]]; then
        echo "No detailed help available for: $cmd"
        echo ""
        echo "Try: blackdot help"
        return 1
    fi

    # Parse info - first line contains metadata, rest is subcommands
    local first_line="${info%%$'\n'*}"
    local subcommands="${info#*$'\n'}"

    # Parse first line: "feature|title|description"
    local feature="${first_line%%|*}"
    local rest="${first_line#*|}"
    local title="${rest%%|*}"
    local description="${rest#*|}"
    description="${description%%|*}"  # Remove trailing pipe if any

    # Show feature status
    local status_text="${GREEN}●${NC} enabled"
    local feature_status="enabled"
    if [[ -n "$feature" && "$feature" != "core" ]]; then
        if type feature_enabled &>/dev/null && ! feature_enabled "$feature" 2>/dev/null; then
            status_text="${DIM}○${NC} disabled"
            feature_status="disabled"
        fi
    else
        status_text="${CYAN}core${NC}"
        feature_status="core"
    fi

    echo "${BOLD}${CYAN}blackdot $cmd${NC} - $title"
    echo ""
    echo "${BOLD}Feature:${NC} $feature ($status_text)"
    echo "${BOLD}Description:${NC} $description"
    echo ""
    echo "${BOLD}Commands:${NC}"
    echo "$subcommands"
    echo ""

    # Show enable hint if disabled
    if [[ "$feature_status" == "disabled" ]]; then
        echo "─────────────────────────────────────────────────────"
        echo "${YELLOW}⚠${NC} This feature is not enabled."
        echo "  Enable with: ${GREEN}blackdot features enable $feature${NC}"
        echo "  Or use: ${DIM}blackdot $cmd --force${NC}"
        echo ""
    fi
}

# Helper function for feature-aware help display
_blackdot_help() {
    local show_all=false
    local show_cmd=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all|-a) show_all=true ;;
            -*) ;;  # ignore other flags
            *) show_cmd="$1" ;;
        esac
        shift
    done

    # If command specified, show command-specific help
    if [[ -n "$show_cmd" ]]; then
        _blackdot_help_command "$show_cmd"
        return $?
    fi

    echo "${BOLD}${CYAN}blackdot${NC} - Manage your blackdot config"
    echo ""
    echo "${BOLD}Usage:${NC} blackdot <command> [options]"
    echo ""

    # Setup & Health (always visible)
    echo "${BOLD}${CYAN}Setup & Health:${NC}"
    echo "  ${YELLOW}setup${NC}             ${DIM}Interactive setup wizard (recommended)${NC}"
    echo "  ${YELLOW}status${NC}, s         ${DIM}Quick visual dashboard${NC}"
    echo "  ${YELLOW}doctor${NC}, health    ${DIM}Run comprehensive health check${NC}"
    echo "  ${YELLOW}lint${NC}              ${DIM}Validate shell config syntax${NC}"
    echo "  ${YELLOW}packages${NC}, pkg     ${DIM}Check/install Brewfile packages${NC}"
    echo "  ${YELLOW}upgrade${NC}, update   ${DIM}Pull latest and run bootstrap${NC}"
    echo ""

    # Vault Operations (feature: vault)
    local vault_visible=true
    if type cli_section_visible &>/dev/null && ! cli_section_visible "Vault Operations"; then
        vault_visible=false
    fi
    if $show_all || $vault_visible; then
        local indicator=""
        if $show_all && type cli_feature_indicator &>/dev/null; then
            indicator=" $(cli_feature_indicator vault)"
        fi
        echo "${BOLD}${CYAN}Vault Operations:${NC}${indicator}"
        echo "  ${YELLOW}vault setup${NC}       ${DIM}Setup vault backend (first-time setup)${NC}"
        echo "  ${YELLOW}vault pull${NC}        ${DIM}Pull secrets from vault${NC}"
        echo "  ${YELLOW}vault push${NC}        ${DIM}Push secrets to vault${NC}"
        echo "  ${YELLOW}vault sync${NC}        ${DIM}Bidirectional sync (smart direction)${NC}"
        echo "  ${YELLOW}vault scan${NC}        ${DIM}Re-scan for new secrets${NC}"
        echo "  ${YELLOW}vault list${NC}        ${DIM}List all vault items${NC}"
        echo "  ${YELLOW}drift${NC}             ${DIM}Compare local files vs vault${NC}"
        echo "  ${YELLOW}sync${NC}              ${DIM}Bidirectional vault sync (smart push/pull)${NC}"
        echo "  ${YELLOW}diff${NC}              ${DIM}Preview changes before sync/restore${NC}"
        echo ""
    fi

    # Backup & Safety (feature: backup_auto)
    local backup_visible=true
    if type cli_section_visible &>/dev/null && ! cli_section_visible "Backup & Safety"; then
        backup_visible=false
    fi
    if $show_all || $backup_visible; then
        local indicator=""
        if $show_all && type cli_feature_indicator &>/dev/null; then
            indicator=" $(cli_feature_indicator backup_auto)"
        fi
        echo "${BOLD}${CYAN}Backup & Safety:${NC}${indicator}"
        echo "  ${YELLOW}backup${NC}            ${DIM}Create backup of current config${NC}"
        echo "  ${YELLOW}backup list${NC}       ${DIM}List all backups${NC}"
        echo "  ${YELLOW}backup restore${NC}    ${DIM}Restore specific backup${NC}"
        echo "  ${YELLOW}rollback${NC}          ${DIM}Instant rollback to last backup${NC}"
        echo ""
    fi

    # Security (always visible)
    echo "${BOLD}${CYAN}Security:${NC}"
    echo "  ${YELLOW}encrypt${NC}           ${DIM}Age encryption management${NC}"
    echo "  ${YELLOW}encrypt init${NC}      ${DIM}Initialize encryption (generate keys)${NC}"
    echo "  ${YELLOW}encrypt edit${NC}      ${DIM}Decrypt, edit, re-encrypt a file${NC}"
    echo "  ${YELLOW}encrypt status${NC}    ${DIM}Show encryption status and key info${NC}"
    echo ""

    # Hooks (always visible)
    echo "${BOLD}${CYAN}Hooks:${NC}"
    echo "  ${YELLOW}hook, hooks${NC}       ${DIM}Hook system management${NC}"
    echo "  ${YELLOW}hook list${NC}         ${DIM}List hooks (all points or specific)${NC}"
    echo "  ${YELLOW}hook run <point>${NC}  ${DIM}Manually trigger hooks${NC}"
    echo "  ${YELLOW}hook add${NC}          ${DIM}Add a hook script to a point${NC}"
    echo "  ${YELLOW}hook points${NC}       ${DIM}List all available hook points${NC}"
    echo ""

    # Feature Management (always visible)
    echo "${BOLD}${CYAN}Feature Management:${NC}"
    echo "  ${YELLOW}features${NC}          ${DIM}List all features and status${NC}"
    echo "  ${YELLOW}features enable${NC}   ${DIM}Enable a feature${NC}"
    echo "  ${YELLOW}features disable${NC}  ${DIM}Disable a feature${NC}"
    echo "  ${YELLOW}features preset${NC}   ${DIM}Enable a preset (minimal/developer/claude/full)${NC}"
    echo ""

    # Configuration (feature: config_layers)
    local config_visible=true
    if type cli_section_visible &>/dev/null && ! cli_section_visible "Configuration"; then
        config_visible=false
    fi
    if $show_all || $config_visible; then
        local indicator=""
        if $show_all && type cli_feature_indicator &>/dev/null; then
            indicator=" $(cli_feature_indicator config_layers)"
        fi
        echo "${BOLD}${CYAN}Configuration:${NC}${indicator}"
        echo "  ${YELLOW}config get${NC}        ${DIM}Get config value (with layer resolution)${NC}"
        echo "  ${YELLOW}config set${NC}        ${DIM}Set config value in specific layer${NC}"
        echo "  ${YELLOW}config show${NC}       ${DIM}Show where a config value comes from${NC}"
        echo "  ${YELLOW}config list${NC}       ${DIM}Show configuration layer status${NC}"
        echo ""
    fi

    # Templates (feature: templates)
    local templates_visible=true
    if type cli_section_visible &>/dev/null && ! cli_section_visible "Templates"; then
        templates_visible=false
    fi
    if $show_all || $templates_visible; then
        local indicator=""
        if $show_all && type cli_feature_indicator &>/dev/null; then
            indicator=" $(cli_feature_indicator templates)"
        fi
        echo "${BOLD}${CYAN}Templates:${NC}${indicator}"
        echo "  ${YELLOW}template${NC}, tmpl    ${DIM}Machine-specific config templates${NC}"
        echo ""
    fi

    # macOS Settings (feature: macos_settings, macOS only)
    if [[ "$(uname -s)" == "Darwin" ]]; then
        local macos_visible=true
        if type cli_section_visible &>/dev/null && ! cli_section_visible "macOS Settings"; then
            macos_visible=false
        fi
        if $show_all || $macos_visible; then
            local indicator=""
            if $show_all && type cli_feature_indicator &>/dev/null; then
                indicator=" $(cli_feature_indicator macos_settings)"
            fi
            echo "${BOLD}${CYAN}macOS Settings:${NC}${indicator}"
            echo "  ${YELLOW}macos${NC} <cmd>       ${DIM}macOS system settings${NC}"
            echo ""
        fi
    fi

    # Metrics (feature: health_metrics)
    local metrics_visible=true
    if type cli_section_visible &>/dev/null && ! cli_section_visible "Metrics"; then
        metrics_visible=false
    fi
    if $show_all || $metrics_visible; then
        local indicator=""
        if $show_all && type cli_feature_indicator &>/dev/null; then
            indicator=" $(cli_feature_indicator health_metrics)"
        fi
        echo "${BOLD}${CYAN}Metrics:${NC}${indicator}"
        echo "  ${YELLOW}metrics${NC}           ${DIM}Visualize health check metrics over time${NC}"
        echo ""
    fi

    # Other Commands (always visible)
    echo "${BOLD}${CYAN}Other Commands:${NC}"
    echo "  ${YELLOW}migrate${NC}           ${DIM}Migrate config to v3.0 (INI→JSON, vault v2→v3)${NC}"
    echo "  ${YELLOW}uninstall${NC}         ${DIM}Remove blackdot configuration${NC}"
    echo "  ${YELLOW}cd${NC}                ${DIM}Change to blackdot directory${NC}"
    echo "  ${YELLOW}edit${NC}              ${DIM}Open blackdot in editor${NC}"
    echo "  ${YELLOW}help${NC}              ${DIM}Show this help${NC}"
    echo ""

    # Footer
    if ! $show_all; then
        # Check for hidden features
        local hidden=""
        if type cli_hidden_features &>/dev/null; then
            hidden=$(cli_hidden_features)
        fi
        if [[ -n "$hidden" ]]; then
            echo "─────────────────────────────────────────────────────"
            echo "${DIM}Some commands hidden. Run 'blackdot help --all' to see all.${NC}"
            echo "${DIM}Disabled features: ${hidden}${NC}"
            echo ""
        fi
    else
        echo "─────────────────────────────────────────────────────"
        echo "${DIM}Legend: ${GREEN}●${NC}${DIM} enabled  ${NC}○${DIM} disabled${NC}"
        echo "${DIM}Enable features: blackdot features enable <name>${NC}"
        echo ""
    fi

    echo "${DIM}Run 'blackdot <command> --help' for detailed options.${NC}"
    echo ""
    echo "${DIM}Runtime: ZSH shell${NC}"
}

# =========================
# Main blackdot() command
# =========================
# The unified entry point. Delegates all commands to the Go binary.
#
# Commands that MUST stay in shell (cannot be Go):
#   - cd: changes current directory
#   - edit: opens in current shell's EDITOR
#   - features enable/disable: also updates in-memory shell state

unalias dotfiles 2>/dev/null || true


# Main blackdot() function - delegates to Go binary
blackdot() {
    local cmd="${1:-help}"

    # Commands that MUST stay in shell (can't be Go)
    case "$cmd" in
        cd)
            # cd must run in current shell to change directory
            cd "$BLACKDOT_DIR"
            return $?
            ;;
        edit)
            # edit must run in current shell for EDITOR
            ${EDITOR:-vim} "$BLACKDOT_DIR"
            return $?
            ;;
    esac

    # Get Go binary path
    local go_bin=$(_blackdot_go_bin)
    if [[ -z "$go_bin" ]]; then
        echo "${RED}[ERROR]${NC} blackdot binary not found. Run: go build -o bin/blackdot ./cmd/blackdot" >&2
        return 1
    fi

    # Special handling for features enable/disable - update shell state too
    if [[ "$cmd" == "features" && ("${2:-}" == "enable" || "${2:-}" == "disable") ]]; then
        "$go_bin" "$@"
        local ret=$?
        # If successful, also update in-memory shell state
        if [[ $ret -eq 0 && -n "${3:-}" ]]; then
            if [[ "${2:-}" == "enable" ]]; then
                feature_enable "${3:-}" 2>/dev/null || true
            else
                feature_disable "${3:-}" 2>/dev/null || true
            fi
        fi
        return $ret
    fi

    # All commands go to Go binary
    "$go_bin" "$@"
}

# Short alias for blackdot command
alias d=blackdot

# =========================
# Tool Group Aliases
# =========================
# These delegate to the Go binary for cross-platform consistency.
# Usage: sshtools keys, awstools profiles, cdktools status, etc.

# Determine Go binary path
_blackdot_go_bin() {
    if [[ -x "$BLACKDOT_DIR/bin/blackdot" ]]; then
        echo "$BLACKDOT_DIR/bin/blackdot"
    elif command -v blackdot &>/dev/null; then
        echo "blackdot"
    else
        echo ""
    fi
}

# Tool group functions - delegate to Go binary
sshtools() {
    local bin=$(_blackdot_go_bin)
    if [[ -z "$bin" ]]; then
        echo "${RED}[ERROR]${NC} Go binary not found. Run: make build" >&2
        return 1
    fi
    "$bin" tools ssh "$@"
}

awstools() {
    local bin=$(_blackdot_go_bin)
    if [[ -z "$bin" ]]; then
        echo "${RED}[ERROR]${NC} Go binary not found. Run: make build" >&2
        return 1
    fi
    "$bin" tools aws "$@"
}

cdktools() {
    local bin=$(_blackdot_go_bin)
    if [[ -z "$bin" ]]; then
        echo "${RED}[ERROR]${NC} Go binary not found. Run: make build" >&2
        return 1
    fi
    "$bin" tools cdk "$@"
}

gotools() {
    local bin=$(_blackdot_go_bin)
    if [[ -z "$bin" ]]; then
        echo "${RED}[ERROR]${NC} Go binary not found. Run: make build" >&2
        return 1
    fi
    "$bin" tools go "$@"
}

rusttools() {
    local bin=$(_blackdot_go_bin)
    if [[ -z "$bin" ]]; then
        echo "${RED}[ERROR]${NC} Go binary not found. Run: make build" >&2
        return 1
    fi
    "$bin" tools rust "$@"
}

pytools() {
    local bin=$(_blackdot_go_bin)
    if [[ -z "$bin" ]]; then
        echo "${RED}[ERROR]${NC} Go binary not found. Run: make build" >&2
        return 1
    fi
    "$bin" tools python "$@"
}

dockertools() {
    local bin=$(_blackdot_go_bin)
    if [[ -z "$bin" ]]; then
        echo "${RED}[ERROR]${NC} Go binary not found. Run: make build" >&2
        return 1
    fi
    "$bin" tools docker "$@"
}

claudetools() {
    local bin=$(_blackdot_go_bin)
    if [[ -z "$bin" ]]; then
        echo "${RED}[ERROR]${NC} Go binary not found. Run: make build" >&2
        return 1
    fi
    "$bin" tools claude "$@"
}

# =========================
# Individual Tool Aliases (Go Binary)
# =========================
# Hyphenated aliases that call Go binary for cross-platform consistency.
# These match the PowerShell pattern: ssh-keys, aws-profiles, etc.
# The unhyphenated versions (sshkeys, awsprofiles) remain as shell functions
# in the tool-specific modules (60-aws.zsh, 65-ssh.zsh, etc.)

# SSH Tools (via Go binary)
ssh-keys()   { "$(_blackdot_go_bin)" tools ssh keys "$@"; }
ssh-gen()    { "$(_blackdot_go_bin)" tools ssh gen "$@"; }
ssh-list()   { "$(_blackdot_go_bin)" tools ssh list "$@"; }
ssh-fp()     { "$(_blackdot_go_bin)" tools ssh fp "$@"; }
ssh-copy()   { "$(_blackdot_go_bin)" tools ssh copy "$@"; }
ssh-tunnel() { "$(_blackdot_go_bin)" tools ssh tunnel "$@"; }
ssh-socks()  { "$(_blackdot_go_bin)" tools ssh socks "$@"; }
ssh-status() { "$(_blackdot_go_bin)" tools ssh status "$@"; }
ssh-agent-status() { "$(_blackdot_go_bin)" tools ssh agent "$@"; }

# AWS Tools (via Go binary)
aws-profiles() { "$(_blackdot_go_bin)" tools aws profiles "$@"; }
aws-who()      { "$(_blackdot_go_bin)" tools aws who "$@"; }
aws-login()    { "$(_blackdot_go_bin)" tools aws login "$@"; }
aws-status()   { "$(_blackdot_go_bin)" tools aws status "$@"; }
# aws-switch and aws-assume need shell wrappers to set env vars
aws-switch() {
    local output
    output=$("$(_blackdot_go_bin)" tools aws switch "$@")
    if [[ $? -eq 0 && -n "$output" ]]; then
        eval "$output"
    else
        echo "$output"
    fi
}
aws-assume() {
    local output
    output=$("$(_blackdot_go_bin)" tools aws assume "$@")
    if [[ $? -eq 0 && -n "$output" ]]; then
        eval "$output"
    else
        echo "$output"
    fi
}
aws-clear() {
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    echo "Cleared AWS temporary credentials"
}

# CDK Tools (via Go binary)
cdk-init()    { "$(_blackdot_go_bin)" tools cdk init "$@"; }
cdk-outputs() { "$(_blackdot_go_bin)" tools cdk outputs "$@"; }
cdk-context() { "$(_blackdot_go_bin)" tools cdk context "$@"; }
cdk-status()  { "$(_blackdot_go_bin)" tools cdk status "$@"; }
# cdk-env needs shell wrapper to set env vars
cdk-env() {
    local output
    output=$("$(_blackdot_go_bin)" tools cdk env "$@")
    if [[ $? -eq 0 && -n "$output" ]]; then
        eval "$output"
    else
        echo "$output"
    fi
}
cdk-env-clear() {
    unset CDK_DEFAULT_ACCOUNT CDK_DEFAULT_REGION
    echo "Cleared CDK environment variables"
}

# Go Tools (via Go binary)
go-new()       { "$(_blackdot_go_bin)" tools go new "$@"; }
go-init()      { "$(_blackdot_go_bin)" tools go init "$@"; }
go-test()      { "$(_blackdot_go_bin)" tools go test "$@"; }
go-cover()     { "$(_blackdot_go_bin)" tools go cover "$@"; }
go-lint()      { "$(_blackdot_go_bin)" tools go lint "$@"; }
go-outdated()  { "$(_blackdot_go_bin)" tools go outdated "$@"; }
go-update()    { "$(_blackdot_go_bin)" tools go update "$@"; }
go-build-all() { "$(_blackdot_go_bin)" tools go build-all "$@"; }
go-bench()     { "$(_blackdot_go_bin)" tools go bench "$@"; }
go-info()      { "$(_blackdot_go_bin)" tools go info "$@"; }

# Rust Tools (via Go binary)
rust-new()      { "$(_blackdot_go_bin)" tools rust new "$@"; }
rust-update()   { "$(_blackdot_go_bin)" tools rust update "$@"; }
rust-switch()   { "$(_blackdot_go_bin)" tools rust switch "$@"; }
rust-lint()     { "$(_blackdot_go_bin)" tools rust lint "$@"; }
rust-fix()      { "$(_blackdot_go_bin)" tools rust fix "$@"; }
rust-outdated() { "$(_blackdot_go_bin)" tools rust outdated "$@"; }
rust-expand()   { "$(_blackdot_go_bin)" tools rust expand "$@"; }
rust-info()     { "$(_blackdot_go_bin)" tools rust info "$@"; }

# Python Tools (via Go binary)
py-new()   { "$(_blackdot_go_bin)" tools python new "$@"; }
py-clean() { "$(_blackdot_go_bin)" tools python clean "$@"; }
py-venv()  { "$(_blackdot_go_bin)" tools python venv "$@"; }
py-test()  { "$(_blackdot_go_bin)" tools python test "$@"; }
py-cover() { "$(_blackdot_go_bin)" tools python cover "$@"; }
py-info()  { "$(_blackdot_go_bin)" tools python info "$@"; }

# Docker Tools (via Go binary)
docker-ps()      { "$(_blackdot_go_bin)" tools docker ps "$@"; }
docker-images()  { "$(_blackdot_go_bin)" tools docker images "$@"; }
docker-ip()      { "$(_blackdot_go_bin)" tools docker ip "$@"; }
docker-env()     { "$(_blackdot_go_bin)" tools docker env "$@"; }
docker-ports()   { "$(_blackdot_go_bin)" tools docker ports "$@"; }
docker-stats()   { "$(_blackdot_go_bin)" tools docker stats "$@"; }
docker-vols()    { "$(_blackdot_go_bin)" tools docker vols "$@"; }
docker-nets()    { "$(_blackdot_go_bin)" tools docker nets "$@"; }
docker-inspect() { "$(_blackdot_go_bin)" tools docker inspect "$@"; }
docker-clean()   { "$(_blackdot_go_bin)" tools docker clean "$@"; }
docker-prune()   { "$(_blackdot_go_bin)" tools docker prune "$@"; }
docker-status()  { "$(_blackdot_go_bin)" tools docker status "$@"; }

# Claude Tools (via Go binary)
claude-status() { "$(_blackdot_go_bin)" tools claude status "$@"; }
claude-env()    { "$(_blackdot_go_bin)" tools claude env "$@"; }
claude-init()   { "$(_blackdot_go_bin)" tools claude init "$@"; }
