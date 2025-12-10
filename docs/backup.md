# Backup System

The backup system creates timestamped snapshots of your configuration files, enabling quick recovery and safe experimentation with settings.

---

## Quick Start

```bash
# Create a backup
blackdot backup

# List available backups
blackdot backup --list

# Restore from latest backup
blackdot backup restore

# Restore specific backup
blackdot backup restore backup-20241205-143022
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
| **Templates** | `~/.config/blackdot/template-variables.sh` |

> **Note:** SSH private keys are NOT backed up by the backup system. Use the vault system (`blackdot vault push/pull`) for key management.

### Backup Format

Each backup is stored as a compressed tar archive with a manifest:

```
~/.blackdot-backups/
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

### `blackdot backup`

Create a new backup of all tracked configuration files.

```bash
blackdot backup
```

Output:
```
[INFO] Creating backup: backup-20241205-143022
[OK] Backup created: backup-20241205-143022.tar.gz (8 files, compressed)
```

### `blackdot backup --list`

List all available backups with their sizes and compression status.

```bash
blackdot backup --list
```

Output:
```
Available backups (max: 10, retention: 30d):
================================================================
  backup-20241205-143022  (24K) [compressed]
  backup-20241204-091500  (24K) [compressed]
  backup-20241203-180000  (22K) [compressed]

Restore with: dotfiles backup restore [backup-name]
Location: /Users/john/.blackdot-backups
```

### `blackdot backup restore [ID]`

Restore files from a backup. Uses the latest backup if no ID specified.

```bash
# Restore from latest
blackdot backup restore

# Restore specific backup
blackdot backup restore backup-20241203-180000
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

### `blackdot backup --config`

Show current backup configuration.

```bash
blackdot backup --config
```

Output:
```
Backup Configuration:
=====================
  enabled:        true
  max_snapshots:  10
  retention_days: 30
  compress:       true
  location:       /Users/john/.blackdot-backups
```

---

## Configuration

Configure the backup system in `~/.config/blackdot/config.json`:

```json
{
  "backup": {
    "enabled": true,
    "max_snapshots": 10,
    "retention_days": 30,
    "compress": true,
    "location": "~/.blackdot-backups"
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
| `location` | string | `~/.blackdot-backups` | Backup storage directory |

### Setting Configuration

Use the config command to modify settings:

```bash
# Increase max snapshots
blackdot config set backup.max_snapshots 20

# Change retention period
blackdot config set backup.retention_days 60

# Disable compression (for debugging)
blackdot config set backup.compress false

# Change backup location
blackdot config set backup.location "~/Dropbox/blackdot-backups"

# Disable backup system
blackdot config set backup.enabled false
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
blackdot backup

# Make changes to .gitconfig, .ssh/config, etc.
vim ~/.gitconfig

# If something breaks, restore
blackdot backup restore
```

### Before Upgrades

Backup before running dotfiles upgrade:

```bash
blackdot backup
blackdot upgrade
```

### Syncing with Cloud Storage

Store backups in cloud-synced folder:

```bash
# Set backup location to Dropbox
blackdot config set backup.location "~/Dropbox/blackdot-backups"

# Or iCloud
blackdot config set backup.location "~/Library/Mobile Documents/com~apple~CloudDocs/blackdot-backups"

# Create backup (now syncs to cloud)
blackdot backup
```

### Migrating to New Machine

On old machine:
```bash
# Create backup
blackdot backup

# Copy backup to new machine
scp ~/.blackdot-backups/backup-*.tar.gz newmachine:~/.blackdot-backups/
```

On new machine:
```bash
# Install dotfiles
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install.sh | bash

# Create backup directory
mkdir -p ~/.blackdot-backups

# Restore from copied backup
blackdot backup restore
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
blackdot config set backup.enabled true
```

### No Backups Found

```
[WARN] No backups found in /Users/john/.blackdot-backups
Create one with: dotfiles backup
```

The backup directory doesn't exist or is empty. Create your first backup:
```bash
blackdot backup
```

### Corrupted Backup

```
[FAIL] Failed to extract backup (corrupted or invalid archive)
```

The backup file is corrupted. Try restoring from a different backup:
```bash
blackdot backup --list
blackdot backup restore backup-20241204-091500
```

### Disk Space

If running low on disk space, reduce retention:
```bash
# Keep only 5 backups
blackdot config set backup.max_snapshots 5

# Keep for only 7 days
blackdot config set backup.retention_days 7

# Run backup to trigger cleanup
blackdot backup
```

---

## Integration with Other Commands

### Doctor Checks

`blackdot doctor` includes backup system health checks:

```
── Backup System ──
✓ Backup system enabled
✓ Found 8 backup(s)
✓ Latest backup: 2 hours ago
```

### Vault Pull

`blackdot vault pull` creates an auto-backup before restoring secrets:

```bash
blackdot vault pull
# [INFO] Creating auto-backup before restore...
# [OK] Backup created: backup-20241205-143022.tar.gz
# [INFO] Restoring secrets from vault...
```

### macOS Settings

`blackdot macos apply --backup` backs up settings before applying:

```bash
blackdot macos apply --backup
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

To add additional files to backup, modify the backup file list in `internal/cli/backup.go`:

```go
// Default backup files
var defaultBackupFiles = []string{
    ".ssh/config",
    ".ssh/known_hosts",
    // ... existing files ...
    ".config/my-app/settings.json",  // Add custom file
}
```

---

## Related Documentation

- [Vault System](vault-README.md) - Secret sync across machines
- [CLI Reference](cli-reference.md) - All commands
- [Troubleshooting](troubleshooting.md) - Common issues
