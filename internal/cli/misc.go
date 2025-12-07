package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

// These are stub commands for CLI commands that exist in bin/dotfiles-*
// They will be implemented as the migration progresses

func newDiffCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "diff",
		Short: "Preview changes before sync/restore",
		Long:  `Show differences between local files and vault state.`,
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Diff Preview")
			fmt.Println("(not yet implemented)")
		},
	}
}

func newDriftCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "drift",
		Short: "Compare local files vs vault",
		Long:  `Detect configuration drift between local files and vault state.`,
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Drift Detection")
			fmt.Println("(not yet implemented)")
		},
	}
}

func newEncryptCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "encrypt",
		Short: "Encrypt sensitive files with age",
		Long:  `Encrypt files using age encryption for secure storage.`,
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Encryption")
			fmt.Println("(not yet implemented)")
		},
	}
}

// newLintCmd is now in lint.go
// newMetricsCmd is now in metrics.go

func newMigrateCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "migrate",
		Short: "Migrate config to v3.0 (INI→JSON, vault v2→v3)",
		Long:  `Run migrations to upgrade configuration format and vault schema.`,
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Migration")
			fmt.Println("(not yet implemented)")
		},
	}

	cmd.AddCommand(
		&cobra.Command{
			Use:   "config",
			Short: "Migrate config format",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Config Migration")
				fmt.Println("(not yet implemented)")
			},
		},
		&cobra.Command{
			Use:   "vault-schema",
			Short: "Migrate vault schema",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Vault Schema Migration")
				fmt.Println("(not yet implemented)")
			},
		},
	)

	return cmd
}

// newPackagesCmd is now in packages.go

func newSetupCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "setup",
		Short: "Interactive setup wizard (recommended)",
		Long: `Run the interactive setup wizard to configure dotfiles.

This is the recommended way to set up dotfiles on a new machine.
It guides you through:
  - Feature selection
  - Vault backend setup
  - Template configuration
  - Symlink creation`,
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Setup Wizard")
			fmt.Println("(not yet implemented)")
		},
	}
}

func newSyncCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "sync",
		Short: "Bidirectional vault sync (smart push/pull)",
		Long: `Synchronize secrets between local machine and vault.

Uses smart detection to determine whether to push or pull:
  - If local is newer, pushes to vault
  - If vault is newer, pulls to local
  - Handles conflicts with user prompts`,
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Sync")
			fmt.Println("(not yet implemented)")
		},
	}
}

// newUninstallCmd is now in uninstall.go
