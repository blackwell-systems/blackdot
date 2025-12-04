# Troubleshooting

This guide covers common issues and their solutions.

## Quick Diagnostics

Run these commands first to understand your system state:

```bash
# Visual dashboard
dotfiles status

# Comprehensive health check
dotfiles doctor

# Check with auto-fix
dotfiles doctor --fix

# Compare local vs vault
dotfiles drift
```

## Installation Issues

### "Permission denied" during install

**Symptom:** Install script fails with permission errors.

**Solution:**
```bash
# Don't use sudo for the install script
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash

# If you need to fix permissions afterward
dotfiles doctor --fix
```

### Install hangs on "Waiting for vault"

**Symptom:** Install prompts for vault but you don't use one.

**Solution:**
```bash
# Option 1: Skip vault during install
./install.sh --minimal

# Option 2: Run setup wizard and choose "skip" when prompted for vault
./install.sh
dotfiles setup   # Choose "Skip" when asked about vault backend
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

### "command not found: dotfiles"

**Symptom:** `dotfiles` command doesn't work.

**Solution:**
```bash
# Ensure zshrc is linked
ls -la ~/.zshrc
# Should show: .zshrc -> ~/workspace/dotfiles/zsh/.zshrc

# If not linked, re-run bootstrap
./bootstrap/bootstrap-mac.sh  # or bootstrap-linux.sh

# Or manually link
ln -sf ~/workspace/dotfiles/zsh/.zshrc ~/.zshrc

# Reload shell
exec zsh
```

### Tab completion not working

**Symptom:** Tab completion for `dotfiles` command doesn't work.

**Solution:**
```bash
# Check if completions directory is in fpath
echo $fpath | tr ' ' '\n' | grep completions

# Rebuild completion cache
rm -f ~/.zcompdump*
exec zsh

# Verify completion file exists
ls ~/workspace/dotfiles/zsh/completions/_dotfiles
```

### ZSH modules not loading

**Symptom:** Aliases or functions missing.

**Solution:**
```bash
# Check which modules loaded
ls -la ~/workspace/dotfiles/zsh/zsh.d/

# Verify symlink
ls -la ~/.zshrc

# Check for syntax errors
for f in ~/workspace/dotfiles/zsh/zsh.d/*.zsh; do
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

**Symptom:** `dotfiles vault pull` can't find items.

**Solution:**
```bash
# List available items
dotfiles vault list

# Check expected item names
# Items should be named: dotfiles-SSH-Config, dotfiles-AWS-Config, etc.

# Verify items exist in vault
dotfiles vault list

# Create missing items
dotfiles vault create
```

### Drift detection shows differences

**Symptom:** `dotfiles drift` shows local differs from vault.

**Solution:**
```bash
# Preview what would change
dotfiles diff --restore   # See what restore would do
dotfiles diff --sync      # See what sync would do

# Choose direction:
# To use vault version:
dotfiles vault pull

# To push local to vault:
dotfiles vault push --all
```

### Vault CLI not found

**Symptom:** Vault CLI not installed.

**Solution:**
```bash
# Bitwarden
brew install bitwarden-cli  # macOS
npm install -g @bitwarden/cli  # Linux

# 1Password
brew install --cask 1password-cli  # macOS
# See 1Password docs for Linux

# pass
brew install pass  # macOS
sudo apt install pass  # Linux
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
dotfiles doctor --fix
```

### AWS credentials permissions

**Symptom:** AWS CLI warns about credential file permissions.

**Solution:**
```bash
chmod 600 ~/.aws/credentials
chmod 600 ~/.aws/config

# Or use doctor
dotfiles doctor --fix
```

## Backup / Restore Issues

### "No backups found"

**Symptom:** `dotfiles backup restore` says no backups exist.

**Solution:**
```bash
# Check backup directory
ls -la ~/.dotfiles-backups/

# Create a backup first
dotfiles backup

# List available backups
dotfiles backup --list
```

### Restore from specific backup

**Symptom:** Need to restore a specific backup.

**Solution:**
```bash
# List backups with dates
dotfiles backup --list

# Interactive restore (shows selection)
dotfiles backup restore

# Manual restore
tar -xzf ~/.dotfiles-backups/backup-YYYYMMDD-HHMMSS.tar.gz -C /
```

## Platform-Specific Issues

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
# Mount dotfiles as volume
docker run -v ~/workspace/dotfiles:/root/workspace/dotfiles ...

# Or use the development image
docker build -t dotfiles-dev .
docker run -it dotfiles-dev
```

## Upgrade Issues

### Upgrade fails with merge conflicts

**Symptom:** `dotfiles upgrade` fails with git errors.

**Solution:**
```bash
cd ~/workspace/dotfiles

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

**Solution:**
```bash
# Ensure bootstrap ran
./bootstrap/bootstrap-mac.sh  # or bootstrap-linux.sh

# Reload shell
exec zsh

# Check version
head -5 ~/workspace/dotfiles/README.md
```

## Still Having Issues?

1. **Run full diagnostics:**
   ```bash
   dotfiles doctor
   dotfiles status
   ```

2. **Check logs:**
   ```bash
   # Installation metrics
   cat ~/.dotfiles-metrics.jsonl | tail -20
   ```

3. **Reset to clean state:**
   ```bash
   # Backup first!
   dotfiles backup

   # Uninstall
   dotfiles uninstall --dry-run  # Preview
   dotfiles uninstall            # Execute

   # Reinstall
   curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash
   ```

4. **Report an issue:**
   - [Open GitHub Issue](https://github.com/blackwell-systems/dotfiles/issues/new)
   - Include output of `dotfiles doctor`
   - Include your OS version and shell version
