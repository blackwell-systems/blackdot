package cli

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"

	"github.com/spf13/cobra"
)

func newMacOSCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "macos",
		Short: "macOS system settings",
		Long:  `Manage macOS system settings and preferences.`,
		Run: func(cmd *cobra.Command, args []string) {
			printMacOSHelp()
		},
	}

	cmd.SetHelpFunc(func(cmd *cobra.Command, args []string) {
		printMacOSHelp()
	})

	cmd.AddCommand(
		newMacOSApplyCmd(),
		newMacOSPreviewCmd(),
		newMacOSDiscoverCmd(),
	)

	return cmd
}

func newMacOSApplyCmd() *cobra.Command {
	var backup bool

	cmd := &cobra.Command{
		Use:   "apply",
		Short: "Apply macOS settings from settings.sh",
		Long:  `Apply macOS system preferences from the settings.sh file.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return macosApply(backup)
		},
	}

	cmd.Flags().BoolVarP(&backup, "backup", "b", false, "Create snapshot before applying")

	return cmd
}

func newMacOSPreviewCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "preview",
		Short: "Preview settings that would be applied",
		Long:  `Show what macOS settings would be changed without applying them.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return macosPreview()
		},
	}
}

func newMacOSDiscoverCmd() *cobra.Command {
	var generate bool
	var snapshot bool
	var compare string

	cmd := &cobra.Command{
		Use:   "discover",
		Short: "Discover current macOS settings",
		Long: `Discover and export current macOS system preferences.

This scans common preference domains and outputs the current settings.
Use --generate to create a settings.sh file from your current preferences.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return macosDiscover(generate, snapshot, compare)
		},
	}

	cmd.Flags().BoolVarP(&generate, "generate", "g", false, "Generate settings.sh from current preferences")
	cmd.Flags().BoolVarP(&snapshot, "snapshot", "s", false, "Save snapshot of current settings")
	cmd.Flags().StringVarP(&compare, "compare", "c", "", "Compare current settings with a snapshot")

	return cmd
}

// printMacOSHelp prints styled help for macOS command
func printMacOSHelp() {
	BoldCyan.Print("dotfiles macos")
	fmt.Print(" - macOS system settings\n")
	fmt.Println()

	Bold.Print("Usage:")
	fmt.Print(" dotfiles macos <command> [options]\n")
	fmt.Println()

	BoldCyan.Println("Commands:")
	printCmd("apply", "Apply settings from settings.sh")
	printCmd("preview", "Preview what would change (dry-run)")
	printCmd("discover", "Discover current macOS settings")
	fmt.Println()

	BoldCyan.Println("Examples:")
	Dim.Println("  # See what settings would be applied")
	fmt.Println("  dotfiles macos preview")
	fmt.Println()
	Dim.Println("  # Apply settings")
	fmt.Println("  dotfiles macos apply")
	fmt.Println()
	Dim.Println("  # Generate settings.sh from current preferences")
	fmt.Println("  dotfiles macos discover --generate")
	fmt.Println()
	Dim.Println("  # Create a backup before applying")
	fmt.Println("  dotfiles macos apply --backup")
	fmt.Println()

	BoldCyan.Println("Workflow:")
	Dim.Println("  1. Configure macOS manually via System Settings")
	Dim.Println("  2. Run: dotfiles macos discover --generate")
	Dim.Println("  3. Review/edit macos/settings.sh")
	Dim.Println("  4. On new machine: dotfiles macos apply")

	// Show platform warning if not on macOS
	if runtime.GOOS != "darwin" {
		fmt.Println()
		Warn("This command only works on macOS")
	}
}

// checkMacOS ensures we're running on macOS and feature is enabled
func checkMacOS() error {
	if runtime.GOOS != "darwin" {
		return fmt.Errorf("this command only runs on macOS")
	}

	// Check if feature is enabled (unless --force is set)
	if !force {
		reg := initRegistry()
		if !reg.Enabled("macos_settings") {
			Fail("Feature 'macos_settings' is not enabled")
			fmt.Println()
			Info("Enable with: dotfiles features enable macos_settings")
			Info("Or run with --force to bypass")
			return fmt.Errorf("feature not enabled")
		}
	}

	return nil
}

// macosApply applies settings from settings.sh
func macosApply(backup bool) error {
	if err := checkMacOS(); err != nil {
		Fail("%v", err)
		return err
	}

	script := filepath.Join(DotfilesDir(), "macos", "apply-settings.sh")
	if _, err := os.Stat(script); os.IsNotExist(err) {
		Fail("Script not found: %s", script)
		return err
	}

	args := []string{}
	if backup {
		args = append(args, "--backup")
	}

	cmd := exec.Command(script, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	return cmd.Run()
}

// macosPreview shows what settings would be applied
func macosPreview() error {
	if err := checkMacOS(); err != nil {
		Fail("%v", err)
		return err
	}

	script := filepath.Join(DotfilesDir(), "macos", "apply-settings.sh")
	if _, err := os.Stat(script); os.IsNotExist(err) {
		Fail("Script not found: %s", script)
		return err
	}

	cmd := exec.Command(script, "--dry-run")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

// macosDiscover discovers current macOS settings
func macosDiscover(generate, snapshot bool, compare string) error {
	if err := checkMacOS(); err != nil {
		Fail("%v", err)
		return err
	}

	script := filepath.Join(DotfilesDir(), "macos", "discover-settings.sh")
	if _, err := os.Stat(script); os.IsNotExist(err) {
		Fail("Script not found: %s", script)
		return err
	}

	args := []string{}
	if generate {
		args = append(args, "--generate")
	}
	if snapshot {
		args = append(args, "--snapshot")
	}
	if compare != "" {
		args = append(args, "--compare", compare)
	}

	cmd := exec.Command(script, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	return cmd.Run()
}
