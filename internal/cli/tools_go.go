// Package cli implements the blackdot command-line interface using Cobra.
package cli

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/spf13/cobra"
)

// newToolsGoCmd creates the go tools subcommand
func newToolsGoCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "go",
		Short: "Go development helpers",
		Long: `Go development helper tools.

Cross-platform Go utilities for project creation, testing, and building.

Commands:
  new       - Create new Go project with standard structure
  init      - Initialize Go module in current directory
  test      - Run tests with options
  cover     - Run tests with coverage report
  lint      - Run go vet and golangci-lint
  outdated  - Show outdated dependencies
  update    - Update all dependencies
  build-all - Cross-compile for all platforms
  bench     - Run benchmarks
  info      - Show Go environment info`,
	}

	cmd.AddCommand(
		newGoNewCmd(),
		newGoInitCmd(),
		newGoTestCmd(),
		newGoCoverCmd(),
		newGoLintCmd(),
		newGoOutdatedCmd(),
		newGoUpdateCmd(),
		newGoBuildAllCmd(),
		newGoBenchCmd(),
		newGoInfoCmd(),
	)

	return cmd
}

// newGoNewCmd creates new Go project
func newGoNewCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "new <name>",
		Short: "Create new Go project with standard structure",
		Long: `Create a new Go project with common directory structure.

Creates:
  <name>/
    cmd/main.go    - Application entrypoint
    internal/      - Private application code
    pkg/           - Public library code
    go.mod         - Module definition`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return runGoNew(args[0])
		},
	}
}

func runGoNew(name string) error {
	// Create directories
	dirs := []string{
		filepath.Join(name, "cmd"),
		filepath.Join(name, "internal"),
		filepath.Join(name, "pkg"),
	}

	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("failed to create directory %s: %w", dir, err)
		}
	}

	// Initialize module
	goModInit := exec.Command("go", "mod", "init", name)
	goModInit.Dir = name
	if err := goModInit.Run(); err != nil {
		return fmt.Errorf("failed to init module: %w", err)
	}

	// Create main.go
	mainGo := `package main

import "fmt"

func main() {
	fmt.Println("Hello, World!")
}
`
	mainPath := filepath.Join(name, "cmd", "main.go")
	if err := os.WriteFile(mainPath, []byte(mainGo), 0644); err != nil {
		return fmt.Errorf("failed to create main.go: %w", err)
	}

	fmt.Printf("Created Go project: %s\n\n", name)
	fmt.Println("Structure:")
	fmt.Println("  cmd/       - Application entrypoints")
	fmt.Println("  internal/  - Private application code")
	fmt.Println("  pkg/       - Public library code")
	fmt.Println()
	fmt.Println("Run: go run ./cmd")

	return nil
}

// newGoInitCmd initializes Go module
func newGoInitCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "init [name]",
		Short: "Initialize Go module in current directory",
		Long:  `Initialize a Go module. If no name provided, uses directory name.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			name := ""
			if len(args) > 0 {
				name = args[0]
			} else {
				cwd, _ := os.Getwd()
				name = filepath.Base(cwd)
				fmt.Printf("Using directory name as module: %s\n", name)
			}

			goModInit := exec.Command("go", "mod", "init", name)
			goModInit.Stdout = os.Stdout
			goModInit.Stderr = os.Stderr
			if err := goModInit.Run(); err != nil {
				return fmt.Errorf("failed to init module: %w", err)
			}

			fmt.Printf("\nInitialized Go module: %s\n", name)
			return nil
		},
	}
}

// newGoTestCmd runs tests
func newGoTestCmd() *cobra.Command {
	var verbose, race, cover bool

	cmd := &cobra.Command{
		Use:   "test [packages]",
		Short: "Run Go tests",
		Long:  `Run Go tests with common options.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			testArgs := []string{"test"}
			if verbose {
				testArgs = append(testArgs, "-v")
			}
			if race {
				testArgs = append(testArgs, "-race")
			}
			if cover {
				testArgs = append(testArgs, "-cover")
			}

			if len(args) > 0 {
				testArgs = append(testArgs, args...)
			} else {
				testArgs = append(testArgs, "./...")
			}

			goTest := exec.Command("go", testArgs...)
			goTest.Stdout = os.Stdout
			goTest.Stderr = os.Stderr
			return goTest.Run()
		},
	}

	cmd.Flags().BoolVarP(&verbose, "verbose", "v", false, "Verbose output")
	cmd.Flags().BoolVarP(&race, "race", "r", false, "Enable race detector")
	cmd.Flags().BoolVarP(&cover, "cover", "c", false, "Enable coverage")

	return cmd
}

