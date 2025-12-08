# Windows Setup Guide

> **Complete guide for Windows users using PowerShell**

This guide covers setting up dotfiles on native Windows with PowerShell. For WSL2, use the standard Linux installation.

---

## Quick Start

```powershell
# 1. Clone the repository
git clone https://github.com/blackwell-systems/dotfiles.git $HOME\workspace\dotfiles

# 2. Install the PowerShell module
cd $HOME\workspace\dotfiles\powershell
.\Install-Dotfiles.ps1

# 3. Restart PowerShell or import manually
Import-Module Dotfiles

# 4. Verify installation
dotfiles-status
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
git clone https://github.com/blackwell-systems/dotfiles.git $HOME\workspace\dotfiles

# Install module
cd $HOME\workspace\dotfiles\powershell
.\Install-Dotfiles.ps1

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
git clone https://github.com/blackwell-systems/dotfiles.git $HOME\workspace\dotfiles
cd $HOME\workspace\dotfiles

# Build and install the Go CLI
go build -o dotfiles.exe ./cmd/dotfiles
Move-Item dotfiles.exe $HOME\.local\bin\

# Add to PATH (if not already)
$env:Path += ";$HOME\.local\bin"
[Environment]::SetEnvironmentVariable("Path", $env:Path, "User")

# Install PowerShell module
cd powershell
.\Install-Dotfiles.ps1

# Run setup wizard
dotfiles setup
```

### Option 3: Download Pre-built Binary

If Go isn't installed, download a pre-built binary:

```powershell
# Check releases page for latest
# https://github.com/blackwell-systems/dotfiles/releases

# Download and extract to PATH
# Then run: dotfiles setup
```

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
| **Hooks** | `Invoke-DotfilesHook`, `Register-DotfilesHook` | 24 hook points |

### Go CLI Features

| Command | Description |
|---------|-------------|
| `dotfiles setup` | Interactive setup wizard |
| `dotfiles status` | Show configuration status |
| `dotfiles doctor` | Health check with auto-fix |
| `dotfiles vault pull` | Pull secrets from vault |
| `dotfiles vault push` | Push secrets to vault |
| `dotfiles features` | Manage feature flags |

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
dotfiles setup
# Select Bitwarden as vault backend
```

### Using 1Password

```powershell
# Install 1Password CLI
winget install AgileBits.1Password.CLI

# Sign in
op signin

# Configure dotfiles
dotfiles setup
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
Import-Module Dotfiles -Verbose
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
dotfiles features enable docker_tools
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
.\Install-Dotfiles.ps1 -Force

# Rebuild CLI (if using Go)
go build -o dotfiles.exe ./cmd/dotfiles
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

- **Documentation**: https://github.com/blackwell-systems/dotfiles
- **Issues**: https://github.com/blackwell-systems/dotfiles/issues
- **PowerShell Commands**: `Get-Command -Module Dotfiles`

---

*Last updated: 2025-12-08*
