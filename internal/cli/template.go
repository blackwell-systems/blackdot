package cli

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"time"

	"github.com/blackwell-systems/blackdot/internal/template"
	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// templateConfig holds template-related paths
type templateConfig struct {
	dotfilesDir  string
	templateDir  string
	generatedDir string
	variablesDir string
}

func getTemplateConfig() (*templateConfig, error) {
	dotfilesDir := os.Getenv("BLACKDOT_DIR")
	if dotfilesDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return nil, fmt.Errorf("cannot determine home directory: %w", err)
		}
		dotfilesDir = filepath.Join(home, ".blackdot")
	}

	return &templateConfig{
		dotfilesDir:  dotfilesDir,
		templateDir:  filepath.Join(dotfilesDir, "templates", "configs"),
		generatedDir: filepath.Join(dotfilesDir, "generated"),
		variablesDir: filepath.Join(dotfilesDir, "templates"),
	}, nil
}

func newTemplateCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "template",
		Aliases: []string{"tmpl"},
		Short:   "Manage machine-specific templates",
		Long: `Manage machine-specific configuration templates.

Templates use Handlebars syntax:
  {{ variable }}              - Simple substitution
  {{#if cond}}...{{/if}}      - Conditional blocks
  {{#if (eq var "val")}}      - Comparison conditionals
  {{#unless cond}}...{{/unless}} - Negated conditional
  {{#each arr}}...{{/each}}   - Iteration
  {{ helper var }}            - Helper functions (filters)

Available helpers: eq, ne, upper, lower, capitalize, trim, replace,
                   append, prepend, quote, squote, truncate, length,
                   basename, dirname, default`,
		Run: func(cmd *cobra.Command, args []string) {
			cmd.Help()
		},
	}

	// Render command
	renderCmd := &cobra.Command{
		Use:   "render [file...]",
		Short: "Render templates to generated/",
		Long: `Render template files using the Go template engine.

If no files are specified, renders all .tmpl files in templates/configs/.
Output goes to the generated/ directory.

Examples:
  dotfiles template render                    # Render all templates
  dotfiles template render gitconfig.tmpl     # Render specific template
  dotfiles template render --stdout file.tmpl # Output to stdout`,
		RunE: runTemplateRender,
	}
	renderCmd.Flags().Bool("stdout", false, "Output to stdout instead of file")
	renderCmd.Flags().Bool("dry-run", false, "Show what would be rendered without writing")

	// Vars command
	varsCmd := &cobra.Command{
		Use:   "vars",
		Short: "List all template variables and values",
		Long: `Show all template variables and their current values.

Variables are loaded from:
  1. Environment (DOTFILES_TMPL_* prefix, highest priority)
  2. templates/_variables.local.sh (machine-specific)
  3. templates/_variables.sh (defaults)
  4. Auto-detected values (hostname, os, user, etc.)`,
		RunE: runTemplateVars,
	}

	// List command
	listCmd := &cobra.Command{
		Use:   "list",
		Short: "Show available templates and status",
		RunE:  runTemplateList,
	}

	// Check command
	checkCmd := &cobra.Command{
		Use:   "check",
		Short: "Validate template syntax",
		RunE:  runTemplateCheck,
	}

	// Filters command
	filtersCmd := &cobra.Command{
		Use:   "filters",
		Short: "List available pipeline filters",
		RunE:  runTemplateFilters,
	}

	// Edit command
	editCmd := &cobra.Command{
		Use:   "edit",
		Short: "Open _variables.local.sh in editor",
		RunE:  runTemplateEdit,
	}

	// Arrays command
	arraysCmd := &cobra.Command{
		Use:   "arrays",
		Short: "Manage JSON/shell arrays for {{#each}} loops",
		RunE:  runTemplateArrays,
	}
	arraysCmd.Flags().BoolP("export-json", "e", false, "Export shell arrays to JSON format")
	arraysCmd.Flags().Bool("validate", false, "Validate JSON arrays file syntax")

	// Vault command
	vaultCmd := &cobra.Command{
		Use:   "vault [command]",
		Short: "Sync template variables with vault",
		Long: `Sync template variables with vault.

Commands:
  push    Push _variables.local.sh to vault
  pull    Pull from vault to _variables.local.sh
  diff    Show differences between local and vault
  sync    Bidirectional sync with conflict detection
  status  Show vault sync status (default)`,
		RunE: runTemplateVaultStatus,
	}
	vaultCmd.AddCommand(
		&cobra.Command{
			Use:   "push",
			Short: "Push _variables.local.sh to vault",
			RunE:  runTemplateVaultPush,
		},
		&cobra.Command{
			Use:   "pull",
			Short: "Pull from vault to _variables.local.sh",
			RunE:  runTemplateVaultPull,
		},
		&cobra.Command{
			Use:   "diff",
			Short: "Show differences between local and vault",
			RunE:  runTemplateVaultDiff,
		},
		&cobra.Command{
			Use:   "sync",
			Short: "Bidirectional sync with conflict detection",
			RunE:  runTemplateVaultSync,
		},
		&cobra.Command{
			Use:   "status",
			Short: "Show vault sync status",
			RunE:  runTemplateVaultStatus,
		},
	)

	cmd.AddCommand(
		renderCmd,
		varsCmd,
		listCmd,
		checkCmd,
		filtersCmd,
		editCmd,
		arraysCmd,
		vaultCmd,
		&cobra.Command{
			Use:   "init",
			Short: "Interactive setup (creates _variables.local.sh)",
			RunE:  runTemplateInit,
		},
		&cobra.Command{
			Use:   "link",
			Short: "Create symlinks from generated/ to destinations",
			RunE:  runTemplateLink,
		},
		&cobra.Command{
			Use:   "diff",
			Short: "Show differences from rendered",
			RunE:  runTemplateDiff,
		},
	)

	return cmd
}

