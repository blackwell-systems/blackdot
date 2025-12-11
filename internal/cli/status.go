package cli

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

type statusItem struct {
	name string
	ok   bool
	info string
	fix  string
	skip bool // Don't show this item
}

func newStatusCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "status",
		Aliases: []string{"s"},
		Short:   "Show quick status dashboard",
		Long: `Display a quick visual dashboard of blackdot status.

Shows:
  - Symlink status (zshrc, claude, /workspace)
  - SSH keys loaded
  - AWS authentication status
  - Lima VM status (macOS only)
  - Claude profile (if dotclaude available)

Examples:
  blackdot status    # Quick visual dashboard
  blackdot s         # Short alias`,
		RunE: runStatus,
	}

	return cmd
}

func runStatus(cmd *cobra.Command, args []string) error {
	home, _ := os.UserHomeDir()

	// Colors
	green := color.New(color.FgGreen).SprintFunc()
	red := color.New(color.FgRed).SprintFunc()
	dim := color.New(color.Faint).SprintFunc()

	var items []statusItem
	var fixes []string

	// Check zshrc symlink
	zshrcPath := filepath.Join(home, ".zshrc")
	zshrcItem := statusItem{name: "zshrc"}
	if isSymlink(zshrcPath) {
		zshrcItem.ok = true
		zshrcItem.info = dim("→ blackdot/zsh/zshrc")
	} else {
		zshrcItem.ok = false
		zshrcItem.info = "not linked"
		zshrcItem.fix = "zshrc: run bootstrap"
		fixes = append(fixes, zshrcItem.fix)
	}
	items = append(items, zshrcItem)

	// Check claude symlink
	claudePath := filepath.Join(home, ".claude")
	claudeItem := statusItem{name: "claude"}
	if isSymlink(claudePath) {
		claudeItem.ok = true
		claudeItem.info = dim("→ workspace/.claude")
	} else {
		claudeItem.ok = false
		claudeItem.info = "not linked"
		claudeItem.fix = "claude: bootstrap-dotfiles.sh"
		fixes = append(fixes, claudeItem.fix)
	}
	items = append(items, claudeItem)

	// Check /workspace symlink
	workspaceItem := statusItem{name: "/workspace"}
	if isSymlink("/workspace") {
		target, _ := os.Readlink("/workspace")
		workspaceItem.ok = true
		workspaceItem.info = dim("→ " + target)
	} else {
		workspaceItem.ok = false
		workspaceItem.info = "missing"
		workspaceItem.fix = "/workspace: sudo ln -sfn $HOME/workspace /workspace"
		fixes = append(fixes, workspaceItem.fix)
	}
	items = append(items, workspaceItem)

	// Check SSH keys
	sshItem := statusItem{name: "ssh"}
	sshCount := countSSHKeys()
	if sshCount > 0 {
		sshItem.ok = true
		sshItem.info = green(fmt.Sprintf("%d keys loaded", sshCount))
	} else {
		sshItem.ok = false
		sshItem.info = red("no keys")
		sshItem.fix = "ssh: blackdot vault restore"
		fixes = append(fixes, sshItem.fix)
	}
	items = append(items, sshItem)

	// Check AWS authentication
	awsItem := statusItem{name: "aws"}
	awsProfile := os.Getenv("_CLAUDE_BEDROCK_PROFILE")
	if checkAWSAuth(awsProfile) {
		awsItem.ok = true
		awsItem.info = green("authenticated")
	} else {
		awsItem.ok = false
		awsItem.info = dim("not authenticated")
		if awsProfile != "" {
			awsItem.fix = fmt.Sprintf("aws: aws sso login --profile %s", awsProfile)
			fixes = append(fixes, awsItem.fix)
		}
	}
	items = append(items, awsItem)

	// Check Lima (macOS only)
	limaItem := statusItem{name: "lima", skip: true}
	if isMacOS() {
		if _, err := exec.LookPath("limactl"); err == nil {
			limaItem.skip = false
			if checkLimaRunning() {
				limaItem.ok = true
				limaItem.info = green("running")
			} else {
				limaItem.ok = false
				limaItem.info = dim("stopped")
				limaItem.fix = "lima: limactl start"
				fixes = append(fixes, limaItem.fix)
			}
		}
	}
	items = append(items, limaItem)

	// Check Claude profile
	profileItem := statusItem{name: "profile", skip: true}
	if _, err := exec.LookPath("dotclaude"); err == nil {
		profileItem.skip = false
		profile := getClaudeProfile()
		if profile != "" && profile != "none" {
			profileItem.ok = true
			profileItem.info = green(profile)
		} else {
			profileItem.ok = false
			profileItem.info = dim("no active profile")
			profileItem.fix = "profile: dotclaude switch <profile>"
			fixes = append(fixes, profileItem.fix)
		}
	} else if _, err := exec.LookPath("claude"); err == nil {
		profileItem.skip = false
		profileItem.ok = false
		profileItem.info = dim("try: dotclaude")
	}
	items = append(items, profileItem)

	// Print city skyline ASCII art
	fmt.Println()
	fmt.Println(dim("                            .|"))
	fmt.Println(dim("                            | |              .-----"))
	fmt.Println(dim("               ___          | |              |     |"))
	fmt.Println(dim("     _    _.-\"    \"-._      | |     _.--\"|   |     |"))
	fmt.Println(dim("  .-\"|  _.|     |    |-.    | |  ._-\"   |   |     |"))
	fmt.Println(dim("  |  | |  |   | |    |  |   |_| -.__|   |   |     |"))
	fmt.Println(dim("  |  | \"-\"     \"     \"\"  \"-\" \" \"-.\"    \"`    |_____"))
	fmt.Println(dim("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"))
	fmt.Println()

	// Print status items
	for _, item := range items {
		if item.skip {
			continue
		}

		var symbol string
		if item.ok {
			symbol = green("◆")
		} else {
			symbol = red("◇")
		}

		fmt.Printf("  %-10s %s  %s\n", item.name, symbol, item.info)
	}
	fmt.Println()

	// Print fixes if needed
	if len(fixes) > 0 {
		fmt.Println(dim("  ┌─ fixes ────────────────────────────────"))
		for _, fix := range fixes {
			fmt.Printf("  %s %s\n", dim("│"), fix)
		}
		fmt.Println(dim("  └─────────────────────────────────────────"))
		fmt.Println()
	}

	return nil
}

