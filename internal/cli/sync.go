package cli

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// Syncable items (matches bash SYNCABLE_ITEMS)
var syncableItems = map[string]string{
	"SSH-Config":          "",
	"AWS-Config":          "",
	"AWS-Credentials":     "",
	"Git-Config":          "",
	"Environment-Secrets": "",
}

// SyncDirection represents the direction of sync
type SyncDirection string

const (
	SyncInSync   SyncDirection = "in_sync"
	SyncPush     SyncDirection = "push"
	SyncPull     SyncDirection = "pull"
	SyncConflict SyncDirection = "conflict"
)

func init() {
	// Initialize paths based on home directory
	home, _ := os.UserHomeDir()
	syncableItems["SSH-Config"] = filepath.Join(home, ".ssh/config")
	syncableItems["AWS-Config"] = filepath.Join(home, ".aws/config")
	syncableItems["AWS-Credentials"] = filepath.Join(home, ".aws/credentials")
	syncableItems["Git-Config"] = filepath.Join(home, ".gitconfig")
	syncableItems["Environment-Secrets"] = filepath.Join(home, ".local/env.secrets")
}

func newSyncCmd() *cobra.Command {
	var dryRun bool
	var forceLocal bool
	var forceVault bool
	var verbose bool
	var all bool

	cmd := &cobra.Command{
		Use:   "sync [items...]",
		Short: "Bidirectional vault sync (smart push/pull)",
		Long: `Synchronize secrets between local machine and vault.

Uses smart detection to determine whether to push or pull:
  - If local changed since last sync → push to vault
  - If vault changed since last sync → pull from vault
  - If both changed → conflict (use --force-* to resolve)
  - If neither changed → skip (already in sync)

Items:
  SSH-Config, AWS-Config, AWS-Credentials, Git-Config, Environment-Secrets

Examples:
  blackdot sync --dry-run         # Preview all changes
  blackdot sync --all             # Sync everything
  blackdot sync Git-Config        # Sync just Git config
  blackdot sync --force-local     # Push all local to vault
  blackdot sync --force-vault     # Pull all vault to local`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runSync(args, dryRun, forceLocal, forceVault, verbose, all)
		},
	}

	cmd.Flags().BoolVarP(&dryRun, "dry-run", "n", false, "Show what would be synced without making changes")
	cmd.Flags().BoolVarP(&forceLocal, "force-local", "l", false, "Push all local changes to vault (overwrite vault)")
	cmd.Flags().BoolVarP(&forceVault, "force-vault", "v", false, "Pull all vault content to local (overwrite local)")
	cmd.Flags().BoolVar(&verbose, "verbose", false, "Show detailed comparison info")
	cmd.Flags().BoolVarP(&all, "all", "a", false, "Sync all syncable items")

	return cmd
}

