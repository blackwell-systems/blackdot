#!/usr/bin/env zsh
# ============================================================
# FILE: templates/_variables.sh
# Default template variables - Single Source of Truth
#
# This file defines default values for all template variables.
# Machine-specific overrides go in _variables.local.sh (gitignored).
#
# Variable Precedence (highest to lowest):
#   1. Environment variables (BLACKDOT_TMPL_*)
#   2. _variables.local.sh (machine-specific)
#   3. Machine-type defaults (TMPL_WORK / TMPL_PERSONAL below)
#   4. TMPL_DEFAULTS (this file)
#   5. TMPL_AUTO (auto-detected, set by lib/_templates.sh)
#
# Usage:
#   Run 'blackdot template init' to create _variables.local.sh
#   Run 'blackdot template vars' to see all current values
# ============================================================

# ============================================================
# Default Values
# These are used when no override is provided
# ============================================================
typeset -gA TMPL_DEFAULTS=(
    # ─────────────────────────────────────────────────────────
    # Git Configuration
    # ─────────────────────────────────────────────────────────
    [git_name]=""                    # Your full name (required)
    [git_email]=""                   # Your email (required)
    [git_signing_key]=""             # GPG key ID (optional)
    [git_default_branch]="main"      # Default branch name
    [git_editor]="nvim"              # Git editor

    # ─────────────────────────────────────────────────────────
    # AWS Configuration
    # ─────────────────────────────────────────────────────────
    [aws_profile]="default"          # Default AWS profile
    [aws_region]="us-east-1"         # Default AWS region
    [aws_output]="json"              # Default output format

    # ─────────────────────────────────────────────────────────
    # AWS Bedrock (Claude API)
    # ─────────────────────────────────────────────────────────
    [bedrock_profile]=""             # Bedrock AWS profile (optional)
    [bedrock_region]="us-west-2"     # Bedrock region

    # ─────────────────────────────────────────────────────────
    # Editor & Tools
    # ─────────────────────────────────────────────────────────
    [editor]="nvim"                  # Default editor ($EDITOR)
    [visual]="code"                  # Visual editor ($VISUAL)
    [pager]="less"                   # Pager for long output

    # ─────────────────────────────────────────────────────────
    # Paths
    # ─────────────────────────────────────────────────────────
    [projects_dir]=""                # Projects directory (auto: $WORKSPACE/projects)
    [notes_dir]=""                   # Notes directory (auto: $WORKSPACE/notes)
    [scripts_dir]=""                 # Custom scripts (auto: $WORKSPACE/scripts)

    # ─────────────────────────────────────────────────────────
    # SSH Configuration
    # ─────────────────────────────────────────────────────────
    [ssh_default_user]=""            # Default SSH username
    [ssh_default_identity]=""        # Default SSH key path

    # ─────────────────────────────────────────────────────────
    # GitHub / Git Hosts
    # ─────────────────────────────────────────────────────────
    [github_user]=""                 # GitHub username
    [github_enterprise_host]=""      # GitHub Enterprise hostname (optional)
    [github_enterprise_user]=""      # GitHub Enterprise username (optional)

    # ─────────────────────────────────────────────────────────
    # Shell Customization
    # ─────────────────────────────────────────────────────────
    [shell_theme]="powerlevel10k"    # Shell theme
    [enable_aws_prompt]="true"       # Show AWS profile in prompt
    [enable_k8s_prompt]="false"      # Show Kubernetes context in prompt

    # ─────────────────────────────────────────────────────────
    # Feature Flags
    # ─────────────────────────────────────────────────────────
    [enable_homebrew]="true"         # Enable Homebrew integration
    [enable_nvm]="true"              # Enable Node Version Manager
    [enable_pyenv]="false"           # Enable Python version manager
    [enable_rbenv]="false"           # Enable Ruby version manager
    [enable_sdkman]="false"          # Enable SDKMAN (Java)
)

# ============================================================
# Work Machine Defaults
# Applied when machine_type == "work"
# ============================================================
typeset -gA TMPL_WORK=(
    # Example work overrides - customize in _variables.local.sh
    # [git_email]="you@company.com"
    # [aws_profile]="work"
    # [github_enterprise_host]="github.company.com"
)

# ============================================================
# Personal Machine Defaults
# Applied when machine_type == "personal"
# ============================================================
typeset -gA TMPL_PERSONAL=(
    # Example personal overrides - customize in _variables.local.sh
    # [git_email]="you@personal.com"
    # [aws_profile]="personal"
)

# ============================================================
# SSH Hosts Configuration (for ssh-config.tmpl)
# Format: name|hostname|user|identity_file|extra_options
# ============================================================
typeset -ga SSH_HOSTS=(
    # Example entries - customize in _variables.local.sh
    # "github|github.com|git|~/.ssh/id_ed25519_github|"
    # "work-server|server.company.com|deploy|~/.ssh/id_ed25519_work|ProxyJump bastion"
)

# ============================================================
# Helper function to get computed values
# These fill in blanks with sensible defaults
# ============================================================
get_computed_defaults() {
    # Set path defaults based on workspace target
    # Priority: TMPL_AUTO[workspace] > WORKSPACE_TARGET > $HOME/workspace
    local workspace
    if [[ -n "${TMPL_AUTO[workspace]:-}" ]]; then
        workspace="${TMPL_AUTO[workspace]}"
    elif [[ -n "${WORKSPACE_TARGET:-}" ]]; then
        workspace="${WORKSPACE_TARGET/#\~/$HOME}"
    else
        workspace="$HOME/workspace"
    fi

    [[ -z "${TMPL_DEFAULTS[projects_dir]}" ]] && TMPL_DEFAULTS[projects_dir]="$workspace/projects"
    [[ -z "${TMPL_DEFAULTS[notes_dir]}" ]] && TMPL_DEFAULTS[notes_dir]="$workspace/notes"
    [[ -z "${TMPL_DEFAULTS[scripts_dir]}" ]] && TMPL_DEFAULTS[scripts_dir]="$workspace/scripts"
}

# Run computed defaults
get_computed_defaults
