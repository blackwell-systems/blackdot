# =========================
# 80-git.zsh
# =========================
# Git shortcuts and cross-platform clipboard utilities
# Provides convenient git aliases and universal copy/paste functions

# =========================
# Git shortcuts (cross-platform)
# =========================
alias gst='git status'
alias gss='git status -sb'

alias ga='git add'
alias gaa='git add --all'

alias gb='git branch'
alias gba='git branch -a'

alias gco='git checkout'
alias gcb='git checkout -b'

alias gd='git diff'
alias gds='git diff --staged'

alias gpl='git pull'
alias gp='git push'
alias gpf='git push --force-with-lease'

alias gcm='git commit -m'
alias gca='git commit --amend'
alias gcl='git clone'

# Quick log views
alias gl1='git log --oneline --decorate --graph -n 15'
alias glg='git log --oneline --decorate --graph --all'

# =========================
# Cross-platform clipboard (copy/paste)
# =========================
# Works on: macOS, Linux (X11/Wayland), WSL

copy() {
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy
  elif command -v wl-copy >/dev/null 2>&1; then
    wl-copy
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --input
  elif command -v clip.exe >/dev/null 2>&1; then
    clip.exe
  else
    echo "No clipboard utility found (pbcopy/wl-copy/xclip/xsel/clip.exe)" >&2
    return 1
  fi
}

paste() {
  if command -v pbpaste >/dev/null 2>&1; then
    pbpaste
  elif command -v wl-paste >/dev/null 2>&1; then
    wl-paste
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -o
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --output
  elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -command "Get-Clipboard" | tr -d '\r'
  else
    echo "No clipboard utility found (pbpaste/wl-paste/xclip/xsel/powershell.exe)" >&2
    return 1
  fi
}

# Aliases for muscle memory
alias cb='copy'
alias cbp='paste'
