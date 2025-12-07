package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

func newFeaturesCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "features",
		Aliases: []string{"feature", "feat"},
		Short:   "Manage dotfiles features",
		Long: `Manage dotfiles features - enable, disable, and query feature status.

Features control which functionality is available in your dotfiles setup.
They can have dependencies on other features and are organized into
categories: core, optional, and integration.`,
		Run: func(cmd *cobra.Command, args []string) {
			// Default: list all features
			listFeatures(cmd, args)
		},
	}

	// Subcommands
	cmd.AddCommand(
		newFeaturesListCmd(),
		newFeaturesEnableCmd(),
		newFeaturesDisableCmd(),
		newFeaturesPresetCmd(),
		newFeaturesCheckCmd(),
		newFeaturesShowCmd(),
	)

	return cmd
}

func newFeaturesListCmd() *cobra.Command {
	var category string
	var jsonOutput bool

	cmd := &cobra.Command{
		Use:   "list [category]",
		Short: "List all features",
		Long:  `List all features with their status, category, and dependencies.`,
		Run: func(cmd *cobra.Command, args []string) {
			if len(args) > 0 {
				category = args[0]
			}
			listFeatures(cmd, args)
		},
	}

	cmd.Flags().StringVarP(&category, "category", "c", "", "filter by category (core, optional, integration)")
	cmd.Flags().BoolVar(&jsonOutput, "json", false, "output as JSON")

	return cmd
}

func newFeaturesEnableCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "enable <feature>",
		Short: "Enable a feature",
		Long: `Enable a feature and its dependencies.

If the feature has dependencies, they will be enabled automatically.
Use --force to skip dependency checking.`,
		Args: cobra.ExactArgs(1),
		Run: func(cmd *cobra.Command, args []string) {
			// TODO: Implement with feature package
			fmt.Printf("Enabling feature: %s\n", args[0])
			fmt.Println("(not yet implemented)")
		},
	}
}

func newFeaturesDisableCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "disable <feature>",
		Short: "Disable a feature",
		Long: `Disable a feature.

Core features cannot be disabled. If other features depend on this feature,
you will be warned (use --force to disable anyway).`,
		Args: cobra.ExactArgs(1),
		Run: func(cmd *cobra.Command, args []string) {
			// TODO: Implement with feature package
			fmt.Printf("Disabling feature: %s\n", args[0])
			fmt.Println("(not yet implemented)")
		},
	}
}

func newFeaturesPresetCmd() *cobra.Command {
	var listPresets bool

	cmd := &cobra.Command{
		Use:   "preset [name]",
		Short: "Apply a feature preset",
		Long: `Apply a preset to enable/disable multiple features at once.

Available presets:
  minimal   - Core features only
  developer - Core + common development tools
  claude    - Developer + Claude AI integration
  full      - All features enabled`,
		Run: func(cmd *cobra.Command, args []string) {
			if listPresets || len(args) == 0 {
				fmt.Println("Available presets:")
				fmt.Println("  minimal   - Core features only")
				fmt.Println("  developer - Core + common development tools")
				fmt.Println("  claude    - Developer + Claude AI integration")
				fmt.Println("  full      - All features enabled")
				return
			}
			// TODO: Implement with feature package
			fmt.Printf("Applying preset: %s\n", args[0])
			fmt.Println("(not yet implemented)")
		},
	}

	cmd.Flags().BoolVar(&listPresets, "list", false, "list available presets")

	return cmd
}

func newFeaturesCheckCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "check <feature>",
		Short: "Check if a feature is enabled",
		Long:  `Check if a feature is enabled. Returns exit code 0 if enabled, 1 if disabled.`,
		Args:  cobra.ExactArgs(1),
		Run: func(cmd *cobra.Command, args []string) {
			// TODO: Implement with feature package
			fmt.Printf("Checking feature: %s\n", args[0])
			fmt.Println("(not yet implemented)")
		},
	}
}

func newFeaturesShowCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "show <feature>",
		Short: "Show detailed feature information",
		Long:  `Show detailed information about a feature including dependencies and dependents.`,
		Args:  cobra.ExactArgs(1),
		Run: func(cmd *cobra.Command, args []string) {
			// TODO: Implement with feature package
			fmt.Printf("Feature: %s\n", args[0])
			fmt.Println("(not yet implemented)")
		},
	}
}

func listFeatures(cmd *cobra.Command, args []string) {
	// TODO: Implement with feature package
	fmt.Println("Feature Registry")
	fmt.Println("================")
	fmt.Println()
	fmt.Println("(not yet implemented - will read from feature package)")
}
