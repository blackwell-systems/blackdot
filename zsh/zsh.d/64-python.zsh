# =========================
# 64-python.zsh
# =========================
# Python/uv aliases and helpers for Python development workflows
# Provides shortcuts for uv package manager, pytest, and auto-venv activation
#
# uv is the preferred Python toolchain - it handles:
# - Package management (replacing pip, pip-tools)
# - Virtual environments (replacing venv)
# - Python version management (replacing pyenv)

# Feature guard: skip if python_tools is disabled
if type feature_enabled &>/dev/null && ! feature_enabled "python_tools" 2>/dev/null; then
    return 0
fi

# =========================
# uv Aliases
# =========================

# Core uv commands
alias uvs='uv sync'                    # Sync dependencies from pyproject.toml/uv.lock
alias uvr='uv run'                     # Run command in project environment
alias uva='uv add'                     # Add dependency
alias uvad='uv add --dev'              # Add dev dependency
alias uvrm='uv remove'                 # Remove dependency
alias uvl='uv lock'                    # Update lock file
alias uvu='uv lock --upgrade'          # Upgrade all dependencies
alias uvp='uv pip'                     # uv pip subcommand
alias uvx='uvx'                        # Run tools (like npx for Python)
alias uvi='uv init'                    # Initialize new project
alias uvt='uv tree'                    # Show dependency tree
alias uvv='uv venv'                    # Create virtual environment
alias uvpy='uv python'                 # Python version management

# Python version management
alias uvpyl='uv python list'           # List available Python versions
alias uvpyi='uv python install'        # Install Python version
alias uvpyp='uv python pin'            # Pin Python version for project

# pip compatibility (via uv)
alias uvpi='uv pip install'            # Install package
alias uvpie='uv pip install -e .'      # Install current package in editable mode
alias uvpir='uv pip install -r'        # Install from requirements file
alias uvpu='uv pip uninstall'          # Uninstall package
alias uvpl='uv pip list'               # List installed packages
alias uvpf='uv pip freeze'             # Freeze dependencies
alias uvpc='uv pip compile'            # Compile requirements

# =========================
# Python Aliases
# =========================

alias py='python3'
alias py3='python3'
alias py2='python2'
alias ipy='ipython'

# =========================
# Pytest Aliases
# =========================

alias pt='pytest'
alias ptv='pytest -v'
alias ptvv='pytest -vv'
alias ptx='pytest -x'                  # Stop on first failure
alias ptxv='pytest -xvs'               # Stop on first, verbose, show output
alias ptc='pytest --cov'               # Coverage
alias ptcr='pytest --cov --cov-report=html'  # Coverage with HTML report
alias ptw='pytest-watch'               # Watch mode (requires pytest-watch)
alias ptf='pytest --failed-first'      # Run failed tests first
alias ptl='pytest --last-failed'       # Only run last failed tests
alias pts='pytest -s'                  # Show print statements (no capture)
alias ptk='pytest -k'                  # Run tests matching expression

# =========================
# Auto-venv Activation
# =========================
# Automatically activates virtual environments when entering directories

# Configuration:
# PYTHON_AUTO_VENV="notify"  - Ask before activating (default)
# PYTHON_AUTO_VENV="auto"    - Activate automatically
# PYTHON_AUTO_VENV="off"     - Disable auto-venv

: ${PYTHON_AUTO_VENV:="notify"}

# Track current venv to avoid re-prompting
typeset -g _PYTHON_CURRENT_VENV=""

