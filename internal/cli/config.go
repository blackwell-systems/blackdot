package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/blackwell-systems/blackdot/v4/internal/config"
	"github.com/spf13/cobra"
)

// configPaths returns the resolved user and machine config paths.
// Environment variables are read at call time (lazy evaluation).
func configPaths() (userPath, machinePath string) {
	mgr := config.DefaultManager()
	return mgr.UserConfigPath(), mgr.MachineConfigPath()
}

func newConfigCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "config",
		Aliases: []string{"cfg"},
		Short:   "Manage configuration",
		Long:    `Manage blackdot configuration`,
		Run: func(cmd *cobra.Command, args []string) {
			printConfigHelp()
		},
	}

	// Override help to use styled version
	cmd.SetHelpFunc(func(cmd *cobra.Command, args []string) {
		printConfigHelp()
	})

	cmd.AddCommand(
		newConfigGetCmd(),
		newConfigSetCmd(),
		newConfigShowCmd(),
		newConfigSourceCmd(),
		newConfigListCmd(),
		newConfigMergedCmd(),
		newConfigInitCmd(),
		newConfigEditCmd(),
	)

	return cmd
}

// printConfigHelp prints styled help matching ZSH style
func printConfigHelp() {
	// Title
	fmt.Print("⚫ ")
	BoldCyan.Print("blackdot config")
	fmt.Print(" - Manage configuration with layered resolution\n")
	fmt.Println()

	// Usage
	Bold.Print("Usage:")
	fmt.Print(" blackdot config <command> [options]\n")
	fmt.Println()

	// Commands
	BoldCyan.Println("Commands:")
	printCmd("get <key>", "Get config value with layer resolution")
	printCmd("set <layer> <k> <v>", "Set config value in specific layer")
	printCmd("show <key>", "Show where a config value comes from")
	printCmd("source <key>", "Get value with source information (JSON)")
	printCmd("list", "Show configuration layer status")
	printCmd("merged", "Show merged config from all layers")
	printCmd("init <layer>", "Initialize machine or project config")
	printCmd("edit [layer]", "Edit config in $EDITOR")
	fmt.Println()

	// Layers
	BoldCyan.Println("Layers (highest to lowest priority):")
	fmt.Print("  ")
	Yellow.Print("1. env")
	fmt.Print("       ")
	Dim.Println("Environment variables (BLACKDOT_*)")
	fmt.Print("  ")
	Yellow.Print("2. project")
	fmt.Print("   ")
	Dim.Println(".blackdot.json in current repo")
	fmt.Print("  ")
	Yellow.Print("3. machine")
	fmt.Print("   ")
	Dim.Println("~/.config/blackdot/machine.json")
	fmt.Print("  ")
	Yellow.Print("4. user")
	fmt.Print("      ")
	Dim.Println("~/.config/blackdot/config.json")
	fmt.Print("  ")
	Yellow.Print("5. default")
	fmt.Print("   ")
	Dim.Println("Built-in defaults")
	fmt.Println()

	// Examples
	BoldCyan.Println("Examples:")
	Dim.Println("  # Get a config value")
	fmt.Println("  blackdot config get vault.backend")
	fmt.Println()
	Dim.Println("  # Set a value in specific layer")
	fmt.Println("  blackdot config set user vault.backend 1password")
	fmt.Println()
	Dim.Println("  # Show where a value comes from")
	fmt.Println("  blackdot config show vault.backend")
	fmt.Println()
	Dim.Println("  # View all layers")
	fmt.Println("  blackdot config list")
	fmt.Println()
	Dim.Println("  # Initialize machine config")
	fmt.Println("  blackdot config init machine work-mac")
	fmt.Println()
}

func newConfigGetCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "get <key> [default]",
		Short: "Get config value with layer resolution",
		Args:  cobra.RangeArgs(1, 2),
		RunE: func(cmd *cobra.Command, args []string) error {
			key := args[0]
			defaultVal := ""
			if len(args) > 1 {
				defaultVal = args[1]
			}
			return configGet(key, defaultVal)
		},
	}
}

func newConfigSetCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "set <layer> <key> <value>",
		Short: "Set config value in specific layer",
		Long: `Set config value in specific layer.

Layers: user, machine, project

Examples:
  blackdot config set user vault.backend 1password
  blackdot config set machine features.debug true
  blackdot config set project shell.theme minimal`,
		Args: cobra.ExactArgs(3),
		RunE: func(cmd *cobra.Command, args []string) error {
			return configSet(args[0], args[1], args[2])
		},
	}
}

func newConfigShowCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "show <key>",
		Short: "Show value from all layers",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return configShow(args[0])
		},
	}
}

func newConfigSourceCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "source <key> [default]",
		Short: "Get value with source information (JSON)",
		Long: `Returns JSON with value and its source layer.

Example output:
  {"value": "bitwarden", "layer": "user", "path": "~/.config/blackdot/config.json"}`,
		Args: cobra.RangeArgs(1, 2),
		RunE: func(cmd *cobra.Command, args []string) error {
			key := args[0]
			defaultVal := ""
			if len(args) > 1 {
				defaultVal = args[1]
			}
			return configSource(key, defaultVal)
		},
	}
}

func newConfigListCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "Show configuration layer status",
		RunE: func(cmd *cobra.Command, args []string) error {
			return configList()
		},
	}
}

func newConfigMergedCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "merged",
		Short: "Show merged config from all layers",
		RunE: func(cmd *cobra.Command, args []string) error {
			return configMerged()
		},
	}
}

func newConfigInitCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "init <layer> [identifier]",
		Short: "Initialize a config layer",
		Long: `Initialize a configuration layer.

Layers: machine, project

Examples:
  blackdot config init machine work-macbook
  blackdot config init project`,
		Args: cobra.RangeArgs(1, 2),
		RunE: func(cmd *cobra.Command, args []string) error {
			layer := args[0]
			identifier := ""
			if len(args) > 1 {
				identifier = args[1]
			}
			return configInit(layer, identifier)
		},
	}
}

func newConfigEditCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "edit [layer]",
		Short: "Edit config file (default: user)",
		Long: `Open config file in editor.

Layers: user (default), machine, project`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			layer := "user"
			if len(args) > 0 {
				layer = args[0]
			}
			return configEdit(layer)
		},
	}
}

// ============================================================
// Implementation Functions
// ============================================================

func configGet(key, defaultVal string) error {
	result, err := config.DefaultManager().GetLayered(key)
	if err != nil {
		return fmt.Errorf("config get %s: %w", key, err)
	}
	if result.Value != "" {
		fmt.Println(result.Value)
		return nil
	}
	if defaultVal != "" {
		fmt.Println(defaultVal)
	}
	return nil
}

func configSet(layer, key, value string) error {
	userPath, machinePath := configPaths()
	var configFile string

	switch layer {
	case "user":
		configFile = userPath
	case "machine":
		configFile = machinePath
	case "project":
		configFile = findProjectConfig()
		if configFile == "" {
			Fail("No project config found")
			fmt.Println("Create one with: blackdot config init project")
			return fmt.Errorf("no project config")
		}
	default:
		Fail("Unknown layer: %s", layer)
		fmt.Println("Valid layers: user, machine, project")
		return fmt.Errorf("unknown layer: %s", layer)
	}

	if err := setInJSONFile(configFile, key, value); err != nil {
		Fail("Failed to set config: %v", err)
		return err
	}

	Pass("Set %s = %s in %s config", key, value, layer)
	return nil
}

func configShow(key string) error {
	PrintHeader("Config: " + key)
	mgr := config.DefaultManager()

	layers := []struct {
		label string
		fetch func() string
	}{
		{"env", func() string {
			envKey := "BLACKDOT_" + strings.ToUpper(strings.ReplaceAll(key, ".", "_"))
			return os.Getenv(envKey)
		}},
		{"project", func() string {
			if path := mgr.ProjectConfigPath(); path != "" {
				return getFromJSONFile(path, key)
			}
			return ""
		}},
		{"machine", func() string {
			return getFromJSONFile(mgr.MachineConfigPath(), key)
		}},
		{"user", func() string {
			return getFromJSONFile(mgr.UserConfigPath(), key)
		}},
	}

	active := false
	for _, l := range layers {
		val := l.fetch()
		if val != "" {
			if !active {
				fmt.Printf("  %-9s %s  %s\n", l.label+":", val, Green.Sprint("<- active"))
				active = true
			} else {
				fmt.Printf("  %-9s %s\n", l.label+":", val)
			}
		} else {
			fmt.Printf("  %-9s %s\n", l.label+":", Dim.Sprint("(not set)"))
		}
	}
	return nil
}

