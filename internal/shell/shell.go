// Package shell provides utilities for interacting with shell configurations.
//
// This package handles:
//   - Generating shell-compatible output for sourcing
//   - Detecting shell type (zsh, bash)
//   - Managing shell integrations
//
// Note: Shell configuration files (zsh.d/*.zsh) remain as Zsh scripts.
// This package helps the Go CLI interoperate with them.
package shell

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// ShellType represents a shell type
type ShellType string

const (
	ShellZsh  ShellType = "zsh"
	ShellBash ShellType = "bash"
	ShellFish ShellType = "fish"
	ShellUnknown ShellType = "unknown"
)

// Detect returns the current shell type
func Detect() ShellType {
	shell := os.Getenv("SHELL")
	if shell == "" {
		return ShellUnknown
	}

	base := filepath.Base(shell)
	switch base {
	case "zsh":
		return ShellZsh
	case "bash":
		return ShellBash
	case "fish":
		return ShellFish
	default:
		return ShellUnknown
	}
}

// ExportVar generates a shell-compatible export statement
func ExportVar(name, value string) string {
	shell := Detect()
	switch shell {
	case ShellFish:
		return fmt.Sprintf("set -gx %s %q", name, value)
	default:
		return fmt.Sprintf("export %s=%q", name, value)
	}
}

// EvalOutput generates output suitable for eval in shell
// Example: eval "$(dotfiles env)"
func EvalOutput(vars map[string]string) string {
	var lines []string
	for name, value := range vars {
		lines = append(lines, ExportVar(name, value))
	}
	return strings.Join(lines, "\n")
}

// SourceCommand returns the command to source the shell config
func SourceCommand(path string) string {
	shell := Detect()
	switch shell {
	case ShellFish:
		return fmt.Sprintf("source %s", path)
	default:
		return fmt.Sprintf("source %q", path)
	}
}

// Integration represents a shell integration (tool that hooks into shell)
type Integration struct {
	Name        string
	Description string
	Condition   func() bool          // Return true if integration should be enabled
	Setup       func() (string, error) // Return shell code to eval
}

// CommonIntegrations returns standard integrations
func CommonIntegrations() []*Integration {
	return []*Integration{
		{
			Name:        "direnv",
			Description: "Directory-specific environment variables",
			Condition: func() bool {
				_, err := os.Stat("/usr/local/bin/direnv")
				if err == nil {
					return true
				}
				_, err = os.Stat("/opt/homebrew/bin/direnv")
				return err == nil
			},
			Setup: func() (string, error) {
				switch Detect() {
				case ShellZsh:
					return `eval "$(direnv hook zsh)"`, nil
				case ShellBash:
					return `eval "$(direnv hook bash)"`, nil
				case ShellFish:
					return `direnv hook fish | source`, nil
				}
				return "", nil
			},
		},
		{
			Name:        "starship",
			Description: "Cross-shell prompt",
			Condition: func() bool {
				_, err := os.Stat("/usr/local/bin/starship")
				if err == nil {
					return true
				}
				_, err = os.Stat("/opt/homebrew/bin/starship")
				return err == nil
			},
			Setup: func() (string, error) {
				switch Detect() {
				case ShellZsh:
					return `eval "$(starship init zsh)"`, nil
				case ShellBash:
					return `eval "$(starship init bash)"`, nil
				case ShellFish:
					return `starship init fish | source`, nil
				}
				return "", nil
			},
		},
		{
			Name:        "zoxide",
			Description: "Smarter cd command",
			Condition: func() bool {
				_, err := os.Stat("/usr/local/bin/zoxide")
				if err == nil {
					return true
				}
				_, err = os.Stat("/opt/homebrew/bin/zoxide")
				return err == nil
			},
			Setup: func() (string, error) {
				switch Detect() {
				case ShellZsh:
					return `eval "$(zoxide init zsh)"`, nil
				case ShellBash:
					return `eval "$(zoxide init bash)"`, nil
				case ShellFish:
					return `zoxide init fish | source`, nil
				}
				return "", nil
			},
		},
	}
}

// GenerateFeatureCheck generates shell code to check if a feature is enabled
// This allows shell scripts to call the Go binary for feature checks
func GenerateFeatureCheck(featureName string) string {
	return fmt.Sprintf(`
# Feature check for %s
if blackdot features check %s >/dev/null 2>&1; then
    _BLACKDOT_FEATURE_%s=1
else
    _BLACKDOT_FEATURE_%s=0
fi
`, featureName, featureName, strings.ToUpper(featureName), strings.ToUpper(featureName))
}
