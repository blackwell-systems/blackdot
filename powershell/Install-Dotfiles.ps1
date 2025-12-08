#Requires -Version 5.1
<#
.SYNOPSIS
    Install the Dotfiles PowerShell module

.DESCRIPTION
    This script installs the Dotfiles PowerShell module to your module path
    and optionally adds it to your PowerShell profile for auto-loading.

.PARAMETER ModulePath
    The path where the module should be installed.
    Defaults to the first path in $env:PSModulePath (user modules).

.PARAMETER NoProfile
    Skip modifying the PowerShell profile.

.PARAMETER Force
    Overwrite existing installation without prompting.

.EXAMPLE
    .\Install-Dotfiles.ps1
    Install the module and add to profile.

.EXAMPLE
    .\Install-Dotfiles.ps1 -NoProfile
    Install the module without modifying profile.

.EXAMPLE
    .\Install-Dotfiles.ps1 -Force
    Force reinstall, overwriting existing installation.
#>
[CmdletBinding()]
param(
    [string]$ModulePath,

    [switch]$NoProfile,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Determine source path (where this script is located)
$SourcePath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Determine target module path
if (-not $ModulePath) {
    # Use user's module path (first entry in PSModulePath)
    $userModulePath = ($env:PSModulePath -split [IO.Path]::PathSeparator)[0]

    # On Windows, typically: ~\Documents\PowerShell\Modules
    # On Linux/Mac: ~/.local/share/powershell/Modules
    $ModulePath = Join-Path $userModulePath "Dotfiles"
}

Write-Host "Dotfiles PowerShell Module Installer" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if dotfiles CLI is available
$dotfilesCli = Get-Command "dotfiles" -ErrorAction SilentlyContinue
if ($dotfilesCli) {
    Write-Host "[OK] dotfiles CLI found: $($dotfilesCli.Source)" -ForegroundColor Green
}
else {
    Write-Host "[WARN] dotfiles CLI not found in PATH" -ForegroundColor Yellow
    Write-Host "       Some features will be unavailable until you install it." -ForegroundColor Yellow
    Write-Host "       See: https://github.com/blackwell-systems/dotfiles" -ForegroundColor Yellow
    Write-Host ""
}

# Check if module already exists
if (Test-Path $ModulePath) {
    if ($Force) {
        Write-Host "Removing existing installation at: $ModulePath" -ForegroundColor Yellow
        Remove-Item -Path $ModulePath -Recurse -Force
    }
    else {
        $response = Read-Host "Module already exists at $ModulePath. Overwrite? (y/N)"
        if ($response -notmatch '^[Yy]') {
            Write-Host "Installation cancelled." -ForegroundColor Yellow
            exit 0
        }
        Remove-Item -Path $ModulePath -Recurse -Force
    }
}

# Create module directory
Write-Host "Installing module to: $ModulePath" -ForegroundColor Cyan
New-Item -Path $ModulePath -ItemType Directory -Force | Out-Null

# Copy module files
$filesToCopy = @(
    'Dotfiles.psm1',
    'Dotfiles.psd1'
)

foreach ($file in $filesToCopy) {
    $source = Join-Path $SourcePath $file
    $dest = Join-Path $ModulePath $file

    if (Test-Path $source) {
        Copy-Item -Path $source -Destination $dest -Force
        Write-Host "  Copied: $file" -ForegroundColor Gray
    }
    else {
        Write-Warning "Source file not found: $source"
    }
}

Write-Host "[OK] Module installed successfully" -ForegroundColor Green
Write-Host ""

# Update PowerShell profile
if (-not $NoProfile) {
    Write-Host "Updating PowerShell profile..." -ForegroundColor Cyan

    # Determine profile path
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not $profilePath) {
        $profilePath = $PROFILE
    }

    # Create profile if it doesn't exist
    if (-not (Test-Path $profilePath)) {
        New-Item -Path $profilePath -ItemType File -Force | Out-Null
        Write-Host "  Created profile: $profilePath" -ForegroundColor Gray
    }

    # Check if already imported
    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    $importLine = "Import-Module Dotfiles"

    if ($profileContent -and $profileContent.Contains($importLine)) {
        Write-Host "  Profile already imports Dotfiles module" -ForegroundColor Gray
    }
    else {
        # Add import line
        $linesToAdd = @(
            "",
            "# Dotfiles PowerShell module - cross-platform hooks and aliases",
            $importLine
        )

        Add-Content -Path $profilePath -Value ($linesToAdd -join "`n")
        Write-Host "  Added module import to: $profilePath" -ForegroundColor Gray
    }

    Write-Host "[OK] Profile updated" -ForegroundColor Green
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "To use now, run:" -ForegroundColor Cyan
Write-Host "  Import-Module Dotfiles" -ForegroundColor White
Write-Host ""
Write-Host "Or restart PowerShell for auto-loading." -ForegroundColor Cyan
Write-Host ""

# Show available commands
Write-Host "Available commands:" -ForegroundColor Cyan
Write-Host "  Hook Management:" -ForegroundColor Yellow
Write-Host "    Invoke-DotfilesHook  - Run a hook point" -ForegroundColor Gray
Write-Host "    Enable-DotfilesHooks - Enable hooks" -ForegroundColor Gray
Write-Host "    Disable-DotfilesHooks - Disable hooks" -ForegroundColor Gray
Write-Host ""
Write-Host "  Tool Aliases:" -ForegroundColor Yellow
Write-Host "    ssh-keys, ssh-gen, ssh-tunnel, ssh-status" -ForegroundColor Gray
Write-Host "    aws-profiles, aws-who, aws-login, aws-switch, aws-status" -ForegroundColor Gray
Write-Host "    cdk-init, cdk-env, cdk-outputs, cdk-status" -ForegroundColor Gray
Write-Host "    go-new, go-test, go-lint, go-info" -ForegroundColor Gray
Write-Host "    rust-new, rust-lint, rust-info" -ForegroundColor Gray
Write-Host "    py-new, py-test, py-info" -ForegroundColor Gray
Write-Host "    docker-ps, docker-images, docker-clean, docker-status" -ForegroundColor Gray
Write-Host ""
Write-Host "  Node.js (fnm):" -ForegroundColor Yellow
Write-Host "    fnm-install, fnm-use, fnm-list, Initialize-Fnm" -ForegroundColor Gray
Write-Host ""
Write-Host "  Navigation:" -ForegroundColor Yellow
Write-Host "    z (zoxide) - smart directory jumping, Initialize-Zoxide" -ForegroundColor Gray
Write-Host ""
Write-Host "  Shortcut:" -ForegroundColor Yellow
Write-Host "    d  - Alias for 'dotfiles'" -ForegroundColor Gray
Write-Host ""
Write-Host "Install packages: .\Install-Packages.ps1" -ForegroundColor Cyan
Write-Host ""
