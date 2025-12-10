package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/blackwell-systems/blackdot/internal/config"
	"github.com/blackwell-systems/blackdot/internal/feature"
	"github.com/spf13/cobra"
)

// Shared registry instance
var registry *feature.Registry

// initRegistry initializes the feature registry and loads config state
func initRegistry() *feature.Registry {
	if registry != nil {
		return registry
	}

	registry = feature.NewRegistry()

	// Load persisted state from config file
	cfg := config.DefaultManager()
	userConfig, err := cfg.Load()
	if err == nil && userConfig.Features != nil {
		registry.LoadState(userConfig.Features)
	}

	return registry
}

func newFeaturesCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "features",
		Aliases: []string{"feature", "feat"},
		Short:   "Manage dotfiles features",
		Long: `Manage dotfiles features - enable, disable, and query feature status.

Features control which functionality is available in your dotfiles setup.
They can have dependencies on other features and are organized into
categories: core, optional, and integration.`,
		Run: func(cmd *cobra.Command, args []string) {
			// Default: list all features
			listFeaturesCmd(cmd, args, "", false, false)
		},
	}

	// Override help to use styled version
	cmd.SetHelpFunc(func(cmd *cobra.Command, args []string) {
		printFeaturesHelp()
	})

	// Subcommands
	cmd.AddCommand(
		newFeaturesListCmd(),
		newFeaturesEnableCmd(),
		newFeaturesDisableCmd(),
		newFeaturesPresetCmd(),
		newFeaturesCheckCmd(),
		newFeaturesShowCmd(),
		newFeaturesValidateCmd(),
	)

	return cmd
}

// printFeaturesHelp prints styled help matching ZSH features help
func printFeaturesHelp() {
	// Title
	BoldCyan.Print("dotfiles features")
	fmt.Print(" - ")
	Dim.Println("Feature registry management")
	fmt.Println()

	// Usage
	Bold.Print("Usage:")
	fmt.Println(" dotfiles features <command> [options]")
	fmt.Println()

	// Commands section
	BoldCyan.Println("Commands:")
	printFeaturesCmd("list [category]", "List all features and their status")
	Dim.Println("                      Categories: core, optional, integration")
	Dim.Println("                      --all: Show dependencies")
	Dim.Println("                      --json: Output as JSON")
	fmt.Println()
	printFeaturesCmd("status [feature]", "Show feature status (all or specific)")
	fmt.Println()
	printFeaturesCmd("enable <feature>", "Enable a feature")
	Dim.Println("                      --persist: Save to config file")
	fmt.Println()
	printFeaturesCmd("disable <feature>", "Disable a feature")
	Dim.Println("                      --persist: Save to config file")
	fmt.Println()
	printFeaturesCmd("preset <name>", "Enable a preset (group of features)")
	Dim.Println("                      --list: Show available presets")
	Dim.Println("                      --persist: Save to config file")
	fmt.Println()
	printFeaturesCmd("check <feature>", "Check if a feature is enabled (for scripts)")
	Dim.Println("                      Returns exit code 0 if enabled, 1 if disabled")
	fmt.Println()
	printFeaturesCmd("validate", "Validate feature registry for circular dependencies")
	Dim.Println("                      and conflicts. Returns exit code 0 if valid.")
	fmt.Println()
	printFeaturesCmd("help", "Show this help")
	fmt.Println()

	// Presets section
	BoldCyan.Println("Available Presets:")
	fmt.Print("  ")
	Yellow.Print("minimal")
	fmt.Print("     ")
	Dim.Println("Shell only (fastest startup)")
	fmt.Print("  ")
	Yellow.Print("developer")
	fmt.Print("   ")
	Dim.Println("vault, aws_helpers, git_hooks, modern_cli")
	fmt.Print("  ")
	Yellow.Print("claude")
	fmt.Print("      ")
	Dim.Println("workspace_symlink, claude_integration, vault, git_hooks")
	fmt.Print("  ")
	Yellow.Print("full")
	fmt.Print("        ")
	Dim.Println("All features enabled")
	fmt.Println()

	// Examples section
	BoldCyan.Println("Examples:")
	fmt.Print("  ")
	Yellow.Print("dotfiles features")
	fmt.Print("                      ")
	Dim.Println("# List all features")
	fmt.Print("  ")
	Yellow.Print("dotfiles features list optional")
	fmt.Print("        ")
	Dim.Println("# List optional features only")
	fmt.Print("  ")
	Yellow.Print("dotfiles features enable vault")
	fmt.Print("         ")
	Dim.Println("# Enable vault (runtime)")
	fmt.Print("  ")
	Yellow.Print("dotfiles features enable vault -p")
	fmt.Print("      ")
	Dim.Println("# Enable and persist")
	fmt.Print("  ")
	Yellow.Print("dotfiles features preset developer")
	fmt.Print("     ")
	Dim.Println("# Enable developer preset")
	fmt.Print("  ")
	Yellow.Print("dotfiles features check vault && ...")
	fmt.Print("  ")
	Dim.Println("# Conditional execution")
	fmt.Println()

	// Environment Variables section
	BoldCyan.Println("Environment Variables:")
	Dim.Println("  Features can also be controlled via environment variables:")
	fmt.Print("    ")
	Yellow.Print("SKIP_WORKSPACE_SYMLINK=true")
	fmt.Print("    ")
	Dim.Println("Disable workspace_symlink")
	fmt.Print("    ")
	Yellow.Print("SKIP_CLAUDE_SETUP=true")
	fmt.Print("         ")
	Dim.Println("Disable claude_integration")
	fmt.Print("    ")
	Yellow.Print("DOTFILES_SKIP_DRIFT_CHECK=1")
	fmt.Print("    ")
	Dim.Println("Disable drift_check")
	fmt.Print("    ")
	Yellow.Print("DOTFILES_FEATURE_<NAME>=true")
	fmt.Print("   ")
	Dim.Println("Enable/disable any feature")
	fmt.Println()
}

