package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/blackwell-systems/dotfiles/internal/template"
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
	dotfilesDir := os.Getenv("DOTFILES_DIR")
	if dotfilesDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return nil, fmt.Errorf("cannot determine home directory: %w", err)
		}
		dotfilesDir = filepath.Join(home, ".dotfiles")
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
  dotfiles-go template render                    # Render all templates
  dotfiles-go template render gitconfig.tmpl     # Render specific template
  dotfiles-go template render --stdout file.tmpl # Output to stdout`,
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

	cmd.AddCommand(
		renderCmd,
		varsCmd,
		listCmd,
		&cobra.Command{
			Use:   "init",
			Short: "Interactive setup (creates _variables.local.sh)",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Template Init")
				fmt.Println("Use: dotfiles template init (bash version)")
				fmt.Println("Go implementation coming soon")
			},
		},
		&cobra.Command{
			Use:   "link",
			Short: "Create symlinks from generated/ to destinations",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Creating symlinks...")
				fmt.Println("Use: dotfiles template link (bash version)")
			},
		},
		&cobra.Command{
			Use:   "diff",
			Short: "Show differences from rendered",
			Run: func(cmd *cobra.Command, args []string) {
				fmt.Println("Template Diff")
				fmt.Println("Use: dotfiles template diff (bash version)")
			},
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
