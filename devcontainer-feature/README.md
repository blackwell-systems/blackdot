# Blackdot Devcontainer Feature

This feature installs [Blackdot](https://github.com/blackwell-systems/blackdot), a vault-backed configuration management system for development environments.

## Usage

Add this feature to your `devcontainer.json`:

```json
{
  "features": {
    "ghcr.io/blackwell-systems/blackdot:1": {}
  }
}
```

With options:

```json
{
  "features": {
    "ghcr.io/blackwell-systems/blackdot:1": {
      "preset": "developer",
      "version": "latest"
    }
  }
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `preset` | string | `developer` | Blackdot preset to apply (`minimal`, `developer`, `claude`, `full`) |
| `version` | string | `latest` | Blackdot version to install |
| `shellIntegration` | boolean | `true` | Add blackdot shell integration to profiles |

## Presets

| Preset | Description |
|--------|-------------|
| `minimal` | Shell config only (fastest startup) |
| `developer` | Vault, AWS helpers, Git hooks, modern CLI tools |
| `claude` | Claude Code integration + vault + git hooks |
| `full` | All features enabled |

## Post-Start Setup

After the container starts, run:

```bash
blackdot setup
```

This will:
1. Prompt for vault authentication (Bitwarden/1Password/pass)
2. Restore your SSH keys, AWS credentials, and other secrets
3. Apply your shell configuration

## SSH Agent Forwarding

For best results, configure SSH agent forwarding in your `devcontainer.json`:

```json
{
  "mounts": [
    "source=${localEnv:SSH_AUTH_SOCK},target=/ssh-agent,type=bind"
  ],
  "containerEnv": {
    "SSH_AUTH_SOCK": "/ssh-agent"
  }
}
```

This allows you to use your host's SSH keys without copying them into the container.

## Quick Start

Generate a complete devcontainer configuration:

```bash
blackdot devcontainer init
```

This creates a `.devcontainer/devcontainer.json` with:
- Microsoft base image for your language
- Blackdot feature configured
- SSH agent forwarding
- VS Code extension recommendations

## Links

- [Blackdot Documentation](https://github.com/blackwell-systems/blackdot)
- [Devcontainer Specification](https://containers.dev/)
- [VS Code Remote Containers](https://code.visualstudio.com/docs/remote/containers)