// runTemplateRender renders template files
func runTemplateRender(cmd *cobra.Command, args []string) error {
	cfg, err := getTemplateConfig()
	if err != nil {
		return err
	}

	toStdout, _ := cmd.Flags().GetBool("stdout")
	dryRun, _ := cmd.Flags().GetBool("dry-run")

	// Create engine and load variables
	engine := template.NewRaymondEngine(cfg.templateDir)
	if err := loadTemplateVariables(engine, cfg); err != nil {
		return fmt.Errorf("loading variables: %w", err)
	}

	// Determine which templates to render
	var templates []string
	if len(args) > 0 {
		for _, arg := range args {
			tmplPath := arg
			if !filepath.IsAbs(arg) {
				tmplPath = filepath.Join(cfg.templateDir, arg)
			}
			templates = append(templates, tmplPath)
		}
	} else {
		// Find all .tmpl files
		entries, err := os.ReadDir(cfg.templateDir)
		if err != nil {
			return fmt.Errorf("reading template directory: %w", err)
		}
		for _, entry := range entries {
			if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".tmpl") {
				templates = append(templates, filepath.Join(cfg.templateDir, entry.Name()))
			}
		}
	}

	if len(templates) == 0 {
		fmt.Println("No templates found to render")
		return nil
	}

	// Ensure generated directory exists
	if !toStdout && !dryRun {
		if err := os.MkdirAll(cfg.generatedDir, 0755); err != nil {
			return fmt.Errorf("creating generated directory: %w", err)
		}
	}

	green := color.New(color.FgGreen).SprintFunc()
	cyan := color.New(color.FgCyan).SprintFunc()

	// Render each template
	for _, tmplPath := range templates {
		baseName := filepath.Base(tmplPath)
		outputName := strings.TrimSuffix(baseName, ".tmpl")

		result, err := engine.RenderFile(tmplPath)
		if err != nil {
			return fmt.Errorf("rendering %s: %w", baseName, err)
		}

		if toStdout {
			fmt.Printf("=== %s ===\n", baseName)
			fmt.Print(result)
			fmt.Println()
		} else if dryRun {
			fmt.Printf("%s %s -> %s (%d bytes)\n",
				cyan("[dry-run]"), baseName, outputName, len(result))
		} else {
			outputPath := filepath.Join(cfg.generatedDir, outputName)
			if err := os.WriteFile(outputPath, []byte(result), 0644); err != nil {
				return fmt.Errorf("writing %s: %w", outputPath, err)
			}
			fmt.Printf("%s %s -> %s\n", green("✓"), baseName, outputName)
		}
	}

	if !toStdout && !dryRun {
		fmt.Printf("\nRendered %d template(s) to %s\n", len(templates), cfg.generatedDir)
	}

	return nil
}

// runTemplateVars shows all template variables
func runTemplateVars(cmd *cobra.Command, args []string) error {
	cfg, err := getTemplateConfig()
	if err != nil {
		return err
	}

	engine := template.NewRaymondEngine(cfg.templateDir)
	if err := loadTemplateVariables(engine, cfg); err != nil {
		return fmt.Errorf("loading variables: %w", err)
	}

	// Get all variables from the engine
	vars := getEngineVars(engine)

	// Sort variable names
	var names []string
	for name := range vars {
		names = append(names, name)
	}
	sort.Strings(names)

	cyan := color.New(color.FgCyan).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()

	fmt.Println("Template Variables")
	fmt.Println("==================")
	fmt.Println()

	for _, name := range names {
		value := vars[name]
		// Truncate long values
		display := value
		if len(display) > 60 {
			display = display[:57] + "..."
		}
		// Check if from environment
		envName := "DOTFILES_TMPL_" + strings.ToUpper(strings.ReplaceAll(name, ".", "_"))
		if os.Getenv(envName) != "" {
			fmt.Printf("  %s = %s %s\n", cyan(name), display, yellow("(env)"))
		} else {
			fmt.Printf("  %s = %s\n", cyan(name), display)
		}
	}

	fmt.Printf("\nTotal: %d variables\n", len(names))
	return nil
}

