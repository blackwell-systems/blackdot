# Go Setup Wizard Implementation Plan

> **Status:** ✅ Implemented (Windows support added)
> **Prerequisite:** Phase 3 (Production Release)
> **Complexity:** High - 7 phases, cross-platform, interactive UI

---

## Overview

~~The current `bin/dotfiles-setup` is a ~1200 line ZSH script that only works on Unix with ZSH installed.~~

**UPDATE (2025-12-09):** Windows support has been implemented directly in the existing Go `setup` command (`internal/cli/setup.go`). The implementation:

- ✅ Works on Windows (PowerShell users)
- ✅ Works on Linux without ZSH
- ✅ Works for binary-only installations
- ✅ Cross-platform with consistent UX

---

## Current ZSH Wizard Analysis

### 7 Phases

| Phase | Name | What It Does | Platform Concerns |
|-------|------|--------------|-------------------|
| 1 | Workspace | Configure ~/workspace, create /workspace symlink | Unix: `sudo ln -sfn`, Windows: `C:\workspace` junction |
| 2 | Symlinks | Link ~/.zshrc, ~/.p10k.zsh | Unix-only files; Windows needs PS profile + Starship |
| 3 | Packages | Install from Brewfile (tier selection) | Homebrew on Unix, winget on Windows |
| 4 | Vault | Configure backend, login, validate schema | Cross-platform but different CLI invocations |
| 5 | Secrets | Scan local vs vault, push/restore | SSH paths differ on Windows |
| 6 | Claude | Install dotclaude if Claude detected | Cross-platform |
| 7 | Templates | Initialize machine-specific configs | Cross-platform |

### Dependencies on Shell Libraries

```
lib/_logging.sh   → internal/color (already ported)
lib/_config.sh    → internal/config (already ported)
lib/_features.sh  → internal/feature (already ported)
lib/_state.sh     → Need to port setup state functions
lib/_vault.sh     → Need to port (or call vaultmux)
```

### State Management

Current state tracking in config.json:
```json
{
  "setup": {
    "workspace": { "completed": true, "timestamp": 1702123456 },
    "symlinks": { "completed": true, "timestamp": 1702123457 },
    "packages": { "completed": false },
    ...
  }
}
```

---

## Go Implementation Design

### File Structure

```
internal/
├── cli/cmd/
│   └── setup.go           # Cobra command definition
├── setup/
│   ├── setup.go           # Main orchestrator
│   ├── phase.go           # Phase interface & registry
│   ├── state.go           # State management
│   ├── ui.go              # Interactive UI (prompts, progress)
│   ├── platform.go        # Platform detection
│   ├── platform_unix.go   # Unix-specific implementations
│   ├── platform_windows.go # Windows-specific implementations
│   └── phases/
│       ├── workspace.go   # Phase 1
│       ├── symlinks.go    # Phase 2
│       ├── packages.go    # Phase 3
│       ├── vault.go       # Phase 4
│       ├── secrets.go     # Phase 5
│       ├── claude.go      # Phase 6
│       └── template.go    # Phase 7
```

### Core Interfaces

```go
// phase.go
type Phase interface {
    // Metadata
    Name() string        // "workspace", "symlinks", etc.
    Title() string       // "Workspace Configuration"
    Description() string // Shown in overview

    // State
    IsCompleted(state *State) bool
    MarkCompleted(state *State) error
    Reset(state *State) error

    // Execution
    Run(ctx context.Context, ui *UI, state *State, platform Platform) error
    Skip(state *State) error
}

// platform.go
type Platform interface {
    // Identity
    Name() string  // "unix", "windows"
    OS() string    // "darwin", "linux", "windows"

    // Phase 2: Symlinks
    GetShellConfigLinks() []SymlinkSpec
    GetThemeConfig() *ThemeConfig
    RunBootstrap(dotfilesDir string) error

    // Phase 3: Packages
    GetPackageManager() PackageManager
    GetPackageTiers() map[string][]string

    // Phase 1: Workspace
    SupportsWorkspaceSymlink() bool
    CreateWorkspaceSymlink(target string) error
}

// ui.go
type UI struct {
    stdin  io.Reader
    stdout io.Writer
    colors *color.Colors
}

func (u *UI) Prompt(question string, defaultYes bool) bool
func (u *UI) PromptChoice(question string, choices []string, defaultIdx int) int
func (u *UI) PromptString(question, defaultVal string) string
func (u *UI) ShowProgress(current, total int, phaseName string)
func (u *UI) ShowBanner()
func (u *UI) ShowStatus(phases []Phase, state *State)
func (u *UI) ShowOverview(phases []Phase)
func (u *UI) Info(msg string, args ...interface{})
func (u *UI) Pass(msg string, args ...interface{})
func (u *UI) Warn(msg string, args ...interface{})
func (u *UI) Fail(msg string, args ...interface{})
```

