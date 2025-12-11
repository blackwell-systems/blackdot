package cli

import (
	"bufio"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/blackwell-systems/blackdot/internal/config"
	"github.com/blackwell-systems/vaultmux"
	_ "github.com/blackwell-systems/vaultmux/backends/bitwarden"
	_ "github.com/blackwell-systems/vaultmux/backends/onepassword"
	_ "github.com/blackwell-systems/vaultmux/backends/pass"
	"github.com/spf13/cobra"
)

// getVaultBackend returns the configured backend type
func getVaultBackend() vaultmux.BackendType {
	// Check env var first
	if backend := os.Getenv("BLACKDOT_VAULT_BACKEND"); backend != "" {
		return vaultmux.BackendType(backend)
	}

	// Check config file
	cfg := config.DefaultManager()
	if val, err := cfg.Get("vault.backend"); err == nil && val != "" {
		return vaultmux.BackendType(val)
	}

	// Default to bitwarden
	return vaultmux.BackendBitwarden
}

// getSessionFile returns the session cache file path
func getSessionFile() string {
	if file := os.Getenv("VAULT_SESSION_FILE"); file != "" {
		return file
	}
	return filepath.Join(BlackdotDir(), "vault", ".vault-session")
}

// newVaultBackend creates a new vault backend with config
func newVaultBackend() (vaultmux.Backend, error) {
	backendType := getVaultBackend()

	cfg := vaultmux.Config{
		Backend:     backendType,
		SessionFile: getSessionFile(),
		SessionTTL:  1800, // 30 minutes
		Prefix:      "blackdot",
	}

	return vaultmux.New(cfg)
}

func newVaultCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "vault",
		Short: "Manage secrets vault",
		Long:  `Secret vault operations`,
		Run: func(cmd *cobra.Command, args []string) {
			printVaultHelp()
		},
	}

	// Override help only for the parent vault command
	// Subcommands will use their default cobra help with flags
	defaultHelp := cmd.HelpFunc()
	cmd.SetHelpFunc(func(c *cobra.Command, args []string) {
		if c.Name() == "vault" && len(args) == 0 {
			printVaultHelp()
		} else {
			defaultHelp(c, args)
		}
	})

	cmd.AddCommand(
		newVaultStatusCmd(),
		newVaultUnlockCmd(),
		newVaultLockCmd(),
		newVaultListCmd(),
		newVaultBackendCmd(),
		newVaultSyncCmd(),
		newVaultGetCmd(),
		newVaultHealthCmd(),
		newVaultQuickCmd(),
		newVaultRestoreCmd(),
		newVaultPushCmd(),
		newVaultScanCmd(),
		newVaultCheckCmd(),
		newVaultValidateCmd(),
		newVaultInitCmd(),
		newVaultCreateCmd(),
		newVaultDeleteCmd(),
	)

	return cmd
}

// newSecretsCmd creates a hidden alias for vault command
// This provides compatibility with ZSH where 'secrets' is an alias for 'vault'
func newSecretsCmd() *cobra.Command {
	cmd := newVaultCmd()
	cmd.Use = "secrets"
	cmd.Short = "Alias for vault (manage secrets)"
	cmd.Hidden = true // Don't clutter help, but still works
	return cmd
}

func newVaultStatusCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show vault status",
		Long:  `Show vault connection status, authentication state, and session info.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return vaultStatus()
		},
	}
}

func newVaultUnlockCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "unlock",
		Short: "Unlock vault and cache session",
		Long:  `Authenticate with the vault backend and cache the session token.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return vaultUnlock()
		},
	}
}

func newVaultLockCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "lock",
		Short: "Lock vault (clear cached session)",
		Long:  `Clear the cached session token, requiring re-authentication.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return vaultLock()
		},
	}
}

func newVaultListCmd() *cobra.Command {
	var jsonOutput bool
	var location string

	cmd := &cobra.Command{
		Use:   "list",
		Short: "List vault items",
		Long:  `List all items in the vault or in a specific location/folder.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return vaultList(jsonOutput, location)
		},
	}

	cmd.Flags().BoolVarP(&jsonOutput, "json", "j", false, "output as JSON")
	cmd.Flags().StringVarP(&location, "location", "l", "", "filter by location/folder")

	return cmd
}

func newVaultBackendCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "backend [name]",
		Short: "Show or set vault backend",
		Long: `Show the current vault backend or set a new one.

Available backends:
  bitwarden  - Bitwarden CLI (bw)
  1password  - 1Password CLI (op)
  pass       - pass (GPG-based password manager)`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 {
				return showBackend()
			}
			return setBackend(args[0])
		},
	}

	return cmd
}

func newVaultSyncCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "sync",
		Short: "Sync vault with remote",
		Long:  `Pull latest changes from the vault remote server.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return vaultSync()
		},
	}
}

func newVaultGetCmd() *cobra.Command {
	var outputNotes bool

	cmd := &cobra.Command{
		Use:   "get <item-name>",
		Short: "Get a vault item",
		Long:  `Retrieve an item from the vault by name.`,
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return vaultGet(args[0], outputNotes)
		},
	}

	cmd.Flags().BoolVarP(&outputNotes, "notes", "n", false, "output only the notes field")

	return cmd
}

func newVaultHealthCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "health",
		Short: "Run vault health check",
		Long:  `Check vault backend availability and authentication status.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return vaultHealth()
		},
	}
}

func newVaultQuickCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "quick",
		Short: "Quick status check (login/unlock only)",
		Long: `Quick vault status check - only checks if vault is accessible.

This is faster than 'vault status' as it skips drift detection
and other detailed checks.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return vaultQuick()
		},
	}
}

func newVaultRestoreCmd() *cobra.Command {
	var force bool
	var dryRun bool

	cmd := &cobra.Command{
		Use:     "restore",
		Aliases: []string{"pull"},
		Short:   "Restore secrets from vault to local",
		Long: `Restore secrets from vault to local machine.

Restores:
  - SSH keys and config
  - AWS credentials
  - Git configuration
  - Environment secrets

Options:
  --force, -f    Skip drift check and overwrite local changes
  --dry-run, -n  Show what would be restored without making changes`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return vaultRestore(force, dryRun)
		},
	}

	cmd.Flags().BoolVarP(&force, "force", "f", false, "Skip drift check and overwrite local changes")
	cmd.Flags().BoolVarP(&dryRun, "dry-run", "n", false, "Show what would be restored")

	return cmd
}

func newVaultPushCmd() *cobra.Command {
	var force bool
	var dryRun bool
	var all bool

	cmd := &cobra.Command{
		Use:   "push [items...]",
		Short: "Push local secrets to vault",
		Long: `Push local secrets to vault.

Items:
  SSH-Config, AWS-Config, AWS-Credentials, Git-Config, Environment-Secrets

Options:
  --force, -f    Overwrite vault content without confirmation
  --dry-run, -n  Show what would be pushed without making changes
  --all, -a      Push all items`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return vaultPush(args, force, dryRun, all)
		},
	}

	cmd.Flags().BoolVarP(&force, "force", "f", false, "Overwrite vault without confirmation")
	cmd.Flags().BoolVarP(&dryRun, "dry-run", "n", false, "Show what would be pushed")
	cmd.Flags().BoolVarP(&all, "all", "a", false, "Push all items")

	return cmd
}

func newVaultScanCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "scan",
		Short: "Scan for local secrets to add to vault",
		Long: `Scan for local secrets that could be added to vault.

Discovers:
  - SSH keys in ~/.ssh/
  - AWS credentials in ~/.aws/
  - Git configuration
  - Environment files`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return vaultScan()
		},
	}
}

func newVaultCheckCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "check",
		Short: "Check required vault items exist",
		Long: `Check that all required vault items exist.

Verifies items defined in vault-items.json exist in the vault.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return vaultCheck()
		},
	}
}

func newVaultValidateCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "validate",
		Short: "Validate vault-items.json schema",
		Long: `Validate the vault-items.json configuration file.

Checks:
  - JSON syntax
  - Required fields
  - Path validity
  - Item name format`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return vaultValidate()
		},
	}
}

func newVaultInitCmd() *cobra.Command {
	return &cobra.Command{
		Use:     "init",
		Aliases: []string{"setup"},
		Short:   "Initialize vault setup",
		Long:    `Interactive vault setup wizard.

Steps:
  1. Select vault backend (bitwarden, 1password, pass)
  2. Verify CLI tool is installed
  3. Test authentication
  4. Create vault-items.json if missing`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return vaultInit()
		},
	}
}

func newVaultCreateCmd() *cobra.Command {
	var dryRun bool
	var force bool
	var fromFile string

	cmd := &cobra.Command{
		Use:   "create <item-name> [content]",
		Short: "Create a new vault item",
		Long: `Create a new Secure Note item in the vault.

Content can be provided as:
  - An argument: blackdot vault create My-Item "content here"
  - From a file: blackdot vault create My-Item --file ~/path/to/file
  - From stdin: echo "content" | blackdot vault create My-Item

Options:
  --dry-run, -n  Show what would be created without making changes
  --force, -f    Overwrite if item already exists
  --file         Read content from file

Examples:
  blackdot vault create API-Key "sk-1234567890"
  blackdot vault create SSH-Config --file ~/.ssh/config
  blackdot vault create --dry-run Git-Config --file ~/.gitconfig`,
		Args: cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			name := args[0]
			var content string

			if fromFile != "" {
				// Read from file
				data, err := os.ReadFile(fromFile)
				if err != nil {
					return fmt.Errorf("failed to read file: %w", err)
				}
				content = string(data)
			} else if len(args) > 1 {
				// Content provided as argument
				content = args[1]
			} else {
				// Read from stdin
				stat, _ := os.Stdin.Stat()
				if (stat.Mode() & os.ModeCharDevice) == 0 {
					data, err := io.ReadAll(os.Stdin)
					if err != nil {
						return fmt.Errorf("failed to read stdin: %w", err)
					}
					content = string(data)
				} else {
					return fmt.Errorf("content required: provide as argument, --file, or stdin")
				}
			}

			return vaultCreate(name, content, dryRun, force)
		},
	}

	cmd.Flags().BoolVarP(&dryRun, "dry-run", "n", false, "Show what would be created")
	cmd.Flags().BoolVarP(&force, "force", "f", false, "Overwrite if item exists")
	cmd.Flags().StringVar(&fromFile, "file", "", "Read content from file")

	return cmd
}

