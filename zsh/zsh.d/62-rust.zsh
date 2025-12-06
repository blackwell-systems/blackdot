# =========================
# 62-rust.zsh
# =========================
# Rust/Cargo aliases and helpers for Rust development workflows
# Provides shortcuts and utilities for cargo commands

# Feature guard: skip if rust_tools is disabled
if type feature_enabled &>/dev/null && ! feature_enabled "rust_tools" 2>/dev/null; then
    return 0
fi

# =========================
# Cargo Aliases
# =========================

# Core cargo commands
alias cb='cargo build'
alias cr='cargo run'
alias ct='cargo test'
alias cc='cargo check'
alias ccl='cargo clippy'
alias cf='cargo fmt'
alias cdoc='cargo doc --open'

# Build variations
alias cbr='cargo build --release'
alias crr='cargo run --release'
alias cba='cargo build --all-features'
alias cbra='cargo build --release --all-features'

# Testing variations
alias ctq='cargo test --quiet'
alias ctn='cargo test -- --nocapture'
alias ctv='cargo test -- --show-output'

# Other useful commands
alias cu='cargo update'
alias cadd='cargo add'
alias crm='cargo remove'
alias cclean='cargo clean'
alias cfix='cargo fix --allow-dirty'
alias caudit='cargo audit'

# Watch mode (requires cargo-watch)
alias cw='cargo watch'
alias cwr='cargo watch -x run'
alias cwt='cargo watch -x test'
alias cwc='cargo watch -x check'

# =========================
# Rust Helper Functions
# =========================

# Update Rust toolchain
rust-update() {
    echo "Updating Rust toolchain..."
    rustup update
    echo ""
    echo "Current toolchain:"
    rustup show active-toolchain
}

# Switch Rust toolchain
rust-switch() {
    local toolchain="${1:-}"

    if [[ -z "$toolchain" ]]; then
        echo "Usage: rust-switch <toolchain>"
        echo ""
        echo "Available toolchains:"
        rustup toolchain list
        return 1
    fi

    rustup default "$toolchain"
    echo "Switched to: $(rustup show active-toolchain)"
}

# Install common Rust tools
rust-tools-install() {
    echo "Installing common Rust development tools..."

    # Clippy and rustfmt (usually included)
    rustup component add clippy rustfmt

    # Useful cargo extensions
    cargo install cargo-watch cargo-edit cargo-audit cargo-outdated cargo-expand 2>/dev/null || true

    echo ""
    echo "Installed tools. Run 'rusttools' to see available commands."
}

# Create new Rust project with common setup
rust-new() {
    local name="${1:-}"
    local template="${2:-bin}"

    if [[ -z "$name" ]]; then
        echo "Usage: rust-new <name> [lib|bin]"
        return 1
    fi

    if [[ "$template" == "lib" ]]; then
        cargo new --lib "$name"
    else
        cargo new "$name"
    fi

    cd "$name"
    echo ""
    echo "Created $template project: $name"
    echo "Run 'cargo run' to build and execute"
}

# Run cargo check then clippy
rust-lint() {
    echo "Running cargo check..."
    cargo check || return 1

    echo ""
    echo "Running clippy..."
    cargo clippy -- -D warnings
}

# Format and lint
rust-fix() {
    echo "Formatting code..."
    cargo fmt

    echo ""
    echo "Running clippy with auto-fix..."
    cargo clippy --fix --allow-dirty --allow-staged
}

# Show outdated dependencies
rust-outdated() {
    if ! command -v cargo-outdated &>/dev/null; then
        echo "Installing cargo-outdated..."
        cargo install cargo-outdated
    fi
    cargo outdated
}

# Expand macros (useful for debugging)
rust-expand() {
    local item="${1:-}"

    if ! command -v cargo-expand &>/dev/null; then
        echo "Installing cargo-expand..."
        cargo install cargo-expand
    fi

    if [[ -n "$item" ]]; then
        cargo expand "$item"
    else
        cargo expand
    fi
}

# =========================
# Rust Tools Help
# =========================