### Platform Implementations

#### Unix Platform

```go
// platform_unix.go
// +build !windows

type UnixPlatform struct {
    dotfilesDir string
}

func (p *UnixPlatform) GetShellConfigLinks() []SymlinkSpec {
    return []SymlinkSpec{
        {
            Source: filepath.Join(p.dotfilesDir, "zsh/zshrc"),
            Target: filepath.Join(os.Getenv("HOME"), ".zshrc"),
        },
    }
}

func (p *UnixPlatform) GetThemeConfig() *ThemeConfig {
    // Check if powerlevel10k is installed
    brewPrefix := getBrewPrefix()
    p10kInstalled := dirExists(filepath.Join(brewPrefix, "share/powerlevel10k"))

    return &ThemeConfig{
        Name:        "Powerlevel10k",
        Installed:   p10kInstalled,
        ConfigPath:  filepath.Join(os.Getenv("HOME"), ".p10k.zsh"),
        BundledPath: filepath.Join(p.dotfilesDir, "zsh/p10k.zsh"),
        InstallHint: "brew install powerlevel10k",
    }
}

func (p *UnixPlatform) GetPackageManager() PackageManager {
    if commandExists("brew") {
        return &BrewPackageManager{dotfilesDir: p.dotfilesDir}
    }
    return nil
}

func (p *UnixPlatform) GetPackageTiers() map[string][]string {
    return map[string][]string{
        "minimal":  readBrewfilePackages("Brewfile.minimal"),
        "enhanced": readBrewfilePackages("Brewfile.enhanced"),
        "full":     readBrewfilePackages("Brewfile"),
    }
}

func (p *UnixPlatform) SupportsWorkspaceSymlink() bool {
    return true
}

func (p *UnixPlatform) CreateWorkspaceSymlink(target string) error {
    // Requires sudo on Unix
    return exec.Command("sudo", "ln", "-sfn", target, "/workspace").Run()
}
```

#### Windows Platform

```go
// platform_windows.go
// +build windows

type WindowsPlatform struct {
    dotfilesDir string
}

func (p *WindowsPlatform) GetShellConfigLinks() []SymlinkSpec {
    // No ZSH on Windows - PowerShell profile handled by module
    return []SymlinkSpec{}
}

func (p *WindowsPlatform) GetThemeConfig() *ThemeConfig {
    starshipInstalled := commandExists("starship")

    return &ThemeConfig{
        Name:        "Starship",
        Installed:   starshipInstalled,
        ConfigPath:  filepath.Join(os.Getenv("USERPROFILE"), ".config/starship.toml"),
        BundledPath: filepath.Join(p.dotfilesDir, "powershell/starship.toml"),
        InstallHint: "winget install Starship.Starship",
    }
}

func (p *WindowsPlatform) GetPackageManager() PackageManager {
    if commandExists("winget") {
        return &WingetPackageManager{dotfilesDir: p.dotfilesDir}
    }
    return nil
}

func (p *WindowsPlatform) GetPackageTiers() map[string][]string {
    // Read from Install-Packages.ps1 tier definitions
    return map[string][]string{
        "minimal":  {"Git.Git", "GitHub.cli", "Microsoft.PowerShell", ...},
        "enhanced": {"Git.Git", ..., "Starship.Starship", ...},
        "full":     {"Git.Git", ..., "Docker.DockerDesktop", ...},
    }
}

func (p *WindowsPlatform) SupportsWorkspaceSymlink() bool {
    return true // Windows supports junctions for same goal
}

func (p *WindowsPlatform) CreateWorkspaceSymlink(target string) error {
    // Windows uses directory junctions (no admin for same-drive)
    // or symlinks (needs admin or Developer Mode)
    workspacePath := "C:\\workspace"

    // Check if already exists
    if _, err := os.Stat(workspacePath); err == nil {
        return nil // Already exists
    }

    // Try junction first (works without admin on same drive)
    cmd := exec.Command("cmd", "/c", "mklink", "/J", workspacePath, target)
    if err := cmd.Run(); err == nil {
        return nil
    }

    // Fall back to symlink (requires admin or Developer Mode)
    cmd = exec.Command("cmd", "/c", "mklink", "/D", workspacePath, target)
    if err := cmd.Run(); err != nil {
        return fmt.Errorf("failed to create workspace link (try running as Administrator): %w", err)
    }

    return nil
}

func (p *WindowsPlatform) IsElevated() bool {
    // Check if running as Administrator
    _, err := os.Open("\\\\.\\PHYSICALDRIVE0")
    return err == nil
}
```

