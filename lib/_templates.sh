#!/usr/bin/env zsh
# ============================================================
# FILE: lib/_templates.sh
# Template engine for machine-specific configuration files
#
# Usage:
#   source "$(dirname "$0")/../lib/_templates.sh"
#
# Functions provided:
#   build_template_vars()      - Build variable map with precedence
#   render_template()          - Render a single template file
#   render_all_templates()     - Render all templates in configs/
#   get_template_var()         - Get a specific variable value
#   list_template_vars()       - List all variables and values
#   validate_template()        - Check template syntax
#
# Template Syntax:
#   {{ variable }}             - Variable substitution
#   {{#if variable }}...{{/if}} - Conditional block (truthy check)
#   {{#if var == "value" }}    - Conditional with comparison
#   {{#unless variable }}      - Negative conditional
#   {{#each array }}...{{/each}} - Array iteration with named fields
#
# Variable Precedence (highest to lowest):
#   1. Environment variables (DOTFILES_TMPL_*)
#   2. Local overrides (_variables.local.sh)
#   3. Machine-type defaults (work/personal)
#   4. Default values (_variables.sh)
#   5. Auto-detected values (hostname, os, etc.)
# ============================================================

# Prevent multiple sourcing
[[ -n "${_TEMPLATES_SOURCED:-}" ]] && return 0
_TEMPLATES_SOURCED=1

# ============================================================
# Directory Setup
# ============================================================
# Determine paths - works whether script is sourced or run directly
if [[ -n "${0:A:h}" ]]; then
    _TEMPLATES_LIB_DIR="${0:A:h}"
else
    _TEMPLATES_LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# Find dotfiles root (lib is one level down)
DOTFILES_DIR="${DOTFILES_DIR:-${_TEMPLATES_LIB_DIR:h}}"
TEMPLATES_DIR="${DOTFILES_DIR}/templates"
TEMPLATES_CONFIG_DIR="${TEMPLATES_DIR}/configs"
GENERATED_DIR="${DOTFILES_DIR}/generated"

# ============================================================
# Color definitions (if not already defined)
# ============================================================
if [[ -z "${RED:-}" ]]; then
    if [[ -t 1 ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        DIM='\033[2m'
        BOLD='\033[1m'
        NC='\033[0m'
    else
        RED='' GREEN='' YELLOW='' BLUE='' CYAN='' DIM='' BOLD='' NC=''
    fi
fi

# ============================================================
# Logging functions (if not already defined)
# ============================================================
if ! command -v info >/dev/null 2>&1; then
    info()  { print "${BLUE}[INFO]${NC} $1"; }
    pass()  { print "${GREEN}[OK]${NC} $1"; }
    warn()  { print "${YELLOW}[WARN]${NC} $1"; }
    fail()  { print "${RED}[FAIL]${NC} $1"; }
    dry()   { print "${CYAN}[DRY-RUN]${NC} $1"; }
    debug() { [[ "${DEBUG:-}" == "1" ]] && print "${DIM}[DEBUG] $1${NC}"; }
fi

# ============================================================
# Variable Storage
# ============================================================
# These are populated by build_template_vars()
typeset -gA TMPL_VARS=()       # Final merged variables
typeset -gA TMPL_AUTO=()       # Auto-detected values
typeset -gA TMPL_DEFAULTS=()   # User defaults
typeset -gA TMPL_WORK=()       # Work machine overrides
typeset -gA TMPL_PERSONAL=()   # Personal machine overrides

# ============================================================
# Array Storage for {{#each}} loops
# ============================================================
# Arrays are stored as pipe-delimited strings with named fields
# Format: "field1|field2|field3|..."
# Schema defines field names for each array type
typeset -gA TMPL_ARRAY_SCHEMAS=(
    # SSH_HOSTS: name|hostname|user|identity|extra
    [ssh_hosts]="name|hostname|user|identity|extra"
    # Generic arrays use "item" as the field name
    [_default]="item"
)

# Global array storage - populated from SSH_HOSTS, etc.
typeset -ga TMPL_ARRAYS_ssh_hosts=()
typeset -ga TMPL_ARRAYS_generic=()

# ============================================================
# Auto-Detection Functions
# ============================================================

# Detect the machine type based on hostname and environment
detect_machine_type() {
    local hostname="${1:-$(hostname -s 2>/dev/null || echo "unknown")}"

    # Check environment variable override first
    if [[ -n "${DOTFILES_MACHINE_TYPE:-}" ]]; then
        echo "${DOTFILES_MACHINE_TYPE}"
        return
    fi

    # Check hostname patterns
    case "$hostname" in
        *-work*|*-corp*|*-office*|*work*|*corp*)
            echo "work"
            ;;
        *-personal*|*-home*|*macbook*|*imac*)
            echo "personal"
            ;;
        *)
            # Check for work indicators
            if [[ -d "$HOME/work" ]] || [[ -d "$HOME/corp" ]]; then
                echo "work"
            elif [[ -d "$HOME/personal" ]] || [[ -f "$HOME/.personal-machine" ]]; then
                echo "personal"
            else
                echo "unknown"
            fi
            ;;
    esac
}

