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
// Semantic Colors (from lib/_colors.sh)
// These describe WHAT the color means, not what it looks like
// ============================================================
var (
	// Semantic colors
	ClrPrimary   = color.New(color.FgCyan)              // Main accent, highlights
	ClrSecondary = color.New(color.FgYellow)            // Secondary accent
	ClrSuccess   = color.New(color.FgGreen)             // Success, enabled, OK
	ClrError     = color.New(color.FgRed)               // Errors, failures, disabled
	ClrWarning   = color.New(color.FgYellow)            // Warnings, caution
	ClrInfo      = color.New(color.FgBlue)              // Informational
	ClrMuted     = color.New(color.Faint)               // Dim - secondary text
	ClrBold      = color.New(color.Bold)                // Emphasis
	ClrHeader    = color.New(color.Bold, color.FgCyan)  // Bold cyan for headers
	ClrBox       = color.New(color.Faint)               // Box borders

	// Tool-specific brand colors (match official brand colors)
	ClrRust   = color.New(color.FgYellow)            // Orange (Rust's brand color)
	ClrGo     = color.New(color.FgCyan)              // Cyan/Teal (Go's gopher blue)
	ClrPython = color.New(color.FgBlue)              // Blue (Python's blue)
	ClrAWS    = color.New(color.FgYellow)            // Orange (AWS's orange)
	ClrCDK    = color.New(color.FgGreen)             // Green (CDK/CloudFormation green)
	ClrNode   = color.New(color.FgGreen)             // Green (Node.js green)
	ClrJava   = color.New(color.FgRed)               // Red (Java red)
	ClrSSH    = color.New(color.FgMagenta)           // Magenta (SSH/security purple)
	ClrDocker = color.New(color.FgCyan)              // Cyan (Docker's blue/teal)
)

// ============================================================
// Legacy Color Names (backward compatibility with lib/_logging.sh)
// ============================================================
var (
	Red     = ClrError
	Green   = ClrSuccess
	Yellow  = ClrWarning
	Blue    = ClrInfo
	Cyan    = ClrPrimary
	Magenta = color.New(color.FgMagenta)
	Bold    = ClrBold
	Dim     = ClrMuted
)

// Combined styles
var (
	BoldCyan  = color.New(color.Bold, color.FgCyan)
	BoldGreen = color.New(color.Bold, color.FgGreen)
	BoldRed   = color.New(color.Bold, color.FgRed)
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

// Section prints a section header
func Section(title string) {
	fmt.Fprintln(os.Stderr)
	Bold.Fprintf(os.Stderr, "=== %s ===\n", title)
	fmt.Fprintln(os.Stderr)
}

// Separator prints a separator line
func Separator() {
	fmt.Fprintln(os.Stderr, "────────────────────────────────────────")
}

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

// ============================================================
// Color Control
// ============================================================

// NoColor disables color output (for piping, CI, etc.)
func NoColor() {
	color.NoColor = true
}

// ForceColor forces color output even when not a TTY
func ForceColor() {
	color.NoColor = false
}

// IsColorEnabled returns whether color output is enabled
func IsColorEnabled() bool {
	return !color.NoColor
}
