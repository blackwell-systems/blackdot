// Package cli implements the blackdot command-line interface using Cobra.
package cli

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"
)

// newToolsRustCmd creates the rust tools subcommand
func newToolsRustCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "rust",
		Short: "Rust development helpers",
		Long: `Rust development helper tools.

Cross-platform Rust/Cargo utilities for project creation, testing, and building.

Commands:
  new       - Create new Rust project
  update    - Update Rust toolchain
  switch    - Switch Rust toolchain
  lint      - Run cargo check + clippy
  fix       - Format and auto-fix with clippy
  outdated  - Show outdated dependencies
  expand    - Expand macros (for debugging)
  info      - Show Rust environment info`,
	}

	cmd.AddCommand(
		newRustNewCmd(),
		newRustUpdateCmd(),
		newRustSwitchCmd(),
		newRustLintCmd(),
		newRustFixCmd(),
		newRustOutdatedCmd(),
		newRustExpandCmd(),
		newRustInfoCmd(),
	)

	return cmd
}

// newRustNewCmd creates new Rust project
func newRustNewCmd() *cobra.Command {
	var lib bool

	cmd := &cobra.Command{
		Use:   "new <name>",
		Short: "Create new Rust project",
		Long:  `Create a new Rust project using cargo new.`,
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			name := args[0]

			cargoArgs := []string{"new"}
			if lib {
				cargoArgs = append(cargoArgs, "--lib")
			}
			cargoArgs = append(cargoArgs, name)

			cargo := exec.Command("cargo", cargoArgs...)
			cargo.Stdout = os.Stdout
			cargo.Stderr = os.Stderr
			if err := cargo.Run(); err != nil {
				return err
			}

			projectType := "bin"
			if lib {
				projectType = "lib"
			}
			fmt.Printf("\nCreated %s project: %s\n", projectType, name)
			fmt.Println("Run: cargo run")

			return nil
		},
	}

	cmd.Flags().BoolVar(&lib, "lib", false, "Create library project")

	return cmd
}

// newRustUpdateCmd updates Rust toolchain
func newRustUpdateCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "update",
		Short: "Update Rust toolchain",
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("Updating Rust toolchain...")

			rustup := exec.Command("rustup", "update")
			rustup.Stdout = os.Stdout
			rustup.Stderr = os.Stderr
			if err := rustup.Run(); err != nil {
				return err
			}

			fmt.Println("\nCurrent toolchain:")
			show := exec.Command("rustup", "show", "active-toolchain")
			show.Stdout = os.Stdout
			return show.Run()
		},
	}
}

// newRustSwitchCmd switches Rust toolchain
func newRustSwitchCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "switch <toolchain>",
		Short: "Switch Rust toolchain",
		Long: `Switch the default Rust toolchain.

Common toolchains: stable, beta, nightly`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 {
				fmt.Println("Available toolchains:")
				list := exec.Command("rustup", "toolchain", "list")
				list.Stdout = os.Stdout
				list.Stderr = os.Stderr
				return list.Run()
			}

			toolchain := args[0]
			rustup := exec.Command("rustup", "default", toolchain)
			rustup.Stdout = os.Stdout
			rustup.Stderr = os.Stderr
			if err := rustup.Run(); err != nil {
				return err
			}

			fmt.Printf("\nSwitched to: ")
			show := exec.Command("rustup", "show", "active-toolchain")
			show.Stdout = os.Stdout
			return show.Run()
		},
	}
}

// newRustLintCmd runs linters
func newRustLintCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "lint",
		Short: "Run cargo check + clippy",
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("Running cargo check...")
			check := exec.Command("cargo", "check")
			check.Stdout = os.Stdout
			check.Stderr = os.Stderr
			if err := check.Run(); err != nil {
				return err
			}

			fmt.Println("\nRunning clippy...")
			clippy := exec.Command("cargo", "clippy", "--", "-D", "warnings")
			clippy.Stdout = os.Stdout
			clippy.Stderr = os.Stderr
			return clippy.Run()
		},
	}
}

// newRustFixCmd formats and fixes code
func newRustFixCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "fix",
		Short: "Format and auto-fix with clippy",
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("Formatting code...")
			cargoFmt := exec.Command("cargo", "fmt")
			cargoFmt.Stdout = os.Stdout
			cargoFmt.Stderr = os.Stderr
			if err := cargoFmt.Run(); err != nil {
				return err
			}

			fmt.Println("\nRunning clippy with auto-fix...")
			clippy := exec.Command("cargo", "clippy", "--fix", "--allow-dirty", "--allow-staged")
			clippy.Stdout = os.Stdout
			clippy.Stderr = os.Stderr
			return clippy.Run()
		},
	}
}

// newRustOutdatedCmd shows outdated dependencies
func newRustOutdatedCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "outdated",
		Short: "Show outdated dependencies",
		RunE: func(cmd *cobra.Command, args []string) error {
			// Check if cargo-outdated is installed
			if _, err := exec.LookPath("cargo-outdated"); err != nil {
				fmt.Println("Installing cargo-outdated...")
				install := exec.Command("cargo", "install", "cargo-outdated")
				install.Stdout = os.Stdout
				install.Stderr = os.Stderr
				if err := install.Run(); err != nil {
					return fmt.Errorf("failed to install cargo-outdated: %w", err)
				}
			}

			outdated := exec.Command("cargo", "outdated")
			outdated.Stdout = os.Stdout
			outdated.Stderr = os.Stderr
			return outdated.Run()
		},
	}
}

// newRustExpandCmd expands macros
func newRustExpandCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "expand [item]",
		Short: "Expand macros (for debugging)",
		RunE: func(cmd *cobra.Command, args []string) error {
			// Check if cargo-expand is installed
			if _, err := exec.LookPath("cargo-expand"); err != nil {
				fmt.Println("Installing cargo-expand...")
				install := exec.Command("cargo", "install", "cargo-expand")
				install.Stdout = os.Stdout
				install.Stderr = os.Stderr
				if err := install.Run(); err != nil {
					return fmt.Errorf("failed to install cargo-expand: %w", err)
				}
			}

			expandArgs := []string{"expand"}
			if len(args) > 0 {
				expandArgs = append(expandArgs, args[0])
			}

			expand := exec.Command("cargo", expandArgs...)
			expand.Stdout = os.Stdout
			expand.Stderr = os.Stderr
			return expand.Run()
		},
	}
}

// newRustInfoCmd shows Rust environment info
func newRustInfoCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "info",
		Short: "Show Rust environment info",
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("Rust Environment Info")
			fmt.Println("───────────────────────")

			// Rust version
			rustc := exec.Command("rustc", "--version")
			out, err := rustc.Output()
			if err != nil {
				fmt.Println("Rust:      not installed")
				fmt.Println("Install:   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh")
				return nil
			}
			parts := strings.Fields(string(out))
			if len(parts) >= 2 {
				fmt.Printf("Rust:      %s\n", parts[1])
			}

			// Toolchain
			toolchain := exec.Command("rustup", "show", "active-toolchain")
			out, _ = toolchain.Output()
			tc := strings.Fields(string(out))
			if len(tc) > 0 {
				fmt.Printf("Toolchain: %s\n", tc[0])
			}

			// Check for Cargo.toml
			if _, err := os.Stat("Cargo.toml"); err == nil {
				fmt.Println("Project:   Cargo.toml found")

				// Get package name
				file, _ := os.Open("Cargo.toml")
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
				fmt.Println("Project:   not in Rust project")
			}

			return nil
		},
	}
}
