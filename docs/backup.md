# Backup System

The backup system creates timestamped snapshots of your configuration files, enabling quick recovery and safe experimentation with settings.

---

## Quick Start

```bash
# Create a backup
dotfiles backup

# List available backups
dotfiles backup --list

# Restore from latest backup
dotfiles backup restore

# Restore specific backup
dotfiles backup restore backup-20241205-143022
```

---

## Overview

### What Gets Backed Up

The backup system captures essential configuration files:

| Category | Files |
|----------|-------|
| **SSH** | `~/.ssh/config`, `~/.ssh/known_hosts` |
| **Git** | `~/.gitconfig` |
| **AWS** | `~/.aws/config`, `~/.aws/credentials` |
| **Shell** | `~/.zshrc`, `~/.p10k.zsh` |
| **Secrets** | `~/.local/env.secrets` |
| **Templates** | `~/.config/dotfiles/template-variables.sh` |

> **Note:** SSH private keys are NOT backed up by the backup system. Use the vault system (`dotfiles vault push/pull`) for key management.

### Backup Format

Each backup is stored as a compressed tar archive with a manifest:

```
~/.dotfiles-backups/
├── backup-20241205-143022.tar.gz
├── backup-20241204-091500.tar.gz
└── backup-20241203-180000.tar.gz
```

The manifest contains metadata:

```json
{
    "timestamp": "20241205-143022",
    "date": "2024-12-05T14:30:22+00:00",
    "hostname": "macbook-pro",
    "files_count": 8,
    "compressed": true,
    "dotfiles_version": "abc1234"
}
```

---

## Commands

### `dotfiles backup`

Create a new backup of all tracked configuration files.

```bash
dotfiles backup
```

Output:
```
[INFO] Creating backup: backup-20241205-143022
[OK] Backup created: backup-20241205-143022.tar.gz (8 files, compressed)
```

### `dotfiles backup --list`

List all available backups with their sizes and compression status.

```bash
dotfiles backup --list
```

Output:
```
Available backups (max: 10, retention: 30d):
================================================================
  backup-20241205-143022  (24K) [compressed]
  backup-20241204-091500  (24K) [compressed]
  backup-20241203-180000  (22K) [compressed]

Restore with: dotfiles backup restore [backup-name]
Location: /Users/john/.dotfiles-backups
```

### `dotfiles backup restore [ID]`

Restore files from a backup. Uses the latest backup if no ID specified.

```bash
# Restore from latest
dotfiles backup restore

# Restore specific backup
dotfiles backup restore backup-20241203-180000
```

Output:
```
[INFO] Restoring from: backup-20241203-180000.tar.gz
[OK] Restored: .ssh/config
[OK] Restored: .gitconfig
[OK] Restored: .aws/config
[OK] Restored: .zshrc

[OK] Restored 4 files from backup-20241203-180000
```

### `dotfiles backup --config`

Show current backup configuration.

```bash
dotfiles backup --config
```

Output:
```
Backup Configuration:
=====================
  enabled:        true
  max_snapshots:  10
  retention_days: 30
  compress:       true
  location:       /Users/john/.dotfiles-backups
```

---

## Configuration

Configure the backup system in `~/.config/dotfiles/config.json`:

```json
{
  "backup": {
    "enabled": true,
    "max_snapshots": 10,
    "retention_days": 30,
    "compress": true,
    "location": "~/.dotfiles-backups"
  }
}
```

### Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `enabled` | boolean | `true` | Enable/disable backup system |
| `max_snapshots` | number | `10` | Maximum backups to keep |
| `retention_days` | number | `30` | Days to keep backups (0 = forever) |
| `compress` | boolean | `true` | Use gzip compression |
| `location` | string | `~/.dotfiles-backups` | Backup storage directory |

### Setting Configuration

Use the config command to modify settings:

```bash
# Increase max snapshots
dotfiles config set backup.max_snapshots 20

# Change retention period
dotfiles config set backup.retention_days 60

# Disable compression (for debugging)
dotfiles config set backup.compress false

# Change backup location
dotfiles config set backup.location "~/Dropbox/dotfiles-backups"

# Disable backup system
dotfiles config set backup.enabled false
```

---

## Automatic Cleanup

The backup system automatically manages disk usage:

### Snapshot Limit

When the number of backups exceeds `max_snapshots`, the oldest backups are deleted:

```
[INFO] Cleaning up 2 old backup(s) (max: 10)...
```

### Retention Policy

Backups older than `retention_days` are removed:

```
[INFO] Removing 3 backup(s) older than 30 days...
```

Set `retention_days: 0` to disable age-based cleanup (only snapshot limit applies).

---

## Use Cases