func runSync(args []string, dryRun, forceLocal, forceVault, verbose, all bool) error {
	// Colors
	red := color.New(color.FgRed).SprintFunc()
	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()
	blue := color.New(color.FgBlue).SprintFunc()
	cyan := color.New(color.FgCyan).SprintFunc()

	// Validate conflicting flags
	if forceLocal && forceVault {
		fmt.Printf("%s Cannot use --force-local and --force-vault together\n", red("[ERROR]"))
		return fmt.Errorf("conflicting flags")
	}

	// Determine items to sync
	itemsToSync := args
	if all || len(args) == 0 {
		itemsToSync = getSyncableItemNames()
	} else {
		// Validate items
		for _, item := range args {
			if _, ok := syncableItems[item]; !ok {
				fmt.Printf("%s Unknown item: %s\n", red("[ERROR]"), item)
				fmt.Printf("Valid items: %s\n", strings.Join(getSyncableItemNames(), ", "))
				return fmt.Errorf("unknown item: %s", item)
			}
		}
	}

	home, _ := os.UserHomeDir()
	dotfilesDir := os.Getenv("BLACKDOT_DIR")
	if dotfilesDir == "" {
		dotfilesDir = filepath.Join(home, ".blackdot")
	}

	// Check offline mode
	if os.Getenv("BLACKDOT_OFFLINE") == "1" {
		fmt.Printf("%s BLACKDOT_OFFLINE=1 - Cannot sync in offline mode\n", yellow("[WARN]"))
		fmt.Println()
		fmt.Println("To sync later:")
		fmt.Println("  unset BLACKDOT_OFFLINE")
		fmt.Println("  blackdot sync")
		return nil
	}

	// Section header
	fmt.Println()
	fmt.Printf("%s%s── Blackdot Sync ──%s\n", "\033[1m", "\033[36m", "\033[0m")

	// Get vault session
	session, err := getVaultSession(dotfilesDir)
	if err != nil {
		fmt.Printf("%s Vault not unlocked\n", red("[ERROR]"))
		fmt.Println()
		fmt.Println("Run: export BW_SESSION=\"$(bw unlock --raw)\"")
		return fmt.Errorf("vault not unlocked")
	}

	// Determine backend name
	backendName := "Bitwarden"
	if _, err := exec.LookPath("pass"); err == nil {
		if os.Getenv("BLACKDOT_VAULT_BACKEND") == "pass" {
			backendName = "pass"
		}
	}

	fmt.Printf("%s Using vault backend: %s\n", blue("ℹ"), backendName)

	// Header
	fmt.Println()
	fmt.Println("========================================")
	fmt.Printf("Syncing %d items with %s\n", len(itemsToSync), backendName)
	if dryRun {
		fmt.Printf("%s\n", cyan("(DRY RUN - no changes will be made)"))
	}
	if forceLocal {
		fmt.Printf("%s\n", yellow("(FORCE LOCAL - pushing all to vault)"))
	}
	if forceVault {
		fmt.Printf("%s\n", yellow("(FORCE VAULT - pulling all from vault)"))
	}
	fmt.Println("========================================")
	fmt.Println()

	// Counters
	pushed := 0
	pulled := 0
	inSync := 0
	conflicts := 0
	failed := 0

	// Get drift state for baseline checksums
	driftStateFile := filepath.Join(os.Getenv("XDG_CACHE_HOME"), "blackdot", "vault-state.json")
	if driftStateFile == "/blackdot/vault-state.json" {
		driftStateFile = filepath.Join(home, ".cache", "blackdot", "vault-state.json")
	}

	// Process each item
	for _, itemName := range itemsToSync {
		localPath := syncableItems[itemName]
		fmt.Printf("%s--- %s ---%s\n", blue(""), itemName, "")
		fmt.Printf("    Local: %s\n", localPath)

		// Determine direction
		var direction SyncDirection
		if forceLocal {
			direction = SyncPush
		} else if forceVault {
			direction = SyncPull
		} else {
			direction = determineSyncDirection(itemName, localPath, session, driftStateFile, verbose)
		}

		switch direction {
		case SyncInSync:
			fmt.Printf("    %s Already in sync\n", green("✓"))
			inSync++

		case SyncPush:
			fmt.Printf("    %s Local → Vault\n", blue("ℹ"))
			if pushErr := pushToVault(itemName, localPath, session, dryRun, green, red); pushErr != nil {
				failed++
			} else {
				pushed++
			}

		case SyncPull:
			fmt.Printf("    %s Vault → Local\n", blue("ℹ"))
			if pullErr := pullFromVault(itemName, localPath, session, dryRun, green, red); pullErr != nil {
				failed++
			} else {
				pulled++
			}

		case SyncConflict:
			fmt.Printf("    %s CONFLICT: Both local and vault have changed\n", yellow("!"))
			fmt.Println("    Use --force-local to push local to vault")
			fmt.Println("    Use --force-vault to pull vault to local")
			conflicts++
		}

		fmt.Println()
	}

	// Summary
	fmt.Println("========================================")
	if dryRun {
		fmt.Printf("%s\n", cyan("DRY RUN SUMMARY:"))
		fmt.Printf("  Would push:  %d\n", pushed)
		fmt.Printf("  Would pull:  %d\n", pulled)
	} else {
		fmt.Println("SYNC SUMMARY:")
		fmt.Printf("  Pushed to vault:    %d\n", pushed)
		fmt.Printf("  Pulled from vault:  %d\n", pulled)
	}
	fmt.Printf("  Already in sync:    %d\n", inSync)
	if conflicts > 0 {
		fmt.Printf("  %sConflicts:            %d%s\n", yellow(""), conflicts, "")
	}
	if failed > 0 {
		fmt.Printf("  %sFailed:               %d%s\n", red(""), failed, "")
	}
	fmt.Println("========================================")

	// Update timestamps if not dry run
	if !dryRun && (pushed > 0 || pulled > 0) {
		timestamp := time.Now().UTC().Format("2006-01-02T15:04:05Z")
		updateSyncTimestamps(timestamp, pushed > 0, pulled > 0)

		// Save drift state
		saveDriftState(itemsToSync, session, driftStateFile)
	}

	// Provide guidance for conflicts
	if conflicts > 0 {
		fmt.Println()
		fmt.Println("To resolve conflicts:")
		fmt.Println("  blackdot sync --force-local   # Push your local changes")
		fmt.Println("  blackdot sync --force-vault   # Pull vault changes")
		fmt.Println("  blackdot drift                # See detailed differences")
	}

	// Exit codes
	if failed > 0 {
		return fmt.Errorf("%d sync operations failed", failed)
	}
	if conflicts > 0 && !forceLocal && !forceVault {
		return fmt.Errorf("%d conflicts detected", conflicts)
	}

	return nil
}