_python_auto_venv() {
    local mode="${PYTHON_AUTO_VENV:-notify}"
    [[ "$mode" == "off" ]] && return

    # Find venv in current directory (check common locations)
    local venv_path=""
    local venv_names=(".venv" "venv" ".virtualenv" "virtualenv")

    for vname in "${venv_names[@]}"; do
        if [[ -f "${PWD}/${vname}/bin/activate" ]]; then
            venv_path="${PWD}/${vname}"
            break
        fi
    done

    # If we found a venv
    if [[ -n "$venv_path" ]]; then
        # Already in this venv?
        if [[ "$VIRTUAL_ENV" == "$venv_path" ]]; then
            return
        fi

        # Already prompted for this directory?
        if [[ "$_PYTHON_CURRENT_VENV" == "$venv_path" ]]; then
            return
        fi

        if [[ "$mode" == "auto" ]]; then
            # Auto-activate
            source "${venv_path}/bin/activate"
            echo "Activated: $(basename "$venv_path")"
            _PYTHON_CURRENT_VENV="$venv_path"
        else
            # Notify mode - ask user
            local venv_name=$(basename "$venv_path")
            echo ""
            echo -e "\033[0;33m󰌠 Virtual environment detected:\033[0m $venv_name"
            echo -n "Activate? [Y/n] "
            read -r response

            if [[ -z "$response" || "$response" =~ ^[Yy]$ ]]; then
                source "${venv_path}/bin/activate"
                echo "Activated: $venv_name"
            fi
            _PYTHON_CURRENT_VENV="$venv_path"
        fi
    elif [[ -n "$VIRTUAL_ENV" ]]; then
        # We're in a venv but left the project directory
        # Check if we're still under the venv's parent
        local venv_parent=$(dirname "$VIRTUAL_ENV")
        if [[ ! "$PWD" == "$venv_parent"* ]]; then
            # Left the project, optionally deactivate
            if [[ "$mode" == "auto" ]]; then
                deactivate 2>/dev/null
                echo "Deactivated: $(basename "$VIRTUAL_ENV")"
                _PYTHON_CURRENT_VENV=""
            fi
        fi
    fi
}

# Register with chpwd hook
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _python_auto_venv

# =========================
# uv Helper Functions
# =========================