### Before Major Changes

Create a backup before modifying critical configs:

```bash
# Backup current state
dotfiles backup

# Make changes to .gitconfig, .ssh/config, etc.
vim ~/.gitconfig

# If something breaks, restore
dotfiles backup restore
```

### Before Upgrades

Backup before running dotfiles upgrade:

```bash
dotfiles backup
dotfiles upgrade
```

### Syncing with Cloud Storage

Store backups in cloud-synced folder:

```bash
# Set backup location to Dropbox
dotfiles config set backup.location "~/Dropbox/dotfiles-backups"

# Or iCloud
dotfiles config set backup.location "~/Library/Mobile Documents/com~apple~CloudDocs/dotfiles-backups"

# Create backup (now syncs to cloud)
dotfiles backup
```

### Migrating to New Machine

On old machine:
```bash
# Create backup
dotfiles backup

# Copy backup to new machine
scp ~/.dotfiles-backups/backup-*.tar.gz newmachine:~/.dotfiles-backups/
```

On new machine:
```bash
# Install dotfiles
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash

# Create backup directory
mkdir -p ~/.dotfiles-backups

# Restore from copied backup
dotfiles backup restore
```

---

## Backup vs Vault

| Feature | Backup | Vault |
|---------|--------|-------|
| **Purpose** | Quick snapshots | Secure sync across machines |
| **Storage** | Local filesystem | Bitwarden/1Password/pass |
| **Encryption** | Optional (gzip) | Yes (vault encryption) |
| **SSH Keys** | No (configs only) | Yes (full key sync) |
| **Secrets** | env.secrets file | All secret files |
| **Use Case** | Before changes | Multi-machine sync |

**Recommendation:**
- Use **backup** for local safety net before making changes
- Use **vault** for syncing secrets across machines

---

## Troubleshooting

### Backup Disabled

```
[WARN] Backup system is disabled in config
Enable with: dotfiles config set backup.enabled true
```

Enable with:
```bash
dotfiles config set backup.enabled true
```

### No Backups Found

```
[WARN] No backups found in /Users/john/.dotfiles-backups
Create one with: dotfiles backup
```

The backup directory doesn't exist or is empty. Create your first backup:
```bash
dotfiles backup
```

### Corrupted Backup

```
[FAIL] Failed to extract backup (corrupted or invalid archive)
```

The backup file is corrupted. Try restoring from a different backup:
```bash
dotfiles backup --list
dotfiles backup restore backup-20241204-091500
```

### Disk Space

If running low on disk space, reduce retention:
```bash
# Keep only 5 backups
dotfiles config set backup.max_snapshots 5

# Keep for only 7 days
dotfiles config set backup.retention_days 7

# Run backup to trigger cleanup
dotfiles backup
```

---

## Integration with Other Commands

### Doctor Checks

`dotfiles doctor` includes backup system health checks:

```
── Backup System ──
✓ Backup system enabled
✓ Found 8 backup(s)
✓ Latest backup: 2 hours ago
```

### Vault Pull

`dotfiles vault pull` creates an auto-backup before restoring secrets:

```bash
dotfiles vault pull
# [INFO] Creating auto-backup before restore...
# [OK] Backup created: backup-20241205-143022.tar.gz
# [INFO] Restoring secrets from vault...
```

### macOS Settings

`dotfiles macos apply --backup` backs up settings before applying:

```bash
dotfiles macos apply --backup
```

---

## Technical Details

### Backup Process

1. Check if backup is enabled in config
2. Create timestamped directory in backup location
3. Copy each tracked file (preserving directory structure)
4. Generate manifest.json with metadata
5. Create tar archive (compressed if enabled)
6. Clean up temporary directory
7. Run automatic cleanup (snapshot limit + retention)

### File Structure Inside Archive

```
backup-20241205-143022/
├── manifest.json
├── .ssh/
│   ├── config
│   └── known_hosts
├── .gitconfig
├── .aws/
│   ├── config
│   └── credentials
├── .zshrc
├── .p10k.zsh
├── .local/
│   └── env.secrets
└── .config/
    └── dotfiles/
        └── template-variables.sh
```

### Adding Custom Files

To add additional files to backup, modify the `BACKUP_FILES` array in `bin/dotfiles-backup`:

```zsh
BACKUP_FILES=(
    "$HOME/.ssh/config"
    "$HOME/.ssh/known_hosts"
    # ... existing files ...
    "$HOME/.config/my-app/settings.json"  # Add custom file
)
```

---

## Related Documentation

- [Vault System](vault-README.md) - Secret sync across machines
- [CLI Reference](cli-reference.md) - All commands
- [Troubleshooting](troubleshooting.md) - Common issues