func getSyncableItemNames() []string {
	names := make([]string, 0, len(syncableItems))
	for name := range syncableItems {
		names = append(names, name)
	}
	return names
}

func calcChecksum(content string) string {
	hash := sha256.Sum256([]byte(content))
	return hex.EncodeToString(hash[:])
}

func getCachedChecksum(itemName, driftStateFile string) string {
	data, err := os.ReadFile(driftStateFile)
	if err != nil {
		return ""
	}

	var state map[string]interface{}
	if err := json.Unmarshal(data, &state); err != nil {
		return ""
	}

	items, ok := state["items"].(map[string]interface{})
	if !ok {
		return ""
	}

	item, ok := items[itemName].(map[string]interface{})
	if !ok {
		return ""
	}

	checksum, _ := item["checksum"].(string)
	return checksum
}

func determineSyncDirection(itemName, localPath, session, driftStateFile string, verbose bool) SyncDirection {
	// Get local content and checksum
	localContent := ""
	localChecksum := ""
	if data, err := os.ReadFile(localPath); err == nil {
		localContent = string(data)
		localChecksum = calcChecksum(localContent)
	}

	// Get vault content and checksum
	vaultContent, _ := getVaultNotes(itemName, session)
	vaultChecksum := ""
	if vaultContent != "" && vaultContent != "null" {
		vaultChecksum = calcChecksum(vaultContent)
	}

	// Get cached checksum (baseline from last sync)
	cachedChecksum := getCachedChecksum(itemName, driftStateFile)

	if verbose {
		fmt.Printf("    Local checksum:  %s\n", truncateChecksum(localChecksum))
		fmt.Printf("    Vault checksum:  %s\n", truncateChecksum(vaultChecksum))
		fmt.Printf("    Cached checksum: %s\n", truncateChecksum(cachedChecksum))
	}

	// Case 1: Both match - in sync
	if localChecksum == vaultChecksum {
		return SyncInSync
	}

	// Case 2: No cached state - use simple comparison
	if cachedChecksum == "" {
		if localChecksum == "" && vaultChecksum != "" {
			return SyncPull // Local missing, vault has content
		} else if localChecksum != "" && vaultChecksum == "" {
			return SyncPush // Vault missing, local has content
		} else {
			return SyncConflict // Both exist but differ, no baseline
		}
	}

	// Case 3: Cached state exists - determine which side changed
	localChanged := localChecksum != cachedChecksum
	vaultChanged := vaultChecksum != cachedChecksum

	if localChanged && !vaultChanged {
		return SyncPush
	} else if !localChanged && vaultChanged {
		return SyncPull
	} else if localChanged && vaultChanged {
		return SyncConflict
	}

	return SyncInSync
}

func truncateChecksum(checksum string) string {
	if checksum == "" {
		return "<missing>"
	}
	if len(checksum) > 16 {
		return checksum[:16] + "..."
	}
	return checksum
}

func pushToVault(itemName, localPath, session string, dryRun bool, green, red func(a ...interface{}) string) error {
	// Read local content
	data, err := os.ReadFile(localPath)
	if err != nil {
		fmt.Printf("    %s Local file not found: %s\n", red("✗"), localPath)
		return err
	}
	localContent := string(data)

	if dryRun {
		fmt.Printf("    %s Would push %s → vault:%s\n", green("→"), localPath, itemName)
		return nil
	}

	// Check if item exists in vault
	existingContent, _ := getVaultNotes(itemName, session)

	if existingContent != "" {
		// Update existing item
		if err := updateVaultItem(itemName, localContent, session); err != nil {
			fmt.Printf("    %s Failed to push %s\n", red("✗"), itemName)
			return err
		}
	} else {
		// Create new item
		if err := createVaultItem(itemName, localContent, session); err != nil {
			fmt.Printf("    %s Failed to create %s\n", red("✗"), itemName)
			return err
		}
	}

	fmt.Printf("    %s Pushed %s to vault\n", green("✓"), itemName)
	return nil
}