### Phase Implementations

#### Phase 2: Symlinks (Example)

```go
// phases/symlinks.go
type SymlinksPhase struct{}

func (p *SymlinksPhase) Name() string  { return "symlinks" }
func (p *SymlinksPhase) Title() string { return "Shell Configuration" }
func (p *SymlinksPhase) Description() string {
    return "Link shell config files"
}

func (p *SymlinksPhase) Run(ctx context.Context, ui *UI, state *State, platform Platform) error {
    links := platform.GetShellConfigLinks()
    theme := platform.GetThemeConfig()

    // Show what will be done
    if len(links) > 0 {
        ui.Info("Files to link:")
        for _, link := range links {
            ui.Printf("  %s → %s", link.Target, link.Source)
        }
    }

    if theme != nil && theme.Installed {
        ui.Info("")
        ui.Info("Optional (you'll be prompted):")
        ui.Printf("  %s → %s theme config", theme.ConfigPath, theme.Name)
    }

    // Prompt to proceed
    if len(links) > 0 {
        if !ui.Prompt("Create symlinks?", true) {
            return p.Skip(state)
        }

        // Create symlinks
        for _, link := range links {
            if err := createSymlinkSafe(link.Source, link.Target); err != nil {
                ui.Warn("Failed to link %s: %v", link.Target, err)
            } else {
                ui.Pass("Linked %s", link.Target)
            }
        }
    }

    // Theme config prompt
    if theme != nil && theme.Installed {
        if err := p.handleThemeConfig(ui, theme); err != nil {
            ui.Warn("Theme config: %v", err)
        }
    } else if theme != nil && !theme.Installed {
        ui.Info("%s not installed. Install with: %s", theme.Name, theme.InstallHint)
    }

    return p.MarkCompleted(state)
}

func (p *SymlinksPhase) handleThemeConfig(ui *UI, theme *ThemeConfig) error {
    configExists := fileExists(theme.ConfigPath)
    isSymlink := isSymlink(theme.ConfigPath)

    if isSymlink {
        ui.Pass("%s config already linked", theme.Name)
        return nil
    }

    var useBundled bool
    if configExists {
        useBundled = ui.Prompt(
            fmt.Sprintf("Existing %s found. Replace with bundled config?", theme.ConfigPath),
            false, // default NO for existing
        )
    } else {
        useBundled = ui.Prompt(
            fmt.Sprintf("Use bundled %s theme config?", theme.Name),
            true, // default YES for new
        )
    }

    if useBundled {
        // Backup existing if not symlink
        if configExists && !isSymlink {
            backupPath := fmt.Sprintf("%s.bak-%d", theme.ConfigPath, time.Now().Unix())
            os.Rename(theme.ConfigPath, backupPath)
            ui.Info("Backed up existing config to %s", backupPath)
        }

        // Create symlink or copy
        if err := createSymlinkSafe(theme.BundledPath, theme.ConfigPath); err != nil {
            return err
        }
        ui.Pass("%s config installed (bundled theme)", theme.Name)
    } else {
        ui.Info("Skipping %s config. Run '%s' to configure.", theme.Name, theme.ConfigureCmd)
    }

    return nil
}
```

