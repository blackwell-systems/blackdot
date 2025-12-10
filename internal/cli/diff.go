package cli

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// diffTrackedItems matches bash implementation
var diffTrackedItems = map[string]string{
	"SSH-Config":          ".ssh/config",
	"AWS-Config":          ".aws/config",
	"AWS-Credentials":     ".aws/credentials",
	"Git-Config":          ".gitconfig",
	"Environment-Secrets": ".local/env.secrets",
}

func newDiffCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "diff [item]",
		Short: "Preview changes before sync/restore",
		Long: `Show differences between local files and vault.

Modes:
  (default)       Show all differences
  --sync, -s      Preview what sync would push to vault
  --restore, -r   Preview what restore would change locally
  [item]          Show diff for specific item only

Items:
  SSH-Config, AWS-Config, AWS-Credentials, Git-Config, Environment-Secrets

Examples:
  dotfiles diff              # Show all differences
  dotfiles diff --sync       # Preview what sync would push
  dotfiles diff --restore    # Preview what restore would change
  dotfiles diff SSH-Config   # Show diff for specific item`,
		RunE: runDiff,
	}

	cmd.Flags().BoolP("sync", "s", false, "Preview what sync would push to vault")
	cmd.Flags().BoolP("restore", "r", false, "Preview what restore would change locally")

	return cmd
}

func runDiff(cmd *cobra.Command, args []string) error {
	syncMode, _ := cmd.Flags().GetBool("sync")
	restoreMode, _ := cmd.Flags().GetBool("restore")

	// Check mutual exclusion
	if syncMode && restoreMode {
		fmt.Println(color.RedString("[ERROR]") + " --sync and --restore are mutually exclusive")
		return fmt.Errorf("--sync and --restore are mutually exclusive")
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("cannot determine home directory: %w", err)
	}

	dotfilesDir := os.Getenv("BLACKDOT_DIR")
	if dotfilesDir == "" {
		dotfilesDir = filepath.Join(home, ".dotfiles")
	}

	// Colors
	bold := color.New(color.Bold).SprintFunc()
	blue := color.New(color.FgBlue).SprintFunc()
	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()
	red := color.New(color.FgRed).SprintFunc()
	cyan := color.New(color.FgCyan).SprintFunc()

	fmt.Println()
	fmt.Println(bold(blue("Dotfiles Diff")))
	fmt.Println()

	// Get vault session
	session, err := getVaultSession(dotfilesDir)
	if err != nil {
		fmt.Printf("%s Bitwarden not unlocked\n", red("[ERROR]"))
		fmt.Println()
		fmt.Println("Run: export BW_SESSION=\"$(bw unlock --raw)\"")
		return fmt.Errorf("vault not unlocked")
	}

	if syncMode {
		return showSyncPreview(home, session, bold, green, yellow, blue)
	}

	if restoreMode {
		return showRestorePreview(home, session, bold, green, yellow, blue)
	}

	// Specific item or all items
	if len(args) > 0 {
		itemName := args[0]
		if relPath, ok := diffTrackedItems[itemName]; ok {
			return showDiff(itemName, filepath.Join(home, relPath), session, bold, green, yellow, red, cyan)
		}
		fmt.Printf("%s Unknown item: %s\n", red("[ERROR]"), itemName)
		fmt.Printf("Available: %s\n", strings.Join(getDiffItemNames(), ", "))
		return fmt.Errorf("unknown item: %s", itemName)
	}

	// Show all diffs
	for itemName, relPath := range diffTrackedItems {
		if err := showDiff(itemName, filepath.Join(home, relPath), session, bold, green, yellow, red, cyan); err != nil {
			// Continue with other items on error
			continue
		}
	}

	fmt.Println()
	return nil
}

func getVaultSession(dotfilesDir string) (string, error) {
	session := os.Getenv("BW_SESSION")
	if session == "" {
		sessionFile := filepath.Join(dotfilesDir, "vault", ".bw-session")
		if data, err := os.ReadFile(sessionFile); err == nil {
			session = strings.TrimSpace(string(data))
		}
	}

	if session == "" {
		return "", fmt.Errorf("no session available")
	}

	// Verify session is valid
	checkCmd := exec.Command("bw", "unlock", "--check", "--session", session)
	if err := checkCmd.Run(); err != nil {
		return "", fmt.Errorf("session invalid")
	}

	return session, nil
}

func getDiffItemNames() []string {
	names := make([]string, 0, len(diffTrackedItems))
	for name := range diffTrackedItems {
		names = append(names, name)
	}
	return names
}

