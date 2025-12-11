// Package cli provides custom help styling that matches the ZSH implementation.
package cli

import (
	"fmt"
	"os"
	"runtime"

	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
)

// Custom help template matching ZSH style
func customHelpFunc(cmd *cobra.Command, args []string) {
	// Root command gets special treatment
	if cmd.Name() == "blackdot" && cmd.Parent() == nil {
		printRootHelp()
		return
	}

	// Subcommands use styled Cobra help
	printCommandHelp(cmd)
}

// printRootHelp prints help matching the ZSH _blackdot_help function exactly
func printRootHelp() {
	// Title
	fmt.Print("⚫ ")
	BoldCyan.Print("blackdot")
	fmt.Print(" - Manage your blackdot config\n")
	fmt.Println()
	Bold.Print("Usage:")
	fmt.Print(" blackdot <command> [options]\n")
	fmt.Println()

	// Setup & Health (always visible)
	BoldCyan.Println("Setup & Health:")
	printCmd("setup", "Interactive setup wizard (recommended)")
	printCmdAlias("status", "s", "Quick visual dashboard")
	printCmdAlias("doctor", "health", "Run comprehensive health check")
	printCmd("lint", "Validate shell config syntax")
	printCmdAlias("packages", "pkg", "Check/install Brewfile packages")
	fmt.Println()

	// Vault Operations
	BoldCyan.Println("Vault Operations:")
	printCmd("vault setup", "Setup vault backend (first-time setup)")
	printCmd("vault pull", "Pull secrets from vault")
	printCmd("vault push", "Push secrets to vault")
	printCmd("vault sync", "Bidirectional sync (smart direction)")
	printCmd("vault scan", "Re-scan for new secrets")
	printCmd("vault list", "List all vault items")
	printCmd("drift", "Compare local files vs vault")
	printCmd("sync", "Bidirectional vault sync (smart push/pull)")
	printCmd("diff", "Preview changes before sync/restore")
	fmt.Println()

	// Backup & Safety
	BoldCyan.Println("Backup & Safety:")
	printCmd("backup", "Create backup of current config")
	printCmd("backup list", "List all backups")
	printCmd("backup restore", "Restore specific backup")
	printCmd("rollback", "Instant rollback to last backup")
	fmt.Println()

	// Security
	BoldCyan.Println("Security:")
	printCmd("encrypt", "Age encryption management")
	printCmd("encrypt init", "Initialize encryption (generate keys)")
	printCmd("encrypt edit", "Decrypt, edit, re-encrypt a file")
	printCmd("encrypt status", "Show encryption status and key info")
	fmt.Println()

	// Feature Management
	BoldCyan.Println("Feature Management:")
	printCmd("features", "List all features and status")
	printCmd("features enable", "Enable a feature")
	printCmd("features disable", "Disable a feature")
	printCmd("features preset", "Enable a preset (minimal/developer/claude/full)")
	fmt.Println()

	// Configuration
	BoldCyan.Println("Configuration:")
	printCmd("config get", "Get config value (with layer resolution)")
	printCmd("config set", "Set config value in specific layer")
	printCmd("config show", "Show where a config value comes from")
	printCmd("config list", "Show configuration layer status")
	fmt.Println()

	// Templates
	BoldCyan.Println("Templates:")
	printCmdAlias("template", "tmpl", "Machine-specific config templates")
	fmt.Println()

	// Developer Tools
	BoldCyan.Println("Developer Tools:")
	printCmd("tools", "Cross-platform developer tool wrappers")
	printCmd("tools ssh", "SSH key and agent management")
	printCmd("tools aws", "AWS CLI helpers (profiles, SSO)")
	printCmd("tools docker", "Docker management shortcuts")
	printCmd("tools claude", "Claude Code backend configuration")
	fmt.Println()

	// macOS Settings (only show on Darwin)
	if runtime.GOOS == "darwin" {
		BoldCyan.Println("macOS Settings:")
		printCmd("macos", "macOS system settings")
		printCmd("macos apply", "Apply settings from settings.sh")
		printCmd("macos preview", "Preview changes (dry-run)")
		printCmd("macos discover", "Discover current settings")
		fmt.Println()
	}

	// Hooks
	BoldCyan.Println("Hooks:")
	printCmdAlias("hook", "hooks", "Hook system management")
	printCmd("hook list", "List hooks (all points or specific)")
	printCmd("hook run <point>", "Manually trigger hooks")
	printCmd("hook add", "Add a hook script to a point")
	printCmd("hook points", "List all available hook points")
	printCmd("hook test", "Test hooks for a point (verbose)")
	fmt.Println()

	// Other Commands
	BoldCyan.Println("Other Commands:")
	printCmd("uninstall", "Remove blackdot configuration")
	printCmd("version", "Show version information")
	printCmd("help", "Show this help")
	fmt.Println()

	Dim.Println("Run 'blackdot <command> --help' for detailed options.")
	fmt.Println()
	Dim.Printf("Runtime: Go CLI (%s)\n", versionStr)
}

