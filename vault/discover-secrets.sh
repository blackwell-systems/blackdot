#!/usr/bin/env zsh
# ============================================================
# FILE: vault/discover-secrets.sh
# Auto-discover SSH keys, AWS configs, and other secrets
# Generates vault-items.json from discovered items
# ============================================================
set -euo pipefail

# Source common functions
VAULT_DIR="$(cd "$(dirname "${0:a}")" && pwd)"
DOTFILES_DIR="$(dirname "$VAULT_DIR")"
source "$DOTFILES_DIR/lib/_logging.sh"

# Output file
VAULT_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/vault-items.json"

# Custom paths to scan (in addition to standard locations)
typeset -a CUSTOM_SSH_PATHS=()
typeset -a CUSTOM_CONFIG_PATHS=()

# ============================================================
# Discovery Functions
# ============================================================

discover_ssh_keys() {
    local -A keys=()
    local -a scan_dirs=("$HOME/.ssh")

    # Add custom SSH paths
    scan_dirs+=("${CUSTOM_SSH_PATHS[@]}")

    for ssh_dir in "${scan_dirs[@]}"; do
        [[ ! -d "$ssh_dir" ]] && continue

        # Find all private keys (files without .pub extension and not known_hosts/config)
        for keyfile in "$ssh_dir"/*; do
            [[ ! -f "$keyfile" ]] && continue
            [[ "$keyfile" == *.pub ]] && continue
            [[ "$(basename "$keyfile")" == "known_hosts" ]] && continue
            [[ "$(basename "$keyfile")" == "config" ]] && continue
            [[ "$(basename "$keyfile")" == "authorized_keys" ]] && continue

            # Check if it looks like a private key
            if head -n 1 "$keyfile" 2>/dev/null | grep -qE '^-----BEGIN .* PRIVATE KEY-----'; then
                local basename="$(basename "$keyfile")"
                local name=$(normalize_ssh_key_name "$basename")

                # Use relative path if in standard location, absolute otherwise
                if [[ "$ssh_dir" == "$HOME/.ssh" ]]; then
                    keys[$name]="~/.ssh/$basename"
                else
                    keys[$name]="$keyfile"
                fi
                info "Found SSH key: $basename → $name"
            fi
        done
    done

    # Return as JSON array
    if [[ ${#keys[@]} -gt 0 ]]; then
        echo "$keys[@]"
    fi
}

normalize_ssh_key_name() {
    local filename="$1"
    local name=""

    # Try to extract meaningful name from filename
    # id_ed25519_github → GitHub
    # id_rsa_work → Work
    # id_ed25519 → Personal

    if [[ "$filename" =~ id_[^_]+_(.+) ]]; then
        # Has service name: id_ed25519_github
        name="${match[1]}"
        name="${(C)name}"  # Capitalize first letter
    elif [[ "$filename" =~ (id_ed25519|id_rsa|id_ecdsa) ]]; then
        # Generic key name
        name="Personal"
    else
        # Use filename as-is
        name="${(C)filename}"
    fi

    echo "SSH-$name"
}

discover_aws_config() {
    local -a items=()

    if [[ -f "$HOME/.aws/credentials" ]]; then
        items+=("AWS-Credentials:$HOME/.aws/credentials")
        info "Found: ~/.aws/credentials"
    fi

    if [[ -f "$HOME/.aws/config" ]]; then
        items+=("AWS-Config:$HOME/.aws/config")
        info "Found: ~/.aws/config"
    fi

    echo "${items[@]}"
}

discover_aws_profiles() {
    local -a profiles=()

    if [[ -f "$HOME/.aws/credentials" ]]; then
        # Extract profile names from [profile_name] sections
        while IFS= read -r line; do
            if [[ "$line" =~ ^\[(.+)\]$ ]]; then
                profiles+=(${match[1]})
            fi
        done < "$HOME/.aws/credentials"
    fi

    echo "${profiles[@]}"
}

discover_git_config() {
    if [[ -f "$HOME/.gitconfig" ]]; then
        info "Found: ~/.gitconfig"
        echo "Git-Config:$HOME/.gitconfig"
        return 0
    fi
    return 1
}

discover_other_secrets() {
    local -a items=()

    # SSH config
    if [[ -f "$HOME/.ssh/config" ]]; then
        items+=("SSH-Config:$HOME/.ssh/config")
        info "Found: ~/.ssh/config"
    fi

    # Claude profiles (if exists)
    if [[ -f "$HOME/.claude/profiles.json" ]]; then
        items+=("Claude-Profiles:$HOME/.claude/profiles.json")
        info "Found: ~/.claude/profiles.json"
    fi

    # NPM config
    if [[ -f "$HOME/.npmrc" ]]; then
        items+=("NPM-Config:$HOME/.npmrc")
        info "Found: ~/.npmrc"
    fi

    # PyPI config
    if [[ -f "$HOME/.pypirc" ]]; then
        items+=("PyPI-Config:$HOME/.pypirc")
        info "Found: ~/.pypirc"
    fi

    # Docker config
    if [[ -f "$HOME/.docker/config.json" ]]; then
        items+=("Docker-Config:$HOME/.docker/config.json")
        info "Found: ~/.docker/config.json"
    fi

    # Environment secrets
    if [[ -f "$HOME/.local/env.secrets" ]]; then
        items+=("Environment-Secrets:$HOME/.local/env.secrets")
        info "Found: ~/.local/env.secrets"
    fi

    echo "${items[@]}"
}

# ============================================================
# JSON Generation
# ============================================================

generate_vault_json() {
    local -A ssh_keys=()
    local -a vault_items=()
    local -a syncable_items=()
    local -a aws_profiles=()

    echo ""
    echo -e "${BOLD}${CYAN}Discovering secrets in standard locations...${NC}"
    echo ""

    # Discover SSH keys
    info "Scanning ~/.ssh/ for SSH keys..."
    local ssh_scan_results=()
    if [[ -d "$HOME/.ssh" ]]; then
        for keyfile in "$HOME/.ssh"/*; do
            [[ ! -f "$keyfile" ]] && continue
            [[ "$keyfile" == *.pub ]] && continue
            [[ "$(basename "$keyfile")" == "known_hosts" ]] && continue
            [[ "$(basename "$keyfile")" == "config" ]] && continue
            [[ "$(basename "$keyfile")" == "authorized_keys" ]] && continue

            # Check if it looks like a private key
            if head -n 1 "$keyfile" 2>/dev/null | grep -qE '^-----BEGIN .* PRIVATE KEY-----'; then
                local basename="$(basename "$keyfile")"

                # Generate name from filename
                local name="$basename"
                if [[ "$basename" =~ ^id_[^_]+_(.+)$ ]]; then
                    # id_ed25519_github → GitHub
                    name="SSH-${(C)match[1]}"
                elif [[ "$basename" =~ ^id_(ed25519|rsa|ecdsa|dsa)$ ]]; then
                    # id_ed25519 → Personal
                    name="SSH-Personal"
                else
                    # custom_key → Custom-Key
                    name="SSH-${(C)basename}"
                fi

                ssh_keys[$name]="~/.ssh/$basename"
                ssh_scan_results+=("$name:~/.ssh/$basename")
                pass "  Found: $basename → $name"
            fi
        done
    fi

    # Discover AWS
    info "Checking for AWS configs..."
    local has_aws=false
    if [[ -f "$HOME/.aws/credentials" ]]; then
        pass "  Found: ~/.aws/credentials"
        syncable_items+=("AWS-Credentials:~/.aws/credentials")
        has_aws=true

        # Extract profiles
        while IFS= read -r line; do
            if [[ "$line" =~ ^\[(.+)\]$ ]]; then
                aws_profiles+=(${match[1]})
            fi
        done < "$HOME/.aws/credentials"
    fi

    if [[ -f "$HOME/.aws/config" ]]; then
        pass "  Found: ~/.aws/config"
        syncable_items+=("AWS-Config:~/.aws/config")
        has_aws=true
    fi

    # Discover Git
    info "Checking for Git config..."
    if [[ -f "$HOME/.gitconfig" ]]; then
        pass "  Found: ~/.gitconfig"
        syncable_items+=("Git-Config:~/.gitconfig")
    fi

    # Discover SSH config
    info "Checking for SSH config..."
    if [[ -f "$HOME/.ssh/config" ]]; then
        pass "  Found: ~/.ssh/config"
        syncable_items+=("SSH-Config:~/.ssh/config")
    fi

    # Discover other common secrets
    info "Checking for other secrets..."
    if [[ -f "$HOME/.claude/profiles.json" ]]; then
        pass "  Found: ~/.claude/profiles.json"
        syncable_items+=("Claude-Profiles:~/.claude/profiles.json")
    fi

    if [[ -f "$HOME/.npmrc" ]]; then
        pass "  Found: ~/.npmrc"
        syncable_items+=("NPM-Config:~/.npmrc")
    fi

    if [[ -f "$HOME/.pypirc" ]]; then
        pass "  Found: ~/.pypirc"
        syncable_items+=("PyPI-Config:~/.pypirc")
    fi

    if [[ -f "$HOME/.docker/config.json" ]]; then
        pass "  Found: ~/.docker/config.json"
        syncable_items+=("Docker-Config:~/.docker/config.json")
    fi

    if [[ -f "$HOME/.local/env.secrets" ]]; then
        pass "  Found: ~/.local/env.secrets"
        syncable_items+=("Environment-Secrets:~/.local/env.secrets")
    fi

    echo ""

    # Check if anything was found
    if [[ ${#ssh_scan_results[@]} -eq 0 ]] && [[ ${#syncable_items[@]} -eq 0 ]]; then
        warn "No secrets found in standard locations"
        echo ""
        echo "Checked locations:"
        echo "  • ~/.ssh/ (SSH keys)"
        echo "  • ~/.aws/ (AWS configs)"
        echo "  • ~/.gitconfig (Git config)"
        echo "  • ~/.npmrc, ~/.pypirc, ~/.docker/config.json"
        echo ""
        return 1
    fi

    # Generate JSON
    echo "{"
    echo "  \"\$schema\": \"https://json-schema.org/draft/2020-12/schema\","
    echo "  \"\$comment\": \"Auto-generated by vault/discover-secrets.sh\","
    echo ""

    # SSH keys section
    echo "  \"ssh_keys\": {"
    if [[ ${#ssh_keys[@]} -gt 0 ]]; then
        local first=true
        for name path in ${(kv)ssh_keys}; do
            [[ "$first" == "false" ]] && echo ","
            echo -n "    \"$name\": \"$path\""
            first=false
        done
        echo ""
    fi
    echo "  },"
    echo ""

    # Vault items section (SSH keys + all discovered files)
    echo "  \"vault_items\": {"
    local first=true

    # Add SSH keys to vault_items
    for name path in ${(kv)ssh_keys}; do
        [[ "$first" == "false" ]] && echo ","
        echo "    \"$name\": {"
        echo "      \"path\": \"$path\","
        echo "      \"required\": true,"
        echo "      \"type\": \"sshkey\""
        echo -n "    }"
        first=false
    done

    # Add other items
    for item in $syncable_items; do
        local name="${item%%:*}"
        local path="${item##*:}"
        [[ "$first" == "false" ]] && echo ","
        echo "    \"$name\": {"
        echo "      \"path\": \"$path\","

        # Required by default for SSH/AWS/Git, optional for others
        if [[ "$name" =~ ^(SSH-Config|AWS-|Git-) ]]; then
            echo "      \"required\": true,"
        else
            echo "      \"required\": false,"
        fi

        # Determine type
        if [[ "$name" =~ ^SSH- ]]; then
            echo "      \"type\": \"sshkey\""
        else
            echo "      \"type\": \"file\""
        fi

        echo -n "    }"
        first=false
    done
    echo ""
    echo "  },"
    echo ""

    # Syncable items section
    echo "  \"syncable_items\": {"
    first=true
    for item in $syncable_items; do
        local name="${item%%:*}"
        local path="${item##*:}"
        [[ "$first" == "false" ]] && echo ","
        echo -n "    \"$name\": \"$path\""
        first=false
    done
    echo ""
    echo "  },"
    echo ""

    # AWS profiles
    echo "  \"aws_expected_profiles\": ["
    if [[ ${#aws_profiles[@]} -gt 0 ]]; then
        local first=true
        for profile in $aws_profiles; do
            [[ "$first" == "false" ]] && echo ","
            echo -n "    \"$profile\""
            first=false
        done
        echo ""
    fi
    echo "  ]"
    echo "}"
}

# ============================================================
# Main
# ============================================================

main() {
    local dry_run=false
    local force=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run|-n)
                dry_run=true
                shift
                ;;
            --force|-f)
                force=true
                shift
                ;;
            --ssh-path)
                if [[ -z "${2:-}" ]]; then
                    fail "--ssh-path requires a directory argument"
                    exit 1
                fi
                CUSTOM_SSH_PATHS+=("$2")
                shift 2
                ;;
            --config-path)
                if [[ -z "${2:-}" ]]; then
                    fail "--config-path requires a directory argument"
                    exit 1
                fi
                CUSTOM_CONFIG_PATHS+=("$2")
                shift 2
                ;;
            --help|-h)
                cat << 'EOF'
Vault Auto-Discovery - Automatically detect secrets in standard locations

Usage: ./discover-secrets.sh [OPTIONS]

Options:
  --dry-run, -n           Show what would be discovered without creating file
  --force, -f             Overwrite existing vault-items.json
  --ssh-path PATH         Additional directory to scan for SSH keys
  --config-path PATH      Additional directory to scan for config files
  --help, -h              Show this help

Standard locations scanned:
  • ~/.ssh/           (SSH keys)
  • ~/.aws/           (AWS configs)
  • ~/.gitconfig      (Git config)
  • ~/.npmrc, ~/.pypirc, ~/.docker/config.json (other secrets)

Custom paths:
  Use --ssh-path and --config-path to scan non-standard locations.
  You can specify these options multiple times.

Examples:
  ./discover-secrets.sh
  ./discover-secrets.sh --dry-run
  ./discover-secrets.sh --ssh-path /mnt/keys --ssh-path ~/backup/.ssh
  ./discover-secrets.sh --config-path ~/custom/configs

Output:
  Generates ~/.config/dotfiles/vault-items.json with discovered items.
EOF
                exit 0
                ;;
            *)
                warn "Unknown option: $1"
                shift
                ;;
        esac
    done

    # Check if config already exists
    if [[ -f "$VAULT_CONFIG_FILE" ]] && ! $force && ! $dry_run; then
        warn "Vault config already exists: $VAULT_CONFIG_FILE"
        echo ""
        echo -n "Overwrite with auto-discovered items? [y/N]: "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            info "Discovery cancelled"
            exit 0
        fi
    fi

    # Generate JSON
    local json=$(generate_vault_json)

    if [[ -z "$json" ]]; then
        exit 1
    fi

    if $dry_run; then
        echo ""
        echo -e "${CYAN}Preview of vault-items.json:${NC}"
        echo ""
        echo "$json"
        echo ""
        info "Dry-run mode: no files were created"
    else
        # Create config directory
        mkdir -p "$(dirname "$VAULT_CONFIG_FILE")"

        # Write JSON
        echo "$json" > "$VAULT_CONFIG_FILE"

        echo ""
        pass "Created: $VAULT_CONFIG_FILE"
        echo ""
        echo "Next steps:"
        echo "  1. Review the generated file:"
        echo "     ${CYAN}cat $VAULT_CONFIG_FILE${NC}"
        echo ""
        echo "  2. Edit if needed (customize names, add/remove items):"
        echo "     ${CYAN}\$EDITOR $VAULT_CONFIG_FILE${NC}"
        echo ""
        echo "  3. Sync to vault:"
        echo "     ${CYAN}dotfiles vault sync --all${NC}"
        echo ""
    fi
}

main "$@"
