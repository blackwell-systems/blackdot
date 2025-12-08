// Package cli implements the dotfiles command-line interface using Cobra.
package cli

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

// Tool feature mappings (matches ZSH feature names)
var toolFeatureMap = map[string]string{
	"ssh":    "ssh_tools",
	"aws":    "aws_helpers",
	"cdk":    "cdk_tools",
	"go":     "go_tools",
	"rust":   "rust_tools",
	"python": "python_tools",
}

// checkToolFeature verifies a tool's feature is enabled
// Returns nil if enabled, error if disabled
func checkToolFeature(toolName string) error {
	featureName, ok := toolFeatureMap[toolName]
	if !ok {
		// No feature mapping, allow by default
		return nil
	}

	reg := initRegistry()
	if !reg.Enabled(featureName) {
		return fmt.Errorf("feature '%s' is disabled\nEnable with: dotfiles features enable %s", featureName, featureName)
	}
	return nil
}

// wrapWithFeatureCheck wraps a command's RunE with feature checking
func wrapWithFeatureCheck(toolName string, cmd *cobra.Command) *cobra.Command {
	originalRunE := cmd.RunE
	originalRun := cmd.Run

	if originalRunE != nil {
		cmd.RunE = func(c *cobra.Command, args []string) error {
			if err := checkToolFeature(toolName); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			return originalRunE(c, args)
		}
	} else if originalRun != nil {
		cmd.Run = func(c *cobra.Command, args []string) {
			if err := checkToolFeature(toolName); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			originalRun(c, args)
		}
	}

	// Also wrap all subcommands
	for _, sub := range cmd.Commands() {
		wrapWithFeatureCheck(toolName, sub)
	}

	return cmd
}

// newToolsCmd creates the tools parent command
func newToolsCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "tools",
		Short: "Cross-platform developer tools",
		Long: `Cross-platform developer tools that work on any platform.

These tools provide functionality traditionally only available through
shell scripts, but implemented in Go for portability to Windows and
other platforms.

Available tool categories:
  ssh     - SSH key and connection management
  aws     - AWS profile and authentication management
  cdk     - AWS CDK development helpers
  go      - Go development helpers
  rust    - Rust/Cargo development helpers
  python  - Python/uv development helpers

Each tool category respects its feature flag:
  ssh_tools, aws_helpers, cdk_tools, go_tools, rust_tools, python_tools

Examples:
  dotfiles tools ssh keys           # List SSH keys with fingerprints
  dotfiles tools ssh status         # Show SSH status with ASCII art
  dotfiles tools aws profiles       # List AWS profiles
  dotfiles tools cdk init           # Initialize CDK project
  dotfiles tools go new myproject   # Create new Go project
  dotfiles tools rust lint          # Run cargo check + clippy
  dotfiles tools python new myapp   # Create new Python project`,
	}

	// Add tool subcommands with feature checks
	cmd.AddCommand(
		wrapWithFeatureCheck("ssh", newToolsSSHCmd()),
		wrapWithFeatureCheck("aws", newToolsAWSCmd()),
		wrapWithFeatureCheck("cdk", newToolsCDKCmd()),
		wrapWithFeatureCheck("go", newToolsGoCmd()),
		wrapWithFeatureCheck("rust", newToolsRustCmd()),
		wrapWithFeatureCheck("python", newToolsPythonCmd()),
	)

	return cmd
}
