# =========================
# 66-docker.zsh
# =========================
# Docker container management, compose workflows, and network utilities
# Provides shortcuts and helpers for Docker workflows
# Runtime guards allow enable/disable without shell reload

# =========================
# Container Aliases (as functions for runtime guards)
# =========================

dps()      { require_feature "docker_tools" || return 1; docker ps "$@"; }
dpsa()     { require_feature "docker_tools" || return 1; docker ps -a "$@"; }
di()       { require_feature "docker_tools" || return 1; docker images "$@"; }
dl()       { require_feature "docker_tools" || return 1; docker logs "$@"; }
dlf()      { require_feature "docker_tools" || return 1; docker logs -f "$@"; }
dstop()    { require_feature "docker_tools" || return 1; docker stop "$@"; }
dstart()   { require_feature "docker_tools" || return 1; docker start "$@"; }
drestart() { require_feature "docker_tools" || return 1; docker restart "$@"; }
drm()      { require_feature "docker_tools" || return 1; docker rm "$@"; }
drmi()     { require_feature "docker_tools" || return 1; docker rmi "$@"; }
dpull()    { require_feature "docker_tools" || return 1; docker pull "$@"; }
dpush()    { require_feature "docker_tools" || return 1; docker push "$@"; }
dbuild()   { require_feature "docker_tools" || return 1; docker build "$@"; }
dtag()     { require_feature "docker_tools" || return 1; docker tag "$@"; }

# =========================
# Docker Compose Aliases (as functions)
# =========================

dc()    { require_feature "docker_tools" || return 1; docker compose "$@"; }
dcu()   { require_feature "docker_tools" || return 1; docker compose up "$@"; }
dcud()  { require_feature "docker_tools" || return 1; docker compose up -d "$@"; }
dcd()   { require_feature "docker_tools" || return 1; docker compose down "$@"; }
dcr()   { require_feature "docker_tools" || return 1; docker compose restart "$@"; }
dcl()   { require_feature "docker_tools" || return 1; docker compose logs -f "$@"; }
dcps()  { require_feature "docker_tools" || return 1; docker compose ps "$@"; }
dcb()   { require_feature "docker_tools" || return 1; docker compose build "$@"; }
dcex()  { require_feature "docker_tools" || return 1; docker compose exec "$@"; }
dcp()   { require_feature "docker_tools" || return 1; docker compose pull "$@"; }
dcrun() { require_feature "docker_tools" || return 1; docker compose run --rm "$@"; }

# =========================
# Container Helper Functions
# =========================

# Execute shell in container (tries bash, falls back to sh)
dsh() {
    require_feature "docker_tools" || return 1
    local container="${1:-}"

    if [[ -z "$container" ]]; then
        echo "Usage: dsh <container>"
        echo ""
        echo "Running containers:"
        docker ps --format "  {{.Names}}"
        return 1
    fi

    # Try bash first, fall back to sh
    docker exec -it "$container" bash 2>/dev/null || docker exec -it "$container" sh
}

