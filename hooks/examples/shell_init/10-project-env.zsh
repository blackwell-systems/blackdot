#!/usr/bin/env zsh
# ============================================================
# Example Hook: shell_init/10-project-env.zsh
# Load project-specific environment at shell startup
#
# Installation:
#   mkdir -p ~/.config/dotfiles/hooks/shell_init
#   cp this_file ~/.config/dotfiles/hooks/shell_init/
#   chmod +x ~/.config/dotfiles/hooks/shell_init/10-project-env.zsh
# ============================================================

# Load work environment if present
if [[ -f "$HOME/.work-env" ]]; then
    source "$HOME/.work-env"
fi

# Auto-activate direnv if installed
if (( $+commands[direnv] )); then
    eval "$(direnv hook zsh)" 2>/dev/null
fi

# Set default AWS profile based on machine
case "$(hostname)" in
    *work*|*corp*)
        export AWS_PROFILE="${AWS_PROFILE:-work}"
        ;;
    *personal*|*home*)
        export AWS_PROFILE="${AWS_PROFILE:-personal}"
        ;;
esac

return 0
