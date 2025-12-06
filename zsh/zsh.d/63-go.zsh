# =========================
# 63-go.zsh
# =========================
# Go aliases and helpers for Go development workflows
# Provides shortcuts and utilities for go commands

# Feature guard: skip if go_tools is disabled
if type feature_enabled &>/dev/null && ! feature_enabled "go_tools" 2>/dev/null; then
    return 0
fi

# =========================
# Go Aliases
# =========================

# Core go commands
alias gob='go build'
alias gor='go run .'
alias got='go test ./...'
alias gof='go fmt ./...'
alias gom='go mod tidy'
alias gov='go vet ./...'
alias gog='go get'
alias goi='go install'

# Testing variations
alias gotv='go test -v ./...'
alias gotc='go test -cover ./...'
alias gotr='go test -race ./...'
alias gotb='go test -bench=. ./...'

# Module commands
alias gomi='go mod init'
alias gomd='go mod download'
alias gomv='go mod verify'
alias gomw='go mod why'
alias gomg='go mod graph'

# Build variations
alias gobr='go build -race'
alias gobl='go build -ldflags="-s -w"'

# Other useful commands
alias goc='go clean'
alias godo='go doc'
alias goenv='go env'
alias golist='go list ./...'
alias gowork='go work'

# =========================
# Go Helper Functions
# =========================

# Run tests with coverage and open in browser
gocover() {
    local pkg="${1:-./...}"
    local coverfile="/tmp/coverage.out"

    echo "Running tests with coverage..."
    go test -coverprofile="$coverfile" "$pkg" || return 1

    echo ""
    echo "Coverage summary:"
    go tool cover -func="$coverfile"

    echo ""
    read -q "REPLY?Open coverage in browser? [y/N] "
    echo ""

    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        go tool cover -html="$coverfile"
    fi
}

# Initialize a new Go module
goinit() {
    local name="${1:-}"

    if [[ -z "$name" ]]; then
        # Try to infer from directory name
        name=$(basename "$(pwd)")
        echo "Using directory name as module: $name"
    fi

    go mod init "$name"
    echo ""
    echo "Initialized Go module: $name"
}

# Create a new Go project with common structure
go-new() {
    local name="${1:-}"

    if [[ -z "$name" ]]; then
        echo "Usage: go-new <project-name>"
        return 1
    fi

    mkdir -p "$name"/{cmd,internal,pkg}
    cd "$name"

    # Initialize module
    go mod init "$name"

    # Create main.go
    cat > cmd/main.go << 'EOF'
package main

import "fmt"

func main() {
    fmt.Println("Hello, World!")
}
EOF

    echo "Created Go project: $name"
    echo ""
    echo "Structure:"
    echo "  cmd/       - Application entrypoints"
    echo "  internal/  - Private application code"
    echo "  pkg/       - Public library code"
    echo ""
    echo "Run: go run ./cmd"
}

# Run go vet and staticcheck/golangci-lint
go-lint() {
    echo "Running go vet..."
    go vet ./... || return 1

    echo ""
    if command -v golangci-lint &>/dev/null; then
        echo "Running golangci-lint..."
        golangci-lint run
    elif command -v staticcheck &>/dev/null; then
        echo "Running staticcheck..."
        staticcheck ./...
    else
        echo "No linter found. Install golangci-lint:"
        echo "  brew install golangci-lint"
        echo "  # or"
        echo "  go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
    fi
}

# Update all dependencies
go-update() {
    echo "Updating all dependencies..."
    go get -u ./...
    go mod tidy
    echo ""
    echo "Dependencies updated"
}

# Show outdated dependencies
go-outdated() {
    if ! command -v go-mod-outdated &>/dev/null; then
        echo "Installing go-mod-outdated..."
        go install github.com/psampaz/go-mod-outdated@latest
    fi

    go list -u -m -json all | go-mod-outdated -direct
}

# Generate mocks (if mockgen installed)
go-mock() {
    local source="${1:-}"
    local dest="${2:-}"

    if ! command -v mockgen &>/dev/null; then
        echo "mockgen not installed. Install with:"
        echo "  go install github.com/golang/mock/mockgen@latest"
        return 1
    fi

    if [[ -z "$source" ]]; then
        echo "Usage: go-mock <source-file> [destination]"
        return 1
    fi

    dest="${dest:-mocks/$(basename "$source")}"
    mkdir -p "$(dirname "$dest")"

    mockgen -source="$source" -destination="$dest"
    echo "Generated mock: $dest"
}

# Quick benchmark
go-bench() {
    local pattern="${1:-.}"
    local count="${2:-5}"

    echo "Running benchmarks (count=$count)..."
    go test -bench="$pattern" -benchmem -count="$count" ./...
}

# Cross-compile for common platforms
go-build-all() {
    local name="${1:-$(basename "$(pwd)")}"
    local output_dir="${2:-dist}"

    mkdir -p "$output_dir"

    echo "Building for multiple platforms..."

    GOOS=darwin GOARCH=amd64 go build -o "$output_dir/${name}-darwin-amd64" ./...
    GOOS=darwin GOARCH=arm64 go build -o "$output_dir/${name}-darwin-arm64" ./...
    GOOS=linux GOARCH=amd64 go build -o "$output_dir/${name}-linux-amd64" ./...
    GOOS=linux GOARCH=arm64 go build -o "$output_dir/${name}-linux-arm64" ./...
    GOOS=windows GOARCH=amd64 go build -o "$output_dir/${name}-windows-amd64.exe" ./...

    echo ""
    echo "Built binaries:"
    ls -la "$output_dir"
}

