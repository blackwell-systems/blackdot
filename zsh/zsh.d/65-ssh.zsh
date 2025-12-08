# =========================
# 65-ssh.zsh
# =========================
# SSH configuration, key management, agent handling, and tunnel utilities
# Provides shortcuts and helpers for SSH workflows
#
# NOTE: Uses runtime feature guards - functions check feature_enabled when called,
# not at load time. This allows features to be enabled/disabled without shell reload.

# =========================
# SSH Config Management
# =========================

# List all configured hosts from ~/.ssh/config
sshlist() {
    require_feature "ssh_tools" || return 1
    if [[ ! -f ~/.ssh/config ]]; then
        echo "No SSH config found at ~/.ssh/config"
        return 1
    fi

    echo "SSH Hosts:"
    echo "──────────────────────────────────────"
    grep -E "^Host\s+" ~/.ssh/config | grep -v "\*" | awk '{print "  " $2}' | sort
    echo ""
    echo "Total: $(grep -cE "^Host\s+" ~/.ssh/config | grep -v "\*" 2>/dev/null || echo 0) hosts"
}

# Quick connect with optional command
sshgo() {
    require_feature "ssh_tools" || return 1
    local host="${1:-}"
    shift 2>/dev/null || true

    if [[ -z "$host" ]]; then
        echo "Usage: sshgo <host> [command...]"
        echo ""
        sshlist
        return 1
    fi

    if [[ $# -gt 0 ]]; then
        ssh "$host" "$@"
    else
        ssh "$host"
    fi
}

# Open SSH config in editor
sshedit() {
    require_feature "ssh_tools" || return 1
    ${EDITOR:-vim} ~/.ssh/config
}

# Add new host to SSH config interactively
sshadd-host() {
    require_feature "ssh_tools" || return 1
    local name="${1:-}"

    if [[ -z "$name" ]]; then
        echo "Usage: sshadd-host <name>"
        return 1
    fi

    echo "Adding SSH host: $name"
    echo "──────────────────────────────────────"

    local hostname user port identity

    echo -n "Hostname (IP or domain): "
    read hostname

    echo -n "User [$(whoami)]: "
    read user
    user="${user:-$(whoami)}"

    echo -n "Port [22]: "
    read port
    port="${port:-22}"

    echo -n "Identity file (leave blank for default): "
    read identity

    # Append to config
    echo "" >> ~/.ssh/config
    echo "Host $name" >> ~/.ssh/config
    echo "    HostName $hostname" >> ~/.ssh/config
    echo "    User $user" >> ~/.ssh/config
    [[ "$port" != "22" ]] && echo "    Port $port" >> ~/.ssh/config
    [[ -n "$identity" ]] && echo "    IdentityFile $identity" >> ~/.ssh/config

    echo ""
    echo "Added host '$name' to ~/.ssh/config"
    echo "Connect with: ssh $name"
}

# =========================
# SSH Key Management
# =========================

# List all SSH keys with fingerprints
sshkeys() {
    require_feature "ssh_tools" || return 1
    local key_dir="${1:-$HOME/.ssh}"

    echo "SSH Keys in $key_dir:"
    echo "──────────────────────────────────────"

    local found=0
    for pub in "$key_dir"/*.pub; do
        [[ -f "$pub" ]] || continue
        found=1
        local name=$(basename "$pub" .pub)
        local fp=$(ssh-keygen -lf "$pub" 2>/dev/null)
        if [[ -n "$fp" ]]; then
            local bits=$(echo "$fp" | awk '{print $1}')
            local hash=$(echo "$fp" | awk '{print $2}')
            local type=$(echo "$fp" | awk '{print $NF}' | tr -d '()')
            printf "  %-20s %s %s (%s)\n" "$name" "$bits" "$type" "$hash"
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo "  No SSH keys found"
    fi
    echo ""
}

# Generate new ED25519 key
sshgen() {
    require_feature "ssh_tools" || return 1
    local name="${1:-}"
    local comment="${2:-}"

    if [[ -z "$name" ]]; then
        echo "Usage: sshgen <name> [comment]"
        echo ""
        echo "Examples:"
        echo "  sshgen github \"GitHub Personal\""
        echo "  sshgen work-server"
        return 1
    fi

    local key_path="$HOME/.ssh/id_ed25519_$name"
    comment="${comment:-$name key}"

    if [[ -f "$key_path" ]]; then
        echo "Key already exists: $key_path"
        echo "Delete it first if you want to regenerate"
        return 1
    fi

    echo "Generating ED25519 key: $key_path"
    ssh-keygen -t ed25519 -f "$key_path" -C "$comment"

    # Set proper permissions
    chmod 600 "$key_path"
    chmod 644 "${key_path}.pub"

    echo ""
    echo "Key generated successfully!"
    echo "Public key:"
    cat "${key_path}.pub"
}

# Copy public key to remote host
sshcopy() {
    require_feature "ssh_tools" || return 1
    local host="${1:-}"
    local key="${2:-}"

    if [[ -z "$host" ]]; then
        echo "Usage: sshcopy <host> [key]"
        echo ""
        echo "Copies public key to remote host's authorized_keys"
        return 1
    fi

    if [[ -n "$key" ]]; then
        ssh-copy-id -i "$key" "$host"
    else
        ssh-copy-id "$host"
    fi
}

# Show fingerprint(s) in multiple formats
sshfp() {
    require_feature "ssh_tools" || return 1
    local key="${1:-}"

    if [[ -z "$key" ]]; then
        # Show all keys
        echo "SSH Key Fingerprints:"
        echo "──────────────────────────────────────"
        for pub in ~/.ssh/*.pub; do
            [[ -f "$pub" ]] || continue
            local name=$(basename "$pub")
            echo ""
            echo "$name:"
            echo "  SHA256: $(ssh-keygen -lf "$pub" 2>/dev/null | awk '{print $2}')"
            echo "  MD5:    $(ssh-keygen -E md5 -lf "$pub" 2>/dev/null | awk '{print $2}')"
        done
    else
        # Show specific key
        local pub_key="$key"
        [[ "$key" != *.pub ]] && pub_key="${key}.pub"
        [[ ! -f "$pub_key" && -f "$HOME/.ssh/${pub_key}" ]] && pub_key="$HOME/.ssh/${pub_key}"
        [[ ! -f "$pub_key" && -f "$HOME/.ssh/id_ed25519_${key}.pub" ]] && pub_key="$HOME/.ssh/id_ed25519_${key}.pub"

        if [[ ! -f "$pub_key" ]]; then
            echo "Key not found: $key"
            return 1
        fi

        echo "Fingerprints for $(basename "$pub_key"):"
        echo "  SHA256: $(ssh-keygen -lf "$pub_key" 2>/dev/null | awk '{print $2}')"
        echo "  MD5:    $(ssh-keygen -E md5 -lf "$pub_key" 2>/dev/null | awk '{print $2}')"
    fi
}

# =========================
# SSH Agent Commands
# =========================

# Start agent if not running, show loaded keys
sshagent() {
    require_feature "ssh_tools" || return 1
    # Check if agent is running
    if [[ -z "$SSH_AUTH_SOCK" ]] || ! ssh-add -l &>/dev/null; then
        echo "Starting SSH agent..."
        eval "$(ssh-agent -s)"
    fi

    echo "SSH Agent Status:"
    echo "──────────────────────────────────────"
    echo "  PID: ${SSH_AGENT_PID:-unknown}"
    echo "  Socket: ${SSH_AUTH_SOCK:-not set}"
    echo ""
    echo "Loaded keys:"
    local keys
    keys=$(ssh-add -l 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        echo "$keys" | while read line; do
            echo "  $line"
        done
    else
        echo "  (no keys loaded)"
    fi
}

# Add key to agent
sshload() {
    require_feature "ssh_tools" || return 1
    local key="${1:-}"

    if [[ -z "$key" ]]; then
        # Load all default keys
        echo "Loading default SSH keys..."
        ssh-add
    else
        # Load specific key
        local key_path="$key"
        [[ ! -f "$key_path" && -f "$HOME/.ssh/$key" ]] && key_path="$HOME/.ssh/$key"
        [[ ! -f "$key_path" && -f "$HOME/.ssh/id_ed25519_$key" ]] && key_path="$HOME/.ssh/id_ed25519_$key"
        [[ ! -f "$key_path" && -f "$HOME/.ssh/id_rsa_$key" ]] && key_path="$HOME/.ssh/id_rsa_$key"

        if [[ ! -f "$key_path" ]]; then
            echo "Key not found: $key"
            echo ""
            echo "Available keys:"
            ls ~/.ssh/id_* 2>/dev/null | grep -v ".pub$" | xargs -I{} basename {}
            return 1
        fi

        ssh-add "$key_path"
    fi

    echo ""
    echo "Currently loaded keys:"
    ssh-add -l
}

# Remove key from agent
sshunload() {
    require_feature "ssh_tools" || return 1
    local key="${1:-}"

    if [[ -z "$key" ]]; then
        echo "Usage: sshunload <key>"
        echo ""
        echo "Currently loaded:"
        ssh-add -l
        return 1
    fi

    local key_path="$key"
    [[ ! -f "$key_path" && -f "$HOME/.ssh/$key" ]] && key_path="$HOME/.ssh/$key"
    [[ ! -f "$key_path" && -f "$HOME/.ssh/id_ed25519_$key" ]] && key_path="$HOME/.ssh/id_ed25519_$key"

    ssh-add -d "$key_path" 2>/dev/null || ssh-add -d "${key_path}.pub" 2>/dev/null
    echo "Removed key from agent"
}

# Remove all keys from agent
sshclear() {
    require_feature "ssh_tools" || return 1
    echo "Removing all keys from SSH agent..."
    ssh-add -D
    echo "Done. No keys loaded."
}

# =========================
# SSH Tunnel Helpers
# =========================

# Create port forward tunnel
sshtunnel() {
    require_feature "ssh_tools" || return 1
    local host="${1:-}"
    local local_port="${2:-}"
    local remote_port="${3:-}"

    if [[ -z "$host" || -z "$local_port" ]]; then
        echo "Usage: sshtunnel <host> <local_port> [remote_port]"
        echo ""
        echo "Creates SSH tunnel: localhost:local_port -> host:remote_port"
        echo "If remote_port is omitted, uses same as local_port"
        echo ""
        echo "Examples:"
        echo "  sshtunnel myserver 8080 80      # localhost:8080 -> myserver:80"
        echo "  sshtunnel db-server 5432        # localhost:5432 -> db-server:5432"
        return 1
    fi

    remote_port="${remote_port:-$local_port}"

    echo "Creating tunnel: localhost:$local_port -> $host:$remote_port"
    echo "Press Ctrl+C to close tunnel"
    ssh -N -L "${local_port}:localhost:${remote_port}" "$host"
}

# SOCKS5 proxy through host
sshsocks() {
    require_feature "ssh_tools" || return 1
    local host="${1:-}"
    local port="${2:-1080}"

    if [[ -z "$host" ]]; then
        echo "Usage: sshsocks <host> [port]"
        echo ""
        echo "Creates SOCKS5 proxy through SSH host"
        echo "Default port: 1080"
        echo ""
        echo "Configure browser/apps to use: socks5://localhost:$port"
        return 1
    fi

    echo "Creating SOCKS5 proxy on localhost:$port through $host"
    echo "Press Ctrl+C to close proxy"
    ssh -N -D "$port" "$host"
}

# List active SSH connections/tunnels
sshtunnels() {
    require_feature "ssh_tools" || return 1
    echo "Active SSH Connections:"
    echo "──────────────────────────────────────"

    local found=0
    ps aux | grep "[s]sh " | grep -v "grep" | while read line; do
        found=1
        local pid=$(echo "$line" | awk '{print $2}')
        local cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf $i" "; print ""}')
        echo "  PID $pid: $cmd"
    done

    if [[ $found -eq 0 ]]; then
        echo "  No active SSH connections"
    fi
}

# =========================
# SSH Tools Help
# =========================

sshtools() {
    require_feature "ssh_tools" || return 1
    # Source theme colors
    source "${DOTFILES_DIR:-$HOME/workspace/dotfiles}/lib/_colors.sh"

    # Check SSH agent status
    local logo_color agent_running keys_loaded
    if [[ -n "$SSH_AUTH_SOCK" ]] && ssh-add -l &>/dev/null; then
        agent_running=true
        keys_loaded=$(ssh-add -l 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$keys_loaded" -gt 0 ]]; then
            logo_color="$CLR_SUCCESS"
        else
            logo_color="$CLR_WARNING"
        fi
    else
        agent_running=false
        keys_loaded=0
        logo_color="$CLR_ERROR"
    fi

    echo ""
    echo -e "${logo_color}  ███████╗███████╗██╗  ██╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗${CLR_NC}"
    echo -e "${logo_color}  ██╔════╝██╔════╝██║  ██║    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝${CLR_NC}"
    echo -e "${logo_color}  ███████╗███████╗███████║       ██║   ██║   ██║██║   ██║██║     ███████╗${CLR_NC}"
    echo -e "${logo_color}  ╚════██║╚════██║██╔══██║       ██║   ██║   ██║██║   ██║██║     ╚════██║${CLR_NC}"
    echo -e "${logo_color}  ███████║███████║██║  ██║       ██║   ╚██████╔╝╚██████╔╝███████╗███████║${CLR_NC}"
    echo -e "${logo_color}  ╚══════╝╚══════╝╚═╝  ╚═╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝${CLR_NC}"
    echo ""

    # Config Management section
    echo -e "  ${CLR_BOX}╭─────────────────────────────────────────────────────────────────╮${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}SSH CONFIG MANAGEMENT${CLR_NC}                                      ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_PRIMARY}sshlist${CLR_NC}            ${CLR_MUTED}List all configured hosts${CLR_NC}                 ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_PRIMARY}sshgo${CLR_NC} <host>       ${CLR_MUTED}Quick connect to host${CLR_NC}                     ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_PRIMARY}sshedit${CLR_NC}            ${CLR_MUTED}Open SSH config in editor${CLR_NC}                 ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_PRIMARY}sshadd-host${CLR_NC} <name> ${CLR_MUTED}Add new host interactively${CLR_NC}                ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}SSH KEY MANAGEMENT${CLR_NC}                                         ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_PRIMARY}sshkeys${CLR_NC}            ${CLR_MUTED}List all keys with fingerprints${CLR_NC}           ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_PRIMARY}sshgen${CLR_NC} <name>      ${CLR_MUTED}Generate new ED25519 key${CLR_NC}                  ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_PRIMARY}sshcopy${CLR_NC} <host>     ${CLR_MUTED}Copy public key to remote host${CLR_NC}            ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_PRIMARY}sshfp${CLR_NC} [key]        ${CLR_MUTED}Show fingerprint(s) (SHA256/MD5)${CLR_NC}          ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}SSH AGENT COMMANDS${CLR_NC}                                         ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_PRIMARY}sshagent${CLR_NC}           ${CLR_MUTED}Start agent / show loaded keys${CLR_NC}            ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_PRIMARY}sshload${CLR_NC} [key]      ${CLR_MUTED}Add key to agent${CLR_NC}                          ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_PRIMARY}sshunload${CLR_NC} <key>    ${CLR_MUTED}Remove key from agent${CLR_NC}                     ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_PRIMARY}sshclear${CLR_NC}           ${CLR_MUTED}Remove all keys from agent${CLR_NC}                ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}SSH TUNNEL HELPERS${CLR_NC}                                         ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_PRIMARY}sshtunnel${CLR_NC} <h> <l> <r> ${CLR_MUTED}Create port forward tunnel${CLR_NC}             ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_PRIMARY}sshsocks${CLR_NC} <host> [p]   ${CLR_MUTED}SOCKS5 proxy (default: 1080)${CLR_NC}           ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_PRIMARY}sshtunnels${CLR_NC}            ${CLR_MUTED}List active SSH connections${CLR_NC}            ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}╰─────────────────────────────────────────────────────────────────╯${CLR_NC}"
    echo ""

    # Current Status
    echo -e "  ${CLR_BOLD}Current Status${CLR_NC}"
    echo -e "  ${CLR_MUTED}───────────────────────────────────────${CLR_NC}"

    if [[ "$agent_running" == "true" ]]; then
        echo -e "    ${CLR_MUTED}Agent${CLR_NC}     ${CLR_SUCCESS}● running${CLR_NC} ${CLR_MUTED}(PID: ${SSH_AGENT_PID:-?})${CLR_NC}"
        if [[ "$keys_loaded" -gt 0 ]]; then
            echo -e "    ${CLR_MUTED}Keys${CLR_NC}      ${CLR_SUCCESS}$keys_loaded loaded${CLR_NC}"
        else
            echo -e "    ${CLR_MUTED}Keys${CLR_NC}      ${CLR_WARNING}0 loaded${CLR_NC} ${CLR_MUTED}(run 'sshload' to add keys)${CLR_NC}"
        fi
    else
        echo -e "    ${CLR_MUTED}Agent${CLR_NC}     ${CLR_ERROR}○ not running${CLR_NC} ${CLR_MUTED}(run 'sshagent' to start)${CLR_NC}"
    fi

    # Count configured hosts
    local host_count=0
    if [[ -f ~/.ssh/config ]]; then
        host_count=$(grep -cE "^Host\s+" ~/.ssh/config 2>/dev/null || echo 0)
    fi
    echo -e "    ${CLR_MUTED}Hosts${CLR_NC}     ${CLR_PRIMARY}$host_count configured${CLR_NC}"

    # Count available keys
    local key_count=$(ls ~/.ssh/*.pub 2>/dev/null | wc -l | tr -d ' ')
    echo -e "    ${CLR_MUTED}Keys${CLR_NC}      ${CLR_PRIMARY}$key_count available${CLR_NC}"

    echo ""
}

# =========================
# Zsh Completions
# =========================

# Completion for sshgo - complete from SSH config hosts
_sshgo() {
    local hosts
    if [[ -f ~/.ssh/config ]]; then
        hosts=(${(f)"$(grep -E "^Host\s+" ~/.ssh/config | grep -v "\*" | awk '{print $2}')"})
        _describe 'SSH hosts' hosts
    fi
}
compdef _sshgo sshgo sshcopy sshtunnel sshsocks

# Completion for sshload - complete from available keys
_sshload() {
    local keys
    keys=(${(f)"$(ls ~/.ssh/id_* 2>/dev/null | grep -v ".pub$" | xargs -I{} basename {})"})
    _describe 'SSH keys' keys
}
compdef _sshload sshload sshunload

# Completion for sshfp
_sshfp() {
    local keys
    keys=(${(f)"$(ls ~/.ssh/*.pub 2>/dev/null | xargs -I{} basename {} .pub)"})
    _describe 'SSH keys' keys
}
compdef _sshfp sshfp
