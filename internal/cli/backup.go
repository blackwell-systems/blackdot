package cli

import (
	"archive/tar"
	"compress/gzip"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// Default files to backup (matches bash implementation)
var defaultBackupFiles = []string{
	".ssh/config",
	".ssh/known_hosts",
	".gitconfig",
	".aws/config",
	".aws/credentials",
	".local/env.secrets",
	".zshrc",
	".p10k.zsh",
	".config/blackdot/config.json",
}

type backupConfig struct {
	backupDir   string
	maxBackups  int
	compress    bool
	blackdotDir string
}

func getBackupConfig() *backupConfig {
	home, _ := os.UserHomeDir()
	blackdotDir := os.Getenv("BLACKDOT_DIR")
	if blackdotDir == "" {
		blackdotDir = filepath.Join(home, ".blackdot")
	}

	return &backupConfig{
		backupDir:   filepath.Join(home, ".blackdot-backups"),
		maxBackups:  10,
		compress:    true,
		blackdotDir: blackdotDir,
	}
}

func newBackupCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "backup",
		Short: "Manage backups",
		Long:  `Manage blackdot backups`,
		RunE:  runBackupCreate,
	}

	// Override help to use styled version
	cmd.SetHelpFunc(func(cmd *cobra.Command, args []string) {
		printBackupHelp()
	})

	cmd.AddCommand(
		&cobra.Command{
			Use:   "create",
			Short: "Create backup of current config",
			RunE:  runBackupCreate,
		},
		&cobra.Command{
			Use:   "list",
			Short: "List all backups",
			RunE:  runBackupList,
		},
		&cobra.Command{
			Use:   "restore [backup-id]",
			Short: "Restore specific backup",
			Long: `Restore a backup. If no backup-id is given, restores the latest.

Examples:
  blackdot backup restore                  # Restore latest
  blackdot backup restore 20231207_120000  # Restore specific`,
			RunE: runBackupRestore,
		},
		&cobra.Command{
			Use:   "clean",
			Short: "Remove old backups (keeps newest 10)",
			RunE:  runBackupClean,
		},
	)

	return cmd
}

// printBackupHelp prints styled help matching ZSH style
func printBackupHelp() {
	// Title
	fmt.Print("⚫ ")
	BoldCyan.Print("blackdot backup")
	fmt.Print(" - ")
	Dim.Println("Manage blackdot backups")
	fmt.Println()

	// Usage
	Bold.Print("Usage:")
	fmt.Println(" blackdot backup [command]")
	fmt.Println()

	// Commands
	BoldCyan.Println("Commands:")
	fmt.Print("  ")
	Yellow.Printf("%-12s", "create")
	Dim.Println("Create backup of current config")
	fmt.Print("  ")
	Yellow.Printf("%-12s", "list")
	Dim.Println("List all backups")
	fmt.Print("  ")
	Yellow.Printf("%-12s", "restore")
	Dim.Println("Restore specific backup")
	fmt.Print("  ")
	Yellow.Printf("%-12s", "clean")
	Dim.Println("Remove old backups (keeps newest 10)")
	fmt.Println()

	// Backed up files
	BoldCyan.Println("Backed Up Files:")
	Dim.Println("  - SSH config and known_hosts")
	Dim.Println("  - Git configuration")
	Dim.Println("  - AWS credentials (if present)")
	Dim.Println("  - Zsh configuration")
	Dim.Println("  - Blackdot config.json")
	Dim.Println("  - Template variables")
	fmt.Println()

	// Examples
	BoldCyan.Println("Examples:")
	fmt.Print("  ")
	Yellow.Print("blackdot backup")
	fmt.Print("              ")
	Dim.Println("# Create a new backup")
	fmt.Print("  ")
	Yellow.Print("blackdot backup list")
	fmt.Print("         ")
	Dim.Println("# List all backups")
	fmt.Print("  ")
	Yellow.Print("blackdot backup restore")
	fmt.Print("      ")
	Dim.Println("# Restore latest backup")
	fmt.Print("  ")
	Yellow.Print("blackdot backup clean")
	fmt.Print("        ")
	Dim.Println("# Remove old backups")
	fmt.Println()
}