// runTemplateList shows available templates
func runTemplateList(cmd *cobra.Command, args []string) error {
	cfg, err := getTemplateConfig()
	if err != nil {
		return err
	}

	entries, err := os.ReadDir(cfg.templateDir)
	if err != nil {
		return fmt.Errorf("reading template directory: %w", err)
	}

	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()

	fmt.Println("Available Templates")
	fmt.Println("===================")
	fmt.Println()

	var count int
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".tmpl") {
			continue
		}

		count++
		baseName := entry.Name()
		outputName := strings.TrimSuffix(baseName, ".tmpl")
		outputPath := filepath.Join(cfg.generatedDir, outputName)

		// Check if generated file exists
		if _, err := os.Stat(outputPath); err == nil {
			info, _ := entry.Info()
			genInfo, _ := os.Stat(outputPath)

			if info != nil && genInfo != nil {
				if genInfo.ModTime().After(info.ModTime()) {
					fmt.Printf("  %s %s -> %s\n", green("✓"), baseName, outputName)
				} else {
					fmt.Printf("  %s %s -> %s (stale)\n", yellow("⚠"), baseName, outputName)
				}
			} else {
				fmt.Printf("  %s %s -> %s\n", green("✓"), baseName, outputName)
			}
		} else {
			fmt.Printf("  - %s (not rendered)\n", baseName)
		}
	}

	fmt.Printf("\nTotal: %d templates in %s\n", count, cfg.templateDir)
	return nil
}

// loadTemplateVariables loads all variable sources into the engine
func loadTemplateVariables(engine *template.RaymondEngine, cfg *templateConfig) error {
	// 1. Load auto-detected variables (lowest priority)
	engine.LoadAutoDetectedVars()

	// 2. Load default variables file
	defaultsFile := filepath.Join(cfg.variablesDir, "_variables.sh")
	if _, err := os.Stat(defaultsFile); err == nil {
		if err := engine.LoadVariablesFile(defaultsFile); err != nil {
			// Non-fatal, just log
			fmt.Fprintf(os.Stderr, "Warning: could not load %s: %v\n", defaultsFile, err)
		}
	}

	// 3. Load local overrides (highest file priority)
	localFile := filepath.Join(cfg.variablesDir, "_variables.local.sh")
	if _, err := os.Stat(localFile); err == nil {
		if err := engine.LoadVariablesFile(localFile); err != nil {
			return fmt.Errorf("loading local variables: %w", err)
		}
	}

	// 4. Environment variables override everything (handled in engine.buildContext)

	return nil
}

// getEngineVars extracts variables from the engine for display
// This is a bit of a hack since the engine doesn't expose vars directly
func getEngineVars(engine *template.RaymondEngine) map[string]string {
	result := make(map[string]string)

	// Common variable names to check
	commonVars := []string{
		"hostname", "os", "user", "home", "shell",
		"machine_type", "git_name", "git_email", "github_username",
		"workspace", "editor", "ssh_default_identity", "ssh_default_user",
		"github_host", "github_enterprise_host", "github_enterprise_user",
		"aws_profile", "aws_region", "bedrock_profile",
		"enable_nvm", "enable_pyenv", "enable_rbenv", "enable_sdkman",
		"enable_k8s_prompt", "enable_aws_prompt",
	}

	for _, name := range commonVars {
		if val, ok := engine.GetVar(name); ok {
			if s, ok := val.(string); ok && s != "" {
				result[name] = s
			}
		}
	}

	return result
}

// runTemplateCheck validates template syntax
func runTemplateCheck(cmd *cobra.Command, args []string) error {
	cfg, err := getTemplateConfig()
	if err != nil {
		return err
	}

	PrintHeader("Template Syntax Check")

	entries, err := os.ReadDir(cfg.templateDir)
	if err != nil {
		return fmt.Errorf("reading template directory: %w", err)
	}

	engine := template.NewRaymondEngine(cfg.templateDir)
	if err := loadTemplateVariables(engine, cfg); err != nil {
		return fmt.Errorf("loading variables: %w", err)
	}

	errors := 0
	checked := 0

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".tmpl") {
			continue
		}

		checked++
		tmplPath := filepath.Join(cfg.templateDir, entry.Name())

		// Try to render the template
		_, err := engine.RenderFile(tmplPath)
		if err != nil {
			Fail("%s: %v", entry.Name(), err)
			errors++
		} else {
			Pass("%s", entry.Name())
		}
	}

	fmt.Println()
	if errors > 0 {
		Fail("Checked %d templates, %d errors", checked, errors)
		return fmt.Errorf("%d templates have syntax errors", errors)
	}

	Pass("All %d templates valid", checked)
	return nil
}

