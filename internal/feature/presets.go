package feature

// Preset represents a named set of features
type Preset struct {
	Name        string
	Description string
	Features    []string
}

// Built-in presets - mirrors FEATURE_PRESETS in lib/_features.sh exactly
var presets = map[string]*Preset{
	"minimal": {
		Name:        "minimal",
		Description: "Shell only (fastest startup)",
		Features: []string{
			"shell",
			"config_layers",
		},
	},
	"developer": {
		Name:        "developer",
		Description: "Vault, AWS helpers, git hooks, modern CLI",
		Features: []string{
			"shell",
			"vault",
			"aws_helpers",
			"cdk_tools",
			"rust_tools",
			"go_tools",
			"python_tools",
			"ssh_tools",
			"docker_tools",
			"nvm_integration",
			"sdkman_integration",
			"git_hooks",
			"modern_cli",
			"config_layers",
		},
	},
	"claude": {
		Name:        "claude",
		Description: "Workspace symlink, Claude integration, vault, git hooks",
		Features: []string{
			"shell",
			"workspace_symlink",
			"claude_integration",
			"vault",
			"git_hooks",
			"modern_cli",
			"config_layers",
		},
	},
	"full": {
		Name:        "full",
		Description: "All features enabled",
		Features: []string{
			"shell",
			"workspace_symlink",
			"claude_integration",
			"vault",
			"templates",
			"aws_helpers",
			"cdk_tools",
			"rust_tools",
			"go_tools",
			"python_tools",
			"ssh_tools",
			"docker_tools",
			"git_hooks",
			"drift_check",
			"backup_auto",
			"health_metrics",
			"config_layers",
			"modern_cli",
			"nvm_integration",
			"sdkman_integration",
		},
	},
}

// GetPreset returns a preset by name
func GetPreset(name string) (*Preset, bool) {
	p, ok := presets[name]
	return p, ok
}

// AllPresets returns all available presets in display order
func AllPresets() []*Preset {
	return []*Preset{
		presets["minimal"],
		presets["developer"],
		presets["claude"],
		presets["full"],
	}
}

// PresetNames returns just the preset names
func PresetNames() []string {
	return []string{"minimal", "developer", "claude", "full"}
}

// ApplyPreset applies a preset to the registry
func (r *Registry) ApplyPreset(name string) error {
	preset, ok := GetPreset(name)
	if !ok {
		return &PresetNotFoundError{Name: name}
	}

	// Reset to defaults first
	r.enabled = make(map[string]bool)
	r.initDefaults()

	// Enable preset features
	for _, fname := range preset.Features {
		if err := r.Enable(fname); err != nil {
			return err
		}
	}

	return nil
}

// PresetNotFoundError indicates an unknown preset
type PresetNotFoundError struct {
	Name string
}

func (e *PresetNotFoundError) Error() string {
	return "unknown preset: " + e.Name
}