// printFeaturesCmd prints a features subcommand with description
func printFeaturesCmd(name, desc string) {
	fmt.Print("  ")
	Yellow.Printf("%-20s", name)
	fmt.Print(" ")
	Dim.Println(desc)
}

func newFeaturesListCmd() *cobra.Command {
	var jsonOutput bool
	var showAll bool

	cmd := &cobra.Command{
		Use:   "list [category]",
		Short: "List all features",
		Long: `List all features with their status, category, and dependencies.

Categories: core, optional, integration`,
		Run: func(cmd *cobra.Command, args []string) {
			category := ""
			if len(args) > 0 {
				category = args[0]
			}
			listFeaturesCmd(cmd, args, category, jsonOutput, showAll)
		},
	}

	cmd.Flags().BoolVarP(&showAll, "all", "a", false, "show dependencies")
	cmd.Flags().BoolVarP(&jsonOutput, "json", "j", false, "output as JSON")

	return cmd
}

func newFeaturesEnableCmd() *cobra.Command {
	var persist bool

	cmd := &cobra.Command{
		Use:   "enable <feature>",
		Short: "Enable a feature",
		Long: `Enable a feature and its dependencies.

If the feature has dependencies, they will be enabled automatically.
Use --persist to save to config file.`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return enableFeature(args[0], persist)
		},
	}

	cmd.Flags().BoolVarP(&persist, "persist", "p", false, "save to config file")

	return cmd
}

func newFeaturesDisableCmd() *cobra.Command {
	var persist bool

	cmd := &cobra.Command{
		Use:   "disable <feature>",
		Short: "Disable a feature",
		Long: `Disable a feature.

Core features cannot be disabled. Use --persist to save to config file.`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return disableFeature(args[0], persist)
		},
	}

	cmd.Flags().BoolVarP(&persist, "persist", "p", false, "save to config file")

	return cmd
}

func newFeaturesPresetCmd() *cobra.Command {
	var listPresets bool
	var persist bool

	cmd := &cobra.Command{
		Use:   "preset [name]",
		Short: "Apply a feature preset",
		Long: `Apply a preset to enable/disable multiple features at once.

Available presets:
  minimal   - Shell only (fastest startup)
  developer - Vault, AWS helpers, git hooks, modern CLI
  claude    - Workspace symlink, Claude integration, vault, git hooks
  full      - All features enabled`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if listPresets || len(args) == 0 {
				listPresetsCmd()
				return nil
			}
			return applyPreset(args[0], persist)
		},
	}

	cmd.Flags().BoolVarP(&listPresets, "list", "l", false, "list available presets")
	cmd.Flags().BoolVarP(&persist, "persist", "p", false, "save to config file")

	return cmd
}

func newFeaturesCheckCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "check <feature>",
		Short: "Check if a feature is enabled",
		Long:  `Check if a feature is enabled. Returns exit code 0 if enabled, 1 if disabled.`,
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return checkFeature(args[0])
		},
	}
}