func newVaultDeleteCmd() *cobra.Command {
	var dryRun bool
	var force bool

	cmd := &cobra.Command{
		Use:   "delete <item-name>...",
		Short: "Delete vault items",
		Long: `Delete items from the vault.

WARNING: Deletion is permanent and cannot be undone.

Protected items (SSH-*, AWS-*, Git-Config, Environment-Secrets) require
typing the item name to confirm, even with --force.

Options:
  --dry-run, -n  Show what would be deleted without making changes
  --force, -f    Skip confirmation prompts (except protected items)

Examples:
  blackdot vault delete TEST-NOTE
  blackdot vault delete --dry-run OLD-KEY
  blackdot vault delete --force TEMP-1 TEMP-2 TEMP-3`,
		Args: cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return vaultDelete(args, dryRun, force)
		},
	}

	cmd.Flags().BoolVarP(&dryRun, "dry-run", "n", false, "Show what would be deleted")
	cmd.Flags().BoolVarP(&force, "force", "f", false, "Skip confirmation prompts")

	return cmd
}

// ============================================================
// Help Functions
// ============================================================

// printVaultHelp prints styled help matching ZSH vault help exactly
func printVaultHelp() {
	// Title
	BoldCyan.Print("blackdot vault")
	fmt.Print(" - Secret vault operations\n")
	fmt.Println()

	// Usage
	Bold.Print("Usage:")
	fmt.Print(" blackdot vault <command> [options]\n")
	fmt.Println()

	// Session section
	BoldCyan.Println("Session:")
	printCmd("unlock", "Unlock vault and cache session")
	printCmd("lock", "Lock vault (clear cached session)")
	printCmd("status", "Full vault status with drift detection")
	printCmd("quick", "Quick status check (login/unlock only)")
	fmt.Println()

	// Sync section
	BoldCyan.Println("Sync:")
	printCmd("restore", "Pull secrets FROM vault to local")
	printCmd("push", "Push secrets TO vault")
	printCmd("sync", "Bidirectional sync (smart direction)")
	fmt.Println()

	// Items section
	BoldCyan.Println("Items:")
	printCmd("list", "List vault items")
	printCmd("create", "Create a new vault item")
	printCmd("delete", "Delete vault item(s)")
	printCmd("scan", "Re-scan for new secrets (updates config)")
	printCmd("check", "Check required vault items exist")
	fmt.Println()

	// Config section
	BoldCyan.Println("Config:")
	printCmd("validate", "Validate vault-items.json schema")
	printCmd("backend", "Show or set vault backend")
	printCmd("init", "Initialize vault setup")
	fmt.Println()

	// Examples
	BoldCyan.Println("Examples:")
	Dim.Println("  # Unlock vault")
	fmt.Println("  blackdot vault unlock")
	fmt.Println()
	Dim.Println("  # Check status")
	fmt.Println("  blackdot vault status")
	fmt.Println()
	Dim.Println("  # Pull secrets from vault")
	fmt.Println("  blackdot vault restore")
	fmt.Println()
	Dim.Println("  # Push local changes")
	fmt.Println("  blackdot vault push --all")
	fmt.Println()

	// Typical Workflow
	BoldCyan.Println("Typical Workflow:")
	Dim.Println("  First time:   blackdot vault init      → Choose backend & discover secrets")
	Dim.Println("  Unlock:       blackdot vault unlock    → Unlock vault for operations")
	Dim.Println("  Add secrets:  blackdot vault push      → Push local changes to vault")
	Dim.Println("  New machine:  blackdot vault restore   → Pull secrets from vault")
	Dim.Println("  Re-scan:      blackdot vault scan      → Find new SSH keys/configs")
}

// ============================================================
// Implementation Functions
// ============================================================

func vaultStatus() error {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	fmt.Println()
	BoldCyan.Println("╔═══════════════════════════════════════════════════════╗")
	BoldCyan.Println("║           Vault Status & Sync Summary                 ║")
	BoldCyan.Println("╚═══════════════════════════════════════════════════════╝")
	fmt.Println()

	// Section 1: Vault Backend Configuration
	BoldCyan.Println("Vault Backend")
	fmt.Println("─────────────")

	backendType := getVaultBackend()
	sessionFile := getSessionFile()

	backend, err := newVaultBackend()
	if err != nil {
		Fail("No vault backend configured")
		fmt.Println()
		fmt.Printf("  %s blackdot vault init\n", Green.Sprint("Setup:"))
		return err
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		Fail("Backend CLI not available: %v", err)
		return err
	}

	Pass("Backend: %s", backend.Name())

	// Check authentication
	authenticated := backend.IsAuthenticated(ctx)
	if authenticated {
		Pass("Logged in: Yes")

		// Check session file
		if info, err := os.Stat(sessionFile); err == nil {
			Pass("Session cached: %s (%d bytes)", info.ModTime().Format("15:04:05"), info.Size())
		} else {
			Warn("Vault locked (session expired)")
			fmt.Println()
			fmt.Printf("  %s blackdot vault unlock\n", Green.Sprint("Unlock:"))
		}
	} else {
		Fail("Not logged in to %s", backendType)
		fmt.Println()
		switch backendType {
		case vaultmux.BackendBitwarden:
			fmt.Printf("  %s bw login && blackdot vault unlock\n", Green.Sprint("Login:"))
		case vaultmux.BackendOnePassword:
			fmt.Printf("  %s blackdot vault unlock\n", Green.Sprint("Login:"))
		default:
			fmt.Printf("  %s blackdot vault unlock\n", Green.Sprint("Login:"))
		}
		return fmt.Errorf("not authenticated")
	}

	fmt.Println()

	// Section 2: Vault Items Summary
	BoldCyan.Println("Vault Items")
	fmt.Println("───────────")

	vaultItems, err := loadVaultItems()
	if err == nil {
		Pass("Config items: %d", len(vaultItems))

		sshCount := 0
		for _, item := range vaultItems {
			if item.Type == "sshkey" {
				sshCount++
			}
		}
		if sshCount > 0 {
			Pass("SSH keys: %d", sshCount)
		}

		// List items
		fmt.Println()
		Dim.Println("  Configured vault items:")
		count := 0
		for name := range vaultItems {
			if count < 10 {
				fmt.Printf("    • %s\n", name)
			}
			count++
		}
		if count > 10 {
			Dim.Printf("    ... and %d more\n", count-10)
		}
	} else {
		Warn("No vault items configured")
		fmt.Println()
		fmt.Printf("  %s blackdot vault scan\n", Green.Sprint("Scan:"))
	}

	fmt.Println()

	// Section 3: Last Sync Timestamp
	BoldCyan.Println("Sync History")
	fmt.Println("────────────")

	cfg := config.DefaultManager()
	lastPull, _ := cfg.Get("vault.last_pull")
	lastPush, _ := cfg.Get("vault.last_push")

	if lastPull != "" {
		Pass("Last pull: %s", formatTimeAgo(lastPull))
	} else {
		Info("Last pull: Never (or not tracked)")
	}

	if lastPush != "" {
		Pass("Last push: %s", formatTimeAgo(lastPush))
	} else {
		Info("Last push: Never (or not tracked)")
	}

	fmt.Println()

	// Section 4: Drift Detection
	if authenticated && vaultItems != nil {
		BoldCyan.Println("Drift Detection (Local vs Vault)")
		fmt.Println("─────────────────────────────────")

		session, err := backend.Authenticate(ctx)
		if err == nil {
			driftCount := 0
			missingVault := 0
			missingLocal := 0
			checkedCount := 0
			var driftedItems []string

			for name, item := range vaultItems {
				localPath := expandPath(item.Path)

				// Check if local file exists
				if _, err := os.Stat(localPath); os.IsNotExist(err) {
					missingLocal++
					continue
				}

				// Get vault content
				vaultContent, err := backend.GetNotes(ctx, name, session)
				if err != nil {
					if errors.Is(err, vaultmux.ErrNotFound) {
						Warn("%s: exists locally but not in vault", name)
						missingVault++
						driftedItems = append(driftedItems, name)
					}
					continue
				}

				checkedCount++

				// Compare content
				driftStatus := checkItemDrift(localPath, vaultContent)
				if driftStatus == 1 {
					Warn("%s: ⚠ DIFFERS from vault", name)
					driftCount++
					driftedItems = append(driftedItems, name)
				} else {
					Pass("%s: ✓ in sync", name)
				}
			}

			fmt.Println()
			fmt.Println("═══════════════════════════════════════════════════════")
			fmt.Println()

			if driftCount == 0 && missingVault == 0 {
				Green.Println("  ✓ All items in sync!")
				fmt.Println()
				fmt.Printf("  %d items checked, no drift detected\n", checkedCount)
			} else {
				if driftCount > 0 {
					Yellow.Printf("  ⚠ Drift detected: %d items differ\n", driftCount)
				}
				if missingVault > 0 {
					Yellow.Printf("  ⚠ Not in vault: %d items\n", missingVault)
				}
				fmt.Println()

				Bold.Println("  Affected items:")
				for _, item := range driftedItems {
					fmt.Printf("    • %s\n", item)
				}
			}

			if missingLocal > 0 {
				fmt.Println()
				Dim.Printf("  %d items not found locally (not installed yet)\n", missingLocal)
			}

			fmt.Println()
			fmt.Println("═══════════════════════════════════════════════════════")
			fmt.Println()

			// Next Actions
			if driftCount > 0 || missingVault > 0 {
				Bold.Println("Next Actions:")
				fmt.Println()

				if driftCount > 0 {
					Cyan.Println("  Option 1: Save local changes to vault")
					fmt.Printf("    %s blackdot vault push --all\n", Green.Sprint("→"))
					fmt.Println()
				}

				if missingVault > 0 {
					Cyan.Println("  Option 2: Scan and push new items to vault")
					fmt.Printf("    %s blackdot vault scan\n", Green.Sprint("→"))
					fmt.Printf("    %s blackdot vault push --all\n", Green.Sprint("→"))
					fmt.Println()
				}

				if driftCount > 0 {
					Cyan.Println("  Option 3: Restore from vault (discard local changes)")
					fmt.Printf("    %s blackdot backup create  %s\n", Green.Sprint("→"), Dim.Sprint("# Safety first"))
					fmt.Printf("    %s blackdot vault restore --force\n", Green.Sprint("→"))
					fmt.Println()
				}

				Cyan.Println("  Option 4: View detailed diff")
				fmt.Printf("    %s blackdot drift\n", Green.Sprint("→"))
				fmt.Println()
			}
		}
	}

	return nil
}

