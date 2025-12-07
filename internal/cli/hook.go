package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

func newHookCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "hook",
		Aliases: []string{"hooks"},
		Short:   "Manage lifecycle hooks",
		Long: `Manage lifecycle hooks that run at key points in dotfiles operations.

Hook points include:
  - pre/post_install, pre/post_bootstrap
  - pre/post_vault_pull, pre/post_vault_push
  - pre/post_doctor, doctor_check
  - shell_init, shell_exit, directory_change`,
		Run: func(cmd *cobra.Command, args []string) {
			cmd.Help()
		},
	}

	cmd.AddCommand(
		&cobra.Command{
			Use:   "list [point]",
			Short: "List hooks (all or for specific point)",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Hooks")
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "run <point>",
			Short: "Manually run hooks for a point",
			Args:  cobra.ExactArgs(1),
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Printf("Running hooks for: %s\n", args[0])
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "add <point> <script>",
			Short: "Add a hook script",
			Args:  cobra.ExactArgs(2),
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Printf("Adding hook to %s: %s\n", args[0], args[1])
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "remove <point> <name>",
			Short: "Remove a hook",
			Args:  cobra.ExactArgs(2),
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Printf("Removing hook from %s: %s\n", args[0], args[1])
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "points",
			Short: "List all available hook points",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Available hook points:")
				fmt.Println("  pre_install, post_install")
				fmt.Println("  pre_bootstrap, post_bootstrap")
				fmt.Println("  pre_vault_pull, post_vault_pull")
				fmt.Println("  pre_vault_push, post_vault_push")
				fmt.Println("  pre_doctor, post_doctor, doctor_check")
				fmt.Println("  shell_init, shell_exit, directory_change")
			},
		},
	)

	return cmd
}
