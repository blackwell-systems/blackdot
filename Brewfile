# ============================================================
# Brewfile - Full install (everything)
# ============================================================
# Use this for: Full-featured workstations, complete toolkit
# Install: brew bundle (uses this file by default)
#
# OTHER TIERS:
#   Brewfile.minimal  - Essentials only (~15 packages)
#   Brewfile.enhanced - Modern tools without containers (~40 packages)
#   Brewfile          - Everything including Docker/Node (~80 packages)
#
# Choose a tier:
#   brew bundle --file=Brewfile.minimal
#   brew bundle --file=Brewfile.enhanced
#   brew bundle  # Uses this file (full)
# ============================================================

# Core CLI tools
brew "git"
brew "zsh"
brew "gh"
brew "bat"
brew "tmux"
brew "tree"
brew "zellij"
brew "node"
brew "colordiff"

# Modern CLI enhancements
brew "fzf"       # Fuzzy finder (Ctrl+R, file search)
brew "eza"       # Modern ls replacement
brew "fd"        # Fast find alternative (pairs with fzf)
brew "ripgrep"   # Fast grep alternative (rg)
brew "zoxide"    # Smarter cd that learns your habits (z command)
brew "glow"      # Render markdown beautifully in terminal
brew "dust"      # Intuitive disk usage (du replacement)
brew "yazi"      # Blazing fast terminal file manager
brew "yq"        # jq for YAML files
brew "btop"      # Beautiful system monitor (htop replacement)

# Containers / dev
brew "docker"
brew "docker-completion"
brew "lima"

# Shell / prompt
brew "powerlevel10k"
brew "zsh-autosuggestions"
brew "zsh-syntax-highlighting"

# Plumbing / libs / utils you already have or will likely want
brew "gettext"
brew "openssl@3"
brew "readline"
brew "sqlite"
brew "simdjson"
brew "brotli"
brew "c-ares"
brew "ca-certificates"
brew "libevent"
brew "libnghttp2"
brew "libnghttp3"
brew "libngtcp2"
brew "libunistring"
brew "libuv"
brew "ncurses"
brew "pcre2"
brew "utf8proc"
brew "uvwasi"
brew "xz"
brew "zstd"
brew "lz4"

# Tools your vault / workflows depend on
brew "jq"
brew "awscli"
brew "bitwarden-cli"

# ============================================================
# macOS-only casks (GUI apps)
# Note: These will be skipped on Linux automatically
# ============================================================
if OS.mac?
  cask "ghostty"
  cask "claude-code"
  cask "font-meslo-for-powerlevel10k"
  cask "microsoft-edge"
  cask "mongodb-compass"
  cask "nosql-workbench"
  cask "rectangle"
  cask "vscodium"
end