// newGoCoverCmd runs tests with coverage
func newGoCoverCmd() *cobra.Command {
	var html bool

	cmd := &cobra.Command{
		Use:   "cover [packages]",
		Short: "Run tests with coverage report",
		Long:  `Run Go tests with coverage and optionally open HTML report.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			pkg := "./..."
			if len(args) > 0 {
				pkg = args[0]
			}

			coverFile := "/tmp/coverage.out"

			fmt.Println("Running tests with coverage...")
			goTest := exec.Command("go", "test", "-coverprofile="+coverFile, pkg)
			goTest.Stdout = os.Stdout
			goTest.Stderr = os.Stderr
			if err := goTest.Run(); err != nil {
				return err
			}

			fmt.Println("\nCoverage summary:")
			goCover := exec.Command("go", "tool", "cover", "-func="+coverFile)
			goCover.Stdout = os.Stdout
			goCover.Stderr = os.Stderr
			goCover.Run()

			if html {
				fmt.Println("\nOpening coverage in browser...")
				goCoverHTML := exec.Command("go", "tool", "cover", "-html="+coverFile)
				goCoverHTML.Run()
			}

			return nil
		},
	}

	cmd.Flags().BoolVar(&html, "html", false, "Open HTML coverage report")

	return cmd
}

// newGoLintCmd runs linters
func newGoLintCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "lint",
		Short: "Run go vet and golangci-lint",
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("Running go vet...")
			goVet := exec.Command("go", "vet", "./...")
			goVet.Stdout = os.Stdout
			goVet.Stderr = os.Stderr
			if err := goVet.Run(); err != nil {
				return err
			}

			fmt.Println()

			// Check for golangci-lint
			if _, err := exec.LookPath("golangci-lint"); err == nil {
				fmt.Println("Running golangci-lint...")
				lint := exec.Command("golangci-lint", "run")
				lint.Stdout = os.Stdout
				lint.Stderr = os.Stderr
				return lint.Run()
			}

			// Check for staticcheck
			if _, err := exec.LookPath("staticcheck"); err == nil {
				fmt.Println("Running staticcheck...")
				staticcheck := exec.Command("staticcheck", "./...")
				staticcheck.Stdout = os.Stdout
				staticcheck.Stderr = os.Stderr
				return staticcheck.Run()
			}

			fmt.Println("No linter found. Install golangci-lint:")
			fmt.Println("  brew install golangci-lint")
			fmt.Println("  # or")
			fmt.Println("  go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest")

			return nil
		},
	}
}

// newGoOutdatedCmd shows outdated dependencies
func newGoOutdatedCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "outdated",
		Short: "Show outdated dependencies",
		RunE: func(cmd *cobra.Command, args []string) error {
			// Check for go-mod-outdated
			if _, err := exec.LookPath("go-mod-outdated"); err != nil {
				fmt.Println("Installing go-mod-outdated...")
				install := exec.Command("go", "install", "github.com/psampaz/go-mod-outdated@latest")
				install.Stdout = os.Stdout
				install.Stderr = os.Stderr
				if err := install.Run(); err != nil {
					return fmt.Errorf("failed to install go-mod-outdated: %w", err)
				}
			}

			// Run go list piped to go-mod-outdated
			goList := exec.Command("go", "list", "-u", "-m", "-json", "all")
			outdated := exec.Command("go-mod-outdated", "-direct")

			pipe, _ := goList.StdoutPipe()
			outdated.Stdin = pipe
			outdated.Stdout = os.Stdout
			outdated.Stderr = os.Stderr

			goList.Start()
			outdated.Run()
			goList.Wait()

			return nil
		},
	}
}

// newGoUpdateCmd updates dependencies
func newGoUpdateCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "update",
		Short: "Update all dependencies",
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("Updating all dependencies...")

			goGet := exec.Command("go", "get", "-u", "./...")
			goGet.Stdout = os.Stdout
			goGet.Stderr = os.Stderr
			if err := goGet.Run(); err != nil {
				return err
			}

			goMod := exec.Command("go", "mod", "tidy")
			goMod.Stdout = os.Stdout
			goMod.Stderr = os.Stderr
			if err := goMod.Run(); err != nil {
				return err
			}

			fmt.Println("\nDependencies updated")
			return nil
		},
	}
}

// newGoBuildAllCmd cross-compiles for all platforms
func newGoBuildAllCmd() *cobra.Command {
	var outputDir string

	cmd := &cobra.Command{
		Use:   "build-all [name]",
		Short: "Cross-compile for all platforms",
		Long: `Build binaries for multiple platforms:
  - darwin/amd64 (macOS Intel)
  - darwin/arm64 (macOS Apple Silicon)
  - linux/amd64
  - linux/arm64
  - windows/amd64`,
		RunE: func(cmd *cobra.Command, args []string) error {
			name := ""
			if len(args) > 0 {
				name = args[0]
			} else {
				cwd, _ := os.Getwd()
				name = filepath.Base(cwd)
			}

			os.MkdirAll(outputDir, 0755)

			platforms := []struct {
				goos   string
				goarch string
				ext    string
			}{
				{"darwin", "amd64", ""},
				{"darwin", "arm64", ""},
				{"linux", "amd64", ""},
				{"linux", "arm64", ""},
				{"windows", "amd64", ".exe"},
			}

			fmt.Println("Building for multiple platforms...")

			for _, p := range platforms {
				output := filepath.Join(outputDir, fmt.Sprintf("%s-%s-%s%s", name, p.goos, p.goarch, p.ext))
				fmt.Printf("  Building %s/%s...\n", p.goos, p.goarch)

				goBuild := exec.Command("go", "build", "-o", output, "./...")
				goBuild.Env = append(os.Environ(), "GOOS="+p.goos, "GOARCH="+p.goarch)
				if err := goBuild.Run(); err != nil {
					fmt.Printf("    Failed: %v\n", err)
				}
			}

			fmt.Println("\nBuilt binaries:")
			entries, _ := os.ReadDir(outputDir)
			for _, e := range entries {
				info, _ := e.Info()
				fmt.Printf("  %s (%d bytes)\n", e.Name(), info.Size())
			}

			return nil
		},
	}

	cmd.Flags().StringVarP(&outputDir, "output", "o", "dist", "Output directory")

	return cmd
}

// newGoBenchCmd runs benchmarks
func newGoBenchCmd() *cobra.Command {
	var count int

	cmd := &cobra.Command{
		Use:   "bench [pattern]",
		Short: "Run benchmarks",
		RunE: func(cmd *cobra.Command, args []string) error {
			pattern := "."
			if len(args) > 0 {
				pattern = args[0]
			}

			fmt.Printf("Running benchmarks (count=%d)...\n", count)

			goBench := exec.Command("go", "test",
				fmt.Sprintf("-bench=%s", pattern),
				"-benchmem",
				fmt.Sprintf("-count=%d", count),
				"./...")
			goBench.Stdout = os.Stdout
			goBench.Stderr = os.Stderr
			return goBench.Run()
		},
	}

	cmd.Flags().IntVarP(&count, "count", "c", 5, "Number of iterations")

	return cmd
}

// newGoInfoCmd shows Go environment info
func newGoInfoCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "info",
		Short: "Show Go environment info",
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("Go Environment Info")
			fmt.Println("───────────────────────")

			// Go version
			goVersion := exec.Command("go", "version")
			out, err := goVersion.Output()
			if err != nil {
				fmt.Println("Go:        not installed")
			} else {
				parts := strings.Fields(string(out))
				if len(parts) >= 3 {
					fmt.Printf("Go:        %s\n", parts[2])
				}
			}

			fmt.Printf("OS/Arch:   %s/%s\n", runtime.GOOS, runtime.GOARCH)

			// GOPATH
			goPath := os.Getenv("GOPATH")
			if goPath == "" {
				home, _ := os.UserHomeDir()
				goPath = filepath.Join(home, "go")
			}
			fmt.Printf("GOPATH:    %s\n", goPath)

			// Check for go.mod
			if _, err := os.Stat("go.mod"); err == nil {
				fmt.Println("Project:   go.mod found")

				// Get module name
				modData, _ := os.ReadFile("go.mod")
				lines := strings.Split(string(modData), "\n")
				for _, line := range lines {
					if strings.HasPrefix(line, "module ") {
						fmt.Printf("Module:    %s\n", strings.TrimPrefix(line, "module "))
						break
					}
					if strings.HasPrefix(line, "go ") {
						fmt.Printf("Requires:  %s\n", line)
					}
				}
			} else {
				fmt.Println("Project:   not in Go project")
			}

			// Check for linters
			if _, err := exec.LookPath("golangci-lint"); err == nil {
				fmt.Println("Linter:    golangci-lint available")
			}

			return nil
		},
	}
}
