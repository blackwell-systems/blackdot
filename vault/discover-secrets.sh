#!/usr/bin/env zsh
# ============================================================
# FILE: vault/discover-secrets.sh
# Auto-discover SSH keys, AWS configs, and other secrets
# Generates vault-items.json from discovered items
# ============================================================
set -euo pipefail

# Source common functions
VAULT_DIR="$(cd "$(dirname "${0:a}")" && pwd)"
BLACKDOT_DIR="$(dirname "$VAULT_DIR")"
source "$BLACKDOT_DIR/lib/_logging.sh"

# Output file
VAULT_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/vault-items.json"

# Custom paths to scan (in addition to standard locations)
typeset -a CUSTOM_SSH_PATHS=()
typeset -a CUSTOM_CONFIG_PATHS=()

# Location settings (from init-vault.sh)
LOCATION_TYPE=""
LOCATION_VALUE=""
MERGE_MODE=false

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

    # Template variables (XDG location - preferred for vault portability)
    local xdg_vars="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/template-variables.sh"
    if [[ -f "$xdg_vars" ]]; then
        items+=("Template-Variables:$xdg_vars")
        info "Found: $xdg_vars"
    else
        # Check templates directory location (legacy/repo location)
        # Try common dotfiles locations (including configured workspace target)
        local ws_target="${WORKSPACE_TARGET:-$HOME/workspace}"
        ws_target="${ws_target/#\~/$HOME}"
        local dotfiles_dirs=("$HOME/dotfiles" "$HOME/.blackdot" "$ws_target/dotfiles")
        for dir in "${dotfiles_dirs[@]}"; do
            if [[ -f "$dir/templates/_variables.local.sh" ]]; then
                items+=("Template-Variables:$dir/templates/_variables.local.sh")
                info "Found: $dir/templates/_variables.local.sh"
                break
            fi
        done
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

    echo "" >&2
    echo -e "${BOLD}${CYAN}Discovering secrets in standard locations...${NC}" >&2
    echo "" >&2

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

    # Discover template variables (XDG location preferred, then dotfiles repo)
    local xdg_vars="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/template-variables.sh"
    if [[ -f "$xdg_vars" ]]; then
        pass "  Found: $xdg_vars"
        syncable_items+=("Template-Variables:~/.config/dotfiles/template-variables.sh")
    else
        # Check common dotfiles locations (including configured workspace target)
        local ws_target="${WORKSPACE_TARGET:-$HOME/workspace}"
        ws_target="${ws_target/#\~/$HOME}"
        for dir in "$HOME/dotfiles" "$HOME/.blackdot" "$ws_target/dotfiles"; do
            if [[ -f "$dir/templates/_variables.local.sh" ]]; then
                pass "  Found: $dir/templates/_variables.local.sh"
                syncable_items+=("Template-Variables:$dir/templates/_variables.local.sh")
                break
            fi
        done
    fi

    echo "" >&2

    # Check if anything was found
    if [[ ${#ssh_scan_results[@]} -eq 0 ]] && [[ ${#syncable_items[@]} -eq 0 ]]; then
        warn "No secrets found in standard locations"
        echo "" >&2
        echo "Checked locations:" >&2
        echo "  • ~/.ssh/ (SSH keys)" >&2
        echo "  • ~/.aws/ (AWS configs)" >&2
        echo "  • ~/.gitconfig (Git config)" >&2
        echo "  • ~/.npmrc, ~/.pypirc, ~/.docker/config.json" >&2
        echo "  • ~/.config/dotfiles/template-variables.sh (template vars)" >&2
        echo "" >&2
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
        local item_name="${item%%:*}"
        local item_path="${item##*:}"
        [[ "$first" == "false" ]] && echo ","
        echo "    \"$item_name\": {"
        echo "      \"path\": \"$item_path\","

        # Required by default for SSH/AWS/Git, optional for others
        if [[ "$item_name" =~ ^(SSH-Config|AWS-|Git-) ]]; then
            echo "      \"required\": true,"
        else
            echo "      \"required\": false,"
        fi

        # Determine type
        if [[ "$item_name" =~ ^SSH- ]]; then
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
        local item_name="${item%%:*}"
        local item_path="${item##*:}"
        [[ "$first" == "false" ]] && echo ","
        echo -n "    \"$item_name\": \"$item_path\""
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
    merged=$(jq -n \
        --argjson discovered "$discovered_json" \
        --argjson existing "$existing_json" '
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
            # Add newly discovered items that were not in old config
            . + ($new | to_entries | map(select(.key as $k | ($old | has($k) | not))) | from_entries)
        ) |

        # Merge syncable_items: discovered + existing
        .syncable_items = (($existing.syncable_items // {}) | . + ($discovered.syncable_items // {})) |

        # Merge aws_expected_profiles: union of both
        .aws_expected_profiles = (
            (($existing.aws_expected_profiles // []) + ($discovered.aws_expected_profiles // [])) | unique
        )
    ' 2>/dev/null)

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
            --location)
                # Format: type:value (e.g., folder:dotfiles)
                if [[ -z "${2:-}" ]]; then
                    fail "--location requires argument in format type:value"
                    exit 1
                fi
                if [[ "$2" == *:* ]]; then
                    LOCATION_TYPE="${2%%:*}"
                    LOCATION_VALUE="${2#*:}"
                else
                    LOCATION_TYPE="$2"
                    LOCATION_VALUE=""
                fi
                shift 2
                ;;
            --merge)
                MERGE_MODE=true
                shift
                ;;
            --help|-h)
                cat << 'EOF'
Vault Auto-Discovery - Automatically detect secrets in standard locations

Usage: ./discover-secrets.sh [OPTIONS]

Options:
  --dry-run, -n           Show what would be discovered without creating file
  --force, -f             Overwrite existing config (skip merge, no backup)
  --merge                 Merge with existing config (no prompt)
  --location TYPE:VALUE   Set vault location (e.g., folder:dotfiles)
  --ssh-path PATH         Additional directory to scan for SSH keys
  --config-path PATH      Additional directory to scan for config files
  --help, -h              Show this help

Standard locations scanned:
  • ~/.ssh/           (SSH keys)
  • ~/.aws/           (AWS configs)
  • ~/.gitconfig      (Git config)
  • ~/.npmrc, ~/.pypirc, ~/.docker/config.json (other secrets)
  • ~/.config/dotfiles/template-variables.sh (template variables)
  • ~/dotfiles/templates/_variables.local.sh (alternate location)

Merge behavior (when config exists):
  Interactive prompt offers three choices:
    [m] Merge - Preserves manual additions & customizations (recommended, default)
    [r] Replace - Use only discovered items (discards manual changes)
    [c] Cancel - Exit without making changes

  Use --force to skip prompt and replace directly
  Use --dry-run to preview without prompt

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
        warn "Existing config found: $VAULT_CONFIG_FILE"
        echo ""

        if $force; then
            warn "Force mode: overwriting without merge"
            final_json="$discovered_json"
        elif $MERGE_MODE; then
            # --merge flag: merge without prompt
            info "Merge mode: combining with existing config"
            local existing_json=$(read_existing_config)
            if [[ -n "$existing_json" ]]; then
                final_json=$(merge_configs "$discovered_json" "$existing_json")
            fi
        elif $dry_run; then
            # In dry-run, default to merge for preview
            local existing_json=$(read_existing_config)
            if [[ -n "$existing_json" ]]; then
                final_json=$(merge_configs "$discovered_json" "$existing_json")
            fi
        else
            # Prompt user for action (loop to allow preview)
            local user_choice=""
            while [[ -z "$user_choice" ]]; do
                echo "Choose action:"
                echo "  ${GREEN}[m]${NC} Merge - Keep items in config that weren't discovered (recommended for existing machines)"
                echo "  ${YELLOW}[r]${NC} Replace - Use only discovered items (recommended for fresh machines)"
                echo "  ${BLUE}[p]${NC} Preview - Show what merge would look like (no changes)"
                echo "  ${DIM}[c]${NC} Cancel - Exit without changes"
                echo ""
                echo "${DIM}Tip: Merge preserves items in config that weren't found locally (e.g., moved files, custom paths).${NC}"
                echo ""
                echo -n "Choice [m/r/p/c]: "
                read -r choice

                case "${choice:-m}" in
                    p|P|preview)
                        # Show merge preview without applying
                        local existing_json=$(read_existing_config)
                        if [[ -n "$existing_json" ]]; then
                            local preview_json=$(merge_configs "$discovered_json" "$existing_json")

                            echo ""
                            echo -e "${CYAN}=== Merge Preview ===${NC}"

                            if command -v jq >/dev/null 2>&1; then
                                local old_items=$(echo "$existing_json" | jq '.vault_items | length')
                                local new_items=$(echo "$preview_json" | jq '.vault_items | length')
                                local discovered_count=$(echo "$discovered_json" | jq '.vault_items | length')

                                echo ""
                                echo "📊 Summary:"
                                echo "  • Existing items: $old_items"
                                echo "  • Discovered items: $discovered_count"
                                echo "  • Merged total: $new_items"
                                echo ""

                                # Show existing items detail
                                echo "📋 Existing Items:"
                                if [[ "$old_items" -gt 0 ]]; then
                                    echo "$existing_json" | jq -r '.vault_items | to_entries | .[] | "  • \(.key)\n    Path: \(.value.path)\n    Type: \(.value.type // "file")\n    Required: \(.value.required // true)"'
                                else
                                    echo "  (none)"
                                fi
                                echo ""

                                # Show discovered items detail
                                echo "🔍 Discovered Items:"
                                if [[ "$discovered_count" -gt 0 ]]; then
                                    echo "$discovered_json" | jq -r '.vault_items | to_entries | .[] | "  • \(.key)\n    Path: \(.value.path)\n    Type: \(.value.type // "file")\n    Required: \(.value.required // true)"'
                                else
                                    echo "  (none)"
                                fi
                                echo ""

                                echo "🔀 Merge Impact:"
                                echo ""

                                local preserved=$(jq -n \
                                    --argjson old "$existing_json" \
                                    --argjson new "$discovered_json" '
                                    $old.vault_items // {} | keys as $old_keys |
                                    $new.vault_items // {} | keys as $new_keys |
                                    $old_keys - $new_keys
                                ')
                                local preserved_count=$(echo "$preserved" | jq 'length')

                                if [[ "$preserved_count" -gt 0 ]]; then
                                    echo "✅ Preserved items in config but not discovered ($preserved_count):"
                                    echo "${DIM}   (These may be custom paths, moved files, or items from other machines)${NC}"
                                    echo "$preserved" | jq -r '.[] | "  • " + .'
                                    echo ""
                                fi

                                local added=$(jq -n \
                                    --argjson old "$existing_json" \
                                    --argjson new "$discovered_json" '
                                    $old.vault_items // {} | keys as $old_keys |
                                    $new.vault_items // {} | keys as $new_keys |
                                    $new_keys - $old_keys
                                ')
                                local added_count=$(echo "$added" | jq 'length')

                                if [[ "$added_count" -gt 0 ]]; then
                                    echo "➕ New discovered items ($added_count):"
                                    echo "$added" | jq -r '.[] | "  • " + .'
                                    echo ""
                                fi
                            else
                                echo "Preview requires jq. Install with: brew install jq"
                            fi

                            echo -e "${CYAN}=====================${NC}"
                            echo ""
                        fi
                        # Loop back to menu
                        ;;
                    m|M|merge|"")
                        user_choice="merge"
                        ;;
                    r|R|replace)
                        user_choice="replace"
                        ;;
                    c|C|cancel)
                        info "Discovery cancelled"
                        exit 0
                        ;;
                    *)
                        fail "Invalid choice: $choice"
                        echo ""
                        ;;
                esac
            done

            # Now apply the user's choice
            case "$user_choice" in
                merge)
                    # Apply merge
                    local existing_json=$(read_existing_config)
                    if [[ -n "$existing_json" ]]; then
                        info "Applying merge..."
                        final_json=$(merge_configs "$discovered_json" "$existing_json")
                    fi
                    ;;
                replace)
                    warn "Replacing config with discovered items only"
                    final_json="$discovered_json"
                    ;;
            esac
        fi
    fi

    # Add vault_location if specified via --location
    if [[ -n "$LOCATION_TYPE" ]] && command -v jq >/dev/null 2>&1; then
        final_json=$(echo "$final_json" | jq \
            --arg type "$LOCATION_TYPE" \
            --arg value "$LOCATION_VALUE" \
            '.vault_location = {type: $type, value: $value}')
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
        echo "     ${CYAN}dotfiles vault push --all${NC}"
        echo ""
    fi
}

main "$@"
