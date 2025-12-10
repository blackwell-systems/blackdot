#Requires -Version 5.1
<#
.SYNOPSIS
    One-line installer for blackdot on Windows.

.DESCRIPTION
    Downloads and installs blackdot for Windows PowerShell users.

    Usage:
        irm https://raw.githubusercontent.com/blackwell-systems/blackdot/main/Install.ps1 | iex

    Or with options:
        $script = irm https://raw.githubusercontent.com/blackwell-systems/blackdot/main/Install.ps1
        & ([scriptblock]::Create($script)) -Preset developer -SkipPackages

.PARAMETER Preset
    Feature preset to apply: minimal, developer, claude, full (default: none)

.PARAMETER SkipPackages
    Skip winget package installation

.PARAMETER SkipBinary
    Skip Go binary download (use shell scripts only)

.PARAMETER WorkspaceTarget
    Installation directory (default: $HOME\workspace)

.PARAMETER Version
    Specific version to download (default: latest)

.EXAMPLE
    irm https://raw.githubusercontent.com/blackwell-systems/blackdot/main/Install.ps1 | iex

.EXAMPLE
    .\Install.ps1 -Preset developer

.EXAMPLE
    .\Install.ps1 -SkipPackages -WorkspaceTarget "D:\dev"
#>

[CmdletBinding()]
param(
    [ValidateSet('minimal', 'developer', 'claude', 'full')]
    [string]$Preset,

    [switch]$SkipPackages,

    [switch]$SkipBinary,

    [string]$WorkspaceTarget = "$HOME\workspace",

    [string]$Version = "latest"
)

# ============================================================
# Colors and Output
# ============================================================
$script:Colors = @{
    Red    = "`e[31m"
    Green  = "`e[32m"
    Yellow = "`e[33m"
    Blue   = "`e[34m"
    Cyan   = "`e[36m"
    Bold   = "`e[1m"
    Reset  = "`e[0m"
}

function Write-Info  { param($Message) Write-Host "$($Colors.Blue)[INFO]$($Colors.Reset) $Message" }
function Write-Pass  { param($Message) Write-Host "$($Colors.Green)[OK]$($Colors.Reset) $Message" }
function Write-Warn  { param($Message) Write-Host "$($Colors.Yellow)[WARN]$($Colors.Reset) $Message" }
function Write-Fail  { param($Message) Write-Host "$($Colors.Red)[FAIL]$($Colors.Reset) $Message" }

# ============================================================
# Banner
# ============================================================
function Show-Banner {
    Write-Host ""
    Write-Host "$($Colors.Cyan)$($Colors.Bold)"
    Write-Host "    ____  __    ___   ________ ____  ____  ______"
    Write-Host "   / __ )/ /   /   | / ____/ //_/ / / / / / / __ \______"
    Write-Host "  / __  / /   / /| |/ /   / ,<  / / / / / / / / // __  /"
    Write-Host " / /_/ / /___/ ___ / /___/ /| |/ /_/ / /_/ / /_/ // /_/ /"
    Write-Host "/_____/_____/_/  |_\____/_/ |_|\____/\____/\____/ \____/"
    Write-Host ""
    Write-Host "$($Colors.Reset)"
    Write-Host "$($Colors.Bold)Vault-backed configuration that travels with you$($Colors.Reset)"
    Write-Host ""
}

# ============================================================
# Prerequisites Check
# ============================================================
function Test-Prerequisites {
    $missing = @()

    # Git is required
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $missing += "git"
    }

    if ($missing.Count -gt 0) {
        Write-Fail "Missing prerequisites: $($missing -join ', ')"
        Write-Host ""
        Write-Host "Install with winget:"
        foreach ($pkg in $missing) {
            switch ($pkg) {
                "git" { Write-Host "  winget install Git.Git" }
            }
        }
        Write-Host ""
        return $false
    }

    Write-Pass "Prerequisites check passed"
    return $true
}

