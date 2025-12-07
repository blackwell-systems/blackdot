package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

func newTemplateCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "template",
		Aliases: []string{"tmpl"},
		Short:   "Manage machine-specific templates",
		Long: `Manage machine-specific configuration templates.

Templates use a Handlebars-like syntax:
  {{ variable }}     - Simple substitution
  {{#if cond}}...{{/if}}  - Conditional blocks
  {{#each arr}}...{{/each}} - Iteration
  {{ var | filter }} - Filter pipes`,
		Run: func(cmd *cobra.Command, args []string) {
			cmd.Help()
		},
	}

	cmd.AddCommand(
		&cobra.Command{
			Use:   "init",
			Short: "Interactive setup (creates _variables.local.sh)",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Template Init")
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "render [file]",
			Short: "Render templates to generated/",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Rendering templates...")
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "link",
			Short: "Create symlinks from generated/ to destinations",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Creating symlinks...")
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "diff",
			Short: "Show differences from rendered",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Template Diff")
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "vars",
			Short: "List all template variables and values",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Template Variables")
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "list",
			Short: "Show available templates and status",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Available Templates")
				fmt.Println("(not yet implemented)")
			},
		},
	)

	return cmd
}
