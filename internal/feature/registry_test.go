package feature

import (
	"os"
	"testing"
)

// TestNewRegistry verifies registry initialization
func TestNewRegistry(t *testing.T) {
	r := NewRegistry()

	if r == nil {
		t.Fatal("NewRegistry should not return nil")
	}

	if len(r.features) == 0 {
		t.Error("Registry should have features registered")
	}
}

// TestCoreFeatureAlwaysEnabled verifies core features are always enabled
func TestCoreFeatureAlwaysEnabled(t *testing.T) {
	r := NewRegistry()

	// Shell is a core feature
	if !r.Enabled("shell") {
		t.Error("core feature 'shell' should always be enabled")
	}

	// Try to disable it - should fail
	err := r.Disable("shell")
	if err == nil {
		t.Error("disabling core feature should return error")
	}

	// Should still be enabled
	if !r.Enabled("shell") {
		t.Error("core feature 'shell' should still be enabled after failed disable")
	}
}

// TestFeatureExists verifies Exists function
func TestFeatureExists(t *testing.T) {
	r := NewRegistry()

	if !r.Exists("vault") {
		t.Error("vault feature should exist")
	}

	if r.Exists("nonexistent_feature") {
		t.Error("nonexistent_feature should not exist")
	}
}

// TestFeatureGet verifies Get function
func TestFeatureGet(t *testing.T) {
	r := NewRegistry()

	f, ok := r.Get("vault")
	if !ok {
		t.Fatal("vault feature should exist")
	}

	if f.Name != "vault" {
		t.Errorf("expected Name='vault', got '%s'", f.Name)
	}

	if f.Category != CategoryOptional {
		t.Errorf("expected Category=optional, got '%s'", f.Category)
	}

	if f.Description == "" {
		t.Error("vault should have a description")
	}

	// Non-existent feature
	_, ok = r.Get("nonexistent")
	if ok {
		t.Error("Get should return false for nonexistent feature")
	}
}

// TestEnableDisable verifies enable/disable functionality
func TestEnableDisable(t *testing.T) {
	r := NewRegistry()

	// vault starts disabled (DefaultFalse)
	if r.Enabled("vault") {
		t.Error("vault should be disabled by default")
	}

	// Enable it
	err := r.Enable("vault")
	if err != nil {
		t.Fatalf("Enable failed: %v", err)
	}

	if !r.Enabled("vault") {
		t.Error("vault should be enabled after Enable()")
	}

	// Disable it
	err = r.Disable("vault")
	if err != nil {
		t.Fatalf("Disable failed: %v", err)
	}

	if r.Enabled("vault") {
		t.Error("vault should be disabled after Disable()")
	}
}

// TestEnableUnknownFeature verifies error on unknown feature
func TestEnableUnknownFeature(t *testing.T) {
	r := NewRegistry()

	err := r.Enable("nonexistent_feature")
	if err == nil {
		t.Error("Enable should fail for unknown feature")
	}
}

// TestDisableUnknownFeature verifies error on unknown feature
func TestDisableUnknownFeature(t *testing.T) {
	r := NewRegistry()

	err := r.Disable("nonexistent_feature")
	if err == nil {
		t.Error("Disable should fail for unknown feature")
	}
}

// TestDependencyEnabling verifies dependencies are auto-enabled
func TestDependencyEnabling(t *testing.T) {
	r := NewRegistry()

	// claude_integration depends on workspace_symlink
	// Both start disabled
	if r.Enabled("workspace_symlink") {
		t.Error("workspace_symlink should be disabled initially")
	}

	// Enable claude_integration (should auto-enable workspace_symlink)
	err := r.Enable("claude_integration")
	if err != nil {
		t.Fatalf("Enable failed: %v", err)
	}

	if !r.Enabled("workspace_symlink") {
		t.Error("dependency workspace_symlink should be auto-enabled")
	}

	if !r.Enabled("claude_integration") {
		t.Error("claude_integration should be enabled")
	}
}

// TestDependencies verifies Dependencies function
func TestDependencies(t *testing.T) {
	r := NewRegistry()

	deps := r.Dependencies("claude_integration")
	if len(deps) == 0 {
		t.Error("claude_integration should have dependencies")
	}

	found := false
	for _, dep := range deps {
		if dep == "workspace_symlink" {
			found = true
			break
		}
	}
	if !found {
		t.Error("claude_integration should depend on workspace_symlink")
	}

	// Feature without dependencies
	deps = r.Dependencies("vault")
	if len(deps) != 0 {
		t.Error("vault should have no dependencies")
	}
}

