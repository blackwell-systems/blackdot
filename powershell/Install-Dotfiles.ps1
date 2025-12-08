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

.PARAMETER Binary
    Also download the Go binary for native cross-platform commands.

.PARAMETER BinaryOnly
    Only download the Go binary, skip module installation.

.PARAMETER BinaryPath
    Where to install the binary. Defaults to ~/.local/bin or ~/bin.

.PARAMETER Version
    Version of the binary to download. Defaults to 'latest'.

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

    [switch]$Force,

    [switch]$Binary,

    [switch]$BinaryOnly,

    [string]$BinaryPath,

    [string]$Version = "latest"
)

$ErrorActionPreference = 'Stop'

# Binary download function
function Install-DotfilesBinary {
    param(
        [string]$InstallPath,
        [string]$Version = "latest"
    )

    # Detect OS
    $os = if ($IsWindows -or $env:OS -eq "Windows_NT") {
        "windows"
    } elseif ($IsMacOS) {
        "darwin"
    } elseif ($IsLinux) {
        "linux"
    } else {
        throw "Unsupported OS for binary download"
    }

    # Detect architecture
    $arch = switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture) {
        "X64" { "amd64" }
        "Arm64" { "arm64" }
        default { throw "Unsupported architecture: $_" }
    }

    # Build binary name
    $suffix = if ($os -eq "windows") { ".exe" } else { "" }
    $binaryName = "dotfiles-$os-$arch$suffix"

    # GitHub release URL
    $baseUrl = "https://github.com/blackwell-systems/dotfiles/releases"
    $downloadUrl = if ($Version -eq "latest") {
        "$baseUrl/latest/download/$binaryName"
    } else {
        "$baseUrl/download/$Version/$binaryName"
    }

    Write-Host "Downloading Go binary: $binaryName" -ForegroundColor Cyan
    Write-Host "From: $downloadUrl" -ForegroundColor Gray

    # Create install directory
    if (-not (Test-Path $InstallPath)) {
        New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
    }

    # Download binary
    $target = Join-Path $InstallPath "dotfiles$suffix"
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $target -UseBasicParsing
    } catch {
        throw "Failed to download binary. Release may not exist yet. Check: $baseUrl"
    }

    # Make executable on Unix
    if ($os -ne "windows") {
        chmod +x $target
    }

    # Verify it works
    try {
        $null = & $target version 2>&1
        Write-Host "[OK] Installed dotfiles binary to: $target" -ForegroundColor Green
    } catch {
        Remove-Item $target -Force -ErrorAction SilentlyContinue
        throw "Binary verification failed"
    }

    # PATH hint
    $pathDirs = $env:PATH -split [IO.Path]::PathSeparator
    if ($InstallPath -notin $pathDirs) {
        Write-Host "[WARN] Add to your PATH: $InstallPath" -ForegroundColor Yellow
    }

    return $target
}

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

# Determine binary install path
if (-not $BinaryPath) {
    $BinaryPath = if ($IsWindows -or $env:OS -eq "Windows_NT") {
        # Windows: use ~/bin or ~/.local/bin
        $localBin = Join-Path $HOME ".local\bin"
        $homeBin = Join-Path $HOME "bin"
        if (Test-Path $localBin) { $localBin }
        elseif (Test-Path $homeBin) { $homeBin }
        else { $localBin }
    } else {
        # Unix: prefer ~/.local/bin
        Join-Path $HOME ".local/bin"
    }
}

# Binary-only mode: just download the binary and exit
if ($BinaryOnly) {
    try {
        Install-DotfilesBinary -InstallPath $BinaryPath -Version $Version
        Write-Host ""
        Write-Host "Binary installation complete!" -ForegroundColor Green
        Write-Host "Run 'dotfiles version' to verify the installation." -ForegroundColor Cyan
    } catch {
        Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    exit 0
}

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

# Install Go binary if requested
if ($Binary) {
    Write-Host "Installing Go binary..." -ForegroundColor Cyan
    try {
        Install-DotfilesBinary -InstallPath $BinaryPath -Version $Version
    } catch {
        Write-Host "[WARN] Binary installation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "       Module will use shell scripts instead." -ForegroundColor Yellow
    }
    Write-Host ""
}

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
Write-Host "    claude-status, claude-bedrock, claude-max, claude-switch" -ForegroundColor Gray
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
