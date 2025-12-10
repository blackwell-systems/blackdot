// Package feature implements the feature registry for dotfiles.
//
// The feature registry is the control plane for the entire system,
// managing which features are enabled/disabled, resolving dependencies,
// and providing presets.
//
// This mirrors the functionality of lib/_features.sh
package feature

import (
	"fmt"
	"os"
	"sort"
	"strings"
)

// Category represents a feature category
type Category string

const (
	CategoryCore        Category = "core"
	CategoryOptional    Category = "optional"
	CategoryIntegration Category = "integration"
)

// DefaultValue represents how a feature's default state is determined
type DefaultValue string

const (
	DefaultTrue  DefaultValue = "true"  // Enabled by default
	DefaultFalse DefaultValue = "false" // Disabled by default
	DefaultEnv   DefaultValue = "env"   // Check env var, disabled if not set
)

// Feature represents a single feature in the registry
type Feature struct {
	Name         string
	Description  string
	Category     Category
	Dependencies []string
	Default      DefaultValue
}

// Registry manages all features
type Registry struct {
	features  map[string]*Feature
	enabled   map[string]bool
	conflicts map[string][]string // feature -> conflicting features
	envMap    map[string]string   // SKIP_* env var -> feature name
}

// NewRegistry creates a registry with all built-in features
// This mirrors FEATURE_REGISTRY in lib/_features.sh exactly
func NewRegistry() *Registry {
	r := &Registry{
		features:  make(map[string]*Feature),
		enabled:   make(map[string]bool),
		conflicts: make(map[string][]string),
		envMap:    make(map[string]string),
	}

	// ============================================================
	// Core features (always enabled)
	// ============================================================
	r.register("shell", CategoryCore, "ZSH shell, prompt, and core aliases", nil, DefaultTrue)

	// ============================================================
	// Optional features (default: disabled or env-controlled)
	// ============================================================
	r.register("workspace_symlink", CategoryOptional, "/workspace symlink for portable sessions", nil, DefaultEnv)
	r.register("claude_integration", CategoryOptional, "Claude Code integration and hooks", []string{"workspace_symlink"}, DefaultEnv)
	r.register("vault", CategoryOptional, "Multi-vault secret management (Bitwarden/1Password/pass)", nil, DefaultFalse)
	r.register("templates", CategoryOptional, "Machine-specific configuration templates", nil, DefaultFalse)
	r.register("git_hooks", CategoryOptional, "Git safety hooks (pre-commit, pre-push)", nil, DefaultTrue)
	r.register("drift_check", CategoryOptional, "Automatic drift detection on vault operations", []string{"vault"}, DefaultEnv)
	r.register("backup_auto", CategoryOptional, "Automatic backup before destructive operations", nil, DefaultFalse)
	r.register("health_metrics", CategoryOptional, "Health check metrics collection and trending", nil, DefaultFalse)
	r.register("macos_settings", CategoryOptional, "macOS system preferences automation", nil, DefaultTrue)
	r.register("config_layers", CategoryOptional, "Hierarchical configuration resolution (env>project>machine>user)", nil, DefaultTrue)
	r.register("cli_feature_filter", CategoryOptional, "Filter CLI help and commands based on enabled features", nil, DefaultTrue)
	r.register("hooks", CategoryOptional, "Lifecycle hooks for custom behavior at key events", nil, DefaultTrue)
	r.register("encryption", CategoryOptional, "Age encryption for sensitive files (templates, secrets)", nil, DefaultFalse)

	// ============================================================
	// Integration features (third-party tool integrations)
	// ============================================================
	r.register("modern_cli", CategoryIntegration, "Modern CLI tools (eza, bat, ripgrep, fzf, zoxide)", nil, DefaultTrue)
	r.register("aws_helpers", CategoryIntegration, "AWS SSO profile management and helpers", nil, DefaultTrue)
	r.register("cdk_tools", CategoryIntegration, "AWS CDK aliases, helpers, and environment management", []string{"aws_helpers"}, DefaultTrue)
	r.register("rust_tools", CategoryIntegration, "Rust/Cargo aliases and helpers", nil, DefaultTrue)
	r.register("go_tools", CategoryIntegration, "Go aliases and helpers", nil, DefaultTrue)
	r.register("python_tools", CategoryIntegration, "Python/uv aliases, auto-venv, pytest helpers", nil, DefaultTrue)
	r.register("ssh_tools", CategoryIntegration, "SSH config, key management, agent, and tunnel helpers", nil, DefaultTrue)
	r.register("docker_tools", CategoryIntegration, "Docker container, compose, and network management", nil, DefaultTrue)
	r.register("nvm_integration", CategoryIntegration, "Lazy-loaded NVM for Node.js version management", nil, DefaultTrue)
	r.register("sdkman_integration", CategoryIntegration, "Lazy-loaded SDKMAN for Java/Gradle/Kotlin", nil, DefaultTrue)
	r.register("dotclaude", CategoryIntegration, "dotclaude profile management for Claude Code", []string{"claude_integration"}, DefaultFalse)

	// Environment variable mappings for backward compatibility
	// Maps SKIP_* vars to feature names (inverted logic: SKIP_X=true means feature=false)
	r.envMap["SKIP_WORKSPACE_SYMLINK"] = "workspace_symlink"
	r.envMap["SKIP_CLAUDE_SETUP"] = "claude_integration"
	r.envMap["BLACKDOT_SKIP_DRIFT_CHECK"] = "drift_check"

	// Initialize enabled state based on defaults
	r.initDefaults()

	return r
}

