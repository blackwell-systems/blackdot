# Devcontainer Support

Blackdot provides first-class support for development containers, enabling consistent environments across VS Code, GitHub Codespaces, and DevPod.

---

## Quick Start

Generate a devcontainer configuration for your project:

```bash
# Interactive mode
blackdot devcontainer init

# Or specify options directly
blackdot devcontainer init --image go --preset developer
```

This creates a `.devcontainer/devcontainer.json` ready for use.

---

## Using the Blackdot Feature

The easiest way to add blackdot to any devcontainer is using the published feature:

```json
{
  "name": "My Development Container",
  "image": "mcr.microsoft.com/devcontainers/go:1.23",
  "features": {
    "ghcr.io/blackwell-systems/blackdot:1": {
      "preset": "developer"
    }
  }
}
```

### Feature Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `preset` | string | `developer` | Blackdot preset to apply |
| `version` | string | `latest` | Blackdot version to install |
| `shellIntegration` | boolean | `true` | Add shell integration to profiles |

### Available Presets

| Preset | Description | Best For |
|--------|-------------|----------|
| `minimal` | Shell config only | Fast startup, CI environments |
| `developer` | Vault, AWS, Git hooks, modern CLI | General development |
| `claude` | Claude Code integration + vault | AI-assisted development |
| `full` | All features enabled | Full-featured workstation |

---

## CLI Commands

### `blackdot devcontainer init`

Generate a devcontainer.json configuration.

```bash
blackdot devcontainer init [OPTIONS]
```

**Options:**

| Option | Short | Description |
|--------|-------|-------------|
| `--image` | | Base image (go, rust, python, node, java, ubuntu, alpine) |
| `--preset` | | Blackdot preset (minimal, developer, claude, full) |
| `--output` | `-o` | Output directory (default: .devcontainer) |
| `--force` | `-f` | Overwrite existing configuration |
| `--no-extensions` | | Don't include VS Code extensions |

**Examples:**

```bash
# Go development with full tools
blackdot devcontainer init --image go --preset developer

# Python for Claude Code sessions
blackdot devcontainer init --image python --preset claude

# Minimal Rust container
blackdot devcontainer init --image rust --preset minimal
```

### `blackdot devcontainer images`

List available base images.

```bash
blackdot devcontainer images
```

---

## Available Base Images

| Language | Image | VS Code Extensions |
|----------|-------|-------------------|
| Go 1.23 | `mcr.microsoft.com/devcontainers/go:1.23` | golang.go |
| Rust | `mcr.microsoft.com/devcontainers/rust:latest` | rust-lang.rust-analyzer |
| Python 3.13 | `mcr.microsoft.com/devcontainers/python:3.13` | ms-python.python |
| Node 22 | `mcr.microsoft.com/devcontainers/typescript-node:22` | dbaeumer.vscode-eslint |
| Java 21 | `mcr.microsoft.com/devcontainers/java:21` | vscjava.vscode-java-pack |
| Ubuntu | `mcr.microsoft.com/devcontainers/base:ubuntu` | - |
| Alpine | `mcr.microsoft.com/devcontainers/base:alpine` | - |
| Debian | `mcr.microsoft.com/devcontainers/base:debian` | - |

---

## SSH Agent Forwarding

Generated configurations automatically include SSH agent forwarding:

```json
{
  "mounts": [
    "source=${localEnv:SSH_AUTH_SOCK},target=/ssh-agent,type=bind,consistency=cached"
  ],
  "containerEnv": {
    "SSH_AUTH_SOCK": "/ssh-agent"
  }
}
```

This allows git operations inside the container to use your host's SSH keys without copying private keys into the container.

**Requirements:**
- SSH agent running on host (`ssh-agent` or system keychain)
- Keys added to agent (`ssh-add ~/.ssh/id_ed25519`)

---

## GitHub Codespaces

Blackdot works seamlessly with GitHub Codespaces:

1. Add `.devcontainer/devcontainer.json` to your repository
2. Open repository in Codespaces
3. Run `blackdot setup` when the container starts

The `postStartCommand` in generated configs automatically runs setup:

```json
{
  "postStartCommand": "blackdot setup --preset developer"
}
```

### Codespaces Secrets

For vault access in Codespaces, configure repository secrets:

1. Go to **Settings → Secrets and variables → Codespaces**
2. Add your vault credentials:
   - `BW_SESSION` for Bitwarden
   - `OP_SERVICE_ACCOUNT_TOKEN` for 1Password

---

## VS Code Remote Containers

1. Install the "Dev Containers" extension
2. Generate config: `blackdot devcontainer init --image go`
3. Open command palette: **Dev Containers: Reopen in Container**

---

## DevPod

DevPod is an open-source alternative to GitHub Codespaces:

```bash
# Install DevPod
brew install devpod

# Create workspace from repository
devpod up github.com/your/repo
```

DevPod automatically detects `.devcontainer/devcontainer.json`.

---

## Custom Configurations

### Adding More Features

Combine blackdot with other devcontainer features:

```json
{
  "features": {
    "ghcr.io/blackwell-systems/blackdot:1": {
      "preset": "developer"
    },
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": {}
  }
}
```

### Custom postStartCommand

Override the default setup:

```json
{
  "postStartCommand": "blackdot setup --preset claude && blackdot vault pull"
}
```

### Environment Variables

Pass environment variables to the container:

```json
{
  "containerEnv": {
    "BLACKDOT_VAULT_BACKEND": "1password",
    "BLACKDOT_FEATURE_VAULT": "true"
  }
}
```

---

## Troubleshooting

### SSH Agent Not Working

**Symptom:** Git operations fail with "Permission denied (publickey)"

**Solution:**
1. Verify SSH agent is running: `ssh-add -l`
2. Add keys if needed: `ssh-add ~/.ssh/id_ed25519`
3. Check socket exists: `echo $SSH_AUTH_SOCK`

### Feature Installation Fails

**Symptom:** Container build fails during blackdot feature installation

**Solution:**
1. Check network connectivity
2. Verify ghcr.io is accessible
3. Try specific version: `"ghcr.io/blackwell-systems/blackdot:1.0.0"`

### Vault Access in Codespaces

**Symptom:** `blackdot vault pull` fails in Codespaces

**Solution:**
1. Add vault credentials to Codespaces secrets
2. Or use `blackdot setup` to configure vault interactively

---

## See Also

- [CLI Reference](cli-reference.md#devcontainer-commands) - Full command documentation
- [Feature Registry](features.md) - All blackdot features
- [Claude Code Integration](claude-code.md) - AI-assisted development
- [Vault System](vault-README.md) - Secret management
