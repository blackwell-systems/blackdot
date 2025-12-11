// Package template provides a Handlebars-like template engine for blackdot.
//
// Syntax supported:
//   - {{ variable }}           - Simple substitution
//   - {{#if cond}}...{{/if}}   - Conditional blocks
//   - {{#unless c}}...{{/unless}} - Negated conditional
//   - {{#each arr}}...{{/each}} - Iteration
//   - {{ var | filter }}       - Filter pipes
//
// This mirrors the functionality of lib/_templates.sh
package template

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// Engine handles template rendering
type Engine struct {
	vars       map[string]string
	arrays     map[string][]string
	filters    map[string]FilterFunc
	templateDir string
}

// FilterFunc is a function that transforms a value
type FilterFunc func(value string) string

// NewEngine creates a new template engine
func NewEngine(templateDir string) *Engine {
	e := &Engine{
		vars:       make(map[string]string),
		arrays:     make(map[string][]string),
		filters:    make(map[string]FilterFunc),
		templateDir: templateDir,
	}

	// Register built-in filters
	e.RegisterFilter("upper", strings.ToUpper)
	e.RegisterFilter("lower", strings.ToLower)
	e.RegisterFilter("trim", strings.TrimSpace)
	e.RegisterFilter("dirname", filepath.Dir)
	e.RegisterFilter("basename", filepath.Base)
	e.RegisterFilter("quote", func(s string) string {
		return fmt.Sprintf("%q", s)
	})
	e.RegisterFilter("default", func(s string) string {
		// This filter needs special handling with arguments
		return s
	})

	return e
}

// SetVar sets a template variable
func (e *Engine) SetVar(name, value string) {
	e.vars[name] = value
}

// SetArray sets an array variable for {{#each}} loops
func (e *Engine) SetArray(name string, values []string) {
	e.arrays[name] = values
}

// GetVar returns a variable value
func (e *Engine) GetVar(name string) (string, bool) {
	// Check environment override first
	envName := "BLACKDOT_TMPL_" + strings.ToUpper(strings.ReplaceAll(name, ".", "_"))
	if val := os.Getenv(envName); val != "" {
		return val, true
	}

	val, ok := e.vars[name]
	return val, ok
}

// RegisterFilter adds a filter function
func (e *Engine) RegisterFilter(name string, fn FilterFunc) {
	e.filters[name] = fn
}

// Render processes a template string and returns the result
func (e *Engine) Render(input string) (string, error) {
	result := input

	// Process {{#each array}}...{{/each}} blocks
	result = e.processEachBlocks(result)

	// Process {{#if condition}}...{{/if}} blocks
	result = e.processIfBlocks(result)

	// Process {{#unless condition}}...{{/unless}} blocks
	result = e.processUnlessBlocks(result)

	// Process {{ variable }} and {{ variable | filter }} substitutions
	result = e.processVariables(result)

	return result, nil
}

// RenderFile reads and renders a template file
func (e *Engine) RenderFile(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("reading template %s: %w", path, err)
	}
	return e.Render(string(data))
}

// processVariables handles {{ var }} and {{ var | filter }} syntax
func (e *Engine) processVariables(input string) string {
	// Match {{ var }} or {{ var | filter }}
	re := regexp.MustCompile(`\{\{\s*([^}|]+?)(?:\s*\|\s*([^}]+))?\s*\}\}`)

	return re.ReplaceAllStringFunc(input, func(match string) string {
		parts := re.FindStringSubmatch(match)
		if len(parts) < 2 {
			return match
		}

		varName := strings.TrimSpace(parts[1])
		value, ok := e.GetVar(varName)
		if !ok {
			// Return empty string for undefined variables
			return ""
		}

		// Apply filter if present
		if len(parts) > 2 && parts[2] != "" {
			filterName := strings.TrimSpace(parts[2])
			if fn, ok := e.filters[filterName]; ok {
				value = fn(value)
			}
		}

		return value
	})
}

// processIfBlocks handles {{#if var}}...{{/if}} and {{#if var}}...{{else}}...{{/if}}
func (e *Engine) processIfBlocks(input string) string {
	// Simple implementation - doesn't handle nested blocks
	re := regexp.MustCompile(`(?s)\{\{#if\s+(\w+)\}\}(.*?)(?:\{\{else\}\}(.*?))?\{\{/if\}\}`)

	return re.ReplaceAllStringFunc(input, func(match string) string {
		parts := re.FindStringSubmatch(match)
		if len(parts) < 3 {
			return match
		}

		varName := parts[1]
		trueBranch := parts[2]
		falseBranch := ""
		if len(parts) > 3 {
			falseBranch = parts[3]
		}

		value, ok := e.GetVar(varName)
		if ok && value != "" && value != "false" && value != "0" {
			return trueBranch
		}
		return falseBranch
	})
}

// processUnlessBlocks handles {{#unless var}}...{{/unless}}
func (e *Engine) processUnlessBlocks(input string) string {
	re := regexp.MustCompile(`(?s)\{\{#unless\s+(\w+)\}\}(.*?)\{\{/unless\}\}`)

	return re.ReplaceAllStringFunc(input, func(match string) string {
		parts := re.FindStringSubmatch(match)
		if len(parts) < 3 {
			return match
		}

		varName := parts[1]
		content := parts[2]

		value, ok := e.GetVar(varName)
		if !ok || value == "" || value == "false" || value == "0" {
			return content
		}
		return ""
	})
}

// processEachBlocks handles {{#each array}}...{{/each}}
func (e *Engine) processEachBlocks(input string) string {
	re := regexp.MustCompile(`(?s)\{\{#each\s+(\w+)\}\}(.*?)\{\{/each\}\}`)

	return re.ReplaceAllStringFunc(input, func(match string) string {
		parts := re.FindStringSubmatch(match)
		if len(parts) < 3 {
			return match
		}

		arrayName := parts[1]
		template := parts[2]

		arr, ok := e.arrays[arrayName]
		if !ok {
			return ""
		}

		var result strings.Builder
		for i, item := range arr {
			// Create a temporary engine for this iteration
			iterContent := template

			// Replace {{this}} with current item
			iterContent = strings.ReplaceAll(iterContent, "{{this}}", item)

			// Replace {{@index}} with current index
			iterContent = strings.ReplaceAll(iterContent, "{{@index}}", fmt.Sprintf("%d", i))

			// Replace {{@first}} and {{@last}}
			if i == 0 {
				iterContent = strings.ReplaceAll(iterContent, "{{@first}}", "true")
			} else {
				iterContent = strings.ReplaceAll(iterContent, "{{@first}}", "")
			}
			if i == len(arr)-1 {
				iterContent = strings.ReplaceAll(iterContent, "{{@last}}", "true")
			} else {
				iterContent = strings.ReplaceAll(iterContent, "{{@last}}", "")
			}

			result.WriteString(iterContent)
		}

		return result.String()
	})
}

// LoadVariablesFile loads variables from a shell-style variables file
func (e *Engine) LoadVariablesFile(path string) error {
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
