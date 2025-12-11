// Package cli implements the dotfiles command-line interface using Cobra.
package cli

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// Claude configuration (matches ZSH defaults in 70-claude.zsh)
type claudeConfig struct {
	BedrockProfile   string
	BedrockRegion    string
	BedrockModel     string
	BedrockFastModel string
	MaxOutputTokens  string
}

func getClaudeConfig() claudeConfig {
	return claudeConfig{
		BedrockProfile:   os.Getenv("CLAUDE_BEDROCK_PROFILE"),
		BedrockRegion:    getEnvDefault("CLAUDE_BEDROCK_REGION", "us-west-2"),
		BedrockModel:     getEnvDefault("CLAUDE_BEDROCK_MODEL", "us.anthropic.claude-sonnet-4-5-20250929-v1:0"),
		BedrockFastModel: getEnvDefault("CLAUDE_BEDROCK_FAST_MODEL", "us.anthropic.claude-3-5-haiku-20241022-v1:0"),
		MaxOutputTokens:  getEnvDefault("CLAUDE_CODE_MAX_OUTPUT_TOKENS", "60000"),
	}
}

func getEnvDefault(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

// newToolsClaudeCmd creates the claude tools subcommand
func newToolsClaudeCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "claude",
		Short: "Claude Code configuration and backend management",
		Long: `Claude Code configuration and backend management tools.

Cross-platform utilities for managing Claude Code settings,
AWS Bedrock integration, and backend routing.

Commands:
  status    - Show current Claude Code configuration
  bedrock   - Print export commands for AWS Bedrock backend
  max       - Print export commands for Anthropic Max backend
  switch    - Interactive backend switcher
  init      - Initialize Claude Code hooks and commands
  env       - Show environment variables for Claude Code`,
	}

	cmd.AddCommand(
		newClaudeStatusCmd(),
		newClaudeBedrockCmd(),
		newClaudeMaxCmd(),
		newClaudeSwitchCmd(),
		newClaudeInitCmd(),
		newClaudeEnvCmd(),
	)

	return cmd
}

// newClaudeStatusCmd shows Claude configuration
func newClaudeStatusCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show current Claude Code configuration",
		Long:  `Display the current Claude Code configuration including Bedrock settings and SSO status.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runClaudeStatus()
		},
	}
}

func runClaudeStatus() error {
	cfg := getClaudeConfig()

	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()
	cyan := color.New(color.FgCyan).SprintFunc()
	dim := color.New(color.Faint).SprintFunc()

	fmt.Println(cyan("Claude Code Configuration"))
	fmt.Println(cyan("========================="))
	fmt.Println()

	// Check for portable sessions
	workspaceExists := false
	if _, err := os.Stat("/workspace"); err == nil {
		workspaceExists = true
	}
	if workspaceExists {
		fmt.Printf("Session portability: %s\n", green("enabled (/workspace exists)"))
	} else {
		fmt.Printf("Session portability: %s\n", dim("disabled"))
	}

	fmt.Printf("Max output tokens:   %s\n", cfg.MaxOutputTokens)
	fmt.Println()

	// Bedrock configuration
	fmt.Println(cyan("Bedrock Configuration:"))
	if cfg.BedrockProfile != "" {
		fmt.Printf("  Profile: %s\n", cfg.BedrockProfile)
		fmt.Printf("  Region:  %s\n", cfg.BedrockRegion)
		fmt.Printf("  Model:   %s\n", cfg.BedrockModel)
		fmt.Printf("  Fast:    %s\n", cfg.BedrockFastModel)
		fmt.Println()

		// Check SSO status
		fmt.Print("  SSO Status: ")
		ssoCmd := exec.Command("aws", "sts", "get-caller-identity", "--profile", cfg.BedrockProfile)
		if err := ssoCmd.Run(); err == nil {
			fmt.Println(green("authenticated"))
		} else {
			fmt.Println(yellow("not authenticated"))
			fmt.Printf("  %s\n", dim(fmt.Sprintf("Run: aws sso login --profile %s", cfg.BedrockProfile)))
		}
	} else {
		fmt.Printf("  %s\n", dim("Not configured (set CLAUDE_BEDROCK_PROFILE)"))
	}

	fmt.Println()

	// Claude installation check
	fmt.Println(cyan("Installation:"))
	if _, err := exec.LookPath("claude"); err == nil {
		fmt.Printf("  Claude CLI: %s\n", green("installed"))
	} else {
		fmt.Printf("  Claude CLI: %s\n", yellow("not found"))
	}

	if _, err := exec.LookPath("dotclaude"); err == nil {
		fmt.Printf("  dotclaude:  %s\n", green("installed"))
	} else {
		fmt.Printf("  dotclaude:  %s\n", dim("not installed"))
	}

	return nil
}

// newClaudeBedrockCmd prints Bedrock export commands
func newClaudeBedrockCmd() *cobra.Command {
	var evalMode bool

	cmd := &cobra.Command{
		Use:   "bedrock",
		Short: "Print export commands for AWS Bedrock backend",
		Long: `Print shell commands to configure Claude Code for AWS Bedrock.

