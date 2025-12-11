# Security Policy

## Overview

This blackdot repository contains configurations and scripts for managing development environments. While the repository itself contains no secrets (all sensitive data is stored in your vault—Bitwarden, 1Password, or pass), we take security seriously.

## Supported Versions

We provide security updates for the latest release only:

| Version | Supported          |
| ------- | ------------------ |
| Latest (main branch) | :white_check_mark: |
| Older releases | :x: |

**Recommendation:** Always use the latest version from the `main` branch.

## Reporting a Vulnerability

### Please DO NOT Report Security Vulnerabilities Publicly

If you discover a security vulnerability, please help us responsibly:

**Preferred Method: GitHub Security Advisories**
1. Go to https://github.com/blackwell-systems/blackdot/security/advisories
2. Click "Report a vulnerability"
3. Provide detailed information about the issue

**Alternative Method: Private Issue**
1. Contact the maintainer through GitHub (@your-username)
2. Include details about the vulnerability
3. Wait for acknowledgment before public disclosure

### What to Include

When reporting a security issue, please include:

- **Description:** Clear description of the vulnerability
- **Impact:** What could an attacker do with this vulnerability?
- **Reproduction:** Steps to reproduce the issue
- **Affected Files:** Which scripts or configurations are affected
- **Suggested Fix:** (Optional) How you would fix it

### Example Security Issues

Issues we consider security-relevant:

- ✅ Scripts that could accidentally leak credentials
- ✅ File permission issues that expose sensitive data
- ✅ Command injection vulnerabilities
- ✅ Insecure defaults in configurations
- ✅ Path traversal issues in bootstrap scripts

Not security issues:

- ❌ General bugs (use regular issues)
- ❌ Feature requests
- ❌ Questions about usage

## Security Best Practices

When using blackdot:

### 1. Never Commit Secrets

- All secrets should be stored in your vault (Bitwarden, 1Password, or pass)
- The `.gitignore` file protects common secret files
- Pre-commit hooks scan for leaked credentials
- Always review changes before committing: `git diff`

### 2. Verify Script Integrity

Before running bootstrap scripts on a new machine:

```bash
# Verify you're on the official repository
git remote -v

# Check recent commits for suspicious changes
git log --oneline -10

# Review bootstrap script before running
cat bootstrap-mac.sh  # or bootstrap-linux.sh
```

### 3. Protect Your Vault

- Use a strong master password (20+ characters)
- Enable two-factor authentication (2FA)
- Keep your vault CLI up to date:
  - Bitwarden: `brew upgrade bitwarden-cli`
  - 1Password: `brew upgrade --cask 1password-cli`
  - pass: `brew upgrade pass`
- Lock your vault when not in use (e.g., `bw lock` for Bitwarden)

### 4. File Permissions

The health check validates file permissions:

```bash
# Check permissions
blackdot doctor

# Auto-fix permission issues
blackdot doctor --fix
```

Expected permissions:
- Private keys: `600` (owner read/write only)
- Public keys: `644` (owner read/write, others read)
- SSH config: `600` (owner read/write only)
- AWS credentials: `600` (owner read/write only)
- Shell configs: `644` (owner read/write, others read)

### 5. Keep Software Updated

```bash
# Update blackdot
blackdot upgrade

# Update Homebrew packages
brew update && brew upgrade

# Update vault CLI
brew upgrade bitwarden-cli   # or: brew upgrade --cask 1password-cli / brew upgrade pass
```

## Known Security Considerations

### Session Caching

The vault system caches sessions in `vault/.vault-session`:
- File has `600` permissions (owner-only access)
- Automatically expires after vault timeout
- **Recommendation:** Lock your vault when leaving your machine (e.g., `bw lock` for Bitwarden)

### SSH Agent

SSH keys are automatically added to the agent:
- Agent stores decrypted private keys in memory
- Keys remain loaded until logout or `ssh-add -D`
- **Recommendation:** Use passphrase-protected keys

### Shared History

Shell history is stored in `~/workspace/.zsh_history`:
- Shared between macOS and Lima VM
- May contain sensitive commands
- **Recommendation:** Prefix sensitive commands with a space to exclude from history

```bash
# This will be in history
echo "public command"

# Leading space prevents history recording (if HIST_IGNORE_SPACE is set)
 echo "sensitive command with secret"
```

### Lima VM Mounts

Lima mounts your macOS home directory:
- Files in `~/workspace` are shared between host and VM
- File permissions preserved
- **Recommendation:** Keep sensitive files in home directory, not workspace

## Security Update Process

When a security issue is reported:

1. **Acknowledgment:** Within 48 hours
2. **Assessment:** Severity and impact evaluation (1-3 days)
3. **Fix Development:** Patch created and tested (1-7 days)
4. **Disclosure:**
   - Fix merged to main branch
   - Security advisory published
   - CHANGELOG updated
   - Users notified via GitHub release

## Disclosure Policy

- **Responsible Disclosure:** We ask for 90 days before public disclosure
- **Credit:** Security researchers will be credited in release notes (unless they prefer anonymity)
- **Coordination:** We'll work with you on disclosure timeline

## Security Checklist for Contributors

When contributing code:

- [ ] No hardcoded credentials or API keys
- [ ] File permissions are restrictive (600/644/700)
- [ ] User input is validated/sanitized
- [ ] File paths don't allow traversal attacks
- [ ] Shell commands properly quote variables
- [ ] Secrets are never logged or printed
- [ ] Pre-commit hooks pass (includes secret scanning)

## Questions?

For general security questions (not vulnerabilities):
- Open a [GitHub Discussion](https://github.com/blackwell-systems/blackdot/discussions)
- Review the [Security Maintenance](README.md#security-maintenance) section in README

## Contact

- **Security Issues:** Use GitHub Security Advisories (preferred)
- **General Questions:** GitHub Discussions
- **Maintainer:** See GitHub profile for contact options

---

**Last Updated:** 2025-11-27
