#Requires -Version 5.1
<#
.SYNOPSIS
    Dotfiles PowerShell module - Cross-platform hooks and aliases for Windows

.DESCRIPTION
    This module provides PowerShell equivalents of ZSH dotfiles functionality:
    - Full lifecycle hooks system (24 hook points)
    - File-based, function-based, and JSON-configured hooks
    - Aliases for dotfiles tools commands
    - Integration with the Go CLI

.NOTES
    Author: Dotfiles
    Requires: dotfiles Go CLI in PATH
#>

# ============================================================
# Module-level state
# ============================================================
$script:DotfilesLastDirectory = $null
$script:DotfilesHooksEnabled = $true

# Hook storage: registered PowerShell functions
$script:RegisteredHooks = @{}

# Cross-platform home directory (works on Windows, Linux, macOS)
$script:HomeDir = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($env:HOME) { $env:HOME } else { "~" }

# ============================================================
# Configuration
# ============================================================

# All valid hook points (must match ZSH exactly)
$script:HOOK_POINTS = @(
    # Lifecycle
    'pre_install', 'post_install',
    'pre_bootstrap', 'post_bootstrap',
    'pre_upgrade', 'post_upgrade',

    # Vault
    'pre_vault_pull', 'post_vault_pull',
    'pre_vault_push', 'post_vault_push',

    # Doctor
    'pre_doctor', 'post_doctor', 'doctor_check',

    # Shell
    'shell_init', 'shell_exit', 'directory_change',

    # Setup
    'pre_setup_phase', 'post_setup_phase', 'setup_complete',

    # Template
    'pre_template_render', 'post_template_render',

    # Encryption
    'pre_encrypt', 'post_decrypt'
)

# Hook point to parent feature mapping
$script:HOOK_FEATURE_MAP = @{
    'pre_vault_pull'        = 'vault'
    'post_vault_pull'       = 'vault'
    'pre_vault_push'        = 'vault'
    'post_vault_push'       = 'vault'
    'pre_template_render'   = 'templates'
    'post_template_render'  = 'templates'
    'pre_encrypt'           = 'encryption'
    'post_decrypt'          = 'encryption'
}

# Configuration paths (cross-platform)
$script:HOOKS_DIR = if ($env:DOTFILES_HOOKS_DIR) {
    $env:DOTFILES_HOOKS_DIR
} elseif ($script:HomeDir) {
    Join-Path $script:HomeDir ".config/dotfiles/hooks"
} else {
    $null
}

$script:HOOKS_CONFIG = if ($env:DOTFILES_HOOKS_CONFIG) {
    $env:DOTFILES_HOOKS_CONFIG
} elseif ($script:HomeDir) {
    Join-Path $script:HomeDir ".config/dotfiles/hooks.json"
} else {
    $null
}

# Settings (can be overridden by env vars or JSON config)
$script:HOOKS_FAIL_FAST = if ($env:DOTFILES_HOOKS_FAIL_FAST -eq 'true') { $true } else { $false }
$script:HOOKS_VERBOSE = if ($env:DOTFILES_HOOKS_VERBOSE -eq 'true') { $true } else { $false }
$script:HOOKS_TIMEOUT = if ($env:DOTFILES_HOOKS_TIMEOUT) { [int]$env:DOTFILES_HOOKS_TIMEOUT } else { 30 }

#region Utility Functions

function Get-DotfilesPath {
    <#
    .SYNOPSIS
        Get the dotfiles installation directory (cross-platform)
    #>
    if ($env:DOTFILES_DIR) {
        return $env:DOTFILES_DIR
    }

    # Cross-platform candidates
    $home = $script:HomeDir
    if (-not $home) { return $null }

    $candidates = @(
        (Join-Path $home "workspace/dotfiles"),
        (Join-Path $home "dotfiles"),
        (Join-Path $home ".dotfiles")
    )

    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path -ErrorAction SilentlyContinue)) {
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

function Test-HookPoint {
    <#
    .SYNOPSIS
        Validate a hook point name
    #>
    param([string]$Point)

    return $script:HOOK_POINTS -contains $Point
}

#endregion

#region Hook System Core

function Register-DotfilesHook {
    <#
    .SYNOPSIS
        Register a PowerShell function as a hook

    .PARAMETER Point
        The hook point to register for

    .PARAMETER ScriptBlock
        The script block to execute

    .PARAMETER Name
        Optional name for the hook (defaults to auto-generated)

    .EXAMPLE
        Register-DotfilesHook -Point "post_vault_pull" -ScriptBlock { ssh-add ~/.ssh/id_ed25519 }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Point,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [string]$Name
    )

    if (-not (Test-HookPoint $Point)) {
        Write-Error "Invalid hook point: $Point. Valid points: $($script:HOOK_POINTS -join ', ')"
        return
    }

    if (-not $Name) {
        $Name = "hook-$(Get-Random)"
    }

    if (-not $script:RegisteredHooks.ContainsKey($Point)) {
        $script:RegisteredHooks[$Point] = @()
    }

    # Check for duplicate (idempotent)
    $existing = $script:RegisteredHooks[$Point] | Where-Object { $_.Name -eq $Name }
    if ($existing) {
        if ($script:HOOKS_VERBOSE) {
            Write-Verbose "Hook already registered: $Point -> $Name"
        }
        return
    }

    $script:RegisteredHooks[$Point] += @{
        Name = $Name
        ScriptBlock = $ScriptBlock
    }

    if ($script:HOOKS_VERBOSE) {
        Write-Verbose "Registered hook: $Point -> $Name"
    }
}

