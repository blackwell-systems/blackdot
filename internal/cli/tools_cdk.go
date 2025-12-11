// Package cli implements the dotfiles command-line interface using Cobra.
package cli

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// newToolsCDKCmd creates the cdk tools subcommand
func newToolsCDKCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "cdk",
		Short: "AWS CDK development helpers",
		Long: `AWS CDK development helper tools.

Cross-platform CDK utilities for project creation, deployment, and environment management.

Commands:
  init       - Initialize new CDK project
  env        - Set CDK_DEFAULT_ACCOUNT/REGION from AWS profile
  env-clear  - Clear CDK environment variables
  outputs    - Show CloudFormation stack outputs
  context    - Show or clear CDK context
  status     - Show CDK status with banner`,
	}

	cmd.AddCommand(
		newCDKInitCmd(),
		newCDKEnvCmd(),
		newCDKEnvClearCmd(),
		newCDKOutputsCmd(),
		newCDKContextCmd(),
		newCDKStatusCmd(),
	)

	return cmd
}

// newCDKInitCmd initializes CDK project
func newCDKInitCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "init [language]",
		Short: "Initialize new CDK project",
		Long: `Initialize a new CDK project.

Languages: typescript (default), python, java, go, csharp, fsharp`,
		RunE: func(cmd *cobra.Command, args []string) error {
			lang := "typescript"
			if len(args) > 0 {
				lang = args[0]
			}

			fmt.Printf("Initializing CDK project with language: %s\n", lang)

			cdk := exec.Command("cdk", "init", "app", "--language", lang)
			cdk.Stdout = os.Stdout
			cdk.Stderr = os.Stderr
			cdk.Stdin = os.Stdin
			if err := cdk.Run(); err != nil {
				return err
			}

			if lang == "typescript" {
				fmt.Println("\nInstalling dependencies...")
				npm := exec.Command("npm", "install")
				npm.Stdout = os.Stdout
				npm.Stderr = os.Stderr
				npm.Run()
			}

			return nil
		},
	}
}

// newCDKEnvCmd sets CDK environment from AWS profile
func newCDKEnvCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "env [profile]",
		Short: "Set CDK_DEFAULT_ACCOUNT/REGION from AWS profile",
		Long: `Set CDK environment variables from AWS profile.

Prints export commands to set CDK_DEFAULT_ACCOUNT and CDK_DEFAULT_REGION.

Usage:
  eval "$(blackdot tools cdk env myprofile)"`,
		RunE: func(cmd *cobra.Command, args []string) error {
			profile := os.Getenv("AWS_PROFILE")
			if len(args) > 0 {
				profile = args[0]
			}
			if profile == "" {
				return fmt.Errorf("no profile specified and AWS_PROFILE not set")
			}

			// Get account ID
			stsCmd := exec.Command("aws", "sts", "get-caller-identity",
				"--profile", profile, "--query", "Account", "--output", "text")
			out, err := stsCmd.Output()
			if err != nil {
				return fmt.Errorf("failed to get account ID - are you authenticated? Run: blackdot tools aws login %s", profile)
			}
			account := strings.TrimSpace(string(out))

			// Get region
			regionCmd := exec.Command("aws", "configure", "get", "region", "--profile", profile)
			out, _ = regionCmd.Output()
			region := strings.TrimSpace(string(out))
			if region == "" {
				region = "us-east-1"
			}

			fmt.Printf("export CDK_DEFAULT_ACCOUNT=%s\n", account)
			fmt.Printf("export CDK_DEFAULT_REGION=%s\n", region)

			return nil
		},
	}
}

// newCDKEnvClearCmd clears CDK environment
func newCDKEnvClearCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "env-clear",
		Short: "Clear CDK environment variables",
		Long: `Print unset commands to clear CDK environment variables.

Usage:
  eval "$(blackdot tools cdk env-clear)"`,
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("unset CDK_DEFAULT_ACCOUNT")
			fmt.Println("unset CDK_DEFAULT_REGION")
			return nil
		},
	}
}

// newCDKOutputsCmd shows CloudFormation stack outputs
func newCDKOutputsCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "outputs <stack>",
		Short: "Show CloudFormation stack outputs",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			stack := args[0]

			fmt.Printf("Outputs for stack: %s\n", stack)

			awsCmd := exec.Command("aws", "cloudformation", "describe-stacks",
				"--stack-name", stack,
				"--query", "Stacks[0].Outputs[*].[OutputKey,OutputValue]",
				"--output", "table")
			awsCmd.Stdout = os.Stdout
			awsCmd.Stderr = os.Stderr
			return awsCmd.Run()
		},
	}
}

