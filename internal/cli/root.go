// Package cli implements the blackdot command-line interface using Cobra.
//
// Commands mirror the existing Zsh implementation in bin/blackdot-*
// to ensure behavioral compatibility during migration.
package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

var (
	// Version info set from main
	versionStr = "dev"
	commitStr  = "none"
	dateStr    = "unknown"

	// Global flags
	verbose bool
	force   bool

	// dotfilesDir is resolved at init
	dotfilesDir string
)

// rootCmd represents the base command
var rootCmd = &cobra.Command{
	Use:   "blackdot",
	Short: "Manage your configuration",
	Long: `blackdot - A feature-rich configuration management system.

This CLI provides commands for managing shell configuration, secrets,
templates, and system health. Features can be enabled/disabled to
customize the available functionality.

Run 'blackdot help' for detailed command information.`,
	SilenceUsage:  true,
	SilenceErrors: true,
	// Show help when called without subcommand
	Run: func(cmd *cobra.Command, args []string) {
		customHelpFunc(cmd, args)
	},
}

// SetVersionInfo sets version information from build flags
func SetVersionInfo(version, commit, date string) {
	versionStr = version
	commitStr = commit
	dateStr = date
}

// Execute runs the root command
func Execute() error {
	err := rootCmd.Execute()
	if err != nil {
		// Check if it's an unknown command error vs execution error
		errStr := err.Error()
		if strings.Contains(errStr, "unknown command") ||
			strings.Contains(errStr, "unknown flag") ||
			strings.Contains(errStr, "unknown shorthand flag") {
			// Unknown command/flag - show help hint
			Red.Fprintf(os.Stderr, "Error: ")
			fmt.Fprintln(os.Stderr, errStr)
			Dim.Fprintln(os.Stderr, "Run 'blackdot help' for usage")
		} else {
			// Execution error - show actual error message
			Red.Fprintf(os.Stderr, "[ERROR] ")
			fmt.Fprintln(os.Stderr, errStr)
		}
	}
	return err
}

func init() {
	cobra.OnInitialize(initConfig)

	// Use custom help function matching ZSH style
	rootCmd.SetHelpFunc(customHelpFunc)

	// Global flags available to all commands
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "verbose output")
	rootCmd.PersistentFlags().BoolVar(&force, "force", false, "bypass feature checks")

	// Add subcommands
	rootCmd.AddCommand(
		newVersionCmd(),
		newFeaturesCmd(),
		newConfigCmd(),
		newDoctorCmd(),
		newStatusCmd(),
		newVaultCmd(),
		newSecretsCmd(), // Alias for vault
		newTemplateCmd(),
		newBackupCmd(),
		newRollbackCmd(),
		newHookCmd(),
		// Additional commands from bin/
		newDiffCmd(),
		newDriftCmd(),
		newEncryptCmd(),
		newLintCmd(),
		newMetricsCmd(),
		newPackagesCmd(),
		newSetupCmd(),
		newSyncCmd(),
		newUninstallCmd(),
		// Cross-platform developer tools
		newToolsCmd(),
		// Platform-specific
		newMacOSCmd(),
		// Import from other dotfile managers
		newImportCmd(),
		// Shell initialization (outputs feature check functions)
		newShellInitCmd(),
		// Note: migrate command dropped - one-time v2→v3 migration handled by bash
	)
}

// initConfig resolves the blackdot directory
func initConfig() {
	// Check BLACKDOT_DIR env var first
	dotfilesDir = os.Getenv("BLACKDOT_DIR")
	if dotfilesDir != "" {
		return
	}

	// Default to ~/.blackdot
	home, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Warning: could not determine home directory: %v\n", err)
		return
	}

	dotfilesDir = filepath.Join(home, ".blackdot")
}

// DotfilesDir returns the resolved blackdot directory path
func DotfilesDir() string {
	return dotfilesDir
}

// ConfigDir returns the config directory (~/.config/blackdot)
func ConfigDir() string {
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" {
		home, _ := os.UserHomeDir()
		configHome = filepath.Join(home, ".config")
	}
	return filepath.Join(configHome, "blackdot")
}