// register adds a feature to the registry
func (r *Registry) register(name string, cat Category, desc string, deps []string, defaultVal DefaultValue) {
	r.features[name] = &Feature{
		Name:         name,
		Description:  desc,
		Category:     cat,
		Dependencies: deps,
		Default:      defaultVal,
	}
}

// initDefaults sets initial enabled state based on feature defaults
func (r *Registry) initDefaults() {
	for name, f := range r.features {
		if f.Category == CategoryCore || f.Default == DefaultTrue {
			r.enabled[name] = true
		}
	}
}

// Get returns a feature by name
func (r *Registry) Get(name string) (*Feature, bool) {
	f, ok := r.features[name]
	return f, ok
}

// Exists checks if a feature exists in the registry
func (r *Registry) Exists(name string) bool {
	_, ok := r.features[name]
	return ok
}

// All returns all features
func (r *Registry) All() []*Feature {
	result := make([]*Feature, 0, len(r.features))
	for _, f := range r.features {
		result = append(result, f)
	}
	sort.Slice(result, func(i, j int) bool {
		return result[i].Name < result[j].Name
	})
	return result
}

// ByCategory returns features in a specific category
func (r *Registry) ByCategory(cat Category) []*Feature {
	var result []*Feature
	for _, f := range r.features {
		if f.Category == cat {
			result = append(result, f)
		}
	}
	sort.Slice(result, func(i, j int) bool {
		return result[i].Name < result[j].Name
	})
	return result
}

// Enabled checks if a feature is enabled
// Resolution order: runtime state -> env vars -> config file -> registry default
func (r *Registry) Enabled(name string) bool {
	f, ok := r.features[name]
	if !ok {
		return false
	}

	// Core features are always enabled
	if f.Category == CategoryCore {
		return true
	}

	// Check runtime state first (highest priority after core)
	if enabled, hasState := r.enabled[name]; hasState {
		return enabled
	}

	// Check environment variable overrides
	if envVal := r.checkEnvOverride(name); envVal != "" {
		return envVal == "true"
	}

	// Fall back to default
	switch f.Default {
	case DefaultTrue:
		return true
	case DefaultEnv:
		// "env" default means disabled unless env var says otherwise
		return false
	default:
		return false
	}
}

// checkEnvOverride checks for environment variable overrides
// Returns "true", "false", or "" (not set)
func (r *Registry) checkEnvOverride(name string) string {
	// Check direct BLACKDOT_FEATURE_<NAME> env var first
	directVar := "BLACKDOT_FEATURE_" + strings.ToUpper(strings.ReplaceAll(name, "_", "_"))
	if val := os.Getenv(directVar); val != "" {
		if val == "true" || val == "1" {
			return "true"
		}
		return "false"
	}

	// Check SKIP_* backward compatibility vars (inverted logic)
	for envVar, featureName := range r.envMap {
		if featureName == name {
			if val := os.Getenv(envVar); val != "" {
				// SKIP_* vars are inverted: SKIP_X=true means feature=false
				if val == "true" || val == "1" {
					return "false"
				}
				return "true"
			}
		}
	}

	return ""
}

