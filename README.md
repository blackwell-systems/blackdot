# Dotfiles Setup

This repository contains my personal dotfiles for **macOS** and **Lima** (Linux), used to configure my development environment consistently across both platforms. The dotfiles include configurations for **Zsh**, **Powerlevel10k**, **Homebrew**, **Claude helpers**, and more.

## Directory Structure

The dotfiles are organized as follows:

```text
~/workspace/dotfiles
├── bootstrap-dotfiles.sh     # Shared symlink bootstrap (zshrc, p10k, Ghostty)
├── bootstrap-lima.sh         # Lima / Linux-specific bootstrap wrapper
├── bootstrap-mac.sh          # macOS-specific bootstrap wrapper
├── Brewfile                  # Unified Homebrew bundle (macOS + Lima)
├── ghostty
│   └── config                # Ghostty terminal config
├── lima
│   └── lima.yaml             # Lima VM config (host-side)
├── vault
│   ├── bootstrap-vault.sh    # Orchestrates all Bitwarden restores
│   ├── restore-ssh.sh        # Restores SSH keys from Bitwarden
│   ├── restore-aws.sh        # Restores ~/.aws/config & ~/.aws/credentials
│   └── restore-env.sh        # Restores environment secrets to ~/.local
└── zsh
    ├── p10k.zsh              # Powerlevel10k theme config
    └── zshrc                 # Main Zsh configuration
```

- **zshrc**: Main Zsh configuration file  
- **p10k.zsh**: Powerlevel10k theme configuration  
- **ghostty/config**: Ghostty terminal configuration  

Symlinks in your home directory (`~/.zshrc`, `~/.p10k.zsh`, etc.) will point to these files.

## Prerequisites

1. macOS or Linux (Lima)
2. Homebrew (Linuxbrew on Lima)
3. Zsh set as the default shell

## Setup Instructions

### 1. Clone the Repository

Clone into `~/workspace/dotfiles`:

cd ~/workspace
git clone https://github.com/your-username/dotfiles.git

### 2. Create Symlinks

All dotfiles exist in their non-dot form inside the repo (e.g., `zshrc` instead of `.zshrc`).  
The bootstrap script creates the expected home-directory dotfiles.

Run:

cd ~/workspace/dotfiles
./bootstrap-dotfiles.sh

The script will:

- Create symlinks in your home directory:
  - `~/.zshrc` → `~/workspace/dotfiles/zsh/zshrc`
  - `~/.p10k.zsh` → `~/workspace/dotfiles/zsh/p10k.zsh`
- Ensure Claude helpers and Zsh plugins are wired in

### 3. Verify Symlinks

ls -lash ~/.zshrc
ls -lash ~/.p10k.zsh

You should see symlinks pointing to the files inside the dotfiles repository.

Reload Zsh:

source ~/.zshrc

### 4. Install Dependencies (Optional)

#### macOS

brew install powerlevel10k
brew install zsh-autosuggestions
brew install zsh-syntax-highlighting

#### Lima (Linux)

if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew install powerlevel10k zsh-autosuggestions zsh-syntax-highlighting

### 5. Confirm Appearance

You should now have:

- Syntax highlighting
- Autosuggestions
- Powerlevel10k prompt

---

## Key Configuration Files

- **~/.zshrc** — Main Zsh config  
- **~/.p10k.zsh** — Powerlevel10k config  
- **Claude helpers** — Functions for controlling which Claude mode runs

---

## Using the Dotfiles

### Switching Claude Modes

Available functions:

- `claude-bedrock` — Uses AWS Bedrock  
- `claude-max` — Uses Anthropic Max  
- `claude-run MODE "prompt"` — Flexible entrypoint

Examples:

claude-run bedrock "explain this code"
claude-run max "optimize this function"

### Navigation Aliases

Included in `.zshrc`:

- `cws` → `~/workspace`
- `ccode` → `~/workspace/code`
- `cwhite` → `~/workspace/whitepapers`
- `cpat` → `~/workspace/patent-pool`

Modify in `zshrc` as needed.

---

## File Synchronization Notes

Because `~/workspace` is the shared mount between **macOS** and **Lima**, the dotfiles repo automatically stays synced:

- macOS writes to `~/workspace/dotfiles`
- Lima sees those same files immediately

This creates a unified environment across machines.

---

## Troubleshooting

### 1. Broken Symlinks

Recreate manually:

ln -sf ~/workspace/dotfiles/zsh/zshrc ~/.zshrc
ln -sf ~/workspace/dotfiles/zsh/p10k.zsh ~/.p10k.zsh

### 2. Missing Tools

Ensure you installed:

- brew  
- zsh  
- powerlevel10k  
- zsh-autosuggestions  
- zsh-syntax-highlighting  

### 3. Conflicts With Existing Config

If an old `.zshrc` or `.p10k.zsh` exists, back it up:

mv ~/.zshrc ~/.zshrc.backup
mv ~/.p10k.zsh ~/.p10k.zsh.backup

Then re-run the bootstrap script.

---

## License

This repository is licensed under the **MIT License**.

---

By following this guide, you'll have a **consistent, portable, and fully automated environment** across macOS and Lima.