// runTemplateFilters lists available pipeline filters
func runTemplateFilters(cmd *cobra.Command, args []string) error {
	PrintHeader("Available Template Filters")
	fmt.Println()

	filters := []struct {
		name string
		desc string
		ex   string
	}{
		{"eq", "Equal comparison", "{{#if (eq var \"value\")}}"},
		{"ne", "Not equal comparison", "{{#if (ne var \"value\")}}"},
		{"upper", "Convert to uppercase", "{{ name | upper }}"},
		{"lower", "Convert to lowercase", "{{ name | lower }}"},
		{"capitalize", "Capitalize first letter", "{{ name | capitalize }}"},
		{"trim", "Remove whitespace", "{{ value | trim }}"},
		{"replace", "Replace substring", "{{ path | replace \"/\" \"_\" }}"},
		{"append", "Append string", "{{ name | append \".txt\" }}"},
		{"prepend", "Prepend string", "{{ name | prepend \"prefix_\" }}"},
		{"quote", "Wrap in double quotes", "{{ value | quote }}"},
		{"squote", "Wrap in single quotes", "{{ value | squote }}"},
		{"truncate", "Limit length", "{{ desc | truncate 50 }}"},
		{"length", "Get string length", "{{ items | length }}"},
		{"basename", "Get filename from path", "{{ path | basename }}"},
		{"dirname", "Get directory from path", "{{ path | dirname }}"},
		{"default", "Provide default value", "{{ value | default \"none\" }}"},
	}

	cyan := color.New(color.FgCyan).SprintFunc()
	dim := color.New(color.Faint).SprintFunc()

	for _, f := range filters {
		fmt.Printf("  %s\n", cyan(f.name))
		fmt.Printf("    %s\n", f.desc)
		fmt.Printf("    %s\n\n", dim(f.ex))
	}

	fmt.Printf("Total: %d filters available\n", len(filters))
	return nil
}

// runTemplateEdit opens the local variables file in editor
func runTemplateEdit(cmd *cobra.Command, args []string) error {
	cfg, err := getTemplateConfig()
	if err != nil {
		return err
	}

	localFile := filepath.Join(cfg.variablesDir, "_variables.local.sh")

	if _, err := os.Stat(localFile); os.IsNotExist(err) {
		Fail("Local variables file not found: %s", localFile)
		fmt.Println("Run 'dotfiles template init' first")
		return err
	}

	editor := os.Getenv("EDITOR")
	if editor == "" {
		editor = "vim"
	}

	editorCmd := exec.Command(editor, localFile)
	editorCmd.Stdin = os.Stdin
	editorCmd.Stdout = os.Stdout
	editorCmd.Stderr = os.Stderr

	if err := editorCmd.Run(); err != nil {
		return fmt.Errorf("editor failed: %w", err)
	}

	Pass("Edited: %s", localFile)
	fmt.Println()
	Info("Run 'dotfiles template render' to apply changes")
	return nil
}