// newCDKContextCmd shows or clears CDK context
func newCDKContextCmd() *cobra.Command {
	var clear bool

	cmd := &cobra.Command{
		Use:   "context",
		Short: "Show or clear CDK context",
		RunE: func(cmd *cobra.Command, args []string) error {
			if clear {
				if err := os.Remove("cdk.context.json"); err != nil {
					if os.IsNotExist(err) {
						fmt.Println("No cdk.context.json to clear")
						return nil
					}
					return err
				}
				fmt.Println("Cleared cdk.context.json")
				return nil
			}

			// Show context
			data, err := os.ReadFile("cdk.context.json")
			if err != nil {
				if os.IsNotExist(err) {
					fmt.Println("No cdk.context.json found in current directory")
					return nil
				}
				return err
			}

			fmt.Println("CDK Context (cdk.context.json):")
			fmt.Println(string(data))
			return nil
		},
	}

	cmd.Flags().BoolVar(&clear, "clear", false, "Clear the context file")

	return cmd
}

// newCDKStatusCmd shows CDK status with banner
func newCDKStatusCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show CDK status with banner",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runCDKStatus()
		},
	}
}

func runCDKStatus() error {
	// Check if CDK is installed
	hasCDK := false
	var cdkVersion string
	if out, err := exec.Command("cdk", "--version").Output(); err == nil {
		hasCDK = true
		cdkVersion = strings.TrimSpace(strings.Split(string(out), "\n")[0])
	}

	// Check if in CDK project
	inProject := false
	if _, err := os.Stat("cdk.json"); err == nil {
		inProject = true
	}

	// Choose color based on status
	var logoColor *color.Color
	if hasCDK && inProject {
		logoColor = color.New(color.FgHiYellow) // Orange-ish for CDK
	} else if hasCDK {
		logoColor = color.New(color.FgCyan)
	} else {
		logoColor = color.New(color.FgRed)
	}

	// Print banner
	fmt.Println()
	logoColor.Println("   ██████╗██████╗ ██╗  ██╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗")
	logoColor.Println("  ██╔════╝██╔══██╗██║ ██╔╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝")
	logoColor.Println("  ██║     ██║  ██║█████╔╝        ██║   ██║   ██║██║   ██║██║     ███████╗")
	logoColor.Println("  ██║     ██║  ██║██╔═██╗        ██║   ██║   ██║██║   ██║██║     ╚════██║")
	logoColor.Println("  ╚██████╗██████╔╝██║  ██╗       ██║   ╚██████╔╝╚██████╔╝███████╗███████║")
	logoColor.Println("   ╚═════╝╚═════╝ ╚═╝  ╚═╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝")
	fmt.Println()

	// Status section
	bold := color.New(color.Bold)
	dim := color.New(color.Faint)
	green := color.New(color.FgGreen)
	red := color.New(color.FgRed)
	cyan := color.New(color.FgCyan)

	bold.Println("  Current Status")
	dim.Println("  ───────────────────────────────────────")

	if hasCDK {
		fmt.Printf("    %s   %s %s\n", dim.Sprint("CDK"), green.Sprint("✓ installed"), dim.Sprintf("(%s)", cdkVersion))
	} else {
		fmt.Printf("    %s   %s %s\n", dim.Sprint("CDK"), red.Sprint("✗ not installed"), dim.Sprint("(npm install -g aws-cdk)"))
	}

	if inProject {
		fmt.Printf("    %s   %s\n", dim.Sprint("Project"), green.Sprint("✓ cdk.json found"))

		// Detect language
		if _, err := os.Stat("package.json"); err == nil {
			fmt.Printf("    %s   %s\n", dim.Sprint("Language"), cyan.Sprint("TypeScript/JavaScript"))
		} else if _, err := os.Stat("requirements.txt"); err == nil {
			fmt.Printf("    %s   %s\n", dim.Sprint("Language"), cyan.Sprint("Python"))
		} else if _, err := os.Stat("go.mod"); err == nil {
			fmt.Printf("    %s   %s\n", dim.Sprint("Language"), cyan.Sprint("Go"))
		}
	} else {
		fmt.Printf("    %s   %s\n", dim.Sprint("Project"), dim.Sprint("not in CDK project"))
	}

	// CDK environment
	if account := os.Getenv("CDK_DEFAULT_ACCOUNT"); account != "" {
		fmt.Printf("    %s   %s\n", dim.Sprint("Account"), cyan.Sprint(account))
	}
	if region := os.Getenv("CDK_DEFAULT_REGION"); region != "" {
		fmt.Printf("    %s   %s\n", dim.Sprint("Region"), cyan.Sprint(region))
	}

	fmt.Println()
	return nil
}

