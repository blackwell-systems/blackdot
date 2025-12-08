#Requires -Version 5.1
<#
.SYNOPSIS
    Dotfiles PowerShell module - Cross-platform hooks and aliases for Windows

.DESCRIPTION
    This module provides PowerShell equivalents of ZSH dotfiles functionality:
    - Lifecycle hooks (shell_init, directory_change, shell_exit)
    - Aliases for dotfiles tools commands
    - Integration with the Go CLI

.NOTES
    Author: Dotfiles
    Requires: dotfiles Go CLI in PATH
#>

# Module-level state
$script:DotfilesLastDirectory = $null
$script:DotfilesHooksEnabled = $true

#region Configuration

function Get-DotfilesPath {
    <#
    .SYNOPSIS
        Get the dotfiles installation directory
    #>
    if ($env:DOTFILES_DIR) {
        return $env:DOTFILES_DIR
    }

    # Default locations
    $candidates = @(
        "$env:USERPROFILE\workspace\dotfiles",
        "$env:USERPROFILE\dotfiles",
        "$env:USERPROFILE\.dotfiles"
    )

    foreach ($path in $candidates) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

function Test-DotfilesCli {
    <#
    .SYNOPSIS
        Check if dotfiles CLI is available
    #>
    $null -ne (Get-Command "dotfiles" -ErrorAction SilentlyContinue)
}

#endregion

#region Hook System

function Invoke-DotfilesHook {
    <#
    .SYNOPSIS
        Run a dotfiles hook point

    .PARAMETER Point
        The hook point to run (e.g., shell_init, directory_change)

    .PARAMETER DryRun
        Preview what would run without executing
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            'shell_init', 'shell_exit', 'directory_change',
            'pre_vault_pull', 'post_vault_pull',
            'pre_vault_push', 'post_vault_push',
            'pre_doctor', 'post_doctor', 'doctor_check',
            'pre_template_render', 'post_template_render',
            'pre_encrypt', 'post_decrypt'
        )]
        [string]$Point,

        [switch]$DryRun
    )

    if (-not $script:DotfilesHooksEnabled) {
        Write-Verbose "Hooks disabled, skipping: $Point"
        return
    }

    if (-not (Test-DotfilesCli)) {
        Write-Verbose "dotfiles CLI not found, skipping hook: $Point"
        return
    }

    $args = @("hook", "run", $Point)
    if ($DryRun) {
        $args += "--dry-run"
    }

    try {
        & dotfiles @args
    }
    catch {
        Write-Warning "Hook '$Point' failed: $_"
    }
}

function Enable-DotfilesHooks {
    <#
    .SYNOPSIS
        Enable dotfiles hooks
    #>
    $script:DotfilesHooksEnabled = $true
    Write-Host "Dotfiles hooks enabled" -ForegroundColor Green
}

function Disable-DotfilesHooks {
    <#
    .SYNOPSIS
        Disable dotfiles hooks
    #>
    $script:DotfilesHooksEnabled = $false
    Write-Host "Dotfiles hooks disabled" -ForegroundColor Yellow
}

#endregion

#region Directory Change Hook

function Set-LocationWithHook {
    <#
    .SYNOPSIS
        Wrapper for Set-Location that triggers directory_change hook
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [string]$Path,

        [switch]$PassThru
    )

    $previousLocation = Get-Location

    # Call the original Set-Location
    if ($Path) {
        Microsoft.PowerShell.Management\Set-Location -Path $Path -PassThru:$PassThru
    }
    else {
        Microsoft.PowerShell.Management\Set-Location -PassThru:$PassThru
    }

    $currentLocation = Get-Location

    # Trigger hook if directory actually changed
    if ($previousLocation.Path -ne $currentLocation.Path) {
        $env:DOTFILES_PREVIOUS_DIR = $previousLocation.Path
        $env:DOTFILES_CURRENT_DIR = $currentLocation.Path
        Invoke-DotfilesHook -Point "directory_change"
    }
}

# Create alias to override cd
Set-Alias -Name cd -Value Set-LocationWithHook -Scope Global -Force

#endregion

#region Shell Exit Hook

$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    if ($script:DotfilesHooksEnabled) {
        Invoke-DotfilesHook -Point "shell_exit"
    }
}

#endregion

#region Prompt Hook (like precmd)

# Store the original prompt function
$script:OriginalPrompt = $function:prompt

function prompt {
    <#
    .SYNOPSIS
        Custom prompt that can trigger pre-prompt hooks
    #>

    # You could add a precmd-like hook here if needed
    # For now, just call the original prompt

    if ($script:OriginalPrompt) {
        & $script:OriginalPrompt
    }
    else {
        "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
    }
}

#endregion

#region Tool Aliases

# SSH Tools
function ssh-keys { dotfiles tools ssh keys @args }
function ssh-gen { dotfiles tools ssh gen @args }
function ssh-list { dotfiles tools ssh list @args }
function ssh-agent-status { dotfiles tools ssh agent @args }
function ssh-fp { dotfiles tools ssh fp @args }
function ssh-tunnel { dotfiles tools ssh tunnel @args }
function ssh-socks { dotfiles tools ssh socks @args }
function ssh-status { dotfiles tools ssh status @args }

