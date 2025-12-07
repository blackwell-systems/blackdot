# =========================
# 61-cdk.zsh
# =========================
# AWS CDK aliases, helpers, and environment management
# Provides shortcuts and utilities for CDK development workflows

# Feature guard: skip if cdk_tools is disabled
if type feature_enabled &>/dev/null && ! feature_enabled "cdk_tools" 2>/dev/null; then
    return 0
fi

# =========================
# CDK Aliases
# =========================

# Core CDK commands
alias cdkd='cdk deploy'
alias cdks='cdk synth'
alias cdkdf='cdk diff'
alias cdkw='cdk watch'
alias cdkls='cdk list'
alias cdkdst='cdk destroy'
alias cdkb='cdk bootstrap'

# Common variations
alias cdkda='cdk deploy --all'
alias cdkdfa='cdk diff --all'
alias cdkhs='cdk deploy --hotswap'
alias cdkhsf='cdk deploy --hotswap-fallback'

# =========================
# CDK Helper Functions
# =========================

# Set CDK environment variables from current AWS profile
cdk-env() {
    local profile="${1:-${AWS_PROFILE:-}}"

    if [[ -z "$profile" ]]; then
        echo "Usage: cdk-env [profile]" >&2
        echo "Or set AWS_PROFILE first" >&2
        return 1
    fi

    # Get account ID
    local account
    account=$(aws sts get-caller-identity --profile "$profile" --query Account --output text 2>/dev/null)
    if [[ -z "$account" || "$account" == "None" ]]; then
        echo "Failed to get account ID. Are you authenticated?" >&2
        echo "Try: awslogin $profile" >&2
        return 1
    fi

    # Get region from profile or default
    local region
    region=$(aws configure get region --profile "$profile" 2>/dev/null)
    region="${region:-us-east-1}"

    export CDK_DEFAULT_ACCOUNT="$account"
    export CDK_DEFAULT_REGION="$region"

    echo "CDK environment set:"
    echo "  CDK_DEFAULT_ACCOUNT=$account"
    echo "  CDK_DEFAULT_REGION=$region"
}

# Clear CDK environment variables
cdk-env-clear() {
    unset CDK_DEFAULT_ACCOUNT
    unset CDK_DEFAULT_REGION
    echo "Cleared CDK_DEFAULT_ACCOUNT and CDK_DEFAULT_REGION"
}

# Deploy all stacks (with optional confirmation)
cdkall() {
    local confirm="${1:---require-approval broadening}"
    echo "Deploying all stacks..."
    cdk deploy --all $confirm "$@"
}

# Diff then prompt to deploy
cdkcheck() {
    local stack="${1:-}"

    echo "Running diff..."
    if [[ -n "$stack" ]]; then
        cdk diff "$stack"
    else
        cdk diff --all
    fi

    echo ""
    read -q "REPLY?Deploy these changes? [y/N] "
    echo ""

    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        if [[ -n "$stack" ]]; then
            cdk deploy "$stack"
        else
            cdk deploy --all
        fi
    else
        echo "Deployment cancelled"
    fi
}

# Hotswap deploy for faster Lambda/ECS updates
cdkhotswap() {
    local stack="${1:-}"

    if [[ -n "$stack" ]]; then
        echo "Hotswap deploying: $stack"
        cdk deploy "$stack" --hotswap
    else
        echo "Hotswap deploying all stacks..."
        cdk deploy --all --hotswap
    fi
}

# Show CloudFormation stack outputs
cdkoutputs() {
    local stack="${1:-}"

    if [[ -z "$stack" ]]; then
        # List available stacks
        echo "Available stacks:"
        aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
            --query 'StackSummaries[].StackName' --output table
        echo ""
        echo "Usage: cdkoutputs <stack-name>"
        return 1
    fi

    echo "Outputs for stack: $stack"
    aws cloudformation describe-stacks --stack-name "$stack" \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' --output table
}

# Initialize a new CDK project
cdkinit() {
    local lang="${1:-typescript}"

    echo "Initializing CDK project with language: $lang"
    cdk init app --language "$lang"

    if [[ "$lang" == "typescript" ]]; then
        echo ""
        echo "Installing dependencies..."
        npm install
    fi
}