// runTemplateArrays manages JSON/shell arrays
func runTemplateArrays(cmd *cobra.Command, args []string) error {
	cfg, err := getTemplateConfig()
	if err != nil {
		return err
	}

	exportJSON, _ := cmd.Flags().GetBool("export-json")
	validate, _ := cmd.Flags().GetBool("validate")

	jsonFile := filepath.Join(cfg.variablesDir, "_arrays.local.json")

	if validate {
		// Validate JSON arrays file
		if _, err := os.Stat(jsonFile); os.IsNotExist(err) {
			Info("No JSON arrays file found: %s", jsonFile)
			return nil
		}

		data, err := os.ReadFile(jsonFile)
		if err != nil {
			Fail("Failed to read arrays file: %v", err)
			return err
		}

		var arrays map[string]interface{}
		if err := json.Unmarshal(data, &arrays); err != nil {
			Fail("Invalid JSON: %v", err)
			return err
		}

		Pass("Valid JSON: %s", jsonFile)
		for key, val := range arrays {
			if arr, ok := val.([]interface{}); ok {
				fmt.Printf("  • %s: %d items\n", key, len(arr))
			}
		}
		return nil
	}

	if exportJSON {
		// Export shell arrays to JSON format
		Info("Shell array export not implemented in Go CLI")
		fmt.Println("Use: dotfiles template arrays --export-json (bash version)")
		return nil
	}

	// Default: list arrays
	PrintHeader("Template Arrays")

	if _, err := os.Stat(jsonFile); os.IsNotExist(err) {
		Info("No JSON arrays file found")
		fmt.Println()
		fmt.Println("Create one at:")
		fmt.Printf("  %s\n", jsonFile)
		return nil
	}

	data, err := os.ReadFile(jsonFile)
	if err != nil {
		return err
	}

	var arrays map[string]interface{}
	if err := json.Unmarshal(data, &arrays); err != nil {
		Fail("Invalid JSON: %v", err)
		return err
	}

	fmt.Printf("Source: %s\n\n", jsonFile)
	for key, val := range arrays {
		if arr, ok := val.([]interface{}); ok {
			fmt.Printf("%s (%d items):\n", key, len(arr))
			for i, item := range arr {
				if i >= 5 {
					fmt.Printf("  ... and %d more\n", len(arr)-5)
					break
				}
				itemJSON, _ := json.Marshal(item)
				fmt.Printf("  [%d] %s\n", i, string(itemJSON))
			}
			fmt.Println()
		}
	}

	return nil
}

// runTemplateInit runs interactive template setup
func runTemplateInit(cmd *cobra.Command, args []string) error {
	cfg, err := getTemplateConfig()
	if err != nil {
		return err
	}

	PrintHeader("Template System Setup")

	localFile := filepath.Join(cfg.variablesDir, "_variables.local.sh")

	// Check if already exists
	if _, err := os.Stat(localFile); err == nil {
		Warn("Local variables file already exists: %s", localFile)
		fmt.Println("Edit it with: dotfiles template edit")
		return nil
	}

	// Auto-detect values
	hostname, _ := os.Hostname()
	user := os.Getenv("USER")
	osName := "linux"
	if runtime.GOOS == "darwin" {
		osName = "macos"
	}

	// Try to get git config
	gitName := ""
	gitEmail := ""
	if out, err := exec.Command("git", "config", "--global", "user.name").Output(); err == nil {
		gitName = strings.TrimSpace(string(out))
	}
	if out, err := exec.Command("git", "config", "--global", "user.email").Output(); err == nil {
		gitEmail = strings.TrimSpace(string(out))
	}

	fmt.Println()
	fmt.Println("Detected System:")
	fmt.Printf("  %-15s %s\n", "Hostname:", hostname)
	fmt.Printf("  %-15s %s\n", "OS:", osName)
	fmt.Printf("  %-15s %s\n", "User:", user)
	if gitName != "" {
		fmt.Printf("  %-15s %s\n", "Git name:", gitName)
	}
	if gitEmail != "" {
		fmt.Printf("  %-15s %s\n", "Git email:", gitEmail)
	}
	fmt.Println()

	// Create template for local variables file
	content := fmt.Sprintf(`#!/usr/bin/env zsh
# ============================================================
# FILE: templates/_variables.local.sh
# Machine-specific template variable overrides
#
# Generated by: dotfiles template init
# Generated on: %s
#
# Edit this file to customize your configuration.
# Run 'dotfiles template render' after making changes.
# ============================================================

# ============================================================
# Git Configuration (required)
# ============================================================
TMPL_DEFAULTS[git_name]="%s"
TMPL_DEFAULTS[git_email]="%s"

# ============================================================
# Machine Type
# Values: work, personal, unknown
# ============================================================
TMPL_AUTO[machine_type]="unknown"

# ============================================================
# Advanced Configuration
# Uncomment and customize as needed
# ============================================================
# TMPL_DEFAULTS[aws_profile]="default"
# TMPL_DEFAULTS[editor]="nvim"
# TMPL_DEFAULTS[enable_nvm]="true"
`, time.Now().Format("2006-01-02 15:04:05"), gitName, gitEmail)

	os.MkdirAll(cfg.variablesDir, 0755)
	if err := os.WriteFile(localFile, []byte(content), 0644); err != nil {
		Fail("Failed to create local variables file: %v", err)
		return err
	}

	Pass("Created: %s", localFile)
	fmt.Println()
	fmt.Println("Next steps:")
	fmt.Println("  1. dotfiles template edit    - Customize variables")
	fmt.Println("  2. dotfiles template vars    - Review all variables")
	fmt.Println("  3. dotfiles template render  - Generate config files")

	return nil
}

