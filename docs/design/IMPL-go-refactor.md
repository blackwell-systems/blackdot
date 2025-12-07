# Go Refactor Design Document

> **Status:** Draft
> **Author:** Claude
> **Created:** 2025-12-07
> **Scope:** Complete rewrite of dotfiles CLI from Zsh to Go

---

## Executive Summary

This document describes the architecture for rewriting the dotfiles system from ~4,000 lines of Zsh to a single Go binary. The design emphasizes:

1. **Vault as independent package** - Reusable library for multi-backend secret management
2. **Feature parity** - All 19 CLI commands preserved
3. **Incremental migration** - Shell and Go coexist during transition
4. **Zero runtime dependencies** - Single static binary, no shell required

**Key Benefits:**
- 10-50x faster startup (no shell/subshell overhead)
- Cross-platform binaries (macOS, Linux, Windows)
- Real testing with mocks and coverage
- Type-safe configuration and APIs

---

## Table of Contents

1. [Current Architecture Analysis](#1-current-architecture-analysis)
2. [Go Architecture Overview](#2-go-architecture-overview)
3. [Package Structure](#3-package-structure)
4. [Component Deep Dives](#4-component-deep-dives)
   - [4.1 Vault Package (Independent)](#41-vault-package-independent)
   - [4.2 Feature Registry](#42-feature-registry)
   - [4.3 Configuration System](#43-configuration-system)
   - [4.4 Template Engine](#44-template-engine)
   - [4.5 CLI Framework](#45-cli-framework)
5. [Shell Integration](#5-shell-integration)
6. [Testing Strategy](#6-testing-strategy)
7. [Build & Distribution](#7-build--distribution)
8. [Migration Phases](#8-migration-phases)
9. [Backwards Compatibility](#9-backwards-compatibility)
10. [Risk Analysis](#10-risk-analysis)

---

## 0. What Stays as Zsh vs What Moves to Go

### Critical Understanding: Hybrid Architecture

The Go binary **does not replace** your shell configuration. It **only replaces** the CLI tools.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        STAYS AS ZSH (Shell Layer)                       │
│                                                                          │
│  zsh/zsh.d/                                                             │
│  ├── 00-init.zsh        # Powerlevel10k, OS detection, brew setup       │
│  ├── 10-plugins.zsh     # Zinit, plugin loading                         │
│  ├── 20-env.zsh         # PATH, environment variables                   │
│  ├── 30-tools.zsh       # Tool configs (fzf, zoxide, etc.)              │
│  ├── 40-aliases.zsh     # Aliases + dotfiles dispatcher (THIN WRAPPER)  │
│  ├── 50-functions.zsh   # Shell functions                               │
│  ├── 60-aws.zsh         # AWS completions, aliases                      │
│  ├── 61-cdk.zsh         # CDK aliases                                   │
│  ├── 62-rust.zsh        # Cargo/rustup setup                            │
│  ├── 63-go.zsh          # Go environment                                │
│  ├── 64-python.zsh      # Python/uv/venv                                │
│  ├── 65-ssh.zsh         # SSH agent, keys                               │
│  ├── 66-docker.zsh      # Docker aliases                                │
│  ├── 70-claude.zsh      # Claude Code integration                       │
│  ├── 80-git.zsh         # Git aliases, functions                        │
│  └── 90-integrations.zsh # NVM, SDKMAN, etc.                            │
│  └── p10k.zsh           # Prompt theme                                  │
│                                                                          │
│  WHY: These configure the SHELL ITSELF. You can't do this from Go.      │
│  - Environment variables must be set in shell                           │
│  - Aliases are shell constructs                                          │
│  - Completions run in shell context                                      │
│  - Prompt is shell-native                                                │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                      MOVES TO GO (CLI Tools Layer)                       │
│                                                                          │
│  bin/dotfiles-*  →  Single `dotfiles` Go binary                          │
│  ├── dotfiles-features   →  dotfiles features                           │
│  ├── dotfiles-config     →  dotfiles config                             │
│  ├── dotfiles-vault      →  dotfiles vault                              │
│  ├── dotfiles-template   →  dotfiles template                           │
│  ├── dotfiles-doctor     →  dotfiles doctor                             │
│  ├── dotfiles-setup      →  dotfiles setup                              │
│  ├── dotfiles-sync       →  dotfiles sync                               │
│  ├── dotfiles-backup     →  dotfiles backup                             │
│  ├── dotfiles-drift      →  dotfiles drift                              │
│  └── ... (19 total)                                                      │
│                                                                          │
│  lib/_*.sh  →  Go packages                                               │
│  ├── _features.sh   →  internal/feature/                                 │
│  ├── _config.sh     →  internal/config/                                  │
│  ├── _vault.sh      →  pkg/vault/                                        │
│  ├── _templates.sh  →  internal/template/                                │
│  └── _state.sh      →  internal/config/state.go                          │
│                                                                          │
│  vault/backends/*.sh  →  pkg/vault/backends/                             │
│  ├── bitwarden.sh   →  bitwarden/bitwarden.go                            │
│  ├── 1password.sh   →  onepassword/onepassword.go                        │
│  └── pass.sh        →  pass/pass.go                                      │
│                                                                          │
│  WHY: These are COMMANDS that can be any executable.                     │
│  - No shell state needed                                                 │
│  - Called as subprocesses                                                │
│  - Return exit codes, output text                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

### The Bridge: Thin Shell Wrapper

The `dotfiles` function in `40-aliases.zsh` becomes a **thin wrapper** that calls the Go binary:

```zsh
# BEFORE: 750-line shell dispatcher
dotfiles() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true
    case "$cmd" in
        vault)
            # 100+ lines of subcommand handling
            ;;
        template)
            # 80+ lines of subcommand handling
            ;;
        # ... etc
    esac
}

# AFTER: 10-line thin wrapper
dotfiles() {
    if [[ -x "$DOTFILES_DIR/bin/dotfiles" ]]; then
        "$DOTFILES_DIR/bin/dotfiles" "$@"
    else
        echo "dotfiles binary not found. Run: make build" >&2
        return 1
    fi
}
```

### What This Means in Practice

| Operation | Before (Shell) | After (Go) |
|-----------|----------------|------------|
| `dotfiles features list` | Zsh sources `_features.sh`, runs function | Go binary executes |
| `dotfiles vault push` | Zsh sources `_vault.sh`, calls backend | Go binary with vault package |
| `cd $WORKSPACE` | Zsh alias (stays as-is) | Zsh alias (unchanged) |
| Prompt display | p10k.zsh (stays as-is) | p10k.zsh (unchanged) |
| `aws sso login` | Zsh function/alias | Zsh function/alias |
| Tab completion | Zsh compdef | Generated by `dotfiles completion zsh` |

### Shell Modules That Query Go

Some shell modules may need to query feature state:

```zsh
# 60-aws.zsh - Before
if feature_enabled "aws_helpers"; then
    # load aws stuff
fi

# 60-aws.zsh - After (calls Go binary)
if dotfiles features check aws_helpers 2>/dev/null; then
    # load aws stuff
fi
```

Or use the generated shell integration:

```zsh
# In 00-init.zsh, after Go binary exists:
eval "$(dotfiles shell-init zsh)"

# This defines:
# - feature_enabled() function that calls Go
# - Completions
# - Any shell helpers
```

---

## 1. Current Architecture Analysis

### 1.1 Codebase Metrics

| Component | File | Lines | Complexity |
|-----------|------|-------|------------|
| Feature Registry | `lib/_features.sh` | 639 | High (dependency resolution, cycles) |
| Config System | `lib/_config.sh` | 291 | Medium (JSON read/write) |
| Vault Abstraction | `lib/_vault.sh` | 611 | High (plugin system, sessions) |
| Template Engine | `lib/_templates.sh` | 1,299 | High (parsing, conditionals, loops) |
| **CLI Commands** | `bin/dotfiles-*` | ~2,500 | Medium (19 commands) |
| **Vault Backends** | `vault/backends/*.sh` | ~1,200 | Medium (3 backends) |
| **Total** | | **~6,500** | |

### 1.2 Architectural Patterns (Current)

```
┌─────────────────────────────────────────────────────────────┐
│                     Shell Entry Point                        │
│                    (zsh/zsh.d/40-aliases.zsh)               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    CLI Dispatcher                            │
│              (dotfiles → bin/dotfiles-*)                    │
└─────────────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         ▼                    ▼                    ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│  _features  │      │   _config   │      │   _vault    │
│     .sh     │      │     .sh     │      │     .sh     │
└─────────────┘      └─────────────┘      └─────────────┘
                                                  │
                           ┌──────────────────────┼──────────────────────┐
                           ▼                      ▼                      ▼
                    ┌────────────┐         ┌────────────┐         ┌────────────┐
                    │ bitwarden  │         │ 1password  │         │    pass    │
                    │    .sh     │         │    .sh     │         │    .sh     │
                    └────────────┘         └────────────┘         └────────────┘
```

### 1.3 Pain Points Addressed by Go

| Problem | Shell | Go Solution |
|---------|-------|-------------|
| Startup time | ~200-500ms (sourcing) | ~5-10ms (binary) |
| Error handling | Exit codes, `set -e` | `error` type, stack traces |
| Testing | BATS (slow, limited mocks) | `testing` pkg, table-driven |
| Cross-platform | macOS/Linux only | +Windows, ARM |
| Dependencies | jq, gpg, pass, etc. | Embedded, optional externals |
| Concurrency | Subshells, `&` | Goroutines, channels |
| Type safety | None | Full static typing |

---

## 2. Go Architecture Overview

### 2.1 High-Level Design

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              dotfiles CLI                                │
│                         (cmd/dotfiles/main.go)                          │
└─────────────────────────────────────────────────────────────────────────┘
                                     │
                                     │ imports
         ┌───────────────────────────┼───────────────────────────┐
         ▼                           ▼                           ▼
┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐
│  internal/cli   │        │ internal/feature│        │ internal/config │
│                 │        │                 │        │                 │
│ - cobra setup   │        │ - registry      │        │ - JSON config   │
│ - 19 commands   │        │ - dependencies  │        │ - layered       │
│ - output format │        │ - presets       │        │ - migration     │
└─────────────────┘        └─────────────────┘        └─────────────────┘
         │                           │                           │
         │                           ▼                           │
         │                 ┌─────────────────┐                   │
         │                 │internal/template│                   │
         │                 │                 │                   │
         │                 │ - parsing       │                   │
         │                 │ - conditionals  │                   │
         │                 │ - filters       │                   │
         │                 └─────────────────┘                   │
         │                                                       │
         └───────────────────────┬───────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│                        pkg/vault (INDEPENDENT)                           │
│                                                                          │
│  ┌─────────────┐   ┌─────────────────────────────────────────────────┐  │
│  │   vault.go  │   │                  backends/                       │  │
│  │             │   │  ┌───────────┐ ┌───────────┐ ┌───────────┐      │  │
│  │ - Interface │──▶│  │ bitwarden │ │ onepassword│ │   pass    │      │  │
│  │ - Factory   │   │  │   .go     │ │    .go    │ │   .go     │      │  │
│  │ - Session   │   │  └───────────┘ └───────────┘ └───────────┘      │  │
│  └─────────────┘   └─────────────────────────────────────────────────┘  │
│                                                                          │
│  Can be imported independently:                                          │
│  import "github.com/user/dotfiles/pkg/vault"                            │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Design Principles

1. **Vault is a library first** - No dotfiles-specific logic in `pkg/vault`
2. **Internal packages are private** - `internal/` prevents external imports
3. **Interfaces at boundaries** - Easy mocking for tests
4. **Configuration by struct** - Type-safe config, no string keys
5. **Errors are values** - Wrap with context, no panics

---

## 3. Package Structure

```
dotfiles/
├── cmd/
│   └── dotfiles/
│       └── main.go                 # Entry point, cobra root
│
├── pkg/                            # PUBLIC - importable by others
│   └── vault/
│       ├── vault.go                # Interface, factory, errors
│       ├── session.go              # Session management
│       ├── options.go              # Functional options pattern
│       ├── backends/
│       │   ├── bitwarden/
│       │   │   └── bitwarden.go
│       │   ├── onepassword/
│       │   │   └── onepassword.go
│       │   └── pass/
│       │       └── pass.go
│       └── vault_test.go
│
├── internal/                       # PRIVATE - dotfiles-specific
│   ├── cli/
│   │   ├── root.go                 # Root command, global flags
│   │   ├── features.go             # dotfiles features
│   │   ├── config.go               # dotfiles config
│   │   ├── vault.go                # dotfiles vault
│   │   ├── template.go             # dotfiles template
│   │   ├── doctor.go               # dotfiles doctor
│   │   ├── setup.go                # dotfiles setup
│   │   ├── sync.go                 # dotfiles sync
│   │   ├── backup.go               # dotfiles backup
│   │   ├── drift.go                # dotfiles drift
│   │   ├── hook.go                 # dotfiles hook
│   │   ├── encrypt.go              # dotfiles encrypt
│   │   ├── packages.go             # dotfiles packages
│   │   ├── migrate.go              # dotfiles migrate
│   │   ├── lint.go                 # dotfiles lint
│   │   ├── diff.go                 # dotfiles diff
│   │   ├── metrics.go              # dotfiles metrics
│   │   ├── uninstall.go            # dotfiles uninstall
│   │   └── output.go               # Shared output formatting
│   │
│   ├── feature/
│   │   ├── registry.go             # Feature definitions
│   │   ├── dependency.go           # Dependency resolution
│   │   ├── preset.go               # Preset definitions
│   │   ├── state.go                # Runtime state
│   │   └── feature_test.go
│   │
│   ├── config/
│   │   ├── config.go               # Config struct, load/save
│   │   ├── layers.go               # Layered config resolution
│   │   ├── migrate.go              # v2 INI → v3 JSON migration
│   │   ├── defaults.go             # Default values
│   │   └── config_test.go
│   │
│   ├── template/
│   │   ├── engine.go               # Main render function
│   │   ├── parser.go               # Tokenizer, AST
│   │   ├── variables.go            # Variable resolution
│   │   ├── conditionals.go         # {{#if}}, {{#unless}}
│   │   ├── loops.go                # {{#each}}
│   │   ├── filters.go              # Pipeline filters
│   │   └── template_test.go
│   │
│   ├── doctor/
│   │   ├── checks.go               # Health check definitions
│   │   ├── fix.go                  # Auto-fix logic
│   │   └── doctor_test.go
│   │
│   ├── shell/
│   │   ├── integration.go          # Shell hook generation
│   │   ├── zsh.go                  # Zsh-specific
│   │   ├── bash.go                 # Bash-specific (future)
│   │   └── env.go                  # Environment detection
│   │
│   └── platform/
│       ├── detect.go               # OS, arch detection
│       ├── paths.go                # XDG, home, dotfiles dir
│       └── exec.go                 # Command execution helpers
│
├── go.mod
├── go.sum
├── Makefile                        # Build targets
└── .goreleaser.yaml                # Release automation
```

---

## 4. Component Deep Dives

### 4.1 Vault Package (Independent)

The vault package is designed to be a **standalone library** that can be used outside of dotfiles.

#### 4.1.1 Core Interface

```go
// pkg/vault/vault.go

package vault

import (
    "context"
    "io"
)

// Backend represents a secret storage backend.
// Implementations: Bitwarden, 1Password, pass
type Backend interface {
    // Metadata
    Name() string

    // Lifecycle
    Init(ctx context.Context) error
    Close() error

    // Authentication
    IsAuthenticated(ctx context.Context) bool
    Authenticate(ctx context.Context) (Session, error)

    // Sync
    Sync(ctx context.Context, session Session) error

    // Item operations
    GetItem(ctx context.Context, name string, session Session) (*Item, error)
    GetNotes(ctx context.Context, name string, session Session) (string, error)
    ItemExists(ctx context.Context, name string, session Session) (bool, error)
    ListItems(ctx context.Context, session Session) ([]*Item, error)

    // Mutations
    CreateItem(ctx context.Context, name, content string, session Session) error
    UpdateItem(ctx context.Context, name, content string, session Session) error
    DeleteItem(ctx context.Context, name string, session Session) error

    // Optional: Location management
    LocationManager
}

// Session represents an authenticated session.
// Opaque to callers - backend-specific internals.
type Session interface {
    Token() string
    IsValid(ctx context.Context) bool
    Refresh(ctx context.Context) error
}

// Item represents a vault item.
type Item struct {
    ID       string            `json:"id"`
    Name     string            `json:"name"`
    Type     ItemType          `json:"type"`
    Notes    string            `json:"notes,omitempty"`
    Fields   map[string]string `json:"fields,omitempty"`
    Created  time.Time         `json:"created,omitempty"`
    Modified time.Time         `json:"modified,omitempty"`
}

// ItemType indicates the type of vault item.
type ItemType int

const (
    ItemTypeSecureNote ItemType = iota
    ItemTypeLogin
    ItemTypeSSHKey
    ItemTypeFile
)

// LocationManager handles organizational units (folders, vaults, etc.)
type LocationManager interface {
    ListLocations(ctx context.Context, session Session) ([]string, error)
    LocationExists(ctx context.Context, name string, session Session) (bool, error)
    CreateLocation(ctx context.Context, name string, session Session) error
    ListItemsInLocation(ctx context.Context, locType, locValue string, session Session) ([]*Item, error)
}
```

#### 4.1.2 Factory Pattern

```go
// pkg/vault/vault.go

// BackendType identifies a vault backend.
type BackendType string

const (
    BackendBitwarden   BackendType = "bitwarden"
    BackendOnePassword BackendType = "1password"
    BackendPass        BackendType = "pass"
)

// Config holds vault configuration.
type Config struct {
    Backend     BackendType
    StorePath   string            // For pass: ~/.password-store
    Prefix      string            // Item prefix: "dotfiles"
    SessionFile string            // Cached session location
    Options     map[string]string // Backend-specific options
}

// New creates a new vault backend based on configuration.
func New(cfg Config) (Backend, error) {
    switch cfg.Backend {
    case BackendBitwarden:
        return bitwarden.New(cfg.Options)
    case BackendOnePassword:
        return onepassword.New(cfg.Options)
    case BackendPass:
        return pass.New(cfg.StorePath, cfg.Prefix)
    default:
        return nil, fmt.Errorf("unknown backend: %s", cfg.Backend)
    }
}

// MustNew creates a backend or panics. Use in init() only.
func MustNew(cfg Config) Backend {
    b, err := New(cfg)
    if err != nil {
        panic(err)
    }
    return b
}
```

#### 4.1.3 Pass Backend Implementation

```go
// pkg/vault/backends/pass/pass.go

package pass

import (
    "context"
    "fmt"
    "os"
    "os/exec"
    "path/filepath"
    "strings"

    "github.com/user/dotfiles/pkg/vault"
)

// Backend implements vault.Backend for pass.
type Backend struct {
    storePath string
    prefix    string
}

// New creates a new pass backend.
func New(storePath, prefix string) (*Backend, error) {
    if storePath == "" {
        storePath = filepath.Join(os.Getenv("HOME"), ".password-store")
    }
    if prefix == "" {
        prefix = "dotfiles"
    }
    return &Backend{
        storePath: storePath,
        prefix:    prefix,
    }, nil
}

func (b *Backend) Name() string { return "pass" }

func (b *Backend) Init(ctx context.Context) error {
    // Check pass is installed
    if _, err := exec.LookPath("pass"); err != nil {
        return fmt.Errorf("pass not installed: %w", err)
    }

    // Check gpg is installed
    if _, err := exec.LookPath("gpg"); err != nil {
        return fmt.Errorf("gpg not installed: %w", err)
    }

    // Check store exists
    if _, err := os.Stat(b.storePath); os.IsNotExist(err) {
        return fmt.Errorf("password store not initialized at %s", b.storePath)
    }

    return nil
}

func (b *Backend) Close() error { return nil }

func (b *Backend) IsAuthenticated(ctx context.Context) bool {
    // pass uses GPG agent - try listing
    cmd := exec.CommandContext(ctx, "pass", "ls")
    return cmd.Run() == nil
}

func (b *Backend) Authenticate(ctx context.Context) (vault.Session, error) {
    // pass doesn't use sessions - GPG agent handles auth
    return &passSession{}, nil
}

func (b *Backend) GetNotes(ctx context.Context, name string, _ vault.Session) (string, error) {
    path := b.itemPath(name)
    cmd := exec.CommandContext(ctx, "pass", "show", path)
    out, err := cmd.Output()
    if err != nil {
        if exitErr, ok := err.(*exec.ExitError); ok && exitErr.ExitCode() == 1 {
            return "", nil // Item not found
        }
        return "", fmt.Errorf("pass show failed: %w", err)
    }
    return string(out), nil
}

func (b *Backend) ItemExists(ctx context.Context, name string, _ vault.Session) (bool, error) {
    gpgPath := filepath.Join(b.storePath, b.prefix, name+".gpg")
    _, err := os.Stat(gpgPath)
    if os.IsNotExist(err) {
        return false, nil
    }
    if err != nil {
        return false, err
    }
    return true, nil
}

func (b *Backend) CreateItem(ctx context.Context, name, content string, _ vault.Session) error {
    exists, err := b.ItemExists(ctx, name, nil)
    if err != nil {
        return err
    }
    if exists {
        return fmt.Errorf("item %q already exists", name)
    }

    path := b.itemPath(name)
    cmd := exec.CommandContext(ctx, "pass", "insert", "-m", path)
    cmd.Stdin = strings.NewReader(content)

    if err := cmd.Run(); err != nil {
        return fmt.Errorf("pass insert failed: %w", err)
    }
    return nil
}

func (b *Backend) UpdateItem(ctx context.Context, name, content string, _ vault.Session) error {
    exists, err := b.ItemExists(ctx, name, nil)
    if err != nil {
        return err
    }
    if !exists {
        return fmt.Errorf("item %q not found", name)
    }

    path := b.itemPath(name)
    cmd := exec.CommandContext(ctx, "pass", "insert", "-m", "-f", path)
    cmd.Stdin = strings.NewReader(content)

    if err := cmd.Run(); err != nil {
        return fmt.Errorf("pass insert failed: %w", err)
    }
    return nil
}

func (b *Backend) DeleteItem(ctx context.Context, name string, _ vault.Session) error {
    path := b.itemPath(name)
    cmd := exec.CommandContext(ctx, "pass", "rm", "-f", path)
    if err := cmd.Run(); err != nil {
        return fmt.Errorf("pass rm failed: %w", err)
    }
    return nil
}

func (b *Backend) itemPath(name string) string {
    return filepath.Join(b.prefix, name)
}

// passSession implements vault.Session for pass (no-op).
type passSession struct{}

func (s *passSession) Token() string                           { return "" }
func (s *passSession) IsValid(ctx context.Context) bool        { return true }
func (s *passSession) Refresh(ctx context.Context) error       { return nil }
```

#### 4.1.4 Bitwarden Backend Implementation

```go
// pkg/vault/backends/bitwarden/bitwarden.go

package bitwarden

import (
    "context"
    "encoding/json"
    "fmt"
    "os"
    "os/exec"
    "strings"
    "time"

    "github.com/user/dotfiles/pkg/vault"
)

// Backend implements vault.Backend for Bitwarden CLI.
type Backend struct {
    sessionFile string
}

func New(opts map[string]string) (*Backend, error) {
    sessionFile := opts["session_file"]
    if sessionFile == "" {
        home, _ := os.UserHomeDir()
        sessionFile = filepath.Join(home, ".config", "dotfiles", ".vault-session")
    }
    return &Backend{sessionFile: sessionFile}, nil
}

func (b *Backend) Name() string { return "bitwarden" }

func (b *Backend) Init(ctx context.Context) error {
    if _, err := exec.LookPath("bw"); err != nil {
        return fmt.Errorf("bitwarden CLI not installed: %w", err)
    }
    return nil
}

func (b *Backend) Close() error { return nil }

func (b *Backend) IsAuthenticated(ctx context.Context) bool {
    session, err := b.loadSession()
    if err != nil || session == "" {
        return false
    }

    cmd := exec.CommandContext(ctx, "bw", "unlock", "--check", "--session", session)
    return cmd.Run() == nil
}

func (b *Backend) Authenticate(ctx context.Context) (vault.Session, error) {
    // Try cached session first
    if token, err := b.loadSession(); err == nil && token != "" {
        sess := &bwSession{token: token, backend: b}
        if sess.IsValid(ctx) {
            return sess, nil
        }
    }

    // Check login status
    cmd := exec.CommandContext(ctx, "bw", "status")
    out, _ := cmd.Output()

    var status struct {
        Status string `json:"status"`
    }
    json.Unmarshal(out, &status)

    if status.Status == "unauthenticated" {
        return nil, fmt.Errorf("not logged in to Bitwarden - run: bw login")
    }

    // Unlock and get session
    cmd = exec.CommandContext(ctx, "bw", "unlock", "--raw")
    cmd.Stdin = os.Stdin
    cmd.Stderr = os.Stderr

    out, err := cmd.Output()
    if err != nil {
        return nil, fmt.Errorf("bw unlock failed: %w", err)
    }

    token := strings.TrimSpace(string(out))
    if err := b.saveSession(token); err != nil {
        // Non-fatal - just log
    }

    return &bwSession{token: token, backend: b}, nil
}

func (b *Backend) Sync(ctx context.Context, session vault.Session) error {
    cmd := exec.CommandContext(ctx, "bw", "sync", "--session", session.Token())
    return cmd.Run()
}

func (b *Backend) GetItem(ctx context.Context, name string, session vault.Session) (*vault.Item, error) {
    cmd := exec.CommandContext(ctx, "bw", "get", "item", name, "--session", session.Token())
    out, err := cmd.Output()
    if err != nil {
        if strings.Contains(string(out), "Not found") {
            return nil, nil
        }
        return nil, err
    }

    var bwItem struct {
        ID    string `json:"id"`
        Name  string `json:"name"`
        Type  int    `json:"type"`
        Notes string `json:"notes"`
    }

    if err := json.Unmarshal(out, &bwItem); err != nil {
        return nil, err
    }

    return &vault.Item{
        ID:    bwItem.ID,
        Name:  bwItem.Name,
        Type:  vault.ItemType(bwItem.Type),
        Notes: bwItem.Notes,
    }, nil
}

func (b *Backend) GetNotes(ctx context.Context, name string, session vault.Session) (string, error) {
    item, err := b.GetItem(ctx, name, session)
    if err != nil {
        return "", err
    }
    if item == nil {
        return "", nil
    }
    return item.Notes, nil
}

// ... remaining methods follow same pattern

func (b *Backend) loadSession() (string, error) {
    data, err := os.ReadFile(b.sessionFile)
    if err != nil {
        return "", err
    }
    return strings.TrimSpace(string(data)), nil
}

func (b *Backend) saveSession(token string) error {
    return os.WriteFile(b.sessionFile, []byte(token), 0600)
}

type bwSession struct {
    token   string
    backend *Backend
}

func (s *bwSession) Token() string { return s.token }

func (s *bwSession) IsValid(ctx context.Context) bool {
    cmd := exec.CommandContext(ctx, "bw", "unlock", "--check", "--session", s.token)
    return cmd.Run() == nil
}

func (s *bwSession) Refresh(ctx context.Context) error {
    // Re-authenticate
    newSession, err := s.backend.Authenticate(ctx)
    if err != nil {
        return err
    }
    s.token = newSession.Token()
    return nil
}
```

#### 4.1.5 Usage as Independent Library

```go
// Example: Using vault package in another project

package main

import (
    "context"
    "fmt"
    "log"

    "github.com/user/dotfiles/pkg/vault"
    _ "github.com/user/dotfiles/pkg/vault/backends/pass" // Register backend
)

func main() {
    ctx := context.Background()

    // Create vault client
    v, err := vault.New(vault.Config{
        Backend:   vault.BackendPass,
        StorePath: "/home/user/.password-store",
        Prefix:    "myapp",
    })
    if err != nil {
        log.Fatal(err)
    }
    defer v.Close()

    // Initialize
    if err := v.Init(ctx); err != nil {
        log.Fatal(err)
    }

    // Authenticate (no-op for pass)
    session, err := v.Authenticate(ctx)
    if err != nil {
        log.Fatal(err)
    }

    // Store a secret
    if err := v.CreateItem(ctx, "API-Key", "sk-1234567890", session); err != nil {
        log.Fatal(err)
    }

    // Retrieve it
    notes, err := v.GetNotes(ctx, "API-Key", session)
    if err != nil {
        log.Fatal(err)
    }
    fmt.Println("Secret:", notes)
}
```

---

### 4.2 Feature Registry

#### 4.2.1 Design

```go
// internal/feature/registry.go

package feature

import (
    "fmt"
    "sort"
)

// Category classifies features.
type Category string

const (
    CategoryCore        Category = "core"
    CategoryOptional    Category = "optional"
    CategoryIntegration Category = "integration"
)

// Definition describes a feature.
type Definition struct {
    Name         string
    Description  string
    Category     Category
    Default      DefaultState
    Dependencies []string
    Conflicts    []string
}

// DefaultState indicates how a feature is enabled by default.
type DefaultState int

const (
    DefaultDisabled DefaultState = iota // false - must be enabled
    DefaultEnabled                      // true - enabled unless disabled
    DefaultEnv                          // Check DOTFILES_FEATURE_* env var
)

// Registry holds all feature definitions.
type Registry struct {
    features map[string]*Definition
    state    map[string]bool // Runtime overrides
    config   *config.Config  // Persisted state
}

// New creates a registry with all built-in features.
func New(cfg *config.Config) *Registry {
    r := &Registry{
        features: make(map[string]*Definition),
        state:    make(map[string]bool),
        config:   cfg,
    }
    r.registerBuiltins()
    return r
}

func (r *Registry) registerBuiltins() {
    // Core
    r.Register(&Definition{
        Name:        "shell",
        Description: "ZSH shell, prompt, and core aliases",
        Category:    CategoryCore,
        Default:     DefaultEnabled,
    })

    // Optional
    r.Register(&Definition{
        Name:         "vault",
        Description:  "Multi-vault secret management (Bitwarden/1Password/pass)",
        Category:     CategoryOptional,
        Default:      DefaultDisabled,
    })

    r.Register(&Definition{
        Name:         "claude_integration",
        Description:  "Claude Code integration and hooks",
        Category:     CategoryOptional,
        Default:      DefaultEnv,
        Dependencies: []string{"workspace_symlink"},
    })

    r.Register(&Definition{
        Name:         "templates",
        Description:  "Machine-specific configuration templates",
        Category:     CategoryOptional,
        Default:      DefaultDisabled,
    })

    // Integrations
    r.Register(&Definition{
        Name:        "modern_cli",
        Description: "Modern CLI tools (eza, bat, ripgrep, fzf, zoxide)",
        Category:    CategoryIntegration,
        Default:     DefaultEnabled,
    })

    // ... more features
}

// IsEnabled checks if a feature is enabled.
// Priority: runtime state > env vars > config file > default
func (r *Registry) IsEnabled(name string) bool {
    def, exists := r.features[name]
    if !exists {
        return false
    }

    // 1. Runtime state (highest priority)
    if enabled, ok := r.state[name]; ok {
        return enabled
    }

    // 2. Environment variable
    if enabled, ok := r.checkEnv(name); ok {
        return enabled
    }

    // 3. Config file
    if enabled, ok := r.config.FeatureEnabled(name); ok {
        return enabled
    }

    // 4. Default
    switch def.Default {
    case DefaultEnabled:
        return true
    case DefaultDisabled:
        return false
    case DefaultEnv:
        return false // If env not set, default to disabled
    }

    return false
}

// Enable enables a feature and its dependencies.
func (r *Registry) Enable(name string) error {
    def, exists := r.features[name]
    if !exists {
        return fmt.Errorf("unknown feature: %s", name)
    }

    // Check for circular dependencies
    if err := r.checkCircular(name, nil); err != nil {
        return err
    }

    // Check for conflicts
    if err := r.checkConflicts(name); err != nil {
        return err
    }

    // Enable dependencies first
    for _, dep := range def.Dependencies {
        if !r.IsEnabled(dep) {
            if err := r.Enable(dep); err != nil {
                return fmt.Errorf("dependency %s: %w", dep, err)
            }
        }
    }

    r.state[name] = true
    return nil
}

// Persist saves feature state to config file.
func (r *Registry) Persist(name string, enabled bool) error {
    return r.config.SetFeature(name, enabled)
}
```

#### 4.2.2 Dependency Resolution

```go
// internal/feature/dependency.go

package feature

import (
    "fmt"
    "strings"
)

// checkCircular detects circular dependencies.
func (r *Registry) checkCircular(name string, visited []string) error {
    // Check if already in path
    for _, v := range visited {
        if v == name {
            return fmt.Errorf("circular dependency: %s",
                strings.Join(append(visited, name), " → "))
        }
    }

    def, exists := r.features[name]
    if !exists {
        return nil
    }

    // Recurse into dependencies
    visited = append(visited, name)
    for _, dep := range def.Dependencies {
        if err := r.checkCircular(dep, visited); err != nil {
            return err
        }
    }

    return nil
}

// checkConflicts ensures no conflicting features are enabled.
func (r *Registry) checkConflicts(name string) error {
    def, exists := r.features[name]
    if !exists {
        return nil
    }

    for _, conflict := range def.Conflicts {
        if r.IsEnabled(conflict) {
            return fmt.Errorf("conflicts with enabled feature: %s", conflict)
        }
    }

    return nil
}

// ResolveDependencies returns all features needed to enable a feature.
func (r *Registry) ResolveDependencies(name string) ([]string, error) {
    var result []string
    seen := make(map[string]bool)

    var resolve func(n string) error
    resolve = func(n string) error {
        if seen[n] {
            return nil
        }
        seen[n] = true

        def, exists := r.features[n]
        if !exists {
            return fmt.Errorf("unknown feature: %s", n)
        }

        // Resolve dependencies first (depth-first)
        for _, dep := range def.Dependencies {
            if err := resolve(dep); err != nil {
                return err
            }
        }

        result = append(result, n)
        return nil
    }

    if err := resolve(name); err != nil {
        return nil, err
    }

    return result, nil
}
```

---

### 4.3 Configuration System

#### 4.3.1 Typed Configuration

```go
// internal/config/config.go

package config

import (
    "encoding/json"
    "os"
    "path/filepath"
    "sync"
)

// Config represents the dotfiles configuration.
type Config struct {
    Version  int             `json:"version"`
    Vault    VaultConfig     `json:"vault"`
    Backup   BackupConfig    `json:"backup"`
    Setup    SetupConfig     `json:"setup"`
    Packages PackagesConfig  `json:"packages"`
    Paths    PathsConfig     `json:"paths"`
    Features map[string]bool `json:"features"`

    // Internal
    path string
    mu   sync.RWMutex
}

type VaultConfig struct {
    Backend    string `json:"backend"`
    AutoSync   bool   `json:"auto_sync"`
    AutoBackup bool   `json:"auto_backup"`
}

type BackupConfig struct {
    Enabled       bool   `json:"enabled"`
    AutoBackup    bool   `json:"auto_backup"`
    RetentionDays int    `json:"retention_days"`
    MaxSnapshots  int    `json:"max_snapshots"`
    Compress      bool   `json:"compress"`
    Location      string `json:"location"`
}

type SetupConfig struct {
    Completed   []string `json:"completed"`
    CurrentTier string   `json:"current_tier"`
}

type PackagesConfig struct {
    Tier            string `json:"tier"`
    AutoUpdate      bool   `json:"auto_update"`
    ParallelInstall bool   `json:"parallel_install"`
}

type PathsConfig struct {
    DotfilesDir     string `json:"dotfiles_dir"`
    ConfigDir       string `json:"config_dir"`
    BackupDir       string `json:"backup_dir"`
    WorkspaceTarget string `json:"workspace_target"`
}

// Load reads configuration from disk.
func Load() (*Config, error) {
    path := configPath()

    // Check if exists
    if _, err := os.Stat(path); os.IsNotExist(err) {
        return createDefault(path)
    }

    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }

    var cfg Config
    if err := json.Unmarshal(data, &cfg); err != nil {
        return nil, err
    }

    cfg.path = path
    return &cfg, nil
}

// Save writes configuration to disk.
func (c *Config) Save() error {
    c.mu.Lock()
    defer c.mu.Unlock()

    data, err := json.MarshalIndent(c, "", "  ")
    if err != nil {
        return err
    }

    return os.WriteFile(c.path, data, 0644)
}

// FeatureEnabled returns whether a feature is enabled in config.
func (c *Config) FeatureEnabled(name string) (bool, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()

    enabled, ok := c.Features[name]
    return enabled, ok
}

// SetFeature updates and persists a feature state.
func (c *Config) SetFeature(name string, enabled bool) error {
    c.mu.Lock()
    if c.Features == nil {
        c.Features = make(map[string]bool)
    }
    c.Features[name] = enabled
    c.mu.Unlock()

    return c.Save()
}

func configPath() string {
    if dir := os.Getenv("XDG_CONFIG_HOME"); dir != "" {
        return filepath.Join(dir, "dotfiles", "config.json")
    }
    home, _ := os.UserHomeDir()
    return filepath.Join(home, ".config", "dotfiles", "config.json")
}

func createDefault(path string) (*Config, error) {
    cfg := &Config{
        Version: 3,
        Vault: VaultConfig{
            AutoBackup: true,
        },
        Backup: BackupConfig{
            Enabled:       true,
            AutoBackup:    true,
            RetentionDays: 30,
            MaxSnapshots:  10,
            Compress:      true,
            Location:      "~/.dotfiles-backups",
        },
        Setup: SetupConfig{
            CurrentTier: "enhanced",
        },
        Packages: PackagesConfig{
            Tier: "enhanced",
        },
        Paths: PathsConfig{
            ConfigDir: "~/.config/dotfiles",
            BackupDir: "~/.dotfiles-backups",
        },
        Features: make(map[string]bool),
        path:     path,
    }

    // Ensure directory exists
    dir := filepath.Dir(path)
    if err := os.MkdirAll(dir, 0755); err != nil {
        return nil, err
    }

    if err := cfg.Save(); err != nil {
        return nil, err
    }

    return cfg, nil
}
```

---

### 4.4 Template Engine

#### 4.4.1 Parser Design

```go
// internal/template/parser.go

package template

import (
    "fmt"
    "regexp"
    "strings"
)

// TokenType identifies template tokens.
type TokenType int

const (
    TokenText TokenType = iota
    TokenVariable       // {{ var }}
    TokenPipeline       // {{ var | filter }}
    TokenIfOpen         // {{#if condition }}
    TokenIfClose        // {{/if}}
    TokenElse           // {{#else}}
    TokenUnlessOpen     // {{#unless condition }}
    TokenUnlessClose    // {{/unless}}
    TokenEachOpen       // {{#each array }}
    TokenEachClose      // {{/each}}
)

// Token represents a parsed template token.
type Token struct {
    Type      TokenType
    Value     string   // For text, variable name, or condition
    Filters   []Filter // For pipelines
    Position  int      // Byte offset in source
}

// Filter represents a pipeline filter.
type Filter struct {
    Name string
    Arg  string
}

// Parser tokenizes template content.
type Parser struct {
    input  string
    pos    int
    tokens []Token
}

// Parse tokenizes the input template.
func Parse(input string) ([]Token, error) {
    p := &Parser{input: input}
    return p.parse()
}

func (p *Parser) parse() ([]Token, error) {
    for p.pos < len(p.input) {
        // Look for {{
        idx := strings.Index(p.input[p.pos:], "{{")
        if idx == -1 {
            // Rest is text
            p.tokens = append(p.tokens, Token{
                Type:     TokenText,
                Value:    p.input[p.pos:],
                Position: p.pos,
            })
            break
        }

        // Text before {{
        if idx > 0 {
            p.tokens = append(p.tokens, Token{
                Type:     TokenText,
                Value:    p.input[p.pos : p.pos+idx],
                Position: p.pos,
            })
        }

        p.pos += idx + 2 // Skip {{

        // Parse tag content
        end := strings.Index(p.input[p.pos:], "}}")
        if end == -1 {
            return nil, fmt.Errorf("unclosed {{ at position %d", p.pos-2)
        }

        content := strings.TrimSpace(p.input[p.pos : p.pos+end])
        p.pos += end + 2 // Skip }}

        token, err := p.parseTag(content)
        if err != nil {
            return nil, err
        }
        p.tokens = append(p.tokens, token)
    }

    return p.tokens, nil
}

func (p *Parser) parseTag(content string) (Token, error) {
    // Block tags
    if strings.HasPrefix(content, "#if ") {
        return Token{Type: TokenIfOpen, Value: strings.TrimPrefix(content, "#if ")}, nil
    }
    if content == "/if" {
        return Token{Type: TokenIfClose}, nil
    }
    if content == "#else" {
        return Token{Type: TokenElse}, nil
    }
    if strings.HasPrefix(content, "#unless ") {
        return Token{Type: TokenUnlessOpen, Value: strings.TrimPrefix(content, "#unless ")}, nil
    }
    if content == "/unless" {
        return Token{Type: TokenUnlessClose}, nil
    }
    if strings.HasPrefix(content, "#each ") {
        return Token{Type: TokenEachOpen, Value: strings.TrimPrefix(content, "#each ")}, nil
    }
    if content == "/each" {
        return Token{Type: TokenEachClose}, nil
    }

    // Pipeline or simple variable
    if strings.Contains(content, "|") {
        return p.parsePipeline(content)
    }

    return Token{Type: TokenVariable, Value: content}, nil
}

func (p *Parser) parsePipeline(content string) (Token, error) {
    parts := strings.Split(content, "|")
    if len(parts) < 2 {
        return Token{}, fmt.Errorf("invalid pipeline: %s", content)
    }

    varName := strings.TrimSpace(parts[0])
    var filters []Filter

    for _, part := range parts[1:] {
        part = strings.TrimSpace(part)

        // Parse filter name and optional argument
        var filter Filter
        if idx := strings.IndexAny(part, " \"'"); idx != -1 {
            filter.Name = part[:idx]
            arg := strings.TrimSpace(part[idx:])
            arg = strings.Trim(arg, "\"'")
            filter.Arg = arg
        } else {
            filter.Name = part
        }

        filters = append(filters, filter)
    }

    return Token{Type: TokenPipeline, Value: varName, Filters: filters}, nil
}
```

#### 4.4.2 Engine Implementation

```go
// internal/template/engine.go

package template

import (
    "bytes"
    "fmt"
    "os"
    "path/filepath"
    "strings"
)

// Engine renders templates with variable substitution.
type Engine struct {
    vars    map[string]string
    arrays  map[string][]map[string]string
    filters map[string]FilterFunc
}

// FilterFunc transforms a value.
type FilterFunc func(value, arg string) string

// New creates a template engine.
func New() *Engine {
    e := &Engine{
        vars:    make(map[string]string),
        arrays:  make(map[string][]map[string]string),
        filters: make(map[string]FilterFunc),
    }
    e.registerBuiltinFilters()
    return e
}

func (e *Engine) registerBuiltinFilters() {
    e.filters["upper"] = func(v, _ string) string { return strings.ToUpper(v) }
    e.filters["lower"] = func(v, _ string) string { return strings.ToLower(v) }
    e.filters["trim"] = func(v, _ string) string { return strings.TrimSpace(v) }
    e.filters["default"] = func(v, arg string) string {
        if v == "" {
            return arg
        }
        return v
    }
    e.filters["quote"] = func(v, _ string) string { return `"` + v + `"` }
    e.filters["basename"] = func(v, _ string) string { return filepath.Base(v) }
    e.filters["dirname"] = func(v, _ string) string { return filepath.Dir(v) }
    e.filters["replace"] = func(v, arg string) string {
        parts := strings.SplitN(arg, ",", 2)
        if len(parts) == 2 {
            return strings.ReplaceAll(v, parts[0], parts[1])
        }
        return v
    }
}

// SetVar sets a template variable.
func (e *Engine) SetVar(name, value string) {
    e.vars[name] = value
}

// SetVars sets multiple variables from a map.
func (e *Engine) SetVars(vars map[string]string) {
    for k, v := range vars {
        e.vars[k] = v
    }
}

// SetArray sets an array for {{#each}} loops.
func (e *Engine) SetArray(name string, items []map[string]string) {
    e.arrays[name] = items
}

// Render processes a template string.
func (e *Engine) Render(content string) (string, error) {
    tokens, err := Parse(content)
    if err != nil {
        return "", err
    }

    return e.evaluate(tokens)
}

// RenderFile processes a template file.
func (e *Engine) RenderFile(path string) (string, error) {
    content, err := os.ReadFile(path)
    if err != nil {
        return "", err
    }
    return e.Render(string(content))
}

func (e *Engine) evaluate(tokens []Token) (string, error) {
    var buf bytes.Buffer

    for i := 0; i < len(tokens); i++ {
        token := tokens[i]

        switch token.Type {
        case TokenText:
            buf.WriteString(token.Value)

        case TokenVariable:
            value := e.vars[token.Value]
            buf.WriteString(value)

        case TokenPipeline:
            value := e.vars[token.Value]
            for _, filter := range token.Filters {
                fn, ok := e.filters[filter.Name]
                if ok {
                    value = fn(value, filter.Arg)
                }
            }
            buf.WriteString(value)

        case TokenIfOpen:
            // Find matching close and evaluate block
            block, closeIdx, err := e.findBlock(tokens[i+1:], TokenIfClose)
            if err != nil {
                return "", err
            }

            if e.evaluateCondition(token.Value) {
                result, err := e.evaluateIfBlock(block, true)
                if err != nil {
                    return "", err
                }
                buf.WriteString(result)
            } else {
                result, err := e.evaluateIfBlock(block, false)
                if err != nil {
                    return "", err
                }
                buf.WriteString(result)
            }

            i += closeIdx + 1

        case TokenEachOpen:
            block, closeIdx, err := e.findBlock(tokens[i+1:], TokenEachClose)
            if err != nil {
                return "", err
            }

            arrayName := token.Value
            items := e.arrays[arrayName]

            for _, item := range items {
                // Create scoped engine with item vars
                scoped := e.clone()
                for k, v := range item {
                    scoped.vars[k] = v
                }

                result, err := scoped.evaluate(block)
                if err != nil {
                    return "", err
                }
                buf.WriteString(result)
            }

            i += closeIdx + 1
        }
    }

    return buf.String(), nil
}

func (e *Engine) evaluateCondition(condition string) bool {
    condition = strings.TrimSpace(condition)

    // Handle: var == "value"
    if strings.Contains(condition, "==") {
        parts := strings.SplitN(condition, "==", 2)
        varName := strings.TrimSpace(parts[0])
        expected := strings.TrimSpace(parts[1])
        expected = strings.Trim(expected, "\"'")
        return e.vars[varName] == expected
    }

    // Handle: var != "value"
    if strings.Contains(condition, "!=") {
        parts := strings.SplitN(condition, "!=", 2)
        varName := strings.TrimSpace(parts[0])
        expected := strings.TrimSpace(parts[1])
        expected = strings.Trim(expected, "\"'")
        return e.vars[varName] != expected
    }

    // Truthy check
    value := e.vars[condition]
    return value != "" && value != "false" && value != "0"
}

func (e *Engine) findBlock(tokens []Token, closeType TokenType) ([]Token, int, error) {
    depth := 1
    for i, token := range tokens {
        switch token.Type {
        case TokenIfOpen, TokenUnlessOpen, TokenEachOpen:
            depth++
        case TokenIfClose, TokenUnlessClose, TokenEachClose:
            depth--
            if depth == 0 && token.Type == closeType {
                return tokens[:i], i, nil
            }
        }
    }
    return nil, 0, fmt.Errorf("unclosed block")
}

func (e *Engine) evaluateIfBlock(tokens []Token, condition bool) (string, error) {
    // Find {{#else}} at depth 0
    var ifPart, elsePart []Token
    depth := 0
    elseIdx := -1

    for i, token := range tokens {
        switch token.Type {
        case TokenIfOpen, TokenUnlessOpen, TokenEachOpen:
            depth++
        case TokenIfClose, TokenUnlessClose, TokenEachClose:
            depth--
        case TokenElse:
            if depth == 0 {
                elseIdx = i
            }
        }
    }

    if elseIdx >= 0 {
        ifPart = tokens[:elseIdx]
        elsePart = tokens[elseIdx+1:]
    } else {
        ifPart = tokens
    }

    if condition {
        return e.evaluate(ifPart)
    }
    return e.evaluate(elsePart)
}

func (e *Engine) clone() *Engine {
    clone := &Engine{
        vars:    make(map[string]string),
        arrays:  e.arrays, // Share arrays
        filters: e.filters, // Share filters
    }
    for k, v := range e.vars {
        clone.vars[k] = v
    }
    return clone
}
```

---

### 4.5 CLI Framework

#### 4.5.1 Root Command

```go
// cmd/dotfiles/main.go

package main

import (
    "os"

    "github.com/user/dotfiles/internal/cli"
)

func main() {
    if err := cli.Execute(); err != nil {
        os.Exit(1)
    }
}
```

```go
// internal/cli/root.go

package cli

import (
    "github.com/spf13/cobra"

    "github.com/user/dotfiles/internal/config"
    "github.com/user/dotfiles/internal/feature"
)

var (
    cfg      *config.Config
    registry *feature.Registry
    verbose  bool
    quiet    bool
)

var rootCmd = &cobra.Command{
    Use:   "dotfiles",
    Short: "Dotfiles management system",
    Long: `A comprehensive dotfiles management system with features including:
  - Feature-based module system
  - Multi-backend secret management (vault)
  - Machine-specific templating
  - Cross-machine synchronization`,
    PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
        var err error
        cfg, err = config.Load()
        if err != nil {
            return err
        }
        registry = feature.New(cfg)
        return nil
    },
}

func init() {
    rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "verbose output")
    rootCmd.PersistentFlags().BoolVarP(&quiet, "quiet", "q", false, "suppress output")

    // Register all subcommands
    rootCmd.AddCommand(featuresCmd)
    rootCmd.AddCommand(configCmd)
    rootCmd.AddCommand(vaultCmd)
    rootCmd.AddCommand(templateCmd)
    rootCmd.AddCommand(doctorCmd)
    rootCmd.AddCommand(setupCmd)
    rootCmd.AddCommand(syncCmd)
    rootCmd.AddCommand(backupCmd)
    rootCmd.AddCommand(driftCmd)
    rootCmd.AddCommand(hookCmd)
    rootCmd.AddCommand(encryptCmd)
    rootCmd.AddCommand(packagesCmd)
    rootCmd.AddCommand(migrateCmd)
    rootCmd.AddCommand(lintCmd)
    rootCmd.AddCommand(diffCmd)
    rootCmd.AddCommand(metricsCmd)
    rootCmd.AddCommand(uninstallCmd)
}

func Execute() error {
    return rootCmd.Execute()
}
```

#### 4.5.2 Features Command

```go
// internal/cli/features.go

package cli

import (
    "encoding/json"
    "fmt"

    "github.com/spf13/cobra"
)

var featuresCmd = &cobra.Command{
    Use:   "features",
    Short: "Manage feature registry",
    Long:  "Enable, disable, and query features in the dotfiles system.",
    Run: func(cmd *cobra.Command, args []string) {
        listFeatures(false)
    },
}

var featuresListCmd = &cobra.Command{
    Use:   "list [category]",
    Short: "List features",
    Run: func(cmd *cobra.Command, args []string) {
        jsonOutput, _ := cmd.Flags().GetBool("json")
        all, _ := cmd.Flags().GetBool("all")

        if jsonOutput {
            listFeaturesJSON()
        } else {
            listFeatures(all)
        }
    },
}

var featuresEnableCmd = &cobra.Command{
    Use:   "enable <feature>",
    Short: "Enable a feature",
    Args:  cobra.ExactArgs(1),
    RunE: func(cmd *cobra.Command, args []string) error {
        name := args[0]
        persist, _ := cmd.Flags().GetBool("persist")

        if err := registry.Enable(name); err != nil {
            return err
        }

        if persist {
            if err := registry.Persist(name, true); err != nil {
                return err
            }
            fmt.Printf("✓ Feature '%s' enabled and saved to config\n", name)
        } else {
            fmt.Printf("✓ Feature '%s' enabled (runtime only)\n", name)
            fmt.Println("  Use --persist to save to config file")
        }

        return nil
    },
}

var featuresDisableCmd = &cobra.Command{
    Use:   "disable <feature>",
    Short: "Disable a feature",
    Args:  cobra.ExactArgs(1),
    RunE: func(cmd *cobra.Command, args []string) error {
        name := args[0]
        persist, _ := cmd.Flags().GetBool("persist")

        if err := registry.Disable(name); err != nil {
            return err
        }

        if persist {
            if err := registry.Persist(name, false); err != nil {
                return err
            }
            fmt.Printf("✓ Feature '%s' disabled and saved to config\n", name)
        } else {
            fmt.Printf("✓ Feature '%s' disabled (runtime only)\n", name)
        }

        return nil
    },
}

var featuresPresetCmd = &cobra.Command{
    Use:   "preset <name>",
    Short: "Enable a preset (group of features)",
    Args:  cobra.ExactArgs(1),
    RunE: func(cmd *cobra.Command, args []string) error {
        name := args[0]
        persist, _ := cmd.Flags().GetBool("persist")

        features, err := registry.ApplyPreset(name)
        if err != nil {
            return err
        }

        if persist {
            for _, f := range features {
                registry.Persist(f, true)
            }
            fmt.Printf("✓ Preset '%s' enabled and saved\n", name)
        } else {
            fmt.Printf("✓ Preset '%s' enabled (runtime only)\n", name)
        }

        fmt.Println("\nEnabled features:")
        for _, f := range features {
            fmt.Printf("  ● %s\n", f)
        }

        return nil
    },
}

var featuresCheckCmd = &cobra.Command{
    Use:   "check <feature>",
    Short: "Check if a feature is enabled (for scripts)",
    Args:  cobra.ExactArgs(1),
    Run: func(cmd *cobra.Command, args []string) {
        if registry.IsEnabled(args[0]) {
            fmt.Printf("✓ Feature '%s' is enabled\n", args[0])
        } else {
            fmt.Printf("○ Feature '%s' is disabled\n", args[0])
            os.Exit(1)
        }
    },
}

func init() {
    featuresListCmd.Flags().Bool("json", false, "output as JSON")
    featuresListCmd.Flags().BoolP("all", "a", false, "show dependencies")

    featuresEnableCmd.Flags().BoolP("persist", "p", false, "save to config")
    featuresDisableCmd.Flags().BoolP("persist", "p", false, "save to config")
    featuresPresetCmd.Flags().BoolP("persist", "p", false, "save to config")
    featuresPresetCmd.Flags().Bool("list", false, "list available presets")

    featuresCmd.AddCommand(featuresListCmd)
    featuresCmd.AddCommand(featuresEnableCmd)
    featuresCmd.AddCommand(featuresDisableCmd)
    featuresCmd.AddCommand(featuresPresetCmd)
    featuresCmd.AddCommand(featuresCheckCmd)
}

func listFeatures(showAll bool) {
    categories := []struct {
        cat   feature.Category
        title string
    }{
        {feature.CategoryCore, "Core (Always Enabled)"},
        {feature.CategoryOptional, "Optional Features"},
        {feature.CategoryIntegration, "Integrations"},
    }

    fmt.Println("Feature Registry")
    fmt.Println("═══════════════════════════════════════════════════════════════")

    for _, c := range categories {
        fmt.Printf("\n\033[1;36m%s\033[0m\n", c.title)
        fmt.Println("───────────────────────────────────────────────────────────────")

        for _, def := range registry.List(c.cat) {
            enabled := registry.IsEnabled(def.Name)

            var icon, color string
            if enabled {
                icon = "●"
                color = "\033[0;32m"
            } else {
                icon = "○"
                color = "\033[2m"
            }

            fmt.Printf("  %s%s\033[0m %-20s \033[2m%s\033[0m\n",
                color, icon, def.Name, def.Description)

            if showAll && len(def.Dependencies) > 0 {
                fmt.Printf("    \033[2m└─ requires: %s\033[0m\n",
                    strings.Join(def.Dependencies, ", "))
            }
        }
    }

    fmt.Println()
    fmt.Println("\033[2mLegend: \033[0;32m●\033[0m enabled  \033[2m○ disabled\033[0m")
}

func listFeaturesJSON() {
    output := make(map[string]interface{})

    for _, def := range registry.ListAll() {
        output[def.Name] = map[string]interface{}{
            "enabled":      registry.IsEnabled(def.Name),
            "category":     def.Category,
            "description":  def.Description,
            "dependencies": def.Dependencies,
        }
    }

    data, _ := json.MarshalIndent(output, "", "  ")
    fmt.Println(string(data))
}
```

---

## 5. Shell Integration

### 5.1 Hybrid Operation

During migration, shell scripts need to call the Go binary:

```zsh
# zsh/zsh.d/40-aliases.zsh

# Detect if Go binary exists
if [[ -x "$DOTFILES_DIR/bin/dotfiles-go" ]]; then
    # Use Go binary
    dotfiles() {
        "$DOTFILES_DIR/bin/dotfiles-go" "$@"
    }
else
    # Fall back to shell implementation
    dotfiles() {
        # ... existing shell dispatcher
    }
fi
```

### 5.2 Feature Checks from Shell

```zsh
# Check if feature is enabled (using Go binary)
feature_enabled() {
    "$DOTFILES_DIR/bin/dotfiles-go" features check "$1" >/dev/null 2>&1
}

# Usage in shell modules
if feature_enabled "vault"; then
    # Load vault functions
fi
```

### 5.3 Shell Hook Generation

The Go binary can generate shell functions:

```go
// internal/shell/zsh.go

package shell

func GenerateZshInit() string {
    return `
# Generated by dotfiles
# Source this file: eval "$(dotfiles shell-init zsh)"

dotfiles() {
    command dotfiles "$@"
}

# Feature check function
feature_enabled() {
    command dotfiles features check "$1" 2>/dev/null
}

# Completion
_dotfiles() {
    local -a commands
    commands=(
        'features:Manage features'
        'config:Configuration'
        'vault:Secret management'
        'template:Template system'
        'doctor:Health checks'
        'setup:Initial setup'
        'sync:Synchronization'
    )
    _describe 'command' commands
}
compdef _dotfiles dotfiles
`
}
```

---

## 6. Testing Strategy

### 6.1 Unit Tests

```go
// internal/feature/registry_test.go

package feature

import (
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestRegistry_IsEnabled(t *testing.T) {
    tests := []struct {
        name     string
        feature  string
        setup    func(*Registry)
        expected bool
    }{
        {
            name:     "core feature always enabled",
            feature:  "shell",
            expected: true,
        },
        {
            name:     "disabled by default",
            feature:  "vault",
            expected: false,
        },
        {
            name:    "enabled at runtime",
            feature: "vault",
            setup: func(r *Registry) {
                r.Enable("vault")
            },
            expected: true,
        },
        {
            name:    "enabled in config",
            feature: "vault",
            setup: func(r *Registry) {
                r.config.SetFeature("vault", true)
            },
            expected: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            cfg := config.NewMock()
            r := New(cfg)

            if tt.setup != nil {
                tt.setup(r)
            }

            assert.Equal(t, tt.expected, r.IsEnabled(tt.feature))
        })
    }
}

func TestRegistry_CircularDependency(t *testing.T) {
    cfg := config.NewMock()
    r := New(cfg)

    // Register features with circular dependency
    r.Register(&Definition{
        Name:         "a",
        Dependencies: []string{"b"},
    })
    r.Register(&Definition{
        Name:         "b",
        Dependencies: []string{"a"},
    })

    err := r.Enable("a")
    require.Error(t, err)
    assert.Contains(t, err.Error(), "circular")
}
```

### 6.2 Integration Tests

```go
// internal/cli/features_test.go

package cli

import (
    "bytes"
    "testing"

    "github.com/stretchr/testify/assert"
)

func TestFeaturesCommand(t *testing.T) {
    tests := []struct {
        name     string
        args     []string
        wantOut  string
        wantErr  bool
    }{
        {
            name:    "list features",
            args:    []string{"features", "list"},
            wantOut: "Feature Registry",
        },
        {
            name:    "enable feature",
            args:    []string{"features", "enable", "vault"},
            wantOut: "enabled",
        },
        {
            name:    "check enabled",
            args:    []string{"features", "check", "shell"},
            wantOut: "enabled",
        },
        {
            name:    "check disabled",
            args:    []string{"features", "check", "vault"},
            wantErr: true, // Exit code 1
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            cmd := rootCmd
            buf := new(bytes.Buffer)
            cmd.SetOut(buf)
            cmd.SetArgs(tt.args)

            err := cmd.Execute()

            if tt.wantErr {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
            }

            if tt.wantOut != "" {
                assert.Contains(t, buf.String(), tt.wantOut)
            }
        })
    }
}
```

### 6.3 Vault Backend Mocking

```go
// pkg/vault/mock/mock.go

package mock

import (
    "context"

    "github.com/user/dotfiles/pkg/vault"
)

// Backend is a mock vault backend for testing.
type Backend struct {
    items map[string]*vault.Item
}

func New() *Backend {
    return &Backend{items: make(map[string]*vault.Item)}
}

func (b *Backend) Name() string { return "mock" }

func (b *Backend) Init(ctx context.Context) error { return nil }
func (b *Backend) Close() error { return nil }

func (b *Backend) IsAuthenticated(ctx context.Context) bool { return true }
func (b *Backend) Authenticate(ctx context.Context) (vault.Session, error) {
    return &mockSession{}, nil
}

func (b *Backend) GetNotes(ctx context.Context, name string, _ vault.Session) (string, error) {
    if item, ok := b.items[name]; ok {
        return item.Notes, nil
    }
    return "", nil
}

func (b *Backend) CreateItem(ctx context.Context, name, content string, _ vault.Session) error {
    b.items[name] = &vault.Item{Name: name, Notes: content}
    return nil
}

// ... other methods

type mockSession struct{}

func (s *mockSession) Token() string                     { return "mock-token" }
func (s *mockSession) IsValid(ctx context.Context) bool  { return true }
func (s *mockSession) Refresh(ctx context.Context) error { return nil }
```

---

## 7. Build & Distribution

### 7.1 Makefile

```makefile
# Makefile

BINARY := dotfiles
VERSION := $(shell git describe --tags --always --dirty)
LDFLAGS := -ldflags "-s -w -X main.version=$(VERSION)"

.PHONY: build test lint clean install

build:
	go build $(LDFLAGS) -o bin/$(BINARY) ./cmd/dotfiles

build-all:
	GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o bin/$(BINARY)-darwin-amd64 ./cmd/dotfiles
	GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o bin/$(BINARY)-darwin-arm64 ./cmd/dotfiles
	GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o bin/$(BINARY)-linux-amd64 ./cmd/dotfiles
	GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o bin/$(BINARY)-linux-arm64 ./cmd/dotfiles

test:
	go test -v -race -cover ./...

test-coverage:
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

lint:
	golangci-lint run

clean:
	rm -rf bin/ coverage.out coverage.html

install: build
	cp bin/$(BINARY) $(DOTFILES_DIR)/bin/dotfiles-go
```

### 7.2 GoReleaser Configuration

```yaml
# .goreleaser.yaml

project_name: dotfiles

builds:
  - id: dotfiles
    binary: dotfiles
    main: ./cmd/dotfiles
    env:
      - CGO_ENABLED=0
    goos:
      - darwin
      - linux
    goarch:
      - amd64
      - arm64
    ldflags:
      - -s -w
      - -X main.version={{.Version}}
      - -X main.commit={{.Commit}}
      - -X main.date={{.Date}}

archives:
  - format: tar.gz
    name_template: "{{ .ProjectName }}_{{ .Version }}_{{ .Os }}_{{ .Arch }}"
    files:
      - README.md
      - LICENSE

checksum:
  name_template: 'checksums.txt'

changelog:
  sort: asc
  filters:
    exclude:
      - '^docs:'
      - '^test:'

brews:
  - name: dotfiles
    repository:
      owner: user
      name: homebrew-tap
    homepage: https://github.com/user/dotfiles
    description: Dotfiles management system
    install: |
      bin.install "dotfiles"
```

---

## 8. Migration Phases

### Phase 1: Foundation (Weeks 1-2)
- [ ] Set up Go module structure
- [ ] Implement `pkg/vault` with pass backend
- [ ] Implement `internal/config` (JSON read/write)
- [ ] Basic CLI skeleton with cobra
- [ ] `dotfiles version` command

### Phase 2: Core Features (Weeks 3-4)
- [ ] Implement `internal/feature` (registry, dependencies)
- [ ] `dotfiles features` command (full parity)
- [ ] `dotfiles config` command
- [ ] Shell integration (`dotfiles shell-init`)

### Phase 3: Vault Integration (Weeks 5-6)
- [ ] Bitwarden backend
- [ ] 1Password backend
- [ ] `dotfiles vault` command (full parity)
- [ ] Session management

### Phase 4: Template System (Weeks 7-8)
- [ ] Template parser
- [ ] Variable resolution
- [ ] Conditionals and loops
- [ ] Pipeline filters
- [ ] `dotfiles template` command

### Phase 5: Remaining Commands (Weeks 9-10)
- [ ] `dotfiles doctor`
- [ ] `dotfiles setup`
- [ ] `dotfiles sync`
- [ ] `dotfiles backup`
- [ ] `dotfiles drift`
- [ ] Remaining commands

### Phase 6: Polish & Migration (Weeks 11-12)
- [ ] Shell-to-Go migration script
- [ ] Documentation updates
- [ ] Performance benchmarks
- [ ] Release automation

---

## 9. Backwards Compatibility

### 9.1 Config File Compatibility

The Go implementation reads the same `~/.config/dotfiles/config.json`:

```go
// Ensure we can read configs written by shell
func TestConfigCompatibility(t *testing.T) {
    // Write config with shell format
    shellConfig := `{
      "version": 3,
      "features": {
        "vault": true,
        "templates": false
      }
    }`

    // Read with Go
    cfg, err := config.LoadFromString(shellConfig)
    require.NoError(t, err)

    assert.True(t, cfg.Features["vault"])
    assert.False(t, cfg.Features["templates"])
}
```

### 9.2 CLI Compatibility

All commands maintain identical interfaces:

| Shell Command | Go Command | Status |
|---------------|------------|--------|
| `dotfiles features list` | `dotfiles features list` | Same |
| `dotfiles features enable vault -p` | `dotfiles features enable vault -p` | Same |
| `dotfiles vault push` | `dotfiles vault push` | Same |
| `dotfiles template render` | `dotfiles template render` | Same |

### 9.3 Gradual Rollout

```zsh
# Users can switch between implementations
export DOTFILES_USE_GO=1  # Use Go binary
export DOTFILES_USE_GO=0  # Use shell (default during migration)
```

---

## 10. Risk Analysis

### 10.1 Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Template engine edge cases | High | Medium | Extensive test suite from existing templates |
| Vault session handling differences | Medium | Medium | Integration tests with real backends |
| Shell integration breaks | High | Low | Maintain shell fallback |
| Performance regression | Low | Low | Benchmark suite |
| Cross-platform issues | Medium | Medium | CI on macOS + Linux |

### 10.2 Rollback Plan

1. Keep shell implementation intact during migration
2. Feature flag (`DOTFILES_USE_GO`) controls which to use
3. If issues found, disable Go binary via flag
4. Shell implementation remains as fallback

---

## Appendix A: Dependency Graph

```
cmd/dotfiles
├── internal/cli
│   ├── internal/feature
│   ├── internal/config
│   ├── internal/template
│   ├── internal/doctor
│   ├── internal/shell
│   └── pkg/vault (independent)
│
└── pkg/vault
    └── pkg/vault/backends/*
```

## Appendix B: Go Dependencies

```go
// go.mod

module github.com/user/dotfiles

go 1.21

require (
    github.com/spf13/cobra v1.8.0      // CLI framework
    github.com/spf13/viper v1.18.0     // Config (optional)
    github.com/stretchr/testify v1.8.4 // Testing
    github.com/fatih/color v1.16.0     // Terminal colors
)
```

---

*Document Version: 1.0*
*Last Updated: 2025-12-07*
