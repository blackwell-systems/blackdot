# Contributing to Dotfiles

Thank you for your interest in contributing to this dotfiles repository! This guide will help you get started.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Testing Your Changes](#testing-your-changes)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Areas for Contribution](#areas-for-contribution)
- [Questions?](#questions)

---

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior through GitHub issues or contact the maintainer.

### Our Standards

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Accept criticism gracefully
- Prioritize the community's best interests

---

## Getting Started

### Prerequisites

- Basic knowledge of shell scripting (bash/zsh)
- Familiarity with Git and GitHub
- One of the supported platforms:
  - macOS (12.0+)
  - Ubuntu/Debian Linux
  - Lima VM
  - WSL2

### Fork and Clone

1. **Fork this repository** on GitHub (click "Fork" button)

2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/workspace/dotfiles
   cd ~/workspace/dotfiles
   ```

3. **Add upstream remote:**
   ```bash
   git remote add upstream https://github.com/blackwell-systems/blackdot.git
   ```

4. **Install the pre-commit hook:**
   ```bash
   cp .pre-commit-hook.sample .git/hooks/pre-commit
   chmod +x .git/hooks/pre-commit
   ```

---

## Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-number-description
```

**Branch naming conventions:**
- `feature/` - New features or enhancements
- `fix/` - Bug fixes
- `docs/` - Documentation improvements
- `refactor/` - Code refactoring (no behavior change)
- `test/` - Adding or improving tests

### 2. Make Your Changes

**Key principles:**
- **Idempotency** - Scripts should be safe to run multiple times
- **Cross-platform** - Test on both macOS and Linux if possible
- **Error handling** - Use `set -euo pipefail` in bash/zsh scripts
- **Documentation** - Update README.md if adding features
- **Security** - Never commit secrets or credentials

**Shell script best practices:**
```bash
#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Use functions for reusability
do_something() {
  local arg="$1"
  # Implementation
}

# Check prerequisites
if ! command -v required_tool >/dev/null 2>&1; then
  echo "Error: required_tool not found" >&2
  exit 1
fi
```

### 3. Test Your Changes

**Required tests before submitting:**

```bash
# 1. ShellCheck validation (for bash scripts)
shellcheck your-script.sh

# 2. ZSH syntax check (for zsh scripts)
zsh -n vault/your-script.sh

# 3. Run health check
blackdot doctor

# 4. Test on clean environment (if possible)
# macOS:
./bootstrap/bootstrap-mac.sh

# Linux:
./bootstrap/bootstrap-linux.sh
```

**Manual testing checklist:**
- [ ] Script runs without errors
- [ ] Script is idempotent (run twice, same result)
- [ ] Error messages are clear and helpful
- [ ] Documentation is updated
- [ ] No secrets or personal info in commits

---

## Testing Your Changes

### Unit Testing

We don't currently have unit tests, but you can validate scripts:

```bash
# Test individual vault scripts
cd vault
./restore-ssh.sh --help

# Test with dry-run mode (where available)
blackdot vault push --dry-run SSH-Config
```

### Integration Testing

**macOS:**
```bash
# Test full bootstrap on macOS
./bootstrap/bootstrap-mac.sh
blackdot doctor --fix
```

**Linux (Docker):**
```bash
# Test in Docker (Ubuntu)
docker run -it --rm -v $PWD:/dotfiles ubuntu:24.04 bash
cd /dotfiles
./bootstrap/bootstrap-linux.sh
blackdot doctor
```

### CI/CD

All pull requests automatically run:
- ShellCheck validation
- ZSH syntax validation
- Markdown linting
- Repository structure checks

View test results in the GitHub Actions tab.

---

## Commit Guidelines

### Commit Message Format

```
<type>: <short summary> (max 72 chars)

<optional body: explain WHAT and WHY, not HOW>

<optional footer: references to issues, breaking changes>
```

**Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `refactor:` - Code refactoring
- `test:` - Adding/updating tests
- `chore:` - Maintenance tasks (dependencies, CI/CD)
- `style:` - Formatting changes (no code logic change)

**Examples:**

```
feat: Add drift detection to health check

Implements --drift flag that compares local files with Bitwarden
vault items. Helps identify unsync'd changes before switching machines.

Closes #42
```

```
fix: Handle spaces in workspace paths

Bootstrap scripts now properly quote paths containing spaces.
Fixes issue on macOS with usernames like "John Doe".

Fixes #38
```

```
docs: Add security maintenance schedule to README

Documents recommended frequency for rotating SSH keys, AWS credentials,
and Bitwarden password.
```

### Pre-commit Hooks

The pre-commit hook automatically runs:
- ShellCheck on bash scripts
- ZSH syntax validation
- Secret scanning
- Repository structure validation

If checks fail, fix the issues and commit again.

---

## Pull Request Process

### 1. Update Your Branch

Before submitting, sync with upstream:

```bash
git fetch upstream
git rebase upstream/main
```

### 2. Push to Your Fork

```bash
git push origin feature/your-feature-name
```

### 3. Create Pull Request

1. Go to GitHub and create a PR from your fork
2. Fill out the PR template:
   - **Description:** What does this PR do?
   - **Motivation:** Why is this change needed?
   - **Testing:** How did you test this?
   - **Screenshots:** (if UI/output changes)
   - **Checklist:** Complete all items

### 4. Code Review

- Respond to feedback promptly
- Make requested changes in new commits
- Don't force-push after review starts
- Be open to suggestions

### 5. Merge

Once approved:
- Maintainer will squash and merge
- Your contribution will be in the next release
- Thank you! 🎉

---

## Areas for Contribution

### Good First Issues

**Easy (1-2 hours):**
- Add new Homebrew packages to Brewfile
- Fix typos in documentation
- Add examples to README
- Improve error messages

**Medium (2-4 hours):**
- Add support for new platform (Arch, Fedora)
- Create new vault restore script
- Add tab completions for commands
- Improve health check validations

**Advanced (4+ hours):**
- Implement Ansible playbook alternative
- Add web dashboard for metrics
- Create Docker-based integration tests
- Extract vault system as standalone tool

### Feature Requests

Browse [open issues](https://github.com/blackwell-systems/blackdot/issues) for ideas, or propose your own:

**Desired features:**
- [ ] Support for additional secret managers (age, pass, 1Password)
- [ ] Web-based metrics dashboard
- [ ] Automated rollback on failed upgrades
- [ ] Plugin system for extensibility
- [ ] Windows native support (not just WSL)
- [ ] Ansible/Terraform alternatives

### Documentation Improvements

- Add screenshots/GIFs to README
- Create video walkthrough (asciinema)
- Write blog post about architecture
- Translate documentation
- Add FAQ section

### Platform Support

Help test and improve support for:
- Debian/Ubuntu variants
- Arch Linux
- Fedora/RHEL
- BSD variants
- Raspberry Pi

---

## Questions?

**Before asking:**
1. Check existing [issues](https://github.com/blackwell-systems/blackdot/issues)
2. Read the [README.md](README.md) thoroughly
3. Search [discussions](https://github.com/blackwell-systems/blackdot/discussions) (if enabled)

**How to ask:**
- Open a [GitHub Issue](https://github.com/blackwell-systems/blackdot/issues/new/choose)
- Provide details: OS, version, error messages, steps to reproduce
- Include output from `blackdot doctor`

**For bugs:**
- Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md)
- Include relevant logs and error messages
- Describe expected vs actual behavior

---

## Development Setup (Advanced)

### Testing Vault Scripts

```bash
# Set up test Bitwarden account (recommended!)
export BW_SESSION="$(bw unlock --raw)"

# Test vault operations (use test account!)
./vault/check-vault-items.sh -v
blackdot vault push --dry-run SSH-Config
```

### Debugging

**Enable debug mode:**
```bash
# For vault scripts
export DEBUG=1
./vault/restore-ssh.sh

# For shell scripts
bash -x ./bootstrap/bootstrap-mac.sh
```

**Check logs:**
```bash
# Health check history
cat ~/.blackdot-metrics.jsonl | jq .

# Git operations
git log --oneline --graph
```

---

## Licensing

By contributing, you agree that your contributions will be licensed under the Apache License 2.0 (same as this project).

See [LICENSE](LICENSE) for details.

---

## Recognition

Contributors will be:
- Listed in CHANGELOG.md for their contributions
- Mentioned in release notes
- Added to GitHub contributors page
- Given credit in commit messages

Thank you for making dotfiles better! 🚀

---

## Additional Resources

- **Main Documentation:** [README.md](README.md)
- **Security Policy:** [SECURITY.md](SECURITY.md)
- **Code of Conduct:** [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- **Changelog:** [CHANGELOG.md](CHANGELOG.md)
- **Architecture Review:** [REVIEW.md](REVIEW.md)
- **Roadmap:** [RECOMMENDATIONS.md](RECOMMENDATIONS.md)
