package cli

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// Drift items to track (matches bash implementation)
var driftTrackedFiles = map[string]string{
	"SSH-Config":           ".ssh/config",
	"AWS-Config":           ".aws/config",
	"AWS-Credentials":      ".aws/credentials",
	"Git-Config":           ".gitconfig",
	"Environment-Secrets":  ".local/env.secrets",
	"Template-Variables":   ".config/dotfiles/template-variables.sh",
	"Claude-Profiles":      ".claude/profiles.json",
}

// DriftState represents the cached vault state
type DriftState struct {
	Timestamp string                    `json:"timestamp"`
	Hostname  string                    `json:"hostname"`
	Files     map[string]DriftFileState `json:"files"`
}

// DriftFileState represents state for a single file
type DriftFileState struct {
	Path     string `json:"path"`
	Checksum string `json:"checksum"`
}

func newDriftCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "drift",
		Short: "Compare local files vs vault",
		Long: `Compare local configuration files against vault.

Modes:
  (default)   Full check - connects to vault and compares
  --quick, -q Fast check against cached state (no vault access)

The quick mode compares local files against the last vault pull.
Full mode connects to vault and compares current vault contents.

Examples:
  dotfiles drift          # Full check (connects to vault)
  dotfiles drift --quick  # Fast check against cached state`,
		RunE: runDrift,
	}

	cmd.Flags().BoolP("quick", "q", false, "Fast check against cached state (no vault access)")

	return cmd
}

func runDrift(cmd *cobra.Command, args []string) error {
	quickMode, _ := cmd.Flags().GetBool("quick")

	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("cannot determine home directory: %w", err)
	}

	// Colors
	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()
	cyan := color.New(color.FgCyan).SprintFunc()
	dim := color.New(color.Faint).SprintFunc()

	if quickMode {
		return runDriftQuick(home, green, yellow, dim)
	}

	return runDriftFull(home, green, yellow, cyan, dim)
}

// runDriftQuick performs a quick drift check against cached state
func runDriftQuick(home string, green, yellow, dim func(a ...interface{}) string) error {
	cacheDir := os.Getenv("XDG_CACHE_HOME")
	if cacheDir == "" {
		cacheDir = filepath.Join(home, ".cache")
	}
	stateFile := filepath.Join(cacheDir, "dotfiles", "vault-state.json")

	// Check if state file exists
	if _, err := os.Stat(stateFile); os.IsNotExist(err) {
		fmt.Println("No drift state available. Run 'dotfiles vault pull' first.")
		return nil
	}

	// Load state
	state, err := loadDriftState(stateFile)
	if err != nil {
		return fmt.Errorf("loading drift state: %w", err)
	}

	fmt.Println("Drift Check (local vs last vault pull)")
	fmt.Println("=======================================")
	fmt.Printf("Last sync: %s\n", state.Timestamp)
	fmt.Println()

	driftCount := 0
	checkedCount := 0

	for itemName, relPath := range driftTrackedFiles {
		filePath := filepath.Join(home, relPath)

		// Get cached checksum
		fileState, ok := state.Files[itemName]
		if !ok {
			continue
		}

		checkedCount++
		currentChecksum := fileChecksum(filePath)

		if fileState.Checksum == currentChecksum {
			fmt.Printf("%s %s: in sync\n", green("✓"), itemName)
		} else if currentChecksum == "MISSING" {
			fmt.Printf("%s %s: file missing (was synced)\n", yellow("!"), itemName)
			driftCount++
		} else {
			fmt.Printf("%s %s: CHANGED locally\n", yellow("✗"), itemName)
			driftCount++
		}
	}

	fmt.Println()
	if driftCount == 0 {
		fmt.Printf("%s\n", green(fmt.Sprintf("All %d items in sync with last vault pull", checkedCount)))
	} else {
		fmt.Printf("%s\n", yellow(fmt.Sprintf("%d of %d items have local changes", driftCount, checkedCount)))
		fmt.Println()
		fmt.Println("Options:")
		fmt.Println("  dotfiles vault push --all  # Push local changes to vault")
		fmt.Println("  dotfiles vault pull        # Overwrite local with vault")
	}

	return nil
}