// runTemplateLink creates symlinks from generated files to destinations
func runTemplateLink(cmd *cobra.Command, args []string) error {
	cfg, err := getTemplateConfig()
	if err != nil {
		return err
	}

	PrintHeader("Linking Generated Files")

	// Define destinations for generated files
	home := os.Getenv("HOME")
	linkMap := map[string]string{
		"gitconfig":    filepath.Join(home, ".gitconfig"),
		"99-local.zsh": filepath.Join(cfg.dotfilesDir, "zsh", "zsh.d", "99-local.zsh"),
		"ssh-config":   filepath.Join(home, ".ssh", "config"),
		"claude.local": filepath.Join(home, ".claude.local"),
	}

	linked := 0
	for file, dest := range linkMap {
		src := filepath.Join(cfg.generatedDir, file)

		if _, err := os.Stat(src); os.IsNotExist(err) {
			continue
		}

		// Create parent directory
		os.MkdirAll(filepath.Dir(dest), 0755)

		// Check existing file
		if info, err := os.Lstat(dest); err == nil {
			if info.Mode()&os.ModeSymlink != 0 {
				// Remove existing symlink
				os.Remove(dest)
			} else {
				// Backup existing file
				backup := dest + ".backup." + time.Now().Format("20060102150405")
				os.Rename(dest, backup)
				Info("Backed up: %s", backup)
			}
		}

		// Create symlink
		if err := os.Symlink(src, dest); err != nil {
			Fail("Failed to link %s: %v", file, err)
			continue
		}

		Pass("Linked: %s → %s", file, dest)
		linked++
	}

	if linked == 0 {
		Info("No files to link (run 'dotfiles template render' first)")
	} else {
		fmt.Printf("\nLinked %d file(s)\n", linked)
	}

	return nil
}

// runTemplateDiff shows differences from rendered templates
func runTemplateDiff(cmd *cobra.Command, args []string) error {
	cfg, err := getTemplateConfig()
	if err != nil {
		return err
	}

	PrintHeader("Template Differences")

	entries, err := os.ReadDir(cfg.templateDir)
	if err != nil {
		return fmt.Errorf("reading template directory: %w", err)
	}

	engine := template.NewRaymondEngine(cfg.templateDir)
	if err := loadTemplateVariables(engine, cfg); err != nil {
		return fmt.Errorf("loading variables: %w", err)
	}

	hasDiff := false
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".tmpl") {
			continue
		}

		tmplPath := filepath.Join(cfg.templateDir, entry.Name())
		outputName := strings.TrimSuffix(entry.Name(), ".tmpl")
		outputPath := filepath.Join(cfg.generatedDir, outputName)

		// Render template
		newContent, err := engine.RenderFile(tmplPath)
		if err != nil {
			Warn("%s: render failed: %v", entry.Name(), err)
			continue
		}

		// Check if generated file exists
		if _, err := os.Stat(outputPath); os.IsNotExist(err) {
			fmt.Printf("  %s: not generated\n", outputName)
			hasDiff = true
			continue
		}

		// Read existing content
		existingContent, err := os.ReadFile(outputPath)
		if err != nil {
			Warn("%s: read failed: %v", outputName, err)
			continue
		}

		if string(existingContent) != newContent {
			fmt.Printf("  %s: differs from template\n", outputName)
			hasDiff = true
		}
	}

	if !hasDiff {
		Pass("All generated files are up to date")
	}

	return nil
}

// Template vault item name
const templateVaultItemName = "Template-Variables"

// runTemplateVaultPush pushes local variables to vault
func runTemplateVaultPush(cmd *cobra.Command, args []string) error {
	cfg, err := getTemplateConfig()
	if err != nil {
		return err
	}

	localFile := filepath.Join(cfg.variablesDir, "_variables.local.sh")

	if _, err := os.Stat(localFile); os.IsNotExist(err) {
		Fail("Local variables file not found: %s", localFile)
		fmt.Println("Run 'dotfiles template init' first")
		return err
	}

	Info("Pushing template variables to vault...")

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	backend, err := newVaultBackend()
	if err != nil {
		Fail("Failed to create vault backend: %v", err)
		return err
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		Fail("Vault backend not available: %v", err)
		return err
	}

	session, err := backend.Authenticate(ctx)
	if err != nil {
		Fail("Authentication required: %v", err)
		return err
	}

	// Read local content
	localContent, err := os.ReadFile(localFile)
	if err != nil {
		Fail("Failed to read local file: %v", err)
		return err
	}

	// Check if item exists
	vaultContent, err := backend.GetNotes(ctx, templateVaultItemName, session)
	if err == nil && vaultContent == string(localContent) {
		Info("Vault already up to date")
		return nil
	}

	// Create or update
	if err != nil {
		// Create new
		if err := backend.CreateItem(ctx, templateVaultItemName, string(localContent), session); err != nil {
			Fail("Failed to create vault item: %v", err)
			return err
		}
		Pass("Created '%s' in vault", templateVaultItemName)
	} else {
		// Update existing
		if err := backend.UpdateItem(ctx, templateVaultItemName, string(localContent), session); err != nil {
			Fail("Failed to update vault item: %v", err)
			return err
		}
		Pass("Updated '%s' in vault", templateVaultItemName)
	}

	return nil
}

