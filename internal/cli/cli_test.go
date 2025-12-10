package cli

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/spf13/cobra"
)

// TestRootCommand verifies the root command is configured correctly
func TestRootCommand(t *testing.T) {
	if rootCmd == nil {
		t.Fatal("rootCmd should not be nil")
	}

	if rootCmd.Use != "blackdot" {
		t.Errorf("expected Use='blackdot', got '%s'", rootCmd.Use)
	}

	if rootCmd.Short == "" {
		t.Error("rootCmd should have a Short description")
	}
}

// TestSubcommandExists verifies all expected subcommands are registered
func TestSubcommandExists(t *testing.T) {
	expectedCommands := []string{
		"version",
		"features",
		"config",
		"doctor",
		"status",
		"vault",
		"secrets", // alias for vault
		"template",
		"backup",
		"rollback",
		"hook",
		"diff",
		"drift",
		"encrypt",
		"lint",
		"metrics",
		"packages",
		"setup",
		"sync",
		"uninstall",
		"tools",
		"import",
	}

	commands := make(map[string]bool)
	for _, cmd := range rootCmd.Commands() {
		commands[cmd.Name()] = true
	}

	for _, expected := range expectedCommands {
		if !commands[expected] {
			t.Errorf("expected command '%s' not found in root commands", expected)
		}
	}
}

// TestGlobalFlags verifies global flags are registered
func TestGlobalFlags(t *testing.T) {
	tests := []struct {
		name      string
		flagName  string
		shorthand string
	}{
		{"verbose flag", "verbose", "v"},
		{"force flag", "force", ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			flag := rootCmd.PersistentFlags().Lookup(tt.flagName)
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

// TestDotfilesDir verifies directory resolution
func TestDotfilesDir(t *testing.T) {
	// Save original env
	original := os.Getenv("BLACKDOT_DIR")
	defer os.Setenv("BLACKDOT_DIR", original)

	// Test with env var set
	os.Setenv("BLACKDOT_DIR", "/custom/path")
	initConfig()
	if DotfilesDir() != "/custom/path" {
		t.Errorf("expected '/custom/path', got '%s'", DotfilesDir())
	}

	// Test with env var unset (uses default)
	os.Unsetenv("BLACKDOT_DIR")
	initConfig()
	dir := DotfilesDir()
	if !strings.HasSuffix(dir, ".blackdot") {
		t.Errorf("expected path ending in '.blackdot', got '%s'", dir)
	}
}

// TestConfigDir verifies config directory resolution
func TestConfigDir(t *testing.T) {
	// Save original env
	original := os.Getenv("XDG_CONFIG_HOME")
	defer os.Setenv("XDG_CONFIG_HOME", original)

	// Test with XDG_CONFIG_HOME set
	os.Setenv("XDG_CONFIG_HOME", "/custom/config")
	dir := ConfigDir()
	expected := filepath.FromSlash("/custom/config/blackdot")
	if dir != expected {
		t.Errorf("expected '%s', got '%s'", expected, dir)
	}

	// Test with XDG_CONFIG_HOME unset
	os.Unsetenv("XDG_CONFIG_HOME")
	dir = ConfigDir()
	if !strings.Contains(dir, filepath.FromSlash(".config/blackdot")) {
		t.Errorf("expected path containing '.config/blackdot', got '%s'", dir)
	}
}

// TestCommandHasHelp verifies commands have help configured
func TestCommandHasHelp(t *testing.T) {
	commands := []string{"vault", "backup", "rollback", "features", "config"}

	for _, name := range commands {
		t.Run(name, func(t *testing.T) {
			cmd, _, err := rootCmd.Find([]string{name})
			if err != nil {
				t.Fatalf("command '%s' not found: %v", name, err)
			}
			if cmd.Short == "" {
				t.Errorf("command '%s' should have Short description", name)
			}
		})
	}
}

// TestSecretsIsHidden verifies secrets command is hidden (alias)
func TestSecretsIsHidden(t *testing.T) {
	cmd, _, err := rootCmd.Find([]string{"secrets"})
	if err != nil {
		t.Fatalf("secrets command not found: %v", err)
	}
	if !cmd.Hidden {
		t.Error("secrets command should be hidden (it's an alias for vault)")
	}
}

// executeCommand is a helper to execute commands and capture output
func executeCommand(root *cobra.Command, args ...string) (string, error) {
	buf := new(bytes.Buffer)
	root.SetOut(buf)
	root.SetErr(buf)
	root.SetArgs(args)

	err := root.Execute()
	return buf.String(), err
}

// TestVersionCommand verifies version command structure
func TestVersionCommand(t *testing.T) {
	cmd := newVersionCmd()

	if cmd.Use != "version" {
		t.Errorf("expected Use='version', got '%s'", cmd.Use)
	}

	if cmd.Short == "" {
		t.Error("version should have Short description")
	}

	if cmd.Run == nil {
		t.Error("version should have Run function")
	}

	// Verify version info can be set
	SetVersionInfo("1.0.0-test", "abc123", "2025-01-01")
	if versionStr != "1.0.0-test" {
		t.Errorf("expected versionStr='1.0.0-test', got '%s'", versionStr)
	}
}
