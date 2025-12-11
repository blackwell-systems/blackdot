package cli

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// Symlinks to remove during uninstall
var uninstallSymlinks = []string{
	".zshrc",
	".p10k.zsh",
	".config/ghostty/config",
	".claude",
}

// Config files to remove
var uninstallConfigFiles = []string{
	".blackdot-metrics.jsonl",
	".blackdot-backups",
}

// Secret files (only removed if --keep-secrets is not set)
var uninstallSecretFiles = []string{
	".ssh/config",
	".aws/config",
	".aws/credentials",
	".gitconfig",
	".local/env.secrets",
}

func newUninstallCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "uninstall",
		Short: "Remove blackdot configuration",
		Long: `Uninstall blackdot by removing symlinks and configurations.

Options:
  --dry-run, -n      Show what would be removed (don't delete)
  --keep-secrets, -k Keep SSH keys and AWS credentials

Examples:
  blackdot uninstall              # Interactive uninstall
  blackdot uninstall --dry-run    # Preview what would be removed
  blackdot uninstall -k           # Keep secrets`,
		RunE: runUninstall,
	}

	cmd.Flags().BoolP("dry-run", "n", false, "Show what would be removed (don't delete)")
	cmd.Flags().BoolP("keep-secrets", "k", false, "Keep SSH keys and AWS credentials")

	return cmd
}

func runUninstall(cmd *cobra.Command, args []string) error {
	dryRun, _ := cmd.Flags().GetBool("dry-run")
	keepSecrets, _ := cmd.Flags().GetBool("keep-secrets")

	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("cannot determine home directory: %w", err)
	}

	dotfilesDir := os.Getenv("BLACKDOT_DIR")
	if dotfilesDir == "" {
		dotfilesDir = filepath.Join(home, ".blackdot")
	}

	// Colors
	bold := color.New(color.Bold)
	red := color.New(color.FgRed)
	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()
	blue := color.New(color.FgBlue).SprintFunc()

	fmt.Println()
	bold.Add(color.FgRed).Println("Dotfiles Uninstaller")
	fmt.Println()

	if dryRun {
		fmt.Println(yellow("DRY RUN MODE - No changes will be made"))
		fmt.Println()
	}

	// Remove symlinks
	fmt.Println(blue("Removing symlinks..."))
	for _, link := range uninstallSymlinks {
		fullPath := filepath.Join(home, link)
		removeItem(fullPath, "symlink", dryRun, green, yellow)
	}

	// Also check /workspace symlink
	removeItem("/workspace", "symlink", dryRun, green, yellow)

	// Remove config files
	fmt.Println()
	fmt.Println(blue("Removing config files..."))
	for _, file := range uninstallConfigFiles {
		fullPath := filepath.Join(home, file)
		removeItem(fullPath, "config", dryRun, green, yellow)
	}

	// Handle secrets
	fmt.Println()
	if keepSecrets {
		fmt.Println(blue("Keeping secrets (--keep-secrets specified)"))
	} else {
		fmt.Println(blue("Removing secrets..."))
		fmt.Println(yellow("WARNING: This will delete SSH keys, AWS credentials, etc."))

		if !dryRun {
			reader := bufio.NewReader(os.Stdin)
			fmt.Print("Are you sure? (yes/no): ")
			confirm, _ := reader.ReadString('\n')
			confirm = strings.TrimSpace(confirm)

			if confirm != "yes" {
				fmt.Println("Keeping secrets.")
				keepSecrets = true
			}
		}

		if !keepSecrets {
			for _, file := range uninstallSecretFiles {
				fullPath := filepath.Join(home, file)
				removeItem(fullPath, "secret", dryRun, green, yellow)
			}
		}
	}

	// Handle dotfiles repository
	fmt.Println()
	fmt.Println(blue("Dotfiles repository..."))
	if info, err := os.Stat(dotfilesDir); err == nil && info.IsDir() {
		if dryRun {
			fmt.Printf("  %s: %s (repository)\n", yellow("Would remove"), dotfilesDir)
		} else {
			reader := bufio.NewReader(os.Stdin)
			fmt.Print("Remove blackdot repository? (yes/no): ")
			confirm, _ := reader.ReadString('\n')
			confirm = strings.TrimSpace(confirm)

			if confirm == "yes" {
				if err := os.RemoveAll(dotfilesDir); err != nil {
					red.Printf("  Failed to remove: %s: %v\n", dotfilesDir, err)
				} else {
					fmt.Printf("  %s: %s\n", green("Removed"), dotfilesDir)
				}
			} else {
				fmt.Println("  Keeping repository.")
			}
		}
	}

	// Summary
	fmt.Println()
	if dryRun {
		fmt.Println(yellow("Dry run complete. Run without --dry-run to apply changes."))
	} else {
		color.New(color.FgGreen).Println("Uninstall complete.")
		fmt.Println()
		fmt.Println("To reinstall:")
		fmt.Println("  curl -fsSL https://raw.githubusercontent.com/blackwell-systems/blackdot/main/install.sh | bash")
	}
	fmt.Println()

	return nil
}

// removeItem removes a file or directory, handling dry-run mode
func removeItem(path string, itemType string, dryRun bool, green, yellow func(a ...interface{}) string) {
	// Check if exists (including broken symlinks)
	_, statErr := os.Lstat(path)
	if statErr != nil {
		return // doesn't exist
	}

	// For symlinks, verify it's actually a symlink
	if itemType == "symlink" {
		info, err := os.Lstat(path)
		if err != nil || info.Mode()&os.ModeSymlink == 0 {
			return // not a symlink
		}
	}

	if dryRun {
		fmt.Printf("  %s: %s (%s)\n", yellow("Would remove"), path, itemType)
	} else {
		if err := os.RemoveAll(path); err != nil {
			fmt.Printf("  Failed to remove: %s: %v\n", path, err)
		} else {
			fmt.Printf("  %s: %s\n", green("Removed"), path)
		}
	}
}
