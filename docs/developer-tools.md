# Developer Tool Integrations

> **Deep Integration:** Not just aliases—helpers, completions, and workflow automation for your entire toolchain.

The dotfiles framework provides deep integrations with modern developer tools. Each tool suite is feature-gated and can be enabled/disabled independently.

---

## Quick Overview

| Tool Suite | Feature Flag | Description |
|------------|--------------|-------------|
| [AWS Tools](#aws-tools) | `aws_helpers` | Profile switching, SSO login, identity display |
| [CDK Tools](#cdk-tools) | `cdk_tools` | Deploy, diff, synth with smart defaults |
| [Rust Tools](#rust-tools) | `rust_tools` | Build, test, clippy, fmt, cargo-watch |
| [Go Tools](#go-tools) | `go_tools` | Build, test, coverage, module management |
| [Python Tools](#python-tools) | `python_tools` | uv package manager, pytest, auto-venv |
| [NVM](#nvm-nodejs) | `nvm_integration` | Lazy-loaded Node.js version manager |
| [SDKMAN](#sdkman-java) | `sdkman_integration` | Lazy-loaded Java/Gradle/Kotlin manager |

**Total:** 90+ aliases across all toolchains, with shell completions and helpers.

---

## Feature Control

Each tool suite is independently toggleable:

```bash
# Enable/disable at runtime
dotfiles features enable rust_tools
dotfiles features disable cdk_tools

# Persist across sessions
dotfiles features enable aws_helpers --persist
dotfiles features disable go_tools --persist

# Check what's enabled
dotfiles features list integration
```

---

## AWS Tools

```
   █████╗ ██╗    ██╗███████╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗
  ██╔══██╗██║    ██║██╔════╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝
  ███████║██║ █╗ ██║███████╗       ██║   ██║   ██║██║   ██║██║     ███████╗
  ██╔══██║██║███╗██║╚════██║       ██║   ██║   ██║██║   ██║██║     ╚════██║
  ██║  ██║╚███╔███╔╝███████║       ██║   ╚██████╔╝╚██████╔╝███████╗███████║
  ╚═╝  ╚═╝ ╚══╝╚══╝ ╚══════╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝
```

**Feature:** `aws_helpers` | **File:** `zsh/zsh.d/50-aws.zsh`

### Commands

| Alias | Description |
|-------|-------------|
| `awsprofiles` | List all AWS profiles from config |
| `awsswitch` | Interactive profile switcher (uses fzf) |
| `awswho` | Display current identity (`aws sts get-caller-identity`) |
| `awslogin` | SSO login for current profile |
| `awslogout` | SSO logout |
| `awsset <profile>` | Set `AWS_PROFILE` directly |
| `awsunset` | Unset `AWS_PROFILE` |
| `awsassume <role-arn>` | Assume IAM role and export credentials |
| `awsregion` | Display current region |
| `awsregions` | List all available regions |

### Features

- **Automatic SSO login:** `awsswitch` detects expired SSO sessions and prompts for login
- **fzf integration:** Fuzzy-select from profiles with preview
- **Credential caching:** Honors AWS credential cache for performance
- **Shell completions:** `awsswitch <TAB>` completes profile names

### Example Workflow

```bash
# Morning: login and switch to work profile
awsswitch                    # Fuzzy-select profile
# If SSO expired, auto-prompts: awslogin

# Check who you're authenticated as
awswho
# {
#   "UserId": "AROAEXAMPLE:john.doe@company.com",
#   "Account": "123456789012",
#   "Arn": "arn:aws:sts::123456789012:assumed-role/..."
# }

# Switch to different profile for deployment
awsset production
awswho                       # Verify

# End of day
awslogout
```

---

## CDK Tools

```
   ██████╗██████╗ ██╗  ██╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗
  ██╔════╝██╔══██╗██║ ██╔╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝
  ██║     ██║  ██║█████╔╝        ██║   ██║   ██║██║   ██║██║     ███████╗
  ██║     ██║  ██║██╔═██╗        ██║   ██║   ██║██║   ██║██║     ╚════██║
  ╚██████╗██████╔╝██║  ██╗       ██║   ╚██████╔╝╚██████╔╝███████╗███████║
   ╚═════╝╚═════╝ ╚═╝  ╚═╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝
  AWS Cloud Development Kit
```

**Feature:** `cdk_tools` | **File:** `zsh/zsh.d/55-cdk.zsh` | **Depends on:** `aws_helpers`

### Commands

| Alias | Description |
|-------|-------------|
| `cdkd` | `cdk deploy` with standard flags |
| `cdkda` | `cdk deploy --all` |
| `cdkdf` | `cdk diff` |
| `cdkdfa` | `cdk diff --all` |
| `cdks` | `cdk synth` |
| `cdksa` | `cdk synth --all` |
| `cdkls` | `cdk list` |
| `cdkdestroy` | `cdk destroy` |
| `cdkwatch` | `cdk watch` for hot-reload development |
| `cdkboot` | `cdk bootstrap` |
| `cdkdoc` | Open CDK docs |
| `cdkctx` | `cdk context` |

### Features

- **Smart defaults:** Common flags like `--require-approval never` for non-prod
- **Stack targeting:** Easy `--all` variants for multi-stack apps
- **Watch mode:** `cdkwatch` for rapid iteration
- **Context management:** `cdkctx` helpers

### Example Workflow

```bash
# Develop with hot-reload
cdkwatch

# Check what changed
cdkdf

# Deploy single stack
cdkd MyStack

# Deploy everything
cdkda

# Tear down
cdkdestroy MyStack
```

---

## Rust Tools

```
  ██████╗ ██╗   ██╗███████╗████████╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗
  ██╔══██╗██║   ██║██╔════╝╚══██╔══╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝
  ██████╔╝██║   ██║███████╗   ██║          ██║   ██║   ██║██║   ██║██║     ███████╗
  ██╔══██╗██║   ██║╚════██║   ██║          ██║   ██║   ██║██║   ██║██║     ╚════██║
  ██║  ██║╚██████╔╝███████║   ██║          ██║   ╚██████╔╝╚██████╔╝███████╗███████║
  ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝          ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝
```

**Feature:** `rust_tools` | **File:** `zsh/zsh.d/62-rust.zsh` | **Status:** `rusttools`

### Commands

| Alias | Description |
|-------|-------------|
| `cb` | `cargo build` |
| `cbr` | `cargo build --release` |
| `ct` | `cargo test` |
| `ctr` | `cargo test --release` |
| `cr` | `cargo run` |
| `crr` | `cargo run --release` |
| `ccl` | `cargo clippy` |
| `cf` | `cargo fmt` |
| `cfc` | `cargo fmt --check` |
| `cw` | `cargo watch` (requires cargo-watch) |
| `cwt` | `cargo watch -x test` |
| `cwr` | `cargo watch -x run` |
| `cwc` | `cargo watch -x check` |
| `cdoc` | `cargo doc --open` |
| `cu` | `cargo update` |
| `cadd` | `cargo add` |
| `crm` | `cargo rm` |

### Features

- **Watch mode integration:** `cw*` aliases for TDD workflow
- **Clippy by default:** Lint-first development
- **Format checking:** `cfc` for CI-friendly format checks
- **cargo-edit integration:** `cadd`/`crm` for dependency management

### Example Workflow

```bash
# Start TDD cycle
cwt                          # Watch and run tests on save

# In another terminal, check lints
ccl

# Format before commit
cf

# Build release
cbr

# Generate and view docs
cdoc
```

---

## Go Tools

```
   ██████╗  ██████╗     ████████╗ ██████╗  ██████╗ ██╗     ███████╗
  ██╔════╝ ██╔═══██╗    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝
  ██║  ███╗██║   ██║       ██║   ██║   ██║██║   ██║██║     ███████╗
  ██║   ██║██║   ██║       ██║   ██║   ██║██║   ██║██║     ╚════██║
  ╚██████╔╝╚██████╔╝       ██║   ╚██████╔╝╚██████╔╝███████╗███████║
   ╚═════╝  ╚═════╝        ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝
```

**Feature:** `go_tools` | **File:** `zsh/zsh.d/63-go.zsh` | **Status:** `gotools`

### Commands

| Alias | Description |
|-------|-------------|
| `gob` | `go build` |
| `gobr` | `go build` for current OS/arch |
| `got` | `go test ./...` |
| `gotv` | `go test -v ./...` |
| `gotc` | `go test -cover ./...` |
| `gocover` | Generate and open HTML coverage report |
| `gor` | `go run .` |
| `gom` | `go mod` |
| `gomt` | `go mod tidy` |
| `gomi` | `go mod init` |
| `goget` | `go get` |
| `gofmt` | `gofmt -w .` |
| `goimports` | Run goimports on project |
| `golint` | Run golangci-lint |
| `govet` | `go vet ./...` |
| `godoc` | Start local godoc server |

### Features

- **Coverage workflow:** `gocover` generates HTML report and opens browser
- **Module management:** `gom*` aliases for common mod operations
- **Linting integration:** `golint` runs golangci-lint if installed
- **Local docs:** `godoc` starts documentation server

### Example Workflow

```bash
# Initialize new module
gomi github.com/user/myproject

# Run tests with coverage
gotc

# Generate coverage report
gocover                      # Opens browser with coverage HTML

# Tidy dependencies
gomt

# Lint before commit
golint
govet
```

---

## Python Tools

```
  ██████╗ ██╗   ██╗████████╗██╗  ██╗ ██████╗ ███╗   ██╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗
  ██╔══██╗╚██╗ ██╔╝╚══██╔══╝██║  ██║██╔═══██╗████╗  ██║    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝
  ██████╔╝ ╚████╔╝    ██║   ███████║██║   ██║██╔██╗ ██║       ██║   ██║   ██║██║   ██║██║     ███████╗
  ██╔═══╝   ╚██╔╝     ██║   ██╔══██║██║   ██║██║╚██╗██║       ██║   ██║   ██║██║   ██║██║     ╚════██║
  ██║        ██║      ██║   ██║  ██║╚██████╔╝██║ ╚████║       ██║   ╚██████╔╝╚██████╔╝███████╗███████║
  ╚═╝        ╚═╝      ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝
  Powered by uv
```

**Feature:** `python_tools` | **File:** `zsh/zsh.d/64-python.zsh` | **Status:** `pythontools`

Python development powered by [uv](https://github.com/astral-sh/uv)—a fast Python package manager that handles:
- Package management (replacing pip, pip-tools)
- Virtual environments (replacing venv)
- Python version management (replacing pyenv)

### uv Aliases

| Alias | Description |
|-------|-------------|
| `uvs` | `uv sync` - Sync from lock file |
| `uvr` | `uv run` - Run in project environment |
| `uva` | `uv add` - Add dependency |
| `uvad` | `uv add --dev` - Add dev dependency |
| `uvrm` | `uv remove` - Remove dependency |
| `uvl` | `uv lock` - Update lock file |
| `uvu` | `uv lock --upgrade` - Upgrade all |
| `uvt` | `uv tree` - Show dependency tree |
| `uvv` | `uv venv` - Create virtual environment |
| `uvpyl` | `uv python list` - List Python versions |
| `uvpyi` | `uv python install` - Install Python version |

### Pytest Aliases

| Alias | Description |
|-------|-------------|
| `pt` | `pytest` |
| `ptv` | `pytest -v` - Verbose |
| `ptx` | `pytest -x` - Stop on first failure |
| `ptxv` | `pytest -xvs` - Verbose, stop, show output |
| `ptc` | `pytest --cov` - With coverage |
| `ptl` | `pytest --last-failed` - Only last failed |
| `pts` | `pytest -s` - Show print statements |
| `ptk` | `pytest -k` - Match expression |

### Auto-venv Activation

Automatically prompts to activate virtual environments when entering directories:

```bash
cd my-project/
# 󰌠 Virtual environment detected: .venv
# Activate? [Y/n]
```

**Configuration:**
```bash
export PYTHON_AUTO_VENV="notify"  # Prompt (default)
export PYTHON_AUTO_VENV="auto"    # Auto-activate
export PYTHON_AUTO_VENV="off"     # Disable
```

### Helper Functions

| Function | Description |
|----------|-------------|
| `uv-new <name>` | Create new project (app/lib/script) |
| `uv-clean` | Remove Python artifacts (__pycache__, etc.) |
| `uv-info` | Show Python/uv environment info |
| `uv-python-setup <ver>` | Install and pin Python version |
| `pt-watch` | Run pytest in watch mode |
| `pt-cov` | Coverage with HTML report |

### Example Workflow

```bash
# Create new project
uv-new my-api app
cd my-api

# Add dependencies
uva fastapi uvicorn
uvad pytest pytest-cov

# Sync and run
uvs
uvr python -m uvicorn main:app --reload

# Run tests
ptxv                 # Stop on first failure, verbose
pt-cov               # Coverage with HTML report
```

---

## NVM (Node.js)

**Feature:** `nvm_integration`
**File:** `zsh/zsh.d/70-nvm.zsh`

### Lazy Loading

NVM is lazy-loaded for fast shell startup. It initializes on first use of:
- `node`
- `npm`
- `npx`
- `nvm`
- `yarn`
- `pnpm`

### Commands

Standard NVM commands, plus:

| Command | Description |
|---------|-------------|
| `nvm use` | Switch Node version |
| `nvm install` | Install Node version |
| `nvm ls` | List installed versions |
| `nvm current` | Show current version |

### Auto-switching

If `.nvmrc` exists in a directory, NVM automatically switches versions when you `cd` into it.

```bash
# Project with .nvmrc
cd my-project/
# Found '.nvmrc' with version <18>
# Now using node v18.19.0

node --version
# v18.19.0
```

---

## SDKMAN (Java)

**Feature:** `sdkman_integration`
**File:** `zsh/zsh.d/75-sdkman.zsh`

### Lazy Loading

SDKMAN is lazy-loaded for fast shell startup. It initializes on first use of:
- `java`
- `javac`
- `gradle`
- `mvn`
- `kotlin`
- `sdk`

### Commands

Standard SDKMAN commands:

| Command | Description |
|---------|-------------|
| `sdk list java` | List available Java versions |
| `sdk install java 21-tem` | Install Temurin Java 21 |
| `sdk use java 17-tem` | Switch to Java 17 |
| `sdk current` | Show current versions |
| `sdk default java 21-tem` | Set default Java version |

### Supported Tools

SDKMAN manages:
- Java (multiple distributions: Temurin, Corretto, GraalVM, etc.)
- Gradle
- Maven
- Kotlin
- Scala
- Groovy
- And 50+ other JVM tools

---

## Shell Completions

All tool commands have tab completion:

```bash
# AWS
awsswitch <TAB>              # Shows profile names

# dotfiles
dotfiles <TAB>               # Shows subcommands
dotfiles features <TAB>      # Shows: enable disable list preset status
dotfiles features enable <TAB>  # Shows: vault aws_helpers rust_tools ...

# Rust
cargo <TAB>                  # Standard cargo completions

# Go
go <TAB>                     # Standard go completions
```

Completions are loaded from `zsh/completions/` directory.

---

## Discoverability

### zsh-you-should-use

The `zsh-you-should-use` plugin reminds you about aliases you're not using:

```bash
$ cargo build
# Found existing alias for "cargo build". You should use: "cb"

$ go test ./...
# Found existing alias for "go test ./...". You should use: "got"
```

Over time, this trains muscle memory for the shortcuts.

### Aliases Command (Coming Soon)

A dedicated command to list and search aliases:

```bash
dotfiles aliases             # List all by category
dotfiles aliases rust        # Show Rust aliases
dotfiles aliases search test # Find aliases containing "test"
```

---

## Adding Custom Aliases

Add your own aliases in `~/.config/dotfiles/aliases.local.zsh`:

```zsh
# My custom aliases
alias mytest='cargo test --workspace --all-features'
alias mydeploy='cdk deploy --require-approval never'
```

This file is sourced after the standard aliases, so you can override defaults.

---

## Related Documentation

- [Feature Registry](features.md) - Enable/disable tool integrations
- [CLI Reference](cli-reference.md) - All dotfiles commands
- [Full Documentation](README-FULL.md) - Complete guide
