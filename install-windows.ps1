#Requires -Version 5.1
<#
.SYNOPSIS
    One-line installer for blackdot on Windows

.DESCRIPTION
    Downloads and installs blackdot with PowerShell module and Go binary.

    Usage:
        irm https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install-windows.ps1 | iex

.PARAMETER WorkspaceTarget
    Where to clone the repository. Defaults to ~/workspace

.PARAMETER Minimal
    Skip optional features (just shell config)

.PARAMETER NoBinary
    Skip Go binary download

.EXAMPLE
    irm https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install-windows.ps1 | iex
#>
[CmdletBinding()]
param(
    [string]$WorkspaceTarget = "$HOME\workspace",
    [switch]$Minimal,
    [switch]$NoBinary
)

$ErrorActionPreference = 'Stop'

# Colors
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Pass { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "[FAIL] $msg" -ForegroundColor Red }

# Banner
Write-Host ""
Write-Host @"
    ____  __    ___   ________ ____  ____  ______
   / __ )/ /   /   | / ____/ //_/ / / / / / / __ \______
  / __  / /   / /| |/ /   / ,<  / / / / / / / / // __  /
 / /_/ / /___/ ___ / /___/ /| |/ /_/ / /_/ / /_/ // /_/ /
/_____/_____/_/  |_\____/_/ |_|\____/\____/\____/ \____/

"@ -ForegroundColor Cyan
Write-Host "Vault-backed configuration that travels with you" -ForegroundColor White
Write-Host ""

# Configuration
$RepoUrl = "https://github.com/blackwell-systems/blackdot.git"
$InstallDir = Join-Path $WorkspaceTarget "blackdot"

Write-Info "Detected platform: Windows PowerShell"

# Check for git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warn "Git not found. Installing via winget..."
    try {
        winget install Git.Git --accept-package-agreements --accept-source-agreements
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } catch {
        Write-Fail "Could not install Git. Please install manually: winget install Git.Git"
        exit 1
    }
}

# Create workspace directory
if (-not (Test-Path $WorkspaceTarget)) {
    New-Item -Path $WorkspaceTarget -ItemType Directory -Force | Out-Null
}

# Clone or update repository
if (Test-Path (Join-Path $InstallDir ".git")) {
    Write-Info "Blackdot already installed at $InstallDir"
    Write-Info "Updating..."
    Push-Location $InstallDir
    try {
        git pull --rebase origin main
        Write-Pass "Updated to latest version"
    } finally {
        Pop-Location
    }
} else {
    Write-Info "Cloning blackdot repository..."
    git clone $RepoUrl $InstallDir
    Write-Pass "Cloned to $InstallDir"
}

# Install PowerShell module
Write-Info "Installing PowerShell module..."
$installScript = Join-Path $InstallDir "powershell\Install-Blackdot.ps1"

$installArgs = @{}
if ($NoBinary) {
    # Don't pass -Binary
} else {
    $installArgs['Binary'] = $true
}
if ($Minimal) {
    $installArgs['NoProfile'] = $true
}

& $installScript @installArgs

# Success message
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              Installation Complete!                        ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

if (-not $Minimal) {
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. Restart PowerShell to load the module" -ForegroundColor White
    Write-Host ""
    Write-Host "  2. Run the setup wizard:" -ForegroundColor White
    Write-Host "     blackdot setup" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  3. Install recommended packages (optional):" -ForegroundColor White
    Write-Host "     cd $InstallDir\powershell" -ForegroundColor Yellow
    Write-Host "     .\Install-Packages.ps1" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "Minimal installation complete." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Restart PowerShell to load the module." -ForegroundColor White
    Write-Host ""
}

Write-Host "Documentation: https://github.com/blackwell-systems/blackdot" -ForegroundColor Gray
Write-Host ""
