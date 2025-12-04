# Docker Containers

Test dotfiles in isolated containers before installing on your system.

## Container Options

| Container | Base | Size | Build Time | Use Case |
|-----------|------|------|------------|----------|
| [extralite](#extralite) | Alpine | ~50MB | ~10s | Quick exploration |
| [lite](#lite) | Alpine | ~200MB | ~60s | Vault command testing |
| [medium](#medium) | Ubuntu | ~400MB | ~3min | Full CLI + Homebrew |
| [full](#full) | Ubuntu | ~800MB+ | ~5min | Complete environment |

---

## extralite

**The fastest option for quick exploration.**

```bash
docker build -f Dockerfile.extralite -t dotfiles-extralite .
docker run -it --rm dotfiles-extralite
```

**Includes:**
- Zsh, bash, git, jq, curl
- All `dotfiles` CLI commands
- `/workspace` symlink

**Does NOT include:**
- Vault CLIs (bw, op, pass, gpg)
- Homebrew
- Package installation

**Best for:** "Does this CLI work?" testing, exploring commands, reading help.

---

## lite

**Alpine with vault CLI support.**

```bash
docker build -f Dockerfile.lite -t dotfiles-lite .
docker run -it --rm dotfiles-lite
```

**Includes:**
- Everything in extralite, plus:
- Bitwarden CLI (`bw`)
- 1Password CLI (`op`)
- pass + GPG

**Usage with vault backends:**

```bash
# Bitwarden
docker run -it --rm -e BW_SESSION="$BW_SESSION" dotfiles-lite

# 1Password
docker run -it --rm dotfiles-lite
# Then: eval $(op signin)

# pass (mount GPG keys)
docker run -it --rm -v ~/.gnupg:/root/.gnupg:ro dotfiles-lite
```

**Best for:** Testing vault restore/sync, verifying secrets integration.

---

## medium

**Ubuntu with Homebrew - can install any package.**

```bash
docker build -f Dockerfile.medium -t dotfiles-medium .
docker run -it --rm dotfiles-medium
```

**Includes:**
- Everything in lite, plus:
- Homebrew (fully functional)
- Can install additional packages

**Does NOT include (to keep size down):**
- eza, fzf, ripgrep, bat, etc.
- Powerlevel10k theme
- Full Brewfile packages

**Add packages as needed:**

```bash
# Inside container
brew install eza fzf ripgrep bat

# Or install full Brewfile
brew bundle --file=/root/workspace/dotfiles/Brewfile
```

**Best for:** Testing with specific brew packages, development workflows.

---

## full

**Complete environment with all packages.**

```bash
docker build -t dotfiles-full .
docker run -it --rm dotfiles-full
```

**Includes:**
- Full bootstrap (runs `bootstrap-linux.sh`)
- All Brewfile packages installed
- Complete development environment

**Best for:** CI/CD, reproducible builds, full integration testing.

---

## Comparison

| Feature | extralite | lite | medium | full |
|---------|-----------|------|--------|------|
| `dotfiles help` | ✓ | ✓ | ✓ | ✓ |
| `dotfiles status` | ✓ | ✓ | ✓ | ✓ |
| `dotfiles doctor` | ✓ | ✓ | ✓ | ✓ |
| `dotfiles setup` | ✓ | ✓ | ✓ | ✓ |
| `dotfiles vault pull` | ✗ | ✓ | ✓ | ✓ |
| Bitwarden CLI | ✗ | ✓ | ✓ | ✓ |
| 1Password CLI | ✗ | ✓ | ✓ | ✓ |
| pass + GPG | ✗ | ✓ | ✓ | ✓ |
| Homebrew | ✗ | ✗ | ✓ | ✓ |
| eza, fzf, ripgrep | ✗ | ✗ | ✗ | ✓ |
| Powerlevel10k | ✗ | ✗ | ✗ | ✓ |

---

## Testing with Mock Vault (pass backend)

Test vault functionality without real credentials using the mock vault setup. This creates a fake GPG key and populates a `pass` (password-store) with test credentials.

> **Note:** The mock vault only works with the `pass` backend. For Bitwarden or 1Password testing, you'll need real vault access.

```bash
# Start lite container
docker run -it --rm dotfiles-lite

# Inside container: setup mock vault with fake credentials
./test/mocks/setup-mock-vault.sh --no-pass  # Creates fake GPG key + pass store

# Switch to pass backend
export DOTFILES_VAULT_BACKEND=pass

# Test vault commands
dotfiles vault check
dotfiles vault pull --preview
dotfiles drift
```

**What it creates:**

| Item | Description |
|------|-------------|
| `SSH-GitHub-Enterprise` | Mock SSH private key |
| `SSH-GitHub-Blackwell` | Mock SSH private key |
| `SSH-Config` | Sample SSH configuration |
| `AWS-Config` | Mock AWS config (profiles) |
| `AWS-Credentials` | Fake AWS credentials |
| `Git-Config` | Sample git configuration |
| `Environment-Secrets` | Mock env vars (API keys) |
| `Claude-Profiles` | Sample Claude profiles JSON |

**Options:**
- `--no-pass` - No GPG passphrase (for automated testing)
- `--clean` - Remove existing mock vault first

**All credentials are FAKE and for testing only!**

---

## Tips

### Mount local dotfiles for testing changes

```bash
docker run -it --rm -v $PWD:/root/workspace/dotfiles dotfiles-lite
```

### Persist home directory between runs

```bash
docker run -it --rm -v dotfiles-home:/root dotfiles-lite
```

### Run specific command and exit

```bash
docker run --rm dotfiles-lite dotfiles doctor
```

---

## Which should I use?

```
Want to...                          → Use
─────────────────────────────────────────────
See if CLI works                    → extralite
Test vault restore/sync             → lite
Install specific brew packages      → medium
Full integration test               → full
CI/CD pipeline                      → full
```
