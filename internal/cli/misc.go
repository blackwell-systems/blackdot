package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

// Commands that remain in bash (stubs for help completeness)
// These are complex interactive commands better suited to shell scripting

// Implemented commands (in their own files):
// newDiffCmd is now in diff.go
// newDoctorCmd is now in doctor.go
// newDriftCmd is now in drift.go
// newEncryptCmd is now in encrypt.go
// newLintCmd is now in lint.go
// newMetricsCmd is now in metrics.go
// newPackagesCmd is now in packages.go
// newSyncCmd is now in sync.go
// newUninstallCmd is now in uninstall.go

// Dropped from Go CLI:
// migrate - one-time v2→v3 migration, users on v3 don't need it

func newSetupCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "setup",
		Short: "Interactive setup wizard (runs bash version)",
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