// formatTimeAgo formats a timestamp as a human-readable time ago string
func formatTimeAgo(timestamp string) string {
	t, err := time.Parse(time.RFC3339, timestamp)
	if err != nil {
		return timestamp
	}

	secondsAgo := int(time.Since(t).Seconds())

	if secondsAgo < 3600 {
		minutesAgo := secondsAgo / 60
		return fmt.Sprintf("%dm ago (%s)", minutesAgo, timestamp)
	} else if secondsAgo < 86400 {
		hoursAgo := secondsAgo / 3600
		return fmt.Sprintf("%dh ago (%s)", hoursAgo, timestamp)
	} else {
		daysAgo := secondsAgo / 86400
		return fmt.Sprintf("%dd ago (%s)", daysAgo, timestamp)
	}
}

func vaultUnlock() error {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	backend, err := newVaultBackend()
	if err != nil {
		Fail("Failed to create backend: %v", err)
		return err
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		Fail("Backend not available: %v", err)
		return err
	}

	Info("Unlocking %s vault...", backend.Name())

	session, err := backend.Authenticate(ctx)
	if err != nil {
		Fail("Authentication failed: %v", err)
		return err
	}

	Pass("Vault unlocked")

	// Debug: show if session file was created by vaultmux
	sessionFile := getSessionFile()
	if info, err := os.Stat(sessionFile); err == nil {
		Info("Session cached: %s (%d bytes)", sessionFile, info.Size())
	} else {
		// vaultmux didn't save - try manual fallback
		Warn("Session file not created by vaultmux, saving manually...")
		token := session.Token()
		if token != "" {
			if err := os.MkdirAll(filepath.Dir(sessionFile), 0700); err != nil {
				Warn("Failed to create session directory: %v", err)
			} else if err := os.WriteFile(sessionFile, []byte(token), 0600); err != nil {
				Warn("Failed to save session: %v", err)
			} else {
				Info("Session saved manually")
			}
		} else {
			Warn("Session token is empty - cannot cache")
		}
	}

	if !session.ExpiresAt().IsZero() {
		Info("Session expires: %s", session.ExpiresAt().Format(time.RFC3339))
	}

	return nil
}

func vaultLock() error {
	// Clear the session file
	sessionFile := getSessionFile()

	if _, err := os.Stat(sessionFile); os.IsNotExist(err) {
		Info("No cached session to clear")
		return nil
	}

	if err := os.Remove(sessionFile); err != nil {
		Fail("Failed to clear session: %v", err)
		return err
	}

	Pass("Vault locked (session cleared)")
	return nil
}

func vaultList(jsonOutput bool, location string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	backend, err := newVaultBackend()
	if err != nil {
		Fail("Failed to create backend: %v", err)
		return err
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		Fail("Backend not available: %v", err)
		return err
	}

	session, err := backend.Authenticate(ctx)
	if err != nil {
		Fail("Authentication required: %v", err)
		return err
	}

	var items []*vaultmux.Item
	if location != "" {
		items, err = backend.ListItemsInLocation(ctx, "folder", location, session)
	} else {
		items, err = backend.ListItems(ctx, session)
	}

	if err != nil {
		Fail("Failed to list items: %v", err)
		return err
	}

	if jsonOutput {
		data, _ := json.MarshalIndent(items, "", "  ")
		fmt.Println(string(data))
		return nil
	}

	if len(items) == 0 {
		Info("No items found")
		return nil
	}

	PrintHeader("Vault Items")

	for _, item := range items {
		loc := item.Location
		if loc == "" {
			loc = "(root)"
		}
		fmt.Printf("  %-30s %s\n", item.Name, Dim.Sprintf("[%s]", loc))
	}

	fmt.Println()
	Info("Total: %d items", len(items))

	return nil
}

func showBackend() error {
	backendType := getVaultBackend()

	fmt.Printf("Current backend: %s\n", backendType)
	fmt.Println()
	fmt.Println("Available backends:")
	fmt.Println("  bitwarden  - Bitwarden CLI (bw)")
	fmt.Println("  1password  - 1Password CLI (op)")
	fmt.Println("  pass       - pass (GPG-based password manager)")

	return nil
}

func setBackend(name string) error {
	// Validate backend name
	switch vaultmux.BackendType(name) {
	case vaultmux.BackendBitwarden, vaultmux.BackendOnePassword, vaultmux.BackendPass:
		// Valid
	default:
		Fail("Unknown backend: %s", name)
		fmt.Println()
		fmt.Println("Available backends: bitwarden, 1password, pass")
		return fmt.Errorf("unknown backend: %s", name)
	}

	// Save to config
	cfg := config.DefaultManager()
	if err := cfg.Set("vault.backend", name); err != nil {
		Fail("Failed to save config: %v", err)
		return err
	}

	Pass("Backend set to: %s", name)
	return nil
}

func vaultSync() error {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	backend, err := newVaultBackend()
	if err != nil {
		Fail("Failed to create backend: %v", err)
		return err
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		Fail("Backend not available: %v", err)
		return err
	}

	session, err := backend.Authenticate(ctx)
	if err != nil {
		Fail("Authentication required: %v", err)
		return err
	}

	Info("Syncing %s vault...", backend.Name())

	if err := backend.Sync(ctx, session); err != nil {
		Fail("Sync failed: %v", err)
		return err
	}

	Pass("Vault synced")
	return nil
}

func vaultGet(name string, notesOnly bool) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	backend, err := newVaultBackend()
	if err != nil {
		Fail("Failed to create backend: %v", err)
		return err
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		Fail("Backend not available: %v", err)
		return err
	}

	session, err := backend.Authenticate(ctx)
	if err != nil {
		Fail("Authentication required: %v", err)
		return err
	}

	if notesOnly {
		notes, err := backend.GetNotes(ctx, name, session)
		if err != nil {
			if errors.Is(err, vaultmux.ErrNotFound) {
				Fail("Item not found: %s", name)
				return err
			}
			Fail("Failed to get item: %v", err)
			return err
		}
		fmt.Println(notes)
		return nil
	}

	item, err := backend.GetItem(ctx, name, session)
	if err != nil {
		if errors.Is(err, vaultmux.ErrNotFound) {
			Fail("Item not found: %s", name)
			return err
		}
		Fail("Failed to get item: %v", err)
		return err
	}

	data, _ := json.MarshalIndent(item, "", "  ")
	fmt.Println(string(data))
	return nil
}

func vaultHealth() error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	PrintHeader("Vault Health Check")

	backendType := getVaultBackend()
	fmt.Printf("Backend: %s\n\n", backendType)

	backend, err := newVaultBackend()
	if err != nil {
		Fail("Failed to create backend: %v", err)
		return err
	}
	defer backend.Close()

	// Check init
	if err := backend.Init(ctx); err != nil {
		Fail("Backend CLI not available: %v", err)
		PrintHint("Install the CLI tool for %s", backendType)
		return err
	}
	Pass("Backend CLI available: %s", backend.Name())

	// Check auth
	if backend.IsAuthenticated(ctx) {
		Pass("Authenticated")
	} else {
		Warn("Not authenticated")
		PrintHint("Run 'blackdot vault unlock' to authenticate")
	}

	// Check session file
	sessionFile := getSessionFile()
	if _, err := os.Stat(sessionFile); err == nil {
		Pass("Session file exists: %s", sessionFile)
	} else {
		Info("No cached session")
	}

	return nil
}

