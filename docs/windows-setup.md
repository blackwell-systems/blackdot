# Windows Setup Guide

> **Complete guide for Windows users using PowerShell**

This guide covers setting up blackdot on native Windows with PowerShell. For WSL2, use the standard Linux installation.

---

## One-Line Install

```powershell
irm https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install-windows.ps1 | iex
```

This will:
1. Clone the repository to `~/workspace/blackdot`
2. Install the PowerShell module
3. Download the Go binary
4. Configure your PowerShell profile

After installation, restart PowerShell and run `blackdot setup`.

---

## Manual Installation

```powershell
# 1. Clone the repository
git clone https://github.com/blackwell-systems/blackdot.git $HOME\workspace\blackdot

# 2. Install the PowerShell module
cd $HOME\workspace\blackdot\powershell
.\Install-Blackdot.ps1 -Binary

# 3. Restart PowerShell or import manually
Import-Module Blackdot

# 4. Run setup wizard
blackdot setup
```

---

## Prerequisites

### Required

- **Windows 10/11** (PowerShell 5.1+ included)
- **Git for Windows** - [Download](https://git-scm.com/download/win) or `winget install Git.Git`
- **PowerShell 7** (recommended) - `winget install Microsoft.PowerShell`

### Optional (for full functionality)

- **Go 1.21+** - For building the CLI from source: `winget install GoLang.Go`
- **Bitwarden CLI** - For vault sync: `winget install Bitwarden.CLI`
- **1Password CLI** - Alternative vault: `winget install AgileBits.1Password.CLI`
- **Docker Desktop** - For Docker tools: `winget install Docker.DockerDesktop`

---

## Installation Options

### Option 1: PowerShell Module Only (Simplest)

If you just want the developer tool aliases:

```powershell
# Clone
git clone https://github.com/blackwell-systems/blackdot.git $HOME\workspace\dotfiles

# Install module
cd $HOME\workspace\dotfiles\powershell
.\Install-Blackdot.ps1

# Done! Restart PowerShell
```

This gives you:
- All tool aliases (ssh-*, aws-*, go-*, rust-*, py-*, docker-*)
- Hook system integration
- Directory change hooks

### Option 2: Full Installation (Recommended)

For complete functionality including vault sync:

```powershell
# Clone
git clone https://github.com/blackwell-systems/blackdot.git $HOME\workspace\dotfiles
cd $HOME\workspace\dotfiles

# Build and install the Go CLI
go build -o blackdot.exe ./cmd/blackdot
Move-Item blackdot.exe $HOME\.local\bin\

# Add to PATH (if not already)
$env:Path += ";$HOME\.local\bin"
[Environment]::SetEnvironmentVariable("Path", $env:Path, "User")

# Install PowerShell module
cd powershell
.\Install-Blackdot.ps1

# Run setup wizard
blackdot setup
```

### Option 3: Download Pre-built Binary

If Go isn't installed, download a pre-built binary:

```powershell
# Check releases page for latest
# https://github.com/blackwell-systems/blackdot/releases

# Download and extract to PATH
# Then run: dotfiles setup
```

---

## Package Installation

Similar to `brew bundle` on macOS/Linux, Windows has a package installer script:

```powershell
# Full installation (all packages)
cd $HOME\workspace\dotfiles\powershell
.\Install-Packages.ps1

# Minimal (essential CLI tools only)
.\Install-Packages.ps1 -Tier minimal

# Enhanced (modern CLI + dev languages, no Docker/editors)
.\Install-Packages.ps1 -Tier enhanced

# Preview what would be installed
.\Install-Packages.ps1 -DryRun
```

### Package Tiers

| Tier | Packages | Use Case |
|------|----------|----------|
| **minimal** | git, gh, pwsh, bat, ripgrep, fzf, jq | Essential CLI tools |
| **enhanced** | + fd, eza, zoxide, glow, dust, AWS CLI, Go, Rust, Python, fnm | Developer workstation |
| **full** | + Docker Desktop, VS Code, Windows Terminal, 1Password CLI | Complete setup |

### What Gets Installed

| Category | Packages |
|----------|----------|
| **CLI Tools** | bat, fd, ripgrep, fzf, eza, zoxide, glow, dust, jq |
| **Development** | Go, Rust, Python, fnm (Node.js manager) |
| **Cloud** | AWS CLI, Bitwarden CLI, 1Password CLI, age (encryption) |
| **Containers** | Docker Desktop |
| **Editors** | VS Code, Windows Terminal |

---

## Node.js Version Management (fnm)

Instead of NVM (Unix-only), use **fnm** (Fast Node Manager) - cross-platform:

```powershell
# Install fnm
winget install Schniz.fnm

# Or via the package script
.\Install-Packages.ps1 -Tier enhanced

# Install Node.js LTS
fnm-install lts-latest

# Switch versions
fnm-use 20

# List installed versions
fnm-list
```

fnm auto-switches Node versions when entering directories with `.nvmrc` or `.node-version` files.

---

## What Gets Installed

### PowerShell Module Features

| Category | Commands | Description |
|----------|----------|-------------|
| **SSH** | `ssh-keys`, `ssh-gen`, `ssh-tunnel`, `ssh-status` | SSH key and tunnel management |
| **AWS** | `aws-profiles`, `aws-who`, `aws-login`, `aws-switch` | AWS profile management |
| **CDK** | `cdk-init`, `cdk-env`, `cdk-outputs`, `cdk-status` | AWS CDK helpers |
| **Go** | `go-new`, `go-test`, `go-lint`, `go-info` | Go development tools |
| **Rust** | `rust-new`, `rust-lint`, `rust-info` | Rust development tools |
| **Python** | `py-new`, `py-test`, `py-info` | Python development tools |
| **Docker** | `docker-ps`, `docker-images`, `docker-clean`, `docker-status` | Docker management |
| **Node.js** | `fnm-install`, `fnm-use`, `fnm-list`, `Initialize-Fnm` | Node version management |
| **Navigation** | `z` (via zoxide), `Initialize-Zoxide` | Smart directory jumping |
| **Hooks** | `Invoke-DotfilesHook`, `Register-DotfilesHook` | 24 hook points |

### Go CLI Features

| Command | Description |
|---------|-------------|
| `blackdot setup` | Interactive setup wizard |
| `blackdot status` | Show configuration status |
| `blackdot doctor` | Health check with auto-fix |
| `blackdot vault pull` | Pull secrets from vault |
| `blackdot vault push` | Push secrets to vault |
| `blackdot features` | Manage feature flags |

---

## Vault Configuration

### Using Bitwarden

```powershell
# Install Bitwarden CLI
winget install Bitwarden.CLI

# Login and unlock
bw login
$env:BW_SESSION = $(bw unlock --raw)

# Configure dotfiles
blackdot setup
# Select Bitwarden as vault backend
```

### Using 1Password

```powershell
# Install 1Password CLI
winget install AgileBits.1Password.CLI

# Sign in
op signin

# Configure dotfiles
blackdot setup
# Select 1Password as vault backend
```

---

## Troubleshooting

### Module not loading

```powershell
# Check if module is installed
Get-Module -ListAvailable Dotfiles

# Check profile imports it
Get-Content $PROFILE

# Manual import
Import-Module Blackdot -Verbose
```

### Commands not found

```powershell
# Ensure dotfiles CLI is in PATH
where.exe dotfiles

# If not found, add to PATH
$env:Path += ";$HOME\.local\bin"
```

### Permission errors

```powershell
# Enable script execution
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### Docker commands fail

```powershell
# Check Docker is running
docker info

# Enable docker_tools feature
blackdot features enable docker_tools
```

---

## Directory Structure

After installation:

```
$HOME\
├── workspace\
│   └── dotfiles\           # Repository clone
│       ├── powershell\     # PowerShell module source
│       └── ...
├── Documents\
│   └── PowerShell\
│       └── Modules\
│           └── Dotfiles\   # Installed module
└── .config\
    └── dotfiles\
        └── config.json     # Configuration
```

---

## Updating

```powershell
# Update repository
cd $HOME\workspace\dotfiles
git pull

# Reinstall module
cd powershell
.\Install-Blackdot.ps1 -Force

# Rebuild CLI (if using Go)
go build -o dotfiles.exe ./cmd/blackdot
Move-Item -Force dotfiles.exe $HOME\.local\bin\
```

---

## Comparison: Windows vs Unix

| Feature | Unix (ZSH) | Windows (PowerShell) |
|---------|------------|---------------------|
| Shell config | `~/.zshrc` | `$PROFILE` |
| Tool aliases | ZSH functions | PowerShell functions |
| Hooks | 24 ZSH hooks | 24 PowerShell hooks |
| Vault sync | ✅ | ✅ |
| Feature flags | ✅ | ✅ |
| Go CLI | ✅ | ✅ |
| Auto-install | `curl \| bash` | Manual (see above) |

---

## Getting Help

- **Documentation**: https://github.com/blackwell-systems/blackdot
- **Issues**: https://github.com/blackwell-systems/blackdot/issues
- **PowerShell Commands**: `Get-Command -Module Dotfiles`

---

*Last updated: 2025-12-08*
