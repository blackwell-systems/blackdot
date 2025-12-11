package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestRollbackCommandExists verifies rollback command is registered
func TestRollbackCommandExists(t *testing.T) {
	cmd, _, err := rootCmd.Find([]string{"rollback"})
	if err != nil {
		t.Fatalf("rollback command not found: %v", err)
	}

	if cmd.Use != "rollback" {
		t.Errorf("expected Use='rollback', got '%s'", cmd.Use)
	}

	if cmd.Short == "" {
		t.Error("rollback should have a Short description")
	}
}

// TestRollbackFlags verifies rollback command has expected flags
func TestRollbackFlags(t *testing.T) {
	cmd := newRollbackCmd()

	tests := []struct {
		name      string
		flagName  string
		shorthand string
	}{
		{"to flag", "to", ""},
		{"list flag", "list", "l"},
		{"yes flag", "yes", "y"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			flag := cmd.Flags().Lookup(tt.flagName)
			if flag == nil {
				t.Errorf("flag '--%s' not found", tt.flagName)
				return
			}
			if tt.shorthand != "" && flag.Shorthand != tt.shorthand {
				t.Errorf("expected shorthand '-%s', got '-%s'", tt.shorthand, flag.Shorthand)
			}
		})
	}
}

// TestRollbackHelp verifies rollback help output
func TestRollbackHelp(t *testing.T) {
	// Capture help output by calling the help function
	// We can't easily capture stdout, but we can verify the function doesn't panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("printRollbackHelp panicked: %v", r)
		}
	}()

	printRollbackHelp()
}

// TestRollbackListNoBackups tests rollback --list with no backups
func TestRollbackListNoBackups(t *testing.T) {
	// Create a temp directory for backups
	tmpDir, err := os.MkdirTemp("", "blackdot-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Save original home and set temp
	originalHome := os.Getenv("HOME")
	os.Setenv("HOME", tmpDir)
	defer os.Setenv("HOME", originalHome)

	// Call rollbackList - should handle no backups gracefully
	err = rollbackList()
	if err != nil {
		t.Errorf("rollbackList should not error with no backups: %v", err)
	}
}

// TestRollbackListWithBackups tests rollback --list with existing backups
func TestRollbackListWithBackups(t *testing.T) {
	// Create a temp directory structure
	tmpDir, err := os.MkdirTemp("", "blackdot-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create backup directory
	backupDir := filepath.Join(tmpDir, ".blackdot-backups")
	if err := os.MkdirAll(backupDir, 0755); err != nil {
		t.Fatalf("failed to create backup dir: %v", err)
	}

	// Create fake backup files
	backups := []string{
		"backup-20250101-120000.tar.gz",
		"backup-20250102-120000.tar.gz",
		"backup-20250103-120000.tar.gz",
	}
	for _, name := range backups {
		f, err := os.Create(filepath.Join(backupDir, name))
		if err != nil {
			t.Fatalf("failed to create backup file: %v", err)
		}
		f.WriteString("fake backup content")
		f.Close()
	}

	// Save original home and set temp
	originalHome := os.Getenv("HOME")
	os.Setenv("HOME", tmpDir)
	defer os.Setenv("HOME", originalHome)

	// Call rollbackList
	err = rollbackList()
	if err != nil {
		t.Errorf("rollbackList failed: %v", err)
	}
}

// TestRollbackRestoreNoBackups tests rollback with no backups
func TestRollbackRestoreNoBackups(t *testing.T) {
	// Create a temp directory
	tmpDir, err := os.MkdirTemp("", "blackdot-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Save original home and set temp
	originalHome := os.Getenv("HOME")
	os.Setenv("HOME", tmpDir)
	defer os.Setenv("HOME", originalHome)

	// Try to restore with no backups - should error
	err = rollbackRestore("", true) // skipConfirm=true
	if err == nil {
		t.Error("rollbackRestore should error when no backups exist")
	}
	if !strings.Contains(err.Error(), "no backups found") {
		t.Errorf("expected 'no backups found' error, got: %v", err)
	}
}

// TestRollbackRestoreSpecificNotFound tests rollback with specific backup that doesn't exist
func TestRollbackRestoreSpecificNotFound(t *testing.T) {
	// Create a temp directory with backup dir
	tmpDir, err := os.MkdirTemp("", "blackdot-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	backupDir := filepath.Join(tmpDir, ".blackdot-backups")
	os.MkdirAll(backupDir, 0755)

	// Save original home and set temp
	originalHome := os.Getenv("HOME")
	os.Setenv("HOME", tmpDir)
	defer os.Setenv("HOME", originalHome)

	// Try to restore non-existent backup
	err = rollbackRestore("nonexistent-backup", true)
	if err == nil {
		t.Error("rollbackRestore should error for non-existent backup")
	}
	if !strings.Contains(err.Error(), "not found") {
		t.Errorf("expected 'not found' error, got: %v", err)
	}
}

// TestGetBackupConfig verifies backup config defaults
func TestGetBackupConfig(t *testing.T) {
	cfg := getBackupConfig()

	if cfg == nil {
		t.Fatal("getBackupConfig should not return nil")
	}

	if cfg.maxBackups != 10 {
		t.Errorf("expected maxBackups=10, got %d", cfg.maxBackups)
	}

	if cfg.compress != true {
		t.Error("expected compress=true")
	}

	if cfg.backupDir == "" {
		t.Error("backupDir should not be empty")
	}
}

// TestFormatSize verifies size formatting
func TestFormatSize(t *testing.T) {
	tests := []struct {
		bytes    int64
		expected string
	}{
		{0, "0 B"},
		{100, "100 B"},
		{1024, "1.0 KB"},
		{1536, "1.5 KB"},
		{1048576, "1.0 MB"},
		{1073741824, "1.0 GB"},
	}

	for _, tt := range tests {
		t.Run(tt.expected, func(t *testing.T) {
			result := formatSize(tt.bytes)
			if result != tt.expected {
				t.Errorf("formatSize(%d) = '%s', expected '%s'", tt.bytes, result, tt.expected)
			}
		})
	}
}