# Show CDK context values
cdkctx() {
    if [[ -f "cdk.context.json" ]]; then
        echo "CDK Context (cdk.context.json):"
        cat cdk.context.json | jq .
    else
        echo "No cdk.context.json found in current directory"
    fi
}

# Clear CDK context cache
cdkctx-clear() {
    if [[ -f "cdk.context.json" ]]; then
        rm cdk.context.json
        echo "Cleared cdk.context.json"
    else
        echo "No cdk.context.json to clear"
    fi
}

# =========================
# CDK Tools Help
# =========================

cdktools() {
    # Source theme colors
    source "${DOTFILES_DIR:-$HOME/workspace/dotfiles}/lib/_colors.sh"

    # Check if CDK is installed and if we're in a CDK project
    local logo_color has_cdk in_project
    if command -v cdk &>/dev/null; then
        has_cdk=true
        if [[ -f "cdk.json" ]]; then
            logo_color="$CLR_CDK"
            in_project=true
        else
            logo_color="$CLR_PRIMARY"
            in_project=false
        fi
    else
        has_cdk=false
        in_project=false
        logo_color="$CLR_ERROR"
    fi

    echo ""
    echo -e "${logo_color}   ██████╗██████╗ ██╗  ██╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗${CLR_NC}"
    echo -e "${logo_color}  ██╔════╝██╔══██╗██║ ██╔╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝${CLR_NC}"
    echo -e "${logo_color}  ██║     ██║  ██║█████╔╝        ██║   ██║   ██║██║   ██║██║     ███████╗${CLR_NC}"
    echo -e "${logo_color}  ██║     ██║  ██║██╔═██╗        ██║   ██║   ██║██║   ██║██║     ╚════██║${CLR_NC}"
    echo -e "${logo_color}  ╚██████╗██████╔╝██║  ██╗       ██║   ╚██████╔╝╚██████╔╝███████╗███████║${CLR_NC}"
    echo -e "${logo_color}   ╚═════╝╚═════╝ ╚═╝  ╚═╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝${CLR_NC}"
    echo ""

    # Aliases section
    echo -e "  ${CLR_BOX}╭─────────────────────────────────────────────────────────────────╮${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}ALIASES${CLR_NC}                                                      ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdkd${CLR_NC}               ${CLR_MUTED}cdk deploy${CLR_NC}                                 ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdks${CLR_NC}               ${CLR_MUTED}cdk synth${CLR_NC}                                  ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdkdf${CLR_NC}              ${CLR_MUTED}cdk diff${CLR_NC}                                   ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdkw${CLR_NC}               ${CLR_MUTED}cdk watch${CLR_NC}                                  ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdkls${CLR_NC}              ${CLR_MUTED}cdk list${CLR_NC}                                   ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdkdst${CLR_NC}             ${CLR_MUTED}cdk destroy${CLR_NC}                                ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdkb${CLR_NC}               ${CLR_MUTED}cdk bootstrap${CLR_NC}                              ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdkda${CLR_NC}              ${CLR_MUTED}cdk deploy --all${CLR_NC}                           ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdkhs${CLR_NC}              ${CLR_MUTED}cdk deploy --hotswap${CLR_NC}                       ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}HELPER FUNCTIONS${CLR_NC}                                            ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdk-env${CLR_NC} [profile]  ${CLR_MUTED}Set CDK_DEFAULT_ACCOUNT/REGION from AWS${CLR_NC}    ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdk-env-clear${CLR_NC}      ${CLR_MUTED}Clear CDK environment variables${CLR_NC}            ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdkall${CLR_NC}             ${CLR_MUTED}Deploy all stacks${CLR_NC}                          ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdkcheck${CLR_NC} [stack]   ${CLR_MUTED}Diff then prompt to deploy${CLR_NC}                 ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdkhotswap${CLR_NC} [stack] ${CLR_MUTED}Fast deploy for Lambda/ECS${CLR_NC}                 ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdkoutputs${CLR_NC} <stack> ${CLR_MUTED}Show CloudFormation stack outputs${CLR_NC}          ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdkinit${CLR_NC} [lang]     ${CLR_MUTED}Initialize new CDK project${CLR_NC}                 ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdkctx${CLR_NC}             ${CLR_MUTED}Show CDK context values${CLR_NC}                    ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_SECONDARY}cdkctx-clear${CLR_NC}       ${CLR_MUTED}Clear CDK context cache${CLR_NC}                    ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}╰─────────────────────────────────────────────────────────────────╯${CLR_NC}"
    echo ""

    # Current Status
    echo -e "  ${CLR_BOLD}Current Status${CLR_NC}"
    echo -e "  ${CLR_MUTED}───────────────────────────────────────${CLR_NC}"

    if [[ "$has_cdk" == "true" ]]; then
        local cdk_version
        cdk_version=$(cdk --version 2>/dev/null | head -1)
        echo -e "    ${CLR_MUTED}CDK${CLR_NC}       ${CLR_SUCCESS}✓ installed${CLR_NC} ${CLR_MUTED}($cdk_version)${CLR_NC}"
    else
        echo -e "    ${CLR_MUTED}CDK${CLR_NC}       ${CLR_ERROR}✗ not installed${CLR_NC} ${CLR_MUTED}(npm install -g aws-cdk)${CLR_NC}"
    fi

    if [[ "$in_project" == "true" ]]; then
        echo -e "    ${CLR_MUTED}Project${CLR_NC}   ${CLR_SUCCESS}✓ cdk.json found${CLR_NC}"
        # Show app language if detectable
        if [[ -f "package.json" ]]; then
            echo -e "    ${CLR_MUTED}Language${CLR_NC}  ${CLR_PRIMARY}TypeScript/JavaScript${CLR_NC}"
        elif [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
            echo -e "    ${CLR_MUTED}Language${CLR_NC}  ${CLR_PRIMARY}Python${CLR_NC}"
        elif [[ -f "pom.xml" ]]; then
            echo -e "    ${CLR_MUTED}Language${CLR_NC}  ${CLR_PRIMARY}Java${CLR_NC}"
        elif [[ -f "go.mod" ]]; then
            echo -e "    ${CLR_MUTED}Language${CLR_NC}  ${CLR_PRIMARY}Go${CLR_NC}"
        fi
    else
        echo -e "    ${CLR_MUTED}Project${CLR_NC}   ${CLR_MUTED}not in CDK project${CLR_NC}"
    fi

    # CDK environment
    if [[ -n "${CDK_DEFAULT_ACCOUNT:-}" ]]; then
        echo -e "    ${CLR_MUTED}Account${CLR_NC}   ${CLR_PRIMARY}$CDK_DEFAULT_ACCOUNT${CLR_NC}"
    fi
    if [[ -n "${CDK_DEFAULT_REGION:-}" ]]; then
        echo -e "    ${CLR_MUTED}Region${CLR_NC}    ${CLR_PRIMARY}$CDK_DEFAULT_REGION${CLR_NC}"
    fi

    echo ""
}

# =========================
# Zsh Completions
# =========================

# Helper: get AWS profiles for completion
_cdk_aws_profiles() {
    local profiles
    profiles=(${(f)"$(aws configure list-profiles 2>/dev/null)"})
    _describe 'AWS profiles' profiles
}

# Helper: get CDK stacks for completion
_cdk_stacks() {
    local stacks
    if [[ -f "cdk.json" ]]; then
        stacks=(${(f)"$(cdk list 2>/dev/null)"})
        _describe 'CDK stacks' stacks
    fi
}

# Helper: get CloudFormation stacks for completion
_cf_stacks() {
    local stacks
    stacks=(${(f)"$(aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query 'StackSummaries[].StackName' --output text 2>/dev/null | tr '\t' '\n')"})
    _describe 'CloudFormation stacks' stacks
}

# Completion for cdk-env
_cdk_env() {
    _arguments '1:profile:_cdk_aws_profiles'
}
compdef _cdk_env cdk-env

# Completion for cdkcheck
_cdkcheck() {
    _arguments '1:stack:_cdk_stacks'
}
compdef _cdkcheck cdkcheck

# Completion for cdkhotswap
_cdkhotswap() {
    _arguments '1:stack:_cdk_stacks'
}
compdef _cdkhotswap cdkhotswap

# Completion for cdkoutputs
_cdkoutputs() {
    _arguments '1:stack:_cf_stacks'
}
compdef _cdkoutputs cdkoutputs

# Completion for cdkinit
_cdkinit() {
    local languages
    languages=(typescript python java go csharp fsharp)
    _describe 'CDK languages' languages
}
compdef _cdkinit cdkinit