Use with eval to set environment:
  eval "$(blackdot tools claude bedrock)"

Or use --eval flag:
  blackdot tools claude bedrock --eval`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runClaudeBedrock(evalMode)
		},
	}

	cmd.Flags().BoolVar(&evalMode, "eval", false, "Output for direct shell evaluation")

	return cmd
}

func runClaudeBedrock(evalMode bool) error {
	cfg := getClaudeConfig()

	if cfg.BedrockProfile == "" {
		return fmt.Errorf("CLAUDE_BEDROCK_PROFILE not set\nConfigure in ~/.claude.local or set environment variable")
	}

	// Check SSO status
	ssoCmd := exec.Command("aws", "sts", "get-caller-identity", "--profile", cfg.BedrockProfile)
	if err := ssoCmd.Run(); err != nil {
		fmt.Fprintln(os.Stderr, "AWS SSO session expired or not authenticated.")
		fmt.Fprintf(os.Stderr, "Run: aws sso login --profile %s\n", cfg.BedrockProfile)
		return fmt.Errorf("SSO authentication required")
	}

	exports := []string{
		fmt.Sprintf("export AWS_PROFILE='%s'", cfg.BedrockProfile),
		fmt.Sprintf("export AWS_REGION='%s'", cfg.BedrockRegion),
		"export CLAUDE_CODE_USE_BEDROCK=1",
		fmt.Sprintf("export ANTHROPIC_MODEL='%s'", cfg.BedrockModel),
		fmt.Sprintf("export ANTHROPIC_SMALL_FAST_MODEL='%s'", cfg.BedrockFastModel),
	}

	if evalMode {
		// Just print the exports for eval
		for _, e := range exports {
			fmt.Println(e)
		}
	} else {
		fmt.Println("Run the following to use AWS Bedrock:")
		fmt.Println()
		for _, e := range exports {
			fmt.Printf("  %s\n", e)
		}
		fmt.Println()
		fmt.Println("Or use: eval \"$(blackdot tools claude bedrock --eval)\"")
	}

	return nil
}

// newClaudeMaxCmd prints Max export commands
func newClaudeMaxCmd() *cobra.Command {
	var evalMode bool

	cmd := &cobra.Command{
		Use:   "max",
		Short: "Print export commands for Anthropic Max backend",
		Long: `Print shell commands to configure Claude Code for Anthropic Max subscription.

This clears any Bedrock-related environment variables to use your
logged-in Anthropic Max session.

Use with eval to set environment:
  eval "$(blackdot tools claude max)"

