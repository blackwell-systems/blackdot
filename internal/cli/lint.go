package cli

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

type lintResult struct {
	file     string
	errors   []string
	warnings []string
}

type lintStats struct {
	checked  int
	errors   int
	warnings int
}

func newLintCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "lint",
		Short: "Validate shell config syntax",
		Long: `Validate shell configuration syntax.

Checks:
  - ZSH syntax in zsh/zsh.d/*.zsh
  - Bash syntax in lib/*.sh, bootstrap/*.sh
  - Shellcheck warnings (if installed)

Examples:
  blackdot lint              # Check all files
  blackdot lint --verbose    # Show all files checked
  blackdot lint --fix        # Show fix suggestions`,
		RunE: runLint,
	}

	cmd.Flags().BoolP("verbose", "v", false, "Show all files checked")
	cmd.Flags().BoolP("fix", "f", false, "Show fix suggestions (requires shellcheck)")

	return cmd
}

func runLint(cmd *cobra.Command, args []string) error {
	verbose, _ := cmd.Flags().GetBool("verbose")
	showFix, _ := cmd.Flags().GetBool("fix")

	dotfilesDir := os.Getenv("BLACKDOT_DIR")
	if dotfilesDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return fmt.Errorf("cannot determine home directory: %w", err)
		}
		dotfilesDir = filepath.Join(home, ".blackdot")
	}

	green := color.New(color.FgGreen).SprintFunc()
	red := color.New(color.FgRed).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()
	cyan := color.New(color.FgCyan).SprintFunc()

	fmt.Println()
	fmt.Println(color.New(color.Bold).Sprint("Blackdot Configuration Linter"))
	fmt.Println("==============================")
	fmt.Println()

	stats := lintStats{}
	var results []lintResult

	// Check for shellcheck
	hasShellcheck := false
	if _, err := exec.LookPath("shellcheck"); err == nil {
		hasShellcheck = true
	}

	// 1. Check ZSH files in zsh.d/
	fmt.Printf("%s Checking ZSH syntax...\n", cyan("→"))
	zshFiles, _ := filepath.Glob(filepath.Join(dotfilesDir, "zsh", "zsh.d", "*.zsh"))
	for _, file := range zshFiles {
		result := checkZshSyntax(file)
		stats.checked++
		if len(result.errors) > 0 {
			stats.errors += len(result.errors)
			results = append(results, result)
			fmt.Printf("  %s %s\n", red("✗"), filepath.Base(file))
		} else if verbose {
			fmt.Printf("  %s %s\n", green("✓"), filepath.Base(file))
		}
	}

	// Check main zshrc
	zshrcPath := filepath.Join(dotfilesDir, "zsh", "zshrc")
	if _, err := os.Stat(zshrcPath); err == nil {
		result := checkZshSyntax(zshrcPath)
		stats.checked++
		if len(result.errors) > 0 {
			stats.errors += len(result.errors)
			results = append(results, result)
			fmt.Printf("  %s %s\n", red("✗"), "zshrc")
		} else if verbose {
			fmt.Printf("  %s %s\n", green("✓"), "zshrc")
		}
	}

	// Check p10k.zsh
	p10kPath := filepath.Join(dotfilesDir, "zsh", "p10k.zsh")
	if _, err := os.Stat(p10kPath); err == nil {
		result := checkZshSyntax(p10kPath)
		stats.checked++
		if len(result.errors) > 0 {
			stats.errors += len(result.errors)
			results = append(results, result)
			fmt.Printf("  %s %s\n", red("✗"), "p10k.zsh")
		} else if verbose {
			fmt.Printf("  %s %s\n", green("✓"), "p10k.zsh")
		}
	}

	// 2. Check Bash/Zsh files (matches bash implementation)
	fmt.Printf("%s Checking Bash syntax...\n", cyan("→"))

	// Collect all shell script paths to check
	var shellFiles []string

	// bootstrap/*.sh
	bootstrapFiles, _ := filepath.Glob(filepath.Join(dotfilesDir, "bootstrap", "*.sh"))
	shellFiles = append(shellFiles, bootstrapFiles...)

	// lib/*.sh
	libFiles, _ := filepath.Glob(filepath.Join(dotfilesDir, "lib", "*.sh"))
	shellFiles = append(shellFiles, libFiles...)

	for _, file := range shellFiles {
		result := checkBashSyntax(file)
		stats.checked++
		if len(result.errors) > 0 {
			stats.errors += len(result.errors)
			results = append(results, result)
			fmt.Printf("  %s %s\n", red("✗"), filepath.Base(file))
		} else if verbose {
			fmt.Printf("  %s %s\n", green("✓"), filepath.Base(file))
		}
	}

	// 3. Validate config files
	fmt.Printf("%s Validating config files...\n", cyan("→"))

	// Check Brewfile exists
	brewfilePath := filepath.Join(dotfilesDir, "Brewfile")
	if _, err := os.Stat(brewfilePath); err == nil {
		stats.checked++
		if verbose {
			fmt.Printf("  %s Brewfile exists\n", green("✓"))
		}
	} else {
		fmt.Printf("  %s Brewfile missing\n", yellow("⚠"))
		stats.warnings++
	}

	// 4. Run shellcheck if available (matches bash - only on bootstrap/*.sh)
	if hasShellcheck {
		fmt.Printf("%s Running shellcheck...\n", cyan("→"))
		for _, file := range bootstrapFiles {
			result := runShellcheck(file, showFix)
			if len(result.warnings) > 0 {
				stats.warnings += len(result.warnings)
				// Find existing result or add new
				found := false
				for i, r := range results {
					if r.file == file {
						results[i].warnings = append(results[i].warnings, result.warnings...)
						found = true
						break
					}
				}
				if !found {
					results = append(results, result)
				}
				if verbose {
					fmt.Printf("  %s %s (%d warnings)\n", yellow("⚠"), filepath.Base(file), len(result.warnings))
				}
			} else if verbose {
				fmt.Printf("  %s %s\n", green("✓"), filepath.Base(file))
			}
		}
	} else {
		fmt.Printf("%s Shellcheck not installed (optional)\n", yellow("⚠"))
		fmt.Println("  Install with: brew install shellcheck")
	}

	// Print detailed results
	if len(results) > 0 {
		fmt.Println()
		fmt.Println(color.New(color.Bold).Sprint("Issues Found:"))
		fmt.Println()
		for _, r := range results {
			if len(r.errors) > 0 || len(r.warnings) > 0 {
				fmt.Printf("%s:\n", cyan(r.file))
				for _, e := range r.errors {
					fmt.Printf("  %s %s\n", red("error:"), e)
				}
				for _, w := range r.warnings {
					fmt.Printf("  %s %s\n", yellow("warning:"), w)
				}
				fmt.Println()
			}
		}
	}

	// Summary (matches bash output format)
	fmt.Println()
	fmt.Println("==============================")
	fmt.Printf("Files checked: %d\n", stats.checked)

	if stats.errors == 0 && stats.warnings == 0 {
		fmt.Printf("%s All checks passed!\n", green("[OK]"))
	} else if stats.errors == 0 {
		fmt.Printf("%s %d warning(s) found\n", yellow("[WARN]"), stats.warnings)
	} else {
		fmt.Printf("%s %d error(s), %d warning(s)\n", red("[FAIL]"), stats.errors, stats.warnings)
	}

	if stats.errors > 0 {
		return fmt.Errorf("lint failed with %d errors", stats.errors)
	}

	return nil
}