function Unregister-DotfilesHook {
    <#
    .SYNOPSIS
        Unregister a hook by name

    .PARAMETER Point
        The hook point

    .PARAMETER Name
        The hook name to remove
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Point,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($script:RegisteredHooks.ContainsKey($Point)) {
        $script:RegisteredHooks[$Point] = $script:RegisteredHooks[$Point] | Where-Object { $_.Name -ne $Name }
    }
}

function Invoke-DotfilesHook {
    <#
    .SYNOPSIS
        Run all hooks for a point

    .PARAMETER Point
        The hook point to run

    .PARAMETER Arguments
        Additional arguments to pass to hooks

    .PARAMETER Verbose
        Show detailed output

    .PARAMETER NoHooks
        Skip hook execution entirely

    .EXAMPLE
        Invoke-DotfilesHook -Point "shell_init"
        Invoke-DotfilesHook -Point "post_vault_pull" -Verbose
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Point,

        [object[]]$Arguments = @(),

        [switch]$NoHooks,

        [switch]$VerboseOutput
    )

    $localVerbose = $VerboseOutput -or $script:HOOKS_VERBOSE

    # Skip if --no-hooks
    if ($NoHooks) {
        if ($localVerbose) { Write-Host "hook_run: skipped via -NoHooks" -ForegroundColor Gray }
        return $true
    }

    # Master disable check
    if (-not $script:DotfilesHooksEnabled -or $env:DOTFILES_HOOKS_DISABLED -eq 'true') {
        if ($localVerbose) { Write-Host "hook_run: hooks disabled globally" -ForegroundColor Gray }
        return $true
    }

    # Validate hook point
    if (-not (Test-HookPoint $Point)) {
        Write-Error "Invalid hook point: $Point"
        return $false
    }

    # Check parent feature (if dotfiles CLI available)
    $parentFeature = $script:HOOK_FEATURE_MAP[$Point]
    if ($parentFeature -and (Test-DotfilesCli)) {
        $featureCheck = & dotfiles features check $parentFeature 2>$null
        if ($LASTEXITCODE -ne 0) {
            if ($localVerbose) {
                Write-Host "hook_run: parent feature '$parentFeature' disabled for $Point" -ForegroundColor Gray
            }
            return $true
        }
    }

    if ($localVerbose) {
        Write-Host "hook_run: running hooks for $Point" -ForegroundColor Cyan
    }

    $failed = $false

    # 1. Run file-based hooks (from hooks directory)
    $pointDir = Join-Path $script:HOOKS_DIR $Point
    if (Test-Path $pointDir) {
        $scripts = Get-ChildItem -Path $pointDir -Filter "*.ps1" | Sort-Object Name

        foreach ($scriptFile in $scripts) {
            if ($localVerbose) {
                Write-Host "  Executing: $($scriptFile.Name)" -ForegroundColor Gray
            }

            try {
                $job = Start-Job -FilePath $scriptFile.FullName -ArgumentList $Arguments
                $completed = Wait-Job $job -Timeout $script:HOOKS_TIMEOUT

                if (-not $completed) {
                    Stop-Job $job
                    Remove-Job $job -Force
                    Write-Warning "Hook timed out: $($scriptFile.Name)"
                    $failed = $true
                } else {
                    $result = Receive-Job $job
                    Remove-Job $job
                    if ($job.State -eq 'Failed') {
                        Write-Warning "Hook failed: $($scriptFile.Name)"
                        $failed = $true
                    }
                }

                if ($failed -and $script:HOOKS_FAIL_FAST) {
                    Write-Host "hook_run: stopping (fail_fast=true)" -ForegroundColor Red
                    return $false
                }
            }
            catch {
                Write-Warning "Hook failed: $($scriptFile.Name) - $_"
                $failed = $true
                if ($script:HOOKS_FAIL_FAST) {
                    return $false
                }
            }
        }
    }

    # 2. Run registered PowerShell function hooks
    if ($script:RegisteredHooks.ContainsKey($Point)) {
        foreach ($hook in $script:RegisteredHooks[$Point]) {
            if ($localVerbose) {
                Write-Host "  Executing function: $($hook.Name)" -ForegroundColor Gray
            }

            try {
                & $hook.ScriptBlock @Arguments
            }
            catch {
                Write-Warning "Hook function failed: $($hook.Name) - $_"
                $failed = $true
                if ($script:HOOKS_FAIL_FAST) {
                    return $false
                }
            }
        }
    }

    # 3. Run JSON-configured hooks
    if (Test-Path $script:HOOKS_CONFIG) {
        try {
            $config = Get-Content $script:HOOKS_CONFIG -Raw | ConvertFrom-Json
            $pointHooks = $config.hooks.$Point

            if ($pointHooks) {
                foreach ($hookDef in $pointHooks) {
                    # Check if enabled
                    if ($null -ne $hookDef.enabled -and -not $hookDef.enabled) {
                        continue
                    }

                    $hookName = if ($hookDef.name) { $hookDef.name } else { "json-hook" }

                    if ($localVerbose) {
                        Write-Host "  Executing JSON hook: $hookName" -ForegroundColor Gray
                    }

                    try {
                        if ($hookDef.command) {
                            Invoke-Expression $hookDef.command
                        }
                        elseif ($hookDef.script) {
                            $scriptPath = $hookDef.script -replace '~', $env:USERPROFILE
                            if (Test-Path $scriptPath) {
                                & $scriptPath @Arguments
                            } else {
                                Write-Warning "Hook script not found: $scriptPath"
                                $failed = $true
                            }
                        }
                    }
                    catch {
                        if (-not $hookDef.fail_ok) {
                            Write-Warning "JSON hook failed: $hookName - $_"
                            $failed = $true
                            if ($script:HOOKS_FAIL_FAST) {
                                return $false
                            }
                        } elseif ($localVerbose) {
                            Write-Host "  $hookName failed but fail_ok=true" -ForegroundColor Yellow
                        }
                    }
                }
            }
        }
        catch {
            if ($localVerbose) {
                Write-Host "  Could not parse hooks.json: $_" -ForegroundColor Yellow
            }
        }
    }

    # 4. Also call Go CLI hook run (for file-based .sh/.zsh hooks)
    if (Test-DotfilesCli) {
        try {
            $verboseFlag = if ($localVerbose) { "--verbose" } else { "" }
            if ($verboseFlag) {
                & dotfiles hook run $verboseFlag $Point @Arguments 2>&1 | Out-Null
            } else {
                & dotfiles hook run $Point @Arguments 2>&1 | Out-Null
            }
        }
        catch {
            # Ignore CLI errors for shell hooks
        }
    }

    return -not $failed
}