// runDriftFull performs a full drift check against vault
func runDriftFull(home string, green, yellow, cyan, dim func(a ...interface{}) string) error {
	dotfilesDir := os.Getenv("DOTFILES_DIR")
	if dotfilesDir == "" {
		dotfilesDir = filepath.Join(home, ".dotfiles")
	}

	// For full mode, we'd need to connect to vault
	// This requires the vault abstraction which isn't fully ported to Go yet
	// For now, we'll show a message and suggest using quick mode or bash version

	fmt.Println()
	fmt.Println(color.New(color.Bold).Sprint("Drift Detection"))
	fmt.Println()

	// Check for vault session
	vaultSessionFile := filepath.Join(dotfilesDir, "vault", ".bw-session")
	bwSession := os.Getenv("BW_SESSION")
	if bwSession == "" {
		if data, err := os.ReadFile(vaultSessionFile); err == nil {
			bwSession = string(data)
		}
	}

	if bwSession == "" {
		fmt.Printf("%s Vault not unlocked - cannot check drift\n", yellow("[WARN]"))
		fmt.Println()
		fmt.Printf("%s For quick local check: dotfiles drift --quick\n", cyan("[INFO]"))
		fmt.Printf("%s To unlock vault: export BW_SESSION=\"$(bw unlock --raw)\"\n", cyan("[INFO]"))
		return nil
	}

	// Perform drift check against vault
	fmt.Printf("%s Checking drift against vault...\n", cyan("[INFO]"))
	fmt.Println()

	driftCount := 0
	checkedCount := 0

	for itemName, relPath := range driftTrackedFiles {
		filePath := filepath.Join(home, relPath)

		// Check if local file exists
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			fmt.Printf("%s %s: local file not found (%s)\n", cyan("[INFO]"), itemName, filePath)
			continue
		}

		// Get vault content using bw CLI
		vaultContent, err := getVaultNotes(itemName, bwSession)
		if err != nil || vaultContent == "" {
			fmt.Printf("%s %s: not found in vault\n", cyan("[INFO]"), itemName)
			continue
		}

		checkedCount++

		// Compare
		localContent, err := os.ReadFile(filePath)
		if err != nil {
			fmt.Printf("%s %s: error reading file: %v\n", yellow("[WARN]"), itemName, err)
			continue
		}

		if string(localContent) == vaultContent {
			fmt.Printf("%s %s: in sync\n", green("[OK]"), itemName)
		} else {
			fmt.Printf("%s %s: LOCAL DIFFERS from vault\n", yellow("[WARN]"), itemName)
			driftCount++
		}
	}

	fmt.Println()
	fmt.Println("========================================")
	if driftCount == 0 {
		fmt.Printf("%s\n", green(fmt.Sprintf("All %d checked items are in sync", checkedCount)))
	} else {
		fmt.Printf("%s\n", yellow(fmt.Sprintf("%d of %d items have drifted", driftCount, checkedCount)))
		fmt.Println()
		fmt.Printf("%s To sync local changes to vault:\n", cyan("[INFO]"))
		fmt.Println("  dotfiles vault sync --all")
		fmt.Println()
		fmt.Printf("%s To restore from vault (overwrite local):\n", cyan("[INFO]"))
		fmt.Println("  dotfiles vault restore")
	}
	fmt.Println("========================================")

	return nil
}

// loadDriftState loads the cached drift state
func loadDriftState(path string) (*DriftState, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var state DriftState
	if err := json.Unmarshal(data, &state); err != nil {
		return nil, err
	}

	return &state, nil
}

// fileChecksum returns SHA256 checksum of a file, or "MISSING" if not found
func fileChecksum(path string) string {
	file, err := os.Open(path)
	if err != nil {
		return "MISSING"
	}
	defer file.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil {
		return "ERROR"
	}

	return hex.EncodeToString(hash.Sum(nil))
}

// getVaultNotes retrieves notes content from Bitwarden
func getVaultNotes(itemName, session string) (string, error) {
	if session == "" {
		return "", fmt.Errorf("no session")
	}

	cmd := exec.Command("bw", "get", "notes", itemName, "--session", session)
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}

	return string(output), nil
}
