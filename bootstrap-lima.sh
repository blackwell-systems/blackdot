#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Lima (dev-ubuntu) bootstrap starting ==="

# Basic packages
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential curl file git zsh

# Linuxbrew install (if not present)
if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Linuxbrew..."
  /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
else
  echo "Linuxbrew already installed."
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" || true
fi

# Shell-related brew packages
brew install powerlevel10k zsh-autosuggestions zsh-syntax-highlighting

# Dotfiles symlinks (shared with macOS)
"$DOTFILES_DIR/bootstrap-dotfiles.sh"

# Set default shell to zsh
if [ "$SHELL" != "$(command -v zsh)" ]; then
  chsh -s "$(command -v zsh)"
fi

echo "=== Lima bootstrap complete ==="
echo "Open a new Lima shell to use zsh + Powerlevel10k."