function Get-DotfilesHook {
    <#
    .SYNOPSIS
        List hooks for a point or all points

    .PARAMETER Point
        Optional specific hook point to list
    #>
    [CmdletBinding()]
    param(
        [string]$Point
    )

    if ($Point) {
        if (-not (Test-HookPoint $Point)) {
            Write-Error "Invalid hook point: $Point"
            return
        }

        Write-Host "`nHooks for: $Point" -ForegroundColor Cyan
        Write-Host ("=" * 60)

        $hasHooks = $false

        # File-based hooks
        $pointDir = Join-Path $script:HOOKS_DIR $Point
        if (Test-Path $pointDir) {
            $scripts = Get-ChildItem -Path $pointDir -Filter "*.ps1" -ErrorAction SilentlyContinue
            if ($scripts) {
                Write-Host "`nFile-based hooks: ($pointDir)" -ForegroundColor Yellow
                foreach ($s in $scripts) {
                    $hasHooks = $true
                    Write-Host "  + $($s.Name)" -ForegroundColor Green
                }
            }
        }

        # Registered functions
        if ($script:RegisteredHooks.ContainsKey($Point) -and $script:RegisteredHooks[$Point].Count -gt 0) {
            Write-Host "`nRegistered functions:" -ForegroundColor Yellow
            foreach ($h in $script:RegisteredHooks[$Point]) {
                $hasHooks = $true
                Write-Host "  + $($h.Name)" -ForegroundColor Green
            }
        }

        # JSON config
        if (Test-Path $script:HOOKS_CONFIG) {
            try {
                $config = Get-Content $script:HOOKS_CONFIG -Raw | ConvertFrom-Json
                $pointHooks = $config.hooks.$Point
                if ($pointHooks) {
                    Write-Host "`nJSON configured: ($($script:HOOKS_CONFIG))" -ForegroundColor Yellow
                    foreach ($h in $pointHooks) {
                        $hasHooks = $true
                        $status = if ($h.enabled -eq $false) { "o" } else { "+" }
                        $color = if ($h.enabled -eq $false) { "Gray" } else { "Green" }
                        $name = if ($h.name) { $h.name } else { "unnamed" }
                        Write-Host "  $status $name" -ForegroundColor $color
                    }
                }
            }
            catch {}
        }

        if (-not $hasHooks) {
            Write-Host "`nNo hooks registered for this point." -ForegroundColor Gray
        }
    }
    else {
        # List all hook points
        Write-Host "`nHook System" -ForegroundColor Cyan
        Write-Host ("=" * 60)

        $categories = @{
            'Lifecycle' = @('pre_install', 'post_install', 'pre_bootstrap', 'post_bootstrap', 'pre_upgrade', 'post_upgrade')
            'Vault' = @('pre_vault_pull', 'post_vault_pull', 'pre_vault_push', 'post_vault_push')
            'Doctor' = @('pre_doctor', 'post_doctor', 'doctor_check')
            'Shell' = @('shell_init', 'shell_exit', 'directory_change')
            'Setup' = @('pre_setup_phase', 'post_setup_phase', 'setup_complete')
            'Template' = @('pre_template_render', 'post_template_render')
            'Encryption' = @('pre_encrypt', 'post_decrypt')
        }

        foreach ($cat in $categories.Keys) {
            Write-Host "`n$cat" -ForegroundColor Cyan
            Write-Host ("-" * 60)

            foreach ($p in $categories[$cat]) {
                $count = 0

                # Count file-based
                $pointDir = Join-Path $script:HOOKS_DIR $p
                if (Test-Path $pointDir) {
                    $count += (Get-ChildItem -Path $pointDir -Filter "*.ps1" -ErrorAction SilentlyContinue).Count
                }

                # Count registered
                if ($script:RegisteredHooks.ContainsKey($p)) {
                    $count += $script:RegisteredHooks[$p].Count
                }

                # Count JSON
                if (Test-Path $script:HOOKS_CONFIG) {
                    try {
                        $config = Get-Content $script:HOOKS_CONFIG -Raw | ConvertFrom-Json
                        if ($config.hooks.$p) {
                            $count += $config.hooks.$p.Count
                        }
                    }
                    catch {}
                }

                if ($count -gt 0) {
                    Write-Host "  + $($p.PadRight(25)) $count hook(s)" -ForegroundColor Green
                }
                else {
                    Write-Host "  o $($p.PadRight(25)) no hooks" -ForegroundColor Gray
                }
            }
        }
    }
}