// printCmd prints a command with description in ZSH style
func printCmd(name, desc string) {
	fmt.Print("  ")
	Yellow.Printf("%-17s", name)
	fmt.Print(" ")
	Dim.Println(desc)
}

// printCmdAlias prints a command with alias and description
func printCmdAlias(name, alias, desc string) {
	fmt.Print("  ")
	combined := fmt.Sprintf("%s, %s", name, alias)
	Yellow.Printf("%-17s", combined)
	fmt.Print(" ")
	Dim.Println(desc)
}

// printCommandHelp prints styled help for subcommands
func printCommandHelp(cmd *cobra.Command) {
	// Title
	fmt.Print("⚫ ")
	BoldCyan.Printf("blackdot %s", cmd.Name())
	if cmd.Short != "" {
		fmt.Print(" - ")
		Dim.Print(cmd.Short)
	}
	fmt.Println()
	fmt.Println()

	// Usage
	Bold.Print("Usage:")
	fmt.Printf(" %s\n", cmd.UseLine())
	fmt.Println()

	// Long description if available
	if cmd.Long != "" {
		fmt.Printf("%s\n\n", cmd.Long)
	}

	// Subcommands
	if cmd.HasAvailableSubCommands() {
		BoldCyan.Println("Commands:")
		for _, sub := range cmd.Commands() {
			if !sub.Hidden {
				fmt.Print("  ")
				Yellow.Printf("%-14s", sub.Name())
				fmt.Print(" ")
				Dim.Println(sub.Short)
			}
		}
		fmt.Println()
	}

	// Flags
	if cmd.HasAvailableFlags() {
		BoldCyan.Println("Flags:")
		cmd.Flags().VisitAll(func(f *pflag.Flag) {
			if f.Shorthand != "" {
				fmt.Print("  ")
				Yellow.Printf("-%s", f.Shorthand)
				fmt.Print(", ")
				Yellow.Printf("--%s", f.Name)
			} else {
				fmt.Print("      ")
				Yellow.Printf("--%s", f.Name)
			}
			fmt.Print("  ")
			Dim.Println(f.Usage)
		})
		fmt.Println()
	}

	// Examples if available
	if cmd.Example != "" {
		BoldCyan.Println("Examples:")
		fmt.Printf("%s\n", cmd.Example)
		fmt.Println()
	}

	Dim.Printf("Run 'blackdot %s <command> --help' for subcommand details.\n", cmd.Name())
}

// RunCommand executes the root command (used by main)
func RunCommand() error {
	return rootCmd.Execute()
}

// checkTerminal returns true if stdout is a terminal
func checkTerminal() bool {
	fileInfo, _ := os.Stdout.Stat()
	return (fileInfo.Mode() & os.ModeCharDevice) != 0
}