func configSource(key, defaultVal string) error {
	userPath, machinePath := configPaths()

	type sourceResult struct {
		Value string `json:"value"`
		Layer string `json:"layer"`
		Path  string `json:"path,omitempty"`
	}

	var result sourceResult

	// Check environment first
	envKey := "BLACKDOT_" + strings.ToUpper(strings.ReplaceAll(key, ".", "_"))
	if val := os.Getenv(envKey); val != "" {
		result = sourceResult{Value: val, Layer: "env"}
		data, _ := json.Marshal(result)
		fmt.Println(string(data))
		return nil
	}

	// Check project config
	if projectConfig := findProjectConfig(); projectConfig != "" {
		if val := getFromJSONFile(projectConfig, key); val != "" {
			result = sourceResult{Value: val, Layer: "project", Path: projectConfig}
			data, _ := json.Marshal(result)
			fmt.Println(string(data))
			return nil
		}
	}

	// Check machine config
	if val := getFromJSONFile(machinePath, key); val != "" {
		result = sourceResult{Value: val, Layer: "machine", Path: machinePath}
		data, _ := json.Marshal(result)
		fmt.Println(string(data))
		return nil
	}

	// Check user config
	if val := getFromJSONFile(userPath, key); val != "" {
		result = sourceResult{Value: val, Layer: "user", Path: userPath}
		data, _ := json.Marshal(result)
		fmt.Println(string(data))
		return nil
	}

	// Return default
	if defaultVal != "" {
		result = sourceResult{Value: defaultVal, Layer: "default"}
	} else {
		result = sourceResult{Value: "", Layer: "none"}
	}
	data, _ := json.Marshal(result)
	fmt.Println(string(data))
	return nil
}

func configList() error {
	userPath, machinePath := configPaths()

	PrintHeader("Configuration Layers")
	fmt.Println()
	fmt.Println("Layer Locations:")
	fmt.Println("───────────────────────────────────────────────────────────────")

	// Environment
	fmt.Printf("  env:       %s\n", Dim.Sprint("BLACKDOT_* environment variables"))

	// Project
	projectConfig := findProjectConfig()
	if projectConfig != "" {
		fmt.Printf("  project:   %s %s\n", projectConfig, Green.Sprint("✓"))
	} else {
		fmt.Printf("  project:   %s\n", Dim.Sprint(".blackdot.json (not found)"))
	}

	// Machine
	if _, err := os.Stat(machinePath); err == nil {
		fmt.Printf("  machine:   %s %s\n", machinePath, Green.Sprint("✓"))
	} else {
		fmt.Printf("  machine:   %s\n", Dim.Sprint(machinePath+" (not found)"))
	}

	// User
	if _, err := os.Stat(userPath); err == nil {
		fmt.Printf("  user:      %s %s\n", userPath, Green.Sprint("✓"))
	} else {
		fmt.Printf("  user:      %s\n", Dim.Sprint(userPath+" (not found)"))
	}

	fmt.Println()
	fmt.Println("Priority: env > project > machine > user > default")
	fmt.Println()

	return nil
}

func configMerged() error {
	userPath, machinePath := configPaths()

	PrintHeader("Merged Configuration")

	merged := make(map[string]interface{})

	// Load user config (lowest priority)
	loadJSONInto(userPath, merged)

	// Load machine config
	loadJSONInto(machinePath, merged)

	// Load project config
	if projectConfig := findProjectConfig(); projectConfig != "" {
		loadJSONInto(projectConfig, merged)
	}

	// Note: environment variables would override but we can't enumerate them easily

	if len(merged) == 0 {
		Info("No configuration found")
		return nil
	}

	data, _ := json.MarshalIndent(merged, "", "  ")
	fmt.Println(string(data))
	return nil
}

func configInit(layer, identifier string) error {
	switch layer {
	case "machine":
		return configInitMachine(identifier)
	case "project":
		return configInitProject()
	default:
		Fail("Unknown layer: %s", layer)
		fmt.Println("Valid layers: machine, project")
		return fmt.Errorf("unknown layer: %s", layer)
	}
}

func configInitMachine(identifier string) error {
	_, machinePath := configPaths()

	if identifier == "" {
		hostname, _ := os.Hostname()
		identifier = hostname
	}

	// Check if already exists
	if _, err := os.Stat(machinePath); err == nil {
		Warn("Machine config already exists: %s", machinePath)
		fmt.Println("Edit it with: blackdot config edit machine")
		return nil
	}

	// Create directory
	os.MkdirAll(filepath.Dir(machinePath), 0755)

	// Create initial config
	initialConfig := map[string]interface{}{
		"$schema": "https://json-schema.org/draft/2020-12/schema",
		"machine": map[string]interface{}{
			"identifier": identifier,
		},
	}

	data, _ := json.MarshalIndent(initialConfig, "", "  ")
	if err := os.WriteFile(machinePath, data, 0644); err != nil {
		Fail("Failed to create machine config: %v", err)
		return err
	}

	Pass("Created machine config: %s", machinePath)
	fmt.Printf("  Identifier: %s\n", identifier)
	fmt.Println()
	fmt.Println("Edit with: blackdot config edit machine")
	return nil
}

