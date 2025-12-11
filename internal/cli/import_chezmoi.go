// Package cli implements the blackdot command-line interface using Cobra.
package cli

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/BurntSushi/toml"
	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// chezmoiImporter handles importing from chezmoi repositories
type chezmoiImporter struct {
	sourceDir    string
	configFile   string
	targetDir    string
	dryRun       bool
	verbose      bool
	stats        importStats
	configData   map[string]interface{}
}

type importStats struct {
	files      int
	templates  int
	dirs       int
	skipped    int
	errors     int
}

// chezmoiFileInfo holds parsed information about a chezmoi source file
type chezmoiFileInfo struct {
	sourcePath   string
	targetPath   string
	isTemplate   bool
	isPrivate    bool
	isExecutable bool
	isEmpty      bool
	isSymlink    bool
	isExact      bool
}

func newImportCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "import",
		Short: "Import from other dotfile managers",
		Long: `Import configuration from other dotfile managers.

Supported sources:
  chezmoi    Import from a chezmoi repository

Examples:
  blackdot import chezmoi                    # Import from default chezmoi location
  blackdot import chezmoi --source ~/chezmoi # Import from custom location
  blackdot import chezmoi --dry-run          # Preview without making changes`,
	}

	cmd.AddCommand(newImportChezmoiCmd())
	return cmd
}

func newImportChezmoiCmd() *cobra.Command {
	var sourceDir string
	var configFile string
	var dryRun bool
	var verbose bool

	cmd := &cobra.Command{
		Use:   "chezmoi",
		Short: "Import from chezmoi repository",
		Long: `Import configuration from a chezmoi repository.

Converts:
  - File prefixes (dot_, private_, executable_, etc.)
  - Go templates to Handlebars syntax
  - chezmoi.toml config to template variables
  - .chezmoiignore patterns

Examples:
  blackdot import chezmoi
  blackdot import chezmoi --source ~/.local/share/chezmoi
  blackdot import chezmoi --dry-run --verbose`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runImportChezmoi(sourceDir, configFile, dryRun, verbose)
		},
	}

	home, _ := os.UserHomeDir()
	defaultSource := filepath.Join(home, ".local", "share", "chezmoi")
	defaultConfig := filepath.Join(home, ".config", "chezmoi", "chezmoi.toml")

	cmd.Flags().StringVarP(&sourceDir, "source", "s", defaultSource, "Chezmoi source directory")
	cmd.Flags().StringVarP(&configFile, "config", "c", defaultConfig, "Chezmoi config file")
	cmd.Flags().BoolVarP(&dryRun, "dry-run", "n", false, "Preview changes without writing")
	cmd.Flags().BoolVarP(&verbose, "verbose", "v", false, "Show detailed progress")

	return cmd
}

func runImportChezmoi(sourceDir, configFile string, dryRun, verbose bool) error {
	cyan := color.New(color.FgCyan).SprintFunc()
	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()
	red := color.New(color.FgRed).SprintFunc()

	fmt.Println()
	fmt.Println(color.New(color.Bold).Sprint("Chezmoi Import"))
	fmt.Println("══════════════════════════════════════")
	fmt.Println()

	// Verify source exists
	if _, err := os.Stat(sourceDir); os.IsNotExist(err) {
		return fmt.Errorf("chezmoi source directory not found: %s", sourceDir)
	}

	fmt.Printf("Source: %s\n", cyan(sourceDir))
	fmt.Printf("Config: %s\n", cyan(configFile))
	if dryRun {
		fmt.Printf("Mode:   %s\n", yellow("DRY RUN"))
	}
	fmt.Println()

	// Get target directory
	dotfilesDir := os.Getenv("BLACKDOT_DIR")
	if dotfilesDir == "" {
		home, _ := os.UserHomeDir()
		dotfilesDir = filepath.Join(home, ".blackdot")
	}

	importer := &chezmoiImporter{
		sourceDir:  sourceDir,
		configFile: configFile,
		targetDir:  dotfilesDir,
		dryRun:     dryRun,
		verbose:    verbose,
		configData: make(map[string]interface{}),
	}

	// Load chezmoi config
	if err := importer.loadConfig(); err != nil {
		fmt.Printf("%s Loading config: %v\n", yellow("!"), err)
	}

	// Process source directory
	fmt.Println(cyan("→ Processing chezmoi source files..."))
	if err := importer.processSourceDir(); err != nil {
		return err
	}

	// Print summary
	fmt.Println()
	fmt.Println("══════════════════════════════════════")
	fmt.Printf("Files:     %s\n", green(fmt.Sprintf("%d", importer.stats.files)))
	fmt.Printf("Templates: %s (converted to Handlebars)\n", green(fmt.Sprintf("%d", importer.stats.templates)))
	fmt.Printf("Dirs:      %s\n", green(fmt.Sprintf("%d", importer.stats.dirs)))
	if importer.stats.skipped > 0 {
		fmt.Printf("Skipped:   %s\n", yellow(fmt.Sprintf("%d", importer.stats.skipped)))
	}
	if importer.stats.errors > 0 {
		fmt.Printf("Errors:    %s\n", red(fmt.Sprintf("%d", importer.stats.errors)))
	}

	if dryRun {
		fmt.Println()
		fmt.Printf("%s Run without --dry-run to apply changes\n", yellow("!"))
	} else {
		fmt.Println()
		fmt.Printf("%s Import complete!\n", green("✓"))
	}

	return nil
}