# ============================================================
# Download Go Binary
# ============================================================
function Install-GoBinary {
    param(
        [string]$InstallDir = "$HOME\.local\bin",
        [string]$Version = "latest"
    )

    # Detect architecture
    $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
    $binaryName = "blackdot-windows-$arch.exe"

    # GitHub release URL
    $baseUrl = "https://github.com/blackwell-systems/blackdot/releases"
    $downloadUrl = if ($Version -eq "latest") {
        "$baseUrl/latest/download/$binaryName"
    } else {
        "$baseUrl/download/$Version/$binaryName"
    }

    Write-Info "Downloading Go binary: $binaryName"
    Write-Info "From: $downloadUrl"

    # Create install directory
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    $targetPath = Join-Path $InstallDir "blackdot.exe"

    try {
        # Download with progress
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $downloadUrl -OutFile $targetPath -UseBasicParsing
        $ProgressPreference = 'Continue'

        # Verify it works
        $versionOutput = & $targetPath version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Pass "Installed blackdot binary to: $targetPath"

            # Check if in PATH
            $pathDirs = $env:PATH -split ';'
            if ($InstallDir -notin $pathDirs) {
                Write-Warn "Add to your PATH: $InstallDir"
                Write-Host ""
                Write-Host "Run this to add permanently:"
                Write-Host "  [Environment]::SetEnvironmentVariable('Path', `$env:PATH + ';$InstallDir', 'User')"
            }
            return $true
        } else {
            throw "Binary verification failed"
        }
    }
    catch {
        Write-Fail "Failed to download binary: $_"
        Write-Fail "Release may not exist yet. Check: $baseUrl"
        if (Test-Path $targetPath) {
            Remove-Item $targetPath -Force
        }
        return $false
    }
}

# ============================================================
# Clone/Update Repository
# ============================================================
function Install-Repository {
    param(
        [string]$TargetDir
    )

    $repoUrl = "https://github.com/blackwell-systems/blackdot.git"

    if (Test-Path (Join-Path $TargetDir ".git")) {
        Write-Info "Blackdot already installed at $TargetDir"
        Write-Info "Updating..."

        Push-Location $TargetDir
        try {
            git pull --rebase origin main 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Pass "Updated to latest version"
            } else {
                Write-Warn "Update failed, continuing with existing version"
            }
        }
        finally {
            Pop-Location
        }
    }
    else {
        # Create parent directory
        $parentDir = Split-Path $TargetDir -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        Write-Info "Cloning blackdot repository..."
        git clone $repoUrl $TargetDir 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Pass "Cloned to $TargetDir"
        } else {
            Write-Fail "Failed to clone repository"
            return $false
        }
    }

    return $true
}

# ============================================================
# Install PowerShell Module
# ============================================================
function Install-BlackdotModule {
    param(
        [string]$BlackdotDir
    )

    $installScript = Join-Path $BlackdotDir "powershell\Install-Blackdot.ps1"

    if (-not (Test-Path $installScript)) {
        Write-Fail "Install script not found: $installScript"
        return $false
    }

    Write-Info "Installing PowerShell module..."

    Push-Location (Join-Path $BlackdotDir "powershell")
    try {
        & $installScript
        if ($LASTEXITCODE -eq 0 -or $?) {
            Write-Pass "PowerShell module installed"
            return $true
        } else {
            Write-Fail "Module installation failed"
            return $false
        }
    }
    catch {
        Write-Fail "Module installation error: $_"
        return $false
    }
    finally {
        Pop-Location
    }
}

