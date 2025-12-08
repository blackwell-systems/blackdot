# Dotfiles PowerShell Module

Cross-platform PowerShell integration for the dotfiles system. Provides hooks, aliases, and developer tools for Windows users.

> **Full Windows Setup Guide**: See [docs/windows-setup.md](../docs/windows-setup.md) for complete installation instructions.

## Quick Start

```powershell
# 1. Clone the repository
git clone https://github.com/blackwell-systems/dotfiles.git $HOME\workspace\dotfiles

# 2. Install the PowerShell module
cd $HOME\workspace\dotfiles\powershell
.\Install-Dotfiles.ps1

# 3. Install development packages (optional but recommended)
.\Install-Packages.ps1

# 4. Restart PowerShell
```

## Features

- **85+ Functions** - Tool aliases, hooks, and integrations
- **Lifecycle Hooks** - 24 hook points mapped to PowerShell events
- **Package Management** - winget-based installer (like Brewfile)
- **Node.js (fnm)** - Cross-platform Node version manager
- **Smart Navigation (zoxide)** - Auto-initialized `z` command
- **Auto Initialization** - fnm, zoxide, and hooks run on module load

---

## Installation

### Prerequisites

- **PowerShell 5.1+** (Windows built-in) or **PowerShell 7+** (recommended)
- **Git** - `winget install Git.Git`
- **dotfiles Go CLI** - Built from source or downloaded

### Install Module

```powershell
cd $HOME\workspace\dotfiles\powershell
.\Install-Dotfiles.ps1
```

### Install Packages

```powershell
# Full installation (all packages)
.\Install-Packages.ps1

# Minimal (essential CLI tools)
.\Install-Packages.ps1 -Tier minimal

# Enhanced (CLI + dev languages, no Docker)
.\Install-Packages.ps1 -Tier enhanced

# Preview only
.\Install-Packages.ps1 -DryRun
```

### Package Tiers

| Tier | Includes |
|------|----------|
| **minimal** | git, gh, pwsh, bat, ripgrep, fzf, jq |
| **enhanced** | + fd, eza, zoxide, glow, dust, AWS CLI, Go, Rust, Python, fnm |
| **full** | + Docker Desktop, VS Code, Windows Terminal, 1Password CLI |

---

## Tool Aliases

### SSH Tools
```powershell
ssh-keys              # List SSH keys with fingerprints
ssh-gen mykey         # Generate ED25519 key pair
ssh-list              # List SSH config hosts
ssh-tunnel 8080:localhost:80 server  # Create tunnel
ssh-status            # Show status with ASCII banner
```

### AWS Tools
```powershell
aws-profiles          # List AWS profiles
aws-who               # Show current identity
aws-login dev         # SSO login to profile
aws-switch prod       # Switch profile (sets env vars)
aws-assume role-arn   # Assume IAM role
aws-clear             # Clear temporary credentials
aws-status            # Show status with ASCII banner
```

### CDK Tools
```powershell
cdk-init              # Initialize CDK project
cdk-env               # Set CDK env vars from AWS profile
cdk-outputs           # Show stack outputs
cdk-context           # Show CDK context
cdk-status            # Show CDK status
```

### Docker Tools
```powershell
docker-ps             # List running containers
docker-images         # List images
docker-ip container   # Get container IP
docker-env container  # Show container env vars
docker-ports          # Show all container ports
docker-stats          # Live resource usage
docker-vols           # List volumes
docker-nets           # List networks
docker-inspect c      # Inspect container
docker-clean          # Remove stopped + dangling
docker-prune          # System prune
docker-status         # Show status with ASCII banner
```

### Go Tools
```powershell
go-new myproject      # Create new Go project
go-init               # Initialize go.mod
go-test               # Run tests
go-cover              # Run with coverage
go-lint               # Run linters
go-outdated           # Check outdated deps
go-update             # Update dependencies
go-build-all          # Build for all platforms
go-bench              # Run benchmarks
go-info               # Show Go info
```