Or use --eval flag:
  blackdot tools claude max --eval`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runClaudeMax(evalMode)
		},
	}

	cmd.Flags().BoolVar(&evalMode, "eval", false, "Output for direct shell evaluation")

	return cmd
}

func runClaudeMax(evalMode bool) error {
	unsets := []string{
		"unset CLAUDE_CODE_USE_BEDROCK",
		"unset AWS_PROFILE",
		"unset AWS_REGION",
		"unset AWS_ACCESS_KEY_ID",
		"unset AWS_SECRET_ACCESS_KEY",
		"unset AWS_SESSION_TOKEN",
		"unset ANTHROPIC_API_KEY",
		"unset ANTHROPIC_BASE_URL",
		"unset ANTHROPIC_AUTH_TOKEN",
		"unset ANTHROPIC_MODEL",
		"unset ANTHROPIC_SMALL_FAST_MODEL",
	}

	if evalMode {
		for _, u := range unsets {
			fmt.Println(u)
		}
	} else {
		fmt.Println("Run the following to use Anthropic Max:")
		fmt.Println()
		for _, u := range unsets {
			fmt.Printf("  %s\n", u)
		}
		fmt.Println()
		fmt.Println("Or use: eval \"$(blackdot tools claude max --eval)\"")
	}

	return nil
}

// newClaudeSwitchCmd provides interactive backend switching
func newClaudeSwitchCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "switch [bedrock|max]",
		Short: "Switch Claude Code backend",
		Long: `Switch between Claude Code backends interactively or by name.

Examples:
  blackdot tools claude switch           # Interactive selection
  blackdot tools claude switch bedrock   # Switch to Bedrock
  blackdot tools claude switch max       # Switch to Max`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) > 0 {
				return runClaudeSwitchTo(args[0])
			}
			return runClaudeSwitchInteractive()
		},
	}
}

func runClaudeSwitchTo(backend string) error {
	switch strings.ToLower(backend) {
	case "bedrock":
		return runClaudeBedrock(false)
	case "max":
		return runClaudeMax(false)
	default:
		return fmt.Errorf("unknown backend: %s (use 'bedrock' or 'max')", backend)
	}
}

func runClaudeSwitchInteractive() error {
	cfg := getClaudeConfig()

	fmt.Println("Claude Code Backend Selection")
	fmt.Println("=============================")
	fmt.Println()
	fmt.Println("1) bedrock - AWS Bedrock" + func() string {
		if cfg.BedrockProfile != "" {
			return fmt.Sprintf(" (profile: %s)", cfg.BedrockProfile)
		}
		return " (not configured)"
	}())
	fmt.Println("2) max     - Anthropic Max subscription")
	fmt.Println()
	fmt.Print("Select backend [1-2]: ")

	reader := bufio.NewReader(os.Stdin)
	input, _ := reader.ReadString('\n')
	input = strings.TrimSpace(input)

	switch input {
	case "1", "bedrock":
		return runClaudeBedrock(false)
	case "2", "max":
		return runClaudeMax(false)
	default:
		return fmt.Errorf("invalid selection: %s", input)
	}
}