func pullFromVault(itemName, localPath, session string, dryRun bool, green, red func(a ...interface{}) string) error {
	// Get vault content
	vaultContent, err := getVaultNotes(itemName, session)
	if err != nil || vaultContent == "" || vaultContent == "null" {
		fmt.Printf("    %s No content in vault for %s\n", red("✗"), itemName)
		return fmt.Errorf("no vault content")
	}

	if dryRun {
		fmt.Printf("    %s Would pull vault:%s → %s\n", green("→"), itemName, localPath)
		return nil
	}

	// Create directory if needed
	parentDir := filepath.Dir(localPath)
	if err := os.MkdirAll(parentDir, 0755); err != nil {
		fmt.Printf("    %s Failed to create directory: %s\n", red("✗"), parentDir)
		return err
	}

	// Backup existing file
	if _, err := os.Stat(localPath); err == nil {
		backupPath := localPath + ".bak"
		os.Rename(localPath, backupPath)
	}

	// Write content with proper permissions
	if err := os.WriteFile(localPath, []byte(vaultContent), 0600); err != nil {
		fmt.Printf("    %s Failed to write %s\n", red("✗"), localPath)
		return err
	}

	fmt.Printf("    %s Pulled %s to %s\n", green("✓"), itemName, localPath)
	return nil
}

func updateVaultItem(itemName, content, session string) error {
	// Get item ID first
	getCmd := exec.Command("bw", "get", "item", itemName, "--session", session)
	output, err := getCmd.Output()
	if err != nil {
		return err
	}

	var item map[string]interface{}
	if err := json.Unmarshal(output, &item); err != nil {
		return err
	}

	itemID, ok := item["id"].(string)
	if !ok {
		return fmt.Errorf("no item ID found")
	}

	// Update notes
	item["notes"] = content

	// Encode and update
	updatedJSON, err := json.Marshal(item)
	if err != nil {
		return err
	}

	// Use bw encode | bw edit
	encodeCmd := exec.Command("bw", "encode")
	encodeCmd.Stdin = strings.NewReader(string(updatedJSON))
	encoded, err := encodeCmd.Output()
	if err != nil {
		return err
	}

	editCmd := exec.Command("bw", "edit", "item", itemID, "--session", session)
	editCmd.Stdin = strings.NewReader(string(encoded))
	_, err = editCmd.Output()
	return err
}

func createVaultItem(itemName, content, session string) error {
	// Create a secure note item
	item := map[string]interface{}{
		"type":           2, // Secure note
		"name":           itemName,
		"notes":          content,
		"secureNote":     map[string]interface{}{"type": 0},
		"organizationId": nil,
		"folderId":       nil,
	}

	itemJSON, err := json.Marshal(item)
	if err != nil {
		return err
	}

	// Use bw encode | bw create
	encodeCmd := exec.Command("bw", "encode")
	encodeCmd.Stdin = strings.NewReader(string(itemJSON))
	encoded, err := encodeCmd.Output()
	if err != nil {
		return err
	}

	createCmd := exec.Command("bw", "create", "item", "--session", session)
	createCmd.Stdin = strings.NewReader(string(encoded))
	_, err = createCmd.Output()
	return err
}

func updateSyncTimestamps(timestamp string, pushed, pulled bool) {
	home, _ := os.UserHomeDir()
	configFile := filepath.Join(home, ".config/blackdot/config.json")

	// Read existing config
	data, err := os.ReadFile(configFile)
	if err != nil {
		return
	}

	var config map[string]interface{}
	if err := json.Unmarshal(data, &config); err != nil {
		return
	}

	// Ensure vault section exists
	vault, ok := config["vault"].(map[string]interface{})
	if !ok {
		vault = make(map[string]interface{})
		config["vault"] = vault
	}

	// Update timestamps
	if pushed {
		vault["last_push"] = timestamp
	}
	if pulled {
		vault["last_pull"] = timestamp
	}
	vault["last_sync"] = timestamp

	// Write back
	updatedData, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return
	}
	os.WriteFile(configFile, updatedData, 0644)
}

func saveDriftState(items []string, session, driftStateFile string) {
	// Create cache directory
	cacheDir := filepath.Dir(driftStateFile)
	os.MkdirAll(cacheDir, 0755)

	// Build state
	state := map[string]interface{}{
		"timestamp": time.Now().UTC().Format(time.RFC3339),
		"items":     make(map[string]interface{}),
	}

	itemsMap := state["items"].(map[string]interface{})
	for _, itemName := range items {
		localPath := syncableItems[itemName]
		localChecksum := ""
		if data, err := os.ReadFile(localPath); err == nil {
			localChecksum = calcChecksum(string(data))
		}

		vaultContent, _ := getVaultNotes(itemName, session)
		vaultChecksum := ""
		if vaultContent != "" && vaultContent != "null" {
			vaultChecksum = calcChecksum(vaultContent)
		}

		// Use local checksum as baseline (after sync they should match)
		checksum := localChecksum
		if checksum == "" {
			checksum = vaultChecksum
		}

		itemsMap[itemName] = map[string]interface{}{
			"checksum":   checksum,
			"local_path": localPath,
			"synced_at":  time.Now().UTC().Format(time.RFC3339),
		}
	}

	// Write state
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return
	}
	os.WriteFile(driftStateFile, data, 0644)
}
