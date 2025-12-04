# =========================
# 20-env.zsh
# =========================
# Environment variables, workspace paths, and history configuration
# Sets up shared environment for cross-platform development

# =========================
# SHARED ENV / TOOLING
# =========================

# Dotfiles directory (derive from this file's location)
# ${(%):-%x} gives the path to the current file being sourced
export DOTFILES_DIR="${${(%):-%x}:A:h:h}"

# Shared workspace (macOS + Lima both use ~/workspace now)
export WORKSPACE="$HOME/workspace"

# =========================
# SHARED HISTORY (cross-platform)
# =========================
# Store history in workspace so it syncs across macOS and Lima
HISTFILE="$HOME/workspace/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY          # Share history between sessions
setopt HIST_IGNORE_DUPS       # Don't record duplicates
setopt HIST_IGNORE_SPACE      # Don't record commands starting with space
setopt HIST_REDUCE_BLANKS     # Remove extra blanks
setopt INC_APPEND_HISTORY     # Add commands immediately (not at shell exit)
