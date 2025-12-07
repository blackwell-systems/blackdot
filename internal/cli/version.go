package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

func newVersionCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "version",
		Short: "Print version information",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Printf("dotfiles %s\n", versionStr)
			if verbose {
				fmt.Printf("  commit: %s\n", commitStr)
				fmt.Printf("  built:  %s\n", dateStr)
			}
		},
	}
}
