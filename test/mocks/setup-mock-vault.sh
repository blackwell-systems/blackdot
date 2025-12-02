#!/usr/bin/env bash
# ============================================================
# FILE: test/mocks/setup-mock-vault.sh
# Creates a mock vault with test credentials using pass
#
# This script sets up a complete mock vault environment for testing
# the dotfiles vault integration without real credentials.
#
# Usage:
#   ./setup-mock-vault.sh           # Interactive - prompts for GPG passphrase
#   ./setup-mock-vault.sh --no-pass # No passphrase (for CI/automated testing)
#   ./setup-mock-vault.sh --clean   # Remove existing mock vault first
#
# Requirements:
#   - gpg (GnuPG)
#   - pass (password-store)
#
# Environment:
#   PASSWORD_STORE_DIR  - Override default ~/.password-store
#   GNUPGHOME          - Override default ~/.gnupg
# ============================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
pass_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; }

# ============================================================
# Configuration
# ============================================================
GPG_TEST_NAME="Dotfiles Test User"
GPG_TEST_EMAIL="test@dotfiles.local"
GPG_TEST_KEY_ID=""

PASSWORD_STORE_DIR="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
GNUPGHOME="${GNUPGHOME:-$HOME/.gnupg}"
PASS_PREFIX="dotfiles"

NO_PASSPHRASE=false
CLEAN_FIRST=false

# ============================================================
# Parse arguments
# ============================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-pass|--no-passphrase)
            NO_PASSPHRASE=true
            ;;
        --clean)
            CLEAN_FIRST=true
            ;;
        --help|-h)
            echo "Usage: $0 [--no-pass] [--clean]"
            echo ""
            echo "Options:"
            echo "  --no-pass    Create GPG key without passphrase (for automated testing)"
            echo "  --clean      Remove existing mock vault before setup"
            echo "  --help       Show this help message"
            exit 0
            ;;
        *)
            fail "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

# ============================================================
# Cleanup function
# ============================================================
cleanup_mock_vault() {
    info "Cleaning up existing mock vault..."

    # Remove password store dotfiles prefix
    if [[ -d "$PASSWORD_STORE_DIR/$PASS_PREFIX" ]]; then
        rm -rf "$PASSWORD_STORE_DIR/$PASS_PREFIX"
        pass_ok "Removed $PASSWORD_STORE_DIR/$PASS_PREFIX"
    fi

    # Optionally remove test GPG key
    local key_id
    key_id=$(gpg --list-keys --keyid-format LONG "$GPG_TEST_EMAIL" 2>/dev/null | grep -E "^pub" | awk '{print $2}' | cut -d'/' -f2 || true)
    if [[ -n "$key_id" ]]; then
        gpg --batch --yes --delete-secret-and-public-key "$key_id" 2>/dev/null || true
        pass_ok "Removed test GPG key"
    fi
}

# ============================================================
# Check dependencies
# ============================================================
check_dependencies() {
    info "Checking dependencies..."

    if ! command -v gpg >/dev/null 2>&1; then
        fail "gpg not found. Install with: apt install gnupg / brew install gnupg"
        exit 1
    fi
    pass_ok "gpg installed ($(gpg --version | head -1))"

    if ! command -v pass >/dev/null 2>&1; then
        fail "pass not found. Install with: apt install pass / brew install pass"
        exit 1
    fi
    pass_ok "pass installed ($(pass version | head -1))"
}

# ============================================================
# Create test GPG key
# ============================================================
create_gpg_key() {
    info "Creating test GPG key..."

    # Check if key already exists
    if gpg --list-keys "$GPG_TEST_EMAIL" >/dev/null 2>&1; then
        GPG_TEST_KEY_ID=$(gpg --list-keys --keyid-format LONG "$GPG_TEST_EMAIL" | grep -E "^pub" | awk '{print $2}' | cut -d'/' -f2)
        warn "Test GPG key already exists: $GPG_TEST_KEY_ID"
        return 0
    fi

    # Create key params file
    local key_params
    key_params=$(mktemp)

    if [[ "$NO_PASSPHRASE" == "true" ]]; then
        cat > "$key_params" << EOF
%no-protection
Key-Type: RSA
Key-Length: 2048
Name-Real: $GPG_TEST_NAME
Name-Email: $GPG_TEST_EMAIL
Expire-Date: 0
%commit
EOF
    else
        cat > "$key_params" << EOF
Key-Type: RSA
Key-Length: 2048
Name-Real: $GPG_TEST_NAME
Name-Email: $GPG_TEST_EMAIL
Expire-Date: 0
%commit
EOF
    fi

    # Generate key
    gpg --batch --gen-key "$key_params"
    rm -f "$key_params"

    # Get the key ID
    GPG_TEST_KEY_ID=$(gpg --list-keys --keyid-format LONG "$GPG_TEST_EMAIL" | grep -E "^pub" | awk '{print $2}' | cut -d'/' -f2)

    pass_ok "Created GPG key: $GPG_TEST_KEY_ID"
}

