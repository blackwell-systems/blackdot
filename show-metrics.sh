#!/usr/bin/env zsh
# ============================================================
# FILE: show-metrics.sh
# Visualizes dotfiles health metrics over time
# Usage: ./show-metrics.sh [--all|--graph|--summary]
# ============================================================

set -uo pipefail

METRICS_FILE="$HOME/.dotfiles-metrics.jsonl"

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
fi

# Check if metrics file exists
if [[ ! -f "$METRICS_FILE" ]]; then
    echo "No metrics found. Run 'dotfiles doctor' to start collecting metrics."
    exit 1
fi

# Check for jq
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required. Install with: brew install jq"
    exit 1
fi

# Parse arguments
MODE="${1:-summary}"

case "$MODE" in
    --all|-a)
        echo -e "${BOLD}=== All Health Check Metrics ===${NC}"
        echo ""
        jq -r '. | "\(.timestamp | split("T")[0]) \(.timestamp | split("T")[1] | split("+")[0]) | Score: \(.health_score) | Errors: \(.errors) | Warnings: \(.warnings) | Branch: \(.git_branch) | \(.hostname)"' "$METRICS_FILE"
        ;;

    --graph|-g)
        echo -e "${BOLD}=== Health Score Trend (Last 30 Checks) ===${NC}"
        echo ""

        # Get last 30 entries and create a simple ASCII graph
        tail -30 "$METRICS_FILE" | jq -r '[.timestamp | split("T")[0], .health_score] | @tsv' | while IFS=$'\t' read -r date score; do
            # Create bar graph
            bar_length=$((score / 5))  # Scale to max 20 chars (100/5)
            bar=$(printf '█%.0s' {1..$bar_length})

            # Color code based on score
            if [[ $score -ge 90 ]]; then
                color="$GREEN"
            elif [[ $score -ge 70 ]]; then
                color="$YELLOW"
            else
                color="$RED"
            fi

            printf "${color}%-12s %3d %s${NC}\n" "$date" "$score" "$bar"
        done
        ;;

    --summary|-s|*)
        echo -e "${BOLD}=== Dotfiles Health Metrics Summary ===${NC}"
        echo ""

        # Total checks
        total=$(wc -l < "$METRICS_FILE" | tr -d ' ')
        echo -e "${CYAN}Total health checks:${NC} $total"
        echo ""

        # Recent checks (last 10)
        echo -e "${BOLD}Last 10 health checks:${NC}"
        tail -10 "$METRICS_FILE" | jq -r '. |
            if .health_score >= 90 then "✅"
            elif .health_score >= 70 then "⚠️ "
            else "❌"
            end as $status |
            "\($status) \(.timestamp | split("T")[0]) | Score: \(.health_score)/100 | E:\(.errors) W:\(.warnings) | \(.git_branch)"
        '
        echo ""

        # Statistics
        echo -e "${BOLD}Statistics:${NC}"

        # Average health score
        avg_score=$(jq -s 'map(.health_score) | add / length | floor' "$METRICS_FILE")
        echo -e "  Average health score: ${CYAN}${avg_score}/100${NC}"

        # Total errors and warnings
        total_errors=$(jq -s 'map(.errors) | add' "$METRICS_FILE")
        total_warnings=$(jq -s 'map(.warnings) | add' "$METRICS_FILE")
        total_fixed=$(jq -s 'map(.fixed) | add' "$METRICS_FILE")

        echo -e "  Total errors found:   ${RED}${total_errors}${NC}"
        echo -e "  Total warnings found: ${YELLOW}${total_warnings}${NC}"
        echo -e "  Total auto-fixed:     ${GREEN}${total_fixed}${NC}"

        # Perfect runs
        perfect=$(jq -s 'map(select(.health_score == 100)) | length' "$METRICS_FILE")
        perfect_pct=$((perfect * 100 / total))
        echo -e "  Perfect runs:         ${GREEN}${perfect}${NC} (${perfect_pct}%)"

        # Recent trend
        echo ""
        echo -e "${BOLD}Recent trend (last 5 vs previous 5):${NC}"

        recent_avg=$(tail -5 "$METRICS_FILE" | jq -s 'map(.health_score) | add / length | floor')
        previous_avg=$(tail -10 "$METRICS_FILE" | head -5 | jq -s 'map(.health_score) | add / length | floor')

        if [[ $recent_avg -gt $previous_avg ]]; then
            trend="📈 Improving"
            color="$GREEN"
        elif [[ $recent_avg -lt $previous_avg ]]; then
            trend="📉 Declining"
            color="$RED"
        else
            trend="➡️  Stable"
            color="$CYAN"
        fi

        echo -e "  ${color}${trend}${NC} (${previous_avg} → ${recent_avg})"

        # Most common issues
        echo ""
        echo -e "${BOLD}Platform distribution:${NC}"
        jq -s 'group_by(.os) | map({os: .[0].os, count: length}) | .[] | "  \(.os): \(.count) checks"' "$METRICS_FILE"

        echo ""
        echo -e "${BLUE}Tip: Use --graph to see health score trend${NC}"
        echo -e "${BLUE}     Use --all to see all entries${NC}"
        ;;
esac

echo ""