// runTemplateVaultPull pulls variables from vault to local
func runTemplateVaultPull(cmd *cobra.Command, args []string) error {
	cfg, err := getTemplateConfig()
	if err != nil {
		return err
	}

	Info("Pulling template variables from vault...")

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	backend, err := newVaultBackend()
	if err != nil {
		Fail("Failed to create vault backend: %v", err)
		return err
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		Fail("Vault backend not available: %v", err)
		return err
	}

	session, err := backend.Authenticate(ctx)
	if err != nil {
		Fail("Authentication required: %v", err)
		return err
	}

	// Get vault content
	vaultContent, err := backend.GetNotes(ctx, templateVaultItemName, session)
	if err != nil {
		Fail("Item '%s' not found in vault", templateVaultItemName)
		fmt.Println("Push with: dotfiles template vault push")
		return err
	}

	if vaultContent == "" {
		Fail("Vault item is empty")
		return fmt.Errorf("empty vault item")
	}

	localFile := filepath.Join(cfg.variablesDir, "_variables.local.sh")

	// Backup if exists
	if _, err := os.Stat(localFile); err == nil {
		backup := localFile + ".backup." + time.Now().Format("20060102150405")
		os.Rename(localFile, backup)
		Info("Backed up: %s", backup)
	}

	// Write vault content
	os.MkdirAll(cfg.variablesDir, 0755)
	if err := os.WriteFile(localFile, []byte(vaultContent), 0600); err != nil {
		Fail("Failed to write local file: %v", err)
		return err
	}

	Pass("Pulled '%s' from vault", templateVaultItemName)
	fmt.Printf("  → %s\n", localFile)
	return nil
}

// runTemplateVaultDiff shows differences between local and vault
func runTemplateVaultDiff(cmd *cobra.Command, args []string) error {
	cfg, err := getTemplateConfig()
	if err != nil {
		return err
	}

	Info("Comparing local and vault...")

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	localFile := filepath.Join(cfg.variablesDir, "_variables.local.sh")

	// Get local content
	var localContent string
	localExists := false
	if data, err := os.ReadFile(localFile); err == nil {
		localContent = string(data)
		localExists = true
	}

	// Get vault content
	var vaultContent string
	vaultExists := false

	backend, err := newVaultBackend()
	if err == nil {
		defer backend.Close()
		if err := backend.Init(ctx); err == nil {
			if session, err := backend.Authenticate(ctx); err == nil {
				if content, err := backend.GetNotes(ctx, templateVaultItemName, session); err == nil {
					vaultContent = content
					vaultExists = true
				}
			}
		}
	}

	// Compare
	if !localExists && !vaultExists {
		Info("Neither local file nor vault item exists")
		return nil
	}

	if !localExists {
		fmt.Println("Vault has content, local file missing")
		fmt.Println("Run: dotfiles template vault pull")
		return nil
	}

	if !vaultExists {
		fmt.Println("Local file exists, vault item missing")
		fmt.Println("Run: dotfiles template vault push")
		return nil
	}

	if localContent == vaultContent {
		Pass("Local and vault are in sync")
		return nil
	}

	// Show diff
	PrintHeader("Differences (local vs vault)")

	// Simple line-by-line diff
	localLines := strings.Split(localContent, "\n")
	vaultLines := strings.Split(vaultContent, "\n")

	maxLines := len(localLines)
	if len(vaultLines) > maxLines {
		maxLines = len(vaultLines)
	}

	for i := 0; i < maxLines; i++ {
		local := ""
		vault := ""
		if i < len(localLines) {
			local = localLines[i]
		}
		if i < len(vaultLines) {
			vault = vaultLines[i]
		}

		if local != vault {
			if local != "" {
				fmt.Printf("- %s\n", local)
			}
			if vault != "" {
				fmt.Printf("+ %s\n", vault)
			}
		}
	}

	fmt.Println()
	fmt.Println("To update vault:  dotfiles template vault push --force")
	fmt.Println("To update local:  dotfiles template vault pull --force")

	return nil
}

