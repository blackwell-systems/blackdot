// Package config provides configuration management for blackdot.
//
// This package implements the layered configuration system with
// resolution order: env > project > machine > user > defaults.
//
// It mirrors the functionality of lib/_config.sh and lib/_config_layers.sh
package config

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
)

// Layer represents a configuration layer
type Layer string

const (
	LayerEnv     Layer = "env"
	LayerProject Layer = "project"
	LayerMachine Layer = "machine"
	LayerUser    Layer = "user"
	LayerDefault Layer = "default"
)

// Config file names
const (
	ProjectConfigFile = ".blackdot.json"
	MachineConfigFile = "machine.json"
	UserConfigFile    = "config.json"
)

// Config represents the blackdot configuration
type Config struct {
	Version  int                    `json:"version"`
	Features map[string]bool        `json:"features,omitempty"`
	Vault    VaultConfig            `json:"vault,omitempty"`
	Setup    SetupState             `json:"setup,omitempty"`
	Extra    map[string]interface{} `json:"-"` // Catch-all for unknown fields
}

// VaultConfig holds vault-related configuration
type VaultConfig struct {
	Backend   string `json:"backend,omitempty"`
	AutoSync  bool   `json:"auto_sync,omitempty"`
	Location  string `json:"location,omitempty"`
	Namespace string `json:"namespace,omitempty"`
}

// SetupState tracks setup wizard progress
type SetupState struct {
	Completed []string `json:"completed,omitempty"`
	Timestamp string   `json:"timestamp,omitempty"`
}

// LayerResult contains a config value and its source
type LayerResult struct {
	Key    string `json:"key"`
	Value  string `json:"value"`
	Source Layer  `json:"source"`
	File   string `json:"file,omitempty"`
}

// Manager handles configuration operations
type Manager struct {
	configDir   string
	dotfilesDir string
}

// NewManager creates a new config manager
func NewManager(configDir, dotfilesDir string) *Manager {
	return &Manager{
		configDir:   configDir,
		dotfilesDir: dotfilesDir,
	}
}

// DefaultManager creates a manager with default paths
func DefaultManager() *Manager {
	configDir := os.Getenv("XDG_CONFIG_HOME")
	if configDir == "" {
		home, _ := os.UserHomeDir()
		configDir = filepath.Join(home, ".config")
	} else {
		// Normalize path separators for cross-platform consistency
		configDir = filepath.Clean(configDir)
	}
	configDir = filepath.Join(configDir, "blackdot")

	dotfilesDir := os.Getenv("BLACKDOT_DIR")
	if dotfilesDir == "" {
		home, _ := os.UserHomeDir()
		dotfilesDir = filepath.Join(home, ".blackdot")
	} else {
		// Normalize path separators for cross-platform consistency
		dotfilesDir = filepath.Clean(dotfilesDir)
	}

	return NewManager(configDir, dotfilesDir)
}

// UserConfigPath returns the path to user config
func (m *Manager) UserConfigPath() string {
	return filepath.Join(m.configDir, UserConfigFile)
}

// MachineConfigPath returns the path to machine config
func (m *Manager) MachineConfigPath() string {
	return filepath.Join(m.configDir, MachineConfigFile)
}

// ProjectConfigPath finds .blackdot.json by walking up from cwd
func (m *Manager) ProjectConfigPath() string {
	dir, err := os.Getwd()
	if err != nil {
		return ""
	}

	for {
		path := filepath.Join(dir, ProjectConfigFile)
		if _, err := os.Stat(path); err == nil {
			return path
		}
		parent := filepath.Dir(dir)
		// Stop when we've reached the root (parent equals current)
		if parent == dir {
			break
		}
		dir = parent
	}
	return ""
}

// Load reads the user config file
func (m *Manager) Load() (*Config, error) {
	return m.loadFile(m.UserConfigPath())
}

// loadFile reads a config file
func (m *Manager) loadFile(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return &Config{Version: 3}, nil
		}
		return nil, err
	}

	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}

	return &cfg, nil
}