function Get-DotfilesHookPoints {
    <#
    .SYNOPSIS
        List all available hook points with descriptions
    #>
    Write-Host "`nAvailable Hook Points" -ForegroundColor Cyan
    Write-Host ("=" * 60)

    $descriptions = @{
        'pre_install' = 'Before install.sh runs'
        'post_install' = 'After install.sh completes'
        'pre_bootstrap' = 'Before bootstrap script'
        'post_bootstrap' = 'After bootstrap completes'
        'pre_upgrade' = 'Before dotfiles upgrade'
        'post_upgrade' = 'After upgrade completes'
        'pre_vault_pull' = 'Before restoring secrets'
        'post_vault_pull' = 'After secrets restored (e.g., ssh-add)'
        'pre_vault_push' = 'Before syncing to vault'
        'post_vault_push' = 'After vault sync'
        'pre_doctor' = 'Before health check'
        'post_doctor' = 'After health check'
        'doctor_check' = 'During doctor (custom checks)'
        'shell_init' = 'Shell startup (PowerShell profile load)'
        'shell_exit' = 'Shell exit'
        'directory_change' = 'After cd (auto-activate envs)'
        'pre_setup_phase' = 'Before each wizard phase'
        'post_setup_phase' = 'After each wizard phase'
        'setup_complete' = 'After all phases done'
        'pre_template_render' = 'Before template rendering'
        'post_template_render' = 'After templates rendered'
        'pre_encrypt' = 'Before file encryption'
        'post_decrypt' = 'After file decryption'
    }

    $categories = @(
        @{ Name = 'Lifecycle'; Points = @('pre_install', 'post_install', 'pre_bootstrap', 'post_bootstrap', 'pre_upgrade', 'post_upgrade') }
        @{ Name = 'Vault'; Points = @('pre_vault_pull', 'post_vault_pull', 'pre_vault_push', 'post_vault_push') }
        @{ Name = 'Doctor'; Points = @('pre_doctor', 'post_doctor', 'doctor_check') }
        @{ Name = 'Shell'; Points = @('shell_init', 'shell_exit', 'directory_change') }
        @{ Name = 'Setup'; Points = @('pre_setup_phase', 'post_setup_phase', 'setup_complete') }
        @{ Name = 'Template'; Points = @('pre_template_render', 'post_template_render') }
        @{ Name = 'Encryption'; Points = @('pre_encrypt', 'post_decrypt') }
    )

    foreach ($cat in $categories) {
        Write-Host "`n$($cat.Name) Hooks" -ForegroundColor Cyan
        foreach ($p in $cat.Points) {
            Write-Host "  $($p.PadRight(25)) $($descriptions[$p])" -ForegroundColor Gray
        }
    }
}