# ============================================================
# Initialize password store
# ============================================================
init_pass() {
    info "Initializing password store..."

    if [[ -f "$PASSWORD_STORE_DIR/.gpg-id" ]]; then
        warn "Password store already initialized"
        return 0
    fi

    pass init "$GPG_TEST_KEY_ID"
    pass_ok "Initialized password store with key: $GPG_TEST_KEY_ID"
}

# ============================================================
# Create mock credentials
# ============================================================
create_mock_credentials() {
    info "Creating mock credentials..."

    # Helper function to insert content
    insert_item() {
        local name="$1"
        local content="$2"
        local path="$PASS_PREFIX/$name"

        if pass show "$path" >/dev/null 2>&1; then
            warn "Item already exists: $name (skipping)"
            return 0
        fi

        echo "$content" | pass insert -m "$path" >/dev/null 2>&1
        pass_ok "Created: $name"
    }

    # ============================================================
    # SSH Keys (mock ed25519 keys - NOT real, for testing only)
    # ============================================================

    insert_item "SSH-GitHub-Enterprise" "-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACBTRVNUX0tFWV9GT1JfR0lUSFVCX0VOVEVSUFJJU0UAAAAAAAAAAAAAAAG
XAAAAEHRlc3RAZXhhbXBsZS5jb20BAgMEBQYHCAkKCwwNDg8QAAAAAAAAAAAAAAAAAAA=
-----END OPENSSH PRIVATE KEY-----
# MOCK KEY - DO NOT USE IN PRODUCTION
# This is a test key for dotfiles vault testing"

    insert_item "SSH-GitHub-Blackwell" "-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACBURVNUX0tFWV9GT1JfR0lUSFVCX0JMQUNLV0VMTAAAAAAAAAAAAAAAAAG
XAAAAEHRlc3RAZXhhbXBsZS5jb20BAgMEBQYHCAkKCwwNDg8QAAAAAAAAAAAAAAAAAAA=
-----END OPENSSH PRIVATE KEY-----
# MOCK KEY - DO NOT USE IN PRODUCTION
# This is a test key for dotfiles vault testing"

    # ============================================================
    # SSH Config
    # ============================================================
    insert_item "SSH-Config" "# SSH Config - Mock for testing
# Generated by setup-mock-vault.sh

Host *
    AddKeysToAgent yes
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_blackwell

Host github.enterprise.example.com
    HostName github.enterprise.example.com
    User git
    IdentityFile ~/.ssh/id_ed25519_enterprise_ghub

Host dev-server
    HostName dev.example.com
    User developer
    IdentityFile ~/.ssh/id_ed25519
    Port 22

Host staging
    HostName staging.example.com
    User deploy
    ProxyJump bastion

Host bastion
    HostName bastion.example.com
    User admin
    IdentityFile ~/.ssh/id_ed25519"

    # ============================================================
    # AWS Config
    # ============================================================
    insert_item "AWS-Config" "# AWS Config - Mock for testing
# Generated by setup-mock-vault.sh

[default]
region = us-east-1
output = json

[profile dev]
region = us-west-2
output = json

[profile staging]
region = us-east-1
output = json
role_arn = arn:aws:iam::123456789012:role/StagingRole
source_profile = default

[profile production]
region = us-east-1
output = json
sso_start_url = https://example.awsapps.com/start
sso_region = us-east-1
sso_account_id = 123456789012
sso_role_name = ProductionAdmin"

    # ============================================================
    # AWS Credentials
    # ============================================================
    insert_item "AWS-Credentials" "# AWS Credentials - Mock for testing
# Generated by setup-mock-vault.sh
# THESE ARE FAKE CREDENTIALS - DO NOT USE

[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[dev]
aws_access_key_id = AKIAI44QH8DHBEXAMPLE
aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY"

    # ============================================================
    # Git Config
    # ============================================================
    insert_item "Git-Config" "# Git Config - Mock for testing
# Generated by setup-mock-vault.sh

[user]
    name = Test User
    email = test@example.com
    signingkey = ABC123DEF456

[core]
    editor = vim
    autocrlf = input
    whitespace = fix

[init]
    defaultBranch = main

[pull]
    rebase = true

[push]
    default = current
    autoSetupRemote = true

[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    lg = log --oneline --graph --all

[diff]
    colorMoved = default

[merge]
    conflictstyle = diff3"

    # ============================================================
    # Environment Secrets
    # ============================================================
    insert_item "Environment-Secrets" "# Environment Secrets - Mock for testing
# Generated by setup-mock-vault.sh
# THESE ARE FAKE SECRETS - DO NOT USE

# API Keys
export GITHUB_TOKEN=\"ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\"
export OPENAI_API_KEY=\"sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\"
export ANTHROPIC_API_KEY=\"sk-ant-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\"

# Database
export DATABASE_URL=\"postgres://user:password@localhost:5432/mydb\"

# Cloud Services
export AWS_ACCESS_KEY_ID=\"AKIAIOSFODNN7EXAMPLE\"
export AWS_SECRET_ACCESS_KEY=\"wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY\"

# Application Secrets
export SECRET_KEY=\"super-secret-key-for-testing-only-not-real\"
export JWT_SECRET=\"jwt-secret-for-testing-only-not-real\""

    # ============================================================
    # Claude Profiles
    # ============================================================
    insert_item "Claude-Profiles" '{
  "version": 1,
  "profiles": {
    "default": {
      "model": "claude-sonnet-4-20250514",
      "maxTokens": 4096,
      "temperature": 0.7
    },
    "coding": {
      "model": "claude-sonnet-4-20250514",
      "maxTokens": 8192,
      "temperature": 0.3,
      "systemPrompt": "You are a helpful coding assistant."
    },
    "creative": {
      "model": "claude-sonnet-4-20250514",
      "maxTokens": 4096,
      "temperature": 0.9,
      "systemPrompt": "You are a creative writing assistant."
    }
  },
  "activeProfile": "default"
}'

    pass_ok "All mock credentials created!"
}

# ============================================================
# Verify setup
# ============================================================
verify_setup() {
    info "Verifying mock vault setup..."
    echo ""

    echo -e "${CYAN}Password Store Contents:${NC}"
    pass ls "$PASS_PREFIX" 2>/dev/null || warn "Could not list password store"
    echo ""

    echo -e "${CYAN}GPG Key:${NC}"
    gpg --list-keys "$GPG_TEST_EMAIL" 2>/dev/null | head -5
    echo ""

    # Test retrieval
    info "Testing credential retrieval..."
    if pass show "$PASS_PREFIX/Git-Config" >/dev/null 2>&1; then
        pass_ok "Can retrieve credentials from vault"
    else
        fail "Cannot retrieve credentials from vault"
    fi
}

# ============================================================
# Print usage instructions
# ============================================================
print_usage() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Mock vault setup complete!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "To use with dotfiles vault commands:"
    echo ""
    echo -e "  ${BOLD}export DOTFILES_VAULT_BACKEND=pass${NC}"
    echo ""
    echo "Then test with:"
    echo ""
    echo "  dotfiles vault check"
    echo "  dotfiles vault restore --preview"
    echo "  dotfiles drift"
    echo ""
    echo "Mock items created:"
    echo "  - SSH-GitHub-Enterprise  (mock SSH key)"
    echo "  - SSH-GitHub-Blackwell   (mock SSH key)"
    echo "  - SSH-Config             (SSH configuration)"
    echo "  - AWS-Config             (AWS configuration)"
    echo "  - AWS-Credentials        (mock AWS credentials)"
    echo "  - Git-Config             (Git configuration)"
    echo "  - Environment-Secrets    (mock environment secrets)"
    echo "  - Claude-Profiles        (Claude profiles JSON)"
    echo ""
    echo -e "${YELLOW}Note: All credentials are FAKE and for testing only!${NC}"
    echo ""
}

# ============================================================
# Main
# ============================================================
main() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Dotfiles Mock Vault Setup${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    check_dependencies

    if [[ "$CLEAN_FIRST" == "true" ]]; then
        cleanup_mock_vault
    fi

    create_gpg_key
    init_pass
    create_mock_credentials
    verify_setup
    print_usage
}

main
