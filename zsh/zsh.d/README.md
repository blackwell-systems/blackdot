# Zsh Configuration Modules

This directory contains modular Zsh configuration files loaded by `~/.zshrc`.

## Load Order

Files are sourced in numerical order:

1. **00-init.zsh** - Powerlevel10k instant prompt, OS detection
2. **10-plugins.zsh** - Completions and plugin loading
3. **20-env.zsh** - Environment variables, workspace, history
4. **30-tools.zsh** - Modern CLI tools (eza, fzf, bat, jq, yq)
5. **40-aliases.zsh** - Basic aliases and navigation helpers
6. **50-functions.zsh** - Shell functions (notes, project navigation, status)
7. **60-aws.zsh** - AWS profile management and SSO helpers
8. **70-claude.zsh** - Claude Code wrapper and routing
9. **80-git.zsh** - Git shortcuts and aliases
10. **90-integrations.zsh** - Zoxide, glow, update checker, lazy loaders
11. **99-local.zsh** - Machine-specific overrides (gitignored)

## Disabling Modules

To disable a module, rename it with a `.disabled` extension:

```bash
mv zsh/zsh.d/60-aws.zsh zsh/zsh.d/60-aws.zsh.disabled
```

Or comment out the source line in `~/.zshrc`.

## Adding Custom Modules

Create new modules following the naming convention:

```bash
# zsh/zsh.d/85-custom.zsh
# Custom functionality here
```

Then add to the source list in `~/.zshrc`.

## Machine-Specific Config

Put machine-specific configuration in `99-local.zsh` (gitignored):

```bash
# ~/.zshrc.local or zsh/zsh.d/99-local.zsh
export AWS_PROFILE="my-default-profile"
alias work='cd ~/workspace/work-stuff'
```
