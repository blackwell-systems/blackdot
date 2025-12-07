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
    # Source theme colors
    source "${DOTFILES_DIR:-$HOME/workspace/dotfiles}/lib/_colors.sh"

    # Check if Go is installed and if we're in a Go project
    local logo_color has_go in_project
    if command -v go &>/dev/null; then
        has_go=true
        if [[ -f "go.mod" ]]; then
            logo_color="$CLR_GO"
            in_project=true
        else
            logo_color="$CLR_SUCCESS"
            in_project=false
        fi
    else
        has_go=false
        in_project=false
        logo_color="$CLR_ERROR"
    fi

    echo ""
    echo -e "${logo_color}   ██████╗  ██████╗     ████████╗ ██████╗  ██████╗ ██╗     ███████╗${CLR_NC}"
    echo -e "${logo_color}  ██╔════╝ ██╔═══██╗    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝${CLR_NC}"
    echo -e "${logo_color}  ██║  ███╗██║   ██║       ██║   ██║   ██║██║   ██║██║     ███████╗${CLR_NC}"
    echo -e "${logo_color}  ██║   ██║██║   ██║       ██║   ██║   ██║██║   ██║██║     ╚════██║${CLR_NC}"
    echo -e "${logo_color}  ╚██████╔╝╚██████╔╝       ██║   ╚██████╔╝╚██████╔╝███████╗███████║${CLR_NC}"
    echo -e "${logo_color}   ╚═════╝  ╚═════╝        ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝${CLR_NC}"
    echo ""

    # Aliases section
    echo -e "  ${CLR_BOX}╭─────────────────────────────────────────────────────────────────╮${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}GO ALIASES${CLR_NC}                                                   ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}gob${CLR_NC}                ${CLR_MUTED}go build${CLR_NC}                                  ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}gor${CLR_NC}                ${CLR_MUTED}go run .${CLR_NC}                                  ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}got${CLR_NC}                ${CLR_MUTED}go test ./...${CLR_NC}                             ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}gotv${CLR_NC}               ${CLR_MUTED}go test -v ./...${CLR_NC}                          ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}gof${CLR_NC}                ${CLR_MUTED}go fmt ./...${CLR_NC}                              ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}gom${CLR_NC}                ${CLR_MUTED}go mod tidy${CLR_NC}                               ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}gov${CLR_NC}                ${CLR_MUTED}go vet ./...${CLR_NC}                              ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}gog${CLR_NC}                ${CLR_MUTED}go get${CLR_NC}                                    ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}HELPER FUNCTIONS${CLR_NC}                                            ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}gocover${CLR_NC}            ${CLR_MUTED}Run tests with coverage report${CLR_NC}            ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}goinit${CLR_NC} [name]      ${CLR_MUTED}Initialize Go module${CLR_NC}                      ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}go-new${CLR_NC} <name>      ${CLR_MUTED}Create new Go project with structure${CLR_NC}      ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}go-lint${CLR_NC}            ${CLR_MUTED}Run vet + golangci-lint${CLR_NC}                   ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}go-update${CLR_NC}          ${CLR_MUTED}Update all dependencies${CLR_NC}                   ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}go-outdated${CLR_NC}        ${CLR_MUTED}Show outdated dependencies${CLR_NC}                ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}go-bench${CLR_NC} [pattern] ${CLR_MUTED}Run benchmarks${CLR_NC}                            ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_GO}go-build-all${CLR_NC}       ${CLR_MUTED}Cross-compile for all platforms${CLR_NC}           ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}╰─────────────────────────────────────────────────────────────────╯${CLR_NC}"
    echo ""

    # Current Status
    echo -e "  ${CLR_BOLD}Current Status${CLR_NC}"
    echo -e "  ${CLR_MUTED}───────────────────────────────────────${CLR_NC}"

    if [[ "$has_go" == "true" ]]; then
        local go_version
        go_version=$(go version 2>/dev/null | cut -d' ' -f3)
        echo -e "    ${CLR_MUTED}Go${CLR_NC}        ${CLR_SUCCESS}✓ installed${CLR_NC} ${CLR_MUTED}($go_version)${CLR_NC}"
    else
        echo -e "    ${CLR_MUTED}Go${CLR_NC}        ${CLR_ERROR}✗ not installed${CLR_NC} ${CLR_MUTED}(brew install go)${CLR_NC}"
    fi

    if [[ "$in_project" == "true" ]]; then
        echo -e "    ${CLR_MUTED}Project${CLR_NC}   ${CLR_SUCCESS}✓ go.mod found${CLR_NC}"
        # Try to get module name
        local mod_name
        mod_name=$(head -1 go.mod 2>/dev/null | cut -d' ' -f2)
        if [[ -n "$mod_name" ]]; then
            echo -e "    ${CLR_MUTED}Module${CLR_NC}    ${CLR_PRIMARY}$mod_name${CLR_NC}"
        fi
        # Show Go version from go.mod if present
        local mod_go_version
        mod_go_version=$(grep '^go ' go.mod 2>/dev/null | cut -d' ' -f2)
        if [[ -n "$mod_go_version" ]]; then
            echo -e "    ${CLR_MUTED}Requires${CLR_NC}  ${CLR_MUTED}go $mod_go_version${CLR_NC}"
        fi
    else
        echo -e "    ${CLR_MUTED}Project${CLR_NC}   ${CLR_MUTED}not in Go project${CLR_NC}"
    fi

    # Show if linter is available
    if command -v golangci-lint &>/dev/null; then
        echo -e "    ${CLR_MUTED}Linter${CLR_NC}    ${CLR_SUCCESS}✓ golangci-lint${CLR_NC}"
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