func newFeaturesShowCmd() *cobra.Command {
	return &cobra.Command{
		Use:     "show <feature>",
		Aliases: []string{"status"},
		Short:   "Show detailed feature information",
		Long:    `Show detailed information about a feature including dependencies and dependents.`,
		Args:    cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return showFeature(args[0])
		},
	}
}

func newFeaturesValidateCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "validate",
		Short: "Validate feature registry for circular dependencies",
		Long:  `Validate feature registry for circular dependencies and conflicts. Returns exit code 0 if valid.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return validateFeatures()
		},
	}
}

// ============================================================
// Implementation Functions
// ============================================================

func listFeaturesCmd(cmd *cobra.Command, args []string, filterCategory string, jsonOutput, showAll bool) {
	reg := initRegistry()

	if jsonOutput {
		listFeaturesJSON(reg)
		return
	}

	PrintHeader("Feature Registry")

	categories := []struct {
		cat   feature.Category
		label string
	}{
		{feature.CategoryCore, "Core (Always Enabled)"},
		{feature.CategoryOptional, "Optional Features"},
		{feature.CategoryIntegration, "Integrations"},
	}

	for _, c := range categories {
		// Skip if filtering by category
		if filterCategory != "" && filterCategory != string(c.cat) {
			continue
		}

		PrintSubheader(c.label)

		features := reg.ByCategory(c.cat)
		for _, f := range features {
			enabled := reg.Enabled(f.Name)
			PrintFeature(f.Name, f.Description, enabled)

			if showAll && len(f.Dependencies) > 0 {
				PrintDeps(strings.Join(f.Dependencies, ", "))
			}
		}
		fmt.Println()
	}

	PrintLegend()
	PrintHint("Use 'blackdot features enable <name>' to enable a feature")
}

func listFeaturesJSON(reg *feature.Registry) {
	output := make(map[string]interface{})

	for _, f := range reg.All() {
		output[f.Name] = map[string]interface{}{
			"enabled":      reg.Enabled(f.Name),
			"category":     string(f.Category),
			"description":  f.Description,
			"dependencies": f.Dependencies,
		}
	}

	data, _ := json.MarshalIndent(output, "", "  ")
	fmt.Println(string(data))
}

func enableFeature(name string, persist bool) error {
	reg := initRegistry()

	if !reg.Exists(name) {
		Fail("Unknown feature: %s", name)
		fmt.Println()
		fmt.Println("Available features:")
		for _, n := range reg.List("") {
			fmt.Printf("  %s\n", n)
		}
		return fmt.Errorf("unknown feature: %s", name)
	}

	// Check if core feature
	f, _ := reg.Get(name)
	if f.Category == feature.CategoryCore {
		Info("Feature '%s' is a core feature (always enabled)", name)
		return nil
	}

	// Get dependencies that will be enabled
	deps := reg.Dependencies(name)
	var depsToEnable []string
	for _, dep := range deps {
		if !reg.Enabled(dep) {
			depsToEnable = append(depsToEnable, dep)
		}
	}

	if len(depsToEnable) > 0 {
		Info("Enabling dependencies first: %s", strings.Join(depsToEnable, ", "))
	}

	// Enable the feature
	if err := reg.Enable(name); err != nil {
		Fail("Failed to enable feature: %v", err)
		return err
	}

	if persist {
		if err := persistFeatureState(reg); err != nil {
			Fail("Failed to save config: %v", err)
			return err
		}
		Pass("Feature '%s' enabled and saved to config", name)
		printShellReloadHint()
	} else {
		Pass("Feature '%s' enabled (runtime only)", name)
		PrintHint("Use --persist to save to config file")
	}

	return nil
}

func disableFeature(name string, persist bool) error {
	reg := initRegistry()

	if !reg.Exists(name) {
		Fail("Unknown feature: %s", name)
		return fmt.Errorf("unknown feature: %s", name)
	}

	// Check if core feature
	f, _ := reg.Get(name)
	if f.Category == feature.CategoryCore {
		Fail("Cannot disable core feature: %s", name)
		return fmt.Errorf("cannot disable core feature: %s", name)
	}

	// Disable the feature
	if err := reg.Disable(name); err != nil {
		Fail("Failed to disable feature: %v", err)
		return err
	}

	if persist {
		if err := persistFeatureState(reg); err != nil {
			Fail("Failed to save config: %v", err)
			return err
		}
		Pass("Feature '%s' disabled and saved to config", name)
		printShellReloadHint()
	} else {
		Pass("Feature '%s' disabled (runtime only)", name)
		PrintHint("Use --persist to save to config file")
	}

	return nil
}

func listPresetsCmd() {
	PrintHeader("Available Presets")

	for _, preset := range feature.AllPresets() {
		BoldCyan.Printf("  %s\n", preset.Name)
		PrintHint("    %s", preset.Description)
		Dim.Printf("    Features: %s\n", strings.Join(preset.Features, ", "))
		fmt.Println()
	}
}

func applyPreset(name string, persist bool) error {
	reg := initRegistry()

	preset, ok := feature.GetPreset(name)
	if !ok {
		Fail("Unknown preset: %s", name)
		fmt.Println()
		fmt.Println("Available presets:")
		for _, n := range feature.PresetNames() {
			fmt.Printf("  %s\n", n)
		}
		return fmt.Errorf("unknown preset: %s", name)
	}

	if err := reg.ApplyPreset(name); err != nil {
		Fail("Failed to apply preset: %v", err)
		return err
	}

	if persist {
		if err := persistFeatureState(reg); err != nil {
			Fail("Failed to save config: %v", err)
			return err
		}
		Pass("Preset '%s' enabled and saved to config", name)
	} else {
		Pass("Preset '%s' enabled (runtime only)", name)
		PrintHint("Use --persist to save to config file")
	}

	fmt.Println()
	fmt.Println("Enabled features:")
	for _, fname := range preset.Features {
		Green.Printf("  ● %s\n", fname)
	}

	if persist {
		printShellReloadHint()
	}

	return nil
}

func checkFeature(name string) error {
	reg := initRegistry()

	if !reg.Exists(name) {
		Fail("Unknown feature: %s", name)
		return fmt.Errorf("unknown feature: %s", name)
	}

	if reg.Enabled(name) {
		Pass("Feature '%s' is enabled", name)
		return nil
	}

	Info("Feature '%s' is disabled", name)
	os.Exit(1)
	return nil
}

func showFeature(name string) error {
	reg := initRegistry()

	f, ok := reg.Get(name)
	if !ok {
		Fail("Unknown feature: %s", name)
		fmt.Println()
		fmt.Println("Available features:")
		for _, n := range reg.List("") {
			fmt.Printf("  %s\n", n)
		}
		return fmt.Errorf("unknown feature: %s", name)
	}

	enabled := reg.Enabled(name)

	// JSON-like output matching Zsh feature_status()
	fmt.Println("{")
	fmt.Printf("  \"name\": \"%s\",\n", f.Name)
	fmt.Printf("  \"enabled\": %t,\n", enabled)
	fmt.Printf("  \"default\": \"%s\",\n", f.Default)
	fmt.Printf("  \"description\": \"%s\",\n", f.Description)
	fmt.Printf("  \"category\": \"%s\",\n", f.Category)

	depsStr := "none"
	if len(f.Dependencies) > 0 {
		depsStr = strings.Join(f.Dependencies, ", ")
	}
	fmt.Printf("  \"dependencies\": \"%s\"\n", depsStr)
	fmt.Println("}")

	return nil
}

func validateFeatures() error {
	PrintHeader("Feature Registry Validation")

	reg := initRegistry()

	if err := reg.Validate(); err != nil {
		Fail("Validation failed: %v", err)
		return err
	}

	Pass("All feature dependencies are valid")
	fmt.Println()
	Green.Println("✓ Registry is valid - no circular dependencies or conflicts")

	return nil
}

// persistFeatureState saves the current feature state to config
func persistFeatureState(reg *feature.Registry) error {
	cfg := config.DefaultManager()

	userConfig, err := cfg.Load()
	if err != nil {
		// Create new config if doesn't exist
		userConfig = &config.Config{Version: 3}
	}

	userConfig.Features = reg.SaveState()

	return cfg.Save(userConfig)
}

// printShellReloadHint prints a hint to reload the shell after feature changes
// The shell wrapper (zsh) does this automatically, but if using Go CLI directly
// the user needs to know to reload for changes to take effect.
func printShellReloadHint() {
	fmt.Println()
	Yellow.Println("Reload your shell to apply changes:")

	// Detect platform and show appropriate reload command
	if isWindows() {
		fmt.Println("  Import-Module Dotfiles -Force")
		Dim.Println("  (or restart PowerShell)")
	} else {
		fmt.Println("  source ~/.zshrc")
		Dim.Println("  (or exec zsh for full reload)")
	}
}

// isWindows returns true if running on Windows
func isWindows() bool {
	return os.PathSeparator == '\\' && os.PathListSeparator == ';'
}