function Add-DotfilesHook {
    <#
    .SYNOPSIS
        Add a hook script to a point

    .PARAMETER Point
        The hook point

    .PARAMETER ScriptPath
        Path to the script to add
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Point,

        [Parameter(Mandatory)]
        [string]$ScriptPath
    )

    if (-not (Test-HookPoint $Point)) {
        Write-Error "Invalid hook point: $Point"
        return
    }

    if (-not (Test-Path $ScriptPath)) {
        Write-Error "Script not found: $ScriptPath"
        return
    }

    $pointDir = Join-Path $script:HOOKS_DIR $Point
    if (-not (Test-Path $pointDir)) {
        New-Item -Path $pointDir -ItemType Directory -Force | Out-Null
    }

    $destPath = Join-Path $pointDir (Split-Path $ScriptPath -Leaf)
    Copy-Item -Path $ScriptPath -Destination $destPath -Force

    Write-Host "Added hook: $destPath" -ForegroundColor Green
    Write-Host "Hook will run during: $Point" -ForegroundColor Gray
}

function Remove-DotfilesHook {
    <#
    .SYNOPSIS
        Remove a hook script from a point

    .PARAMETER Point
        The hook point

    .PARAMETER Name
        The hook script name to remove
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Point,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $hookPath = Join-Path $script:HOOKS_DIR $Point $Name

    if (Test-Path $hookPath) {
        Remove-Item $hookPath -Force
        Write-Host "Removed hook: $hookPath" -ForegroundColor Green
    }
    else {
        Write-Error "Hook not found: $hookPath"
    }
}

function Test-DotfilesHook {
    <#
    .SYNOPSIS
        Test hooks for a point (verbose dry-run style)

    .PARAMETER Point
        The hook point to test
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Point
    )

    Write-Host "`nTesting hooks for: $Point" -ForegroundColor Cyan
    Write-Host ("=" * 60)

    Get-DotfilesHook -Point $Point

    Write-Host "`n" + ("-" * 60)
    Write-Host "Executing with verbose:" -ForegroundColor Yellow
    Write-Host ""

    $result = Invoke-DotfilesHook -Point $Point -VerboseOutput

    Write-Host ""
    if ($result) {
        Write-Host "All hooks completed successfully" -ForegroundColor Green
    }
    else {
        Write-Host "One or more hooks failed" -ForegroundColor Red
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

    if ($Path) {
        Microsoft.PowerShell.Management\Set-Location -Path $Path -PassThru:$PassThru
    }
    else {
        Microsoft.PowerShell.Management\Set-Location -PassThru:$PassThru
    }

    $currentLocation = Get-Location

    if ($previousLocation.Path -ne $currentLocation.Path) {
        $env:DOTFILES_PREVIOUS_DIR = $previousLocation.Path
        $env:DOTFILES_CURRENT_DIR = $currentLocation.Path
        Invoke-DotfilesHook -Point "directory_change" | Out-Null
    }
}

# Try to override cd alias for directory change hooks
# On some PowerShell versions, cd is AllScope and can't be overridden
try {
    Set-Alias -Name cd -Value Set-LocationWithHook -Scope Global -Force -ErrorAction Stop
} catch {
    # Silently continue - cd will use built-in behavior
    # Users can call Set-LocationWithHook explicitly or use sl alias
}

#endregion

#region Shell Exit Hook