# =========================
# Go Tools Help
# =========================

gotools() {
    # Colors
    local cyan='\033[0;36m'
    local red='\033[0;31m'
    local green='\033[0;32m'
    local bold='\033[1m'
    local dim='\033[2m'
    local nc='\033[0m'

    # Check if Go is installed and if we're in a Go project
    local logo_color has_go in_project
    if command -v go &>/dev/null; then
        has_go=true
        if [[ -f "go.mod" ]]; then
            logo_color="$cyan"
            in_project=true
        else
            logo_color="$green"
            in_project=false
        fi
    else
        has_go=false
        in_project=false
        logo_color="$red"
    fi

    echo ""
    echo -e "${logo_color}   ██████╗  ██████╗     ████████╗ ██████╗  ██████╗ ██╗     ███████╗${nc}"
    echo -e "${logo_color}  ██╔════╝ ██╔═══██╗    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝${nc}"
    echo -e "${logo_color}  ██║  ███╗██║   ██║       ██║   ██║   ██║██║   ██║██║     ███████╗${nc}"
    echo -e "${logo_color}  ██║   ██║██║   ██║       ██║   ██║   ██║██║   ██║██║     ╚════██║${nc}"
    echo -e "${logo_color}  ╚██████╔╝╚██████╔╝       ██║   ╚██████╔╝╚██████╔╝███████╗███████║${nc}"
    echo -e "${logo_color}   ╚═════╝  ╚═════╝        ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝${nc}"
    echo ""

    # Aliases section
    echo -e "  ${dim}╭─────────────────────────────────────────────────────────────────╮${nc}"
    echo -e "  ${dim}│${nc}  ${bold}${cyan}GO ALIASES${nc}                                                   ${dim}│${nc}"
    echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}gob${nc}                ${dim}go build${nc}                                  ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}gor${nc}                ${dim}go run .${nc}                                  ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}got${nc}                ${dim}go test ./...${nc}                             ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}gotv${nc}               ${dim}go test -v ./...${nc}                          ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}gof${nc}                ${dim}go fmt ./...${nc}                              ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}gom${nc}                ${dim}go mod tidy${nc}                               ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}gov${nc}                ${dim}go vet ./...${nc}                              ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}gog${nc}                ${dim}go get${nc}                                    ${dim}│${nc}"
    echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
    echo -e "  ${dim}│${nc}  ${bold}${cyan}HELPER FUNCTIONS${nc}                                            ${dim}│${nc}"
    echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}gocover${nc}            ${dim}Run tests with coverage report${nc}            ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}goinit${nc} [name]      ${dim}Initialize Go module${nc}                      ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}go-new${nc} <name>      ${dim}Create new Go project with structure${nc}      ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}go-lint${nc}            ${dim}Run vet + golangci-lint${nc}                   ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}go-update${nc}          ${dim}Update all dependencies${nc}                   ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}go-outdated${nc}        ${dim}Show outdated dependencies${nc}                ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}go-bench${nc} [pattern] ${dim}Run benchmarks${nc}                            ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${cyan}go-build-all${nc}       ${dim}Cross-compile for all platforms${nc}           ${dim}│${nc}"
    echo -e "  ${dim}╰─────────────────────────────────────────────────────────────────╯${nc}"
    echo ""

    # Current Status
    echo -e "  ${bold}Current Status${nc}"
    echo -e "  ${dim}───────────────────────────────────────${nc}"

    if [[ "$has_go" == "true" ]]; then
        local go_version
        go_version=$(go version 2>/dev/null | cut -d' ' -f3)
        echo -e "    ${dim}Go${nc}        ${green}✓ installed${nc} ${dim}($go_version)${nc}"
    else
        echo -e "    ${dim}Go${nc}        ${red}✗ not installed${nc} ${dim}(brew install go)${nc}"
    fi

    if [[ "$in_project" == "true" ]]; then
        echo -e "    ${dim}Project${nc}   ${green}✓ go.mod found${nc}"
        # Try to get module name
        local mod_name
        mod_name=$(head -1 go.mod 2>/dev/null | cut -d' ' -f2)
        if [[ -n "$mod_name" ]]; then
            echo -e "    ${dim}Module${nc}    ${cyan}$mod_name${nc}"
        fi
        # Show Go version from go.mod if present
        local mod_go_version
        mod_go_version=$(grep '^go ' go.mod 2>/dev/null | cut -d' ' -f2)
        if [[ -n "$mod_go_version" ]]; then
            echo -e "    ${dim}Requires${nc}  ${dim}go $mod_go_version${nc}"
        fi
    else
        echo -e "    ${dim}Project${nc}   ${dim}not in Go project${nc}"
    fi

    # Show if linter is available
    if command -v golangci-lint &>/dev/null; then
        echo -e "    ${dim}Linter${nc}    ${green}✓ golangci-lint${nc}"
    fi

    echo ""
}

# =========================
# Zsh Completions
# =========================

# Completion for goinit
_goinit() {
    _arguments '1:module name:'
}
compdef _goinit goinit

# Completion for go-new
_go_new() {
    _arguments '1:project name:'
}
compdef _go_new go-new

# Completion for go-bench
_go_bench() {
    _arguments '1:pattern:' '2:count:'
}
compdef _go_bench go-bench