// vaultQuick provides a quick status check (login/unlock only)
func vaultQuick() error {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	backendType := getVaultBackend()

	fmt.Println("Vault Status")
	fmt.Println("────────────")

	if backendType == "" {
		fmt.Println("  Backend:    Not configured")
		fmt.Println()
		Info("Run 'blackdot setup' to configure a vault")
		return fmt.Errorf("vault not configured")
	}

	fmt.Printf("  Backend:    %s\n", backendType)

	backend, err := newVaultBackend()
	if err != nil {
		fmt.Println("  Status:     Backend not available")
		return err
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		fmt.Println("  CLI:        Not installed")
		fmt.Println()
		switch backendType {
		case vaultmux.BackendBitwarden:
			Info("Install with: brew install bitwarden-cli")
		case vaultmux.BackendOnePassword:
			Info("Install with: brew install --cask 1password-cli")
		case vaultmux.BackendPass:
			Info("Install with: brew install pass")
		}
		return err
	}

	fmt.Printf("  CLI:        %s\n", backend.Name())

	if backend.IsAuthenticated(ctx) {
		fmt.Println("  Status:     Authenticated")
		fmt.Println()
		Pass("Vault is accessible")
		return nil
	}

	fmt.Println("  Status:     Not authenticated")
	fmt.Println()
	Info("Run: blackdot vault unlock")
	return fmt.Errorf("vault not authenticated")
}

// vaultRestore restores secrets from vault to local machine
func vaultRestore(force, dryRun bool) error {
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	PrintHeader("Vault Restore")

	// Check offline mode
	if isOfflineMode() {
		Warn("Offline mode enabled (BLACKDOT_OFFLINE=1) - skipping vault operation")
		return nil
	}

	// Validate vault-items.json first
	Info("Validating vault-items.json schema...")
	if err := vaultValidate(); err != nil {
		return err
	}
	fmt.Println()

	backendType := getVaultBackend()
	fmt.Printf("Backend: %s\n", backendType)

	backend, err := newVaultBackend()
	if err != nil {
		Fail("Failed to create backend: %v", err)
		return err
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		Fail("Backend not available: %v", err)
		return err
	}

	session, err := backend.Authenticate(ctx)
	if err != nil {
		Fail("Authentication required: %v", err)
		return err
	}

	// Sync with remote
	Info("Syncing vault...")
	if err := backend.Sync(ctx, session); err != nil {
		Warn("Sync warning: %v", err)
	}
	Pass("Vault synced")
	fmt.Println()

	// Load vault items configuration
	vaultItems, err := loadVaultItems()
	if err != nil {
		Fail("Failed to load vault-items.json: %v", err)
		return err
	}

	// Pre-restore drift check (unless --force)
	if !force && !dryRun {
		Info("Checking for local changes before restore...")
		driftedItems := []string{}

		for name, item := range vaultItems {
			path := expandPath(item.Path)

			// Get vault content to compare
			notes, err := backend.GetNotes(ctx, name, session)
			if err != nil {
				continue // Can't check drift if vault item doesn't exist
			}

			driftStatus := checkItemDrift(path, notes)
			if driftStatus == 1 { // Drifted
				driftedItems = append(driftedItems, name)
			}
		}

		if len(driftedItems) > 0 {
			Warn("Local files have changed since last vault sync:")
			for _, item := range driftedItems {
				fmt.Printf("  - %s\n", item)
			}
			fmt.Println()
			fmt.Println("Options:")
			fmt.Println("  1. Run 'blackdot vault push' first to save local changes")
			fmt.Println("  2. Run restore with --force to overwrite local changes")
			fmt.Println("  3. Run 'blackdot drift' to see detailed differences")
			fmt.Println()
			Fail("Restore aborted to prevent data loss")
			return fmt.Errorf("local drift detected - use --force to overwrite")
		}
		Pass("No local drift detected - safe to restore")
		fmt.Println()
	}

	// Auto-backup before restore (if not dry-run)
	if !dryRun {
		Info("Creating backup before restore...")
		backupCmd := exec.Command(filepath.Join(BlackdotDir(), "bin", "blackdot"), "backup", "create")
		backupCmd.Stdout = os.Stdout
		backupCmd.Stderr = os.Stderr
		if err := backupCmd.Run(); err != nil {
			Warn("Backup failed (continuing anyway): %v", err)
		} else {
			Pass("Backup created")
		}
		fmt.Println()
	}

	if dryRun {
		fmt.Println("=== Preview Mode - No changes will be made ===")
		fmt.Println()
	}

	// Restore each item
	restored := 0
	skipped := 0
	failed := 0

	for name, item := range vaultItems {
		path := expandPath(item.Path)

		if dryRun {
			if _, err := os.Stat(path); err == nil {
				fmt.Printf("  %s → %s (exists, would overwrite)\n", name, path)
			} else {
				fmt.Printf("  %s → %s (new)\n", name, path)
			}
			restored++
			continue
		}

		// Get item from vault
		notes, err := backend.GetNotes(ctx, name, session)
		if err != nil {
			if errors.Is(err, vaultmux.ErrNotFound) {
				if item.Required {
					Fail("%s: not found in vault (required)", name)
					failed++
				} else {
					Warn("%s: not found in vault (optional)", name)
					skipped++
				}
				continue
			}
			Fail("%s: failed to get from vault: %v", name, err)
			failed++
			continue
		}

		// Create parent directory
		dir := filepath.Dir(path)
		if err := os.MkdirAll(dir, 0755); err != nil {
			Fail("%s: failed to create directory: %v", name, err)
			failed++
			continue
		}

		// Backup existing file before overwrite
		if err := backupFile(path); err != nil {
			Warn("%s: backup failed: %v", name, err)
		}

		// Handle SSH keys specially - extract private and public keys
		if item.Type == "sshkey" {
			// Extract and write private key
			privateKey := extractSSHPrivateKey(notes)
			if privateKey == "" {
				Fail("%s: no private key found in vault item", name)
				failed++
				continue
			}

			// Ensure private key ends with newline
			if !strings.HasSuffix(privateKey, "\n") {
				privateKey += "\n"
			}

			if err := os.WriteFile(path, []byte(privateKey), 0600); err != nil {
				Fail("%s: failed to write private key: %v", name, err)
				failed++
				continue
			}

			// Extract and write public key
			publicKey := extractSSHPublicKey(notes)
			if publicKey != "" {
				pubPath := path + ".pub"
				// Ensure public key ends with newline
				if !strings.HasSuffix(publicKey, "\n") {
					publicKey += "\n"
				}
				if err := os.WriteFile(pubPath, []byte(publicKey), 0644); err != nil {
					Warn("%s: failed to write public key: %v", name, err)
				} else {
					Pass("%s → %s (+ .pub)", name, path)
				}
			} else {
				Pass("%s → %s", name, path)
			}
			restored++
			continue
		}

		// Handle environment secrets specially - create loader script
		if name == "Environment-Secrets" || strings.HasSuffix(path, "env.secrets") {
			if err := os.WriteFile(path, []byte(notes), 0600); err != nil {
				Fail("%s: failed to write file: %v", name, err)
				failed++
				continue
			}

			// Create load-env.sh loader script
			if err := createEnvLoader(path); err != nil {
				Warn("%s: failed to create loader script: %v", name, err)
			} else {
				Pass("%s → %s (+ load-env.sh)", name, path)
			}
			restored++
			continue
		}

		// Standard file restoration
		perm := os.FileMode(0644)
		if strings.Contains(path, ".aws/") || strings.Contains(path, ".ssh/") {
			perm = 0600
		}

		if err := os.WriteFile(path, []byte(notes), perm); err != nil {
			Fail("%s: failed to write file: %v", name, err)
			failed++
			continue
		}

		Pass("%s → %s", name, path)
		restored++
	}

	fmt.Println()
	fmt.Println("========================================")
	if dryRun {
		fmt.Printf("DRY RUN: Would restore %d items\n", restored)
	} else {
		fmt.Printf("Restored: %d\n", restored)
	}
	fmt.Printf("Skipped: %d\n", skipped)
	if failed > 0 {
		Fail("Failed: %d", failed)
		return fmt.Errorf("%d items failed to restore", failed)
	}
	fmt.Println("========================================")

	// Save timestamp and drift state (if not dry-run)
	if !dryRun && failed == 0 {
		if err := saveVaultTimestamp("vault.last_pull"); err != nil {
			Warn("Failed to save timestamp: %v", err)
		}

		Info("Saving drift state for startup checks...")
		if err := saveVaultDriftState(vaultItems); err != nil {
			Warn("Failed to save drift state: %v", err)
		} else {
			Pass("Drift state saved to %s", getVaultDriftStatePath())
		}
	}

	return nil
}