### Main Setup Command

```go
// cmd/setup.go
var setupCmd = &cobra.Command{
    Use:   "setup",
    Short: "Interactive setup wizard",
    Long: `Guide through initial dotfiles configuration.

The setup wizard will:
  1. Configure workspace directory
  2. Link shell configuration files
  3. Install packages (Homebrew/winget)
  4. Configure vault backend
  5. Manage secrets (SSH keys, AWS, Git)
  6. Set up Claude Code integration
  7. Initialize machine-specific templates

Your progress is saved automatically. If interrupted,
run 'dotfiles setup' again to continue.`,
    RunE: runSetup,
}

func init() {
    setupCmd.Flags().BoolP("status", "s", false, "Show current setup status only")
    setupCmd.Flags().BoolP("reset", "r", false, "Reset state and re-run from beginning")
    rootCmd.AddCommand(setupCmd)
}

func runSetup(cmd *cobra.Command, args []string) error {
    // Initialize
    cfg := config.Load()
    state := setup.NewState(cfg)
    platform := setup.DetectPlatform()
    ui := setup.NewUI(os.Stdin, os.Stdout)

    // Register phases
    phases := []setup.Phase{
        phases.NewWorkspacePhase(),
        phases.NewSymlinksPhase(),
        phases.NewPackagesPhase(),
        phases.NewVaultPhase(),
        phases.NewSecretsPhase(),
        phases.NewClaudePhase(),
        phases.NewTemplatePhase(),
    }

    // Handle --status
    if statusOnly, _ := cmd.Flags().GetBool("status"); statusOnly {
        ui.ShowStatus(phases, state)
        return nil
    }

    // Handle --reset
    if reset, _ := cmd.Flags().GetBool("reset"); reset {
        if ui.Prompt("Reset all setup progress?", false) {
            for _, p := range phases {
                p.Reset(state)
            }
            ui.Pass("State reset")
        } else {
            ui.Info("Reset cancelled")
            return nil
        }
    }

    // Show banner and status
    ui.ShowBanner()
    ui.ShowStatus(phases, state)

    // Check if any setup needed
    needsSetup := false
    for _, p := range phases {
        if !p.IsCompleted(state) {
            needsSetup = true
            break
        }
    }

    if !needsSetup {
        ui.Pass("All setup complete!")
        ui.Info("Run 'dotfiles doctor' to verify health.")
        ui.Info("Run 'dotfiles setup --reset' to reconfigure.")
        return nil
    }

    // Show overview and prompt to begin
    ui.ShowOverview(phases)
    ui.PromptContinue("Press Enter to begin setup...")

    // Run each phase
    for i, phase := range phases {
        if phase.IsCompleted(state) {
            continue
        }

        ui.ShowProgress(i+1, len(phases), phase.Title())

        if err := phase.Run(cmd.Context(), ui, state, platform); err != nil {
            ui.Warn("Phase %s: %v", phase.Name(), err)
            // Continue to next phase
        }
    }

    // Final status
    ui.ShowStatus(phases, state)

    // Feature preset selection (end of setup)
    if !state.NeedsSetup() {
        ui.ShowCompletionBanner()
        selectFeaturePreset(ui, cfg)
        showNextSteps(ui, cfg, platform)
    }

    return nil
}
```

---

## Implementation Tasks

> **Note:** Instead of the separate `internal/setup/` package structure planned below,
> Windows support was added directly to `internal/cli/setup.go` using platform detection
> helpers. This simpler approach avoided duplication while achieving cross-platform support.

### Phase 1: Core Infrastructure
- [x] ~~Create `internal/setup/` package structure~~ (done inline in setup.go)
- [x] ~~Implement `Phase` interface~~ (existing phase functions)
- [x] Implement `State` management (reuse config.json) ✅
- [x] Implement `UI` with prompts and progress ✅
- [x] Implement `Platform` interface + detection ✅ (helper functions)

