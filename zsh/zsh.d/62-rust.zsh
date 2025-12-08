# =========================
# 62-rust.zsh
# =========================
# Rust/Cargo aliases and helpers for Rust development workflows
# Provides shortcuts and utilities for cargo commands
# Runtime guards allow enable/disable without shell reload

# =========================
# Cargo Aliases (as functions for runtime guards)
# =========================

# Note: Using 'function' keyword to override existing aliases at parse time
unalias cb cr ct cc ccl cf cdoc cbr crr cba cbra ctq ctn ctv cu cadd crm cclean cfix caudit cw cwr cwt cwc 2>/dev/null

# Core cargo commands
function cb   { require_feature "rust_tools" || return 1; cargo build "$@"; }
function cr   { require_feature "rust_tools" || return 1; cargo run "$@"; }
function ct   { require_feature "rust_tools" || return 1; cargo test "$@"; }
function cc   { require_feature "rust_tools" || return 1; cargo check "$@"; }
function ccl  { require_feature "rust_tools" || return 1; cargo clippy "$@"; }
function cf   { require_feature "rust_tools" || return 1; cargo fmt "$@"; }
function cdoc { require_feature "rust_tools" || return 1; cargo doc --open "$@"; }

# Build variations
function cbr  { require_feature "rust_tools" || return 1; cargo build --release "$@"; }
function crr  { require_feature "rust_tools" || return 1; cargo run --release "$@"; }
function cba  { require_feature "rust_tools" || return 1; cargo build --all-features "$@"; }
function cbra { require_feature "rust_tools" || return 1; cargo build --release --all-features "$@"; }

# Testing variations
function ctq { require_feature "rust_tools" || return 1; cargo test --quiet "$@"; }
function ctn { require_feature "rust_tools" || return 1; cargo test -- --nocapture "$@"; }
function ctv { require_feature "rust_tools" || return 1; cargo test -- --show-output "$@"; }

# Other useful commands
function cu     { require_feature "rust_tools" || return 1; cargo update "$@"; }
function cadd   { require_feature "rust_tools" || return 1; cargo add "$@"; }
function crm    { require_feature "rust_tools" || return 1; cargo remove "$@"; }
function cclean { require_feature "rust_tools" || return 1; cargo clean "$@"; }
function cfix   { require_feature "rust_tools" || return 1; cargo fix --allow-dirty "$@"; }
function caudit { require_feature "rust_tools" || return 1; cargo audit "$@"; }

# Watch mode (requires cargo-watch)
function cw  { require_feature "rust_tools" || return 1; cargo watch "$@"; }
function cwr { require_feature "rust_tools" || return 1; cargo watch -x run "$@"; }
function cwt { require_feature "rust_tools" || return 1; cargo watch -x test "$@"; }
function cwc { require_feature "rust_tools" || return 1; cargo watch -x check "$@"; }

# =========================
# Rust Helper Functions
# =========================

# Update Rust toolchain
rust-update() {
    require_feature "rust_tools" || return 1
    echo "Updating Rust toolchain..."
    rustup update
    echo ""
    echo "Current toolchain:"
    rustup show active-toolchain
}

# Switch Rust toolchain
rust-switch() {
    require_feature "rust_tools" || return 1
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
    require_feature "rust_tools" || return 1
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
    require_feature "rust_tools" || return 1
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
    require_feature "rust_tools" || return 1
    echo "Running cargo check..."
    cargo check || return 1

    echo ""
    echo "Running clippy..."
    cargo clippy -- -D warnings
}

# Format and lint
rust-fix() {
    require_feature "rust_tools" || return 1
    echo "Formatting code..."
    cargo fmt

    echo ""
    echo "Running clippy with auto-fix..."
    cargo clippy --fix --allow-dirty --allow-staged
}

# Show outdated dependencies
rust-outdated() {
    require_feature "rust_tools" || return 1
    if ! command -v cargo-outdated &>/dev/null; then
        echo "Installing cargo-outdated..."
        cargo install cargo-outdated
    fi
    cargo outdated
}