### Rust Tools
```powershell
rust-new myapp        # Create Rust project
rust-update           # Update Rust toolchain
rust-switch stable    # Switch toolchain
rust-lint             # cargo check + clippy
rust-fix              # cargo fix
rust-outdated         # Check outdated crates
rust-expand           # Expand macros
rust-info             # Show Rust info
```

### Python Tools
```powershell
py-new myapp          # Create Python project with uv
py-clean              # Clean __pycache__
py-venv               # Create/activate venv
py-test               # Run pytest
py-cover              # Run with coverage
py-info               # Show Python info
```

### Node.js (fnm)
```powershell
fnm-install lts       # Install Node version
fnm-use 20            # Switch to version
fnm-list              # List installed versions
Initialize-Fnm        # Manually init fnm
```

fnm auto-switches when entering directories with `.nvmrc` or `.node-version`.

### Navigation (zoxide)
```powershell
z dotfiles            # Jump to ~/workspace/dotfiles
z proj                # Jump to frequently used "proj" dir
Initialize-Zoxide     # Manually init zoxide
```

---

## Hooks

### Available Hook Points

| Hook Point | Trigger |
|------------|---------|
| `shell_init` | PowerShell start (module import) |
| `shell_exit` | PowerShell exit |
| `directory_change` | After `cd` / `Set-Location` |
| `pre_vault_pull` | Before vault restore |
| `post_vault_pull` | After vault restore |
| `pre_vault_push` | Before vault sync |
| `post_vault_push` | After vault sync |
| `pre_install` | Before dotfiles install |
| `post_install` | After dotfiles install |

### Hook Commands

```powershell
# Run a hook manually
Invoke-DotfilesHook -Point "shell_init"

# Dry run (preview)
Invoke-DotfilesHook -Point "post_vault_pull" -DryRun

# Disable/enable hooks
Disable-DotfilesHooks
Enable-DotfilesHooks

# Register custom hook
Register-DotfilesHook -Point "directory_change" -Script {
    Write-Host "Changed to: $PWD"
}
```

---

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `DOTFILES_DIR` | Override dotfiles installation path |
| `DOTFILES_HOOKS_DISABLED` | Disable all hooks if `true` |

---

## Comparison: ZSH vs PowerShell

| Feature | ZSH | PowerShell |
|---------|-----|------------|
| Shell init | `.zshrc` | `$PROFILE` |
| Directory change | `chpwd` hook | `cd` wrapper |
| Shell exit | `zshexit` | `PowerShell.Exiting` event |
| Node.js | NVM | fnm (cross-platform) |
| Package manager | Homebrew | winget |
| Smart cd | zoxide | zoxide |
| Tool aliases | Shell functions | PowerShell functions |

---

## Troubleshooting

### Module not loading

```powershell
# Check if installed
Get-Module -ListAvailable Dotfiles

# Check profile imports it
Get-Content $PROFILE | Select-String "Dotfiles"

# Force reimport
Import-Module Dotfiles -Force -Verbose
```

### dotfiles CLI not found

```powershell
# Check if in PATH
where.exe dotfiles

# Add Go bin to PATH
$env:PATH += ";$HOME\go\bin"
[Environment]::SetEnvironmentVariable("Path", $env:PATH, "User")
```

### Hooks not running

```powershell
# Check if hooks are enabled
Get-DotfilesHook

# Verify CLI works
dotfiles hook list

# Enable hooks
Enable-DotfilesHooks
```

### fnm/zoxide not working

```powershell
# Reinstall packages
.\Install-Packages.ps1 -Force

# Manual initialization
Initialize-Fnm
Initialize-Zoxide

# Restart PowerShell
```

---

## Files in This Directory

| File | Purpose |
|------|---------|
| `Dotfiles.psm1` | PowerShell module (85+ functions) |
| `Dotfiles.psd1` | Module manifest |
| `Install-Dotfiles.ps1` | Module installer |
| `Install-Packages.ps1` | winget package installer |
| `packages.json` | Package manifest |

---

## License

MIT - See [LICENSE](../LICENSE) in the main repository.