# Detect OS type
detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            elif [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
                echo "docker"
            elif [[ "$(hostname)" == lima-* ]] || [[ -n "${LIMA_INSTANCE:-}" ]]; then
                echo "lima"
            else
                echo "linux"
            fi
            ;;
        *) echo "unknown" ;;
    esac
}

# Detect architecture
detect_arch() {
    local arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64) echo "amd64" ;;
        arm64|aarch64) echo "arm64" ;;
        *) echo "$arch" ;;
    esac
}

# Build auto-detected variables
build_auto_vars() {
    local hostname_short="${$(hostname -s 2>/dev/null):-unknown}"
    local hostname_full="${$(hostname -f 2>/dev/null):-$hostname_short}"

    TMPL_AUTO=(
        # System info
        [hostname]="$hostname_short"
        [hostname_full]="$hostname_full"
        [os]="$(detect_os)"
        [os_family]="$(uname -s)"
        [arch]="$(detect_arch)"
        [user]="${USER:-$(whoami)}"
        [uid]="${UID:-$(id -u)}"

        # Paths
        [home]="$HOME"
        [workspace]="${WORKSPACE:-$HOME/workspace}"
        [dotfiles_dir]="${DOTFILES_DIR}"

        # Machine type
        [machine_type]="$(detect_machine_type "$hostname_short")"

        # Timestamps
        [date]="$(date +%Y-%m-%d)"
        [datetime]="$(date '+%Y-%m-%d %H:%M:%S')"
        [year]="$(date +%Y)"
    )
}

# ============================================================
# Variable Loading
# ============================================================

# Load variables from files
load_variable_files() {
    # Load defaults
    if [[ -f "${TEMPLATES_DIR}/_variables.sh" ]]; then
        source "${TEMPLATES_DIR}/_variables.sh"
        debug "Loaded: ${TEMPLATES_DIR}/_variables.sh"
    else
        warn "Variables file not found: ${TEMPLATES_DIR}/_variables.sh"
    fi

    # Load local overrides (machine-specific)
    if [[ -f "${TEMPLATES_DIR}/_variables.local.sh" ]]; then
        source "${TEMPLATES_DIR}/_variables.local.sh"
        debug "Loaded: ${TEMPLATES_DIR}/_variables.local.sh"
    fi
}