// runTemplateVaultSync performs bidirectional sync
func runTemplateVaultSync(cmd *cobra.Command, args []string) error {
	cfg, err := getTemplateConfig()
	if err != nil {
		return err
	}

	Info("Syncing template variables...")

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	localFile := filepath.Join(cfg.variablesDir, "_variables.local.sh")

	// Check local
	localExists := false
	var localContent string
	if data, err := os.ReadFile(localFile); err == nil {
		localExists = true
		localContent = string(data)
	}

	// Check vault
	vaultExists := false
	var vaultContent string

	backend, err := newVaultBackend()
	if err != nil {
		Fail("Failed to create vault backend: %v", err)
		return err
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		Fail("Vault backend not available: %v", err)
		return err
	}

	session, err := backend.Authenticate(ctx)
	if err != nil {
		Fail("Authentication required: %v", err)
		return err
	}

	if content, err := backend.GetNotes(ctx, templateVaultItemName, session); err == nil {
		vaultExists = true
		vaultContent = content
	}

	// Sync logic
	if !localExists && !vaultExists {
		Info("Neither local file nor vault item exists")
		fmt.Println("Run: dotfiles template init")
		return nil
	}

	if !localExists {
		Info("Local file missing, pulling from vault...")
		return runTemplateVaultPull(cmd, args)
	}

	if !vaultExists {
		Info("Vault item missing, pushing to vault...")
		return runTemplateVaultPush(cmd, args)
	}

	if localContent == vaultContent {
		Pass("Already in sync")
		return nil
	}

	Warn("Conflict detected: local and vault differ")
	fmt.Println()
	fmt.Println("To resolve:")
	fmt.Println("  dotfiles template vault push  - Use local (push to vault)")
	fmt.Println("  dotfiles template vault pull  - Use vault (pull to local)")
	fmt.Println("  dotfiles template vault diff  - See differences")

	return fmt.Errorf("conflict detected")
}

// runTemplateVaultStatus shows vault sync status
func runTemplateVaultStatus(cmd *cobra.Command, args []string) error {
	cfg, err := getTemplateConfig()
	if err != nil {
		return err
	}

	PrintHeader("Template Vault Status")

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	backendType := getVaultBackend()
	fmt.Printf("  %-20s %s\n", "Vault backend:", backendType)
	fmt.Printf("  %-20s %s\n", "Vault item:", templateVaultItemName)
	fmt.Println()

	localFile := filepath.Join(cfg.variablesDir, "_variables.local.sh")

	// Check local
	fmt.Println("Local:")
	if info, err := os.Stat(localFile); err == nil {
		fmt.Printf("  %-20s %s (%d bytes)\n", "File:", Green.Sprint("exists"), info.Size())
		fmt.Printf("  %-20s %s\n", "Path:", localFile)
		fmt.Printf("  %-20s %s\n", "Modified:", info.ModTime().Format("2006-01-02 15:04:05"))
	} else {
		fmt.Printf("  %-20s %s\n", "File:", Yellow.Sprint("missing"))
	}

	// Check vault
	fmt.Println()
	fmt.Println("Vault:")

	backend, err := newVaultBackend()
	if err != nil {
		fmt.Printf("  %-20s %s\n", "Status:", Red.Sprint("backend unavailable"))
		return nil
	}
	defer backend.Close()

	if err := backend.Init(ctx); err != nil {
		fmt.Printf("  %-20s %s\n", "Status:", Red.Sprint("CLI not installed"))
		return nil
	}

	session, err := backend.Authenticate(ctx)
	if err != nil {
		fmt.Printf("  %-20s %s\n", "Status:", Yellow.Sprint("not authenticated"))
		return nil
	}

	vaultContent, err := backend.GetNotes(ctx, templateVaultItemName, session)
	if err != nil {
		fmt.Printf("  %-20s %s\n", "Item:", Yellow.Sprint("missing"))
	} else {
		fmt.Printf("  %-20s %s (%d bytes)\n", "Item:", Green.Sprint("exists"), len(vaultContent))
	}

	// Sync status
	fmt.Println()
	fmt.Println("Sync Status:")

	localContent, localErr := os.ReadFile(localFile)
	if localErr != nil && err != nil {
		fmt.Printf("  %-20s %s\n", "Status:", Yellow.Sprint("no data"))
		fmt.Println("  Run: dotfiles template init")
	} else if localErr != nil {
		fmt.Printf("  %-20s %s\n", "Status:", Yellow.Sprint("local missing"))
		fmt.Println("  Run: dotfiles template vault pull")
	} else if err != nil {
		fmt.Printf("  %-20s %s\n", "Status:", Yellow.Sprint("vault missing"))
		fmt.Println("  Run: dotfiles template vault push")
	} else if string(localContent) == vaultContent {
		fmt.Printf("  %-20s %s\n", "Status:", Green.Sprint("in sync"))
	} else {
		fmt.Printf("  %-20s %s\n", "Status:", Yellow.Sprint("out of sync"))
		fmt.Println("  Run: dotfiles template vault diff")
	}

	return nil
}