# Expand macros (useful for debugging)
rust-expand() {
    require_feature "rust_tools" || return 1
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
    require_feature "rust_tools" || return 1
    # Source theme colors
    source "${DOTFILES_DIR:-$HOME/workspace/dotfiles}/lib/_colors.sh"

    # Check if Rust is installed and if we're in a Rust project
    local logo_color has_rust in_project
    if command -v rustc &>/dev/null; then
        has_rust=true
        if [[ -f "Cargo.toml" ]]; then
            logo_color="$CLR_RUST"
            in_project=true
        else
            logo_color="$CLR_PRIMARY"
            in_project=false
        fi
    else
        has_rust=false
        in_project=false
        logo_color="$CLR_ERROR"
    fi

    echo ""
    echo -e "${logo_color}  ██████╗ ██╗   ██╗███████╗████████╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗${CLR_NC}"
    echo -e "${logo_color}  ██╔══██╗██║   ██║██╔════╝╚══██╔══╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝${CLR_NC}"
    echo -e "${logo_color}  ██████╔╝██║   ██║███████╗   ██║          ██║   ██║   ██║██║   ██║██║     ███████╗${CLR_NC}"
    echo -e "${logo_color}  ██╔══██╗██║   ██║╚════██║   ██║          ██║   ██║   ██║██║   ██║██║     ╚════██║${CLR_NC}"
    echo -e "${logo_color}  ██║  ██║╚██████╔╝███████║   ██║          ██║   ╚██████╔╝╚██████╔╝███████╗███████║${CLR_NC}"
    echo -e "${logo_color}  ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝          ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝${CLR_NC}"
    echo ""

    # Aliases section
    echo -e "  ${CLR_BOX}╭─────────────────────────────────────────────────────────────────╮${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}CARGO ALIASES${CLR_NC}                                                ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}cb${CLR_NC}                 ${CLR_MUTED}cargo build${CLR_NC}                               ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}cr${CLR_NC}                 ${CLR_MUTED}cargo run${CLR_NC}                                 ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}ct${CLR_NC}                 ${CLR_MUTED}cargo test${CLR_NC}                                ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}cc${CLR_NC}                 ${CLR_MUTED}cargo check${CLR_NC}                               ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}ccl${CLR_NC}                ${CLR_MUTED}cargo clippy${CLR_NC}                              ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}cf${CLR_NC}                 ${CLR_MUTED}cargo fmt${CLR_NC}                                 ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}cbr${CLR_NC}                ${CLR_MUTED}cargo build --release${CLR_NC}                     ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}cw${CLR_NC}                 ${CLR_MUTED}cargo watch${CLR_NC}                               ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_HEADER}HELPER FUNCTIONS${CLR_NC}                                            ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}├─────────────────────────────────────────────────────────────────┤${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}rust-update${CLR_NC}        ${CLR_MUTED}Update Rust toolchain (rustup update)${CLR_NC}     ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}rust-switch${CLR_NC} <tc>   ${CLR_MUTED}Switch toolchain (stable/nightly/beta)${CLR_NC}    ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}rust-new${CLR_NC} <name>    ${CLR_MUTED}Create new Rust project${CLR_NC}                   ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}rust-lint${CLR_NC}          ${CLR_MUTED}Run check + clippy${CLR_NC}                        ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}rust-fix${CLR_NC}           ${CLR_MUTED}Format + clippy auto-fix${CLR_NC}                  ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}rust-outdated${CLR_NC}      ${CLR_MUTED}Show outdated dependencies${CLR_NC}                ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}rust-expand${CLR_NC}        ${CLR_MUTED}Expand macros (debugging)${CLR_NC}                 ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}│${CLR_NC}  ${CLR_RUST}rust-tools-install${CLR_NC} ${CLR_MUTED}Install common Rust tools${CLR_NC}                 ${CLR_BOX}│${CLR_NC}"
    echo -e "  ${CLR_BOX}╰─────────────────────────────────────────────────────────────────╯${CLR_NC}"
    echo ""

    # Current Status
    echo -e "  ${CLR_BOLD}Current Status${CLR_NC}"
    echo -e "  ${CLR_MUTED}───────────────────────────────────────${CLR_NC}"

    if [[ "$has_rust" == "true" ]]; then
        local rust_version toolchain
        rust_version=$(rustc --version 2>/dev/null | cut -d' ' -f2)
        toolchain=$(rustup show active-toolchain 2>/dev/null | cut -d' ' -f1)
        echo -e "    ${CLR_MUTED}Rust${CLR_NC}      ${CLR_SUCCESS}✓ installed${CLR_NC} ${CLR_MUTED}($rust_version)${CLR_NC}"
        echo -e "    ${CLR_MUTED}Toolchain${CLR_NC} ${CLR_PRIMARY}$toolchain${CLR_NC}"
    else
        echo -e "    ${CLR_MUTED}Rust${CLR_NC}      ${CLR_ERROR}✗ not installed${CLR_NC} ${CLR_MUTED}(curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh)${CLR_NC}"
    fi

    if [[ "$in_project" == "true" ]]; then
        echo -e "    ${CLR_MUTED}Project${CLR_NC}   ${CLR_SUCCESS}✓ Cargo.toml found${CLR_NC}"
        # Try to get package name
        local pkg_name
        pkg_name=$(grep -m1 '^name' Cargo.toml 2>/dev/null | cut -d'"' -f2)
        if [[ -n "$pkg_name" ]]; then
            echo -e "    ${CLR_MUTED}Package${CLR_NC}   ${CLR_PRIMARY}$pkg_name${CLR_NC}"
        fi
    else
        echo -e "    ${CLR_MUTED}Project${CLR_NC}   ${CLR_MUTED}not in Rust project${CLR_NC}"
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