// vaultPush pushes local secrets to vault
func vaultPush(items []string, force, dryRun, all bool) error {
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	PrintHeader("Push to Vault")

	// Check offline mode
	if isOfflineMode() {
		Warn("Offline mode enabled (BLACKDOT_OFFLINE=1) - skipping vault operation")
		return nil
	}

	// Validate vault-items.json first
	Info("Validating vault-items.json schema...")
	if err := vaultValidate(); err != nil {
		return err
	}
	fmt.Println()

	backendType := getVaultBackend()
	fmt.Printf("Backend: %s\n", backendType)

	backend, err := newVaultBackend()
	if err != nil {
		Fail("Failed to create backend: %v", err)
		return err
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		Fail("Backend not available: %v", err)
		return err
	}

	session, err := backend.Authenticate(ctx)
	if err != nil {
		Fail("Authentication required: %v", err)
		return err
	}

	// Sync with remote
	Info("Syncing vault...")
	if err := backend.Sync(ctx, session); err != nil {
		Warn("Sync warning: %v", err)
	}
	Pass("Vault synced")
	fmt.Println()

	// Load syncable items
	syncableItems, err := loadSyncableItems()
	if err != nil {
		Fail("Failed to load syncable items: %v", err)
		return err
	}

	// Determine which items to sync
	var itemsToSync map[string]string
	if all {
		itemsToSync = syncableItems
	} else if len(items) > 0 {
		itemsToSync = make(map[string]string)
		for _, name := range items {
			if path, ok := syncableItems[name]; ok {
				itemsToSync[name] = path
			} else {
				Fail("Unknown item: %s", name)
				fmt.Println("Valid items:")
				for k := range syncableItems {
					fmt.Printf("  %s\n", k)
				}
				return fmt.Errorf("unknown item: %s", name)
			}
		}
	} else {
		Warn("No items specified. Use --all or specify items to sync.")
		fmt.Println()
		fmt.Println("Valid items:")
		for k, v := range syncableItems {
			fmt.Printf("  %-25s %s\n", k, v)
		}
		return nil
	}

	if dryRun {
		fmt.Println("=== Preview Mode - No changes will be made ===")
		fmt.Println()
	}

	// Push each item
	synced := 0
	skipped := 0
	failed := 0

	for name, pathTemplate := range itemsToSync {
		path := expandPath(pathTemplate)

		fmt.Printf("--- %s ---\n", name)

		// Check if local file exists
		localContent, err := os.ReadFile(path)
		if err != nil {
			Warn("Local file not found: %s", path)
			skipped++
			continue
		}

		// Get current vault content
		vaultContent, err := backend.GetNotes(ctx, name, session)
		if err != nil && !errors.Is(err, vaultmux.ErrNotFound) {
			Fail("Failed to get vault item: %v", err)
			failed++
			continue
		}

		// Compare
		if string(localContent) == vaultContent {
			Pass("Already in sync: %s", path)
			skipped++
			continue
		}

		if dryRun {
			fmt.Printf("Would update '%s' from %s\n", name, path)
			synced++
			continue
		}

		// Update vault
		if vaultContent == "" {
			// Create new item
			if err := backend.CreateItem(ctx, name, string(localContent), session); err != nil {
				Fail("Failed to create '%s': %v", name, err)
				failed++
				continue
			}
			Pass("Created '%s' from %s", name, path)
		} else {
			// Update existing item
			if err := backend.UpdateItem(ctx, name, string(localContent), session); err != nil {
				Fail("Failed to update '%s': %v", name, err)
				failed++
				continue
			}
			Pass("Updated '%s' from %s", name, path)
		}
		synced++
		fmt.Println()
	}

	fmt.Println()
	fmt.Println("========================================")
	if dryRun {
		fmt.Printf("DRY RUN: Would sync %d items\n", synced)
	} else {
		fmt.Printf("Synced: %d\n", synced)
	}
	fmt.Printf("Skipped (no changes): %d\n", skipped)
	if failed > 0 {
		Fail("Failed: %d", failed)
		return fmt.Errorf("%d items failed to push", failed)
	}
	fmt.Println("========================================")

	// Save timestamp (if not dry-run and we synced something)
	if !dryRun && synced > 0 && failed == 0 {
		if err := saveVaultTimestamp("vault.last_push"); err != nil {
			Warn("Failed to save timestamp: %v", err)
		}
	}

	return nil
}

// vaultScan scans for local secrets to add to vault
func vaultScan() error {
	PrintHeader("Secret Discovery")

	fmt.Println("Scanning for secrets in standard locations...")
	fmt.Println()

	type discoveredItem struct {
		Name     string
		Path     string
		Type     string
		Required bool
	}

	var discovered []discoveredItem

	homeDir, _ := os.UserHomeDir()

	// Scan SSH keys
	Info("Scanning ~/.ssh/ for SSH keys...")
	sshDir := filepath.Join(homeDir, ".ssh")
	if entries, err := os.ReadDir(sshDir); err == nil {
		for _, entry := range entries {
			if entry.IsDir() {
				continue
			}
			name := entry.Name()
			// Skip known non-key files
			if name == "known_hosts" || name == "config" || name == "authorized_keys" ||
				strings.HasSuffix(name, ".pub") {
				continue
			}

			// Check if it looks like a private key
			keyPath := filepath.Join(sshDir, name)
			content, err := os.ReadFile(keyPath)
			if err != nil {
				continue
			}
			if strings.HasPrefix(string(content), "-----BEGIN") &&
				strings.Contains(string(content), "PRIVATE KEY") {
				// Generate vault name from filename
				vaultName := normalizeSSHKeyName(name)
				Pass("  Found: %s → %s", name, vaultName)
				discovered = append(discovered, discoveredItem{
					Name:     vaultName,
					Path:     "~/.ssh/" + name,
					Type:     "sshkey",
					Required: true,
				})
			}
		}
	}
	fmt.Println()

	// Scan AWS configs
	Info("Checking for AWS configs...")
	awsDir := filepath.Join(homeDir, ".aws")
	if _, err := os.Stat(filepath.Join(awsDir, "credentials")); err == nil {
		Pass("  Found: ~/.aws/credentials")
		discovered = append(discovered, discoveredItem{
			Name:     "AWS-Credentials",
			Path:     "~/.aws/credentials",
			Type:     "file",
			Required: true,
		})
	}
	if _, err := os.Stat(filepath.Join(awsDir, "config")); err == nil {
		Pass("  Found: ~/.aws/config")
		discovered = append(discovered, discoveredItem{
			Name:     "AWS-Config",
			Path:     "~/.aws/config",
			Type:     "file",
			Required: true,
		})
	}
	fmt.Println()

	// Scan Git config
	Info("Checking for Git config...")
	if _, err := os.Stat(filepath.Join(homeDir, ".gitconfig")); err == nil {
		Pass("  Found: ~/.gitconfig")
		discovered = append(discovered, discoveredItem{
			Name:     "Git-Config",
			Path:     "~/.gitconfig",
			Type:     "file",
			Required: true,
		})
	}
	fmt.Println()

	// Scan SSH config
	Info("Checking for SSH config...")
	if _, err := os.Stat(filepath.Join(homeDir, ".ssh", "config")); err == nil {
		Pass("  Found: ~/.ssh/config")
		discovered = append(discovered, discoveredItem{
			Name:     "SSH-Config",
			Path:     "~/.ssh/config",
			Type:     "file",
			Required: true,
		})
	}
	fmt.Println()

	// Scan other common secrets
	Info("Checking for other secrets...")
	otherSecrets := map[string]string{
		"Claude-Profiles":       filepath.Join(homeDir, ".claude", "profiles.json"),
		"NPM-Config":            filepath.Join(homeDir, ".npmrc"),
		"PyPI-Config":           filepath.Join(homeDir, ".pypirc"),
		"Docker-Config":         filepath.Join(homeDir, ".docker", "config.json"),
		"Environment-Secrets":   filepath.Join(homeDir, ".local", "env.secrets"),
		"Template-Variables":    filepath.Join(homeDir, ".config", "blackdot", "template-variables.sh"),
	}
	for name, path := range otherSecrets {
		if _, err := os.Stat(path); err == nil {
			shortPath := strings.Replace(path, homeDir, "~", 1)
			Pass("  Found: %s", shortPath)
			discovered = append(discovered, discoveredItem{
				Name:     name,
				Path:     shortPath,
				Type:     "file",
				Required: false,
			})
		}
	}
	fmt.Println()

	if len(discovered) == 0 {
		Warn("No secrets found in standard locations")
		return nil
	}

	// Generate JSON output
	fmt.Println("========================================")
	fmt.Printf("Discovered %d items\n", len(discovered))
	fmt.Println("========================================")
	fmt.Println()

	// Build vault-items structure
	vaultItemsJSON := map[string]interface{}{
		"$schema":  "https://json-schema.org/draft/2020-12/schema",
		"$comment": "Generated by blackdot vault scan",
	}

	sshKeys := make(map[string]string)
	vaultItems := make(map[string]map[string]interface{})
	syncableItems := make(map[string]string)

	for _, item := range discovered {
		vaultItems[item.Name] = map[string]interface{}{
			"path":     item.Path,
			"type":     item.Type,
			"required": item.Required,
		}

		if item.Type == "sshkey" {
			sshKeys[item.Name] = item.Path
		} else {
			syncableItems[item.Name] = item.Path
		}
	}

	vaultItemsJSON["ssh_keys"] = sshKeys
	vaultItemsJSON["vault_items"] = vaultItems
	vaultItemsJSON["syncable_items"] = syncableItems

	jsonBytes, _ := json.MarshalIndent(vaultItemsJSON, "", "  ")
	fmt.Println("Preview of vault-items.json:")
	fmt.Println()
	fmt.Println(string(jsonBytes))
	fmt.Println()

	configDir := os.Getenv("XDG_CONFIG_HOME")
	if configDir == "" {
		configDir = filepath.Join(homeDir, ".config")
	}
	vaultItemsPath := filepath.Join(configDir, "blackdot", "vault-items.json")

	// Check if file already exists
	existingConfig := false
	if _, err := os.Stat(vaultItemsPath); err == nil {
		existingConfig = true
	}

	// Prompt user for action
	fmt.Println("What would you like to do?")
	fmt.Println()
	if existingConfig {
		fmt.Println("  1) Merge - Add new items to existing config")
		fmt.Println("  2) Replace - Overwrite with new config (backup created)")
		fmt.Println("  3) Preview only - Don't save (copy JSON above)")
	} else {
		fmt.Println("  1) Save - Create new config file")
		fmt.Println("  2) Preview only - Don't save (copy JSON above)")
	}
	fmt.Println()
	fmt.Print("Select action [1]: ")

	reader := bufio.NewReader(os.Stdin)
	choice, _ := reader.ReadString('\n')
	choice = strings.TrimSpace(choice)
	if choice == "" {
		choice = "1"
	}

	if existingConfig {
		switch choice {
		case "1":
			// Merge with existing config
			existingData, err := os.ReadFile(vaultItemsPath)
			if err != nil {
				Fail("Failed to read existing config: %v", err)
				return err
			}

			var existingJSON map[string]interface{}
			if err := json.Unmarshal(existingData, &existingJSON); err != nil {
				Fail("Failed to parse existing config: %v", err)
				return err
			}

			// Merge vault_items
			if existingVaultItems, ok := existingJSON["vault_items"].(map[string]interface{}); ok {
				for name, item := range vaultItems {
					if _, exists := existingVaultItems[name]; !exists {
						existingVaultItems[name] = item
						Info("Added: %s", name)
					}
				}
				vaultItemsJSON["vault_items"] = existingVaultItems
			}

			// Merge ssh_keys
			if existingSSHKeys, ok := existingJSON["ssh_keys"].(map[string]interface{}); ok {
				for name, path := range sshKeys {
					if _, exists := existingSSHKeys[name]; !exists {
						existingSSHKeys[name] = path
					}
				}
				vaultItemsJSON["ssh_keys"] = existingSSHKeys
			}

			// Merge syncable_items
			if existingSyncable, ok := existingJSON["syncable_items"].(map[string]interface{}); ok {
				for name, path := range syncableItems {
					if _, exists := existingSyncable[name]; !exists {
						existingSyncable[name] = path
					}
				}
				vaultItemsJSON["syncable_items"] = existingSyncable
			}

			// Write merged config
			mergedBytes, _ := json.MarshalIndent(vaultItemsJSON, "", "  ")
			if err := os.WriteFile(vaultItemsPath, mergedBytes, 0644); err != nil {
				Fail("Failed to write config: %v", err)
				return err
			}
			Pass("Merged config saved to %s", vaultItemsPath)

		case "2":
			// Backup and replace
			backupPath := vaultItemsPath + ".bak-" + time.Now().Format("20060102150405")
			if err := os.Rename(vaultItemsPath, backupPath); err != nil {
				Fail("Failed to backup: %v", err)
				return err
			}
			Info("Backed up to: %s", backupPath)

			if err := os.WriteFile(vaultItemsPath, jsonBytes, 0644); err != nil {
				Fail("Failed to write config: %v", err)
				return err
			}
			Pass("Config saved to %s", vaultItemsPath)

		default:
			Info("Preview only - no changes made")
			fmt.Printf("To save manually: copy the JSON above to %s\n", vaultItemsPath)
		}
	} else {
		switch choice {
		case "1":
			// Create directory if needed
			if err := os.MkdirAll(filepath.Dir(vaultItemsPath), 0755); err != nil {
				Fail("Failed to create config directory: %v", err)
				return err
			}

			if err := os.WriteFile(vaultItemsPath, jsonBytes, 0644); err != nil {
				Fail("Failed to write config: %v", err)
				return err
			}
			Pass("Config saved to %s", vaultItemsPath)

		default:
			Info("Preview only - no changes made")
			fmt.Printf("To save manually: copy the JSON above to %s\n", vaultItemsPath)
		}
	}

	fmt.Println()
	fmt.Println("Next steps:")
	fmt.Printf("  %s blackdot vault push --all   # Push secrets to vault\n", Green.Sprint("→"))
	fmt.Printf("  %s blackdot vault status       # Check sync status\n", Green.Sprint("→"))

	return nil
}