# Create new Python project with uv
uv-new() {
    local name="${1:-}"
    local template="${2:-app}"

    if [[ -z "$name" ]]; then
        echo "Usage: uv-new <project-name> [app|lib|script]"
        echo ""
        echo "Templates:"
        echo "  app     Application with pyproject.toml (default)"
        echo "  lib     Library package structure"
        echo "  script  Single script with inline dependencies"
        return 1
    fi

    case "$template" in
        lib)
            uv init --lib "$name"
            ;;
        script)
            # Create a script with inline dependencies
            mkdir -p "$name"
            cat > "$name/main.py" << 'EOF'
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
Run with: uv run main.py
Add dependencies to the list above.
"""

def main():
    print("Hello from uv script!")

if __name__ == "__main__":
    main()
EOF
            echo "Created script project: $name"
            echo "Run with: cd $name && uv run main.py"
            return
            ;;
        *)
            uv init "$name"
            ;;
    esac

    cd "$name"
    echo ""
    echo "Created $template project: $name"
    echo "Run: uv sync && uv run python -c 'print(\"Hello!\")'"
}

# Clean Python artifacts
uv-clean() {
    echo "Cleaning Python artifacts..."

    # Enable null_glob so unmatched patterns expand to nothing
    setopt localoptions null_glob

    # Compiled files
    find . -type f -name "*.pyc" -delete 2>/dev/null
    find . -type f -name "*.pyo" -delete 2>/dev/null
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null

    # Build artifacts
    rm -rf build/ dist/ *.egg-info/ .eggs/ 2>/dev/null

    # Test/coverage artifacts
    rm -rf .pytest_cache/ .coverage htmlcov/ .tox/ 2>/dev/null

    # Type checker caches
    rm -rf .mypy_cache/ .pytype/ 2>/dev/null

    echo "Done"
}

# Show Python/uv info
uv-info() {
    echo "Python Environment Info"
    echo "───────────────────────"

    if command -v uv &>/dev/null; then
        echo "uv:        $(uv --version)"
    else
        echo "uv:        not installed"
    fi

    if command -v python3 &>/dev/null; then
        echo "Python:    $(python3 --version 2>&1 | cut -d' ' -f2)"
        echo "Location:  $(which python3)"
    fi

    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "Venv:      $VIRTUAL_ENV"
    else
        echo "Venv:      none active"
    fi

    if [[ -f "pyproject.toml" ]]; then
        echo "Project:   pyproject.toml found"
        local project_name
        project_name=$(grep -m1 '^name' pyproject.toml 2>/dev/null | cut -d'"' -f2)
        if [[ -n "$project_name" ]]; then
            echo "Name:      $project_name"
        fi
    fi
}

# Run pytest with common options
pt-watch() {
    if ! command -v pytest-watch &>/dev/null; then
        echo "Installing pytest-watch..."
        uv add --dev pytest-watch
    fi
    pytest-watch "$@"
}

# Coverage report with browser
pt-cov() {
    local pkg="${1:-.}"

    pytest --cov="$pkg" --cov-report=html --cov-report=term

    echo ""
    read -q "REPLY?Open coverage in browser? [y/N] "
    echo ""

    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        if command -v open &>/dev/null; then
            open htmlcov/index.html
        elif command -v xdg-open &>/dev/null; then
            xdg-open htmlcov/index.html
        fi
    fi
}

# Install Python version with uv and set as default
uv-python-setup() {
    local version="${1:-3.12}"

    echo "Installing Python $version..."
    uv python install "$version"

    if [[ -f "pyproject.toml" ]]; then
        echo ""
        echo "Pinning Python $version for this project..."
        uv python pin "$version"
    fi

    echo ""
    echo "Python $version is ready. Use 'uv run python' in projects."
}

# =========================
# Python Tools Help
# =========================

pythontools() {
    # Colors
    local yellow='\033[0;33m'
    local blue='\033[0;34m'
    local cyan='\033[0;36m'
    local red='\033[0;31m'
    local green='\033[0;32m'
    local bold='\033[1m'
    local dim='\033[2m'
    local nc='\033[0m'

    # Check if uv and Python are installed
    local logo_color has_uv has_python in_project in_venv
    has_uv=false
    has_python=false
    in_project=false
    in_venv=false

    command -v uv &>/dev/null && has_uv=true
    command -v python3 &>/dev/null && has_python=true
    [[ -f "pyproject.toml" ]] && in_project=true
    [[ -n "$VIRTUAL_ENV" ]] && in_venv=true

    if [[ "$has_uv" == "true" && "$in_project" == "true" ]]; then
        logo_color="$yellow"
    elif [[ "$has_uv" == "true" ]]; then
        logo_color="$blue"
    else
        logo_color="$red"
    fi

    echo ""
    echo -e "${logo_color}  ██████╗ ██╗   ██╗████████╗██╗  ██╗ ██████╗ ███╗   ██╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗${nc}"
    echo -e "${logo_color}  ██╔══██╗╚██╗ ██╔╝╚══██╔══╝██║  ██║██╔═══██╗████╗  ██║    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝${nc}"
    echo -e "${logo_color}  ██████╔╝ ╚████╔╝    ██║   ███████║██║   ██║██╔██╗ ██║       ██║   ██║   ██║██║   ██║██║     ███████╗${nc}"
    echo -e "${logo_color}  ██╔═══╝   ╚██╔╝     ██║   ██╔══██║██║   ██║██║╚██╗██║       ██║   ██║   ██║██║   ██║██║     ╚════██║${nc}"
    echo -e "${logo_color}  ██║        ██║      ██║   ██║  ██║╚██████╔╝██║ ╚████║       ██║   ╚██████╔╝╚██████╔╝███████╗███████║${nc}"
    echo -e "${logo_color}  ╚═╝        ╚═╝      ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝${nc}"
    echo -e "  ${dim}Powered by${nc} ${cyan}uv${nc}"
    echo ""

    # Aliases section
    echo -e "  ${dim}╭─────────────────────────────────────────────────────────────────╮${nc}"
    echo -e "  ${dim}│${nc}  ${bold}${yellow}UV ALIASES${nc}                                                   ${dim}│${nc}"
    echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}uvs${nc}                ${dim}uv sync (sync from lock file)${nc}              ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}uvr${nc}                ${dim}uv run (run in project env)${nc}               ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}uva${nc}                ${dim}uv add (add dependency)${nc}                   ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}uvad${nc}               ${dim}uv add --dev${nc}                              ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}uvrm${nc}               ${dim}uv remove${nc}                                 ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}uvl${nc}                ${dim}uv lock${nc}                                   ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}uvu${nc}                ${dim}uv lock --upgrade${nc}                         ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}uvt${nc}                ${dim}uv tree (dependency tree)${nc}                 ${dim}│${nc}"
    echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
    echo -e "  ${dim}│${nc}  ${bold}${yellow}PYTEST ALIASES${nc}                                               ${dim}│${nc}"
    echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}pt${nc}                 ${dim}pytest${nc}                                    ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}ptv${nc}                ${dim}pytest -v${nc}                                 ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}ptx${nc}                ${dim}pytest -x (stop on first fail)${nc}            ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}ptxv${nc}               ${dim}pytest -xvs (verbose, stop, output)${nc}       ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}ptc${nc}                ${dim}pytest --cov${nc}                              ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}ptl${nc}                ${dim}pytest --last-failed${nc}                      ${dim}│${nc}"
    echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
    echo -e "  ${dim}│${nc}  ${bold}${yellow}HELPER FUNCTIONS${nc}                                            ${dim}│${nc}"
    echo -e "  ${dim}├─────────────────────────────────────────────────────────────────┤${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}uv-new${nc} <name>      ${dim}Create new Python project${nc}                 ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}uv-clean${nc}           ${dim}Clean Python artifacts${nc}                    ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}uv-info${nc}            ${dim}Show Python/uv info${nc}                       ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}uv-python-setup${nc}    ${dim}Install and pin Python version${nc}            ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}pt-watch${nc}           ${dim}Run pytest in watch mode${nc}                  ${dim}│${nc}"
    echo -e "  ${dim}│${nc}  ${yellow}pt-cov${nc}             ${dim}Coverage with HTML report${nc}                 ${dim}│${nc}"
    echo -e "  ${dim}╰─────────────────────────────────────────────────────────────────╯${nc}"
    echo ""

    # Auto-venv setting
    echo -e "  ${bold}Auto-venv Mode${nc}"
    echo -e "  ${dim}───────────────────────────────────────${nc}"
    case "${PYTHON_AUTO_VENV:-notify}" in
        auto)   echo -e "    ${dim}Mode${nc}      ${green}auto${nc} ${dim}(activates on cd)${nc}" ;;
        off)    echo -e "    ${dim}Mode${nc}      ${red}off${nc} ${dim}(disabled)${nc}" ;;
        *)      echo -e "    ${dim}Mode${nc}      ${yellow}notify${nc} ${dim}(prompts on cd)${nc}" ;;
    esac
    echo -e "    ${dim}Set with:${nc} export PYTHON_AUTO_VENV=auto|notify|off"
    echo ""

    # Current Status
    echo -e "  ${bold}Current Status${nc}"
    echo -e "  ${dim}───────────────────────────────────────${nc}"

    if [[ "$has_uv" == "true" ]]; then
        local uv_version
        uv_version=$(uv --version 2>/dev/null | cut -d' ' -f2)
        echo -e "    ${dim}uv${nc}        ${green}✓ installed${nc} ${dim}($uv_version)${nc}"
    else
        echo -e "    ${dim}uv${nc}        ${red}✗ not installed${nc} ${dim}(curl -LsSf https://astral.sh/uv/install.sh | sh)${nc}"
    fi

    if [[ "$has_python" == "true" ]]; then
        local py_version
        py_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        echo -e "    ${dim}Python${nc}    ${green}✓ installed${nc} ${dim}($py_version)${nc}"
    else
        echo -e "    ${dim}Python${nc}    ${red}✗ not installed${nc}"
    fi

    if [[ "$in_venv" == "true" ]]; then
        echo -e "    ${dim}Venv${nc}      ${green}✓ active${nc} ${dim}($(basename "$VIRTUAL_ENV"))${nc}"
    else
        echo -e "    ${dim}Venv${nc}      ${dim}none active${nc}"
    fi

    if [[ "$in_project" == "true" ]]; then
        echo -e "    ${dim}Project${nc}   ${green}✓ pyproject.toml found${nc}"
        local pkg_name
        pkg_name=$(grep -m1 '^name' pyproject.toml 2>/dev/null | cut -d'"' -f2)
        if [[ -n "$pkg_name" ]]; then
            echo -e "    ${dim}Package${nc}   ${cyan}$pkg_name${nc}"
        fi
    else
        echo -e "    ${dim}Project${nc}   ${dim}not in Python project${nc}"
    fi

    echo ""
}

# =========================
# Zsh Completions
# =========================

# Completion for uv-new
_uv_new() {
    _arguments \
        '1:name:' \
        '2:template:(app lib script)'
}
compdef _uv_new uv-new

# Completion for uv-python-setup
_uv_python_setup() {
    local versions
    versions=(3.8 3.9 3.10 3.11 3.12 3.13)
    _describe 'Python versions' versions
}
compdef _uv_python_setup uv-python-setup
