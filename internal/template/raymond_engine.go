// Package template provides a Handlebars-compatible template engine using raymond.
//
// This is the Phase C implementation that uses the raymond library for
// proper Handlebars parsing instead of regex-based processing.
//
// Syntax supported (standard Handlebars):
//   - {{ variable }}              - Simple substitution
//   - {{#if cond}}...{{/if}}      - Conditional blocks
//   - {{#if (eq var "val")}}      - Comparison conditionals
//   - {{#unless c}}...{{/unless}} - Negated conditional
//   - {{#each arr}}...{{/each}}   - Iteration
//   - {{ helper var }}            - Helper functions (filters)
//   - {{ helper var "arg" }}      - Helper with argument
//
// This mirrors the functionality of lib/_templates.sh with standard Handlebars syntax.
package template

import (
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/aymerick/raymond"
)

// helpersRegistered ensures helpers are only registered once (raymond uses global registry)
var helpersOnce sync.Once

// RaymondEngine handles template rendering using the raymond Handlebars library
type RaymondEngine struct {
	vars        map[string]interface{}
	arrays      map[string][]map[string]interface{}
	templateDir string
}

// NewRaymondEngine creates a new raymond-based template engine
func NewRaymondEngine(templateDir string) *RaymondEngine {
	e := &RaymondEngine{
		vars:        make(map[string]interface{}),
		arrays:      make(map[string][]map[string]interface{}),
		templateDir: templateDir,
	}

	return e
}

// registerHelpers registers all Handlebars helpers
// This is called once globally (raymond uses a global helper registry)
func registerHelpers() {
	helpersOnce.Do(func() {
		registerAllHelpers()
	})
}

// registerAllHelpers does the actual helper registration
func registerAllHelpers() {

	// Comparison helpers for conditionals
	raymond.RegisterHelper("eq", func(a, b string) bool {
		return a == b
	})

	raymond.RegisterHelper("ne", func(a, b string) bool {
		return a != b
	})

	// Case transformation filters
	raymond.RegisterHelper("upper", func(s string) string {
		return strings.ToUpper(s)
	})

	raymond.RegisterHelper("lower", func(s string) string {
		return strings.ToLower(s)
	})

	raymond.RegisterHelper("capitalize", func(s string) string {
		if s == "" {
			return ""
		}
		return strings.ToUpper(s[:1]) + s[1:]
	})

	// String operation filters
	raymond.RegisterHelper("trim", func(s string) string {
		return strings.TrimSpace(s)
	})

	raymond.RegisterHelper("replace", func(s, old, new string) string {
		return strings.ReplaceAll(s, old, new)
	})

	raymond.RegisterHelper("append", func(s, suffix string) string {
		return s + suffix
	})

	raymond.RegisterHelper("prepend", func(prefix, s string) string {
		return prefix + s
	})

	raymond.RegisterHelper("quote", func(s string) raymond.SafeString {
		return raymond.SafeString(`"` + s + `"`)
	})

	raymond.RegisterHelper("squote", func(s string) raymond.SafeString {
		return raymond.SafeString("'" + s + "'")
	})

	raymond.RegisterHelper("truncate", func(s string, n int) string {
		if len(s) <= n {
			return s
		}
		return s[:n]
	})

	raymond.RegisterHelper("length", func(s string) int {
		return len(s)
	})

	// Path operation filters
	raymond.RegisterHelper("basename", func(s string) string {
		return filepath.Base(s)
	})

	raymond.RegisterHelper("dirname", func(s string) string {
		return filepath.Dir(s)
	})

	// Default value filter
	raymond.RegisterHelper("default", func(s, defaultVal string) string {
		if s == "" {
			return defaultVal
		}
		return s
	})
}

// SetVar sets a template variable
func (e *RaymondEngine) SetVar(name string, value interface{}) {
	e.vars[name] = value
}