$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    if ($script:DotfilesHooksEnabled) {
        Invoke-DotfilesHook -Point "shell_exit" | Out-Null
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
function ssh-copy { dotfiles tools ssh copy @args }

# AWS Tools
function aws-profiles { dotfiles tools aws profiles @args }
function aws-who { dotfiles tools aws who @args }
function aws-login { dotfiles tools aws login @args }
function aws-switch {
    $result = dotfiles tools aws switch @args
    if ($LASTEXITCODE -eq 0 -and $result) {
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

# Docker Tools
function docker-ps { dotfiles tools docker ps @args }
function docker-images { dotfiles tools docker images @args }
function docker-ip { dotfiles tools docker ip @args }
function docker-env { dotfiles tools docker env @args }
function docker-ports { dotfiles tools docker ports @args }
function docker-stats { dotfiles tools docker stats @args }
function docker-vols { dotfiles tools docker vols @args }
function docker-nets { dotfiles tools docker nets @args }
function docker-inspect { dotfiles tools docker inspect @args }
function docker-clean { dotfiles tools docker clean @args }
function docker-prune { dotfiles tools docker prune @args }
function docker-status { dotfiles tools docker status @args }

# Claude Tools
function claude-status { dotfiles tools claude status @args }
function claude-env { dotfiles tools claude env @args }
function claude-init { dotfiles tools claude init @args }
function claude-bedrock {
    <#
    .SYNOPSIS
        Configure environment for AWS Bedrock backend
    .DESCRIPTION
        Sets environment variables for Claude Code to use AWS Bedrock.
        Use -Eval to set the variables in the current session.
    #>
    param(
        [switch]$Eval
    )

    if ($Eval) {
        # Get the exports and set them
        $output = dotfiles tools claude bedrock --eval 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error $output
            return
        }
        foreach ($line in $output -split "`n") {
            if ($line -match '^export\s+(\w+)=''?([^'']*?)''?$') {
                $varName = $matches[1]
                $varValue = $matches[2]
                Set-Item -Path "Env:$varName" -Value $varValue
                Write-Host "Set $varName" -ForegroundColor Green
            }
        }
        Write-Host "`nClaude Code configured for AWS Bedrock" -ForegroundColor Cyan
    } else {
        dotfiles tools claude bedrock @args
    }
}
function claude-max {
    <#
    .SYNOPSIS
        Configure environment for Anthropic Max backend
    .DESCRIPTION
        Clears Bedrock-related environment variables to use Max subscription.
        Use -Eval to clear the variables in the current session.
    #>
    param(
        [switch]$Eval
    )

    if ($Eval) {
        # Get the unsets and apply them
        $output = dotfiles tools claude max --eval 2>&1
        foreach ($line in $output -split "`n") {
            if ($line -match '^unset\s+(\w+)$') {
                $varName = $matches[1]
                Remove-Item -Path "Env:$varName" -ErrorAction SilentlyContinue
                Write-Host "Cleared $varName" -ForegroundColor Yellow
            }
        }
        Write-Host "`nClaude Code configured for Anthropic Max" -ForegroundColor Cyan
    } else {
        dotfiles tools claude max @args
    }
}
function claude-switch {
    <#
    .SYNOPSIS
        Switch Claude Code backend interactively or by name
    .EXAMPLE
        claude-switch              # Interactive selection
        claude-switch bedrock      # Switch to Bedrock
        claude-switch max          # Switch to Max
    #>
    param(
        [Parameter(Position = 0)]
        [ValidateSet('bedrock', 'max')]
        [string]$Backend
    )

    if ($Backend) {
        switch ($Backend) {
            'bedrock' { claude-bedrock -Eval }
            'max' { claude-max -Eval }
        }
    } else {
        Write-Host "Claude Code Backend Selection" -ForegroundColor Cyan
        Write-Host "=============================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1) bedrock - AWS Bedrock"
        Write-Host "2) max     - Anthropic Max subscription"
        Write-Host ""
        $choice = Read-Host "Select backend [1-2]"

        switch ($choice) {
            '1' { claude-bedrock -Eval }
            'bedrock' { claude-bedrock -Eval }
            '2' { claude-max -Eval }
            'max' { claude-max -Eval }
            default { Write-Error "Invalid selection: $choice" }
        }
    }
}

# Claude convenience aliases (matching ZSH cbed/cmax/cm)
# Note: Using 'cbed' instead of 'cb' to avoid collision with Rust's cargo-build alias
Set-Alias -Name cbed -Value claude-bedrock -Scope Global -Force
Set-Alias -Name cmax -Value claude-max -Scope Global -Force
Set-Alias -Name cm -Value claude-max -Scope Global -Force  # Alias for cmax

# Tool Group Aliases
# These expose the full tool category as a single command
# Usage: sshtools keys, awstools profiles, cdktools status, etc.
function sshtools    { dotfiles tools ssh @args }
function awstools    { dotfiles tools aws @args }
function cdktools    { dotfiles tools cdk @args }
function gotools     { dotfiles tools go @args }
function rusttools   { dotfiles tools rust @args }
function pytools     { dotfiles tools python @args }
function dockertools { dotfiles tools docker @args }
function claudetools { dotfiles tools claude @args }

#endregion

#region Core Dotfiles Commands

function dotfiles-status { dotfiles status @args }
function dotfiles-doctor { dotfiles doctor @args }
function dotfiles-setup { dotfiles setup @args }
function dotfiles-vault { dotfiles vault @args }
function dotfiles-hook { dotfiles hook @args }

function dotfiles-features {
    <#
    .SYNOPSIS
        Wrapper for dotfiles features that auto-reloads module after changes
    .DESCRIPTION
        When enabling, disabling, or applying presets, the module is automatically
        reloaded to apply the changes. This is safe in PowerShell (just reloads
        the module). ZSH users need to manually run 'exec zsh'.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Subcommand,

        [Parameter(ValueFromRemainingArguments = $true)]
        $RemainingArgs
    )

    # Run the actual command
    if ($Subcommand) {
        & dotfiles features $Subcommand @RemainingArgs
    } else {
        & dotfiles features
    }
    $exitCode = $LASTEXITCODE

    # Auto-reload module after enable/disable/preset to apply changes
    if ($exitCode -eq 0 -and $Subcommand -match '^(enable|disable|preset)$') {
        Write-Host ""
        Write-Host "Reloading module to apply feature changes..." -ForegroundColor Yellow
        Import-Module Dotfiles -Force -Global
    }

    return $exitCode
}

# Wrapper function that handles feature commands with auto-reload
function Invoke-Dotfiles {
    <#
    .SYNOPSIS
        Main dotfiles wrapper with feature change detection
    .DESCRIPTION
        Wraps the dotfiles CLI. When 'features enable/disable/preset' is used,
        auto-reloads the PowerShell module to apply changes. This is safe in
        PowerShell (Import-Module -Force just reloads, doesn't replace shell).
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Command,

        [Parameter(ValueFromRemainingArguments = $true)]
        $RemainingArgs
    )

    # Run the actual command
    if ($Command) {
        & dotfiles $Command @RemainingArgs
    } else {
        & dotfiles
    }
    $exitCode = $LASTEXITCODE

    # Auto-reload after feature changes
    if ($exitCode -eq 0 -and $Command -match '^(features?|feat)$') {
        $subcmd = if ($RemainingArgs.Count -gt 0) { $RemainingArgs[0] } else { "" }
        if ($subcmd -match '^(enable|disable|preset)$') {
            Write-Host ""
            Write-Host "Reloading module to apply feature changes..." -ForegroundColor Yellow
            Import-Module Dotfiles -Force -Global
        }
    }

    return $exitCode
}

Set-Alias -Name d -Value Invoke-Dotfiles -Scope Global

#endregion

#region Module Initialization

function Initialize-DotfilesHooks {
    <#
    .SYNOPSIS
        Initialize hooks system from JSON config
    #>

    if (Test-Path $script:HOOKS_CONFIG) {
        try {
            $config = Get-Content $script:HOOKS_CONFIG -Raw | ConvertFrom-Json

            if ($config.settings) {
                if ($null -ne $config.settings.fail_fast) {
                    $script:HOOKS_FAIL_FAST = $config.settings.fail_fast
                }
                if ($null -ne $config.settings.verbose) {
                    $script:HOOKS_VERBOSE = $config.settings.verbose
                }
                if ($null -ne $config.settings.timeout) {
                    $script:HOOKS_TIMEOUT = [int]$config.settings.timeout
                }
            }

            if ($script:HOOKS_VERBOSE) {
                Write-Host "hook_init: initialized (fail_fast=$($script:HOOKS_FAIL_FAST), verbose=$($script:HOOKS_VERBOSE), timeout=$($script:HOOKS_TIMEOUT))" -ForegroundColor Gray
            }
        }
        catch {
            Write-Verbose "Could not load hooks config: $_"
        }
    }
}

function Initialize-Dotfiles {
    <#
    .SYNOPSIS
        Initialize dotfiles module and run shell_init hook
    #>

    if (-not (Test-DotfilesCli)) {
        Write-Warning "dotfiles CLI not found in PATH. Some features will be unavailable."
        Write-Warning "Install from: https://github.com/blackwell-systems/dotfiles"
    }

    # Initialize hooks configuration
    Initialize-DotfilesHooks

    # Store initial directory
    $script:DotfilesLastDirectory = Get-Location

    # Run shell_init hook
    Invoke-DotfilesHook -Point "shell_init" | Out-Null

    # Initialize zoxide if available (smarter cd)
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    }

    # Initialize fnm if available (Node.js version manager)
    if (Get-Command fnm -ErrorAction SilentlyContinue) {
        fnm env --use-on-cd | Out-String | Invoke-Expression
    }

    Write-Verbose "Dotfiles PowerShell module initialized"
}

