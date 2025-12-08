// Package cli implements the dotfiles command-line interface using Cobra.
package cli

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// newToolsAWSCmd creates the aws tools subcommand
func newToolsAWSCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "aws",
		Short: "AWS profile and authentication management",
		Long: `AWS profile and authentication management tools.

Cross-platform AWS utilities for managing profiles, SSO login,
and cross-account role assumption.

Commands:
  profiles  - List all configured AWS profiles
  who       - Show current AWS identity
  login     - SSO login to AWS profile
  switch    - Set AWS_PROFILE environment variable (prints export command)
  assume    - Assume IAM role for cross-account access
  clear     - Clear temporary credentials`,
	}

	cmd.AddCommand(
		newAWSProfilesCmd(),
		newAWSWhoCmd(),
		newAWSLoginCmd(),
		newAWSSwitchCmd(),
		newAWSAssumeCmd(),
		newAWSClearCmd(),
		newAWSStatusCmd(),
	)

	return cmd
}

// newAWSProfilesCmd lists AWS profiles
func newAWSProfilesCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "profiles",
		Short: "List all configured AWS profiles",
		Long:  `List all AWS profiles from ~/.aws/config with active profile marked.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runAWSProfiles()
		},
	}
}

func runAWSProfiles() error {
	// Get profiles using aws cli
	out, err := exec.Command("aws", "configure", "list-profiles").Output()
	if err != nil {
		return fmt.Errorf("failed to list profiles (is AWS CLI installed?): %w", err)
	}

	currentProfile := os.Getenv("AWS_PROFILE")

	fmt.Println("Available AWS profiles:")
	scanner := bufio.NewScanner(strings.NewReader(string(out)))
	for scanner.Scan() {
		profile := strings.TrimSpace(scanner.Text())
		if profile == "" {
			continue
		}
		if profile == currentProfile {
			fmt.Printf("  * %s (active)\n", profile)
		} else {
			fmt.Printf("    %s\n", profile)
		}
	}

	return nil
}

// newAWSWhoCmd shows current AWS identity
func newAWSWhoCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "who",
		Short: "Show current AWS identity",
		Long:  `Display the current AWS identity (account, user, ARN).`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runAWSWho()
		},
	}
}

func runAWSWho() error {
	profile := os.Getenv("AWS_PROFILE")
	if profile == "" {
		profile = "default"
	}
	fmt.Printf("Profile: %s\n", profile)

	cmd := exec.Command("aws", "sts", "get-caller-identity", "--output", "table")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Printf("Not authenticated. Run: dotfiles tools aws login %s\n", profile)
		return nil
	}

	return nil
}

// newAWSLoginCmd performs SSO login
func newAWSLoginCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "login [profile]",
		Short: "SSO login to AWS profile",
		Long: `Perform AWS SSO login for the specified profile.

If no profile is specified, uses AWS_PROFILE or defaults to 'default'.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			profile := ""
			if len(args) > 0 {
				profile = args[0]
			} else {
				profile = os.Getenv("AWS_PROFILE")
				if profile == "" {
					profile = "default"
				}
			}
			return runAWSLogin(profile)
		},
	}
}

func runAWSLogin(profile string) error {
	fmt.Printf("Logging in to AWS SSO profile: %s\n", profile)

	cmd := exec.Command("aws", "sso", "login", "--profile", profile)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("SSO login failed: %w", err)
	}

	fmt.Println()
	fmt.Printf("Logged in successfully. To use this profile:\n")
	fmt.Printf("  export AWS_PROFILE=%s\n", profile)

	return nil
}

// newAWSSwitchCmd sets AWS profile
func newAWSSwitchCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "switch <profile>",
		Short: "Set AWS_PROFILE (prints export command)",
		Long: `Print the export command to set AWS_PROFILE.

Since Go cannot modify the parent shell's environment,
this command prints the export command to execute.

Usage:
  eval "$(dotfiles tools aws switch myprofile)"

Or copy and paste the output.`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			profile := args[0]

			// Verify profile exists
			out, err := exec.Command("aws", "configure", "list-profiles").Output()
			if err != nil {
				return fmt.Errorf("failed to list profiles: %w", err)
			}

			found := false
			for _, p := range strings.Split(string(out), "\n") {
				if strings.TrimSpace(p) == profile {
					found = true
					break
				}
			}

			if !found {
				return fmt.Errorf("profile '%s' not found", profile)
			}

			// Print export command
			fmt.Printf("export AWS_PROFILE=%s\n", profile)
			return nil
		},
	}
}

