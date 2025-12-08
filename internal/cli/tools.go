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

Examples:
  dotfiles tools ssh keys         # List SSH keys with fingerprints
  dotfiles tools ssh gen github   # Generate new ED25519 key
  dotfiles tools ssh list         # List configured SSH hosts
  dotfiles tools ssh agent        # Show SSH agent status`,
	}

	// Add tool subcommands
	cmd.AddCommand(newToolsSSHCmd())

	return cmd
}
