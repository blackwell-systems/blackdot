package feature

import (
	"testing"
)

// TestGetPreset verifies GetPreset function
func TestGetPreset(t *testing.T) {
	tests := []string{"minimal", "developer", "claude", "full"}

	for _, name := range tests {
		t.Run(name, func(t *testing.T) {
			preset, ok := GetPreset(name)
			if !ok {
				t.Errorf("preset '%s' should exist", name)
				return
			}
			if preset.Name != name {
				t.Errorf("expected Name='%s', got '%s'", name, preset.Name)
			}
			if preset.Description == "" {
				t.Error("preset should have description")
			}
			if len(preset.Features) == 0 {
				t.Error("preset should have features")
			}
		})
	}
}

// TestGetPresetUnknown verifies GetPreset returns false for unknown presets
func TestGetPresetUnknown(t *testing.T) {
	_, ok := GetPreset("nonexistent")
	if ok {
		t.Error("GetPreset should return false for unknown preset")
	}
}

// TestAllPresets verifies AllPresets function
func TestAllPresets(t *testing.T) {
	all := AllPresets()

	if len(all) != 4 {
		t.Errorf("expected 4 presets, got %d", len(all))
	}

	// Verify order
	expected := []string{"minimal", "developer", "claude", "full"}
	for i, preset := range all {
		if preset.Name != expected[i] {
			t.Errorf("expected preset[%d]='%s', got '%s'", i, expected[i], preset.Name)
		}
	}
}

// TestPresetNames verifies PresetNames function
func TestPresetNames(t *testing.T) {
	names := PresetNames()

	if len(names) != 4 {
		t.Errorf("expected 4 names, got %d", len(names))
	}

	expected := []string{"minimal", "developer", "claude", "full"}
	for i, name := range names {
		if name != expected[i] {
			t.Errorf("expected names[%d]='%s', got '%s'", i, expected[i], name)
		}
	}
}

// TestApplyPresetMinimal verifies minimal preset
func TestApplyPresetMinimal(t *testing.T) {
	r := NewRegistry()

	err := r.ApplyPreset("minimal")
	if err != nil {
		t.Fatalf("ApplyPreset failed: %v", err)
	}

	// Shell should be enabled
	if !r.Enabled("shell") {
		t.Error("shell should be enabled in minimal preset")
	}

	// config_layers should be enabled
	if !r.Enabled("config_layers") {
		t.Error("config_layers should be enabled in minimal preset")
	}

	// vault should NOT be enabled in minimal
	if r.Enabled("vault") {
		t.Error("vault should NOT be enabled in minimal preset")
	}
}

// TestApplyPresetDeveloper verifies developer preset
func TestApplyPresetDeveloper(t *testing.T) {
	r := NewRegistry()

	err := r.ApplyPreset("developer")
	if err != nil {
		t.Fatalf("ApplyPreset failed: %v", err)
	}

	// Check key developer features
	expected := []string{"vault", "aws_helpers", "git_hooks", "modern_cli"}
	for _, feature := range expected {
		if !r.Enabled(feature) {
			t.Errorf("%s should be enabled in developer preset", feature)
		}
	}
}

// TestApplyPresetClaude verifies claude preset
func TestApplyPresetClaude(t *testing.T) {
	r := NewRegistry()

	err := r.ApplyPreset("claude")
	if err != nil {
		t.Fatalf("ApplyPreset failed: %v", err)
	}

	// Check key claude features
	expected := []string{"workspace_symlink", "claude_integration", "vault"}
	for _, feature := range expected {
		if !r.Enabled(feature) {
			t.Errorf("%s should be enabled in claude preset", feature)
		}
	}
}

// TestApplyPresetFull verifies full preset
func TestApplyPresetFull(t *testing.T) {
	r := NewRegistry()

	err := r.ApplyPreset("full")
	if err != nil {
		t.Fatalf("ApplyPreset failed: %v", err)
	}

	// Check that many features are enabled
	fullPreset, _ := GetPreset("full")
	for _, feature := range fullPreset.Features {
		if !r.Enabled(feature) {
			t.Errorf("%s should be enabled in full preset", feature)
		}
	}
}

// TestApplyPresetUnknown verifies error for unknown preset
func TestApplyPresetUnknown(t *testing.T) {
	r := NewRegistry()

	err := r.ApplyPreset("nonexistent")
	if err == nil {
		t.Error("ApplyPreset should fail for unknown preset")
	}

	// Verify it's the right error type
	if _, ok := err.(*PresetNotFoundError); !ok {
		t.Errorf("expected PresetNotFoundError, got %T", err)
	}
}

// TestPresetNotFoundError verifies error message
func TestPresetNotFoundError(t *testing.T) {
	err := &PresetNotFoundError{Name: "test"}

	if err.Error() != "unknown preset: test" {
		t.Errorf("unexpected error message: %s", err.Error())
	}
}

// TestPresetResetsState verifies ApplyPreset resets previous state
func TestPresetResetsState(t *testing.T) {
	r := NewRegistry()

	// Enable vault
	r.Enable("vault")
	if !r.Enabled("vault") {
		t.Fatal("vault should be enabled")
	}

	// Apply minimal preset (which doesn't include vault)
	r.ApplyPreset("minimal")

	// vault should now be disabled
	if r.Enabled("vault") {
		t.Error("vault should be disabled after applying minimal preset")
	}
}

// TestMinimalPresetIncludesShell verifies all presets include shell
func TestAllPresetsIncludeShell(t *testing.T) {
	for _, preset := range AllPresets() {
		found := false
		for _, f := range preset.Features {
			if f == "shell" {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("preset '%s' should include 'shell'", preset.Name)
		}
	}
}

// TestDeveloperPresetHasMoreThanMinimal verifies developer > minimal
func TestDeveloperPresetHasMoreThanMinimal(t *testing.T) {
	minimal, _ := GetPreset("minimal")
	developer, _ := GetPreset("developer")

	if len(developer.Features) <= len(minimal.Features) {
		t.Error("developer preset should have more features than minimal")
	}
}

// TestFullPresetHasMoreThanDeveloper verifies full > developer
func TestFullPresetHasMoreThanDeveloper(t *testing.T) {
	developer, _ := GetPreset("developer")
	full, _ := GetPreset("full")

	if len(full.Features) <= len(developer.Features) {
		t.Error("full preset should have more features than developer")
	}
}
