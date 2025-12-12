package cli

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// TestDevcontainerCommand verifies command structure
func TestDevcontainerCommand(t *testing.T) {
	cmd := newDevcontainerCmd()

	if cmd.Use != "devcontainer" {
		t.Errorf("expected Use='devcontainer', got '%s'", cmd.Use)
	}

	if cmd.Short == "" {
		t.Error("devcontainer command should have Short description")
	}

	if cmd.Long == "" {
		t.Error("devcontainer command should have Long description")
	}
}

// TestDevcontainerSubcommands verifies subcommands exist
func TestDevcontainerSubcommands(t *testing.T) {
	cmd := newDevcontainerCmd()

	expectedSubcommands := []string{"init", "images", "services"}
	subcommands := make(map[string]bool)
	for _, sub := range cmd.Commands() {
		subcommands[sub.Name()] = true
	}

	for _, expected := range expectedSubcommands {
		if !subcommands[expected] {
			t.Errorf("expected subcommand '%s' not found", expected)
		}
	}
}

// TestDevcontainerInitFlags verifies init command flags
func TestDevcontainerInitFlags(t *testing.T) {
	cmd := newDevcontainerInitCmd()

	flags := []struct {
		name      string
		shorthand string
	}{
		{"image", ""},
		{"preset", ""},
		{"output", "o"},
		{"force", "f"},
		{"no-extensions", ""},
		{"services", ""},
	}

	for _, f := range flags {
		t.Run(f.name, func(t *testing.T) {
			flag := cmd.Flags().Lookup(f.name)
			if flag == nil {
				t.Errorf("flag '--%s' not found", f.name)
				return
			}
			if f.shorthand != "" && flag.Shorthand != f.shorthand {
				t.Errorf("expected shorthand '-%s', got '-%s'", f.shorthand, flag.Shorthand)
			}
		})
	}
}