// vaultCheck checks required vault items exist
func vaultCheck() error {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	PrintHeader("Check Vault Items")

	backend, err := newVaultBackend()
	if err != nil {
		Fail("Failed to create backend: %v", err)
		return err
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		Fail("Backend not available: %v", err)
		return err
	}

	session, err := backend.Authenticate(ctx)
	if err != nil {
		Fail("Authentication required: %v", err)
		return err
	}

	// Sync vault
	Info("Syncing vault...")
	if err := backend.Sync(ctx, session); err != nil {
		Warn("Sync warning: %v", err)
	}
	fmt.Println()

	// Load vault items
	vaultItems, err := loadVaultItems()
	if err != nil {
		Fail("Failed to load vault-items.json: %v", err)
		return err
	}

	// Get all items from vault
	Info("Fetching item list...")
	items, err := backend.ListItems(ctx, session)
	if err != nil {
		Fail("Failed to list items: %v", err)
		return err
	}

	// Build a set of vault item names
	vaultItemNames := make(map[string]bool)
	for _, item := range items {
		vaultItemNames[item.Name] = true
	}

	fmt.Println()
	fmt.Println("=== Required Items ===")
	missing := 0
	for name, item := range vaultItems {
		if !item.Required {
			continue
		}
		if vaultItemNames[name] {
			Pass("%s", name)
		} else {
			Fail("[MISSING] %s", name)
			missing++
		}
	}

	fmt.Println()
	fmt.Println("=== Optional Items ===")
	for name, item := range vaultItems {
		if item.Required {
			continue
		}
		if vaultItemNames[name] {
			Pass("%s", name)
		} else {
			Warn("%s - not found (optional)", name)
		}
	}

	fmt.Println()
	fmt.Println("========================================")
	if missing == 0 {
		Pass("All required vault items present!")
		fmt.Println("You can safely run: blackdot vault restore")
		return nil
	}

	Fail("Missing %d required item(s)", missing)
	fmt.Println()
	fmt.Println("To create missing items:")
	fmt.Println("  blackdot vault push ITEM-NAME")
	return fmt.Errorf("%d required items missing", missing)
}

// vaultValidate validates the vault-items.json schema
func vaultValidate() error {
	Info("Validating vault configuration schema...")
	fmt.Println()

	// Find vault-items.json
	configDir := os.Getenv("XDG_CONFIG_HOME")
	if configDir == "" {
		configDir = filepath.Join(os.Getenv("HOME"), ".config")
	}

	vaultItemsPath := filepath.Join(configDir, "blackdot", "vault-items.json")

	// Check if file exists
	if _, err := os.Stat(vaultItemsPath); os.IsNotExist(err) {
		Fail("vault-items.json not found at %s", vaultItemsPath)
		fmt.Println()
		Info("Copy the example file:")
		fmt.Printf("  cp %s/vault/vault-items.example.json %s\n", BlackdotDir(), vaultItemsPath)
		return err
	}

	// Read the file
	data, err := os.ReadFile(vaultItemsPath)
	if err != nil {
		Fail("Failed to read vault-items.json: %v", err)
		return err
	}

	// Parse JSON
	var config map[string]interface{}
	if err := json.Unmarshal(data, &config); err != nil {
		Fail("Invalid JSON syntax: %v", err)
		return err
	}
	Pass("JSON syntax valid")

	// Check required sections
	errors := 0

	// Check vault_items section
	if vaultItems, ok := config["vault_items"].(map[string]interface{}); ok {
		Pass("vault_items section found (%d items)", len(vaultItems))

		// Validate each item
		for name, itemData := range vaultItems {
			item, ok := itemData.(map[string]interface{})
			if !ok {
				Fail("  %s: invalid item format", name)
				errors++
				continue
			}

			// Check required fields
			if _, ok := item["path"]; !ok {
				Fail("  %s: missing 'path' field", name)
				errors++
			}

			// Validate type if present
			if itemType, ok := item["type"].(string); ok {
				validTypes := []string{"file", "sshkey", "env", "directory"}
				isValid := false
				for _, t := range validTypes {
					if t == itemType {
						isValid = true
						break
					}
				}
				if !isValid {
					Warn("  %s: unknown type '%s'", name, itemType)
				}
			}
		}
	} else {
		Warn("vault_items section not found")
	}

	// Check ssh_keys section (optional)
	if sshKeys, ok := config["ssh_keys"].(map[string]interface{}); ok {
		Pass("ssh_keys section found (%d keys)", len(sshKeys))
	}

	// Check syncable_items section (optional)
	if syncable, ok := config["syncable_items"].(map[string]interface{}); ok {
		Pass("syncable_items section found (%d items)", len(syncable))
	}

	fmt.Println()
	if errors > 0 {
		Fail("Validation failed with %d errors", errors)
		return fmt.Errorf("validation failed")
	}

	Pass("Vault configuration is valid")
	return nil
}

