// Package cli implements the blackdot command-line interface using Cobra.
package cli

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

// Tool feature mappings (matches ZSH feature names)
var toolFeatureMap = map[string]string{
	"ssh":    "ssh_tools",
	"aws":    "aws_helpers",
	"cdk":    "cdk_tools",
	"go":     "go_tools",
	"rust":   "rust_tools",
	"python": "python_tools",
	"docker": "docker_tools",
	"claude": "claude_integration",
}

// checkToolFeature verifies a tool's feature is enabled
// Returns nil if enabled, error if disabled
func checkToolFeature(toolName string) error {
	featureName, ok := toolFeatureMap[toolName]
	if !ok {
		// No feature mapping, allow by default
		return nil
	}

	reg := initRegistry()
	if !reg.Enabled(featureName) {
		return fmt.Errorf("feature '%s' is disabled\nEnable with: blackdot features enable %s", featureName, featureName)
	}
	return nil
}

// wrapWithFeatureCheck wraps a command's RunE with feature checking
func wrapWithFeatureCheck(toolName string, cmd *cobra.Command) *cobra.Command {
	originalRunE := cmd.RunE
	originalRun := cmd.Run

	if originalRunE != nil {
		cmd.RunE = func(c *cobra.Command, args []string) error {
			if err := checkToolFeature(toolName); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			return originalRunE(c, args)
		}
	} else if originalRun != nil {
		cmd.Run = func(c *cobra.Command, args []string) {
			if err := checkToolFeature(toolName); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			originalRun(c, args)
		}
	}

	// Also wrap all subcommands
	for _, sub := range cmd.Commands() {
		wrapWithFeatureCheck(toolName, sub)
	}

	return cmd
}

// newToolsCmd creates the tools parent command
func newToolsCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "tools",
		Short: "Cross-platform developer tools",
		Long:  `Cross-platform developer tools`,
		Run: func(cmd *cobra.Command, args []string) {
			printToolsHelp()
		},
	}

	// Store default help before overriding
	defaultHelp := cmd.HelpFunc()

	// Override help only for the tools command itself, not subcommands
	cmd.SetHelpFunc(func(c *cobra.Command, args []string) {
		// Only use styled help for the parent "tools" command
		if c.Name() == "tools" {
			printToolsHelp()
		} else {
			// Use default Cobra help for subcommands
			defaultHelp(c, args)
		}
	})

	// Add tool subcommands with feature checks
	cmd.AddCommand(
		wrapWithFeatureCheck("ssh", newToolsSSHCmd()),
		wrapWithFeatureCheck("aws", newToolsAWSCmd()),
		wrapWithFeatureCheck("cdk", newToolsCDKCmd()),
		wrapWithFeatureCheck("go", newToolsGoCmd()),
		wrapWithFeatureCheck("rust", newToolsRustCmd()),
		wrapWithFeatureCheck("python", newToolsPythonCmd()),
		wrapWithFeatureCheck("docker", newDockerToolsCmd()),
		wrapWithFeatureCheck("claude", newToolsClaudeCmd()),
	)

	return cmd
}

// printToolsHelp prints styled help matching ZSH style
func printToolsHelp() {
	// Title
	BoldCyan.Print("blackdot tools")
	fmt.Print(" - ")
	Dim.Println("Cross-platform developer tools")
	fmt.Println()

	// Usage
	Bold.Print("Usage:")
	fmt.Println(" blackdot tools <category> <command> [options]")
	fmt.Println()

	// Categories
	BoldCyan.Println("Categories:")
	printToolsCmd("ssh", "SSH key and connection management")
	printToolsCmd("aws", "AWS profile and authentication")
	printToolsCmd("cdk", "AWS CDK development helpers")
	printToolsCmd("go", "Go development helpers")
	printToolsCmd("rust", "Rust/Cargo development helpers")
	printToolsCmd("python", "Python/uv development helpers")
	printToolsCmd("docker", "Docker container management")
	printToolsCmd("claude", "Claude Code configuration")
	fmt.Println()

	// Feature flags
	BoldCyan.Println("Feature Flags:")
	Dim.Println("  Each category respects its feature flag:")
	Dim.Println("  ssh_tools, aws_helpers, cdk_tools, go_tools,")
	Dim.Println("  rust_tools, python_tools, docker_tools, claude_integration")
	fmt.Println()

	// Examples
	BoldCyan.Println("Examples:")
	fmt.Print("  ")
	Yellow.Print("blackdot tools ssh keys")
	fmt.Print("           ")
	Dim.Println("# List SSH keys with fingerprints")
	fmt.Print("  ")
	Yellow.Print("blackdot tools ssh status")
	fmt.Print("         ")
	Dim.Println("# Show SSH status with ASCII art")
	fmt.Print("  ")
	Yellow.Print("blackdot tools aws profiles")
	fmt.Print("       ")
	Dim.Println("# List AWS profiles")
	fmt.Print("  ")
	Yellow.Print("blackdot tools docker ps")
	fmt.Print("          ")
	Dim.Println("# List running containers")
	fmt.Print("  ")
	Yellow.Print("blackdot tools docker clean")
	fmt.Print("       ")
	Dim.Println("# Remove stopped containers")
	fmt.Print("  ")
	Yellow.Print("blackdot tools claude status")
	fmt.Print("      ")
	Dim.Println("# Show Claude configuration")
	fmt.Println()

	Dim.Println("Run 'blackdot tools <category> --help' for category details.")
}

// printToolsCmd prints a tools category with description
func printToolsCmd(name, desc string) {
	fmt.Print("  ")
	Yellow.Printf("%-10s", name)
	fmt.Print(" ")
	Dim.Println(desc)
}