// TestDevcontainerImages verifies image list
func TestDevcontainerImages(t *testing.T) {
	if len(devcontainerImages) == 0 {
		t.Fatal("devcontainerImages should not be empty")
	}

	expectedImages := []string{"Go", "Rust", "Python", "Node", "Ubuntu", "Alpine"}
	imageNames := make(map[string]bool)
	for _, img := range devcontainerImages {
		// Extract first word of name
		imageNames[img.Name] = true
	}

	for _, expected := range expectedImages {
		found := false
		for name := range imageNames {
			if name == expected || len(name) > len(expected) && name[:len(expected)] == expected {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("expected image containing '%s' not found", expected)
		}
	}
}

// TestDevcontainerImageStructure verifies image struct fields
func TestDevcontainerImageStructure(t *testing.T) {
	for _, img := range devcontainerImages {
		t.Run(img.Name, func(t *testing.T) {
			if img.Name == "" {
				t.Error("image should have Name")
			}
			if img.Image == "" {
				t.Error("image should have Image URL")
			}
			if img.Description == "" {
				t.Error("image should have Description")
			}
			// Extensions can be empty for base images
		})
	}
}

// TestDevcontainerPresets verifies preset list
func TestDevcontainerPresets(t *testing.T) {
	if len(devcontainerPresets) == 0 {
		t.Fatal("devcontainerPresets should not be empty")
	}

	expectedPresets := []string{"minimal", "developer", "claude", "full"}
	presetNames := make(map[string]bool)
	for _, p := range devcontainerPresets {
		presetNames[p.Name] = true
	}

	for _, expected := range expectedPresets {
		if !presetNames[expected] {
			t.Errorf("expected preset '%s' not found", expected)
		}
	}
}

// TestGenerateDevcontainerConfig verifies config generation
func TestGenerateDevcontainerConfig(t *testing.T) {
	image := DevcontainerImage{
		Name:        "Go 1.23",
		Image:       "mcr.microsoft.com/devcontainers/go:1.23",
		Description: "Go development",
		Extensions:  []string{"golang.go"},
	}

	config := generateDevcontainerConfig(image, "developer", false)

	// Check basic fields
	if config.Name != "Development Container" {
		t.Errorf("expected Name='Development Container', got '%s'", config.Name)
	}
	if config.Image != image.Image {
		t.Errorf("expected Image='%s', got '%s'", image.Image, config.Image)
	}
	if config.RemoteUser != "vscode" {
		t.Errorf("expected RemoteUser='vscode', got '%s'", config.RemoteUser)
	}

	// Check features
	if config.Features == nil {
		t.Fatal("Features should not be nil")
	}
	blackdotFeature, ok := config.Features["ghcr.io/blackwell-systems/blackdot:1"]
	if !ok {
		t.Error("blackdot feature should be present")
	}
	if blackdotFeature["preset"] != "developer" {
		t.Errorf("expected preset='developer', got '%s'", blackdotFeature["preset"])
	}

	// Check postStartCommand
	if config.PostStartCommand != "blackdot setup --preset developer" {
		t.Errorf("unexpected PostStartCommand: %s", config.PostStartCommand)
	}

	// Check VS Code extensions
	if config.Customizations == nil || config.Customizations.VSCode == nil {
		t.Error("Customizations.VSCode should not be nil when extensions provided")
	} else if len(config.Customizations.VSCode.Extensions) != 1 {
		t.Errorf("expected 1 extension, got %d", len(config.Customizations.VSCode.Extensions))
	}

	// Check SSH agent forwarding
	if len(config.Mounts) == 0 {
		t.Error("Mounts should contain SSH agent socket mount")
	}
	if config.ContainerEnv == nil || config.ContainerEnv["SSH_AUTH_SOCK"] != "/ssh-agent" {
		t.Error("ContainerEnv should set SSH_AUTH_SOCK")
	}
}

// TestGenerateDevcontainerConfigNoExtensions verifies --no-extensions flag
func TestGenerateDevcontainerConfigNoExtensions(t *testing.T) {
	image := DevcontainerImage{
		Name:       "Go 1.23",
		Image:      "mcr.microsoft.com/devcontainers/go:1.23",
		Extensions: []string{"golang.go"},
	}

	config := generateDevcontainerConfig(image, "developer", true) // noVSExt = true

	if config.Customizations != nil {
		t.Error("Customizations should be nil when noVSExt is true")
	}
}

// TestGenerateDevcontainerConfigBaseImage verifies base image without extensions
func TestGenerateDevcontainerConfigBaseImage(t *testing.T) {
	image := DevcontainerImage{
		Name:       "Ubuntu",
		Image:      "mcr.microsoft.com/devcontainers/base:ubuntu",
		Extensions: []string{}, // No extensions
	}

	config := generateDevcontainerConfig(image, "minimal", false)

	// Should not have Customizations when no extensions
	if config.Customizations != nil {
		t.Error("Customizations should be nil for base image without extensions")
	}
}

// TestDevcontainerConfigJSON verifies JSON serialization
func TestDevcontainerConfigJSON(t *testing.T) {
	image := DevcontainerImage{
		Name:       "Python 3.12",
		Image:      "mcr.microsoft.com/devcontainers/python:3.12",
		Extensions: []string{"ms-python.python"},
	}

	config := generateDevcontainerConfig(image, "claude", false)

	jsonData, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		t.Fatalf("failed to marshal config: %v", err)
	}

	// Verify it's valid JSON by unmarshaling
	var parsed DevcontainerConfig
	if err := json.Unmarshal(jsonData, &parsed); err != nil {
		t.Fatalf("failed to unmarshal config: %v", err)
	}

	if parsed.Image != config.Image {
		t.Error("JSON roundtrip failed: Image mismatch")
	}
}

// TestRunDevcontainerInit verifies end-to-end init
func TestRunDevcontainerInit(t *testing.T) {
	tmpDir := t.TempDir()
	outputDir := filepath.Join(tmpDir, ".devcontainer")

	err := runDevcontainerInit("go", "developer", outputDir, false, false, nil)
	if err != nil {
		t.Fatalf("runDevcontainerInit failed: %v", err)
	}

	// Check file exists
	configPath := filepath.Join(outputDir, "devcontainer.json")
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		t.Error("devcontainer.json was not created")
	}

	// Read and verify content
	data, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatalf("failed to read devcontainer.json: %v", err)
	}

	var config DevcontainerConfig
	if err := json.Unmarshal(data, &config); err != nil {
		t.Fatalf("failed to parse devcontainer.json: %v", err)
	}

	if config.Image != "mcr.microsoft.com/devcontainers/go:1.23" {
		t.Errorf("unexpected image: %s", config.Image)
	}
}