#endregion

#region Tool Integrations

function Initialize-Fnm {
    <#
    .SYNOPSIS
        Initialize fnm (Fast Node Manager) for the current session
    .DESCRIPTION
        Loads fnm environment and enables auto-switching when entering
        directories with .nvmrc or .node-version files.
    #>
    if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
        Write-Host "fnm not found. Install with: winget install Schniz.fnm" -ForegroundColor Yellow
        return
    }
    fnm env --use-on-cd | Out-String | Invoke-Expression
    Write-Host "fnm initialized" -ForegroundColor Green
}

function fnm-install {
    <#
    .SYNOPSIS
        Install a Node.js version using fnm
    #>
    param([string]$Version = "lts-latest")
    if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
        Write-Host "fnm not found. Install with: winget install Schniz.fnm" -ForegroundColor Yellow
        return
    }
    fnm install $Version
}

function fnm-use {
    <#
    .SYNOPSIS
        Switch to a Node.js version using fnm
    #>
    param([string]$Version)
    if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
        Write-Host "fnm not found. Install with: winget install Schniz.fnm" -ForegroundColor Yellow
        return
    }
    fnm use $Version
}

function fnm-list {
    <#
    .SYNOPSIS
        List installed Node.js versions
    #>
    if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
        Write-Host "fnm not found. Install with: winget install Schniz.fnm" -ForegroundColor Yellow
        return
    }
    fnm list
}

