package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

// Commands that remain in bash (stubs for help completeness)
// These are complex interactive commands better suited to shell scripting

// newDiffCmd is now in diff.go
// newDoctorCmd is now in doctor.go
// newDriftCmd is now in drift.go
// newEncryptCmd is now in encrypt.go
// newLintCmd is now in lint.go
// newMetricsCmd is now in metrics.go

func newMigrateCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "migrate",
		Short: "Migrate config to v3.0 (INI→JSON, vault v2→v3)",
		Long: `Run migrations to upgrade configuration format and vault schema.

NOTE: This command runs via the bash implementation.
Run 'dotfiles migrate' instead of 'dotfiles-go migrate'.

Migrations are one-time operations for upgrading from v2 to v3.
New installations on v3 do not need to run migrations.`,
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Migration - Use 'dotfiles migrate' (bash version)")
			fmt.Println("")
			fmt.Println("Migrations are one-time operations for upgrading to v3.")
			fmt.Println("Run the bash version: dotfiles migrate")
		},
	}

	cmd.AddCommand(
		&cobra.Command{
			Use:   "config",
			Short: "Migrate config format (INI→JSON)",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Run: dotfiles migrate config")
			},
		},
		&cobra.Command{
			Use:   "vault-schema",
			Short: "Migrate vault schema (v2→v3)",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Run: dotfiles migrate vault-schema")
			},
		},
	)

	return cmd
}

// newPackagesCmd is now in packages.go

func newSetupCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "setup",
		Short: "Interactive setup wizard (1190-line bash wizard)",
		Long: `Run the interactive setup wizard to configure dotfiles.

NOTE: This command runs via the bash implementation.
Run 'dotfiles setup' instead of 'dotfiles-go setup'.

The setup wizard is a 7-step interactive process:
  1. Workspace - Configure workspace directory
  2. Symlinks  - Link shell config files
  3. Packages  - Install Homebrew packages
  4. Vault     - Configure secret backend
  5. Secrets   - Manage SSH/AWS/Git configs
  6. Claude    - AI assistant integration
  7. Templates - Machine-specific configs

Progress is saved automatically. Resume anytime with 'dotfiles setup'.`,
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Setup Wizard - Use 'dotfiles setup' (bash version)")
			fmt.Println("")
			fmt.Println("The setup wizard is a 7-step interactive process.")
			fmt.Println("Run the bash version: dotfiles setup")
		},
	}
}

func newSyncCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "sync",
		Short: "Bidirectional vault sync (514-line bash sync)",
		Long: `Synchronize secrets between local machine and vault.

NOTE: This command runs via the bash implementation.
Run 'dotfiles sync' instead of 'dotfiles-go sync'.

Uses smart detection to determine whether to push or pull:
  - If local is newer, pushes to vault
  - If vault is newer, pulls to local
  - Handles conflicts with user prompts

Options (use with bash version):
  --dry-run, -n      Preview changes without making them
  --force-local, -l  Push all local changes to vault
  --force-vault, -v  Pull all vault content to local
  --all, -a          Sync all syncable items`,
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Sync - Use 'dotfiles sync' (bash version)")
			fmt.Println("")
			fmt.Println("Bidirectional vault sync with smart direction detection.")
			fmt.Println("Run the bash version: dotfiles sync")
		},
	}
}

// newUninstallCmd is now in uninstall.go