// TestRunDevcontainerInitOverwrite verifies --force flag
func TestRunDevcontainerInitOverwrite(t *testing.T) {
	tmpDir := t.TempDir()
	outputDir := filepath.Join(tmpDir, ".devcontainer")

	// Create first config
	err := runDevcontainerInit("go", "developer", outputDir, false, false, nil)
	if err != nil {
		t.Fatalf("first runDevcontainerInit failed: %v", err)
	}

	// Try without force - should fail
	err = runDevcontainerInit("rust", "claude", outputDir, false, false, nil)
	if err == nil {
		t.Error("expected error when overwriting without --force")
	}

	// Try with force - should succeed
	err = runDevcontainerInit("rust", "claude", outputDir, true, false, nil)
	if err != nil {
		t.Fatalf("runDevcontainerInit with force failed: %v", err)
	}

	// Verify it was overwritten
	data, _ := os.ReadFile(filepath.Join(outputDir, "devcontainer.json"))
	var config DevcontainerConfig
	json.Unmarshal(data, &config)
	if config.Image != "mcr.microsoft.com/devcontainers/rust:latest" {
		t.Error("config was not overwritten")
	}
}

// TestRunDevcontainerInitInvalidImage verifies error for unknown image
func TestRunDevcontainerInitInvalidImage(t *testing.T) {
	tmpDir := t.TempDir()
	outputDir := filepath.Join(tmpDir, ".devcontainer")

	err := runDevcontainerInit("invalid-image", "developer", outputDir, false, false, nil)
	if err == nil {
		t.Error("expected error for invalid image")
	}
}

// TestRunDevcontainerInitInvalidPreset verifies error for unknown preset
func TestRunDevcontainerInitInvalidPreset(t *testing.T) {
	tmpDir := t.TempDir()
	outputDir := filepath.Join(tmpDir, ".devcontainer")

	err := runDevcontainerInit("go", "invalid-preset", outputDir, false, false, nil)
	if err == nil {
		t.Error("expected error for invalid preset")
	}
}

// TestRunDevcontainerInitWithServices verifies services support
func TestRunDevcontainerInitWithServices(t *testing.T) {
	tmpDir := t.TempDir()
	outputDir := filepath.Join(tmpDir, ".devcontainer")

	err := runDevcontainerInit("go", "developer", outputDir, false, false, []string{"postgres", "redis"})
	if err != nil {
		t.Fatalf("runDevcontainerInit with services failed: %v", err)
	}

	// Check docker-compose.yml exists
	composePath := filepath.Join(outputDir, "docker-compose.yml")
	if _, err := os.Stat(composePath); os.IsNotExist(err) {
		t.Error("docker-compose.yml was not created")
	}

	// Check .env.example exists
	envPath := filepath.Join(outputDir, ".env.example")
	if _, err := os.Stat(envPath); os.IsNotExist(err) {
		t.Error(".env.example was not created")
	}

	// Check devcontainer.json references compose
	configPath := filepath.Join(outputDir, "devcontainer.json")
	data, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatalf("failed to read devcontainer.json: %v", err)
	}

	var config DevcontainerConfig
	if err := json.Unmarshal(data, &config); err != nil {
		t.Fatalf("failed to parse devcontainer.json: %v", err)
	}

	if config.DockerComposeFile != "docker-compose.yml" {
		t.Errorf("expected dockerComposeFile='docker-compose.yml', got '%s'", config.DockerComposeFile)
	}
	if config.Service != "app" {
		t.Errorf("expected service='app', got '%s'", config.Service)
	}
	if config.Image != "" {
		t.Error("image should be empty when using docker-compose")
	}
}

// TestDevcontainerServices verifies services list
func TestDevcontainerServices(t *testing.T) {
	if len(devcontainerServices) == 0 {
		t.Fatal("devcontainerServices should not be empty")
	}

	expectedServices := []string{"postgres", "redis", "mysql", "mongo", "sqlite", "localstack", "minio"}
	serviceNames := make(map[string]bool)
	for _, svc := range devcontainerServices {
		serviceNames[svc.Name] = true
	}

	for _, expected := range expectedServices {
		if !serviceNames[expected] {
			t.Errorf("expected service '%s' not found", expected)
		}
	}
}

// TestDevcontainerServicesSubcommand verifies services subcommand exists
func TestDevcontainerServicesSubcommand(t *testing.T) {
	cmd := newDevcontainerCmd()

	found := false
	for _, sub := range cmd.Commands() {
		if sub.Name() == "services" {
			found = true
			break
		}
	}

	if !found {
		t.Error("expected subcommand 'services' not found")
	}
}
