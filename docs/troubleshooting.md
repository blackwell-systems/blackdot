# Troubleshooting

This guide covers common issues and their solutions.

## Quick Diagnostics

Run these commands first to understand your system state:

```bash
# Visual dashboard
blackdot status

# Comprehensive health check
blackdot doctor

# Check with auto-fix
blackdot doctor --fix

# Compare local vs vault
blackdot drift
```

## Installation Issues

### "Permission denied" during install

**Symptom:** Install script fails with permission errors.

**Solution:**
```bash
# Don't use sudo for the install script
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install.sh | bash

# If you need to fix permissions afterward
blackdot doctor --fix
```

### Install hangs on "Waiting for vault"

**Symptom:** Install prompts for vault but you don't use one.

**Solution:**
```bash
# Option 1: Skip vault during install
./install.sh --minimal

# Option 2: Run setup wizard and choose "skip" when prompted for vault
./install.sh
blackdot setup   # Choose "Skip" when asked about vault backend
```

### Homebrew not found (macOS)

**Symptom:** `brew: command not found` after install.

**Solution:**
```bash
# Homebrew installs to different locations on Intel vs Apple Silicon
# For Apple Silicon (M1/M2/M3):
eval "$(/opt/homebrew/bin/brew shellenv)"

# For Intel:
eval "$(/usr/local/bin/brew shellenv)"

# Then re-run bootstrap
./bootstrap/bootstrap-mac.sh
```

### PowerShell module not loading (Windows)

**Symptom:** `blackdot: The term 'blackdot' is not recognized` after install.

**Solution:**
```powershell
# Check if module is imported
Get-Module -Name Blackdot

# If not, import it manually
Import-Module $HOME\workspace\blackdot\powershell\Blackdot.psm1

# Add to your PowerShell profile for auto-loading
Add-Content $PROFILE "`nImport-Module $HOME\workspace\blackdot\powershell\Blackdot.psm1"

# Restart PowerShell
```

## Shell Issues

### Prompt looks wrong or broken

**Symptom:** Missing icons, garbled characters, or plain prompt.

**Solution:**
```bash
# Install a Nerd Font
brew install --cask font-meslo-lg-nerd-font

# Configure your terminal to use "MesloLGS NF" font
# Then restart your terminal
```

### "command not found: blackdot"

**Symptom:** `blackdot` command doesn't work.

**Solution:**
```bash
# Ensure zshrc is linked
ls -la ~/.zshrc
# Should show: .zshrc -> ~/workspace/blackdot/zsh/.zshrc

# If not linked, re-run bootstrap
./bootstrap/bootstrap-mac.sh  # or bootstrap-linux.sh

# Or manually link
ln -sf ~/workspace/blackdot/zsh/.zshrc ~/.zshrc

# Reload shell
exec zsh
```

### Tab completion not working

**Symptom:** Tab completion for `blackdot` command doesn't work.

**Zsh Solution:**
```bash
# Check if completions directory is in fpath
echo $fpath | tr ' ' '\n' | grep completions

# Rebuild completion cache
rm -f ~/.zcompdump*
exec zsh

# Verify completion file exists
ls ~/workspace/blackdot/zsh/completions/_blackdot
```

**PowerShell Solution:**
```powershell
# Reload the module to refresh completions
Remove-Module Blackdot -ErrorAction SilentlyContinue
Import-Module Blackdot

# Check if argument completers are registered
Get-ArgumentCompleter -Native | Where-Object { $_.CommandName -eq 'blackdot' }
```

### ZSH modules not loading

**Symptom:** Aliases or functions missing.

**Solution:**
```bash
# Check which modules loaded
ls -la ~/workspace/blackdot/zsh/zsh.d/

# Verify symlink
ls -la ~/.zshrc