// Save writes the user config file
func (m *Manager) Save(cfg *Config) error {
	// Ensure directory exists
	if err := os.MkdirAll(m.configDir, 0755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(m.UserConfigPath(), data, 0644)
}

// Get retrieves a config value using dot notation (e.g., "vault.backend")
func (m *Manager) Get(key string) (string, error) {
	cfg, err := m.Load()
	if err != nil {
		return "", err
	}

	return getNestedValue(cfg, key)
}

// GetLayered retrieves a value with layer resolution
func (m *Manager) GetLayered(key string) (*LayerResult, error) {
	result := &LayerResult{Key: key}

	// Layer 1: Environment variable
	// vault.backend -> BLACKDOT_VAULT_BACKEND
	envKey := "BLACKDOT_" + strings.ToUpper(strings.ReplaceAll(key, ".", "_"))
	if val := os.Getenv(envKey); val != "" {
		result.Value = val
		result.Source = LayerEnv
		result.File = envKey
		return result, nil
	}

	// Layer 2: Project config
	if path := m.ProjectConfigPath(); path != "" {
		if cfg, err := m.loadFile(path); err == nil {
			if val, err := getNestedValue(cfg, key); err == nil && val != "" {
				result.Value = val
				result.Source = LayerProject
				result.File = path
				return result, nil
			}
		}
	}

	// Layer 3: Machine config
	if cfg, err := m.loadFile(m.MachineConfigPath()); err == nil {
		if val, err := getNestedValue(cfg, key); err == nil && val != "" {
			result.Value = val
			result.Source = LayerMachine
			result.File = m.MachineConfigPath()
			return result, nil
		}
	}

	// Layer 4: User config
	if cfg, err := m.loadFile(m.UserConfigPath()); err == nil {
		if val, err := getNestedValue(cfg, key); err == nil && val != "" {
			result.Value = val
			result.Source = LayerUser
			result.File = m.UserConfigPath()
			return result, nil
		}
	}

	// Layer 5: Default
	result.Source = LayerDefault
	return result, nil
}

// Set writes a config value using dot notation
func (m *Manager) Set(key, value string) error {
	cfg, err := m.Load()
	if err != nil {
		return err
	}

	if err := setNestedValue(cfg, key, value); err != nil {
		return err
	}

	return m.Save(cfg)
}

// getNestedValue extracts a value using dot notation
func getNestedValue(cfg *Config, key string) (string, error) {
	parts := strings.Split(key, ".")
	if len(parts) == 0 {
		return "", errors.New("empty key")
	}

	switch parts[0] {
	case "version":
		return string(rune(cfg.Version + '0')), nil
	case "vault":
		if len(parts) < 2 {
			return "", errors.New("incomplete vault key")
		}
		switch parts[1] {
		case "backend":
			return cfg.Vault.Backend, nil
		case "auto_sync":
			if cfg.Vault.AutoSync {
				return "true", nil
			}
			return "false", nil
		case "location":
			return cfg.Vault.Location, nil
		case "namespace":
			return cfg.Vault.Namespace, nil
		}
	case "features":
		if len(parts) < 2 {
			return "", errors.New("incomplete features key")
		}
		if enabled, ok := cfg.Features[parts[1]]; ok {
			if enabled {
				return "true", nil
			}
			return "false", nil
		}
	}

	return "", errors.New("key not found: " + key)
}

// setNestedValue sets a value using dot notation
func setNestedValue(cfg *Config, key, value string) error {
	parts := strings.Split(key, ".")
	if len(parts) == 0 {
		return errors.New("empty key")
	}

	switch parts[0] {
	case "vault":
		if len(parts) < 2 {
			return errors.New("incomplete vault key")
		}
		switch parts[1] {
		case "backend":
			cfg.Vault.Backend = value
		case "auto_sync":
			cfg.Vault.AutoSync = value == "true"
		case "location":
			cfg.Vault.Location = value
		case "namespace":
			cfg.Vault.Namespace = value
		default:
			return errors.New("unknown vault key: " + parts[1])
		}
	case "features":
		if len(parts) < 2 {
			return errors.New("incomplete features key")
		}
		if cfg.Features == nil {
			cfg.Features = make(map[string]bool)
		}
		cfg.Features[parts[1]] = value == "true"
	default:
		return errors.New("unknown config section: " + parts[0])
	}

	return nil
}