# AWS Tools
function aws-profiles { dotfiles tools aws profiles @args }
function aws-who { dotfiles tools aws who @args }
function aws-login { dotfiles tools aws login @args }
function aws-switch {
    $result = dotfiles tools aws switch @args
    if ($LASTEXITCODE -eq 0 -and $result) {
        # Execute the export command (convert to PowerShell syntax)
        $result | ForEach-Object {
            if ($_ -match '^export (\w+)=(.*)$') {
                Set-Item -Path "env:$($Matches[1])" -Value $Matches[2]
            }
        }
    }
}
function aws-assume {
    $result = dotfiles tools aws assume @args
    if ($LASTEXITCODE -eq 0 -and $result) {
        $result | ForEach-Object {
            if ($_ -match '^export (\w+)=(.*)$') {
                Set-Item -Path "env:$($Matches[1])" -Value $Matches[2]
            }
        }
    }
}
function aws-clear {
    Remove-Item env:AWS_ACCESS_KEY_ID -ErrorAction SilentlyContinue
    Remove-Item env:AWS_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue
    Remove-Item env:AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
    Write-Host "Cleared AWS temporary credentials" -ForegroundColor Green
}
function aws-status { dotfiles tools aws status @args }

# CDK Tools
function cdk-init { dotfiles tools cdk init @args }
function cdk-env {
    $result = dotfiles tools cdk env @args
    if ($LASTEXITCODE -eq 0 -and $result) {
        $result | ForEach-Object {
            if ($_ -match '^export (\w+)=(.*)$') {
                Set-Item -Path "env:$($Matches[1])" -Value $Matches[2]
            }
        }
    }
}
function cdk-env-clear {
    Remove-Item env:CDK_DEFAULT_ACCOUNT -ErrorAction SilentlyContinue
    Remove-Item env:CDK_DEFAULT_REGION -ErrorAction SilentlyContinue
    Write-Host "Cleared CDK environment variables" -ForegroundColor Green
}
function cdk-outputs { dotfiles tools cdk outputs @args }
function cdk-context { dotfiles tools cdk context @args }
function cdk-status { dotfiles tools cdk status @args }

# Go Tools
function go-new { dotfiles tools go new @args }
function go-init { dotfiles tools go init @args }
function go-test { dotfiles tools go test @args }
function go-cover { dotfiles tools go cover @args }
function go-lint { dotfiles tools go lint @args }
function go-outdated { dotfiles tools go outdated @args }
function go-update { dotfiles tools go update @args }
function go-build-all { dotfiles tools go build-all @args }
function go-bench { dotfiles tools go bench @args }
function go-info { dotfiles tools go info @args }

# Rust Tools
function rust-new { dotfiles tools rust new @args }
function rust-update { dotfiles tools rust update @args }
function rust-switch { dotfiles tools rust switch @args }
function rust-lint { dotfiles tools rust lint @args }
function rust-fix { dotfiles tools rust fix @args }
function rust-outdated { dotfiles tools rust outdated @args }
function rust-expand { dotfiles tools rust expand @args }
function rust-info { dotfiles tools rust info @args }

# Python Tools
function py-new { dotfiles tools python new @args }
function py-clean { dotfiles tools python clean @args }
function py-venv { dotfiles tools python venv @args }
function py-test { dotfiles tools python test @args }
function py-cover { dotfiles tools python cover @args }
function py-info { dotfiles tools python info @args }

#endregion

#region Core Dotfiles Commands

function dotfiles-status { dotfiles status @args }
function dotfiles-doctor { dotfiles doctor @args }
function dotfiles-setup { dotfiles setup @args }
function dotfiles-features { dotfiles features @args }
function dotfiles-vault { dotfiles vault @args }
function dotfiles-hook { dotfiles hook @args }

# Short alias
Set-Alias -Name d -Value dotfiles -Scope Global

#endregion

#region Module Initialization

function Initialize-Dotfiles {
    <#
    .SYNOPSIS
        Initialize dotfiles module and run shell_init hook
    #>

    if (-not (Test-DotfilesCli)) {
        Write-Warning "dotfiles CLI not found in PATH. Some features will be unavailable."
        Write-Warning "Install from: https://github.com/blackwell-systems/dotfiles"
        return
    }

    # Store initial directory
    $script:DotfilesLastDirectory = Get-Location

    # Run shell_init hook
    Invoke-DotfilesHook -Point "shell_init"

    Write-Verbose "Dotfiles PowerShell module initialized"
}

#endregion

#region Exports

Export-ModuleMember -Function @(
    # Hooks
    'Invoke-DotfilesHook',
    'Enable-DotfilesHooks',
    'Disable-DotfilesHooks',

    # Utilities
    'Get-DotfilesPath',
    'Test-DotfilesCli',
    'Initialize-Dotfiles',

    # CD wrapper
    'Set-LocationWithHook',

    # SSH aliases
    'ssh-keys', 'ssh-gen', 'ssh-list', 'ssh-agent-status',
    'ssh-fp', 'ssh-tunnel', 'ssh-socks', 'ssh-status',

    # AWS aliases
    'aws-profiles', 'aws-who', 'aws-login', 'aws-switch',
    'aws-assume', 'aws-clear', 'aws-status',

    # CDK aliases
    'cdk-init', 'cdk-env', 'cdk-env-clear',
    'cdk-outputs', 'cdk-context', 'cdk-status',

    # Go aliases
    'go-new', 'go-init', 'go-test', 'go-cover', 'go-lint',
    'go-outdated', 'go-update', 'go-build-all', 'go-bench', 'go-info',

    # Rust aliases
    'rust-new', 'rust-update', 'rust-switch', 'rust-lint',
    'rust-fix', 'rust-outdated', 'rust-expand', 'rust-info',

    # Python aliases
    'py-new', 'py-clean', 'py-venv', 'py-test', 'py-cover', 'py-info',

    # Core commands
    'dotfiles-status', 'dotfiles-doctor', 'dotfiles-setup',
    'dotfiles-features', 'dotfiles-vault', 'dotfiles-hook'
)

Export-ModuleMember -Alias @('cd', 'd')

#endregion

# Auto-initialize when module is imported
Initialize-Dotfiles