// Enable enables a feature and its dependencies
func (r *Registry) Enable(name string) error {
	f, ok := r.features[name]
	if !ok {
		return fmt.Errorf("unknown feature: %s", name)
	}

	// Check for circular dependencies
	if err := r.detectCircularDep(name, nil); err != nil {
		return err
	}

	// Check for conflicts
	if err := r.checkConflicts(name); err != nil {
		return err
	}

	// Enable dependencies first
	for _, dep := range f.Dependencies {
		if !r.Enabled(dep) {
			if err := r.Enable(dep); err != nil {
				return fmt.Errorf("failed to enable dependency %s: %w", dep, err)
			}
		}
	}

	r.enabled[name] = true
	return nil
}

// Disable disables a feature (if not core)
func (r *Registry) Disable(name string) error {
	f, ok := r.features[name]
	if !ok {
		return fmt.Errorf("unknown feature: %s", name)
	}

	if f.Category == CategoryCore {
		return fmt.Errorf("cannot disable core feature: %s", name)
	}

	r.enabled[name] = false
	return nil
}

// detectCircularDep checks for circular dependencies
func (r *Registry) detectCircularDep(name string, visited []string) error {
	// Check if already in visit path = cycle
	for _, v := range visited {
		if v == name {
			return fmt.Errorf("circular dependency detected: %s -> %s", strings.Join(visited, " -> "), name)
		}
	}

	f, ok := r.features[name]
	if !ok {
		return nil
	}

	visited = append(visited, name)
	for _, dep := range f.Dependencies {
		if err := r.detectCircularDep(dep, visited); err != nil {
			return err
		}
	}

	return nil
}

// checkConflicts checks if enabling a feature would create a conflict
func (r *Registry) checkConflicts(name string) error {
	conflicts, ok := r.conflicts[name]
	if !ok {
		return nil
	}

	for _, conflict := range conflicts {
		if r.Enabled(conflict) {
			return fmt.Errorf("cannot enable '%s': conflicts with enabled feature '%s'", name, conflict)
		}
	}

	return nil
}

// Dependencies returns the dependencies of a feature
func (r *Registry) Dependencies(name string) []string {
	if f, ok := r.features[name]; ok {
		return f.Dependencies
	}
	return nil
}

// Dependents returns features that depend on the given feature
func (r *Registry) Dependents(name string) []string {
	var result []string
	for _, f := range r.features {
		for _, dep := range f.Dependencies {
			if dep == name {
				result = append(result, f.Name)
				break
			}
		}
	}
	return result
}

// MissingDeps returns missing dependencies for a feature
func (r *Registry) MissingDeps(name string) []string {
	f, ok := r.features[name]
	if !ok {
		return nil
	}

	var missing []string
	for _, dep := range f.Dependencies {
		if !r.Enabled(dep) {
			missing = append(missing, dep)
		}
	}
	return missing
}

// Validate checks all features for circular dependencies and conflicts
func (r *Registry) Validate() error {
	for name := range r.features {
		if err := r.detectCircularDep(name, nil); err != nil {
			return err
		}
	}

	// Check for conflict violations
	for name := range r.features {
		if r.Enabled(name) {
			if conflicts, ok := r.conflicts[name]; ok {
				for _, conflict := range conflicts {
					if r.Enabled(conflict) {
						return fmt.Errorf("conflict: '%s' and '%s' are both enabled but mutually exclusive", name, conflict)
					}
				}
			}
		}
	}

	return nil
}

// LoadState loads enabled state from a map (e.g., from config file)
func (r *Registry) LoadState(state map[string]bool) {
	for name, enabled := range state {
		if _, ok := r.features[name]; ok {
			r.enabled[name] = enabled
		}
	}
}

// SaveState returns the current enabled state as a map
// Only returns non-core features that differ from defaults
func (r *Registry) SaveState() map[string]bool {
	result := make(map[string]bool)
	for name, f := range r.features {
		if f.Category == CategoryCore {
			continue // Don't save core features
		}
		enabled := r.enabled[name]
		// Only save if different from default
		defaultEnabled := f.Default == DefaultTrue
		if enabled != defaultEnabled {
			result[name] = enabled
		}
	}
	return result
}

// List returns feature names, optionally filtered by category
func (r *Registry) List(category string) []string {
	var result []string
	for name, f := range r.features {
		if category == "" || string(f.Category) == category {
			result = append(result, name)
		}
	}
	sort.Strings(result)
	return result
}
