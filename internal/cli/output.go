// Package cli output utilities
// Mirrors lib/_colors.sh and lib/_logging.sh from the Zsh implementation
package cli

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/fatih/color"
)

// ============================================================
// Colors
// ============================================================
var (
	Red     = color.New(color.FgRed)
	Green   = color.New(color.FgGreen)
	Yellow  = color.New(color.FgYellow)
	Blue    = color.New(color.FgBlue)
	Cyan    = color.New(color.FgCyan)
	Magenta = color.New(color.FgMagenta)
	Bold    = color.New(color.Bold)
	Dim     = color.New(color.Faint)
)

// Combined styles
var (
	BoldCyan = color.New(color.Bold, color.FgCyan)
)

// ============================================================
// Logging Functions (from lib/_logging.sh)
// ============================================================

// Info prints an informational message (blue)
func Info(format string, a ...interface{}) {
	msg := fmt.Sprintf(format, a...)
	Blue.Fprint(os.Stderr, "[INFO] ")
	fmt.Fprintln(os.Stderr, msg)
}

// Pass prints a success message (green)
func Pass(format string, a ...interface{}) {
	msg := fmt.Sprintf(format, a...)
	Green.Fprint(os.Stderr, "[OK] ")
	fmt.Fprintln(os.Stderr, msg)
}

// Warn prints a warning message (yellow)
func Warn(format string, a ...interface{}) {
	msg := fmt.Sprintf(format, a...)
	Yellow.Fprint(os.Stderr, "[WARN] ")
	fmt.Fprintln(os.Stderr, msg)
}

// Fail prints an error message (red)
func Fail(format string, a ...interface{}) {
	msg := fmt.Sprintf(format, a...)
	Red.Fprint(os.Stderr, "[FAIL] ")
	fmt.Fprintln(os.Stderr, msg)
}

// DryRun prints a dry-run message (cyan)
func DryRun(format string, a ...interface{}) {
	msg := fmt.Sprintf(format, a...)
	Cyan.Fprint(os.Stderr, "[DRY-RUN] ")
	fmt.Fprintln(os.Stderr, msg)
}

// Debug prints a debug message (only when verbose flag is set)
func Debug(format string, a ...interface{}) {
	if !verbose {
		return
	}
	msg := fmt.Sprintf(format, a...)
	Magenta.Fprint(os.Stderr, "[DEBUG] ")
	fmt.Fprintln(os.Stderr, msg)
}

// ============================================================
// Helper Functions (from lib/_logging.sh)
// ============================================================

// Confirm prompts for yes/no confirmation
// Returns true for yes, false for no
func Confirm(prompt string) bool {
	if prompt == "" {
		prompt = "Continue?"
	}

	Yellow.Fprintf(os.Stderr, "%s ", prompt)
	fmt.Fprint(os.Stderr, "[y/N] ")

	reader := bufio.NewReader(os.Stdin)
	response, _ := reader.ReadString('\n')
	response = strings.TrimSpace(strings.ToLower(response))

	return response == "y" || response == "yes"
}

// ============================================================
// Feature Status Display
// ============================================================

// StatusIcon returns the appropriate icon for enabled/disabled state
func StatusIcon(enabled bool) string {
	if enabled {
		return "●"
	}
	return "○"
}

// StatusColor returns the appropriate color for enabled/disabled state
func StatusColor(enabled bool) *color.Color {
	if enabled {
		return Green
	}
	return Dim
}

// PrintFeature prints a feature with status icon and description
func PrintFeature(name, description string, enabled bool) {
	icon := StatusIcon(enabled)
	c := StatusColor(enabled)

	c.Printf("  %s ", icon)
	fmt.Printf("%-20s ", name)
	Dim.Printf("%s\n", description)
}

// PrintDeps prints dependencies in dim text with tree prefix
func PrintDeps(deps string) {
	Dim.Printf("    └─ requires: %s\n", deps)
}

// ============================================================
// Section Headers
// ============================================================

// PrintHeader prints a bold section header with double-line border
func PrintHeader(title string) {
	Bold.Println(title)
	fmt.Println(strings.Repeat("═", len(title)+10))
	fmt.Println()
}

// PrintSubheader prints a category subheader with single-line border
func PrintSubheader(title string) {
	BoldCyan.Println(title)
	fmt.Println(strings.Repeat("─", len(title)+10))
}

// PrintLegend prints the feature status legend
func PrintLegend() {
	fmt.Println()
	Dim.Print("Legend: ")
	Green.Print("●")
	Dim.Print(" enabled  ")
	Dim.Print("○ disabled")
	fmt.Println()
}

// PrintHint prints a dim hint message
func PrintHint(format string, a ...interface{}) {
	msg := fmt.Sprintf(format, a...)
	Dim.Println(msg)
}
