package config

import (
	"os"
	"path/filepath"
	"testing"
)

// TestNewManager verifies manager creation
func TestNewManager(t *testing.T) {
	m := NewManager("/config", "/blackdot")

	if m == nil {
		t.Fatal("NewManager should not return nil")
	}

	if m.configDir != "/config" {
		t.Errorf("expected configDir='/config', got '%s'", m.configDir)
	}

	if m.blackdotDir != "/blackdot" {
		t.Errorf("expected blackdotDir='/blackdot', got '%s'", m.blackdotDir)
	}
}

// TestDefaultManager verifies default manager creation
func TestDefaultManager(t *testing.T) {
	m := DefaultManager()

	if m == nil {
		t.Fatal("DefaultManager should not return nil")
	}

	if m.configDir == "" {
		t.Error("configDir should not be empty")
	}

	if m.blackdotDir == "" {
		t.Error("blackdotDir should not be empty")
	}
}

// TestDefaultManagerWithEnv verifies DefaultManager respects env vars
func TestDefaultManagerWithEnv(t *testing.T) {
	// Save original env
	origConfig := os.Getenv("XDG_CONFIG_HOME")
	origBlackdot := os.Getenv("BLACKDOT_DIR")
	defer func() {
		os.Setenv("XDG_CONFIG_HOME", origConfig)
		os.Setenv("BLACKDOT_DIR", origBlackdot)
	}()

	os.Setenv("XDG_CONFIG_HOME", "/custom/config")
	os.Setenv("BLACKDOT_DIR", "/custom/blackdot")

	m := DefaultManager()

	expectedConfig := filepath.FromSlash("/custom/config/blackdot")
	if m.configDir != expectedConfig {
		t.Errorf("expected configDir='%s', got '%s'", expectedConfig, m.configDir)
	}

	expectedBlackdot := filepath.FromSlash("/custom/blackdot")
	if m.blackdotDir != expectedBlackdot {
		t.Errorf("expected blackdotDir='%s', got '%s'", expectedBlackdot, m.blackdotDir)
	}
}

// TestConfigPaths verifies path methods
func TestConfigPaths(t *testing.T) {
	m := NewManager("/config", "/blackdot")

	expectedUser := filepath.FromSlash("/config/config.json")
	if m.UserConfigPath() != expectedUser {
		t.Errorf("unexpected UserConfigPath: got %s, want %s", m.UserConfigPath(), expectedUser)
	}

	expectedMachine := filepath.FromSlash("/config/machine.json")
	if m.MachineConfigPath() != expectedMachine {
		t.Errorf("unexpected MachineConfigPath: got %s, want %s", m.MachineConfigPath(), expectedMachine)
	}
}

// TestLoadNonexistent verifies Load returns default config for missing file
func TestLoadNonexistent(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "config-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	m := NewManager(tmpDir, tmpDir)

	cfg, err := m.Load()
	if err != nil {
		t.Fatalf("Load should not error for missing file: %v", err)
	}

	if cfg.Version != 3 {
		t.Errorf("expected Version=3 for new config, got %d", cfg.Version)
	}
}

// TestSaveAndLoad verifies Save and Load roundtrip
func TestSaveAndLoad(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "config-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	m := NewManager(tmpDir, tmpDir)

	// Create and save config
	cfg := &Config{
		Version: 3,
		Vault: VaultConfig{
			Backend: "bitwarden",
		},
		Features: map[string]bool{
			"vault": true,
		},
	}

	err = m.Save(cfg)
	if err != nil {
		t.Fatalf("Save failed: %v", err)
	}

	// Verify file exists
	if _, err := os.Stat(m.UserConfigPath()); os.IsNotExist(err) {
		t.Error("config file should exist after Save")
	}

	// Load and verify
	loaded, err := m.Load()
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	if loaded.Vault.Backend != "bitwarden" {
		t.Errorf("expected Backend='bitwarden', got '%s'", loaded.Vault.Backend)
	}

	if !loaded.Features["vault"] {
		t.Error("vault feature should be enabled")
	}
}