// Status commands for other tools - add these to their respective files

// addStatusToSSH adds status command to SSH tools
func newSSHStatusCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show SSH status with banner",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runSSHStatus()
		},
	}
}

func runSSHStatus() error {
	// Check agent status
	authSock := os.Getenv("SSH_AUTH_SOCK")
	agentRunning := authSock != ""
	keysLoaded := 0

	if agentRunning {
		if out, err := exec.Command("ssh-add", "-l").Output(); err == nil {
			lines := strings.Split(strings.TrimSpace(string(out)), "\n")
			for _, l := range lines {
				if l != "" && !strings.Contains(l, "no identities") {
					keysLoaded++
				}
			}
		}
	}

	// Choose color
	var logoColor *color.Color
	if agentRunning && keysLoaded > 0 {
		logoColor = color.New(color.FgGreen)
	} else if agentRunning {
		logoColor = color.New(color.FgYellow)
	} else {
		logoColor = color.New(color.FgRed)
	}

	// Print banner
	fmt.Println()
	logoColor.Println("  ███████╗███████╗██╗  ██╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗")
	logoColor.Println("  ██╔════╝██╔════╝██║  ██║    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝")
	logoColor.Println("  ███████╗███████╗███████║       ██║   ██║   ██║██║   ██║██║     ███████╗")
	logoColor.Println("  ╚════██║╚════██║██╔══██║       ██║   ██║   ██║██║   ██║██║     ╚════██║")
	logoColor.Println("  ███████║███████║██║  ██║       ██║   ╚██████╔╝╚██████╔╝███████╗███████║")
	logoColor.Println("  ╚══════╝╚══════╝╚═╝  ╚═╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝")
	fmt.Println()

	bold := color.New(color.Bold)
	dim := color.New(color.Faint)
	green := color.New(color.FgGreen)
	red := color.New(color.FgRed)
	yellow := color.New(color.FgYellow)
	cyan := color.New(color.FgCyan)

	bold.Println("  Current Status")
	dim.Println("  ───────────────────────────────────────")

	if agentRunning {
		agentPID := os.Getenv("SSH_AGENT_PID")
		if agentPID == "" {
			agentPID = "?"
		}
		fmt.Printf("    %s     %s %s\n", dim.Sprint("Agent"), green.Sprint("● running"), dim.Sprintf("(PID: %s)", agentPID))

		if keysLoaded > 0 {
			fmt.Printf("    %s      %s\n", dim.Sprint("Keys"), green.Sprintf("%d loaded", keysLoaded))
		} else {
			fmt.Printf("    %s      %s %s\n", dim.Sprint("Keys"), yellow.Sprint("0 loaded"), dim.Sprint("(run 'sshload')"))
		}
	} else {
		fmt.Printf("    %s     %s %s\n", dim.Sprint("Agent"), red.Sprint("○ not running"), dim.Sprint("(run 'sshagent')"))
	}

	// Count hosts and keys
	hostCount := 0
	if file, err := os.Open(os.Getenv("HOME") + "/.ssh/config"); err == nil {
		defer file.Close()
		scanner := bufio.NewScanner(file)
		for scanner.Scan() {
			if strings.HasPrefix(strings.TrimSpace(scanner.Text()), "Host ") {
				hostCount++
			}
		}
	}
	fmt.Printf("    %s     %s\n", dim.Sprint("Hosts"), cyan.Sprintf("%d configured", hostCount))

	// Count available keys
	keyFiles, _ := os.ReadDir(os.Getenv("HOME") + "/.ssh")
	keyCount := 0
	for _, f := range keyFiles {
		if strings.HasSuffix(f.Name(), ".pub") {
			keyCount++
		}
	}
	fmt.Printf("    %s      %s\n", dim.Sprint("Keys"), cyan.Sprintf("%d available", keyCount))

	fmt.Println()
	return nil
}