// TestDependents verifies Dependents function
func TestDependents(t *testing.T) {
	r := NewRegistry()

	dependents := r.Dependents("workspace_symlink")
	if len(dependents) == 0 {
		t.Error("workspace_symlink should have dependents")
	}

	found := false
	for _, dep := range dependents {
		if dep == "claude_integration" {
			found = true
			break
		}
	}
	if !found {
		t.Error("claude_integration should be a dependent of workspace_symlink")
	}
}

// TestMissingDeps verifies MissingDeps function
func TestMissingDeps(t *testing.T) {
	r := NewRegistry()

	// claude_integration depends on workspace_symlink which is disabled
	missing := r.MissingDeps("claude_integration")
	if len(missing) == 0 {
		t.Error("claude_integration should have missing dependencies")
	}

	// Enable the dependency
	r.Enable("workspace_symlink")
	missing = r.MissingDeps("claude_integration")
	if len(missing) != 0 {
		t.Error("claude_integration should have no missing dependencies after enabling workspace_symlink")
	}
}

// TestByCategory verifies ByCategory function
func TestByCategory(t *testing.T) {
	r := NewRegistry()

	core := r.ByCategory(CategoryCore)
	if len(core) == 0 {
		t.Error("should have core features")
	}

	optional := r.ByCategory(CategoryOptional)
	if len(optional) == 0 {
		t.Error("should have optional features")
	}

	integration := r.ByCategory(CategoryIntegration)
	if len(integration) == 0 {
		t.Error("should have integration features")
	}

	// Verify shell is in core
	found := false
	for _, f := range core {
		if f.Name == "shell" {
			found = true
			break
		}
	}
	if !found {
		t.Error("shell should be in core category")
	}
}

// TestAll verifies All function
func TestAll(t *testing.T) {
	r := NewRegistry()

	all := r.All()
	if len(all) == 0 {
		t.Error("All should return features")
	}

	// Should be sorted by name
	for i := 1; i < len(all); i++ {
		if all[i].Name < all[i-1].Name {
			t.Error("All should return features sorted by name")
			break
		}
	}
}

// TestList verifies List function
func TestList(t *testing.T) {
	r := NewRegistry()

	// All features
	all := r.List("")
	if len(all) == 0 {
		t.Error("List should return features")
	}

	// Filtered by category
	optional := r.List("optional")
	if len(optional) == 0 {
		t.Error("List with optional filter should return features")
	}

	if len(optional) >= len(all) {
		t.Error("filtered list should be smaller than all")
	}
}

// TestLoadState verifies LoadState function
func TestLoadState(t *testing.T) {
	r := NewRegistry()

	state := map[string]bool{
		"vault":     true,
		"templates": true,
	}

	r.LoadState(state)

	if !r.Enabled("vault") {
		t.Error("vault should be enabled after LoadState")
	}

	if !r.Enabled("templates") {
		t.Error("templates should be enabled after LoadState")
	}
}

// TestSaveState verifies SaveState function
func TestSaveState(t *testing.T) {
	r := NewRegistry()

	// Enable some features
	r.Enable("vault")
	r.Enable("templates")

	state := r.SaveState()

	if !state["vault"] {
		t.Error("vault should be in saved state")
	}

	if !state["templates"] {
		t.Error("templates should be in saved state")
	}

	// Core features should not be saved
	if _, ok := state["shell"]; ok {
		t.Error("core feature 'shell' should not be in saved state")
	}
}

// TestValidate verifies Validate function
func TestValidate(t *testing.T) {
	r := NewRegistry()

	err := r.Validate()
	if err != nil {
		t.Errorf("Validate should pass for default registry: %v", err)
	}
}