// TestGetSetVaultBackend verifies Get/Set for vault.backend
func TestGetSetVaultBackend(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "config-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	m := NewManager(tmpDir, tmpDir)

	// Set value
	err = m.Set("vault.backend", "1password")
	if err != nil {
		t.Fatalf("Set failed: %v", err)
	}

	// Get value
	val, err := m.Get("vault.backend")
	if err != nil {
		t.Fatalf("Get failed: %v", err)
	}

	if val != "1password" {
		t.Errorf("expected '1password', got '%s'", val)
	}
}

// TestGetSetVaultAutoSync verifies Get/Set for vault.auto_sync
func TestGetSetVaultAutoSync(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "config-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	m := NewManager(tmpDir, tmpDir)

	// Set true
	m.Set("vault.auto_sync", "true")
	val, _ := m.Get("vault.auto_sync")
	if val != "true" {
		t.Errorf("expected 'true', got '%s'", val)
	}

	// Set false
	m.Set("vault.auto_sync", "false")
	val, _ = m.Get("vault.auto_sync")
	if val != "false" {
		t.Errorf("expected 'false', got '%s'", val)
	}
}

// TestGetSetFeatures verifies Get/Set for features
func TestGetSetFeatures(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "config-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	m := NewManager(tmpDir, tmpDir)

	// Set feature
	err = m.Set("features.vault", "true")
	if err != nil {
		t.Fatalf("Set failed: %v", err)
	}

	// Get feature
	val, err := m.Get("features.vault")
	if err != nil {
		t.Fatalf("Get failed: %v", err)
	}

	if val != "true" {
		t.Errorf("expected 'true', got '%s'", val)
	}
}

// TestGetLayeredEnv verifies env var takes precedence
func TestGetLayeredEnv(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "config-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	m := NewManager(tmpDir, tmpDir)

	// Save a value in config
	m.Set("vault.backend", "bitwarden")

	// Set env var (should take precedence)
	orig := os.Getenv("BLACKDOT_VAULT_BACKEND")
	os.Setenv("BLACKDOT_VAULT_BACKEND", "1password")
	defer os.Setenv("BLACKDOT_VAULT_BACKEND", orig)

	result, err := m.GetLayered("vault.backend")
	if err != nil {
		t.Fatalf("GetLayered failed: %v", err)
	}

	if result.Value != "1password" {
		t.Errorf("expected Value='1password', got '%s'", result.Value)
	}

	if result.Source != LayerEnv {
		t.Errorf("expected Source=env, got '%s'", result.Source)
	}
}

// TestGetLayeredUser verifies user config fallback
func TestGetLayeredUser(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "config-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	m := NewManager(tmpDir, tmpDir)

	// Save a value in config
	m.Set("vault.backend", "bitwarden")

	// Clear any env var
	orig := os.Getenv("BLACKDOT_VAULT_BACKEND")
	os.Unsetenv("BLACKDOT_VAULT_BACKEND")
	defer os.Setenv("BLACKDOT_VAULT_BACKEND", orig)

	result, err := m.GetLayered("vault.backend")
	if err != nil {
		t.Fatalf("GetLayered failed: %v", err)
	}

	if result.Value != "bitwarden" {
		t.Errorf("expected Value='bitwarden', got '%s'", result.Value)
	}

	if result.Source != LayerUser {
		t.Errorf("expected Source=user, got '%s'", result.Source)
	}
}

// TestGetLayeredDefault verifies default fallback
func TestGetLayeredDefault(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "config-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	m := NewManager(tmpDir, tmpDir)

	// Clear env var
	orig := os.Getenv("BLACKDOT_VAULT_BACKEND")
	os.Unsetenv("BLACKDOT_VAULT_BACKEND")
	defer os.Setenv("BLACKDOT_VAULT_BACKEND", orig)

	result, err := m.GetLayered("vault.backend")
	if err != nil {
		t.Fatalf("GetLayered failed: %v", err)
	}

	if result.Source != LayerDefault {
		t.Errorf("expected Source=default, got '%s'", result.Source)
	}
}

// TestSetUnknownSection verifies error for unknown section
func TestSetUnknownSection(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "config-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	m := NewManager(tmpDir, tmpDir)

	err = m.Set("unknown.key", "value")
	if err == nil {
		t.Error("Set should fail for unknown section")
	}
}

