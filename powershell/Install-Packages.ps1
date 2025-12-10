#Requires -Version 5.1
<#
.SYNOPSIS
    Install development packages for Windows

.DESCRIPTION
    Installs packages from packages.json using winget.
    Equivalent to 'brew bundle' on macOS/Linux.

.PARAMETER Tier
    Installation tier: minimal, enhanced, or full (default: full)
    - minimal: Essential CLI tools only
    - enhanced: Modern CLI tools + development languages
    - full: Everything including Docker, editors

.PARAMETER DryRun
    Show what would be installed without installing

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\Install-Packages.ps1
    Install all packages

.EXAMPLE
    .\Install-Packages.ps1 -Tier minimal
    Install only essential packages

.EXAMPLE
    .\Install-Packages.ps1 -DryRun
    Preview what would be installed
#>
[CmdletBinding()]
param(
    [ValidateSet("minimal", "enhanced", "full")]
    [string]$Tier = "full",

    [switch]$DryRun,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Package tiers
$MinimalPackages = @(
    "Git.Git",
    "GitHub.cli",
    "Microsoft.PowerShell",
    "sharkdp.bat",
    "BurntSushi.ripgrep.MSVC",
    "junegunn.fzf",
    "stedolan.jq"
)

$EnhancedPackages = $MinimalPackages + @(
    "sharkdp.fd",
    "ajeetdsouza.zoxide",
    "eza-community.eza",
    "charmbracelet.glow",
    "bootandy.dust",
    "Starship.Starship",
    "Amazon.AWSCLI",
    "Bitwarden.CLI",
    "FiloSottile.age",
    "GoLang.Go",
    "Rustlang.Rustup",
    "Python.Python.3.12",
    "Schniz.fnm"
)

$FullPackages = $EnhancedPackages + @(
    "AgileBits.1Password.CLI",
    "Docker.DockerDesktop",
    "Microsoft.VisualStudioCode",
    "Microsoft.WindowsTerminal"
)

# Select packages based on tier
$PackagesToInstall = switch ($Tier) {
    "minimal"  { $MinimalPackages }
    "enhanced" { $EnhancedPackages }
    "full"     { $FullPackages }
}

Write-Host ""
Write-Host "Dotfiles Package Installer" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tier: $Tier ($($PackagesToInstall.Count) packages)" -ForegroundColor Yellow
Write-Host ""

# Check for winget
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] winget not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "winget is required for package installation." -ForegroundColor Yellow
    Write-Host "It should be pre-installed on Windows 10/11." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "If missing, install from:" -ForegroundColor Yellow
    Write-Host "  https://aka.ms/getwinget" -ForegroundColor White
    exit 1
}

Write-Host "[OK] winget found: $(winget --version)" -ForegroundColor Green
Write-Host ""

# Check which packages are already installed
Write-Host "Checking installed packages..." -ForegroundColor Cyan
$installedRaw = winget list --accept-source-agreements 2>$null
$installed = @{}
foreach ($line in $installedRaw) {
    foreach ($pkg in $PackagesToInstall) {
        if ($line -match [regex]::Escape($pkg)) {
            $installed[$pkg] = $true
        }
    }
}

# Categorize packages
$toInstall = @()
$alreadyInstalled = @()

foreach ($pkg in $PackagesToInstall) {
    if ($installed[$pkg]) {
        $alreadyInstalled += $pkg
    } else {
        $toInstall += $pkg
    }
}

Write-Host ""
Write-Host "Already installed: $($alreadyInstalled.Count)" -ForegroundColor Green
foreach ($pkg in $alreadyInstalled) {
    Write-Host "  [OK] $pkg" -ForegroundColor Gray
}

Write-Host ""
Write-Host "To install: $($toInstall.Count)" -ForegroundColor Yellow
foreach ($pkg in $toInstall) {
    Write-Host "  [ ] $pkg" -ForegroundColor White
}

if ($toInstall.Count -eq 0) {
    Write-Host ""
    Write-Host "All packages already installed!" -ForegroundColor Green
    exit 0
}

if ($DryRun) {
    Write-Host ""
    Write-Host "[DRY RUN] Would install $($toInstall.Count) packages" -ForegroundColor Yellow
    exit 0
}

# Confirm installation
if (-not $Force) {
    Write-Host ""
    $response = Read-Host "Install $($toInstall.Count) packages? (Y/n)"
    if ($response -match '^[Nn]') {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Install packages
Write-Host ""
Write-Host "Installing packages..." -ForegroundColor Cyan
Write-Host ""

$successCount = 0
$failCount = 0

foreach ($pkg in $toInstall) {
    Write-Host "Installing: $pkg" -ForegroundColor White
    try {
        $result = winget install --id $pkg --accept-package-agreements --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Installed" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "  [WARN] May need manual install" -ForegroundColor Yellow
            $failCount++
        }
    } catch {
        Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
    }
    Write-Host ""
}

# Summary
Write-Host "Installation complete!" -ForegroundColor Cyan
Write-Host "  Installed: $successCount" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  Failed: $failCount" -ForegroundColor Yellow
}
Write-Host ""

# Post-install hints
Write-Host "Post-installation steps:" -ForegroundColor Cyan
Write-Host ""

if ($toInstall -contains "Schniz.fnm") {
    Write-Host "  fnm (Node.js version manager):" -ForegroundColor Yellow
    Write-Host "    fnm install --lts" -ForegroundColor Gray
    Write-Host "    fnm use lts-latest" -ForegroundColor Gray
    Write-Host "    Add to profile: fnm env --use-on-cd | Out-String | Invoke-Expression" -ForegroundColor Gray
    Write-Host ""
}

if ($toInstall -contains "Rustlang.Rustup") {
    Write-Host "  Rust:" -ForegroundColor Yellow
    Write-Host "    Restart terminal, then: rustup default stable" -ForegroundColor Gray
    Write-Host ""
}

if ($toInstall -contains "ajeetdsouza.zoxide") {
    Write-Host "  zoxide (smart cd):" -ForegroundColor Yellow
    Write-Host "    Add to profile: Invoke-Expression (& { zoxide init powershell | Out-String })" -ForegroundColor Gray
    Write-Host ""
}

if ($toInstall -contains "Starship.Starship") {
    Write-Host "  Starship (cross-platform prompt):" -ForegroundColor Yellow
    Write-Host "    Add to profile: Invoke-Expression (&starship init powershell)" -ForegroundColor Gray
    Write-Host "    Config: ~/.config/starship.toml" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "Restart your terminal for changes to take effect." -ForegroundColor Cyan
Write-Host ""