// SetArray sets an array variable for {{#each}} loops
// items should be a slice of maps with field names as keys
func (e *RaymondEngine) SetArray(name string, items []map[string]interface{}) {
	e.arrays[name] = items
}

// GetVar returns a variable value with environment override support
func (e *RaymondEngine) GetVar(name string) (interface{}, bool) {
	// Check environment override first (highest priority)
	envName := "DOTFILES_TMPL_" + strings.ToUpper(strings.ReplaceAll(name, ".", "_"))
	if val := os.Getenv(envName); val != "" {
		return val, true
	}

	val, ok := e.vars[name]
	return val, ok
}

// buildContext creates the template context with all variables and arrays
func (e *RaymondEngine) buildContext() map[string]interface{} {
	ctx := make(map[string]interface{})

	// Copy all variables
	for k, v := range e.vars {
		ctx[k] = v
	}

	// Add arrays for {{#each}} loops
	for k, v := range e.arrays {
		ctx[k] = v
	}

	// Apply environment overrides
	for k := range e.vars {
		envName := "DOTFILES_TMPL_" + strings.ToUpper(strings.ReplaceAll(k, ".", "_"))
		if val := os.Getenv(envName); val != "" {
			ctx[k] = val
		}
	}

	return ctx
}

// preprocessTemplate converts bash-style syntax to standard Handlebars
// This ensures compatibility with templates using {{#else}} instead of {{else}}
func preprocessTemplate(input string) string {
	// Convert {{#else}} to {{else}} (bash extension to standard Handlebars)
	return strings.ReplaceAll(input, "{{#else}}", "{{else}}")
}

// Render processes a template string and returns the result
func (e *RaymondEngine) Render(input string) (string, error) {
	// Register helpers (once globally)
	registerHelpers()

	// Preprocess template for compatibility
	input = preprocessTemplate(input)

	// Build context with all variables
	ctx := e.buildContext()

	// Parse and execute template
	result, err := raymond.Render(input, ctx)
	if err != nil {
		return "", err
	}

	return result, nil
}

// RenderFile reads and renders a template file
func (e *RaymondEngine) RenderFile(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	return e.Render(string(data))
}

// LoadVariablesFile loads variables from a shell-style variables file
// This matches the bash implementation's variable loading
func (e *RaymondEngine) LoadVariablesFile(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	// Parse VAR=value or VAR="value" lines
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)

		// Skip comments and empty lines
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		// Handle export VAR=value
		line = strings.TrimPrefix(line, "export ")

		// Split on first =
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}

		name := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])

		// Remove quotes
		value = strings.Trim(value, `"'`)

		e.SetVar(name, value)
	}

	return nil
}

// LoadAutoDetectedVars loads auto-detected variables like hostname, os, etc.
// This mirrors the bash _templates.sh build_auto_vars function
func (e *RaymondEngine) LoadAutoDetectedVars() {
	// Hostname
	if hostname, err := os.Hostname(); err == nil {
		e.SetVar("hostname", hostname)
	}

	// OS detection
	e.SetVar("os", detectOS())

	// User
	if user := os.Getenv("USER"); user != "" {
		e.SetVar("user", user)
	}

	// Home directory
	if home := os.Getenv("HOME"); home != "" {
		e.SetVar("home", home)
	}

	// Shell
	if shell := os.Getenv("SHELL"); shell != "" {
		e.SetVar("shell", shell)
	}
}

// detectOS returns the current OS type matching bash implementation
func detectOS() string {
	// Check for Darwin (macOS)
	if _, err := os.Stat("/System/Library"); err == nil {
		return "macos"
	}

	// Check for WSL
	if data, err := os.ReadFile("/proc/version"); err == nil {
		if strings.Contains(strings.ToLower(string(data)), "microsoft") {
			return "wsl"
		}
	}

	// Check for Linux
	if _, err := os.Stat("/proc"); err == nil {
		return "linux"
	}

	return "unknown"
}
