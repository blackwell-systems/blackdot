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
    # Colors
    local green='\033[0;32m'
    local red='\033[0;31m'
    local yellow='\033[0;33m'
    local cyan='\033[0;36m'
    local magenta='\033[0;35m'
    local bold='\033[1m'
    local dim='\033[2m'
    local nc='\033[0m'

    # Check if CDK is installed and if we're in a CDK project
    local logo_color has_cdk in_project
    if command -v cdk &>/dev/null; then
        has_cdk=true
        if [[ -f "cdk.json" ]]; then
            logo_color="$green"
            in_project=true
        else
            logo_color="$cyan"
            in_project=false
        fi
    else
        has_cdk=false
        in_project=false
        logo_color="$red"
    fi

    echo ""
    echo -e "${logo_color}   ██████╗██████╗ ██╗  ██╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗${nc}"
    echo -e "${logo_color}  ██╔════╝██╔══██╗██║ ██╔╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝${nc}"
    echo -e "${logo_color}  ██║     ██║  ██║█████╔╝        ██║   ██║   ██║██║   ██║██║     ███████╗${nc}"
    echo -e "${logo_color}  ██║     ██║  ██║██╔═██╗        ██║   ██║   ██║██║   ██║██║     ╚════██║${nc}"
    echo -e "${logo_color}  ╚██████╗██████╔╝██║  ██╗       ██║   ╚██████╔╝╚██████╔╝███████╗███████║${nc}"
    echo -e "${logo_color}   ╚═════╝╚═════╝ ╚═╝  ╚═╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝${nc}"
    echo ""

    # Aliases section
    echo -e "  ${dim}╭─────────────────────────────────────────────────────────────────╮${nc}"
    echo -e "  ${dim}│${nc}  ${bold}${cyan}ALIASES${nc}                                                      ${dim}│${nc}"
    echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdkd${nc}               ${dim}cdk deploy${nc}                                 ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdks${nc}               ${dim}cdk synth${nc}                                  ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdkdf${nc}              ${dim}cdk diff${nc}                                   ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdkw${nc}               ${dim}cdk watch${nc}                                  ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdkls${nc}              ${dim}cdk list${nc}                                   ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdkdst${nc}             ${dim}cdk destroy${nc}                                ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdkb${nc}               ${dim}cdk bootstrap${nc}                              ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdkda${nc}              ${dim}cdk deploy --all${nc}                           ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdkhs${nc}              ${dim}cdk deploy --hotswap${nc}                       ${dim}│${nc}"
    echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
    echo -e "  ${dim}│${nc}  ${bold}${cyan}HELPER FUNCTIONS${nc}                                            ${dim}│${nc}"
    echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdk-env${nc} [profile]  ${dim}Set CDK_DEFAULT_ACCOUNT/REGION from AWS${nc}    ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdk-env-clear${nc}      ${dim}Clear CDK environment variables${nc}            ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdkall${nc}             ${dim}Deploy all stacks${nc}                          ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdkcheck${nc} [stack]   ${dim}Diff then prompt to deploy${nc}                 ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdkhotswap${nc} [stack] ${dim}Fast deploy for Lambda/ECS${nc}                 ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdkoutputs${nc} <stack> ${dim}Show CloudFormation stack outputs${nc}          ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdkinit${nc} [lang]     ${dim}Initialize new CDK project${nc}                 ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdkctx${nc}             ${dim}Show CDK context values${nc}                    ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}cdkctx-clear${nc}       ${dim}Clear CDK context cache${nc}                    ${dim}│${nc}"
    echo -e "  ${dim}╰─────────────────────────────────────────────────────────────────╯${nc}"
    echo ""

    # Current Status
    echo -e "  ${bold}Current Status${nc}"
    echo -e "  ${dim}───────────────────────────────────────${nc}"

    if [[ "$has_cdk" == "true" ]]; then
        local cdk_version
        cdk_version=$(cdk --version 2>/dev/null | head -1)
        echo -e "    ${dim}CDK${nc}       ${green}✓ installed${nc} ${dim}($cdk_version)${nc}"
    else
        echo -e "    ${dim}CDK${nc}       ${red}✗ not installed${nc} ${dim}(npm install -g aws-cdk)${nc}"
    fi

    if [[ "$in_project" == "true" ]]; then
        echo -e "    ${dim}Project${nc}   ${green}✓ cdk.json found${nc}"
        # Show app language if detectable
        if [[ -f "package.json" ]]; then
            echo -e "    ${dim}Language${nc}  ${cyan}TypeScript/JavaScript${nc}"
        elif [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
            echo -e "    ${dim}Language${nc}  ${cyan}Python${nc}"
        elif [[ -f "pom.xml" ]]; then
            echo -e "    ${dim}Language${nc}  ${cyan}Java${nc}"
        elif [[ -f "go.mod" ]]; then
            echo -e "    ${dim}Language${nc}  ${cyan}Go${nc}"
        fi
    else
        echo -e "    ${dim}Project${nc}   ${dim}not in CDK project${nc}"
    fi

    # CDK environment
    if [[ -n "${CDK_DEFAULT_ACCOUNT:-}" ]]; then
        echo -e "    ${dim}Account${nc}   ${cyan}$CDK_DEFAULT_ACCOUNT${nc}"
    fi
    if [[ -n "${CDK_DEFAULT_REGION:-}" ]]; then
        echo -e "    ${dim}Region${nc}    ${cyan}$CDK_DEFAULT_REGION${nc}"
    fi

    echo ""
}
