package cli

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// MetricEntry represents a single health check metric
type MetricEntry struct {
	Timestamp   string `json:"timestamp"`
	HealthScore int    `json:"health_score"`
	Errors      int    `json:"errors"`
	Warnings    int    `json:"warnings"`
	Fixed       int    `json:"fixed"`
	GitBranch   string `json:"git_branch"`
	GitCommit   string `json:"git_commit"`
	Hostname    string `json:"hostname"`
	OS          string `json:"os"`
}

func newMetricsCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "metrics",
		Short: "Visualize health check metrics over time",
		Long: `Show health check metrics dashboard and historical trends.

Modes:
  (default)     Summary with statistics and recent checks
  --graph, -g   ASCII bar chart of health scores (last 30)
  --all, -a     Show all metric entries

Examples:
  dotfiles-go metrics           # Summary view
  dotfiles-go metrics --graph   # Health score trend
  dotfiles-go metrics --all     # All entries`,
		RunE: runMetrics,
	}

	cmd.Flags().BoolP("all", "a", false, "Show all metric entries")
	cmd.Flags().BoolP("graph", "g", false, "Show health score graph (last 30)")

	return cmd
}

func runMetrics(cmd *cobra.Command, args []string) error {
	home, _ := os.UserHomeDir()
	metricsFile := filepath.Join(home, ".dotfiles-metrics.jsonl")

	showAll, _ := cmd.Flags().GetBool("all")
	showGraph, _ := cmd.Flags().GetBool("graph")

	// Check if metrics file exists
	if _, err := os.Stat(metricsFile); os.IsNotExist(err) {
		fmt.Println("No metrics found. Run 'dotfiles doctor' to start collecting metrics.")
		return nil
	}

	// Load all metrics
	entries, err := loadMetrics(metricsFile)
	if err != nil {
		return fmt.Errorf("loading metrics: %w", err)
	}

	if len(entries) == 0 {
		fmt.Println("No metrics found. Run 'dotfiles doctor' to start collecting metrics.")
		return nil
	}

	bold := color.New(color.Bold).SprintFunc()
	cyan := color.New(color.FgCyan).SprintFunc()
	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()
	red := color.New(color.FgRed).SprintFunc()
	blue := color.New(color.FgBlue).SprintFunc()

	if showAll {
		// Show all entries
		fmt.Println()
		fmt.Println(bold("=== All Health Check Metrics ==="))
		fmt.Println()

		for _, e := range entries {
			date, timeStr := parseTimestamp(e.Timestamp)
			fmt.Printf("%s %s | Score: %d | Errors: %d | Warnings: %d | Branch: %s | %s\n",
				date, timeStr, e.HealthScore, e.Errors, e.Warnings, e.GitBranch, e.Hostname)
		}
	} else if showGraph {
		// Show ASCII graph of last 30
		fmt.Println()
		fmt.Println(bold("=== Health Score Trend (Last 30 Checks) ==="))
		fmt.Println()

		// Get last 30 entries
		start := 0
		if len(entries) > 30 {
			start = len(entries) - 30
		}
		recentEntries := entries[start:]

		for _, e := range recentEntries {
			date, _ := parseTimestamp(e.Timestamp)
			score := e.HealthScore

			// Create bar (scale to max 20 chars)
			barLen := score / 5
			bar := strings.Repeat("█", barLen)

			// Color code based on score
			var colorFn func(a ...interface{}) string
			if score >= 90 {
				colorFn = green
			} else if score >= 70 {
				colorFn = yellow
			} else {
				colorFn = red
			}

			fmt.Printf("%s%-12s %3d %s%s\n", colorFn(""), date, score, bar, color.New(color.Reset).Sprint(""))
		}
	} else {
		// Summary mode (default)
		fmt.Println()
		fmt.Println(bold("=== Dotfiles Health Metrics Summary ==="))
		fmt.Println()

		// Total checks
		total := len(entries)
		fmt.Printf("%s %d\n", cyan("Total health checks:"), total)
		fmt.Println()

		// Last 10 checks
		fmt.Println(bold("Last 10 health checks:"))
		start := 0
		if len(entries) > 10 {
			start = len(entries) - 10
		}
		for _, e := range entries[start:] {
			date, _ := parseTimestamp(e.Timestamp)

			var status string
			if e.HealthScore >= 90 {
				status = green("✓")
			} else if e.HealthScore >= 70 {
				status = yellow("⚠")
			} else {
				status = red("✗")
			}

			fmt.Printf("%s %s | Score: %d/100 | E:%d W:%d | %s\n",
				status, date, e.HealthScore, e.Errors, e.Warnings, e.GitBranch)
		}
		fmt.Println()

		// Statistics
		fmt.Println(bold("Statistics:"))

		// Average health score
		var totalScore int
		for _, e := range entries {
			totalScore += e.HealthScore
		}
		avgScore := totalScore / total
		fmt.Printf("  Average health score: %s\n", cyan(fmt.Sprintf("%d/100", avgScore)))

		// Total errors, warnings, fixed
		var totalErrors, totalWarnings, totalFixed int
		for _, e := range entries {
			totalErrors += e.Errors
			totalWarnings += e.Warnings
			totalFixed += e.Fixed
		}

		fmt.Printf("  Total errors found:   %s\n", red(fmt.Sprintf("%d", totalErrors)))
		fmt.Printf("  Total warnings found: %s\n", yellow(fmt.Sprintf("%d", totalWarnings)))
		fmt.Printf("  Total auto-fixed:     %s\n", green(fmt.Sprintf("%d", totalFixed)))

		// Perfect runs
		var perfect int
		for _, e := range entries {
			if e.HealthScore == 100 {
				perfect++
			}
		}
		perfectPct := perfect * 100 / total
		fmt.Printf("  Perfect runs:         %s (%d%%)\n", green(fmt.Sprintf("%d", perfect)), perfectPct)

		// Recent trend
		fmt.Println()
		fmt.Println(bold("Recent trend (last 5 vs previous 5):"))

		recentAvg := 0
		previousAvg := 0

		if len(entries) >= 5 {
			last5 := entries[len(entries)-5:]
			for _, e := range last5 {
				recentAvg += e.HealthScore
			}
			recentAvg /= 5
		}

		if len(entries) >= 10 {
			prev5 := entries[len(entries)-10 : len(entries)-5]
			for _, e := range prev5 {
				previousAvg += e.HealthScore
			}
			previousAvg /= 5
		} else if len(entries) >= 5 {
			previousAvg = recentAvg // Not enough data for previous
		}

		var trend string
		var trendColor func(a ...interface{}) string
		if recentAvg > previousAvg {
			trend = "Improving"
			trendColor = green
		} else if recentAvg < previousAvg {
			trend = "Declining"
			trendColor = red
		} else {
			trend = "Stable"
			trendColor = cyan
		}

		fmt.Printf("  %s (%d -> %d)\n", trendColor(trend), previousAvg, recentAvg)

		// Platform distribution
		fmt.Println()
		fmt.Println(bold("Platform distribution:"))
		osCount := make(map[string]int)
		for _, e := range entries {
			osCount[e.OS]++
		}
		for os, count := range osCount {
			if os == "" {
				os = "unknown"
			}
			fmt.Printf("  %s: %d checks\n", os, count)
		}

		fmt.Println()
		fmt.Printf("%s\n", blue("Tip: Use --graph to see health score trend"))
		fmt.Printf("%s\n", blue("     Use --all to see all entries"))
	}

	fmt.Println()
	return nil
}

func loadMetrics(path string) ([]MetricEntry, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var entries []MetricEntry
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}

		var entry MetricEntry
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			// Skip malformed lines
			continue
		}
		entries = append(entries, entry)
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}

	// Sort by timestamp
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Timestamp < entries[j].Timestamp
	})

	return entries, nil
}

func parseTimestamp(ts string) (date, timeStr string) {
	// Format: 2024-12-07T12:34:56+00:00
	parts := strings.Split(ts, "T")
	if len(parts) >= 2 {
		date = parts[0]
		timeParts := strings.Split(parts[1], "+")
		if len(timeParts) >= 1 {
			timeStr = timeParts[0]
		}
	}
	return
}
