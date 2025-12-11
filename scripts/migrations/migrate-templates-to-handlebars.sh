#!/usr/bin/env bash
# =============================================================================
# Template Migration Script: Custom Syntax → Standard Handlebars
# =============================================================================
# This script converts our custom template syntax to standard Handlebars
# that's compatible with both our updated bash engine and Go's raymond library.
#
# Changes made:
#   {{#if var == "value"}}  →  {{#if (eq var "value")}}
#   {{#if var != "value"}}  →  {{#if (ne var "value")}}
#
# Note: Pipe syntax ({{ var | filter }}) is NOT used in current templates,
# so no conversion is needed for that.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLACKDOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$BLACKDOT_DIR/templates/configs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }

# Dry run by default
DRY_RUN="${DRY_RUN:-true}"
BACKUP="${BACKUP:-true}"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Migrate template files from custom syntax to standard Handlebars.

Options:
    --dry-run       Show what would change (default)
    --apply         Actually make the changes
    --no-backup     Skip creating .bak files
    -h, --help      Show this help

Examples:
    $0 --dry-run    # Preview changes
    $0 --apply      # Apply changes (creates backups)
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --apply) DRY_RUN=false; shift ;;
        --no-backup) BACKUP=false; shift ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown option: $1"; usage; exit 1 ;;
    esac
done

echo "=============================================="
echo "Template Migration: Custom → Handlebars"
echo "=============================================="
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    warn "DRY RUN MODE - No changes will be made"
    warn "Use --apply to make actual changes"
    echo ""
fi

# Track changes
TOTAL_FILES=0
TOTAL_CHANGES=0

migrate_file() {
    local file="$1"
    local filename=$(basename "$file")
    local changes=0

    info "Processing: $filename"

    # Check for patterns that need migration
    # Pattern 1: {{#if var == "value"}}
    local eq_matches=$(grep -c '{{#if [a-zA-Z_][a-zA-Z0-9_]* == "' "$file" 2>/dev/null || true)

    # Pattern 2: {{#if var != "value"}} (if any)
    local ne_matches=$(grep -c '{{#if [a-zA-Z_][a-zA-Z0-9_]* != "' "$file" 2>/dev/null || true)

    changes=$((eq_matches + ne_matches))

    if [[ $changes -eq 0 ]]; then
        pass "  No changes needed"
        return 0
    fi

    TOTAL_CHANGES=$((TOTAL_CHANGES + changes))

    # Show what will change
    echo "  Found $changes pattern(s) to convert:"

    # Show specific lines
    grep -n '{{#if [a-zA-Z_][a-zA-Z0-9_]* ==' "$file" 2>/dev/null | while read -r line; do
        local linenum=$(echo "$line" | cut -d: -f1)
        local content=$(echo "$line" | cut -d: -f2-)
        echo "    Line $linenum: $content"
    done

    grep -n '{{#if [a-zA-Z_][a-zA-Z0-9_]* !=' "$file" 2>/dev/null | while read -r line; do
        local linenum=$(echo "$line" | cut -d: -f1)
        local content=$(echo "$line" | cut -d: -f2-)
        echo "    Line $linenum: $content"
    done

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would convert to:"
        # Show what it would become
        grep '{{#if [a-zA-Z_][a-zA-Z0-9_]* ==' "$file" 2>/dev/null | while read -r line; do
            # Convert == to (eq)
            local converted=$(echo "$line" | sed -E 's/\{\{#if ([a-zA-Z_][a-zA-Z0-9_]*) == "([^"]+)"/{{#if (eq \1 "\2")/g')
            echo "    → $converted"
        done
        return 0
    fi

    # Actually make changes
    if [[ "$BACKUP" == "true" ]]; then
        cp "$file" "$file.bak"
        echo "  Created backup: $filename.bak"
    fi

    # Convert {{#if var == "value"}} → {{#if (eq var "value")}}
    sed -i -E 's/\{\{#if ([a-zA-Z_][a-zA-Z0-9_]*) == "([^"]+)"/{{#if (eq \1 "\2")/g' "$file"

    # Convert {{#if var != "value"}} → {{#if (ne var "value")}}
    sed -i -E 's/\{\{#if ([a-zA-Z_][a-zA-Z0-9_]*) != "([^"]+)"/{{#if (ne \1 "\2")/g' "$file"

    pass "  Converted $changes pattern(s)"
}

# Find and process all template files
for tmpl in "$TEMPLATES_DIR"/*.tmpl; do
    if [[ -f "$tmpl" ]]; then
        TOTAL_FILES=$((TOTAL_FILES + 1))
        migrate_file "$tmpl"
        echo ""
    fi
done

echo "=============================================="
echo "Summary"
echo "=============================================="
echo "Files processed: $TOTAL_FILES"
echo "Patterns found:  $TOTAL_CHANGES"

if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    if [[ $TOTAL_CHANGES -gt 0 ]]; then
        warn "Run with --apply to make these changes"
    else
        pass "All templates already use standard Handlebars syntax!"
    fi
else
    echo ""
    pass "Migration complete!"
    if [[ "$BACKUP" == "true" ]]; then
        info "Backup files created with .bak extension"
        info "To remove backups: rm $TEMPLATES_DIR/*.bak"
    fi
fi