// isSymlink checks if a path is a symbolic link
func isSymlink(path string) bool {
	info, err := os.Lstat(path)
	if err != nil {
		return false
	}
	return info.Mode()&os.ModeSymlink != 0
}

// countSSHKeys returns the number of SSH keys loaded in the agent
func countSSHKeys() int {
	cmd := exec.Command("ssh-add", "-l")
	output, err := cmd.Output()
	if err != nil {
		return 0
	}
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) == 1 && lines[0] == "" {
		return 0
	}
	return len(lines)
}

// checkAWSAuth checks if AWS authentication is valid
func checkAWSAuth(profile string) bool {
	args := []string{"sts", "get-caller-identity"}
	if profile != "" {
		args = append(args, "--profile", profile)
	}
	cmd := exec.Command("aws", args...)
	err := cmd.Run()
	return err == nil
}

// isMacOS returns true if running on macOS
func isMacOS() bool {
	return os.Getenv("OSTYPE") == "darwin" || fileExists("/System/Library/CoreServices/SystemVersion.plist")
}

// fileExists checks if a file exists
func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// checkLimaRunning checks if any Lima VMs are running
func checkLimaRunning() bool {
	cmd := exec.Command("limactl", "list")
	output, err := cmd.Output()
	if err != nil {
		return false
	}
	return strings.Contains(string(output), "Running")
}

// getClaudeProfile returns the active Claude profile
func getClaudeProfile() string {
	cmd := exec.Command("dotclaude", "active")
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}