// isShellScript checks if a file is a shell script (has shebang)
func isShellScript(file string) bool {
	data, err := os.ReadFile(file)
	if err != nil {
		return false
	}
	// Check for shebang
	if len(data) < 2 {
		return false
	}
	return data[0] == '#' && data[1] == '!'
}

// checkZshSyntax runs zsh -n on a file
func checkZshSyntax(file string) lintResult {
	result := lintResult{file: file}

	cmd := exec.Command("zsh", "-n", file)
	output, err := cmd.CombinedOutput()
	if err != nil {
		// Parse error output
		lines := strings.Split(string(output), "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if line != "" {
				result.errors = append(result.errors, line)
			}
		}
		if len(result.errors) == 0 {
			result.errors = append(result.errors, err.Error())
		}
	}

	return result
}

// checkBashSyntax runs bash -n on a file
func checkBashSyntax(file string) lintResult {
	result := lintResult{file: file}

	// First check if it's a zsh script
	data, err := os.ReadFile(file)
	if err != nil {
		result.errors = append(result.errors, err.Error())
		return result
	}

	// Determine shell from shebang
	shell := "bash"
	lines := strings.Split(string(data), "\n")
	if len(lines) > 0 && strings.HasPrefix(lines[0], "#!") {
		shebang := lines[0]
		if strings.Contains(shebang, "zsh") {
			shell = "zsh"
		}
	}

	cmd := exec.Command(shell, "-n", file)
	output, err := cmd.CombinedOutput()
	if err != nil {
		errLines := strings.Split(string(output), "\n")
		for _, line := range errLines {
			line = strings.TrimSpace(line)
			if line != "" {
				result.errors = append(result.errors, line)
			}
		}
		if len(result.errors) == 0 {
			result.errors = append(result.errors, err.Error())
		}
	}

	return result
}

// runShellcheck runs shellcheck on a file
func runShellcheck(file string, showFix bool) lintResult {
	result := lintResult{file: file}

	args := []string{"-f", "gcc", file}
	if showFix {
		args = []string{"-f", "diff", file}
	}

	cmd := exec.Command("shellcheck", args...)
	output, _ := cmd.CombinedOutput()

	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line != "" && !strings.HasPrefix(line, "In ") {
			result.warnings = append(result.warnings, line)
		}
	}

	return result
}