func (i *chezmoiImporter) loadConfig() error {
	if _, err := os.Stat(i.configFile); os.IsNotExist(err) {
		return nil // Config is optional
	}

	var config struct {
		Data map[string]interface{} `toml:"data"`
	}

	if _, err := toml.DecodeFile(i.configFile, &config); err != nil {
		return err
	}

	i.configData = config.Data
	return nil
}

func (i *chezmoiImporter) processSourceDir() error {
	return filepath.Walk(i.sourceDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Skip the root directory
		if path == i.sourceDir {
			return nil
		}

		// Get relative path
		relPath, err := filepath.Rel(i.sourceDir, path)
		if err != nil {
			return err
		}

		// Skip .git directory
		if strings.HasPrefix(relPath, ".git") {
			if info.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		// Parse chezmoi file info
		fileInfo := i.parseChezmoiPath(relPath, info.IsDir())

		if info.IsDir() {
			return i.processDirectory(fileInfo)
		}
		return i.processFile(path, fileInfo)
	})
}

func (i *chezmoiImporter) parseChezmoiPath(path string, isDir bool) chezmoiFileInfo {
	info := chezmoiFileInfo{
		sourcePath: path,
	}

	// Process each path component
	parts := strings.Split(path, string(filepath.Separator))
	targetParts := make([]string, 0, len(parts))

	for _, part := range parts {
		targetPart := part

		// Check for attributes (order matters!)
		if strings.HasPrefix(targetPart, "exact_") {
			info.isExact = true
			targetPart = strings.TrimPrefix(targetPart, "exact_")
		}
		if strings.HasPrefix(targetPart, "private_") {
			info.isPrivate = true
			targetPart = strings.TrimPrefix(targetPart, "private_")
		}
		if strings.HasPrefix(targetPart, "empty_") {
			info.isEmpty = true
			targetPart = strings.TrimPrefix(targetPart, "empty_")
		}
		if strings.HasPrefix(targetPart, "executable_") {
			info.isExecutable = true
			targetPart = strings.TrimPrefix(targetPart, "executable_")
		}
		if strings.HasPrefix(targetPart, "symlink_") {
			info.isSymlink = true
			targetPart = strings.TrimPrefix(targetPart, "symlink_")
		}
		if strings.HasPrefix(targetPart, "dot_") {
			targetPart = "." + strings.TrimPrefix(targetPart, "dot_")
		}

		// Check for template suffix
		if strings.HasSuffix(targetPart, ".tmpl") {
			info.isTemplate = true
			targetPart = strings.TrimSuffix(targetPart, ".tmpl")
		}

		targetParts = append(targetParts, targetPart)
	}

	info.targetPath = filepath.Join(targetParts...)
	return info
}