func runBackupCreate(cmd *cobra.Command, args []string) error {
	cfg := getBackupConfig()
	home, _ := os.UserHomeDir()

	green := color.New(color.FgGreen).SprintFunc()
	cyan := color.New(color.FgCyan).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()

	// Create backup directory
	if err := os.MkdirAll(cfg.backupDir, 0700); err != nil {
		return fmt.Errorf("creating backup directory: %w", err)
	}

	// Generate backup name with timestamp (matches bash: backup-YYYYMMDD-HHMMSS)
	timestamp := time.Now().Format("20060102-150405")
	backupName := fmt.Sprintf("backup-%s.tar.gz", timestamp)
	backupPath := filepath.Join(cfg.backupDir, backupName)

	fmt.Println()
	fmt.Println(color.New(color.Bold).Sprint("Creating Backup"))
	fmt.Println("================")
	fmt.Println()

	// Create tar.gz file
	file, err := os.Create(backupPath)
	if err != nil {
		return fmt.Errorf("creating backup file: %w", err)
	}
	defer file.Close()

	gw := gzip.NewWriter(file)
	defer gw.Close()

	tw := tar.NewWriter(gw)
	defer tw.Close()

	// Add files to backup
	var backedUp int
	for _, relPath := range defaultBackupFiles {
		fullPath := filepath.Join(home, relPath)

		// Check if file exists
		info, err := os.Stat(fullPath)
		if os.IsNotExist(err) {
			fmt.Printf("  %s %s (not found, skipped)\n", yellow("-"), relPath)
			continue
		}
		if err != nil {
			fmt.Printf("  %s %s: %v\n", yellow("⚠"), relPath, err)
			continue
		}

		// Read file
		data, err := os.ReadFile(fullPath)
		if err != nil {
			fmt.Printf("  %s %s: %v\n", yellow("⚠"), relPath, err)
			continue
		}

		// Create tar header
		header := &tar.Header{
			Name:    relPath,
			Size:    info.Size(),
			Mode:    int64(info.Mode()),
			ModTime: info.ModTime(),
		}

		if err := tw.WriteHeader(header); err != nil {
			return fmt.Errorf("writing tar header: %w", err)
		}

		if _, err := tw.Write(data); err != nil {
			return fmt.Errorf("writing file to tar: %w", err)
		}

		fmt.Printf("  %s %s\n", green("✓"), relPath)
		backedUp++
	}

	// Also backup templates/_variables.local.sh if it exists
	varFile := filepath.Join(cfg.blackdotDir, "templates", "_variables.local.sh")
	if info, err := os.Stat(varFile); err == nil {
		data, err := os.ReadFile(varFile)
		if err == nil {
			header := &tar.Header{
				Name:    "blackdot/templates/_variables.local.sh",
				Size:    info.Size(),
				Mode:    int64(info.Mode()),
				ModTime: info.ModTime(),
			}
			if err := tw.WriteHeader(header); err == nil {
				tw.Write(data)
				fmt.Printf("  %s %s\n", green("✓"), "templates/_variables.local.sh")
				backedUp++
			}
		}
	}

	fmt.Println()
	fmt.Printf("Backup created: %s\n", cyan(backupPath))
	fmt.Printf("Files backed up: %d\n", backedUp)

	// Clean old backups
	cleanOldBackups(cfg)

	return nil
}

func runBackupList(cmd *cobra.Command, args []string) error {
	cfg := getBackupConfig()

	cyan := color.New(color.FgCyan).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()

	fmt.Println()
	fmt.Printf("Available backups (max: %d):\n", cfg.maxBackups)
	fmt.Println("==========================================")
	fmt.Println()

	entries, err := os.ReadDir(cfg.backupDir)
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Println("No backups found.")
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
		fmt.Println("No backups found.")
		return nil
	}

	// Sort by name (which includes timestamp)
	sort.Slice(backups, func(i, j int) bool {
		return backups[i].Name() > backups[j].Name() // Newest first
	})

	for i, b := range backups {
		info, _ := b.Info()
		name := b.Name()

		// Parse timestamp from name
		timestamp := strings.TrimPrefix(name, "backup_")
		timestamp = strings.TrimSuffix(timestamp, ".tar.gz")

		// Format size
		size := "?"
		if info != nil {
			size = formatSize(info.Size())
		}

		marker := " "
		if i == 0 {
			marker = yellow("→")
		}

		fmt.Printf("  %s %s  %s  %s\n", marker, cyan(timestamp), size, name)
	}

	fmt.Println()
	fmt.Println("Restore with: blackdot backup restore [backup-name]")
	fmt.Printf("Location: %s\n", cfg.backupDir)
	return nil
}

