// Package cli implements the dotfiles command-line interface using Cobra.
package cli

import (
	"github.com/spf13/cobra"
)

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

Examples:
  dotfiles tools ssh keys           # List SSH keys with fingerprints
  dotfiles tools ssh status         # Show SSH status with ASCII art
  dotfiles tools aws profiles       # List AWS profiles
  dotfiles tools cdk init           # Initialize CDK project
  dotfiles tools go new myproject   # Create new Go project
  dotfiles tools rust lint          # Run cargo check + clippy
  dotfiles tools python new myapp   # Create new Python project`,
	}

	// Add tool subcommands
	cmd.AddCommand(
		newToolsSSHCmd(),
		newToolsAWSCmd(),
		newToolsCDKCmd(),
		newToolsGoCmd(),
		newToolsRustCmd(),
		newToolsPythonCmd(),
	)

	return cmd
}
