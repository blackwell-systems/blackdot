# Dotfiles PowerShell Module

Cross-platform PowerShell integration for the dotfiles system. Provides hooks, aliases, and developer tools for Windows users.

## Features

- **Lifecycle Hooks** - `shell_init`, `directory_change`, `shell_exit` mapped to PowerShell events
- **Tool Aliases** - 50+ functions wrapping `dotfiles tools` commands
- **Environment Management** - AWS, CDK environment variable handling
- **Automatic Initialization** - Runs `shell_init` hook on module import

## Installation

### Prerequisites

1. **PowerShell 5.1+** (Windows) or **PowerShell 7+** (cross-platform)
2. **dotfiles Go CLI** in your PATH

### Quick Install

```powershell
# From the dotfiles repository
cd powershell
.\Install-Dotfiles.ps1
```

### Manual Install

```powershell
# Copy to your modules directory
$modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\Dotfiles"
Copy-Item -Path ".\powershell\*" -Destination $modulePath -Recurse

# Add to your profile
Add-Content -Path $PROFILE -Value "Import-Module Dotfiles"
```

## Usage

### Hooks

```powershell
# Run a hook manually
Invoke-DotfilesHook -Point "shell_init"

# Dry run (preview)
Invoke-DotfilesHook -Point "post_vault_pull" -DryRun

# Disable/enable hooks
Disable-DotfilesHooks
Enable-DotfilesHooks
```

### Tool Aliases

**SSH Tools:**
```powershell
ssh-keys          # List SSH keys with fingerprints
ssh-gen mykey     # Generate ED25519 key pair
ssh-status        # Show SSH status with ASCII banner
ssh-tunnel 8080:localhost:80 myserver  # Create tunnel
```

**AWS Tools:**
```powershell
aws-profiles      # List AWS profiles
aws-who           # Show current identity
aws-login dev     # SSO login to profile
aws-switch prod   # Switch profile (sets env vars)
aws-status        # Show status with ASCII banner
```

**CDK Tools:**
```powershell
cdk-init          # Initialize CDK project
cdk-env           # Set CDK env vars from AWS profile
cdk-status        # Show CDK status
```

**Language Tools:**
```powershell
# Go
go-new myproject  # Create new Go project
go-test           # Run tests
go-lint           # Run linters

# Rust
rust-new myapp    # Create Rust project
rust-lint         # Run cargo check + clippy

# Python
py-new myapp      # Create Python project with uv
py-test           # Run pytest
```

### Directory Change Hook

The module overrides `cd` to trigger the `directory_change` hook:

```powershell
cd C:\Projects\myapp  # Triggers directory_change hook
```

This enables auto-venv activation, project-specific env vars, etc.

### Short Alias

```powershell
d status    # Same as: dotfiles status
d doctor    # Same as: dotfiles doctor
```

## Hook Points

| Hook Point | Trigger |
|------------|---------|
| `shell_init` | Module import (PowerShell start) |
| `shell_exit` | PowerShell exit |
| `directory_change` | After `cd` / `Set-Location` |
| `pre_vault_pull` | Before vault restore |
| `post_vault_pull` | After vault restore |
| `pre_vault_push` | Before vault sync |
| `post_vault_push` | After vault sync |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `DOTFILES_DIR` | Override dotfiles installation path |
| `DOTFILES_HOOKS_DISABLED` | Disable all hooks if set to `true` |

## Comparison with ZSH

| Feature | ZSH | PowerShell |
|---------|-----|------------|
| Shell init hook | `.zshrc` + `shell_init` | Profile + `shell_init` |
| Directory change | `chpwd_functions` | `cd` wrapper |
| Shell exit | `zshexit` | `PowerShell.Exiting` event |
| Prompt hook | `precmd_functions` | `prompt` function |
| Tool aliases | Shell functions | PowerShell functions |

## Troubleshooting

### Module not loading

```powershell
# Check if installed
Get-Module -ListAvailable Dotfiles

# Force reimport
Import-Module Dotfiles -Force
```

### dotfiles CLI not found

```powershell
# Check PATH
$env:PATH -split ';' | Where-Object { $_ -like '*dotfiles*' }

# Add to PATH (example)
$env:PATH += ";C:\Users\you\go\bin"
```

### Hooks not running

```powershell
# Check if enabled
# (module variable, not directly accessible)

# Verify CLI works
dotfiles hook list
```

## License

MIT - See [LICENSE](../LICENSE) in the main repository.