function Initialize-Zoxide {
    <#
    .SYNOPSIS
        Initialize zoxide (smarter cd) for the current session
    #>
    if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) {
        Write-Host "zoxide not found. Install with: winget install ajeetdsouza.zoxide" -ForegroundColor Yellow
        return
    }
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
    Write-Host "zoxide initialized (use 'z' to jump to directories)" -ForegroundColor Green
}

#endregion

#region Exports

Export-ModuleMember -Function @(
    # Hook system
    'Register-DotfilesHook',
    'Unregister-DotfilesHook',
    'Invoke-DotfilesHook',
    'Get-DotfilesHook',
    'Get-DotfilesHookPoints',
    'Add-DotfilesHook',
    'Remove-DotfilesHook',
    'Test-DotfilesHook',
    'Enable-DotfilesHooks',
    'Disable-DotfilesHooks',

    # Utilities
    'Get-DotfilesPath',
    'Test-DotfilesCli',
    'Test-HookPoint',
    'Initialize-Dotfiles',
    'Initialize-DotfilesHooks',

    # CD wrapper
    'Set-LocationWithHook',

    # SSH aliases
    'ssh-keys', 'ssh-gen', 'ssh-list', 'ssh-agent-status',
    'ssh-fp', 'ssh-tunnel', 'ssh-socks', 'ssh-status', 'ssh-copy',

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

    # Docker aliases
    'docker-ps', 'docker-images', 'docker-ip', 'docker-env',
    'docker-ports', 'docker-stats', 'docker-vols', 'docker-nets',
    'docker-inspect', 'docker-clean', 'docker-prune', 'docker-status',

    # Node.js (fnm) integration
    'Initialize-Fnm', 'fnm-install', 'fnm-use', 'fnm-list',

    # Zoxide integration
    'Initialize-Zoxide',

    # Core commands
    'dotfiles-status', 'dotfiles-doctor', 'dotfiles-setup',
    'dotfiles-features', 'dotfiles-vault', 'dotfiles-hook',

    # Tool group aliases (expose full tool category)
    'sshtools', 'awstools', 'cdktools', 'gotools',
    'rusttools', 'pytools', 'dockertools', 'claudetools',

    # Main wrapper (handles feature auto-reload)
    'Invoke-Dotfiles'
)

Export-ModuleMember -Alias @('cd', 'd')

#endregion

# Auto-initialize when module is imported
Initialize-Dotfiles
