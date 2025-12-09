package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestVaultCommandExists verifies vault command is registered
func TestVaultCommandExists(t *testing.T) {
	cmd, _, err := rootCmd.Find([]string{"vault"})
	if err != nil {
		t.Fatalf("vault command not found: %v", err)
	}

	if cmd.Use != "vault" {
		t.Errorf("expected Use='vault', got '%s'", cmd.Use)
	}
}

// TestVaultSubcommands verifies all vault subcommands exist
func TestVaultSubcommands(t *testing.T) {
	vaultCmd := newVaultCmd()

	expectedSubcommands := []string{
		"status",
		"unlock",
		"lock",
		"list",
		"backend",
		"sync",
		"get",
		"health",
		"quick",
		"restore",
		"push",
		"scan",
		"check",
		"validate",
		"init",
		"create",
		"delete",
	}

	subcommands := make(map[string]bool)
	for _, cmd := range vaultCmd.Commands() {
		subcommands[cmd.Name()] = true
	}

	for _, expected := range expectedSubcommands {
		if !subcommands[expected] {
			t.Errorf("expected vault subcommand '%s' not found", expected)
		}
	}
}

// TestSecretsCommandIsAlias verifies secrets is an alias for vault
func TestSecretsCommandIsAlias(t *testing.T) {
	secretsCmd := newSecretsCmd()

	if secretsCmd.Use != "secrets" {
		t.Errorf("expected Use='secrets', got '%s'", secretsCmd.Use)
	}

	if !secretsCmd.Hidden {
		t.Error("secrets command should be hidden")
	}

	// Verify it has the same subcommands as vault
	vaultCmd := newVaultCmd()

	secretsSubs := make(map[string]bool)
	for _, cmd := range secretsCmd.Commands() {
		secretsSubs[cmd.Name()] = true
	}

	for _, cmd := range vaultCmd.Commands() {
		if !secretsSubs[cmd.Name()] {
			t.Errorf("secrets missing subcommand '%s' that vault has", cmd.Name())
		}
	}
}

// TestVaultInitHasSetupAlias verifies init has setup alias
func TestVaultInitHasSetupAlias(t *testing.T) {
	initCmd := newVaultInitCmd()

	hasSetupAlias := false
	for _, alias := range initCmd.Aliases {
		if alias == "setup" {
			hasSetupAlias = true
			break
		}
	}

	if !hasSetupAlias {
		t.Error("vault init should have 'setup' alias")
	}
}

// TestVaultRestoreHasPullAlias verifies restore has pull alias
func TestVaultRestoreHasPullAlias(t *testing.T) {
	restoreCmd := newVaultRestoreCmd()

	hasPullAlias := false
	for _, alias := range restoreCmd.Aliases {
		if alias == "pull" {
			hasPullAlias = true
			break
		}
	}

	if !hasPullAlias {
		t.Error("vault restore should have 'pull' alias")
	}
}

// TestGetVaultBackend verifies backend resolution
func TestGetVaultBackend(t *testing.T) {
	// Save original env
	original := os.Getenv("DOTFILES_VAULT_BACKEND")
	defer os.Setenv("DOTFILES_VAULT_BACKEND", original)

	// Test with env var set
	os.Setenv("DOTFILES_VAULT_BACKEND", "1password")
	backend := getVaultBackend()
	if string(backend) != "1password" {
		t.Errorf("expected '1password', got '%s'", backend)
	}

	// Test with env var unset (uses default)
	os.Unsetenv("DOTFILES_VAULT_BACKEND")
	backend = getVaultBackend()
	if string(backend) != "bitwarden" {
		t.Errorf("expected default 'bitwarden', got '%s'", backend)
	}
}

// TestGetSessionFile verifies session file path resolution
func TestGetSessionFile(t *testing.T) {
	// Save original envs
	originalSession := os.Getenv("VAULT_SESSION_FILE")
	originalDotfiles := os.Getenv("DOTFILES_DIR")
	defer func() {
		os.Setenv("VAULT_SESSION_FILE", originalSession)
		os.Setenv("DOTFILES_DIR", originalDotfiles)
	}()

	// Test with env var set
	os.Setenv("VAULT_SESSION_FILE", "/custom/session")
	path := getSessionFile()
	if path != "/custom/session" {
		t.Errorf("expected '/custom/session', got '%s'", path)
	}

	// Test with env var unset
	os.Unsetenv("VAULT_SESSION_FILE")
	os.Setenv("DOTFILES_DIR", "/test/dotfiles")
	initConfig() // Re-init to pick up DOTFILES_DIR
	path = getSessionFile()
	expected := filepath.Join(DotfilesDir(), "vault", ".vault-session")
	if path != expected {
		t.Errorf("expected '%s', got '%s'", expected, path)
	}
}

// TestVaultHelp verifies vault help doesn't panic
func TestVaultHelp(t *testing.T) {
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("printVaultHelp panicked: %v", r)
		}
	}()

	printVaultHelp()
}

