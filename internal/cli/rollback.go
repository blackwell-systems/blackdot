package cli

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/spf13/cobra"
)

func newRollbackCmd() *cobra.Command {
	var toBackup string
	var listBackups bool
	var yes bool
	var dryRun bool

	cmd := &cobra.Command{
		Use:   "rollback",
		Short: "Instant rollback to last backup",
		Long: `Quickly rollback to the most recent backup (or a specific one).

This is a convenience command equivalent to 'blackdot backup restore'.
For more backup options, use 'blackdot backup'.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			// Check feature
			if !force {
				reg := initRegistry()
				if !reg.Enabled("backup_auto") {
					Fail("Feature 'backup_auto' is not enabled")
					fmt.Println()
					Info("Enable with: blackdot features enable backup_auto")
					Info("Or run with --force to bypass")
					return fmt.Errorf("feature not enabled")
				}
			}

			if listBackups {
				return rollbackList()
			}

			return rollbackRestore(toBackup, yes, dryRun)
		},
	}

	// Override help to use styled version
	cmd.SetHelpFunc(func(cmd *cobra.Command, args []string) {
		printRollbackHelp()
	})

	cmd.Flags().StringVar(&toBackup, "to", "", "Rollback to specific backup ID")
	cmd.Flags().BoolVarP(&listBackups, "list", "l", false, "List available backups")
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "Skip confirmation prompt")
	cmd.Flags().BoolVarP(&dryRun, "dry-run", "n", false, "Preview what would be rolled back without making changes")

	return cmd
}

// printRollbackHelp prints styled help matching ZSH style
func printRollbackHelp() {
	// Title
	fmt.Print("⚫ ")
	BoldCyan.Print("blackdot rollback")
	fmt.Print(" - ")
	Dim.Println("Instant rollback to last backup")
	fmt.Println()

	// Usage
	Bold.Print("Usage:")
	fmt.Println(" blackdot rollback [flags]")
	fmt.Println()

	// Flags
	BoldCyan.Println("Flags:")
	fmt.Print("      ")
	Yellow.Print("--to ID")
	fmt.Print("    ")
	Dim.Println("Rollback to specific backup")
	fmt.Print("  ")
	Yellow.Print("-l")
	fmt.Print(", ")
	Yellow.Print("--list")
	fmt.Print("    ")
	Dim.Println("List available backups")
	fmt.Print("  ")
	Yellow.Print("-y")
	fmt.Print(", ")
	Yellow.Print("--yes")
	fmt.Print("     ")
	Dim.Println("Skip confirmation prompt")
	fmt.Println()

	// Examples
	BoldCyan.Println("Examples:")
	Dim.Println("  # Quick rollback to most recent backup")
	fmt.Println("  blackdot rollback")
	fmt.Println()
	Dim.Println("  # Rollback to a specific backup")
	fmt.Println("  blackdot rollback --to backup-20250101-120000")
	fmt.Println()
	Dim.Println("  # List available backups")
	fmt.Println("  blackdot rollback --list")
	fmt.Println()

	// See also
	BoldCyan.Println("See Also:")
	fmt.Print("  ")
	Yellow.Print("blackdot backup")
	fmt.Print("         ")
	Dim.Println("Create a new backup")
	fmt.Print("  ")
	Yellow.Print("blackdot backup --list")
	fmt.Print("  ")
	Dim.Println("List all backups with details")
	fmt.Println()
}

// rollbackList shows available backups
func rollbackList() error {
	cfg := getBackupConfig()

	fmt.Println()
	BoldCyan.Println("Available backups for rollback:")
	fmt.Println("================================")
	fmt.Println()

	entries, err := os.ReadDir(cfg.backupDir)
	if err != nil {
		if os.IsNotExist(err) {
			Warn("No backups found")
			Info("Create one with: blackdot backup")
			return nil
		}
		return fmt.Errorf("reading backup directory: %w", err)
	}

	var backups []os.DirEntry
	for _, e := range entries {
		// Support both naming conventions: backup- (bash) and backup_ (legacy Go)
		if (strings.HasPrefix(e.Name(), "backup-") || strings.HasPrefix(e.Name(), "backup_")) &&
			(strings.HasSuffix(e.Name(), ".tar.gz") || strings.HasSuffix(e.Name(), ".tar")) {
			backups = append(backups, e)
		}
	}

	if len(backups) == 0 {
		Warn("No backups found")
		Info("Create one with: blackdot backup")
		return nil
	}

	// Sort by name (which includes timestamp) - newest first
	sort.Slice(backups, func(i, j int) bool {
		return backups[i].Name() > backups[j].Name()
	})

	// Show top 5 for rollback
	limit := 5
	if len(backups) < limit {
		limit = len(backups)
	}

	for i, b := range backups[:limit] {
		info, _ := b.Info()
		name := b.Name()

		// Extract backup ID from name
		backupID := strings.TrimPrefix(name, "backup-")
		backupID = strings.TrimPrefix(backupID, "backup_")
		backupID = strings.TrimSuffix(backupID, ".tar.gz")
		backupID = strings.TrimSuffix(backupID, ".tar")

		// Format size
		size := "?"
		if info != nil {
			size = formatSize(info.Size())
		}

		marker := " "
		if i == 0 {
			marker = "→"
			Yellow.Printf("  %s ", marker)
			fmt.Printf("%-22s  %s  ", backupID, size)
			Dim.Println("(latest)")
		} else {
			fmt.Printf("  %s %-22s  %s\n", marker, backupID, size)
		}
	}

	if len(backups) > limit {
		fmt.Println()
		Dim.Printf("  ... and %d more (use 'blackdot backup list' to see all)\n", len(backups)-limit)
	}

	fmt.Println()
	fmt.Println("Rollback with:")
	fmt.Printf("  blackdot rollback                  # restore latest\n")
	fmt.Printf("  blackdot rollback --to <backup-id> # restore specific\n")
	fmt.Println()
	Dim.Printf("Location: %s\n", cfg.backupDir)

	return nil
}

// rollbackRestore performs the actual restore
func rollbackRestore(specificBackup string, skipConfirm bool, dryRun bool) error {
	cfg := getBackupConfig()

	// Find backup to restore
	var backupPath string
	var backupID string

	if specificBackup != "" {
		// Specific backup requested - try multiple naming patterns
		patterns := []string{
			filepath.Join(cfg.backupDir, fmt.Sprintf("backup-%s.tar.gz", specificBackup)),
			filepath.Join(cfg.backupDir, fmt.Sprintf("backup_%s.tar.gz", specificBackup)),
			filepath.Join(cfg.backupDir, fmt.Sprintf("%s.tar.gz", specificBackup)),
			filepath.Join(cfg.backupDir, fmt.Sprintf("backup-%s.tar", specificBackup)),
			filepath.Join(cfg.backupDir, fmt.Sprintf("backup_%s.tar", specificBackup)),
			filepath.Join(cfg.backupDir, specificBackup),
		}
		for _, p := range patterns {
			if _, err := os.Stat(p); err == nil {
				backupPath = p
				break
			}
		}
		if backupPath == "" {
			Fail("Backup not found: %s", specificBackup)
			fmt.Println()
			fmt.Println("Available backups:")
			rollbackList()
			return fmt.Errorf("backup not found: %s", specificBackup)
		}
		backupID = specificBackup
	} else {
		// Find latest backup by name (contains timestamp)
		entries, err := os.ReadDir(cfg.backupDir)
		if err != nil {
			if os.IsNotExist(err) {
				Fail("No backups found")
				Info("Create one with: blackdot backup")
				return fmt.Errorf("no backups found")
			}
			return fmt.Errorf("reading backup directory: %w", err)
		}

		var backups []string
		for _, e := range entries {
			// Support both naming conventions
			if (strings.HasPrefix(e.Name(), "backup-") || strings.HasPrefix(e.Name(), "backup_")) &&
				(strings.HasSuffix(e.Name(), ".tar.gz") || strings.HasSuffix(e.Name(), ".tar")) {
				backups = append(backups, e.Name())
			}
		}

		if len(backups) == 0 {
			Fail("No backups found")
			Info("Create one with: blackdot backup")
			return fmt.Errorf("no backups found")
		}

		// Sort newest first (name contains timestamp)
		sort.Sort(sort.Reverse(sort.StringSlice(backups)))
		backupPath = filepath.Join(cfg.backupDir, backups[0])

		// Extract ID for display
		backupID = strings.TrimPrefix(backups[0], "backup-")
		backupID = strings.TrimPrefix(backupID, "backup_")
		backupID = strings.TrimSuffix(backupID, ".tar.gz")
		backupID = strings.TrimSuffix(backupID, ".tar")
	}

	// Confirm we have a valid path
	if _, err := os.Stat(backupPath); err != nil {
		return fmt.Errorf("backup not found: %s", backupPath)
	}

	// In dry-run mode, skip the warning and confirmation
	if dryRun {
		Info("Preview rollback to: %s", backupID)
		fmt.Println()
		// Use the backup restore logic with dry-run
		return runBackupRestoreWithDryRun(nil, []string{backupID}, true)
	}

	fmt.Println()
	Warn("This will overwrite your current configuration files!")
	fmt.Printf("  Backup: %s\n", backupID)
	fmt.Println()

	// Ask for confirmation unless -y flag is set
	if !skipConfirm {
		fmt.Print("Proceed with rollback? [y/N] ")
		reader := bufio.NewReader(os.Stdin)
		response, err := reader.ReadString('\n')
		if err != nil {
			return fmt.Errorf("reading input: %w", err)
		}
		response = strings.TrimSpace(strings.ToLower(response))
		if response != "y" && response != "yes" {
			Info("Rollback cancelled")
			return nil
		}
	}

	Info("Rolling back to: %s", backupID)
	fmt.Println()

	// Use the backup restore logic
	return runBackupRestore(nil, []string{backupID})
}