func configInitProject() error {
	cwd, _ := os.Getwd()
	projectConfig := filepath.Join(cwd, ".blackdot.json")

	// Check if already exists
	if _, err := os.Stat(projectConfig); err == nil {
		Warn("Project config already exists: %s", projectConfig)
		fmt.Println("Edit it with: blackdot config edit project")
		return nil
	}

	// Create initial config
	initialConfig := map[string]interface{}{
		"$schema":  "https://json-schema.org/draft/2020-12/schema",
		"$comment": "Project-specific blackdot configuration",
	}

	data, _ := json.MarshalIndent(initialConfig, "", "  ")
	if err := os.WriteFile(projectConfig, data, 0644); err != nil {
		Fail("Failed to create project config: %v", err)
		return err
	}

	Pass("Created project config: %s", projectConfig)
	fmt.Println()
	fmt.Println("Edit with: blackdot config edit project")
	return nil
}

func configEdit(layer string) error {
	userPath, machinePath := configPaths()

	editor := os.Getenv("EDITOR")
	if editor == "" {
		editor = "vim"
	}

	var configFile string
	switch layer {
	case "user":
		configFile = userPath
	case "machine":
		configFile = machinePath
	case "project":
		configFile = findProjectConfig()
		if configFile == "" {
			Fail("No project config found")
			fmt.Println("Create one with: blackdot config init project")
			return fmt.Errorf("no project config")
		}
	default:
		Fail("Unknown layer: %s", layer)
		fmt.Println("Valid layers: user, machine, project")
		return fmt.Errorf("unknown layer: %s", layer)
	}

	if _, err := os.Stat(configFile); os.IsNotExist(err) {
		Fail("Config file does not exist: %s", configFile)
		fmt.Printf("Create it with: blackdot config init %s\n", layer)
		return err
	}

	cmd := exec.Command(editor, configFile)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// ============================================================
// Helper Functions
// ============================================================

func findProjectConfig() string {
	// Search up from current directory for .blackdot.json
	dir, _ := os.Getwd()
	for {
		configPath := filepath.Join(dir, ".blackdot.json")
		if _, err := os.Stat(configPath); err == nil {
			return configPath
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return ""
}

func getFromJSONFile(path, key string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}

	var obj map[string]interface{}
	if err := json.Unmarshal(data, &obj); err != nil {
		return ""
	}

	// Navigate nested keys
	parts := strings.Split(key, ".")
	current := obj
	for i, part := range parts {
		if i == len(parts)-1 {
			if val, ok := current[part]; ok {
				switch v := val.(type) {
				case string:
					return v
				case bool:
					if v {
						return "true"
					}
					return "false"
				case float64:
					return fmt.Sprintf("%v", v)
				default:
					data, _ := json.Marshal(v)
					return string(data)
				}
			}
		} else {
			if nested, ok := current[part].(map[string]interface{}); ok {
				current = nested
			} else {
				return ""
			}
		}
	}
	return ""
}

func setInJSONFile(path, key, value string) error {
	// Read existing file or create new
	var obj map[string]interface{}

	if data, err := os.ReadFile(path); err == nil {
		if err := json.Unmarshal(data, &obj); err != nil {
			return fmt.Errorf("parsing %s: %w", path, err)
		}
	}
	if obj == nil {
		obj = make(map[string]interface{})
	}

	// Navigate and set nested keys
	parts := strings.Split(key, ".")
	current := obj
	for i, part := range parts {
		if i == len(parts)-1 {
			// Try to parse value as JSON, otherwise use as string
			var parsed interface{}
			if err := json.Unmarshal([]byte(value), &parsed); err == nil {
				current[part] = parsed
			} else {
				current[part] = value
			}
		} else {
			if _, ok := current[part]; !ok {
				current[part] = make(map[string]interface{})
			}
			if nested, ok := current[part].(map[string]interface{}); ok {
				current = nested
			} else {
				return fmt.Errorf("cannot set nested key: %s is not an object", part)
			}
		}
	}

	// Create directory if needed
	os.MkdirAll(filepath.Dir(path), 0755)

	// Write back
	data, _ := json.MarshalIndent(obj, "", "  ")
	return os.WriteFile(path, data, 0644)
}

func loadJSONInto(path string, target map[string]interface{}) {
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}

	var obj map[string]interface{}
	if err := json.Unmarshal(data, &obj); err != nil {
		return
	}

	// Merge into target
	for k, v := range obj {
		target[k] = v
	}
}
