package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

func newBackupCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "backup",
		Short: "Manage backups",
		Long:  `Create, list, and restore backups of your dotfiles configuration.`,
		Run: func(cmd *cobra.Command, args []string) {
			// Default: create backup
			fmt.Println("Creating backup...")
			fmt.Println("(not yet implemented)")
		},
	}

	cmd.AddCommand(
		&cobra.Command{
			Use:   "create",
			Short: "Create backup of current config",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Creating backup...")
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "list",
			Short: "List all backups",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Backups")
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "restore [backup-id]",
			Short: "Restore specific backup",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Restoring backup...")
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "clean",
			Short: "Remove old backups",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Cleaning old backups...")
				fmt.Println("(not yet implemented)")
			},
		},
	)

	return cmd
}