# Execute command in container
dex() {
    require_feature "docker_tools" || return 1
    local container="${1:-}"
    shift 2>/dev/null || true

    if [[ -z "$container" ]]; then
        echo "Usage: dex <container> [command...]"
        echo ""
        echo "Running containers:"
        docker ps --format "  {{.Names}}"
        return 1
    fi

    if [[ $# -eq 0 ]]; then
        docker exec -it "$container" sh
    else
        docker exec -it "$container" "$@"
    fi
}

# Get container IP address
dip() {
    require_feature "docker_tools" || return 1
    local container="${1:-}"

    if [[ -z "$container" ]]; then
        echo "Usage: dip <container>"
        return 1
    fi

    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container"
}

# Show container environment variables
denv() {
    require_feature "docker_tools" || return 1
    local container="${1:-}"

    if [[ -z "$container" ]]; then
        echo "Usage: denv <container>"
        return 1
    fi

    docker exec "$container" env 2>/dev/null || \
        docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$container"
}

# Show all containers with exposed ports
dports() {
    require_feature "docker_tools" || return 1
    echo "Container Ports:"
    echo "──────────────────────────────────────"
    docker ps --format "table {{.Names}}\t{{.Ports}}" | tail -n +2 | while read line; do
        echo "  $line"
    done
}

# Pretty docker stats
dstats() {
    require_feature "docker_tools" || return 1
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

# Live docker stats
dstatsf() {
    require_feature "docker_tools" || return 1
    docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

# List volumes with details
dvols() {
    require_feature "docker_tools" || return 1
    echo "Docker Volumes:"
    echo "──────────────────────────────────────"
    docker volume ls --format "table {{.Name}}\t{{.Driver}}" | tail -n +2 | while read line; do
        echo "  $line"
    done
    echo ""
    echo "Total: $(docker volume ls -q | wc -l | tr -d ' ') volumes"
}

# Inspect with optional jq filtering
dinspect() {
    require_feature "docker_tools" || return 1
    local container="${1:-}"
    local jq_path="${2:-}"

    if [[ -z "$container" ]]; then
        echo "Usage: dinspect <container> [jq-path]"
        echo ""
        echo "Examples:"
        echo "  dinspect myapp                  # Full inspect"
        echo "  dinspect myapp .NetworkSettings # Just network settings"
        echo "  dinspect myapp .Config.Env      # Just environment"
        return 1
    fi

    if [[ -n "$jq_path" ]]; then
        docker inspect "$container" | jq ".[0]$jq_path"
    else
        docker inspect "$container" | jq '.[0]'
    fi
}

# =========================
# Network Commands
# =========================

# List networks with details
dnets() {
    require_feature "docker_tools" || return 1
    echo "Docker Networks:"
    echo "──────────────────────────────────────"
    docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
}

# Show containers on a network
dnetinspect() {
    require_feature "docker_tools" || return 1
    local network="${1:-bridge}"
    echo "Containers on network '$network':"
    echo "──────────────────────────────────────"
    docker network inspect "$network" -f '{{range .Containers}}{{.Name}} ({{.IPv4Address}}){{println}}{{end}}'
}

# =========================
# Cleanup Commands
# =========================

# Remove stopped containers and dangling images
dclean() {
    require_feature "docker_tools" || return 1
    echo "Cleaning up Docker..."
    echo ""

    # Remove stopped containers
    local stopped=$(docker ps -aq -f status=exited | wc -l | tr -d ' ')
    if [[ "$stopped" -gt 0 ]]; then
        echo "Removing $stopped stopped containers..."
        docker container prune -f
    else
        echo "No stopped containers to remove"
    fi

    # Remove dangling images
    local dangling=$(docker images -f "dangling=true" -q | wc -l | tr -d ' ')
    if [[ "$dangling" -gt 0 ]]; then
        echo "Removing $dangling dangling images..."
        docker image prune -f
    else
        echo "No dangling images to remove"
    fi

    echo ""
    echo "Done!"
}

# Interactive system prune
dprune() {
    require_feature "docker_tools" || return 1
    echo "This will remove:"
    echo "  - All stopped containers"
    echo "  - All networks not used by containers"
    echo "  - All dangling images"
    echo "  - All dangling build cache"
    echo ""
    docker system prune
}

# Aggressive cleanup (with confirmation)
dprune-all() {
    require_feature "docker_tools" || return 1
    echo "WARNING: This will remove:"
    echo "  - All stopped containers"
    echo "  - All networks not used by containers"
    echo "  - ALL unused images (not just dangling)"
    echo "  - All build cache"
    echo ""
    echo -n "Are you sure? [y/N] "
    read confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        docker system prune -a --volumes
    else
        echo "Cancelled"
    fi
}

# =========================
# Build Helpers
# =========================

# Build with tag from current directory name
dbuild-here() {
    require_feature "docker_tools" || return 1
    local tag="${1:-$(basename $(pwd))}"
    echo "Building image: $tag"
    docker build -t "$tag" .
}

# Build with no cache
dbuild-fresh() {
    require_feature "docker_tools" || return 1
    local tag="${1:-$(basename $(pwd))}"
    echo "Building image (no cache): $tag"
    docker build --no-cache -t "$tag" .
}

# =========================
# Docker Tools Help
# =========================

dockertools() {
    require_feature "docker_tools" || return 1
    # Source theme colors
    source "${DOTFILES_DIR:-$HOME/workspace/dotfiles}/lib/_colors.sh"

    # Check Docker status
    local logo_color daemon_running containers_running
    if docker info &>/dev/null; then
        daemon_running=true
        containers_running=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$containers_running" -gt 0 ]]; then
            logo_color="$CLR_SUCCESS"
        else
            logo_color="$CLR_DOCKER"
        fi
    else
        daemon_running=false
        containers_running=0
        logo_color="$CLR_ERROR"
    fi

    echo ""
    echo -e "${logo_color}  ██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗     ████████╗ ██████╗  ██████╗ ██╗     ███████╗${CLR_NC}"
    echo -e "${logo_color}  ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝${CLR_NC}"
    echo -e "${logo_color}  ██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝       ██║   ██║   ██║██║   ██║██║     ███████╗${CLR_NC}"
    echo -e "${logo_color}  ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗       ██║   ██║   ██║██║   ██║██║     ╚════██║${CLR_NC}"
    echo -e "${logo_color}  ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║       ██║   ╚██████╔╝╚██████╔╝███████╗███████║${CLR_NC}"
    echo -e "${logo_color}  ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝${CLR_NC}"
    echo ""

    # Container commands section
    echo -e "  ${CLR_BOX}╭─────────────────────────────────────────────────────────────────╮${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}CONTAINER COMMANDS${CLR_NC}                                         ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dps${CLR_NC}                ${CLR_MUTED}docker ps${CLR_NC}                                 ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dpsa${CLR_NC}               ${CLR_MUTED}docker ps -a${CLR_NC}                              ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}di${CLR_NC}                 ${CLR_MUTED}docker images${CLR_NC}                             ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dsh${CLR_NC} <container>    ${CLR_MUTED}Shell into container (bash/sh)${CLR_NC}            ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dex${CLR_NC} <c> [cmd]      ${CLR_MUTED}Execute command in container${CLR_NC}              ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dl${CLR_NC} / ${CLR_DOCKER}dlf${CLR_NC}          ${CLR_MUTED}docker logs / logs -f${CLR_NC}                     ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dstop${CLR_NC} / ${CLR_DOCKER}dstart${CLR_NC}    ${CLR_MUTED}Stop / start container${CLR_NC}                    ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}drm${CLR_NC} / ${CLR_DOCKER}drmi${CLR_NC}        ${CLR_MUTED}Remove container / image${CLR_NC}                  ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}DOCKER COMPOSE${CLR_NC}                                             ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dc${CLR_NC}                 ${CLR_MUTED}docker compose${CLR_NC}                            ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dcu${CLR_NC} / ${CLR_DOCKER}dcud${CLR_NC}        ${CLR_MUTED}compose up / up -d${CLR_NC}                        ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dcd${CLR_NC}                ${CLR_MUTED}compose down${CLR_NC}                              ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dcr${CLR_NC}                ${CLR_MUTED}compose restart${CLR_NC}                           ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dcl${CLR_NC}                ${CLR_MUTED}compose logs -f${CLR_NC}                           ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dcps${CLR_NC}               ${CLR_MUTED}compose ps${CLR_NC}                                ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dcb${CLR_NC}                ${CLR_MUTED}compose build${CLR_NC}                             ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dcex${CLR_NC}               ${CLR_MUTED}compose exec${CLR_NC}                              ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}INSPECTION & NETWORKING${CLR_NC}                                    ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dip${CLR_NC} <container>    ${CLR_MUTED}Get container IP address${CLR_NC}                  ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}denv${CLR_NC} <container>   ${CLR_MUTED}Show container env vars${CLR_NC}                   ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dports${CLR_NC}             ${CLR_MUTED}Show all exposed ports${CLR_NC}                    ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dstats${CLR_NC}             ${CLR_MUTED}Pretty docker stats${CLR_NC}                       ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dvols${CLR_NC}              ${CLR_MUTED}List volumes${CLR_NC}                              ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dnets${CLR_NC}              ${CLR_MUTED}List networks${CLR_NC}                             ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dinspect${CLR_NC} <c> [jq]  ${CLR_MUTED}Inspect with jq filtering${CLR_NC}                 ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}CLEANUP${CLR_NC}                                                    ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dclean${CLR_NC}             ${CLR_MUTED}Remove stopped + dangling${CLR_NC}                 ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dprune${CLR_NC}             ${CLR_MUTED}Interactive system prune${CLR_NC}                  ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_DOCKER}dprune-all${CLR_NC}         ${CLR_MUTED}Aggressive cleanup (confirm)${CLR_NC}              ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}╰─────────────────────────────────────────────────────────────────╯${CLR_NC}"
    echo ""

    # Current Status
    echo -e "  ${CLR_BOLD}Current Status${CLR_NC}"
    echo -e "  ${CLR_MUTED}───────────────────────────────────────${CLR_NC}"

    if [[ "$daemon_running" == "true" ]]; then
        echo -e "    ${CLR_MUTED}Daemon${CLR_NC}      ${CLR_SUCCESS}● running${CLR_NC}"

        local total_containers=$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')
        echo -e "    ${CLR_MUTED}Containers${CLR_NC}  ${CLR_PRIMARY}$containers_running running${CLR_NC} ${CLR_MUTED}/ $total_containers total${CLR_NC}"

        local images=$(docker images -q 2>/dev/null | wc -l | tr -d ' ')
        echo -e "    ${CLR_MUTED}Images${CLR_NC}      ${CLR_PRIMARY}$images${CLR_NC}"

        local volumes=$(docker volume ls -q 2>/dev/null | wc -l | tr -d ' ')
        echo -e "    ${CLR_MUTED}Volumes${CLR_NC}     ${CLR_PRIMARY}$volumes${CLR_NC}"

        local networks=$(docker network ls -q 2>/dev/null | wc -l | tr -d ' ')
        echo -e "    ${CLR_MUTED}Networks${CLR_NC}    ${CLR_PRIMARY}$networks${CLR_NC}"

        # Check for compose
        if docker compose version &>/dev/null; then
            local compose_version=$(docker compose version --short 2>/dev/null)
            echo -e "    ${CLR_MUTED}Compose${CLR_NC}     ${CLR_SUCCESS}v$compose_version${CLR_NC}"
        fi
    else
        echo -e "    ${CLR_MUTED}Daemon${CLR_NC}      ${CLR_ERROR}○ not running${CLR_NC}"
        echo -e "    ${CLR_MUTED}${CLR_NC}            ${CLR_MUTED}Start with: sudo systemctl start docker${CLR_NC}"
    fi

    echo ""
}

# =========================
# Zsh Completions
# =========================

# Completion for container commands - complete running containers
_docker_running_containers() {
    local containers
    containers=(${(f)"$(docker ps --format '{{.Names}}' 2>/dev/null)"})
    _describe 'running containers' containers
}

# Completion for all containers
_docker_all_containers() {
    local containers
    containers=(${(f)"$(docker ps -a --format '{{.Names}}' 2>/dev/null)"})
    _describe 'containers' containers
}

# Completion for images
_docker_images() {
    local images
    images=(${(f)"$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -v '<none>')"})
    _describe 'images' images
}

compdef _docker_running_containers dsh dex dip denv dl dlf dstop drestart
compdef _docker_all_containers drm dstart
compdef _docker_images drmi