func showDiff(itemName, localPath, session string, bold, green, yellow, red, cyan func(a ...interface{}) string) error {
	// Check if local file exists
	localContent, err := os.ReadFile(localPath)
	if err != nil {
		fmt.Printf("%s%s%s: Local file not found (%s)\n", yellow(""), itemName, "", localPath)
		return nil
	}

	// Get vault content
	vaultContent, err := getVaultNotes(itemName, session)
	if err != nil || vaultContent == "" {
		fmt.Printf("%s%s%s: Not found in Bitwarden\n", yellow(""), itemName, "")
		return nil
	}

	// Compare
	if string(localContent) == vaultContent {
		fmt.Printf("%s%s%s: In sync %s\n", green(""), itemName, "", green("✓"))
		return nil
	}

	// Show diff header
	fmt.Println()
	fmt.Printf("%s\n", bold(cyan(fmt.Sprintf("═══ %s ═══", itemName))))
	fmt.Printf("%sLocal file:%s %s\n", yellow(""), "", localPath)
	fmt.Println()

	// Create temp files for diff
	tempLocal, err := os.CreateTemp("", "diff-local-*")
	if err != nil {
		return err
	}
	defer os.Remove(tempLocal.Name())

	tempVault, err := os.CreateTemp("", "diff-vault-*")
	if err != nil {
		return err
	}
	defer os.Remove(tempVault.Name())

	tempLocal.WriteString(string(localContent))
	tempLocal.Close()
	tempVault.WriteString(vaultContent)
	tempVault.Close()

	// Show diff headers
	fmt.Printf("%s--- Bitwarden (vault)%s\n", red(""), "")
	fmt.Printf("%s+++ Local (file)%s\n", green(""), "")

	// Run diff command
	diffCmd := exec.Command("diff", "-u", tempVault.Name(), tempLocal.Name())
	output, _ := diffCmd.Output()

	// Skip the first 2 lines (file headers) and limit to 50 lines
	lines := strings.Split(string(output), "\n")
	if len(lines) > 2 {
		lines = lines[2:] // Skip --- and +++ headers from diff output
	}

	displayLines := lines
	if len(displayLines) > 50 {
		displayLines = displayLines[:50]
	}

	for _, line := range displayLines {
		if strings.HasPrefix(line, "+") {
			fmt.Println(green(line))
		} else if strings.HasPrefix(line, "-") {
			fmt.Println(red(line))
		} else if strings.HasPrefix(line, "@@") {
			fmt.Println(cyan(line))
		} else {
			fmt.Println(line)
		}
	}

	if len(lines) > 50 {
		fmt.Printf("%s... (%d more lines)%s\n", yellow(""), len(lines)-50, "")
	}

	fmt.Println()
	return nil
}

func showSyncPreview(home, session string, bold, green, yellow, blue func(a ...interface{}) string) error {
	fmt.Println(bold("Preview: What 'blackdot vault sync' would push to Bitwarden"))
	fmt.Println()

	for itemName, relPath := range diffTrackedItems {
		localPath := filepath.Join(home, relPath)

		localContent, err := os.ReadFile(localPath)
		if err != nil {
			continue // File doesn't exist locally
		}

		vaultContent, err := getVaultNotes(itemName, session)
		if err != nil || vaultContent == "" {
			fmt.Printf("  %s %s: Would CREATE in vault\n", green("+"), itemName)
		} else if string(localContent) != vaultContent {
			fmt.Printf("  %s %s: Would UPDATE in vault\n", yellow("~"), itemName)
		} else {
			fmt.Printf("  %s %s: No changes\n", blue("="), itemName)
		}
	}

	fmt.Println()
	return nil
}

func showRestorePreview(home, session string, bold, green, yellow, blue func(a ...interface{}) string) error {
	fmt.Println(bold("Preview: What 'blackdot vault restore' would change locally"))
	fmt.Println()

	for itemName, relPath := range diffTrackedItems {
		localPath := filepath.Join(home, relPath)

		vaultContent, err := getVaultNotes(itemName, session)
		if err != nil || vaultContent == "" {
			fmt.Printf("  %s %s: Not in vault (skip)\n", yellow("!"), itemName)
			continue
		}

		localContent, err := os.ReadFile(localPath)
		if err != nil {
			fmt.Printf("  %s %s: Would CREATE %s\n", green("+"), itemName, localPath)
		} else if string(localContent) != vaultContent {
			fmt.Printf("  %s %s: Would OVERWRITE %s\n", yellow("~"), itemName, localPath)
		} else {
			fmt.Printf("  %s %s: No changes\n", blue("="), itemName)
		}
	}

	fmt.Println()
	return nil
}