func runBackupRestore(cmd *cobra.Command, args []string) error {
	cfg := getBackupConfig()
	home, _ := os.UserHomeDir()

	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()

	// Find backup to restore
	var backupPath string
	if len(args) > 0 {
		// Specific backup requested - try multiple naming patterns
		patterns := []string{
			filepath.Join(cfg.backupDir, fmt.Sprintf("backup-%s.tar.gz", args[0])),
			filepath.Join(cfg.backupDir, fmt.Sprintf("backup_%s.tar.gz", args[0])),
			filepath.Join(cfg.backupDir, fmt.Sprintf("%s.tar.gz", args[0])),
			filepath.Join(cfg.backupDir, args[0]),
		}
		for _, p := range patterns {
			if _, err := os.Stat(p); err == nil {
				backupPath = p
				break
			}
		}
		if backupPath == "" {
			return fmt.Errorf("backup not found: %s", args[0])
		}
	} else {
		// Find latest backup by modification time
		entries, err := os.ReadDir(cfg.backupDir)
		if err != nil {
			return fmt.Errorf("reading backup directory: %w", err)
		}

		var latestName string
		var latestTime time.Time
		for _, e := range entries {
			// Support both naming conventions
			if (strings.HasPrefix(e.Name(), "backup-") || strings.HasPrefix(e.Name(), "backup_")) &&
				(strings.HasSuffix(e.Name(), ".tar.gz") || strings.HasSuffix(e.Name(), ".tar")) {
				info, err := e.Info()
				if err != nil {
					continue
				}
				if info.ModTime().After(latestTime) {
					latestTime = info.ModTime()
					latestName = e.Name()
				}
			}
		}

		if latestName == "" {
			return fmt.Errorf("no backups found in %s", cfg.backupDir)
		}
		backupPath = filepath.Join(cfg.backupDir, latestName)
	}

	// Check backup exists
	if _, err := os.Stat(backupPath); err != nil {
		return fmt.Errorf("backup not found: %s", backupPath)
	}

	fmt.Println()
	fmt.Println(color.New(color.Bold).Sprint("Restoring Backup"))
	fmt.Println("=================")
	fmt.Printf("From: %s\n\n", backupPath)

	// Open backup
	file, err := os.Open(backupPath)
	if err != nil {
		return fmt.Errorf("opening backup: %w", err)
	}
	defer file.Close()

	gr, err := gzip.NewReader(file)
	if err != nil {
		return fmt.Errorf("decompressing backup: %w", err)
	}
	defer gr.Close()

	tr := tar.NewReader(gr)

	// Detect archive format - bash wraps in backup-YYYYMMDD-HHMMSS/ directory
	var wrapperDir string

	var restored int
	for {
		header, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("reading backup: %w", err)
		}

		// Skip directories
		if header.Typeflag == tar.TypeDir {
			// Detect wrapper directory (bash format)
			if strings.HasPrefix(header.Name, "backup-") || strings.HasPrefix(header.Name, "backup_") {
				wrapperDir = strings.TrimSuffix(header.Name, "/")
			}
			continue
		}

		// Skip manifest.json (bash metadata file)
		if strings.HasSuffix(header.Name, "manifest.json") {
			continue
		}

		// Strip wrapper directory if present (bash format)
		relPath := header.Name
		if wrapperDir != "" && strings.HasPrefix(relPath, wrapperDir+"/") {
			relPath = strings.TrimPrefix(relPath, wrapperDir+"/")
		}

		// Determine destination
		var destPath string
		if strings.HasPrefix(relPath, "blackdot/") {
			// Blackdot-relative path
			destPath = filepath.Join(cfg.blackdotDir, strings.TrimPrefix(relPath, "blackdot/"))
		} else {
			// Home-relative path
			destPath = filepath.Join(home, relPath)
		}

		// Create parent directory
		if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
			fmt.Printf("  %s %s: %v\n", yellow("⚠"), relPath, err)
			continue
		}

		// Create file
		outFile, err := os.OpenFile(destPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, os.FileMode(header.Mode))
		if err != nil {
			fmt.Printf("  %s %s: %v\n", yellow("⚠"), relPath, err)
			continue
		}

		if _, err := io.Copy(outFile, tr); err != nil {
			outFile.Close()
			fmt.Printf("  %s %s: %v\n", yellow("⚠"), relPath, err)
			continue
		}
		outFile.Close()

		fmt.Printf("  %s %s\n", green("✓"), relPath)
		restored++
	}

	fmt.Printf("\nRestored %d files\n", restored)
	return nil
}

func runBackupClean(cmd *cobra.Command, args []string) error {
	cfg := getBackupConfig()
	removed := cleanOldBackups(cfg)
	fmt.Printf("Removed %d old backups (keeping newest %d)\n", removed, cfg.maxBackups)
	return nil
}

func cleanOldBackups(cfg *backupConfig) int {
	entries, err := os.ReadDir(cfg.backupDir)
	if err != nil {
		return 0
	}

	var backups []string
	for _, e := range entries {
		// Support both naming conventions
		if (strings.HasPrefix(e.Name(), "backup-") || strings.HasPrefix(e.Name(), "backup_")) &&
			(strings.HasSuffix(e.Name(), ".tar.gz") || strings.HasSuffix(e.Name(), ".tar")) {
			backups = append(backups, e.Name())
		}
	}

	if len(backups) <= cfg.maxBackups {
		return 0
	}

	// Sort newest first
	sort.Sort(sort.Reverse(sort.StringSlice(backups)))

	// Remove old ones
	var removed int
	for i := cfg.maxBackups; i < len(backups); i++ {
		path := filepath.Join(cfg.backupDir, backups[i])
		if err := os.Remove(path); err == nil {
			removed++
		}
	}

	return removed
}

func formatSize(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}