// vaultInit initializes vault setup
func vaultInit() error {
	PrintHeader("Vault Setup Wizard")

	reader := bufio.NewReader(os.Stdin)

	// Check for existing config
	configDir := os.Getenv("XDG_CONFIG_HOME")
	if configDir == "" {
		configDir = filepath.Join(os.Getenv("HOME"), ".config")
	}
	vaultConfigPath := filepath.Join(configDir, "blackdot", "vault-items.json")

	if _, err := os.Stat(vaultConfigPath); err == nil {
		Info("Existing configuration found: %s", vaultConfigPath)
		fmt.Println()
		fmt.Println("What would you like to do?")
		fmt.Println("  1) Add new items (keep existing, scan for more)")
		fmt.Println("  2) Reconfigure (backup current, start fresh)")
		fmt.Println("  3) Cancel (keep current config)")
		fmt.Println()
		fmt.Print("Your choice [1]: ")
		choice, _ := reader.ReadString('\n')
		choice = strings.TrimSpace(choice)
		if choice == "" {
			choice = "1"
		}

		switch choice {
		case "1":
			// Run scan with merge
			return vaultScan()
		case "2":
			// Backup and continue
			backup := vaultConfigPath + ".backup." + time.Now().Format("20060102150405")
			if err := os.Rename(vaultConfigPath, backup); err != nil {
				Fail("Failed to backup config: %v", err)
				return err
			}
			Info("Backed up to: %s", backup)
		default:
			Info("Keeping current configuration")
			return nil
		}
	}

	// Show education
	fmt.Println()
	fmt.Println("This wizard helps you set up vault integration for your secrets.")
	fmt.Println()
	fmt.Println("The system stores your secrets as individual items in your")
	fmt.Println("password vault. Each file (SSH key, config) becomes one item.")
	fmt.Println()
	fmt.Println("Supported backends:")
	fmt.Println("  • bitwarden  - Bitwarden CLI (bw)")
	fmt.Println("  • 1password  - 1Password CLI (op)")
	fmt.Println("  • pass       - pass (GPG-based password manager)")
	fmt.Println()

	// Step 1: Select backend
	fmt.Println("Step 1: Select Vault Backend")
	fmt.Println("────────────────────────────")
	fmt.Println()

	// Detect available backends
	available := []string{}
	backendNames := map[string]string{
		"bitwarden": "Bitwarden",
		"1password": "1Password",
		"pass":      "pass (GPG-based)",
	}

	if _, err := exec.LookPath("bw"); err == nil {
		available = append(available, "bitwarden")
	}
	if _, err := exec.LookPath("op"); err == nil {
		available = append(available, "1password")
	}
	if _, err := exec.LookPath("pass"); err == nil {
		available = append(available, "pass")
	}

	if len(available) == 0 {
		Warn("No vault CLI detected.")
		fmt.Println()
		fmt.Println("Install one of the supported backends:")
		fmt.Println("  brew install bitwarden-cli")
		fmt.Println("  brew install 1password-cli")
		fmt.Println("  brew install pass")
		return fmt.Errorf("no vault backend available")
	}

	fmt.Println("Available backends:")
	for i, backend := range available {
		fmt.Printf("  %d) %s\n", i+1, backendNames[backend])
	}
	fmt.Printf("  %d) Skip (configure later)\n", len(available)+1)
	fmt.Println()

	fmt.Print("Select backend [1]: ")
	choiceStr, _ := reader.ReadString('\n')
	choiceStr = strings.TrimSpace(choiceStr)
	if choiceStr == "" {
		choiceStr = "1"
	}

	var selectedBackend string
	choice := 0
	fmt.Sscanf(choiceStr, "%d", &choice)

	if choice == len(available)+1 {
		cfg := config.DefaultManager()
		cfg.Set("vault.backend", "none")
		Info("Vault setup skipped. Run 'blackdot vault init' anytime.")
		return nil
	} else if choice >= 1 && choice <= len(available) {
		selectedBackend = available[choice-1]
	} else {
		Fail("Invalid selection")
		return fmt.Errorf("invalid selection")
	}

	// Save backend
	cfg := config.DefaultManager()
	if err := cfg.Set("vault.backend", selectedBackend); err != nil {
		Fail("Failed to save config: %v", err)
		return err
	}
	Pass("Backend set to: %s", backendNames[selectedBackend])
	fmt.Println()

	// Step 2: Test authentication
	fmt.Println("Step 2: Authentication")
	fmt.Println("──────────────────────")
	fmt.Println()

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	backend, err := newVaultBackend()
	if err != nil {
		Fail("Failed to create backend: %v", err)
		return err
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		Fail("Backend CLI not available: %v", err)
		return err
	}

	if !backend.IsAuthenticated(ctx) {
		Warn("Not authenticated to %s", backend.Name())
		fmt.Println()
		fmt.Println("Please authenticate first:")
		switch selectedBackend {
		case "bitwarden":
			fmt.Println("  bw login")
			fmt.Println("  blackdot vault unlock")
		case "1password":
			fmt.Println("  op signin")
		case "pass":
			fmt.Println("  pass init <gpg-id>")
		}
		fmt.Println()
		fmt.Println("Then run setup again:")
		fmt.Println("  blackdot vault init")
		return fmt.Errorf("authentication required")
	}

	Pass("Authenticated to %s", backend.Name())
	fmt.Println()

	// Step 3: Setup type
	fmt.Println("Step 3: Setup Type")
	fmt.Println("──────────────────")
	fmt.Println()
	fmt.Println("How would you like to set up vault integration?")
	fmt.Println()
	fmt.Println("  1) Fresh - Scan local files, create new items")
	fmt.Println("  2) Manual - Create template config, edit manually")
	fmt.Println()
	fmt.Print("Your choice [1]: ")

	setupChoice, _ := reader.ReadString('\n')
	setupChoice = strings.TrimSpace(setupChoice)
	if setupChoice == "" || setupChoice == "1" {
		// Run discovery
		return vaultScan()
	}

	// Manual setup - copy example file
	exampleFile := filepath.Join(BlackdotDir(), "vault", "vault-items.example.json")
	if _, err := os.Stat(exampleFile); err == nil {
		os.MkdirAll(filepath.Dir(vaultConfigPath), 0755)
		data, _ := os.ReadFile(exampleFile)
		os.WriteFile(vaultConfigPath, data, 0644)
		Pass("Created config from template")
	} else {
		// Create minimal config
		minimalConfig := `{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$comment": "Created by vault setup wizard",
  "ssh_keys": {},
  "vault_items": {},
  "syncable_items": {}
}
`
		os.MkdirAll(filepath.Dir(vaultConfigPath), 0755)
		os.WriteFile(vaultConfigPath, []byte(minimalConfig), 0644)
		Pass("Created minimal config")
	}

	fmt.Println()
	fmt.Println("Configuration created at:")
	fmt.Printf("  %s\n", vaultConfigPath)
	fmt.Println()
	fmt.Println("Edit this file to define your vault items:")
	fmt.Println("  $EDITOR " + vaultConfigPath)
	fmt.Println()
	fmt.Println("When ready, run:")
	fmt.Println("  blackdot vault restore  - Restore from vault")
	fmt.Println("  blackdot vault push     - Backup to vault")

	return nil
}

// ============================================================
// Helper Functions
// ============================================================

// VaultItem represents an item in vault-items.json
type VaultItem struct {
	Path     string `json:"path"`
	Type     string `json:"type"`
	Required bool   `json:"required"`
}

// isOfflineMode checks if running in offline mode
func isOfflineMode() bool {
	return os.Getenv("BLACKDOT_OFFLINE") == "1"
}

// calculateChecksum returns SHA256 checksum of content
func calculateChecksum(content []byte) string {
	h := sha256.Sum256(content)
	return fmt.Sprintf("%x", h)
}

// backupFile creates a timestamped backup of a file
func backupFile(path string) error {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return nil // Nothing to backup
	}

	timestamp := time.Now().Format("20060102150405")
	backupPath := fmt.Sprintf("%s.bak-%s", path, timestamp)

	content, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("failed to read file for backup: %w", err)
	}

	if err := os.WriteFile(backupPath, content, 0600); err != nil {
		return fmt.Errorf("failed to write backup: %w", err)
	}

	return nil
}

// extractSSHPrivateKey extracts the private key block from notes
func extractSSHPrivateKey(notes string) string {
	lines := strings.Split(notes, "\n")
	var result []string
	inKey := false

	for _, line := range lines {
		if strings.Contains(line, "BEGIN OPENSSH PRIVATE KEY") ||
			strings.Contains(line, "BEGIN RSA PRIVATE KEY") ||
			strings.Contains(line, "BEGIN EC PRIVATE KEY") ||
			strings.Contains(line, "BEGIN DSA PRIVATE KEY") {
			inKey = true
		}
		if inKey {
			result = append(result, line)
		}
		if strings.Contains(line, "END OPENSSH PRIVATE KEY") ||
			strings.Contains(line, "END RSA PRIVATE KEY") ||
			strings.Contains(line, "END EC PRIVATE KEY") ||
			strings.Contains(line, "END DSA PRIVATE KEY") {
			inKey = false
		}
	}

	return strings.Join(result, "\n")
}

// extractSSHPublicKey extracts the public key line from notes
func extractSSHPublicKey(notes string) string {
	lines := strings.Split(notes, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "ssh-ed25519 ") ||
			strings.HasPrefix(line, "ssh-rsa ") ||
			strings.HasPrefix(line, "ssh-ecdsa ") ||
			strings.HasPrefix(line, "ecdsa-sha2-") ||
			strings.HasPrefix(line, "ssh-dss ") {
			return line
		}
	}
	return ""
}

// checkItemDrift checks if a local file differs from vault content
// Returns: 0 = no drift, 1 = drifted, 2 = local missing
func checkItemDrift(localPath, vaultContent string) int {
	localContent, err := os.ReadFile(localPath)
	if err != nil {
		if os.IsNotExist(err) {
			return 2 // Local missing
		}
		return 0 // Can't check, assume no drift
	}

	if string(localContent) != vaultContent {
		return 1 // Drifted
	}
	return 0 // No drift
}

// getVaultDriftStatePath returns the path to the vault drift state file
func getVaultDriftStatePath() string {
	cacheDir := os.Getenv("XDG_CACHE_HOME")
	if cacheDir == "" {
		home, _ := os.UserHomeDir()
		cacheDir = filepath.Join(home, ".cache")
	}
	return filepath.Join(cacheDir, "blackdot", "vault-state.json")
}

// saveVaultDriftState saves the current vault drift state after restore
func saveVaultDriftState(items map[string]VaultItem) error {
	statePath := getVaultDriftStatePath()

	// Create directory
	if err := os.MkdirAll(filepath.Dir(statePath), 0755); err != nil {
		return err
	}

	state := map[string]interface{}{
		"timestamp": time.Now().UTC().Format(time.RFC3339),
		"items":     make(map[string]interface{}),
	}

	itemsMap := state["items"].(map[string]interface{})

	for name, item := range items {
		path := expandPath(item.Path)
		content, err := os.ReadFile(path)
		if err != nil {
			continue
		}

		info, _ := os.Stat(path)
		modTime := ""
		if info != nil {
			modTime = info.ModTime().UTC().Format(time.RFC3339)
		}

		itemsMap[name] = map[string]interface{}{
			"checksum":   calculateChecksum(content),
			"mod_time":   modTime,
			"local_path": path,
		}
	}

	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(statePath, data, 0644)
}

