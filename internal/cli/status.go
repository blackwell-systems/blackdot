package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

func newStatusCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "status",
		Aliases: []string{"s"},
		Short:   "Show quick status dashboard",
		Long:    `Display a quick visual dashboard of dotfiles status.`,
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Dotfiles Status")
			fmt.Println("===============")
			fmt.Println()
			fmt.Println("(not yet implemented)")
		},
	}

	return cmd
}