# ============================================================
# Install Packages (Optional)
# ============================================================
function Install-BlackdotPackages {
    param(
        [string]$BlackdotDir,
        [string]$Tier = "enhanced"
    )

    $packagesScript = Join-Path $BlackdotDir "powershell\Install-Packages.ps1"

    if (-not (Test-Path $packagesScript)) {
        Write-Warn "Packages script not found, skipping"
        return $true
    }

    Write-Info "Installing packages (tier: $Tier)..."

    Push-Location (Join-Path $BlackdotDir "powershell")
    try {
        & $packagesScript -Tier $Tier
        Write-Pass "Packages installed"
        return $true
    }
    catch {
        Write-Warn "Some packages may not have installed: $_"
        return $true  # Non-fatal
    }
    finally {
        Pop-Location
    }
}

# ============================================================
# Apply Preset
# ============================================================
function Set-BlackdotPreset {
    param(
        [string]$Preset
    )

    if (-not $Preset) { return $true }

    $blackdot = Get-Command blackdot -ErrorAction SilentlyContinue
    if (-not $blackdot) {
        $blackdot = Get-Command blackdot.exe -ErrorAction SilentlyContinue
    }

    if ($blackdot) {
        Write-Info "Applying preset: $Preset"
        & $blackdot.Source features preset $Preset
        if ($LASTEXITCODE -eq 0) {
            Write-Pass "Preset '$Preset' applied"
            return $true
        }
    }

    Write-Warn "Could not apply preset (blackdot CLI not in PATH yet)"
    Write-Host "  Run after restart: blackdot features preset $Preset"
    return $true
}

# ============================================================
# Main Installation
# ============================================================
function Main {
    Show-Banner

    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        exit 1
    }

    $blackdotDir = Join-Path $WorkspaceTarget "blackdot"

    # Clone/update repository
    Write-Host ""
    if (-not (Install-Repository -TargetDir $blackdotDir)) {
        exit 1
    }

    # Install Go binary (unless skipped)
    Write-Host ""
    if (-not $SkipBinary) {
        $binaryInstalled = Install-GoBinary -Version $Version
        if (-not $binaryInstalled) {
            Write-Warn "Binary installation failed, shell scripts will be used"
        }
    }

    # Install PowerShell module
    Write-Host ""
    if (-not (Install-BlackdotModule -BlackdotDir $blackdotDir)) {
        Write-Warn "Module installation had issues, but continuing..."
    }

    # Install packages (unless skipped)
    if (-not $SkipPackages) {
        Write-Host ""
        Write-Host "Install development packages via winget? (This may take a while)"
        $response = Read-Host "Install packages? [y/N]"
        if ($response -match '^[Yy]') {
            Install-BlackdotPackages -BlackdotDir $blackdotDir
        } else {
            Write-Info "Skipping package installation"
            Write-Host "  Run later: $blackdotDir\powershell\Install-Packages.ps1"
        }
    }

    # Apply preset
    if ($Preset) {
        Write-Host ""
        Set-BlackdotPreset -Preset $Preset
    }

    # Success message
    Write-Host ""
    Write-Host "$($Colors.Green)$($Colors.Bold)================================================$($Colors.Reset)"
    Write-Host "$($Colors.Green)$($Colors.Bold)         Installation Complete!                $($Colors.Reset)"
    Write-Host "$($Colors.Green)$($Colors.Bold)================================================$($Colors.Reset)"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host ""
    Write-Host "  1. Restart PowerShell to load the module"
    Write-Host ""
    Write-Host "  2. Set up vault and restore secrets:"
    Write-Host "     $($Colors.Cyan)blackdot setup$($Colors.Reset)"
    Write-Host ""
    Write-Host "  3. Verify installation:"
    Write-Host "     $($Colors.Cyan)blackdot doctor$($Colors.Reset)"
    Write-Host ""

    if (-not $SkipPackages -and $response -notmatch '^[Yy]') {
        Write-Host "  Optional: Install development packages:"
        Write-Host "     $($Colors.Cyan)$blackdotDir\powershell\Install-Packages.ps1$($Colors.Reset)"
        Write-Host ""
    }

    Write-Host "Documentation: $($Colors.Blue)https://github.com/blackwell-systems/blackdot$($Colors.Reset)"
    Write-Host ""
}

# Run main
Main
