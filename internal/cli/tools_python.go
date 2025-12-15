// Package cli implements the blackdot command-line interface using Cobra.
package cli

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

// newToolsPythonCmd creates the python tools subcommand
func newToolsPythonCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "python",
		Short: "Python/uv development helpers",
		Long: `Python development helper tools (powered by uv).

Cross-platform Python utilities for project creation, testing, and environment management.

Commands:
  new       - Create new Python project with uv
  clean     - Clean Python artifacts (*.pyc, __pycache__, etc)
  venv      - Create virtual environment
  test      - Run pytest
  cover     - Run pytest with coverage
  info      - Show Python environment info`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runPythonStatus()
		},
	}

	cmd.AddCommand(
		newPythonNewCmd(),
		newPythonCleanCmd(),
		newPythonVenvCmd(),
		newPythonTestCmd(),
		newPythonCoverCmd(),
		newPythonInfoCmd(),
	)

	return cmd
}

// newPythonNewCmd creates new Python project
func newPythonNewCmd() *cobra.Command {
	var template string

	cmd := &cobra.Command{
		Use:   "new <name>",
		Short: "Create new Python project with uv",
		Long: `Create a new Python project using uv.

Templates:
  app     Application with pyproject.toml (default)
  lib     Library package structure
  script  Single script with inline dependencies`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			name := args[0]
			return runPythonNew(name, template)
		},
	}

	cmd.Flags().StringVarP(&template, "template", "t", "app", "Project template (app, lib, script)")

	return cmd
}

func runPythonNew(name, template string) error {
	switch template {
	case "lib":
		uv := exec.Command("uv", "init", "--lib", name)
		uv.Stdout = os.Stdout
		uv.Stderr = os.Stderr
		if err := uv.Run(); err != nil {
			return err
		}
	case "script":
		// Create script with inline dependencies
		if err := os.MkdirAll(name, 0755); err != nil {
			return err
		}

		script := `# /// script
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
`
		if err := os.WriteFile(filepath.Join(name, "main.py"), []byte(script), 0644); err != nil {
			return err
		}
		fmt.Printf("Created script project: %s\n", name)
		fmt.Printf("Run with: cd %s && uv run main.py\n", name)
		return nil
	default:
		uv := exec.Command("uv", "init", name)
		uv.Stdout = os.Stdout
		uv.Stderr = os.Stderr
		if err := uv.Run(); err != nil {
			return err
		}
	}

	fmt.Printf("\nCreated %s project: %s\n", template, name)
	fmt.Println("Run: uv sync && uv run python -c 'print(\"Hello!\")'")
	return nil
}