// TestEnvOverride verifies environment variable overrides
func TestEnvOverride(t *testing.T) {
	r := NewRegistry()

	// Save original env
	original := os.Getenv("BLACKDOT_FEATURE_VAULT")
	defer os.Setenv("BLACKDOT_FEATURE_VAULT", original)

	// Test direct env var
	os.Setenv("BLACKDOT_FEATURE_VAULT", "true")

	// Need new registry to pick up env
	r = NewRegistry()
	if !r.Enabled("vault") {
		t.Error("vault should be enabled via BLACKDOT_FEATURE_VAULT=true")
	}

	os.Setenv("BLACKDOT_FEATURE_VAULT", "false")
	r = NewRegistry()
	if r.Enabled("vault") {
		t.Error("vault should be disabled via BLACKDOT_FEATURE_VAULT=false")
	}
}

// TestSkipEnvVarOverride verifies SKIP_* env vars work (inverted logic)
func TestSkipEnvVarOverride(t *testing.T) {
	r := NewRegistry()

	// Save original env
	original := os.Getenv("SKIP_WORKSPACE_SYMLINK")
	defer os.Setenv("SKIP_WORKSPACE_SYMLINK", original)

	// Enable workspace_symlink first
	r.Enable("workspace_symlink")
	if !r.Enabled("workspace_symlink") {
		t.Fatal("workspace_symlink should be enabled")
	}

	// SKIP_* vars have inverted logic: SKIP_X=true means feature=false
	os.Setenv("SKIP_WORKSPACE_SYMLINK", "true")

	// The env check happens in Enabled() but runtime state takes precedence
	// Let's test with a fresh registry
	r = NewRegistry()
	if r.Enabled("workspace_symlink") {
		t.Error("workspace_symlink should be disabled via SKIP_WORKSPACE_SYMLINK=true")
	}
}

// TestEnabledNonexistent verifies Enabled returns false for unknown features
func TestEnabledNonexistent(t *testing.T) {
	r := NewRegistry()

	if r.Enabled("nonexistent_feature") {
		t.Error("Enabled should return false for nonexistent feature")
	}
}

// TestCategories verifies category constants
func TestCategories(t *testing.T) {
	if CategoryCore != "core" {
		t.Errorf("expected CategoryCore='core', got '%s'", CategoryCore)
	}
	if CategoryOptional != "optional" {
		t.Errorf("expected CategoryOptional='optional', got '%s'", CategoryOptional)
	}
	if CategoryIntegration != "integration" {
		t.Errorf("expected CategoryIntegration='integration', got '%s'", CategoryIntegration)
	}
}

// TestDefaultValues verifies default value constants
func TestDefaultValues(t *testing.T) {
	if DefaultTrue != "true" {
		t.Errorf("expected DefaultTrue='true', got '%s'", DefaultTrue)
	}
	if DefaultFalse != "false" {
		t.Errorf("expected DefaultFalse='false', got '%s'", DefaultFalse)
	}
	if DefaultEnv != "env" {
		t.Errorf("expected DefaultEnv='env', got '%s'", DefaultEnv)
	}
}

// TestFeatureDefaults verifies specific feature defaults
func TestFeatureDefaults(t *testing.T) {
	r := NewRegistry()

	tests := []struct {
		feature  string
		expected bool
	}{
		{"shell", true},            // core
		{"vault", false},           // DefaultFalse
		{"git_hooks", true},        // DefaultTrue
		{"modern_cli", true},       // DefaultTrue
		{"workspace_symlink", false}, // DefaultEnv (no env set)
	}

	for _, tt := range tests {
		t.Run(tt.feature, func(t *testing.T) {
			if r.Enabled(tt.feature) != tt.expected {
				t.Errorf("expected Enabled('%s')=%v", tt.feature, tt.expected)
			}
		})
	}
}

// TestCDKDependsOnAWS verifies cdk_tools depends on aws_helpers
func TestCDKDependsOnAWS(t *testing.T) {
	r := NewRegistry()

	deps := r.Dependencies("cdk_tools")
	found := false
	for _, dep := range deps {
		if dep == "aws_helpers" {
			found = true
			break
		}
	}
	if !found {
		t.Error("cdk_tools should depend on aws_helpers")
	}
}

// TestDotclaudeDependsOnClaude verifies dotclaude depends on claude_integration
func TestDotclaudeDependsOnClaude(t *testing.T) {
	r := NewRegistry()

	deps := r.Dependencies("dotclaude")
	found := false
	for _, dep := range deps {
		if dep == "claude_integration" {
			found = true
			break
		}
	}
	if !found {
		t.Error("dotclaude should depend on claude_integration")
	}
}