# Load arrays for {{#each}} loops
load_template_arrays() {
    # SSH_HOSTS array (defined in _variables.sh or _variables.local.sh)
    if (( ${#SSH_HOSTS[@]} > 0 )); then
        TMPL_ARRAYS_ssh_hosts=("${SSH_HOSTS[@]}")
        debug "Loaded SSH_HOSTS array: ${#TMPL_ARRAYS_ssh_hosts[@]} items"
    fi
}

# Build the final variable map with proper precedence
build_template_vars() {
    # Reset
    TMPL_VARS=()

    # Layer 1: Auto-detected values (lowest priority)
    build_auto_vars
    for key in "${(@k)TMPL_AUTO}"; do
        TMPL_VARS[$key]="${TMPL_AUTO[$key]}"
    done

    # Layer 2: Load variable files (sets TMPL_DEFAULTS, TMPL_WORK, TMPL_PERSONAL)
    load_variable_files

    # Layer 3: Apply default values
    for key in "${(@k)TMPL_DEFAULTS}"; do
        TMPL_VARS[$key]="${TMPL_DEFAULTS[$key]}"
    done

    # Layer 4: Apply machine-type specific values
    local machine_type="${TMPL_VARS[machine_type]}"
    case "$machine_type" in
        work)
            for key in "${(@k)TMPL_WORK}"; do
                TMPL_VARS[$key]="${TMPL_WORK[$key]}"
            done
            ;;
        personal)
            for key in "${(@k)TMPL_PERSONAL}"; do
                TMPL_VARS[$key]="${TMPL_PERSONAL[$key]}"
            done
            ;;
    esac

    # Layer 5: Environment variable overrides (highest priority)
    # Format: DOTFILES_TMPL_GIT_NAME -> git_name
    local env_var
    for env_var in ${(k)parameters[(I)DOTFILES_TMPL_*]}; do
        local key="${env_var#DOTFILES_TMPL_}"
        key="${key:l}"  # lowercase
        key="${key//_/-}"  # underscores to hyphens... actually keep underscores
        key="${key//-/_}"  # keep underscores
        TMPL_VARS[$key]="${(P)env_var}"
        debug "Env override: $key = ${(P)env_var}"
    done

    # Load arrays for {{#each}} loops
    load_template_arrays

    debug "Built ${#TMPL_VARS[@]} template variables"
}

# Get a specific variable value
get_template_var() {
    local key="$1"
    local default="${2:-}"

    if [[ -z "${TMPL_VARS[$key]:-}" ]]; then
        build_template_vars
    fi

    echo "${TMPL_VARS[$key]:-$default}"
}

# List all variables and their values
list_template_vars() {
    local show_values="${1:-true}"

    build_template_vars

    print "${BOLD}Template Variables${NC}"
    print "──────────────────────────────────────"

    # Group by category
    print "\n${CYAN}Auto-detected:${NC}"
    for key in hostname hostname_full os os_family arch user home workspace machine_type date; do
        if [[ -n "${TMPL_VARS[$key]:-}" ]]; then
            if [[ "$show_values" == "true" ]]; then
                printf "  %-20s = %s\n" "$key" "${TMPL_VARS[$key]}"
            else
                printf "  %s\n" "$key"
            fi
        fi
    done

    print "\n${CYAN}User-configured:${NC}"
    for key in "${(@k)TMPL_VARS}"; do
        # Skip auto-detected keys
        case "$key" in
            hostname|hostname_full|os|os_family|arch|user|uid|home|workspace|dotfiles_dir|machine_type|date|datetime|year)
                continue
                ;;
        esac
        if [[ "$show_values" == "true" ]]; then
            printf "  %-20s = %s\n" "$key" "${TMPL_VARS[$key]}"
        else
            printf "  %s\n" "$key"
        fi
    done | sort

    print "\n${DIM}Total: ${#TMPL_VARS[@]} variables${NC}"
}

# ============================================================
# Template Rendering
# ============================================================

# Escape special characters for sed replacement
escape_for_sed() {
    local str="$1"
    # Escape backslashes, forward slashes, and ampersands
    str="${str//\\/\\\\}"
    str="${str//\//\\/}"
    str="${str//&/\\&}"
    echo "$str"
}