rusttools() {
    # Colors
    local orange='\033[0;33m'
    local red='\033[0;31m'
    local green='\033[0;32m'
    local cyan='\033[0;36m'
    local bold='\033[1m'
    local dim='\033[2m'
    local nc='\033[0m'

    # Check if Rust is installed and if we're in a Rust project
    local logo_color has_rust in_project
    if command -v rustc &>/dev/null; then
        has_rust=true
        if [[ -f "Cargo.toml" ]]; then
            logo_color="$orange"
            in_project=true
        else
            logo_color="$cyan"
            in_project=false
        fi
    else
        has_rust=false
        in_project=false
        logo_color="$red"
    fi

    echo ""
    echo -e "${logo_color}  ██████╗ ██╗   ██╗███████╗████████╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗${nc}"
    echo -e "${logo_color}  ██╔══██╗██║   ██║██╔════╝╚══██╔══╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝${nc}"
    echo -e "${logo_color}  ██████╔╝██║   ██║███████╗   ██║          ██║   ██║   ██║██║   ██║██║     ███████╗${nc}"
    echo -e "${logo_color}  ██╔══██╗██║   ██║╚════██║   ██║          ██║   ██║   ██║██║   ██║██║     ╚════██║${nc}"
    echo -e "${logo_color}  ██║  ██║╚██████╔╝███████║   ██║          ██║   ╚██████╔╝╚██████╔╝███████╗███████║${nc}"
    echo -e "${logo_color}  ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝          ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝${nc}"
    echo ""

    # Aliases section
    echo -e "  ${dim}╭─────────────────────────────────────────────────────────────────╮${nc}"
    echo -e "  ${dim}│${nc}  ${bold}${cyan}CARGO ALIASES${nc}                                                ${dim}│${nc}"
    echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
    echo -e "  ${dim}│${nc}  ${orange}cb${nc}                 ${dim}cargo build${nc}                               ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${orange}cr${nc}                 ${dim}cargo run${nc}                                 ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${orange}ct${nc}                 ${dim}cargo test${nc}                                ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${orange}cc${nc}                 ${dim}cargo check${nc}                               ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${orange}ccl${nc}                ${dim}cargo clippy${nc}                              ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${orange}cf${nc}                 ${dim}cargo fmt${nc}                                 ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${orange}cbr${nc}                ${dim}cargo build --release${nc}                     ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${orange}cw${nc}                 ${dim}cargo watch${nc}                               ${dim}│${nc}"
    echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
    echo -e "  ${dim}│${nc}  ${bold}${cyan}HELPER FUNCTIONS${nc}                                            ${dim}│${nc}"
    echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
    echo -e "  ${dim}│${nc}  ${orange}rust-update${nc}        ${dim}Update Rust toolchain (rustup update)${nc}     ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${orange}rust-switch${nc} <tc>   ${dim}Switch toolchain (stable/nightly/beta)${nc}    ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${orange}rust-new${nc} <name>    ${dim}Create new Rust project${nc}                   ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${orange}rust-lint${nc}          ${dim}Run check + clippy${nc}                        ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${orange}rust-fix${nc}           ${dim}Format + clippy auto-fix${nc}                  ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${orange}rust-outdated${nc}      ${dim}Show outdated dependencies${nc}                ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${orange}rust-expand${nc}        ${dim}Expand macros (debugging)${nc}                 ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${orange}rust-tools-install${nc} ${dim}Install common Rust tools${nc}                 ${dim}│${nc}"
    echo -e "  ${dim}╰─────────────────────────────────────────────────────────────────╯${nc}"
    echo ""

    # Current Status
    echo -e "  ${bold}Current Status${nc}"
    echo -e "  ${dim}───────────────────────────────────────${nc}"

    if [[ "$has_rust" == "true" ]]; then
        local rust_version toolchain
        rust_version=$(rustc --version 2>/dev/null | cut -d' ' -f2)
        toolchain=$(rustup show active-toolchain 2>/dev/null | cut -d' ' -f1)
        echo -e "    ${dim}Rust${nc}      ${green}✓ installed${nc} ${dim}($rust_version)${nc}"
        echo -e "    ${dim}Toolchain${nc} ${cyan}$toolchain${nc}"
    else
        echo -e "    ${dim}Rust${nc}      ${red}✗ not installed${nc} ${dim}(curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh)${nc}"
    fi

    if [[ "$in_project" == "true" ]]; then
        echo -e "    ${dim}Project${nc}   ${green}✓ Cargo.toml found${nc}"
        # Try to get package name
        local pkg_name
        pkg_name=$(grep -m1 '^name' Cargo.toml 2>/dev/null | cut -d'"' -f2)
        if [[ -n "$pkg_name" ]]; then
            echo -e "    ${dim}Package${nc}   ${cyan}$pkg_name${nc}"
        fi
    else
        echo -e "    ${dim}Project${nc}   ${dim}not in Rust project${nc}"
    fi

    echo ""
}

# =========================
# Zsh Completions
# =========================

# Completion for rust-switch
_rust_switch() {
    local toolchains
    toolchains=(${(f)"$(rustup toolchain list 2>/dev/null | cut -d' ' -f1)"})
    _describe 'Rust toolchains' toolchains
}
compdef _rust_switch rust-switch

# Completion for rust-new
_rust_new() {
    _arguments \
        '1:name:' \
        '2:template:(bin lib)'
}
compdef _rust_new rust-new