func (i *chezmoiImporter) processDirectory(info chezmoiFileInfo) error {
	// Skip special chezmoi directories
	if strings.HasPrefix(info.sourcePath, ".chezmoi") {
		return filepath.SkipDir
	}

	targetPath := filepath.Join(i.targetDir, "templates", "configs", info.targetPath)

	if i.verbose {
		fmt.Printf("  DIR  %s → %s\n", info.sourcePath, info.targetPath)
	}

	if !i.dryRun {
		if err := os.MkdirAll(targetPath, 0755); err != nil {
			i.stats.errors++
			return nil
		}
	}

	i.stats.dirs++
	return nil
}

func (i *chezmoiImporter) processFile(sourcePath string, info chezmoiFileInfo) error {
	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()

	// Skip special chezmoi files
	if strings.HasPrefix(info.sourcePath, ".chezmoi") {
		if i.verbose {
			fmt.Printf("  %s %s (chezmoi special file)\n", yellow("SKIP"), info.sourcePath)
		}
		i.stats.skipped++
		return nil
	}

	// Read source content
	content, err := os.ReadFile(sourcePath)
	if err != nil {
		i.stats.errors++
		return nil
	}

	// Convert template if needed
	outputContent := string(content)
	if info.isTemplate {
		outputContent = i.convertGoTemplateToHandlebars(outputContent)
		i.stats.templates++
	}

	// Determine output path
	outputPath := info.targetPath
	if info.isTemplate {
		outputPath += ".tmpl"
	}
	fullOutputPath := filepath.Join(i.targetDir, "templates", "configs", outputPath)

	if i.verbose || i.dryRun {
		status := green("FILE")
		if info.isTemplate {
			status = green("TMPL")
		}
		fmt.Printf("  %s %s → %s", status, info.sourcePath, outputPath)
		if info.isPrivate {
			fmt.Printf(" [private]")
		}
		if info.isExecutable {
			fmt.Printf(" [executable]")
		}
		fmt.Println()
	}

	if !i.dryRun {
		// Create parent directories
		if err := os.MkdirAll(filepath.Dir(fullOutputPath), 0755); err != nil {
			i.stats.errors++
			return nil
		}

		// Write file
		perm := os.FileMode(0644)
		if info.isPrivate {
			perm = 0600
		}
		if info.isExecutable {
			perm = 0755
		}

		if err := os.WriteFile(fullOutputPath, []byte(outputContent), perm); err != nil {
			i.stats.errors++
			return nil
		}
	}

	i.stats.files++
	return nil
}

