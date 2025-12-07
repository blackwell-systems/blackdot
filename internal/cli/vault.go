package cli

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/blackwell-systems/dotfiles/internal/config"
	"github.com/blackwell-systems/vaultmux"
	_ "github.com/blackwell-systems/vaultmux/backends/bitwarden"
	_ "github.com/blackwell-systems/vaultmux/backends/onepassword"
	_ "github.com/blackwell-systems/vaultmux/backends/pass"
	"github.com/spf13/cobra"
)

// getVaultBackend returns the configured backend type
func getVaultBackend() vaultmux.BackendType {
	// Check env var first
	if backend := os.Getenv("DOTFILES_VAULT_BACKEND"); backend != "" {
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
	return filepath.Join(DotfilesDir(), "vault", ".vault-session")
}

// newVaultBackend creates a new vault backend with config
func newVaultBackend() (vaultmux.Backend, error) {
	backendType := getVaultBackend()

	cfg := vaultmux.Config{
		Backend:     backendType,
		SessionFile: getSessionFile(),
		SessionTTL:  1800, // 30 minutes
		Prefix:      "dotfiles",
	}

	return vaultmux.New(cfg)
}

func newVaultCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "vault",
		Short: "Manage secrets vault",
		Long: `Manage secrets using the multi-vault backend system.

Supported backends: Bitwarden, 1Password, pass

The vault system allows syncing secrets between your local machine
and a secure vault backend, with support for SSH keys, AWS credentials,
environment files, and custom secrets.`,
		Run: func(cmd *cobra.Command, args []string) {
			cmd.Help()
		},
	}

	cmd.AddCommand(
		newVaultStatusCmd(),
		newVaultUnlockCmd(),
		newVaultLockCmd(),
		newVaultListCmd(),
		newVaultBackendCmd(),
		newVaultSyncCmd(),
		newVaultGetCmd(),
		newVaultHealthCmd(),
	)

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

// ============================================================
// Implementation Functions
// ============================================================

func vaultStatus() error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	PrintHeader("Vault Status")

	backendType := getVaultBackend()
	fmt.Printf("Backend: %s\n", backendType)
	fmt.Printf("Session file: %s\n", getSessionFile())
	fmt.Println()

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

	Pass("Backend initialized: %s", backend.Name())

	// Check authentication
	if backend.IsAuthenticated(ctx) {
		Pass("Authenticated")
	} else {
		Warn("Not authenticated - run 'dotfiles vault unlock'")
	}

	return nil
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
		PrintHint("Run 'dotfiles vault unlock' to authenticate")
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
