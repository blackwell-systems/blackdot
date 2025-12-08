package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/blackwell-systems/dotfiles/internal/config"
	"github.com/spf13/cobra"
)

// Config layer paths
var (
	configLayerUser    = filepath.Join(os.Getenv("HOME"), ".config", "dotfiles", "config.json")
	configLayerMachine = filepath.Join(os.Getenv("HOME"), ".config", "dotfiles", "machine.json")
)

func init() {
	if xdg := os.Getenv("XDG_CONFIG_HOME"); xdg != "" {
		configLayerUser = filepath.Join(xdg, "dotfiles", "config.json")
		configLayerMachine = filepath.Join(xdg, "dotfiles", "machine.json")
	}
}

func newConfigCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "config",
		Aliases: []string{"cfg"},
		Short:   "Manage configuration",
		Long: `Manage dotfiles configuration with layered resolution.

Configuration layers (highest to lowest priority):
  1. Environment variables (DOTFILES_*)
  2. Project config (.dotfiles.json in repo)
  3. Machine config (~/.config/dotfiles/machine.json)
  4. User config (~/.config/dotfiles/config.json)
  5. Built-in defaults`,
		Run: func(cmd *cobra.Command, args []string) {
			cmd.Help()
		},
	}

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
  dotfiles config set user vault.backend 1password
  dotfiles config set machine features.debug true
  dotfiles config set project shell.theme minimal`,
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
  {"value": "bitwarden", "layer": "user", "path": "~/.config/dotfiles/config.json"}`,
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
  dotfiles config init machine work-macbook
  dotfiles config init project`,
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
	// Check environment first
	envKey := "DOTFILES_" + strings.ToUpper(strings.ReplaceAll(key, ".", "_"))
	if val := os.Getenv(envKey); val != "" {
		fmt.Println(val)
		return nil
	}

	// Check project config
	if projectConfig := findProjectConfig(); projectConfig != "" {
		if val := getFromJSONFile(projectConfig, key); val != "" {
			fmt.Println(val)
			return nil
		}
	}

	// Check machine config
	if val := getFromJSONFile(configLayerMachine, key); val != "" {
		fmt.Println(val)
		return nil
	}

	// Check user config
	cfg := config.DefaultManager()
	if val, err := cfg.Get(key); err == nil && val != "" {
		fmt.Println(val)
		return nil
	}

	// Return default
	if defaultVal != "" {
		fmt.Println(defaultVal)
	}
	return nil
}

func configSet(layer, key, value string) error {
	var configFile string

	switch layer {
	case "user":
		configFile = configLayerUser
	case "machine":
		configFile = configLayerMachine
	case "project":
		configFile = findProjectConfig()
		if configFile == "" {
			Fail("No project config found")
			fmt.Println("Create one with: dotfiles config init project")
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

	// Environment
	envKey := "DOTFILES_" + strings.ToUpper(strings.ReplaceAll(key, ".", "_"))
	if val := os.Getenv(envKey); val != "" {
		fmt.Printf("  env:      %s  %s\n", val, Green.Sprint("← active"))
		return nil
	}
	fmt.Printf("  env:      %s\n", Dim.Sprint("(not set)"))

	// Project
	active := false
	projectConfig := findProjectConfig()
	if projectConfig != "" {
		if val := getFromJSONFile(projectConfig, key); val != "" {
			if !active {
				fmt.Printf("  project:  %s  %s\n", val, Green.Sprint("← active"))
				active = true
			} else {
				fmt.Printf("  project:  %s\n", val)
			}
		} else {
			fmt.Printf("  project:  %s\n", Dim.Sprint("(not set)"))
		}
	} else {
		fmt.Printf("  project:  %s\n", Dim.Sprint("(no config)"))
	}

	// Machine
	if val := getFromJSONFile(configLayerMachine, key); val != "" {
		if !active {
			fmt.Printf("  machine:  %s  %s\n", val, Green.Sprint("← active"))
			active = true
		} else {
			fmt.Printf("  machine:  %s\n", val)
		}
	} else {
		fmt.Printf("  machine:  %s\n", Dim.Sprint("(not set)"))
	}

	// User
	cfg := config.DefaultManager()
	if val, err := cfg.Get(key); err == nil && val != "" {
		if !active {
			fmt.Printf("  user:     %s  %s\n", val, Green.Sprint("← active"))
		} else {
			fmt.Printf("  user:     %s\n", val)
		}
	} else {
		fmt.Printf("  user:     %s\n", Dim.Sprint("(not set)"))
	}

	return nil
}

func configSource(key, defaultVal string) error {
	type sourceResult struct {
		Value string `json:"value"`
		Layer string `json:"layer"`
		Path  string `json:"path,omitempty"`
	}

	var result sourceResult

	// Check environment first
	envKey := "DOTFILES_" + strings.ToUpper(strings.ReplaceAll(key, ".", "_"))
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
	if val := getFromJSONFile(configLayerMachine, key); val != "" {
		result = sourceResult{Value: val, Layer: "machine", Path: configLayerMachine}
		data, _ := json.Marshal(result)
		fmt.Println(string(data))
		return nil
	}

	// Check user config
	cfg := config.DefaultManager()
	if val, err := cfg.Get(key); err == nil && val != "" {
		result = sourceResult{Value: val, Layer: "user", Path: configLayerUser}
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
	PrintHeader("Configuration Layers")
	fmt.Println()
	fmt.Println("Layer Locations:")
	fmt.Println("───────────────────────────────────────────────────────────────")

	// Environment
	fmt.Printf("  env:       %s\n", Dim.Sprint("DOTFILES_* environment variables"))

	// Project
	projectConfig := findProjectConfig()
	if projectConfig != "" {
		fmt.Printf("  project:   %s %s\n", projectConfig, Green.Sprint("✓"))
	} else {
		fmt.Printf("  project:   %s\n", Dim.Sprint(".dotfiles.json (not found)"))
	}

	// Machine
	if _, err := os.Stat(configLayerMachine); err == nil {
		fmt.Printf("  machine:   %s %s\n", configLayerMachine, Green.Sprint("✓"))
	} else {
		fmt.Printf("  machine:   %s\n", Dim.Sprint(configLayerMachine+" (not found)"))
	}

	// User
	if _, err := os.Stat(configLayerUser); err == nil {
		fmt.Printf("  user:      %s %s\n", configLayerUser, Green.Sprint("✓"))
	} else {
		fmt.Printf("  user:      %s\n", Dim.Sprint(configLayerUser+" (not found)"))
	}

	fmt.Println()
	fmt.Println("Priority: env > project > machine > user > default")
	fmt.Println()

	return nil
}

func configMerged() error {
	PrintHeader("Merged Configuration")

	merged := make(map[string]interface{})

	// Load user config (lowest priority)
	loadJSONInto(configLayerUser, merged)

	// Load machine config
	loadJSONInto(configLayerMachine, merged)

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
	if identifier == "" {
		hostname, _ := os.Hostname()
		identifier = hostname
	}

	// Check if already exists
	if _, err := os.Stat(configLayerMachine); err == nil {
		Warn("Machine config already exists: %s", configLayerMachine)
		fmt.Println("Edit it with: dotfiles config edit machine")
		return nil
	}

	// Create directory
	os.MkdirAll(filepath.Dir(configLayerMachine), 0755)

	// Create initial config
	initialConfig := map[string]interface{}{
		"$schema": "https://json-schema.org/draft/2020-12/schema",
		"machine": map[string]interface{}{
			"identifier": identifier,
		},
	}

	data, _ := json.MarshalIndent(initialConfig, "", "  ")
	if err := os.WriteFile(configLayerMachine, data, 0644); err != nil {
		Fail("Failed to create machine config: %v", err)
		return err
	}

	Pass("Created machine config: %s", configLayerMachine)
	fmt.Printf("  Identifier: %s\n", identifier)
	fmt.Println()
	fmt.Println("Edit with: dotfiles config edit machine")
	return nil
}

func configInitProject() error {
	cwd, _ := os.Getwd()
	projectConfig := filepath.Join(cwd, ".dotfiles.json")

	// Check if already exists
	if _, err := os.Stat(projectConfig); err == nil {
		Warn("Project config already exists: %s", projectConfig)
		fmt.Println("Edit it with: dotfiles config edit project")
		return nil
	}

	// Create initial config
	initialConfig := map[string]interface{}{
		"$schema": "https://json-schema.org/draft/2020-12/schema",
		"$comment": "Project-specific dotfiles configuration",
	}

	data, _ := json.MarshalIndent(initialConfig, "", "  ")
	if err := os.WriteFile(projectConfig, data, 0644); err != nil {
		Fail("Failed to create project config: %v", err)
		return err
	}

	Pass("Created project config: %s", projectConfig)
	fmt.Println()
	fmt.Println("Edit with: dotfiles config edit project")
	return nil
}

func configEdit(layer string) error {
	editor := os.Getenv("EDITOR")
	if editor == "" {
		editor = "vim"
	}

	var configFile string
	switch layer {
	case "user":
		configFile = configLayerUser
	case "machine":
		configFile = configLayerMachine
	case "project":
		configFile = findProjectConfig()
		if configFile == "" {
			Fail("No project config found")
			fmt.Println("Create one with: dotfiles config init project")
			return fmt.Errorf("no project config")
		}
	default:
		Fail("Unknown layer: %s", layer)
		fmt.Println("Valid layers: user, machine, project")
		return fmt.Errorf("unknown layer: %s", layer)
	}

	if _, err := os.Stat(configFile); os.IsNotExist(err) {
		Fail("Config file does not exist: %s", configFile)
		fmt.Printf("Create it with: dotfiles config init %s\n", layer)
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
	// Search up from current directory for .dotfiles.json
	dir, _ := os.Getwd()
	for {
		configPath := filepath.Join(dir, ".dotfiles.json")
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
		json.Unmarshal(data, &obj)
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