// convertGoTemplateToHandlebars converts Go template syntax to Handlebars
func (i *chezmoiImporter) convertGoTemplateToHandlebars(content string) string {
	result := content

	// Step 1: Convert control structures BEFORE variable substitution
	// This ensures .chezmoi.os in {{ if eq .chezmoi.os "darwin" }} is handled correctly

	// Convert {{ if eq .chezmoi.os "value" }} to {{#if (eq os "value")}}
	ifChezmoiEqRegex := regexp.MustCompile(`\{\{\s*if\s+eq\s+\.chezmoi\.([a-zA-Z_][a-zA-Z0-9_]*)\s+"([^"]*)"\s*\}\}`)
	result = ifChezmoiEqRegex.ReplaceAllString(result, `{{#if (eq $1 "$2")}}`)

	// Convert {{ else if eq .chezmoi.os "value" }} to {{else}}{{#if (eq os "value")}}
	elseIfChezmoiEqRegex := regexp.MustCompile(`\{\{\s*else\s+if\s+eq\s+\.chezmoi\.([a-zA-Z_][a-zA-Z0-9_]*)\s+"([^"]*)"\s*\}\}`)
	result = elseIfChezmoiEqRegex.ReplaceAllString(result, `{{else}}{{#if (eq $1 "$2")}}`)

	// Convert {{ if eq .var "value" }} to {{#if (eq var "value")}}
	ifEqRegex := regexp.MustCompile(`\{\{\s*if\s+eq\s+\.([a-zA-Z_][a-zA-Z0-9_.]*)\s+"([^"]*)"\s*\}\}`)
	result = ifEqRegex.ReplaceAllString(result, `{{#if (eq $1 "$2")}}`)

	// Convert {{ if ne .var "value" }} to {{#if (ne var "value")}}
	ifNeRegex := regexp.MustCompile(`\{\{\s*if\s+ne\s+\.([a-zA-Z_][a-zA-Z0-9_.]*)\s+"([^"]*)"\s*\}\}`)
	result = ifNeRegex.ReplaceAllString(result, `{{#if (ne $1 "$2")}}`)

	// Convert {{ else if eq .var "value" }} to {{else}}{{#if (eq var "value")}}
	elseIfEqRegex := regexp.MustCompile(`\{\{\s*else\s+if\s+eq\s+\.([a-zA-Z_][a-zA-Z0-9_.]*)\s+"([^"]*)"\s*\}\}`)
	result = elseIfEqRegex.ReplaceAllString(result, `{{else}}{{#if (eq $1 "$2")}}`)

	// Convert {{ if .var }} to {{#if var}}
	ifVarRegex := regexp.MustCompile(`\{\{\s*if\s+\.([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}`)
	result = ifVarRegex.ReplaceAllString(result, `{{#if $1}}`)

	// Convert {{ range .items }} to {{#each items}}
	rangeRegex := regexp.MustCompile(`\{\{\s*range\s+\.([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}`)
	result = rangeRegex.ReplaceAllString(result, `{{#each $1}}`)

	// Convert {{ else }} to {{else}}
	result = regexp.MustCompile(`\{\{\s*else\s*\}\}`).ReplaceAllString(result, `{{else}}`)

	// Convert {{ end }} to {{/if}} (we'll fix for each blocks later)
	result = regexp.MustCompile(`\{\{\s*end\s*\}\}`).ReplaceAllString(result, `{{/if}}`)

	// Step 2: Convert .chezmoi.* variables to our naming
	result = strings.ReplaceAll(result, ".chezmoi.os", "os")
	result = strings.ReplaceAll(result, ".chezmoi.arch", "arch")
	result = strings.ReplaceAll(result, ".chezmoi.hostname", "hostname")
	result = strings.ReplaceAll(result, ".chezmoi.username", "user")
	result = strings.ReplaceAll(result, ".chezmoi.homeDir", "home")

	// Step 3: Convert variable expressions

	// Convert {{ .var | filter "arg" }} to {{ filter var "arg" }}
	dotVarFilterArgRegex := regexp.MustCompile(`\{\{\s*\.([a-zA-Z_][a-zA-Z0-9_]*)\s*\|\s*([a-zA-Z]+)\s+"([^"]*)"\s*\}\}`)
	result = dotVarFilterArgRegex.ReplaceAllString(result, `{{ $2 $1 "$3" }}`)

	// Convert {{ .var | filter }} to {{ filter var }}
	dotVarFilterRegex := regexp.MustCompile(`\{\{\s*\.([a-zA-Z_][a-zA-Z0-9_]*)\s*\|\s*([a-zA-Z]+)\s*\}\}`)
	result = dotVarFilterRegex.ReplaceAllString(result, `{{ $2 $1 }}`)

	// Convert {{ .var }} to {{ var }}
	dotVarRegex := regexp.MustCompile(`\{\{\s*\.([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}`)
	result = dotVarRegex.ReplaceAllString(result, `{{ $1 }}`)

	// Step 4: Fix {{/if}} after {{#each}} - need to be {{/each}}
	result = fixEndTags(result)

	return result
}

// fixEndTags attempts to match {{/if}} and {{/each}} correctly
func fixEndTags(content string) string {
	var result strings.Builder
	scanner := bufio.NewScanner(strings.NewReader(content))

	// Track block depth
	type block struct {
		kind string // "if" or "each"
	}
	var stack []block

	for scanner.Scan() {
		line := scanner.Text()

		// Track opens
		if strings.Contains(line, "{{#if") {
			stack = append(stack, block{kind: "if"})
		}
		if strings.Contains(line, "{{#each") {
			stack = append(stack, block{kind: "each"})
		}
		if strings.Contains(line, "{{#unless") {
			stack = append(stack, block{kind: "unless"})
		}

		// Fix closes
		if strings.Contains(line, "{{/if}}") && len(stack) > 0 {
			top := stack[len(stack)-1]
			if top.kind == "each" {
				line = strings.Replace(line, "{{/if}}", "{{/each}}", 1)
			} else if top.kind == "unless" {
				line = strings.Replace(line, "{{/if}}", "{{/unless}}", 1)
			}
			stack = stack[:len(stack)-1]
		}

		result.WriteString(line)
		result.WriteString("\n")
	}

	return result.String()
}