### Phase 2: Platform Implementations
- [x] Implement Unix support (darwin, linux) ✅
- [x] Implement Windows support ✅
- [x] Abstract package manager (Homebrew/winget) ✅
- [x] Abstract symlink creation (mklink /J on Windows) ✅

### Phase 3: Port Each Phase
- [x] Port Phase 1: Workspace ✅ (C:\workspace junction on Windows)
- [x] Port Phase 2: Symlinks ✅ (PowerShell profile on Windows)
- [x] Port Phase 3: Packages ✅ (winget on Windows)
- [x] Port Phase 4: Vault ✅ (backend detection, login)
- [x] Port Phase 5: Secrets ✅ (scan, push, restore)
- [x] Port Phase 6: Claude ✅ (dotclaude install)
- [x] Port Phase 7: Templates ✅ (init)

### Phase 4: Command Integration
- [x] Add `setup` command to Cobra ✅
- [x] Wire up --status and --reset flags ✅
- [x] Feature preset selection at end ✅
- [x] Next steps display ✅

### Phase 5: Testing
- [ ] Unit tests for each phase
- [ ] Platform-specific tests
- [x] Integration test (mock UI) - tested manually
- [x] Manual testing on Linux ✅
- [x] Cross-compile for Windows ✅ (`GOOS=windows go build`)
- [ ] Manual testing on actual Windows machine

---

## Migration Path

1. ~~**Implement Go version** alongside ZSH version~~ ✅ Done
2. ~~**Feature flag**: `DOTFILES_SETUP_GO=1` to opt-in~~ (Not needed - Go is already default)
3. **Test extensively** on all platforms - Linux ✅, Windows pending
4. ~~**Make Go default** when stable~~ ✅ Already default via Phase 2 shell switchover
5. **Remove ZSH version** in Phase 3 cleanup - `bin/dotfiles-setup` can be deprecated

---

## Complexity Estimate

| Component | Lines of Go | Effort |
|-----------|-------------|--------|
| Core (phase, state, ui, platform) | ~500 | Medium |
| Platform implementations | ~300 | Medium |
| 7 phase implementations | ~1000 | High |
| Command + integration | ~200 | Low |
| Tests | ~500 | Medium |
| **Total** | **~2500** | **High** |

---

## Open Questions

1. ~~**Vault phase**: Call vaultmux directly or shell out to `bw`/`op`/`pass`?~~
   - **RESOLVED**: Uses existing shell scripts via `exec.Command()`
2. ~~**Secrets phase**: How much of vault/_common.sh to port vs reuse?~~
   - **RESOLVED**: Reuses existing shell scripts
3. ~~**Windows /workspace**: Skip entirely or offer alternative?~~
   - **RESOLVED**: Create `C:\workspace` junction (same goal as Unix `/workspace`)
   - Try junction first (no admin needed on same drive), fall back to symlink
4. ~~**Sudo prompts**: How to handle elevated permissions cross-platform?~~
   - **RESOLVED**:
   - Unix: Shell out to `sudo` command
   - Windows: Try junction first, prompt to run as Admin if needed

---

## Implementation Summary (2025-12-09)

Windows support was implemented directly in `internal/cli/setup.go` rather than creating
a separate `internal/setup/` package. Key additions:

```go
// Platform detection helpers
func isWindows() bool                    // in features.go (reused)
func workspaceSymlinkPath() string       // "/workspace" or "C:\workspace"
func defaultWorkspaceDir() string        // ~/workspace on both
func shellConfigName() string            // ".zshrc" or "PowerShell profile"
func packageManagerName() string         // "Homebrew" or "winget"
func getPhaseDescriptions() map[string]string  // platform-aware descriptions

// Phase implementations updated
func phaseWorkspace()    // createWorkspaceSymlink() handles both platforms
func phaseSymlinks()     // createWindowsSymlinks() for PowerShell profile
func phasePackages()     // phasePackagesWindows() for winget
func inferState()        // platform-aware state detection
```

**Total changes:** ~290 lines added/modified in setup.go

---

*Last Updated: 2025-12-09*