// newPythonCleanCmd cleans Python artifacts
func newPythonCleanCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "clean",
		Short: "Clean Python artifacts",
		Long:  `Remove *.pyc, __pycache__, build artifacts, coverage files, etc.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("Cleaning Python artifacts...")

			// Remove __pycache__ directories
			filepath.Walk(".", func(path string, info os.FileInfo, err error) error {
				if err != nil {
					return nil
				}
				if info.IsDir() && info.Name() == "__pycache__" {
					os.RemoveAll(path)
					return filepath.SkipDir
				}
				// Remove .pyc and .pyo files
				if strings.HasSuffix(info.Name(), ".pyc") || strings.HasSuffix(info.Name(), ".pyo") {
					os.Remove(path)
				}
				return nil
			})

			// Remove common build/cache directories
			dirsToRemove := []string{
				"build", "dist", ".eggs",
				".pytest_cache", ".coverage", "htmlcov", ".tox",
				".mypy_cache", ".pytype",
			}

			for _, dir := range dirsToRemove {
				os.RemoveAll(dir)
			}

			// Remove *.egg-info directories
			entries, _ := os.ReadDir(".")
			for _, e := range entries {
				if e.IsDir() && strings.HasSuffix(e.Name(), ".egg-info") {
					os.RemoveAll(e.Name())
				}
			}

			fmt.Println("Done")
			return nil
		},
	}
}

// newPythonVenvCmd creates virtual environment
func newPythonVenvCmd() *cobra.Command {
	var pythonVersion string

	cmd := &cobra.Command{
		Use:   "venv [path]",
		Short: "Create virtual environment with uv",
		RunE: func(cmd *cobra.Command, args []string) error {
			venvPath := ".venv"
			if len(args) > 0 {
				venvPath = args[0]
			}

			uvArgs := []string{"venv", venvPath}
			if pythonVersion != "" {
				uvArgs = append(uvArgs, "--python", pythonVersion)
			}

			uv := exec.Command("uv", uvArgs...)
			uv.Stdout = os.Stdout
			uv.Stderr = os.Stderr
			if err := uv.Run(); err != nil {
				return err
			}

			fmt.Printf("\nCreated virtual environment: %s\n", venvPath)
			fmt.Printf("Activate with: source %s/bin/activate\n", venvPath)
			return nil
		},
	}

	cmd.Flags().StringVarP(&pythonVersion, "python", "p", "", "Python version (e.g., 3.12)")

	return cmd
}

// newPythonTestCmd runs pytest
func newPythonTestCmd() *cobra.Command {
	var verbose, stopFirst bool

	cmd := &cobra.Command{
		Use:   "test [args...]",
		Short: "Run pytest",
		RunE: func(cmd *cobra.Command, args []string) error {
			pytestArgs := []string{"run", "pytest"}
			if verbose {
				pytestArgs = append(pytestArgs, "-v")
			}
			if stopFirst {
				pytestArgs = append(pytestArgs, "-x")
			}
			pytestArgs = append(pytestArgs, args...)

			uv := exec.Command("uv", pytestArgs...)
			uv.Stdout = os.Stdout
			uv.Stderr = os.Stderr
			uv.Stdin = os.Stdin
			return uv.Run()
		},
	}

	cmd.Flags().BoolVarP(&verbose, "verbose", "v", false, "Verbose output")
	cmd.Flags().BoolVarP(&stopFirst, "exit-first", "x", false, "Stop on first failure")

	return cmd
}

// newPythonCoverCmd runs pytest with coverage
func newPythonCoverCmd() *cobra.Command {
	var html bool

	cmd := &cobra.Command{
		Use:   "cover [package]",
		Short: "Run pytest with coverage",
		RunE: func(cmd *cobra.Command, args []string) error {
			pkg := "."
			if len(args) > 0 {
				pkg = args[0]
			}

			pytestArgs := []string{"run", "pytest", "--cov=" + pkg, "--cov-report=term"}
			if html {
				pytestArgs = append(pytestArgs, "--cov-report=html")
			}

			uv := exec.Command("uv", pytestArgs...)
			uv.Stdout = os.Stdout
			uv.Stderr = os.Stderr
			uv.Stdin = os.Stdin
			if err := uv.Run(); err != nil {
				return err
			}

			if html {
				fmt.Println("\nHTML report generated: htmlcov/index.html")
			}

			return nil
		},
	}

	cmd.Flags().BoolVar(&html, "html", false, "Generate HTML coverage report")

	return cmd
}

// newPythonInfoCmd shows Python environment info
func newPythonInfoCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "info",
		Short: "Show Python environment info",
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("Python Environment Info")
			fmt.Println("───────────────────────")

			// uv version
			uv := exec.Command("uv", "--version")
			out, err := uv.Output()
			if err != nil {
				fmt.Println("uv:        not installed")
				fmt.Println("Install:   curl -LsSf https://astral.sh/uv/install.sh | sh")
			} else {
				parts := strings.Fields(string(out))
				if len(parts) >= 2 {
					fmt.Printf("uv:        %s\n", parts[1])
				}
			}

			// Python version
			python := exec.Command("python3", "--version")
			out, err = python.Output()
			if err != nil {
				fmt.Println("Python:    not installed")
			} else {
				parts := strings.Fields(string(out))
				if len(parts) >= 2 {
					fmt.Printf("Python:    %s\n", parts[1])
				}

				// Python location
				which := exec.Command("which", "python3")
				out, _ = which.Output()
				fmt.Printf("Location:  %s", string(out))
			}

			// Virtual environment
			venv := os.Getenv("VIRTUAL_ENV")
			if venv != "" {
				fmt.Printf("Venv:      %s\n", venv)
			} else {
				fmt.Println("Venv:      none active")
			}

			// Check for pyproject.toml
			if _, err := os.Stat("pyproject.toml"); err == nil {
				fmt.Println("Project:   pyproject.toml found")

				// Get package name
				file, _ := os.Open("pyproject.toml")
				if file != nil {
					defer file.Close()
					scanner := bufio.NewScanner(file)
					for scanner.Scan() {
						line := scanner.Text()
						if strings.HasPrefix(line, "name = ") {
							name := strings.Trim(strings.TrimPrefix(line, "name = "), "\"")
							fmt.Printf("Package:   %s\n", name)
							break
						}
					}
				}
			} else {
				fmt.Println("Project:   not in Python project")
			}

			return nil
		},
	}
}

func runPythonStatus() error {
	// Check if uv is installed
	uvInstalled := false
	uvVersion := ""
	uvCmd := exec.Command("uv", "--version")
	if out, err := uvCmd.Output(); err == nil {
		uvInstalled = true
		parts := strings.Fields(string(out))
		if len(parts) >= 2 {
			uvVersion = parts[1]
		}
	}

	// Check Python version
	pythonInstalled := false
	pythonVersion := ""
	pyCmd := exec.Command("python3", "--version")
	if out, err := pyCmd.Output(); err == nil {
		pythonInstalled = true
		parts := strings.Fields(string(out))
		if len(parts) >= 2 {
			pythonVersion = parts[1]
		}
	}

	// Check if in Python project
	_, err := os.Stat("pyproject.toml")
	inProject := err == nil

	// Choose color based on status (uv is the key tool)
	var logoColor string
	if uvInstalled && inProject {
		logoColor = "\033[32m" // Green when uv installed and in project
	} else if uvInstalled {
		logoColor = "\033[34m" // Blue when uv installed but not in project
	} else {
		logoColor = "\033[31m" // Red when uv not installed
	}
	reset := "\033[0m"
	dim := "\033[2m"
	bold := "\033[1m"
	green := "\033[32m"
	red := "\033[31m"
	yellow := "\033[33m"
	blue := "\033[34m"

	fmt.Println()
	fmt.Printf("%s  ██████╗ ██╗   ██╗████████╗██╗  ██╗ ██████╗ ███╗   ██╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗%s\n", logoColor, reset)
	fmt.Printf("%s  ██╔══██╗╚██╗ ██╔╝╚══██╔══╝██║  ██║██╔═══██╗████╗  ██║    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝%s\n", logoColor, reset)
	fmt.Printf("%s  ██████╔╝ ╚████╔╝    ██║   ███████║██║   ██║██╔██╗ ██║       ██║   ██║   ██║██║   ██║██║     ███████╗%s\n", logoColor, reset)
	fmt.Printf("%s  ██╔═══╝   ╚██╔╝     ██║   ██╔══██║██║   ██║██║╚██╗██║       ██║   ██║   ██║██║   ██║██║     ╚════██║%s\n", logoColor, reset)
	fmt.Printf("%s  ██║        ██║      ██║   ██║  ██║╚██████╔╝██║ ╚████║       ██║   ╚██████╔╝╚██████╔╝███████╗███████║%s\n", logoColor, reset)
	fmt.Printf("%s  ╚═╝        ╚═╝      ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝%s\n", logoColor, reset)
	fmt.Println()

	fmt.Printf("  %sCurrent Status%s\n", bold, reset)
	fmt.Printf("  %s───────────────────────────────────────%s\n", dim, reset)

	// Python version
	if pythonInstalled {
		fmt.Printf("    %sPython%s     %s%s%s\n", dim, reset, yellow, pythonVersion, reset)
	} else {
		fmt.Printf("    %sPython%s     %snot installed%s\n", dim, reset, red, reset)
	}

	// uv version
	if uvInstalled {
		fmt.Printf("    %suv%s         %s%s%s\n", dim, reset, blue, uvVersion, reset)
	} else {
		fmt.Printf("    %suv%s         %snot installed%s\n", dim, reset, dim, reset)
	}

	// Virtual environment
	venv := os.Getenv("VIRTUAL_ENV")
	if venv != "" {
		fmt.Printf("    %sVenv%s       %s✓ active%s\n", dim, reset, green, reset)
	} else {
		fmt.Printf("    %sVenv%s       %snone active%s\n", dim, reset, dim, reset)
	}

	// Check for pyproject.toml
	if _, err := os.Stat("pyproject.toml"); err == nil {
		fmt.Printf("    %sProject%s    %s✓ pyproject.toml found%s\n", dim, reset, green, reset)

		// Get package name
		file, _ := os.Open("pyproject.toml")
		if file != nil {
			defer file.Close()
			scanner := bufio.NewScanner(file)
			for scanner.Scan() {
				line := scanner.Text()
				if strings.HasPrefix(line, "name = ") {
					name := strings.Trim(strings.TrimPrefix(line, "name = "), "\"")
					fmt.Printf("    %sPackage%s    %s%s%s\n", dim, reset, yellow, name, reset)
					break
				}
			}
		}
	} else {
		fmt.Printf("    %sProject%s    %snot in Python project%s\n", dim, reset, dim, reset)
	}

	fmt.Println()
	return nil
}
