# Test Drive: Try Before You Trust

> **Don't trust random install scripts?** Smart. Test blackdot in an isolated Alpine container before touching your system.

---

## Quick Start

```bash
# Clone and build
git clone https://github.com/blackwell-systems/blackdot.git
cd dotfiles
docker build -f Dockerfile.lite -t blackdot-lite .

# Run interactive container
docker run -it --rm blackdot-lite

# You're now in a safe container - nothing touches your host
```

When you're done, type `exit` or press `Ctrl+D`. The container is destroyed instantly.

---

## What to Try

### 1. Check Your Environment

```zsh
blackdot status
```

You'll see the city skyline dashboard showing:
- zshrc status (not linked - expected in container)
- workspace directory (missing - expected)
- ssh keys (none - safe default)
- Claude profile (none - unless you add dotclaude)

**What this shows:** The visual health monitoring system that keeps your blackdot in sync.

---

### 2. Run Health Check

```zsh
blackdot doctor
```

This validates:
- ✅ Core components present
- ⚠️ Expected warnings (no brew, not bootstrapped)
- ℹ️ Optional components (templates, vault)

**What this shows:** Comprehensive diagnostics to catch issues before they break your workflow.

---

### 3. Explore Vault System

```zsh
# See what can be synced
ls vault/

# Check vault functions
blackdot vault help

# View available backends
ls vault/backends/

# Preview what sync would do (dry run)
blackdot sync --help
```

**What this shows:** Multi-backend secret management (Bitwarden, 1Password, pass) with smart bidirectional sync - no vendor lock-in.

---

### 4. Inspect Templates

```zsh
# See machine-specific templates
ls templates/configs/

# View a template
cat templates/configs/ssh-config.tmpl

# Check default template variables
cat templates/_variables.sh

# Template variables can also be stored in vault for portability:
# ~/.config/dotfiles/template-variables.sh (XDG location, vault-synced)
# templates/_variables.local.sh (repo-local overrides)
```

**What this shows:** How templates adapt configs to different machines (work vs personal, macOS vs Linux). Variables can be stored in your vault for easy restoration on new machines.

---

### 5. Test dotclaude Integration

Want to see the Claude Code integration? Install dotclaude in the container:

```zsh
# Install dotclaude
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotclaude/main/install.sh | bash

# Reload shell to get dotclaude in PATH
exec zsh

# Create a test profile
dotclaude create test-project
dotclaude activate test-project

# Now check status again
blackdot status
# ↑ You'll see: profile ◆ test-project

# Check doctor
blackdot doctor
# ↑ Claude Code section shows ✓ all green
```

**What this shows:** Seamless integration between blackdot and dotclaude for portable Claude sessions.

---

## Sample Workflows

### Workflow 1: Explore Without Installing Anything

```zsh
# Just browse the code
cd /root/workspace/dotfiles

# Read the zsh configuration
cat zsh/zshrc

# Check available functions
ls zsh/zsh.d/

# View git integration
cat zsh/zsh.d/80-git.zsh

# Exit when done
exit
```

**Zero impact** - container destroyed, nothing persisted.

---

### Workflow 2: Test Commands Safely

```zsh
# Try all CLI commands
blackdot help
blackdot doctor
blackdot status
blackdot sync --help
blackdot packages --help
blackdot vault help

# Check what doctor validates
blackdot doctor | grep "^──"

# See all available scripts
ls bin/blackdot-*

exit
```

**Learn the CLI** without touching your system.

---

### Workflow 3: Test with Your Config (Advanced)

Mount your actual blackdot for testing:

```bash
# From host
docker run -it --rm \
  -v ~/.config/dotfiles:/root/workspace/blackdot \
  blackdot-lite

# Inside container
cd /root/workspace/dotfiles
blackdot status
blackdot doctor

exit
```

**Your files are read-only from the container** - can't accidentally break anything.

---

## What You Can't Test

Some features require a real system:

| Feature | Why Not in Container | Test How |
|---------|---------------------|----------|
| **Bootstrap** | Needs package installation | Use VM or test machine |
| **Homebrew** | Not in Alpine by default | macOS/Linux host or full Dockerfile |
| **Bitwarden sync** | No BW_SESSION | Mock with test credentials |
| **Git hooks** | No git repos in container | Clone test repo in container |
| **SSH keys** | No keys in container | Generate test keys: `ssh-keygen -t ed25519` |

---

## Container Specs

**Base:** Alpine Linux 3.19 (~20MB)

**Includes:**
- bash, zsh
- git, jq
- coreutils, util-linux
- blackdot CLI (pre-installed)

**Does NOT include:**
- Homebrew
- Your secrets/credentials
- SSH keys
- Actual configs (templates only)

---

## Next Steps

### Ready to Install?

```bash
# One-line install
curl -fsSL https://blackdot.blackwell.systems/install | bash

# Or manual
git clone https://github.com/blackwell-systems/blackdot.git ~/workspace/dotfiles
cd ~/workspace/dotfiles
./bootstrap/bootstrap-mac.sh  # or ./bootstrap/bootstrap-linux.sh
```

### Want to Learn More?

- [Full Documentation](README-FULL.md) - Complete 1,900+ line guide
- [CLI Reference](cli-reference.md) - All commands and flags
- [Vault System](vault-README.md) - Secret management deep dive
- [Templates](templates.md) - Machine-specific configuration
- [Claude Code Integration](claude-code.md) - Portable sessions

---

## FAQ

**Q: Can I break my host system from the container?**
A: No. With `--rm` flag, nothing persists. Without volume mounts, the container can't touch your files.

**Q: Can I test the actual bootstrap?**
A: Use the full `Dockerfile` (not Dockerfile.lite) for complete bootstrap testing. It installs Homebrew and runs the real bootstrap.

**Q: What if I want to save my test session?**
A: Remove the `--rm` flag and use `docker commit` to save the container state. But that defeats the "trust nothing" purpose.

**Q: Can I test with my actual secrets?**
A: You could mount your Bitwarden session, but that's risky. Better to test with mock credentials first.

**Q: How do I test the dotclaude integration properly?**
A: Install dotclaude in the container (it's just a shell script). Create test profiles. Check integration with `blackdot status` and `blackdot doctor`.

---

## Troubleshooting

### "docker: command not found"

Install Docker:
- **macOS:** `brew install --cask docker` or [Docker Desktop](https://docker.com)
- **Linux:** `curl -fsSL https://get.docker.com | sh`
- **Windows:** [Docker Desktop for Windows](https://docker.com)

### Build fails

```bash
# Clean rebuild
docker build --no-cache -f Dockerfile.lite -t blackdot-lite .
```

### Container won't start

```bash
# Check Docker is running
docker ps

# Try with explicit shell
docker run -it --rm blackdot-lite zsh
```

### Commands not found in container

```bash
# Ensure you're sourcing zshrc
source ~/.zshrc

# Or reload shell
exec zsh
```

---

**Ready to trust it?** Install for real: [Installation Guide](README-FULL.md#installation)

**Still skeptical?** Read the code: [github.com/blackwell-systems/blackdot](https://github.com/blackwell-systems/blackdot)