// newClaudeInitCmd initializes Claude Code hooks/commands
func newClaudeInitCmd() *cobra.Command {
	var force bool

	cmd := &cobra.Command{
		Use:   "init",
		Short: "Initialize Claude Code hooks and commands",
		Long: `Initialize Claude Code configuration from blackdot templates.

This copies the claude/ directory contents to ~/.claude/ including:
  - settings.json  (permissions and preferences)
  - commands/      (custom slash commands)
  - hooks/         (pre-tool and session hooks)

Use --force to overwrite existing files.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runClaudeInit(force)
		},
	}

	cmd.Flags().BoolVarP(&force, "force", "f", false, "Overwrite existing files")

	return cmd
}

func runClaudeInit(force bool) error {
	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()

	// Find dotfiles directory
	dotfilesDir := os.Getenv("BLACKDOT_DIR")
	if dotfilesDir == "" {
		home, _ := os.UserHomeDir()
		dotfilesDir = filepath.Join(home, "workspace", "dotfiles")
	}

	srcDir := filepath.Join(dotfilesDir, "claude")
	if _, err := os.Stat(srcDir); os.IsNotExist(err) {
		return fmt.Errorf("source directory not found: %s", srcDir)
	}

	// Target directory
	home, _ := os.UserHomeDir()
	destDir := filepath.Join(home, ".claude")

	// Create .claude directory
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return fmt.Errorf("failed to create %s: %w", destDir, err)
	}

	// Copy files
	items := []struct {
		src  string
		dest string
		dir  bool
	}{
		{"settings.json", "settings.json", false},
		{"commands", "commands", true},
		{"hooks", "hooks", true},
	}

	for _, item := range items {
		srcPath := filepath.Join(srcDir, item.src)
		destPath := filepath.Join(destDir, item.dest)

		// Check if exists
		if _, err := os.Stat(destPath); err == nil && !force {
			fmt.Printf("%s %s already exists (use --force to overwrite)\n", yellow("!"), item.dest)
			continue
		}

		if item.dir {
			// Copy directory recursively
			if err := copyDir(srcPath, destPath); err != nil {
				fmt.Printf("%s Failed to copy %s: %v\n", yellow("!"), item.src, err)
				continue
			}
		} else {
			// Copy file
			if err := copyFile(srcPath, destPath); err != nil {
				fmt.Printf("%s Failed to copy %s: %v\n", yellow("!"), item.src, err)
				continue
			}
		}
		fmt.Printf("%s Copied %s\n", green("✓"), item.dest)
	}

	fmt.Println()
	fmt.Printf("Claude Code configuration initialized in %s\n", destDir)

	return nil
}

// copyFile copies a single file
func copyFile(src, dest string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}

	// Get source file permissions
	info, err := os.Stat(src)
	if err != nil {
		return err
	}

	return os.WriteFile(dest, data, info.Mode())
}

// copyDir copies a directory recursively
func copyDir(src, dest string) error {
	// Remove existing directory if it exists
	os.RemoveAll(dest)

	// Create destination directory
	srcInfo, err := os.Stat(src)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dest, srcInfo.Mode()); err != nil {
		return err
	}

	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		srcPath := filepath.Join(src, entry.Name())
		destPath := filepath.Join(dest, entry.Name())

		if entry.IsDir() {
			if err := copyDir(srcPath, destPath); err != nil {
				return err
			}
		} else {
			if err := copyFile(srcPath, destPath); err != nil {
				return err
			}
		}
	}

	return nil
}

// newClaudeEnvCmd shows Claude environment variables
func newClaudeEnvCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "env",
		Short: "Show Claude Code environment variables",
		Long:  `Display all Claude Code related environment variables currently set.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runClaudeEnv()
		},
	}
}

func runClaudeEnv() error {
	cyan := color.New(color.FgCyan).SprintFunc()
	dim := color.New(color.Faint).SprintFunc()

	envVars := []string{
		"CLAUDE_BEDROCK_PROFILE",
		"CLAUDE_BEDROCK_REGION",
		"CLAUDE_BEDROCK_MODEL",
		"CLAUDE_BEDROCK_FAST_MODEL",
		"CLAUDE_CODE_MAX_OUTPUT_TOKENS",
		"CLAUDE_CODE_USE_BEDROCK",
		"ANTHROPIC_API_KEY",
		"ANTHROPIC_BASE_URL",
		"ANTHROPIC_AUTH_TOKEN",
		"ANTHROPIC_MODEL",
		"ANTHROPIC_SMALL_FAST_MODEL",
		"AWS_PROFILE",
		"AWS_REGION",
	}

	fmt.Println(cyan("Claude Code Environment Variables"))
	fmt.Println(cyan("=================================="))
	fmt.Println()

	for _, v := range envVars {
		val := os.Getenv(v)
		if val != "" {
			// Mask sensitive values
			if strings.Contains(strings.ToLower(v), "key") || strings.Contains(strings.ToLower(v), "token") {
				val = val[:4] + "..." + val[len(val)-4:]
			}
			fmt.Printf("  %s=%s\n", v, val)
		} else {
			fmt.Printf("  %s=%s\n", v, dim("(not set)"))
		}
	}

	fmt.Println()

	// Show config file locations
	fmt.Println(cyan("Configuration Files:"))
	home, _ := os.UserHomeDir()

	configFiles := []string{
		filepath.Join(home, ".claude.local"),
		filepath.Join(home, ".claude", "settings.json"),
	}

	for _, f := range configFiles {
		if _, err := os.Stat(f); err == nil {
			fmt.Printf("  %s (exists)\n", f)
		} else {
			fmt.Printf("  %s %s\n", f, dim("(not found)"))
		}
	}

	// Platform-specific notes
	fmt.Println()
	if runtime.GOOS == "windows" {
		fmt.Println(dim("Note: On Windows, use PowerShell $env:VAR_NAME syntax"))
	}

	return nil
}