// newAWSAssumeCmd assumes IAM role
func newAWSAssumeCmd() *cobra.Command {
	var sessionName string

	cmd := &cobra.Command{
		Use:   "assume <role-arn>",
		Short: "Assume IAM role for cross-account access",
		Long: `Assume an IAM role and print export commands for temporary credentials.

Usage:
  eval "$(dotfiles tools aws assume arn:aws:iam::123456789:role/MyRole)"`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return runAWSAssume(args[0], sessionName)
		},
	}

	cmd.Flags().StringVarP(&sessionName, "session", "s", "cli-session", "Session name")

	return cmd
}

type stsCredentials struct {
	Credentials struct {
		AccessKeyId     string `json:"AccessKeyId"`
		SecretAccessKey string `json:"SecretAccessKey"`
		SessionToken    string `json:"SessionToken"`
	} `json:"Credentials"`
}

func runAWSAssume(roleArn, sessionName string) error {
	cmd := exec.Command("aws", "sts", "assume-role",
		"--role-arn", roleArn,
		"--role-session-name", sessionName,
		"--output", "json")

	out, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to assume role: %w", err)
	}

	var creds stsCredentials
	if err := json.Unmarshal(out, &creds); err != nil {
		return fmt.Errorf("failed to parse credentials: %w", err)
	}

	// Print export commands
	fmt.Printf("export AWS_ACCESS_KEY_ID=%s\n", creds.Credentials.AccessKeyId)
	fmt.Printf("export AWS_SECRET_ACCESS_KEY=%s\n", creds.Credentials.SecretAccessKey)
	fmt.Printf("export AWS_SESSION_TOKEN=%s\n", creds.Credentials.SessionToken)

	return nil
}

// newAWSClearCmd clears temporary credentials
func newAWSClearCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "clear",
		Short: "Clear temporary credentials (prints unset commands)",
		Long: `Print unset commands to clear temporary AWS credentials.

Usage:
  eval "$(dotfiles tools aws clear)"`,
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("unset AWS_ACCESS_KEY_ID")
			fmt.Println("unset AWS_SECRET_ACCESS_KEY")
			fmt.Println("unset AWS_SESSION_TOKEN")
			return nil
		},
	}
}

// newAWSStatusCmd shows AWS status with banner
func newAWSStatusCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show AWS status with banner",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runAWSStatus()
		},
	}
}

func runAWSStatus() error {
	// Check if authenticated
	isAuthenticated := false
	authCmd := exec.Command("aws", "sts", "get-caller-identity")
	if err := authCmd.Run(); err == nil {
		isAuthenticated = true
	}

	// Choose color
	var logoColor *color.Color
	if isAuthenticated {
		logoColor = color.New(color.FgYellow) // AWS Orange-ish
	} else {
		logoColor = color.New(color.FgRed)
	}

	// Print banner
	fmt.Println()
	logoColor.Println("   █████╗ ██╗    ██╗███████╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗")
	logoColor.Println("  ██╔══██╗██║    ██║██╔════╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝")
	logoColor.Println("  ███████║██║ █╗ ██║███████╗       ██║   ██║   ██║██║   ██║██║     ███████╗")
	logoColor.Println("  ██╔══██║██║███╗██║╚════██║       ██║   ██║   ██║██║   ██║██║     ╚════██║")
	logoColor.Println("  ██║  ██║╚███╔███╔╝███████║       ██║   ╚██████╔╝╚██████╔╝███████╗███████║")
	logoColor.Println("  ╚═╝  ╚═╝ ╚══╝╚══╝ ╚══════╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝")
	fmt.Println()

	bold := color.New(color.Bold)
	dim := color.New(color.Faint)
	green := color.New(color.FgGreen)
	red := color.New(color.FgRed)
	cyan := color.New(color.FgCyan)

	bold.Println("  Current Status")
	dim.Println("  ───────────────────────────────────────")

	// Profile
	profile := os.Getenv("AWS_PROFILE")
	if profile != "" {
		fmt.Printf("    %s   %s\n", dim.Sprint("Profile"), cyan.Sprint(profile))
	} else {
		fmt.Printf("    %s   %s\n", dim.Sprint("Profile"), dim.Sprint("<not set>"))
	}

	// Session status
	if isAuthenticated {
		fmt.Printf("    %s   %s\n", dim.Sprint("Session"), green.Sprint("✓ authenticated"))
	} else {
		fmt.Printf("    %s   %s %s\n", dim.Sprint("Session"), red.Sprint("✗ not authenticated"), dim.Sprint("(run awslogin)"))
	}

	fmt.Println()
	return nil
}
