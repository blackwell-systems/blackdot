#!/usr/bin/env zsh
# ============================================================
# Example Hook: directory_change/10-auto-env.zsh
# Auto-activate environments when entering directories
#
# Installation:
#   mkdir -p ~/.config/dotfiles/hooks/directory_change
#   cp this_file ~/.config/dotfiles/hooks/directory_change/
#   chmod +x ~/.config/dotfiles/hooks/directory_change/10-auto-env.zsh
#
# Receives: $1 = new directory path (PWD)
# ============================================================

local new_dir="${1:-$PWD}"

# Auto-activate Python virtual environment
if [[ -d "$new_dir/.venv" && -f "$new_dir/.venv/bin/activate" ]]; then
    # Only activate if not already in this venv
    if [[ "${VIRTUAL_ENV:-}" != "$new_dir/.venv" ]]; then
        source "$new_dir/.venv/bin/activate"
    fi
elif [[ -d "$new_dir/venv" && -f "$new_dir/venv/bin/activate" ]]; then
    if [[ "${VIRTUAL_ENV:-}" != "$new_dir/venv" ]]; then
        source "$new_dir/venv/bin/activate"
    fi
fi

# Auto-use .nvmrc if present
if [[ -f "$new_dir/.nvmrc" ]]; then
    # Only if nvm is loaded
    if (( $+functions[nvm] )); then
        nvm use 2>/dev/null
    fi
fi

# Load .env file if present (be careful with this!)
# Uncomment if you want auto-loading of .env files
# if [[ -f "$new_dir/.env" ]]; then
#     set -a
#     source "$new_dir/.env"
#     set +a
# fi

return 0