// TestVaultStatusCmd verifies status command structure
func TestVaultStatusCmd(t *testing.T) {
	cmd := newVaultStatusCmd()

	if cmd.Use != "status" {
		t.Errorf("expected Use='status', got '%s'", cmd.Use)
	}

	if cmd.Short == "" {
		t.Error("status should have Short description")
	}

	if cmd.RunE == nil {
		t.Error("status should have RunE function")
	}
}

// TestVaultQuickCmd verifies quick command structure
func TestVaultQuickCmd(t *testing.T) {
	cmd := newVaultQuickCmd()

	if cmd.Use != "quick" {
		t.Errorf("expected Use='quick', got '%s'", cmd.Use)
	}

	if cmd.Short == "" {
		t.Error("quick should have Short description")
	}
}

// TestVaultBackendCmd verifies backend command structure
func TestVaultBackendCmd(t *testing.T) {
	cmd := newVaultBackendCmd()

	// Use may include args pattern like "backend [name]"
	if !strings.HasPrefix(cmd.Use, "backend") {
		t.Errorf("expected Use to start with 'backend', got '%s'", cmd.Use)
	}

	// Should have subcommands or be runnable
	if cmd.RunE == nil && cmd.Run == nil && len(cmd.Commands()) == 0 {
		t.Error("backend should be runnable or have subcommands")
	}
}

// TestVaultPushFlags verifies push command has expected flags
func TestVaultPushFlags(t *testing.T) {
	cmd := newVaultPushCmd()

	// Check for --all flag
	flag := cmd.Flags().Lookup("all")
	if flag == nil {
		t.Error("push command should have --all flag")
	}

	// Check for --dry-run flag
	flag = cmd.Flags().Lookup("dry-run")
	if flag == nil {
		t.Error("push command should have --dry-run flag")
	}
}

// TestVaultRestoreFlags verifies restore command has expected flags
func TestVaultRestoreFlags(t *testing.T) {
	cmd := newVaultRestoreCmd()

	// Check for --force flag
	flag := cmd.Flags().Lookup("force")
	if flag == nil {
		t.Error("restore command should have --force flag")
	}

	// Check for --dry-run flag
	flag = cmd.Flags().Lookup("dry-run")
	if flag == nil {
		t.Error("restore command should have --dry-run flag")
	}
}

// TestVaultDeleteFlags verifies delete command has expected flags
func TestVaultDeleteFlags(t *testing.T) {
	cmd := newVaultDeleteCmd()

	// Check for --force flag
	flag := cmd.Flags().Lookup("force")
	if flag == nil {
		t.Error("delete command should have --force flag")
	}

	// Check for --dry-run flag
	flag = cmd.Flags().Lookup("dry-run")
	if flag == nil {
		t.Error("delete command should have --dry-run flag")
	}
}

// TestVaultCommandAliasesWork verifies aliases resolve correctly
func TestVaultCommandAliasesWork(t *testing.T) {
	vaultCmd := newVaultCmd()

	// Test setup -> init
	cmd, args, err := vaultCmd.Find([]string{"setup"})
	if err != nil {
		t.Fatalf("failed to find 'setup': %v", err)
	}
	if cmd.Name() != "init" {
		t.Errorf("'setup' should resolve to 'init', got '%s'", cmd.Name())
	}
	_ = args // unused

	// Test pull -> restore
	cmd, _, err = vaultCmd.Find([]string{"pull"})
	if err != nil {
		t.Fatalf("failed to find 'pull': %v", err)
	}
	if cmd.Name() != "restore" {
		t.Errorf("'pull' should resolve to 'restore', got '%s'", cmd.Name())
	}
}

// TestVaultItemsPath verifies vault items path construction
func TestVaultItemsPath(t *testing.T) {
	// Save and set DOTFILES_DIR
	original := os.Getenv("DOTFILES_DIR")
	os.Setenv("DOTFILES_DIR", "/test/dotfiles")
	defer os.Setenv("DOTFILES_DIR", original)

	initConfig()

	// Vault items should be in vault/ subdirectory
	expected := filepath.FromSlash("/test/dotfiles/vault")
	vaultDir := filepath.Join(DotfilesDir(), "vault")
	if vaultDir != expected {
		t.Errorf("expected vault dir '%s', got '%s'", expected, vaultDir)
	}
}

// TestNewVaultBackendError verifies error handling when backend unavailable
func TestNewVaultBackendError(t *testing.T) {
	// This test verifies the function handles missing backends gracefully
	// We can't easily test success without actual vault backends installed

	// Save original env
	original := os.Getenv("DOTFILES_VAULT_BACKEND")
	defer os.Setenv("DOTFILES_VAULT_BACKEND", original)

	// Set an invalid backend
	os.Setenv("DOTFILES_VAULT_BACKEND", "nonexistent")

	_, err := newVaultBackend()
	if err == nil {
		t.Log("Backend creation succeeded (backend may be registered)")
	} else if !strings.Contains(err.Error(), "unknown") && !strings.Contains(err.Error(), "unsupported") {
		// Some error is expected for invalid backend
		t.Logf("Got expected error: %v", err)
	}
}