# Check for syntax errors
for f in ~/workspace/blackdot/zsh/zsh.d/*.zsh; do
  zsh -n "$f" || echo "Error in $f"
done
```

## Vault Issues (Bitwarden / 1Password / pass)

### "BW_SESSION not set"

**Symptom:** Vault commands fail with session errors.

**Solution:**
```bash
# Log in first (if needed)
bw login

# Unlock and export session
export BW_SESSION="$(bw unlock --raw)"

# Verify
bw unlock --check --session "$BW_SESSION"
```

### "Vault item not found"

**Symptom:** `blackdot vault pull` can't find items.

**Solution:**
```bash
# List available items
blackdot vault list

# Check expected item names
# Items should be named: blackdot-SSH-Config, blackdot-AWS-Config, etc.

# Verify items exist in vault
blackdot vault list

# Create missing items
blackdot vault create
```

### Drift detection shows differences

**Symptom:** `blackdot drift` shows local differs from vault.

**Solution:**
```bash
# Preview what would change
blackdot diff --restore   # See what restore would do
blackdot diff --sync      # See what sync would do

# Best: Smart sync auto-detects direction for each file
blackdot sync             # Auto push/pull based on what changed
blackdot sync --dry-run   # Preview first

# Or choose direction manually:
blackdot vault pull       # Pull vault → local (overwrites local)
blackdot vault push --all # Push local → vault (overwrites vault)
```

### Vault CLI not found

**Symptom:** Vault CLI not installed.

**Solution:**

**macOS:**
```bash
brew install bitwarden-cli       # Bitwarden
brew install --cask 1password-cli # 1Password
brew install pass                 # pass
```

**Linux:**
```bash
npm install -g @bitwarden/cli    # Bitwarden
sudo apt install pass            # pass
# See 1Password docs for Linux
```

**Windows (PowerShell):**
```powershell
winget install Bitwarden.CLI     # Bitwarden
winget install AgileBits.1Password.CLI  # 1Password
# pass not natively supported on Windows
```

## Permission Issues

### SSH key permissions wrong

**Symptom:** SSH says "Permissions too open" or "bad permissions".

**Solution:**
```bash
# Fix SSH directory
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub

# Or use doctor
blackdot doctor --fix
```

### AWS credentials permissions

**Symptom:** AWS CLI warns about credential file permissions.

**Solution:**
```bash
chmod 600 ~/.aws/credentials
chmod 600 ~/.aws/config

# Or use doctor
blackdot doctor --fix
```

## Backup / Restore Issues

### "No backups found"

**Symptom:** `blackdot backup restore` says no backups exist.

**Solution:**
```bash
# Check backup directory
ls -la ~/.blackdot-backups/

# Create a backup first
blackdot backup

# List available backups
blackdot backup --list
```

### Restore from specific backup

**Symptom:** Need to restore a specific backup.

**Solution:**
```bash
# List backups with dates
blackdot backup --list

# Interactive restore (shows selection)
blackdot backup restore

# Manual restore
tar -xzf ~/.blackdot-backups/backup-YYYYMMDD-HHMMSS.tar.gz -C /
```

## Platform-Specific Issues

### Windows: Execution policy blocking scripts

**Symptom:** PowerShell says "running scripts is disabled on this system"

**Solution:**
```powershell
# Check current policy
Get-ExecutionPolicy

# Set to allow local scripts (run as Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Retry import
Import-Module Blackdot
```

### Windows: Module not found after install

**Symptom:** `Import-Module Blackdot` fails with "module not found"

**Solution:**
```powershell
# Add to PSModulePath
$modulePath = "$HOME\workspace\blackdot\powershell"
$env:PSModulePath = "$modulePath;$env:PSModulePath"

# Or copy to standard module location
Copy-Item -Recurse $modulePath\* $HOME\Documents\PowerShell\Modules\Blackdot\
```

### WSL2: Slow shell startup

**Symptom:** Shell takes seconds to start.

**Solution:**
```bash
# Disable Windows PATH integration
# Add to /etc/wsl.conf:
[interop]
appendWindowsPath = false

# Restart WSL
wsl --shutdown
```

### Lima: Directory not accessible

**Symptom:** Can't access files from Lima VM.

**Solution:**
```bash
# Check mount
limactl shell default mount

# Verify workspace symlink
ls -la /workspace

# Re-run bootstrap if needed
./bootstrap/bootstrap-linux.sh
```

### Docker: Changes not persisting

**Symptom:** Container loses changes on restart.

**Solution:**
```bash
# Mount blackdot as volume
docker run -v ~/workspace/blackdot:/root/workspace/blackdot ...

# Or use the development image
docker build -t blackdot-dev .
docker run -it blackdot-dev
```

## Upgrade Issues

### Upgrade fails with merge conflicts

**Symptom:** `blackdot upgrade` fails with git errors.

**Solution:**
```bash
cd ~/workspace/blackdot

# Check status
git status

# Stash local changes
git stash

# Pull updates
git pull origin main

# Re-apply changes
git stash pop

# Re-run bootstrap
./bootstrap/bootstrap-mac.sh  # or bootstrap-linux.sh
```

### After upgrade, features missing

**Symptom:** New features not available after upgrade.

**Zsh Solution:**
```bash
# Ensure bootstrap ran
./bootstrap/bootstrap-mac.sh  # or bootstrap-linux.sh

# Reload shell
exec zsh

# Check version
head -5 ~/workspace/blackdot/README.md
```

**PowerShell Solution:**
```powershell
# Pull latest changes
cd $HOME\workspace\blackdot
git pull

# Reload the module
Remove-Module Blackdot -ErrorAction SilentlyContinue
Import-Module .\powershell\Blackdot.psm1

# Check status
blackdot status
```

## Still Having Issues?

1. **Run full diagnostics:**
   ```bash
   blackdot doctor
   blackdot status
   ```

2. **Check logs:**
   ```bash
   # Installation metrics
   cat ~/.blackdot-metrics.jsonl | tail -20
   ```

3. **Reset to clean state:**
   ```bash
   # Backup first!
   blackdot backup

   # Uninstall
   blackdot uninstall --dry-run  # Preview
   blackdot uninstall            # Execute

   # Reinstall
   curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install.sh | bash
   ```

4. **Report an issue:**
   - [Open GitHub Issue](https://github.com/blackwell-systems/blackdot/issues/new)
   - Include output of `blackdot doctor`
   - Include your OS version and shell version
