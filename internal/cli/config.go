package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

func newConfigCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "config",
		Aliases: []string{"cfg"},
		Short:   "Manage configuration",
		Long: `Manage dotfiles configuration with layered resolution.

Configuration layers (highest to lowest priority):
  1. Environment variables (DOTFILES_*)
  2. Project config (.dotfiles.json in repo)
  3. Machine config (~/.config/dotfiles/machine.json)
  4. User config (~/.config/dotfiles/config.json)
  5. Built-in defaults`,
		Run: func(cmd *cobra.Command, args []string) {
			cmd.Help()
		},
	}

	cmd.AddCommand(
		&cobra.Command{
			Use:   "get <key> [default]",
			Short: "Get config value with layer resolution",
			Args:  cobra.RangeArgs(1, 2),
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Printf("Getting config key: %s\n", args[0])
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "set <layer> <key> <value>",
			Short: "Set config value in specific layer",
			Args:  cobra.ExactArgs(3),
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Printf("Setting %s.%s = %s\n", args[0], args[1], args[2])
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "show <key>",
			Short: "Show value from all layers",
			Args:  cobra.ExactArgs(1),
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Printf("Showing layers for: %s\n", args[0])
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "list",
			Short: "Show configuration layer status",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Configuration Layers")
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "merged",
			Short: "Show merged config from all layers",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Merged Configuration")
				fmt.Println("(not yet implemented)")
			},
		},
	)

	return cmd
}