// saveVaultTimestamp saves a timestamp to config
func saveVaultTimestamp(key string) error {
	cfg := config.DefaultManager()
	timestamp := time.Now().UTC().Format(time.RFC3339)
	return cfg.Set(key, timestamp)
}

// createEnvLoader creates the load-env.sh script
func createEnvLoader(envSecretsPath string) error {
	loaderPath := filepath.Join(filepath.Dir(envSecretsPath), "load-env.sh")

	loaderContent := `#!/usr/bin/env bash
# Auto-generated by blackdot vault restore
# Source this file to load environment secrets: source ~/.local/load-env.sh

ENV_FILE="$HOME/.local/env.secrets"

if [[ -f "$ENV_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # Export the variable
        export "$line"
    done < "$ENV_FILE"
fi
`
	return os.WriteFile(loaderPath, []byte(loaderContent), 0700)
}

// loadVaultItems loads the vault_items section from vault-items.json
func loadVaultItems() (map[string]VaultItem, error) {
	configDir := os.Getenv("XDG_CONFIG_HOME")
	if configDir == "" {
		configDir = filepath.Join(os.Getenv("HOME"), ".config")
	}
	vaultItemsPath := filepath.Join(configDir, "blackdot", "vault-items.json")

	data, err := os.ReadFile(vaultItemsPath)
	if err != nil {
		return nil, err
	}

	var config struct {
		VaultItems map[string]VaultItem `json:"vault_items"`
	}

	if err := json.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	return config.VaultItems, nil
}

// loadSyncableItems loads the syncable_items section from vault-items.json
func loadSyncableItems() (map[string]string, error) {
	configDir := os.Getenv("XDG_CONFIG_HOME")
	if configDir == "" {
		configDir = filepath.Join(os.Getenv("HOME"), ".config")
	}
	vaultItemsPath := filepath.Join(configDir, "blackdot", "vault-items.json")

	data, err := os.ReadFile(vaultItemsPath)
	if err != nil {
		return nil, err
	}

	var config struct {
		SyncableItems map[string]string `json:"syncable_items"`
		VaultItems    map[string]struct {
			Path string `json:"path"`
		} `json:"vault_items"`
	}

	if err := json.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	// If syncable_items exists, use it; otherwise derive from vault_items
	if len(config.SyncableItems) > 0 {
		return config.SyncableItems, nil
	}

	// Derive from vault_items
	result := make(map[string]string)
	for name, item := range config.VaultItems {
		result[name] = item.Path
	}
	return result, nil
}

// expandPath expands ~ to home directory in a path
func expandPath(path string) string {
	if strings.HasPrefix(path, "~/") {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, path[2:])
	}
	if strings.HasPrefix(path, "$HOME/") {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, path[6:])
	}
	return path
}

// normalizeSSHKeyName generates a vault item name from an SSH key filename
func normalizeSSHKeyName(filename string) string {
	// id_ed25519_github → SSH-Github
	// id_rsa_work → SSH-Work
	// id_ed25519 → SSH-Personal

	re := regexp.MustCompile(`^id_[^_]+_(.+)$`)
	if matches := re.FindStringSubmatch(filename); len(matches) == 2 {
		name := matches[1]
		// Capitalize first letter
		if len(name) > 0 {
			name = strings.ToUpper(name[:1]) + name[1:]
		}
		return "SSH-" + name
	}

	// Generic key (id_ed25519, id_rsa, etc.)
	if strings.HasPrefix(filename, "id_") {
		return "SSH-Personal"
	}

	// Use filename as-is
	return "SSH-" + strings.Title(filename)
}

// vaultCreate creates a new vault item
func vaultCreate(name, content string, dryRun, force bool) error {
	PrintHeader("Create Vault Item")

	// Handle dry-run without connecting to backend
	if dryRun {
		fmt.Println("(DRY RUN - no changes will be made)")
		fmt.Println()
		fmt.Printf("Item name: %s\n", name)
		fmt.Printf("Content size: %d bytes\n", len(content))
		fmt.Println()
		fmt.Printf("Would create/update '%s'\n", name)
		fmt.Println()
		fmt.Println("Preview (first 5 lines):")
		fmt.Println("---")
		lines := strings.Split(content, "\n")
		for i, line := range lines {
			if i >= 5 {
				break
			}
			fmt.Println(line)
		}
		fmt.Println("---")
		Pass("Dry run complete")
		return nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	backend, err := newVaultBackend()
	if err != nil {
		return fmt.Errorf("failed to create backend: %w", err)
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		return fmt.Errorf("backend not available: %w", err)
	}

	session, err := backend.Authenticate(ctx)
	if err != nil {
		return fmt.Errorf("authentication failed: %w", err)
	}

	// Sync first
	Info("Syncing vault...")
	if err := backend.Sync(ctx, session); err != nil {
		Warn("Sync failed: %v", err)
	}

	// Check if item exists
	existing, _ := backend.GetNotes(ctx, name, session)
	if existing != "" {
		Warn("Item '%s' already exists (%d chars)", name, len(existing))
		if !force {
			Fail("Use --force to overwrite")
			return fmt.Errorf("item exists, use --force to overwrite")
		}
		Info("Will overwrite existing item (--force)")
	}

	fmt.Printf("Item name: %s\n", name)
	fmt.Printf("Content size: %d bytes\n", len(content))

	if existing != "" {
		// Update existing
		if err := backend.UpdateItem(ctx, name, content, session); err != nil {
			return fmt.Errorf("failed to update item: %w", err)
		}
		Pass("Updated '%s'", name)
	} else {
		// Create new
		if err := backend.CreateItem(ctx, name, content, session); err != nil {
			return fmt.Errorf("failed to create item: %w", err)
		}
		Pass("Created '%s'", name)
	}

	fmt.Println()
	fmt.Println("Verify with: blackdot vault list")

	return nil
}

// isProtectedItem checks if an item is a protected blackdot item
func isProtectedItem(name string) bool {
	protected := []string{
		"SSH-", "AWS-", "Git-Config", "Environment-Secrets",
	}
	for _, prefix := range protected {
		if strings.HasPrefix(name, prefix) || name == prefix {
			return true
		}
	}
	return false
}

// vaultDelete deletes vault items
func vaultDelete(names []string, dryRun, force bool) error {
	PrintHeader("Delete from Vault")

	// Handle dry-run without connecting to backend
	if dryRun {
		fmt.Println("(DRY RUN - no changes will be made)")
		fmt.Println()
		for _, name := range names {
			fmt.Printf("--- %s ---\n", name)
			fmt.Printf("Would delete '%s'\n", name)
			if isProtectedItem(name) {
				Warn("Protected item - would require confirmation to delete")
			}
			fmt.Println()
		}
		Pass("Dry run complete")
		return nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	backend, err := newVaultBackend()
	if err != nil {
		return fmt.Errorf("failed to create backend: %w", err)
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		return fmt.Errorf("backend not available: %w", err)
	}

	session, err := backend.Authenticate(ctx)
	if err != nil {
		return fmt.Errorf("authentication failed: %w", err)
	}

	// Sync first
	Info("Syncing vault...")
	if err := backend.Sync(ctx, session); err != nil {
		Warn("Sync failed: %v", err)
	}

	var deleted, skipped, failed int

	for _, name := range names {
		fmt.Printf("--- %s ---\n", name)

		// Check if item exists
		existing, _ := backend.GetNotes(ctx, name, session)
		if existing == "" {
			Warn("Item '%s' not found", name)
			skipped++
			fmt.Println()
			continue
		}

		fmt.Printf("  Size: %d chars\n", len(existing))

		// Check if protected
		if isProtectedItem(name) {
			fmt.Println()
			Warn("⚠ This is a protected blackdot item!")
			fmt.Println("Deleting this will break your blackdot restore.")
			fmt.Println()

			// Always require confirmation for protected items
			fmt.Print("Type the item name to confirm deletion: ")
			reader := bufio.NewReader(os.Stdin)
			confirm, _ := reader.ReadString('\n')
			confirm = strings.TrimSpace(confirm)
			if confirm != name {
				Warn("Confirmation failed - skipping")
				skipped++
				fmt.Println()
				continue
			}
		} else {
			// Non-protected: respect --force
			if !force {
				fmt.Printf("Delete '%s'? [y/N] ", name)
				reader := bufio.NewReader(os.Stdin)
				confirm, _ := reader.ReadString('\n')
				confirm = strings.TrimSpace(confirm)
				if !strings.EqualFold(confirm, "y") {
					Warn("Cancelled")
					skipped++
					fmt.Println()
					continue
				}
			}
		}

		// Perform deletion
		if err := backend.DeleteItem(ctx, name, session); err != nil {
			Fail("Failed to delete '%s': %v", name, err)
			failed++
		} else {
			Pass("Deleted '%s'", name)
			deleted++
		}
		fmt.Println()
	}

	// Summary
	fmt.Println("========================================")
	if dryRun {
		fmt.Println("DRY RUN SUMMARY:")
		fmt.Printf("  Would delete: %d\n", deleted)
	} else {
		fmt.Println("SUMMARY:")
		fmt.Printf("  Deleted: %d\n", deleted)
	}
	fmt.Printf("  Skipped: %d\n", skipped)
	if failed > 0 {
		Fail("Failed: %d", failed)
	}
	fmt.Println("========================================")

	if failed > 0 {
		return fmt.Errorf("%d items failed to delete", failed)
	}
	return nil
}
