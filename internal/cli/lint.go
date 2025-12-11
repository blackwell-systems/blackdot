package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
	"gopkg.in/yaml.v3"
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
		Short: "Validate configuration and code",
		Long: `Comprehensive linter for blackdot configuration and code.

Checks:
  - ZSH syntax in zsh/zsh.d/*.zsh
  - Bash syntax in lib/*.sh, bootstrap/*.sh
  - Go code (go vet, go fmt)
  - JSON files (config, packages.json)
  - YAML files (GitHub workflows)
  - PowerShell syntax (if pwsh available)
  - Brewfile tiers existence
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

	blackdotDir := os.Getenv("BLACKDOT_DIR")
	if blackdotDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return fmt.Errorf("cannot determine home directory: %w", err)
		}
		blackdotDir = filepath.Join(home, ".blackdot")
	}

	green := color.New(color.FgGreen).SprintFunc()
	red := color.New(color.FgRed).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()
	cyan := color.New(color.FgCyan).SprintFunc()
	dim := color.New(color.Faint).SprintFunc()

	fmt.Println()
	fmt.Println(color.New(color.Bold).Sprint("Blackdot Configuration Linter"))
	fmt.Println("==============================")
	fmt.Println()

	stats := lintStats{}
	var results []lintResult

	// Check for available tools
	hasShellcheck := commandExists("shellcheck")
	hasPwsh := commandExists("pwsh")
	hasGo := commandExists("go")

	// 1. Check ZSH files in zsh.d/
	fmt.Printf("%s Checking ZSH syntax...\n", cyan("→"))
	zshFiles, _ := filepath.Glob(filepath.Join(blackdotDir, "zsh", "zsh.d", "*.zsh"))
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
	zshrcPath := filepath.Join(blackdotDir, "zsh", "zshrc")
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
	p10kPath := filepath.Join(blackdotDir, "zsh", "p10k.zsh")
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

	// 2. Check Bash/Shell files
	fmt.Printf("%s Checking Bash syntax...\n", cyan("→"))

	// Collect all shell script paths to check
	var shellFiles []string

	// bootstrap/*.sh
	bootstrapFiles, _ := filepath.Glob(filepath.Join(blackdotDir, "bootstrap", "*.sh"))
	shellFiles = append(shellFiles, bootstrapFiles...)

	// lib/*.sh
	libFiles, _ := filepath.Glob(filepath.Join(blackdotDir, "lib", "*.sh"))
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

	// 3. Check Go code (if go is available)
	if hasGo {
		fmt.Printf("%s Checking Go code...\n", cyan("→"))

		// Run go vet
		vetResult := runGoVet(blackdotDir)
		stats.checked++
		if len(vetResult.errors) > 0 {
			stats.errors += len(vetResult.errors)
			results = append(results, vetResult)
			fmt.Printf("  %s go vet\n", red("✗"))
		} else if verbose {
			fmt.Printf("  %s go vet\n", green("✓"))
		}

		// Run go fmt check
		fmtResult := runGoFmtCheck(blackdotDir)
		stats.checked++
		if len(fmtResult.warnings) > 0 {
			stats.warnings += len(fmtResult.warnings)
			results = append(results, fmtResult)
			fmt.Printf("  %s go fmt %s\n", yellow("⚠"), dim(fmt.Sprintf("(%d files need formatting)", len(fmtResult.warnings))))
		} else if verbose {
			fmt.Printf("  %s go fmt\n", green("✓"))
		}
	} else {
		fmt.Printf("%s Go not installed, skipping Go checks\n", yellow("⚠"))
	}

	// 4. Validate JSON files
	fmt.Printf("%s Validating JSON files...\n", cyan("→"))

	jsonFiles := []string{
		filepath.Join(blackdotDir, "powershell", "packages.json"),
	}

	// Also check config directory JSON files
	configDir := filepath.Join(os.Getenv("HOME"), ".config", "blackdot")
	if configJSON := filepath.Join(configDir, "config.json"); lintFileExists(configJSON) {
		jsonFiles = append(jsonFiles, configJSON)
	}

	for _, file := range jsonFiles {
		if !lintFileExists(file) {
			continue
		}
		result := validateJSON(file)
		stats.checked++
		if len(result.errors) > 0 {
			stats.errors += len(result.errors)
			results = append(results, result)
			fmt.Printf("  %s %s\n", red("✗"), filepath.Base(file))
		} else if verbose {
			fmt.Printf("  %s %s\n", green("✓"), filepath.Base(file))
		}
	}

	// 5. Validate YAML files (GitHub workflows)
	fmt.Printf("%s Validating YAML files...\n", cyan("→"))

	yamlFiles, _ := filepath.Glob(filepath.Join(blackdotDir, ".github", "workflows", "*.yml"))
	yamlFiles2, _ := filepath.Glob(filepath.Join(blackdotDir, ".github", "workflows", "*.yaml"))
	yamlFiles = append(yamlFiles, yamlFiles2...)

	for _, file := range yamlFiles {
		result := validateYAML(file)
		stats.checked++
		if len(result.errors) > 0 {
			stats.errors += len(result.errors)
			results = append(results, result)
			fmt.Printf("  %s %s\n", red("✗"), filepath.Base(file))
		} else if verbose {
			fmt.Printf("  %s %s\n", green("✓"), filepath.Base(file))
		}
	}

	// 6. Check Brewfile tiers
	fmt.Printf("%s Checking Brewfile tiers...\n", cyan("→"))

	brewfileTiers := []string{
		filepath.Join(blackdotDir, "brew", "Brewfile"),
		filepath.Join(blackdotDir, "brew", "Brewfile.minimal"),
		filepath.Join(blackdotDir, "brew", "Brewfile.enhanced"),
	}

	for _, file := range brewfileTiers {
		stats.checked++
		if lintFileExists(file) {
			if verbose {
				fmt.Printf("  %s %s\n", green("✓"), filepath.Base(file))
			}
		} else {
			fmt.Printf("  %s %s missing\n", yellow("⚠"), filepath.Base(file))
			stats.warnings++
		}
	}

	// 7. Check PowerShell syntax (if pwsh available)
	if hasPwsh {
		fmt.Printf("%s Checking PowerShell syntax...\n", cyan("→"))

		psFiles, _ := filepath.Glob(filepath.Join(blackdotDir, "powershell", "*.psm1"))
		psFiles2, _ := filepath.Glob(filepath.Join(blackdotDir, "powershell", "*.ps1"))
		psFiles = append(psFiles, psFiles2...)

		for _, file := range psFiles {
			result := checkPowerShellSyntax(file)
			stats.checked++
			if len(result.errors) > 0 {
				stats.errors += len(result.errors)
				results = append(results, result)
				fmt.Printf("  %s %s\n", red("✗"), filepath.Base(file))
			} else if verbose {
				fmt.Printf("  %s %s\n", green("✓"), filepath.Base(file))
			}
		}
	} else if verbose {
		fmt.Printf("%s PowerShell (pwsh) not installed, skipping PS checks\n", dim("ℹ"))
	}

	// 8. Run shellcheck if available (on both bootstrap and lib)
	if hasShellcheck {
		fmt.Printf("%s Running shellcheck...\n", cyan("→"))

		// Run on all shell files
		for _, file := range shellFiles {
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
					fmt.Printf("  %s %s %s\n", yellow("⚠"), filepath.Base(file), dim(fmt.Sprintf("(%d warnings)", len(result.warnings))))
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
		hasIssues := false
		for _, r := range results {
			if len(r.errors) > 0 || len(r.warnings) > 0 {
				hasIssues = true
				break
			}
		}

		if hasIssues {
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
	}

	// Summary
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

// commandExists checks if a command is available in PATH
func commandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

// lintFileExists checks if a file exists (local to lint)
func lintFileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// checkZshSyntax runs zsh -n on a file
func checkZshSyntax(file string) lintResult {
	result := lintResult{file: file}

	cmd := exec.Command("zsh", "-n", file)
	output, err := cmd.CombinedOutput()
	if err != nil {
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

// runGoVet runs go vet on the project
func runGoVet(dir string) lintResult {
	result := lintResult{file: "go vet"}

	cmd := exec.Command("go", "vet", "./...")
	cmd.Dir = dir
	output, err := cmd.CombinedOutput()
	if err != nil {
		lines := strings.Split(string(output), "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if line != "" && !strings.HasPrefix(line, "#") {
				result.errors = append(result.errors, line)
			}
		}
	}

	return result
}

// runGoFmtCheck checks if any Go files need formatting
func runGoFmtCheck(dir string) lintResult {
	result := lintResult{file: "go fmt"}

	cmd := exec.Command("gofmt", "-l", ".")
	cmd.Dir = dir
	output, err := cmd.CombinedOutput()
	if err != nil {
		result.warnings = append(result.warnings, err.Error())
		return result
	}

	// gofmt -l outputs files that need formatting
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line != "" {
			result.warnings = append(result.warnings, fmt.Sprintf("%s needs formatting", line))
		}
	}

	return result
}

// validateJSON validates a JSON file
func validateJSON(file string) lintResult {
	result := lintResult{file: file}

	data, err := os.ReadFile(file)
	if err != nil {
		result.errors = append(result.errors, err.Error())
		return result
	}

	var js interface{}
	if err := json.Unmarshal(data, &js); err != nil {
		result.errors = append(result.errors, fmt.Sprintf("invalid JSON: %s", err.Error()))
	}

	return result
}

// validateYAML validates a YAML file
func validateYAML(file string) lintResult {
	result := lintResult{file: file}

	data, err := os.ReadFile(file)
	if err != nil {
		result.errors = append(result.errors, err.Error())
		return result
	}

	var yml interface{}
	if err := yaml.Unmarshal(data, &yml); err != nil {
		result.errors = append(result.errors, fmt.Sprintf("invalid YAML: %s", err.Error()))
	}

	return result
}

// checkPowerShellSyntax validates PowerShell syntax using pwsh
func checkPowerShellSyntax(file string) lintResult {
	result := lintResult{file: file}

	// Use PowerShell's parser to check syntax
	script := fmt.Sprintf(`
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile('%s', [ref]$null, [ref]$errors) | Out-Null
if ($errors) {
    foreach ($e in $errors) {
        Write-Output $e.Message
    }
    exit 1
}
`, file)

	cmd := exec.Command("pwsh", "-NoProfile", "-Command", script)
	output, err := cmd.CombinedOutput()
	if err != nil {
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