// TestSetUnknownVaultKey verifies error for unknown vault key
func TestSetUnknownVaultKey(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "config-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	m := NewManager(tmpDir, tmpDir)

	err = m.Set("vault.unknown", "value")
	if err == nil {
		t.Error("Set should fail for unknown vault key")
	}
}

// TestLayerConstants verifies layer constants
func TestLayerConstants(t *testing.T) {
	if LayerEnv != "env" {
		t.Error("LayerEnv should be 'env'")
	}
	if LayerProject != "project" {
		t.Error("LayerProject should be 'project'")
	}
	if LayerMachine != "machine" {
		t.Error("LayerMachine should be 'machine'")
	}
	if LayerUser != "user" {
		t.Error("LayerUser should be 'user'")
	}
	if LayerDefault != "default" {
		t.Error("LayerDefault should be 'default'")
	}
}

// TestConfigFileConstants verifies file name constants
func TestConfigFileConstants(t *testing.T) {
	if ProjectConfigFile != ".blackdot.json" {
		t.Error("ProjectConfigFile should be '.blackdot.json'")
	}
	if MachineConfigFile != "machine.json" {
		t.Error("MachineConfigFile should be 'machine.json'")
	}
	if UserConfigFile != "config.json" {
		t.Error("UserConfigFile should be 'config.json'")
	}
}

// TestProjectConfigPath verifies project config discovery
func TestProjectConfigPath(t *testing.T) {
	// Create temp directory structure
	tmpDir, err := os.MkdirTemp("", "config-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	// Resolve symlinks (macOS: /var -> /private/var)
	tmpDir, err = filepath.EvalSymlinks(tmpDir)
	if err != nil {
		t.Fatal(err)
	}

	// Create project config in temp dir
	projectConfig := filepath.Join(tmpDir, ".blackdot.json")
	os.WriteFile(projectConfig, []byte(`{"version":3}`), 0644)

	// Create subdirectory
	subDir := filepath.Join(tmpDir, "subdir")
	os.MkdirAll(subDir, 0755)

	// Save original cwd and change to subdir
	origDir, _ := os.Getwd()
	os.Chdir(subDir)
	defer os.Chdir(origDir)

	m := NewManager(tmpDir, tmpDir)
	path := m.ProjectConfigPath()

	if path != projectConfig {
		t.Errorf("expected '%s', got '%s'", projectConfig, path)
	}
}

// TestVaultConfigFields verifies VaultConfig struct
func TestVaultConfigFields(t *testing.T) {
	cfg := &Config{
		Vault: VaultConfig{
			Backend:   "bitwarden",
			AutoSync:  true,
			Location:  "/path/to/vault",
			Namespace: "blackdot",
		},
	}

	if cfg.Vault.Backend != "bitwarden" {
		t.Error("Backend not set correctly")
	}
	if !cfg.Vault.AutoSync {
		t.Error("AutoSync not set correctly")
	}
	if cfg.Vault.Location != "/path/to/vault" {
		t.Error("Location not set correctly")
	}
	if cfg.Vault.Namespace != "blackdot" {
		t.Error("Namespace not set correctly")
	}
}

// TestSetupStateFields verifies SetupState struct
func TestSetupStateFields(t *testing.T) {
	cfg := &Config{
		Setup: SetupState{
			Completed: []string{"packages", "vault"},
			Timestamp: "2025-01-01T00:00:00Z",
		},
	}

	if len(cfg.Setup.Completed) != 2 {
		t.Error("Completed not set correctly")
	}
	if cfg.Setup.Timestamp != "2025-01-01T00:00:00Z" {
		t.Error("Timestamp not set correctly")
	}
}

// TestLayerResultFields verifies LayerResult struct
func TestLayerResultFields(t *testing.T) {
	result := &LayerResult{
		Key:    "vault.backend",
		Value:  "bitwarden",
		Source: LayerUser,
		File:   "/path/to/config.json",
	}

	if result.Key != "vault.backend" {
		t.Error("Key not set correctly")
	}
	if result.Value != "bitwarden" {
		t.Error("Value not set correctly")
	}
	if result.Source != LayerUser {
		t.Error("Source not set correctly")
	}
	if result.File != "/path/to/config.json" {
		t.Error("File not set correctly")
	}
}