# Evaluate a condition expression
evaluate_condition() {
    local condition="$1"

    # Trim whitespace
    condition="${condition## }"
    condition="${condition%% }"

    # Handle: var == "value" or var == 'value'
    if [[ "$condition" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*==[[:space:]]*[\"\']([^\"\']*)[\"\']$ ]]; then
        local var="${match[1]}"
        local expected="${match[2]}"
        local actual="${TMPL_VARS[$var]:-}"
        debug "Condition: $var == '$expected' (actual: '$actual')"
        [[ "$actual" == "$expected" ]]
        return $?
    fi

    # Handle: var != "value"
    if [[ "$condition" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*!=[[:space:]]*[\"\']([^\"\']*)[\"\']$ ]]; then
        local var="${match[1]}"
        local expected="${match[2]}"
        local actual="${TMPL_VARS[$var]:-}"
        debug "Condition: $var != '$expected' (actual: '$actual')"
        [[ "$actual" != "$expected" ]]
        return $?
    fi

    # Handle: simple variable (truthy check)
    local var="${condition//[^a-zA-Z0-9_]/}"
    local value="${TMPL_VARS[$var]:-}"
    debug "Truthy check: $var = '$value'"
    [[ -n "$value" && "$value" != "false" && "$value" != "0" ]]
}

# ============================================================
# {{#each}} Loop Processing
# ============================================================

# Parse a pipe-delimited array item into field variables
# Usage: parse_array_item "value1|value2|value3" "field1|field2|field3"
# Sets: EACH_field1="value1", EACH_field2="value2", etc.
parse_array_item() {
    local item="$1"
    local schema="$2"

    # Split schema into field names
    local -a fields
    fields=("${(@s:|:)schema}")

    # Split item into values
    local -a values
    values=("${(@s:|:)item}")

    # Set EACH_* variables for each field
    local i
    for (( i = 1; i <= ${#fields[@]}; i++ )); do
        local field="${fields[$i]}"
        local value="${values[$i]:-}"
        # Export to associative array for substitution
        TMPL_EACH_VARS[$field]="$value"
        debug "  EACH.$field = '$value'"
    done
}

# Substitute {{#each}} item variables in a block
# Replaces {{ fieldname }} with the current item's field value
substitute_each_vars() {
    local block="$1"

    for field in "${(@k)TMPL_EACH_VARS}"; do
        local value="${TMPL_EACH_VARS[$field]}"
        # Replace {{ field }} and {{field}}
        block="${block//\{\{ $field \}\}/$value}"
        block="${block//\{\{$field\}\}/$value}"
    done

    echo "$block"
}

# Process {{#each array}}...{{/each}} blocks
# Expands loops by iterating over array items
process_each_loops() {
    local content="$1"
    local max_iterations=50
    local iteration=0

    # Process {{#each ...}}...{{/each}} blocks
    while [[ "$content" == *'{{#each '* ]] && (( iteration++ < max_iterations )); do
        # Find the first {{#each block
        local before="${content%%\{\{#each *}"
        local rest="${content#*\{\{#each }"

        # Extract array name (everything until }})
        local array_name="${rest%%\}\}*}"
        array_name="${array_name## }"  # trim leading space
        array_name="${array_name%% }"  # trim trailing space
        rest="${rest#*\}\}}"

        # Find matching {{/each}} (simple - no nesting support for now)
        local block="${rest%%\{\{/each\}\}*}"
        local after="${rest#*\{\{/each\}\}}"

        debug "Processing {{#each $array_name}}"

        # Get the array and schema
        local -a items
        local schema="${TMPL_ARRAY_SCHEMAS[$array_name]:-${TMPL_ARRAY_SCHEMAS[_default]}}"

        # Load array based on name
        case "$array_name" in
            ssh_hosts)
                items=("${TMPL_ARRAYS_ssh_hosts[@]}")
                ;;
            *)
                # Try to find a matching array variable
                local array_var="TMPL_ARRAYS_${array_name}"
                if (( ${(P)#array_var} > 0 )); then
                    items=("${(P@)array_var}")
                else
                    debug "Array not found: $array_name"
                    items=()
                fi
                ;;
        esac

        # Build expanded content
        local expanded=""
        typeset -gA TMPL_EACH_VARS=()

        if (( ${#items[@]} == 0 )); then
            debug "  Array is empty, skipping block"
        else
            local item
            for item in "${items[@]}"; do
                debug "  Processing item: $item"

                # Parse item into field variables
                TMPL_EACH_VARS=()
                parse_array_item "$item" "$schema"

                # Substitute variables in this iteration's block
                local rendered_block
                rendered_block=$(substitute_each_vars "$block")

                expanded+="$rendered_block"
            done
        fi

        # Replace the entire {{#each}}...{{/each}} with expanded content
        content="${before}${expanded}${after}"
    done

    echo "$content"
}

# Process conditional blocks in content
process_conditionals() {
    local content="$1"
    local max_iterations=100
    local iteration=0

    # Process {{#if ...}}...{{/if}} blocks
    while [[ "$content" == *'{{#if '* ]] && (( iteration++ < max_iterations )); do
        # Find the first {{#if block
        local before="${content%%\{\{#if *}"
        local rest="${content#*\{\{#if }"

        # Extract condition (everything until }})
        local condition="${rest%%\}\}*}"
        rest="${rest#*\}\}}"

        # Find matching {{/if}} - handle nested blocks
        local block=""
        local depth=1
        local remaining="$rest"

        while (( depth > 0 )) && [[ -n "$remaining" ]]; do
            if [[ "$remaining" == *'{{#if '* && "$remaining" == *'{{/if}}'* ]]; then
                local next_if="${remaining%%\{\{#if *}"
                local next_endif="${remaining%%\{\{/if\}\}*}"

                if [[ ${#next_if} -lt ${#next_endif} ]]; then
                    # Next is an {{#if
                    block+="${remaining%%\{\{#if *}}"
                    remaining="${remaining#*\{\{#if }"
                    local nested_cond="${remaining%%\}\}*}"
                    remaining="${remaining#*\}\}}"
                    block+="{{#if ${nested_cond}}}"
                    (( depth++ ))
                else
                    # Next is an {{/if}}
                    block+="${remaining%%\{\{/if\}\}*}"
                    remaining="${remaining#*\{\{/if\}\}}"
                    if (( depth > 1 )); then
                        block+="{{/if}}"
                    fi
                    (( depth-- ))
                fi
            elif [[ "$remaining" == *'{{/if}}'* ]]; then
                block+="${remaining%%\{\{/if\}\}*}"
                remaining="${remaining#*\{\{/if\}\}}"
                (( depth-- ))
            else
                # No more tags found
                block+="$remaining"
                break
            fi
        done

        # Handle {{#else}} within the block
        local if_block="$block"
        local else_block=""
        if [[ "$block" == *'{{#else}}'* ]]; then
            if_block="${block%%\{\{#else\}\}*}"
            else_block="${block#*\{\{#else\}\}}"
        fi

        # Evaluate and substitute
        if evaluate_condition "$condition"; then
            content="${before}${if_block}${remaining}"
        else
            content="${before}${else_block}${remaining}"
        fi
    done

    # Process {{#unless ...}}...{{/unless}} blocks (negative conditional)
    iteration=0
    while [[ "$content" == *'{{#unless '* ]] && (( iteration++ < max_iterations )); do
        local before="${content%%\{\{#unless *}"
        local rest="${content#*\{\{#unless }"
        local condition="${rest%%\}\}*}"
        rest="${rest#*\}\}}"
        local block="${rest%%\{\{/unless\}\}*}"
        local after="${rest#*\{\{/unless\}\}}"

        if ! evaluate_condition "$condition"; then
            content="${before}${block}${after}"
        else
            content="${before}${after}"
        fi
    done

    echo "$content"
}

# Render a single template file
render_template() {
    local template_file="$1"
    local output_file="${2:-}"
    local dry_run="${3:-false}"

    if [[ ! -f "$template_file" ]]; then
        fail "Template not found: $template_file"
        return 1
    fi

    # Build variables if not already done
    if [[ ${#TMPL_VARS[@]} -eq 0 ]]; then
        build_template_vars
    fi

    # Read template content
    local content
    content=$(<"$template_file")

    # Process {{#each}} loops first (expands arrays)
    content=$(process_each_loops "$content")

    # Process conditionals second (works inside expanded loops)
    content=$(process_conditionals "$content")

    # Variable substitution: {{ var }} and {{var}}
    for key in "${(@k)TMPL_VARS}"; do
        local value="${TMPL_VARS[$key]}"
        local escaped_value=$(escape_for_sed "$value")

        # Replace {{ var }} (with spaces)
        content="${content//\{\{ $key \}\}/$value}"
        # Replace {{var}} (without spaces)
        content="${content//\{\{$key\}\}/$value}"
    done

    # Check for unresolved variables
    local unresolved
    unresolved=$(echo "$content" | grep -oE '\{\{[^}]+\}\}' | head -5)
    if [[ -n "$unresolved" ]]; then
        warn "Unresolved variables in template:"
        echo "$unresolved" | while read -r var; do
            echo "  $var"
        done
    fi

    # Output
    if [[ -z "$output_file" ]]; then
        # Print to stdout
        echo "$content"
    elif [[ "$dry_run" == "true" ]]; then
        dry "Would write to: $output_file"
        echo "$content"
    else
        # Write to file
        mkdir -p "$(dirname "$output_file")"
        echo "$content" > "$output_file"
        pass "Rendered: ${template_file:t} → ${output_file}"
    fi
}

# Render all templates in the configs directory
render_all_templates() {
    local dry_run="${1:-false}"
    local force="${2:-false}"
    local count=0
    local errors=0

    # Build variables once
    build_template_vars

    info "Rendering templates..."
    info "Machine type: ${TMPL_VARS[machine_type]}"

    # Ensure output directory exists
    mkdir -p "$GENERATED_DIR"

    # Find all template files
    for template in "$TEMPLATES_CONFIG_DIR"/*.tmpl(N); do
        if [[ ! -f "$template" ]]; then
            continue
        fi

        local basename="${template:t:r}"  # Remove path and .tmpl extension
        local output_file="$GENERATED_DIR/$basename"

        # Check if output is newer than template (skip if not forced)
        if [[ "$force" != "true" && -f "$output_file" && "$output_file" -nt "$template" ]]; then
            debug "Skipping (up to date): $basename"
            continue
        fi

        if render_template "$template" "$output_file" "$dry_run"; then
            (( count++ ))
        else
            (( errors++ ))
        fi
    done

    if [[ $count -eq 0 && $errors -eq 0 ]]; then
        info "No templates to render (all up to date)"
    else
        info "Rendered $count template(s)"
    fi

    if [[ $errors -gt 0 ]]; then
        fail "Failed to render $errors template(s)"
        return 1
    fi

    return 0
}

# ============================================================
# Template Validation
# ============================================================

# Validate template syntax
validate_template() {
    local template_file="$1"
    local errors=0

    if [[ ! -f "$template_file" ]]; then
        fail "Template not found: $template_file"
        return 1
    fi

    local content
    content=$(<"$template_file")
    local line_num=0

    # Check for unmatched conditionals
    local if_count=$(grep -c '{{#if ' <<< "$content" || echo 0)
    local endif_count=$(grep -c '{{/if}}' <<< "$content" || echo 0)
    if [[ "$if_count" -ne "$endif_count" ]]; then
        fail "Unmatched {{#if}}/{{/if}} blocks: $if_count opens, $endif_count closes"
        (( errors++ ))
    fi

    local unless_count=$(grep -c '{{#unless ' <<< "$content" || echo 0)
    local endunless_count=$(grep -c '{{/unless}}' <<< "$content" || echo 0)
    if [[ "$unless_count" -ne "$endunless_count" ]]; then
        fail "Unmatched {{#unless}}/{{/unless}} blocks"
        (( errors++ ))
    fi

    # Check for unmatched {{#each}} blocks
    local each_count=$(grep -c '{{#each ' <<< "$content" || echo 0)
    local endeach_count=$(grep -c '{{/each}}' <<< "$content" || echo 0)
    if [[ "$each_count" -ne "$endeach_count" ]]; then
        fail "Unmatched {{#each}}/{{/each}} blocks: $each_count opens, $endeach_count closes"
        (( errors++ ))
    fi

    # Check for malformed variable syntax
    if grep -qE '\{\{[^}]*$' <<< "$content"; then
        fail "Unclosed {{ tag found"
        (( errors++ ))
    fi

    if grep -qE '^[^{]*\}\}' <<< "$content" | grep -v '{{'; then
        warn "Possible orphaned }} found"
    fi

    if [[ $errors -eq 0 ]]; then
        pass "Template syntax valid: ${template_file:t}"
        return 0
    else
        return 1
    fi
}

# Validate all templates
validate_all_templates() {
    local errors=0

    info "Validating templates..."

    for template in "$TEMPLATES_CONFIG_DIR"/*.tmpl(N); do
        if ! validate_template "$template"; then
            (( errors++ ))
        fi
    done

    if [[ $errors -eq 0 ]]; then
        pass "All templates valid"
        return 0
    else
        fail "$errors template(s) have errors"
        return 1
    fi
}

# ============================================================
# Template Diff
# ============================================================

# Show what would change if templates were rendered
show_template_diff() {
    local verbose="${1:-false}"

    build_template_vars

    info "Comparing templates with generated files..."

    local changes=0
    local missing=0

    for template in "$TEMPLATES_CONFIG_DIR"/*.tmpl(N); do
        local basename="${template:t:r}"
        local output_file="$GENERATED_DIR/$basename"

        if [[ ! -f "$output_file" ]]; then
            warn "Not generated: $basename"
            (( missing++ ))
            continue
        fi

        # Render to temp file
        local temp_file=$(mktemp)
        render_template "$template" "$temp_file" false 2>/dev/null

        if ! diff -q "$output_file" "$temp_file" >/dev/null 2>&1; then
            warn "Changed: $basename"
            if [[ "$verbose" == "true" ]]; then
                diff --color=auto -u "$output_file" "$temp_file" || true
            fi
            (( changes++ ))
        else
            pass "Up to date: $basename"
        fi

        rm -f "$temp_file"
    done

    if [[ $changes -eq 0 && $missing -eq 0 ]]; then
        pass "All generated files are up to date"
    else
        info "$changes file(s) changed, $missing file(s) missing"
    fi
}
