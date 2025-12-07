# Vaultmux Architecture Document

> **Module:** `github.com/blackwell-systems/vaultmux`
> **Status:** Draft
> **Author:** Claude
> **Created:** 2025-12-07

---

## Executive Summary

Vaultmux is a Go library that provides a unified interface for interacting with multiple secret management backends. It abstracts away the differences between Bitwarden, 1Password, and pass (the standard Unix password manager), allowing applications to work with any supported backend through a single API.

**Key Features:**
- Unified `Backend` interface for all secret managers
- Session management with caching and refresh
- Context-aware operations with timeout support
- Location/folder management across backends
- Zero external dependencies (only stdlib + backend CLIs)

---

## Table of Contents

1. [Design Goals](#1-design-goals)
2. [Architecture Overview](#2-architecture-overview)
3. [Core Interfaces](#3-core-interfaces)
4. [Backend Implementations](#4-backend-implementations)
5. [Session Management](#5-session-management)
6. [Error Handling](#6-error-handling)
7. [Testing Strategy](#7-testing-strategy)
8. [Usage Examples](#8-usage-examples)
9. [Backend Comparison](#9-backend-comparison)
10. [Future Backends](#10-future-backends)

---

## 1. Design Goals

### 1.1 Primary Goals

| Goal | Description |
|------|-------------|
| **Unified API** | Single interface works with any backend |
| **Minimal Dependencies** | Only Go stdlib; backends use their own CLIs |
| **Context Support** | All operations accept `context.Context` for cancellation/timeout |
| **Session Caching** | Avoid repeated authentication prompts |
| **Testability** | Mock backend for unit testing |

### 1.2 Non-Goals

| Non-Goal | Rationale |
|----------|-----------|
| GUI/TUI | Library only; consumers build their own UI |
| Backend installation | Users install `bw`, `op`, `pass` themselves |
| Encryption | Delegated to backend implementations |
| Key generation | Out of scope; use backend tools |

### 1.3 Design Principles

1. **Backend CLIs are the source of truth** - We shell out to `bw`, `op`, `pass` rather than reimplementing their protocols
2. **Fail fast, fail clearly** - Explicit errors over silent failures
3. **No global state** - All state lives in Backend/Session structs
4. **Functional options** - Extensible configuration without breaking changes

---

## 2. Architecture Overview

### 2.1 Package Structure

```
github.com/blackwell-systems/vaultmux/
├── vaultmux.go           # Core types: Backend, Session, Item, errors
├── factory.go            # New() factory, backend registration
├── session.go            # Session interface, caching logic
├── options.go            # Functional options for configuration
├── errors.go             # Typed errors: ErrNotFound, ErrAuth, etc.
│
├── backends/
│   ├── bitwarden/
│   │   ├── bitwarden.go  # Bitwarden CLI backend
│   │   └── session.go    # BW session management
│   │
│   ├── onepassword/
│   │   ├── onepassword.go # 1Password CLI backend
│   │   └── session.go     # OP session management
│   │
│   └── pass/
│       └── pass.go        # pass (GPG-based) backend
│
├── mock/
│   └── mock.go            # In-memory mock for testing
│
├── internal/
│   └── exec/
│       └── exec.go        # Command execution helpers
│
├── go.mod
├── go.sum
├── README.md
├── ARCHITECTURE.md        # This document
└── vaultmux_test.go
```

### 2.2 Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Consumer Application                         │
│                                                                      │
│   import "github.com/blackwell-systems/vaultmux"                    │
│                                                                      │
│   backend, _ := vaultmux.New(vaultmux.Config{...})                  │
│   session, _ := backend.Authenticate(ctx)                           │
│   notes, _ := backend.GetNotes(ctx, "SSH-Config", session)          │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          vaultmux.Backend                            │
│                           (interface)                                │
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │
│  │ Authenticate│  │  GetNotes   │  │ CreateItem  │  │  Sync     │  │
│  │ GetItem     │  │  ItemExists │  │ UpdateItem  │  │  Close    │  │
│  │ ListItems   │  │  DeleteItem │  │ ListLocations│ │  Init     │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └───────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                  │
            ┌─────────────────────┼─────────────────────┐
            ▼                     ▼                     ▼
┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐
│     Bitwarden     │  │    1Password      │  │       pass        │
│                   │  │                   │  │                   │
│  Shells out to:   │  │  Shells out to:   │  │  Shells out to:   │
│  $ bw get item    │  │  $ op item get    │  │  $ pass show      │
│  $ bw create      │  │  $ op item create │  │  $ pass insert    │
│  $ bw sync        │  │  $ op signin      │  │  $ pass rm        │
└───────────────────┘  └───────────────────┘  └───────────────────┘
         │                      │                      │
         ▼                      ▼                      ▼
┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐
│   Bitwarden CLI   │  │  1Password CLI    │  │    pass + GPG     │
│       (bw)        │  │       (op)        │  │                   │
└───────────────────┘  └───────────────────┘  └───────────────────┘
```

### 2.3 Data Flow

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  Config  │────▶│ Factory  │────▶│ Backend  │────▶│ Session  │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
                      │                 │                │
                      │                 │                │
                      ▼                 ▼                ▼
               ┌──────────┐     ┌──────────────┐  ┌────────────┐
               │ Backend  │     │ CLI Command  │  │ Cached     │
               │ Selection│     │ Execution    │  │ Token      │
               └──────────┘     └──────────────┘  └────────────┘
```

---

## 3. Core Interfaces

### 3.1 Backend Interface

```go
// Backend represents a secret storage backend.
type Backend interface {
    // Metadata
    Name() string

    // Lifecycle
    Init(ctx context.Context) error
    Close() error

    // Authentication
    IsAuthenticated(ctx context.Context) bool
    Authenticate(ctx context.Context) (Session, error)

    // Sync (pull latest from server)
    Sync(ctx context.Context, session Session) error

    // Item Operations (CRUD)
    GetItem(ctx context.Context, name string, session Session) (*Item, error)
    GetNotes(ctx context.Context, name string, session Session) (string, error)
    ItemExists(ctx context.Context, name string, session Session) (bool, error)
    ListItems(ctx context.Context, session Session) ([]*Item, error)

    // Mutations
    CreateItem(ctx context.Context, name, content string, session Session) error
    UpdateItem(ctx context.Context, name, content string, session Session) error
    DeleteItem(ctx context.Context, name string, session Session) error

    // Location Management (folders/vaults)
    LocationManager
}

// LocationManager handles organizational units.
type LocationManager interface {
    ListLocations(ctx context.Context, session Session) ([]string, error)
    LocationExists(ctx context.Context, name string, session Session) (bool, error)
    CreateLocation(ctx context.Context, name string, session Session) error
    ListItemsInLocation(ctx context.Context, locType, locValue string, session Session) ([]*Item, error)
}
```

### 3.2 Session Interface

```go
// Session represents an authenticated session.
type Session interface {
    // Token returns the session token (empty for pass).
    Token() string

    // IsValid checks if the session is still valid.
    IsValid(ctx context.Context) bool

    // Refresh attempts to refresh an expired session.
    Refresh(ctx context.Context) error

    // ExpiresAt returns when the session expires (zero for non-expiring).
    ExpiresAt() time.Time
}
```

### 3.3 Item Type

```go
// Item represents a vault item.
type Item struct {
    ID       string            `json:"id"`
    Name     string            `json:"name"`
    Type     ItemType          `json:"type"`
    Notes    string            `json:"notes,omitempty"`
    Fields   map[string]string `json:"fields,omitempty"`
    Location string            `json:"location,omitempty"` // Folder/vault
    Created  time.Time         `json:"created,omitempty"`
    Modified time.Time         `json:"modified,omitempty"`
}

// ItemType indicates the type of vault item.
type ItemType int

const (
    ItemTypeSecureNote ItemType = iota
    ItemTypeLogin
    ItemTypeSSHKey
    ItemTypeIdentity
    ItemTypeCard
)
```

### 3.4 Configuration

```go
// Config holds backend configuration.
type Config struct {
    // Backend type: "bitwarden", "1password", "pass"
    Backend BackendType

    // Pass-specific
    StorePath string // Default: ~/.password-store
    Prefix    string // Default: "dotfiles"

    // Session management
    SessionFile  string        // Where to cache session token
    SessionTTL   time.Duration // How long to cache (default: 30m)

    // Backend-specific options
    Options map[string]string
}

// BackendType identifies a vault backend.
type BackendType string

const (
    BackendBitwarden   BackendType = "bitwarden"
    BackendOnePassword BackendType = "1password"
    BackendPass        BackendType = "pass"
)
```

---

## 4. Backend Implementations

### 4.1 Bitwarden Backend

**CLI:** `bw` (Bitwarden CLI)

**Authentication Flow:**
```
1. Check bw status → "locked" or "unauthenticated"
2. If unauthenticated: prompt user to run `bw login`
3. If locked: run `bw unlock --raw` → returns session token
4. Cache session token to file (chmod 0600)
5. Pass --session flag to all subsequent commands
```

**Key Commands:**
```bash
bw status                           # Check login/lock status
bw unlock --raw                     # Get session token
bw sync --session $TOKEN            # Sync vault
bw get item "name" --session $TOKEN # Get item as JSON
bw create item $JSON --session $TOKEN
bw edit item $ID $JSON --session $TOKEN
bw delete item $ID --session $TOKEN
```

**Folder Mapping:**
- `ListLocations` → `bw list folders`
- `CreateLocation` → `bw create folder`
- Items have `folderId` field

### 4.2 1Password Backend

**CLI:** `op` (1Password CLI v2)

**Authentication Flow:**
```
1. Check op account list → returns accounts
2. Run op signin → interactive auth, returns session token
3. Session token valid for 30 minutes
4. Pass token via OP_SESSION_* env var or --session flag
```

**Key Commands:**
```bash
op account list                     # List accounts
op signin                           # Interactive sign-in
op item get "name" --format json    # Get item
op item create --category=SecureNote --title="name" notes="content"
op item edit "name" notes="content"
op item delete "name"
op vault list                       # List vaults (locations)
```

**Vault Mapping:**
- `ListLocations` → `op vault list`
- Items have `vault` field
- Can specify `--vault` on operations

### 4.3 Pass Backend

**CLI:** `pass` + `gpg`

**Authentication Flow:**
```
1. Check if ~/.password-store exists
2. GPG agent handles decryption (may prompt for passphrase)
3. No session token - each operation may trigger GPG prompt
4. GPG agent caches passphrase (configurable timeout)
```

**Key Commands:**
```bash
pass ls                             # List all entries
pass show "prefix/name"             # Decrypt and show
pass insert -m "prefix/name"        # Create (multiline)
pass insert -m -f "prefix/name"     # Update (force overwrite)
pass rm -f "prefix/name"            # Delete
pass git pull / push                # Sync (if git-enabled)
```

**Directory Mapping:**
- `ListLocations` → list top-level directories in store
- `CreateLocation` → `mkdir` in store
- Items stored as: `~/.password-store/<prefix>/<name>.gpg`

---

## 5. Session Management

### 5.1 Session Caching

```go
// SessionCache handles session persistence.
type SessionCache struct {
    path string
    ttl  time.Duration
}

// File format (JSON):
// {
//   "token": "...",
//   "created": "2025-12-07T10:00:00Z",
//   "expires": "2025-12-07T10:30:00Z",
//   "backend": "bitwarden"
// }

func (c *SessionCache) Load() (*CachedSession, error)
func (c *SessionCache) Save(token string, ttl time.Duration) error
func (c *SessionCache) Clear() error
```

### 5.2 Session Lifecycle

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   New()     │────▶│   Init()    │────▶│Authenticate │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                          ┌────────────────────┤
                          ▼                    ▼
                   ┌─────────────┐     ┌─────────────┐
                   │ Load cached │     │ Interactive │
                   │   session   │     │    auth     │
                   └─────────────┘     └─────────────┘
                          │                    │
                          ▼                    ▼
                   ┌─────────────┐     ┌─────────────┐
                   │  Validate   │     │   Cache     │
                   │   token     │     │   token     │
                   └─────────────┘     └─────────────┘
                          │                    │
                          └─────────┬──────────┘
                                    ▼
                             ┌─────────────┐
                             │   Return    │
                             │   Session   │
                             └─────────────┘
```

### 5.3 Auto-Refresh

```go
// AutoRefreshSession wraps a session with automatic refresh.
type AutoRefreshSession struct {
    inner   Session
    backend Backend
    mu      sync.Mutex
}

func (s *AutoRefreshSession) Token() string {
    s.mu.Lock()
    defer s.mu.Unlock()

    if !s.inner.IsValid(context.Background()) {
        // Attempt refresh
        if err := s.inner.Refresh(context.Background()); err != nil {
            // Re-authenticate
            newSession, _ := s.backend.Authenticate(context.Background())
            s.inner = newSession
        }
    }
    return s.inner.Token()
}
```

---

## 6. Error Handling

### 6.1 Error Types

```go
// errors.go

package vaultmux

import "errors"

var (
    // ErrNotFound indicates the item doesn't exist.
    ErrNotFound = errors.New("item not found")

    // ErrAlreadyExists indicates the item already exists.
    ErrAlreadyExists = errors.New("item already exists")

    // ErrNotAuthenticated indicates no valid session.
    ErrNotAuthenticated = errors.New("not authenticated")

    // ErrSessionExpired indicates the session has expired.
    ErrSessionExpired = errors.New("session expired")

    // ErrBackendNotInstalled indicates the CLI tool is missing.
    ErrBackendNotInstalled = errors.New("backend CLI not installed")

    // ErrBackendLocked indicates the vault is locked.
    ErrBackendLocked = errors.New("vault is locked")

    // ErrPermissionDenied indicates insufficient permissions.
    ErrPermissionDenied = errors.New("permission denied")
)

// BackendError wraps errors with backend context.
type BackendError struct {
    Backend string
    Op      string // Operation: "get", "create", "delete", etc.
    Item    string // Item name (if applicable)
    Err     error
}

func (e *BackendError) Error() string {
    if e.Item != "" {
        return fmt.Sprintf("%s: %s %q: %v", e.Backend, e.Op, e.Item, e.Err)
    }
    return fmt.Sprintf("%s: %s: %v", e.Backend, e.Op, e.Err)
}

func (e *BackendError) Unwrap() error {
    return e.Err
}
```

### 6.2 Error Checking

```go
// Usage
notes, err := backend.GetNotes(ctx, "SSH-Config", session)
if err != nil {
    if errors.Is(err, vaultmux.ErrNotFound) {
        // Item doesn't exist - create it
        return backend.CreateItem(ctx, "SSH-Config", content, session)
    }
    if errors.Is(err, vaultmux.ErrSessionExpired) {
        // Re-authenticate and retry
        session, _ = backend.Authenticate(ctx)
        return backend.GetNotes(ctx, "SSH-Config", session)
    }
    return err
}
```

---

## 7. Testing Strategy

### 7.1 Mock Backend

```go
// mock/mock.go

package mock

import (
    "context"
    "sync"

    "github.com/blackwell-systems/vaultmux"
)

// Backend is an in-memory mock for testing.
type Backend struct {
    items    map[string]*vaultmux.Item
    mu       sync.RWMutex

    // Behavior control
    AuthError   error
    GetError    error
    CreateError error
}

func New() *Backend {
    return &Backend{
        items: make(map[string]*vaultmux.Item),
    }
}

func (b *Backend) Name() string { return "mock" }

func (b *Backend) Init(ctx context.Context) error { return nil }
func (b *Backend) Close() error { return nil }

func (b *Backend) IsAuthenticated(ctx context.Context) bool {
    return b.AuthError == nil
}

func (b *Backend) Authenticate(ctx context.Context) (vaultmux.Session, error) {
    if b.AuthError != nil {
        return nil, b.AuthError
    }
    return &mockSession{}, nil
}

func (b *Backend) GetNotes(ctx context.Context, name string, _ vaultmux.Session) (string, error) {
    if b.GetError != nil {
        return "", b.GetError
    }
    b.mu.RLock()
    defer b.mu.RUnlock()

    item, ok := b.items[name]
    if !ok {
        return "", vaultmux.ErrNotFound
    }
    return item.Notes, nil
}

func (b *Backend) CreateItem(ctx context.Context, name, content string, _ vaultmux.Session) error {
    if b.CreateError != nil {
        return b.CreateError
    }
    b.mu.Lock()
    defer b.mu.Unlock()

    if _, exists := b.items[name]; exists {
        return vaultmux.ErrAlreadyExists
    }
    b.items[name] = &vaultmux.Item{
        Name:  name,
        Notes: content,
        Type:  vaultmux.ItemTypeSecureNote,
    }
    return nil
}

// ... other methods

// Helper methods for tests
func (b *Backend) SetItem(name, content string) {
    b.mu.Lock()
    defer b.mu.Unlock()
    b.items[name] = &vaultmux.Item{Name: name, Notes: content}
}

func (b *Backend) Clear() {
    b.mu.Lock()
    defer b.mu.Unlock()
    b.items = make(map[string]*vaultmux.Item)
}
```

### 7.2 Integration Tests

```go
// vaultmux_integration_test.go
//go:build integration

package vaultmux_test

import (
    "context"
    "os"
    "testing"

    "github.com/blackwell-systems/vaultmux"
)

func TestPassBackendIntegration(t *testing.T) {
    if os.Getenv("VAULTMUX_TEST_PASS") == "" {
        t.Skip("Set VAULTMUX_TEST_PASS=1 to run pass integration tests")
    }

    ctx := context.Background()
    backend, err := vaultmux.New(vaultmux.Config{
        Backend:   vaultmux.BackendPass,
        Prefix:    "vaultmux-test",
    })
    if err != nil {
        t.Fatalf("New: %v", err)
    }
    defer backend.Close()

    if err := backend.Init(ctx); err != nil {
        t.Fatalf("Init: %v", err)
    }

    session, err := backend.Authenticate(ctx)
    if err != nil {
        t.Fatalf("Authenticate: %v", err)
    }

    // Test create
    testItem := "test-item-" + time.Now().Format("20060102150405")
    err = backend.CreateItem(ctx, testItem, "test content", session)
    if err != nil {
        t.Fatalf("CreateItem: %v", err)
    }

    // Test get
    notes, err := backend.GetNotes(ctx, testItem, session)
    if err != nil {
        t.Fatalf("GetNotes: %v", err)
    }
    if notes != "test content" {
        t.Errorf("GetNotes = %q, want %q", notes, "test content")
    }

    // Cleanup
    _ = backend.DeleteItem(ctx, testItem, session)
}
```

---

## 8. Usage Examples

### 8.1 Basic Usage

```go
package main

import (
    "context"
    "fmt"
    "log"

    "github.com/blackwell-systems/vaultmux"
)

func main() {
    ctx := context.Background()

    // Create backend
    backend, err := vaultmux.New(vaultmux.Config{
        Backend: vaultmux.BackendPass,
        Prefix:  "myapp",
    })
    if err != nil {
        log.Fatal(err)
    }
    defer backend.Close()

    // Initialize (checks CLI availability)
    if err := backend.Init(ctx); err != nil {
        log.Fatal(err)
    }

    // Authenticate
    session, err := backend.Authenticate(ctx)
    if err != nil {
        log.Fatal(err)
    }

    // Store a secret
    err = backend.CreateItem(ctx, "API-Key", "sk-secret123", session)
    if err != nil {
        log.Fatal(err)
    }

    // Retrieve it
    secret, err := backend.GetNotes(ctx, "API-Key", session)
    if err != nil {
        log.Fatal(err)
    }
    fmt.Println("Secret:", secret)
}
```

### 8.2 With Timeout

```go
ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()

notes, err := backend.GetNotes(ctx, "SSH-Config", session)
if err != nil {
    if ctx.Err() == context.DeadlineExceeded {
        log.Println("Operation timed out")
    }
    return err
}
```

### 8.3 Backend Auto-Detection

```go
// Auto-detect based on available CLIs
func DetectBackend() vaultmux.BackendType {
    if _, err := exec.LookPath("bw"); err == nil {
        return vaultmux.BackendBitwarden
    }
    if _, err := exec.LookPath("op"); err == nil {
        return vaultmux.BackendOnePassword
    }
    if _, err := exec.LookPath("pass"); err == nil {
        return vaultmux.BackendPass
    }
    return "" // No backend available
}
```

### 8.4 Sync Workflow

```go
func syncSecrets(ctx context.Context, backend vaultmux.Backend, session vaultmux.Session) error {
    // Pull latest from server
    if err := backend.Sync(ctx, session); err != nil {
        return fmt.Errorf("sync failed: %w", err)
    }

    // List all items
    items, err := backend.ListItems(ctx, session)
    if err != nil {
        return err
    }

    for _, item := range items {
        fmt.Printf("- %s (type: %d)\n", item.Name, item.Type)
    }

    return nil
}
```

---

## 9. Backend Comparison

| Feature | Bitwarden | 1Password | pass |
|---------|-----------|-----------|------|
| **CLI Tool** | `bw` | `op` | `pass` |
| **Auth Method** | Email/password + 2FA | Account + biometrics | GPG key |
| **Session Duration** | Until lock | 30 minutes | GPG agent TTL |
| **Sync** | `bw sync` | Automatic | `pass git pull/push` |
| **Offline Mode** | Yes (cached) | Limited | Yes (local files) |
| **Folders** | Yes (folderId) | Vaults | Directories |
| **Sharing** | Organizations | Vaults | Git repos |
| **Free Tier** | Yes | No | Yes (FOSS) |
| **Self-Host** | Yes (Vaultwarden) | No | Yes (any git host) |

### 9.1 When to Use Each

**Bitwarden:**
- Team/organization use
- Cross-platform sync needed
- Self-hosting preferred (Vaultwarden)

**1Password:**
- Enterprise environments
- Biometric auth important
- Watchtower/security features needed

**pass:**
- Unix power users
- Git-based workflow
- Minimal dependencies preferred
- Full offline support needed

---

## 10. Future Backends

### 10.1 Planned

| Backend | CLI | Priority | Notes |
|---------|-----|----------|-------|
| **HashiCorp Vault** | `vault` | Medium | Enterprise secret management |
| **AWS Secrets Manager** | `aws` | Low | Cloud-native, AWS-only |
| **Doppler** | `doppler` | Low | Developer-focused |
| **Keychain (macOS)** | `security` | Low | macOS-only, no sync |

### 10.2 Backend Plugin System (Future)

```go
// Future: Dynamic backend registration
func init() {
    vaultmux.RegisterBackend("hashicorp", func(cfg vaultmux.Config) (vaultmux.Backend, error) {
        return hashicorp.New(cfg.Options)
    })
}
```

---

## Appendix A: CLI Command Reference

### Bitwarden (`bw`)

```bash
# Status
bw status                                    # {"status":"locked"}

# Auth
bw login                                     # Interactive login
bw unlock --raw                              # Get session token

# Items
bw get item "name" --session $BW_SESSION     # JSON output
bw create item "$JSON" --session $BW_SESSION
bw edit item "$ID" "$JSON" --session $BW_SESSION
bw delete item "$ID" --session $BW_SESSION

# Sync
bw sync --session $BW_SESSION

# Folders
bw list folders --session $BW_SESSION
bw create folder "$JSON" --session $BW_SESSION
```

### 1Password (`op`)

```bash
# Auth
op account list
op signin                                    # Returns session token

# Items
op item get "name" --format json
op item create --category SecureNote --title "name" notes="content"
op item edit "name" notes="new content"
op item delete "name"

# Vaults
op vault list --format json
op vault create "name"
```

### pass

```bash
# List
pass                                         # Tree view
pass ls                                      # List entries

# Items
pass show "prefix/name"                      # Decrypt and show
pass insert -m "prefix/name"                 # Create multiline
pass insert -m -f "prefix/name"              # Update (force)
pass rm -f "prefix/name"                     # Delete

# Git sync
pass git pull
pass git push
```

---

## Appendix B: Security Considerations

1. **Session tokens are sensitive** - Store with mode 0600, clear on lock
2. **GPG agent passphrase caching** - Configure appropriate timeout
3. **CLI output may contain secrets** - Don't log full command output
4. **Context cancellation** - Ensure partial operations are safe
5. **Concurrent access** - Session refresh needs mutex protection

---

*Document Version: 1.0*
*Last Updated: 2025-12-07*
