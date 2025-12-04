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
        for name key_path in ${(kv)ssh_keys}; do
            [[ "$first" == "false" ]] && echo ","
            echo -n "    \"$name\": \"$key_path\""
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
    for name key_path in ${(kv)ssh_keys}; do
        [[ "$first" == "false" ]] && echo ","
        echo "    \"$name\": {"
        echo "      \"path\": \"$key_path\","
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
# Merge Logic
# ============================================================

# Read existing config and parse it
read_existing_config() {
    if [[ ! -f "$VAULT_CONFIG_FILE" ]]; then
        return 1
    fi

    # Parse JSON using zsh/zpty or jq if available
    if command -v jq >/dev/null 2>&1; then
        cat "$VAULT_CONFIG_FILE"
    else
        # Fallback: just read the file
        cat "$VAULT_CONFIG_FILE"
    fi
}

# Merge discovered items with existing config
merge_configs() {
    local discovered_json="$1"
    local existing_json="$2"

    # If no jq, just return discovered (fallback to old behavior)
    if ! command -v jq >/dev/null 2>&1; then
        warn "jq not installed - cannot merge configs, using discovered items only"
        echo "$discovered_json"
        return 0
    fi

    # Merge logic:
    # - Keep all discovered items (they're current)
    # - Add existing items that weren't discovered (manual additions)
    # - Preserve custom properties where possible

    local merged
    merged=$(jq -s '
        # $discovered is .[0], $existing is .[1]
        .[0] as $discovered |
        .[1] as $existing |

        # Start with discovered base
        $discovered |

        # Merge ssh_keys: discovered + existing (discovered wins on conflicts)
        .ssh_keys = ($existing.ssh_keys // {} | . + $discovered.ssh_keys) |

        # Merge vault_items: more complex - preserve manual items
        .vault_items = (
            ($existing.vault_items // {}) as $old |
            ($discovered.vault_items // {}) as $new |
            # Start with old items, process each
            ($old | to_entries | map(
                .key as $item_name |
                .value as $old_item |
                # Check if item was rediscovered
                if ($new | has($item_name)) then
                    # Item exists in both: use discovered path but preserve customizations
                    {
                        key: $item_name,
                        value: ($new[$item_name] |
                            # Preserve "required" flag if it was manually set to false
                            if ($old_item.required == false) then
                                .required = false
                            else . end
                        )
                    }
                else
                    # Item only in existing: keep it (manual addition)
                    {key: $item_name, value: $old_item}
                end
            ) | from_entries) |
            # Add newly discovered items that weren't in old config
            . + ($new | to_entries | map(select(.key as $k | ($old | has($k) | not))) | from_entries)
        ) |

        # Merge syncable_items: discovered + existing
        .syncable_items = (($existing.syncable_items // {}) | . + ($discovered.syncable_items // {})) |

        # Merge aws_expected_profiles: union of both
        .aws_expected_profiles = (
            (($existing.aws_expected_profiles // []) + ($discovered.aws_expected_profiles // [])) | unique
        )
    ' <(echo "$discovered_json") <(echo "$existing_json") 2>/dev/null)

    if [[ -z "$merged" ]]; then
        warn "Merge failed, using discovered items only"
        echo "$discovered_json"
    else
        echo "$merged"
    fi
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
  --force, -f             Overwrite existing config (skip merge, no backup)
  --ssh-path PATH         Additional directory to scan for SSH keys
  --config-path PATH      Additional directory to scan for config files
  --help, -h              Show this help

Standard locations scanned:
  • ~/.ssh/           (SSH keys)
  • ~/.aws/           (AWS configs)
  • ~/.gitconfig      (Git config)
  • ~/.npmrc, ~/.pypirc, ~/.docker/config.json (other secrets)

Merge behavior (when config exists):
  ✓ Preserves manual additions (items not auto-discovered)
  ✓ Preserves manual customizations (e.g., required: false)
  ✓ Updates paths for discovered items
  ✓ Creates automatic backup before merge
  ✗ Use --force to skip merge and overwrite completely

Custom paths:
  Use --ssh-path and --config-path to scan non-standard locations.
  You can specify these options multiple times.

Examples:
  ./discover-secrets.sh                     # Safe merge with existing config
  ./discover-secrets.sh --dry-run           # Preview without changes
  ./discover-secrets.sh --force             # Overwrite without merge
  ./discover-secrets.sh --ssh-path /mnt/keys --ssh-path ~/backup/.ssh

Output:
  Generates ~/.config/dotfiles/vault-items.json with discovered items.
  If config exists, merges intelligently unless --force is used.
EOF
                exit 0
                ;;
            *)
                warn "Unknown option: $1"
                shift
                ;;
        esac
    done

    # Generate discovered JSON
    local discovered_json=$(generate_vault_json)

    if [[ -z "$discovered_json" ]]; then
        exit 1
    fi

    # Check if config already exists and merge
    local final_json="$discovered_json"
    local config_existed=false

    if [[ -f "$VAULT_CONFIG_FILE" ]]; then
        config_existed=true
        info "Existing config found: $VAULT_CONFIG_FILE"

        if $force; then
            warn "Force mode: overwriting without merge"
            final_json="$discovered_json"
        else
            # Attempt to merge
            local existing_json=$(read_existing_config)
            if [[ -n "$existing_json" ]]; then
                info "Merging with existing config (preserves manual additions)..."
                final_json=$(merge_configs "$discovered_json" "$existing_json")

                if [[ "$final_json" == "$discovered_json" ]] && command -v jq >/dev/null 2>&1; then
                    # Merge returned same as discovered (no existing items to preserve)
                    info "No manual items to preserve"
                fi
            fi
        fi
    fi

    if $dry_run; then
        echo ""
        echo -e "${CYAN}Preview of vault-items.json:${NC}"
        echo ""
        echo "$final_json" | jq '.' 2>/dev/null || echo "$final_json"
        echo ""
        if $config_existed; then
            info "Dry-run mode: would merge with existing config"
        else
            info "Dry-run mode: would create new config"
        fi
    else
        # Create config directory
        mkdir -p "$(dirname "$VAULT_CONFIG_FILE")"

        # Backup existing config if it exists
        if $config_existed && ! $force; then
            local backup_file="${VAULT_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$VAULT_CONFIG_FILE" "$backup_file"
            info "Backed up existing config to: $backup_file"
        fi

        # Write JSON (pretty print if jq available)
        if command -v jq >/dev/null 2>&1; then
            echo "$final_json" | jq '.' > "$VAULT_CONFIG_FILE"
        else
            echo "$final_json" > "$VAULT_CONFIG_FILE"
        fi

        echo ""
        if $config_existed; then
            pass "Updated: $VAULT_CONFIG_FILE (merged with existing)"
        else
            pass "Created: $VAULT_CONFIG_FILE"
        fi
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
