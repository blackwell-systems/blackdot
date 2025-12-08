package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// Health check state
type doctorState struct {
	checksPassed int
	checksFailed int
	checksWarned int

	failedChecks []string
	failedFixes  []string
	warnChecks   []string
	warnFixes    []string

	// Colors
	bold   func(a ...interface{}) string
	dim    func(a ...interface{}) string
	red    func(a ...interface{}) string
	green  func(a ...interface{}) string
	yellow func(a ...interface{}) string
	blue   func(a ...interface{}) string
	cyan   func(a ...interface{}) string
}

func newDoctorCmd() *cobra.Command {
	var fixMode bool
	var quickMode bool

	cmd := &cobra.Command{
		Use:     "doctor",
		Aliases: []string{"health"},
		Short:   "Comprehensive dotfiles health check",
		Long:    `Comprehensive dotfiles health check`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runDoctor(fixMode, quickMode)
		},
	}

	// Override help to use styled version
	cmd.SetHelpFunc(func(cmd *cobra.Command, args []string) {
		printDoctorHelp()
	})

	cmd.Flags().BoolVarP(&fixMode, "fix", "f", false, "Auto-fix permission issues")
	cmd.Flags().BoolVarP(&quickMode, "quick", "q", false, "Run quick checks only (skip vault)")

	return cmd
}

// printDoctorHelp prints styled help matching ZSH doctor help
func printDoctorHelp() {
	// Title
	BoldCyan.Print("dotfiles doctor")
	fmt.Print(" - ")
	Dim.Println("Comprehensive dotfiles health check")
	fmt.Println()

	// Usage
	Bold.Print("Usage:")
	fmt.Println(" dotfiles doctor [OPTIONS]")
	fmt.Println()

	// Options
	BoldCyan.Println("Options:")
	fmt.Print("  ")
	Yellow.Print("--fix")
	fmt.Print(", ")
	Yellow.Print("-f")
	fmt.Print("      ")
	Dim.Println("Auto-fix permission issues")
	fmt.Print("  ")
	Yellow.Print("--quick")
	fmt.Print(", ")
	Yellow.Print("-q")
	fmt.Print("    ")
	Dim.Println("Run quick checks only (skip vault)")
	fmt.Print("  ")
	Yellow.Print("--help")
	fmt.Print(", ")
	Yellow.Print("-h")
	fmt.Print("     ")
	Dim.Println("Show this help")
	fmt.Println()

	// Checks section
	BoldCyan.Println("Checks:")
	Dim.Println("  - Version & updates")
	Dim.Println("  - Core components (symlinks)")
	Dim.Println("  - Required commands")
	Dim.Println("  - SSH configuration")
	Dim.Println("  - AWS configuration")
	Dim.Println("  - Vault status")
	Dim.Println("  - Shell configuration")
	Dim.Println("  - Claude Code")
	Dim.Println("  - Template system")
	fmt.Println()

	// Examples
	BoldCyan.Println("Examples:")
	fmt.Print("  ")
	Yellow.Print("dotfiles doctor")
	fmt.Print("          ")
	Dim.Println("# Run all checks")
	fmt.Print("  ")
	Yellow.Print("dotfiles doctor --fix")
	fmt.Print("    ")
	Dim.Println("# Auto-fix permissions")
	fmt.Print("  ")
	Yellow.Print("dotfiles doctor --quick")
	fmt.Print("  ")
	Dim.Println("# Fast checks only")
	fmt.Println()
}

func runDoctor(fixMode, quickMode bool) error {
	// Initialize state
	state := &doctorState{
		bold:   color.New(color.Bold).SprintFunc(),
		dim:    color.New(color.Faint).SprintFunc(),
		red:    color.New(color.FgRed).SprintFunc(),
		green:  color.New(color.FgGreen).SprintFunc(),
		yellow: color.New(color.FgYellow).SprintFunc(),
		blue:   color.New(color.FgBlue).SprintFunc(),
		cyan:   color.New(color.FgCyan).SprintFunc(),
	}

	home, _ := os.UserHomeDir()
	dotfilesDir := getDotfilesDir()

	// Banner
	fmt.Println()
	boldCyan := color.New(color.Bold, color.FgCyan).SprintFunc()
	fmt.Println(boldCyan(`    ____        __  _____ __                ____             __
   / __ \____  / /_/ __(_) /__  _____      / __ \____  _____/ /_____  _____
  / / / / __ \/ __/ /_/ / / _ \/ ___/_____/ / / / __ \/ ___/ __/ __ \/ ___/
 / /_/ / /_/ / /_/ __/ / /  __(__  )_____/ /_/ / /_/ / /__/ /_/ /_/ / /
/_____/\____/\__/_/ /_/_/\___/____/     /_____/\____/\___/\__/\____/_/`))
	fmt.Println()
	fmt.Println(state.dim("Comprehensive dotfiles health check"))
	fmt.Println()

	// Section 1: Version & Updates
	state.section("Version & Updates")
	checkVersionAndUpdates(state, dotfilesDir)

	// Section 2: Core Components
	state.section("Core Components")
	checkCoreComponents(state, home, dotfilesDir)

	// Section 3: Required Commands
	state.section("Required Commands")
	checkRequiredCommands(state)

	// Section 4: SSH Configuration
	state.section("SSH Configuration")
	checkSSHConfiguration(state, home, fixMode)

	// Section 5: AWS Configuration (if present)
	if _, err := os.Stat(filepath.Join(home, ".aws")); err == nil {
		state.section("AWS Configuration")
		checkAWSConfiguration(state, home, fixMode)
	}

	// Section 6: Vault Status (unless quick mode)
	if !quickMode {
		checkVaultStatus(state)
	}

	// Section 7: Shell Configuration
	state.section("Shell Configuration")
	checkShellConfiguration(state, home, dotfilesDir)

	// Section 8: Claude Code (optional)
	if _, err := exec.LookPath("claude"); err == nil {
		state.section("Claude Code")
		checkClaudeCode(state, home)
	}

	// Section 9: Template System
	state.section("Template System")
	checkTemplateSystem(state, dotfilesDir)

	// Summary
	printSummary(state, fixMode)

	// Save metrics
	saveMetrics(state, dotfilesDir, home)

	// Exit code
	if state.checksFailed > 0 {
		return fmt.Errorf("health check failed with %d error(s)", state.checksFailed)
	}
	return nil
}

func getDotfilesDir() string {
	if dir := os.Getenv("DOTFILES_DIR"); dir != "" {
		return dir
	}
	if _, err := os.Stat("/workspace/dotfiles"); err == nil {
		return "/workspace/dotfiles"
	}
	home, _ := os.UserHomeDir()
	if _, err := os.Stat(filepath.Join(home, "workspace/dotfiles")); err == nil {
		return filepath.Join(home, "workspace/dotfiles")
	}
	return ""
}

func (s *doctorState) section(name string) {
	fmt.Println()
	fmt.Printf("%s%s── %s ──%s\n", "\033[1m", "\033[36m", name, "\033[0m")
}

func (s *doctorState) pass(msg string) {
	fmt.Printf("%s %s\n", s.green("✓"), msg)
	s.checksPassed++
}

func (s *doctorState) fail(msg, fix string) {
	fmt.Printf("%s %s\n", s.red("✗"), msg)
	s.failedChecks = append(s.failedChecks, msg)
	s.failedFixes = append(s.failedFixes, fix)
	s.checksFailed++
}

func (s *doctorState) warn(msg, fix string) {
	fmt.Printf("%s %s\n", s.yellow("!"), msg)
	s.warnChecks = append(s.warnChecks, msg)
	s.warnFixes = append(s.warnFixes, fix)
	s.checksWarned++
}

func (s *doctorState) info(msg string) {
	fmt.Printf("%s %s\n", s.blue("ℹ"), msg)
}

func checkVersionAndUpdates(state *doctorState, dotfilesDir string) {
	// Check version from CHANGELOG.md
	changelogPath := filepath.Join(dotfilesDir, "CHANGELOG.md")
	if content, err := os.ReadFile(changelogPath); err == nil {
		lines := strings.Split(string(content), "\n")
		for _, line := range lines {
			if strings.HasPrefix(line, "## [") {
				// Extract version
				start := strings.Index(line, "[")
				end := strings.Index(line, "]")
				if start >= 0 && end > start {
					version := line[start+1 : end]
					if version != "Unreleased" {
						state.pass(fmt.Sprintf("Dotfiles version: %s", version))
						break
					}
				}
			}
		}
	} else {
		state.warn("CHANGELOG.md not found", "")
	}

	// Check for git updates
	if _, err := os.Stat(filepath.Join(dotfilesDir, ".git")); err == nil {
		// Try to fetch
		fetchCmd := exec.Command("git", "-C", dotfilesDir, "fetch", "origin", "main", "--dry-run")
		if err := fetchCmd.Run(); err == nil {
			localCmd := exec.Command("git", "-C", dotfilesDir, "rev-parse", "HEAD")
			localOut, _ := localCmd.Output()
			local := strings.TrimSpace(string(localOut))

			remoteCmd := exec.Command("git", "-C", dotfilesDir, "rev-parse", "origin/main")
			remoteOut, _ := remoteCmd.Output()
			remote := strings.TrimSpace(string(remoteOut))

			if local == remote {
				state.pass("Up to date with origin/main")
			} else {
				behindCmd := exec.Command("git", "-C", dotfilesDir, "rev-list", "--count", "HEAD..origin/main")
				behindOut, _ := behindCmd.Output()
				behind := strings.TrimSpace(string(behindOut))
				state.warn(fmt.Sprintf("Behind origin/main by %s commit(s)", behind), "dotfiles-upgrade")
			}
		} else {
			state.info("Could not check for updates (offline?)")
		}
	} else {
		state.warn("Not a git repository", "")
	}
}

func checkCoreComponents(state *doctorState, home, dotfilesDir string) {
	// Check symlinks
	checkSymlink := func(name, link, target string) {
		info, err := os.Lstat(link)
		if err != nil {
			state.fail(fmt.Sprintf("%s symlink missing", name), fmt.Sprintf("ln -sf \"$DOTFILES_DIR/%s\" \"%s\"", target, link))
			return
		}

		if info.Mode()&os.ModeSymlink != 0 {
			actualTarget, _ := os.Readlink(link)
			expectedTarget := target
			expectedFullPath := filepath.Join(dotfilesDir, target)

			if actualTarget == expectedTarget || actualTarget == expectedFullPath {
				state.pass(fmt.Sprintf("%s symlink OK", name))
			} else {
				state.fail(fmt.Sprintf("%s points to wrong target: %s", name, actualTarget),
					fmt.Sprintf("rm \"%s\" && ln -sf \"$DOTFILES_DIR/%s\" \"%s\"", link, target, link))
			}
		} else {
			state.warn(fmt.Sprintf("%s exists but is not a symlink", name),
				fmt.Sprintf("mv \"%s\" \"%s.backup\" && ln -sf \"$DOTFILES_DIR/%s\" \"%s\"", link, link, target, link))
		}
	}

	checkSymlink("~/.zshrc", filepath.Join(home, ".zshrc"), "zsh/zshrc")
	checkSymlink("~/.p10k.zsh", filepath.Join(home, ".p10k.zsh"), "zsh/p10k.zsh")

	// Check ~/.claude symlink (special case - not relative to dotfilesDir)
	workspaceTarget := filepath.Join(home, "workspace")
	if wt := os.Getenv("WORKSPACE_TARGET"); wt != "" {
		workspaceTarget = wt
	}
	claudeTarget := filepath.Join(workspaceTarget, ".claude")

	// Check claude symlink separately since it's not relative to DOTFILES_DIR
	claudeLink := filepath.Join(home, ".claude")
	if info, err := os.Lstat(claudeLink); err != nil {
		state.fail("~/.claude symlink missing", fmt.Sprintf("ln -sf \"%s\" \"%s\"", claudeTarget, claudeLink))
	} else if info.Mode()&os.ModeSymlink != 0 {
		actualTarget, _ := os.Readlink(claudeLink)
		if actualTarget == claudeTarget {
			state.pass("~/.claude symlink OK")
		} else {
			state.fail(fmt.Sprintf("~/.claude points to wrong target: %s", actualTarget),
				fmt.Sprintf("rm \"%s\" && ln -sf \"%s\" \"%s\"", claudeLink, claudeTarget, claudeLink))
		}
	} else {
		state.warn("~/.claude exists but is not a symlink",
			fmt.Sprintf("mv \"%s\" \"%s.backup\" && ln -sf \"%s\" \"%s\"", claudeLink, claudeLink, claudeTarget, claudeLink))
	}

	// Check /workspace symlink
	if info, err := os.Lstat("/workspace"); err == nil && info.Mode()&os.ModeSymlink != 0 {
		actualTarget, _ := os.Readlink("/workspace")
		if actualTarget == workspaceTarget {
			state.pass(fmt.Sprintf("/workspace symlink correct -> %s", workspaceTarget))
		} else {
			state.warn(fmt.Sprintf("/workspace -> %s (expected: %s)", actualTarget, workspaceTarget), "")
		}
	} else {
		state.warn("/workspace symlink not configured (optional for multi-machine)", "")
	}
}

func checkRequiredCommands(state *doctorState) {
	checkCommand := func(cmd, pkg string) {
		if path, err := exec.LookPath(cmd); err == nil {
			// Get version
			verCmd := exec.Command(path, "--version")
			verOut, _ := verCmd.Output()
			version := strings.Split(strings.TrimSpace(string(verOut)), "\n")[0]
			if len(version) > 40 {
				version = version[:40]
			}
			state.pass(fmt.Sprintf("%s %s", cmd, state.dim(fmt.Sprintf("(%s)", version))))
		} else {
			state.fail(fmt.Sprintf("%s not found", cmd), fmt.Sprintf("brew install %s", pkg))
		}
	}

	checkCommand("zsh", "zsh")
	checkCommand("git", "git")
	checkCommand("brew", "homebrew")
	checkCommand("jq", "jq")

	// Check vault CLIs (optional)
	if _, err := exec.LookPath("bw"); err == nil {
		state.pass("bw (Bitwarden CLI)")
	} else if _, err := exec.LookPath("op"); err == nil {
		state.pass("op (1Password CLI)")
	} else if _, err := exec.LookPath("pass"); err == nil {
		state.pass("pass (standard Unix password manager)")
	} else {
		state.info("No vault CLI installed (optional - for vault features)")
	}
}

func checkSSHConfiguration(state *doctorState, home string, fixMode bool) {
	sshDir := filepath.Join(home, ".ssh")

	info, err := os.Stat(sshDir)
	if err != nil {
		state.warn("~/.ssh directory does not exist", "mkdir -p ~/.ssh && chmod 700 ~/.ssh")
		return
	}

	// Check directory permissions
	perms := info.Mode().Perm()
	if perms == 0700 {
		state.pass("~/.ssh directory permissions (700)")
	} else {
		if fixMode {
			os.Chmod(sshDir, 0700)
			state.pass("~/.ssh permissions fixed to 700")
		} else {
			state.fail(fmt.Sprintf("~/.ssh has permissions %04o (should be 700)", perms), "chmod 700 ~/.ssh")
		}
	}

	// Check for SSH keys
	entries, _ := os.ReadDir(sshDir)
	keyCount := 0
	for _, entry := range entries {
		name := entry.Name()
		if strings.HasPrefix(name, "id_") && !strings.HasSuffix(name, ".pub") {
			keyCount++

			// Check key permissions
			keyPath := filepath.Join(sshDir, name)
			keyInfo, _ := os.Stat(keyPath)
			keyPerms := keyInfo.Mode().Perm()
			if keyPerms != 0600 {
				if fixMode {
					os.Chmod(keyPath, 0600)
					state.pass(fmt.Sprintf("Fixed permissions on %s", name))
				} else {
					state.fail(fmt.Sprintf("%s has permissions %04o (should be 600)", name, keyPerms),
						fmt.Sprintf("chmod 600 \"%s\"", keyPath))
				}
			}
		}
	}

	if keyCount > 0 {
		state.pass(fmt.Sprintf("Found %d SSH private key(s)", keyCount))
	} else {
		state.warn("No SSH keys found in ~/.ssh", "ssh-keygen -t ed25519 -C \"your_email@example.com\"")
	}
}

func checkAWSConfiguration(state *doctorState, home string, fixMode bool) {
	awsDir := filepath.Join(home, ".aws")

	// Check config
	if _, err := os.Stat(filepath.Join(awsDir, "config")); err == nil {
		state.pass("~/.aws/config exists")
	} else {
		state.warn("~/.aws/config not found", "")
	}

	// Check credentials
	credsPath := filepath.Join(awsDir, "credentials")
	if info, err := os.Stat(credsPath); err == nil {
		perms := info.Mode().Perm()
		if perms == 0600 {
			state.pass("~/.aws/credentials permissions (600)")
		} else {
			if fixMode {
				os.Chmod(credsPath, 0600)
				state.pass("Fixed ~/.aws/credentials permissions")
			} else {
				state.fail(fmt.Sprintf("~/.aws/credentials has permissions %04o (should be 600)", perms),
					"chmod 600 ~/.aws/credentials")
			}
		}
	} else {
		state.info("~/.aws/credentials not found (using SSO or IAM roles?)")
	}
}

func checkVaultStatus(state *doctorState) {
	// Check Bitwarden
	if _, err := exec.LookPath("bw"); err == nil {
		state.section("Vault Status (Bitwarden)")

		loginCmd := exec.Command("bw", "login", "--check")
		if err := loginCmd.Run(); err == nil {
			state.pass("Logged in to Bitwarden")

			unlockCmd := exec.Command("bw", "unlock", "--check")
			if err := unlockCmd.Run(); err == nil {
				state.pass("Vault is unlocked")
			} else {
				state.warn("Vault is locked", "dotfiles vault unlock")
			}
		} else {
			state.warn("Not logged in to Bitwarden", "bw login && dotfiles vault unlock")
		}
		return
	}

	// Check 1Password
	if _, err := exec.LookPath("op"); err == nil {
		state.section("Vault Status (1Password)")

		accountCmd := exec.Command("op", "account", "get")
		if err := accountCmd.Run(); err == nil {
			state.pass("Signed in to 1Password")
		} else {
			state.warn("Not signed in to 1Password", "dotfiles vault unlock")
		}
		return
	}

	// Check pass
	if _, err := exec.LookPath("pass"); err == nil {
		state.section("Vault Status (pass)")

		home, _ := os.UserHomeDir()
		if _, err := os.Stat(filepath.Join(home, ".password-store")); err == nil {
			state.pass("Password store initialized")
		} else {
			state.warn("Password store not initialized", "pass init <gpg-id>")
		}
	}
}

func checkShellConfiguration(state *doctorState, home, dotfilesDir string) {
	// Check default shell
	shell := os.Getenv("SHELL")
	if strings.Contains(shell, "zsh") {
		state.pass("Default shell is zsh")
	} else {
		state.warn(fmt.Sprintf("Default shell is %s (expected zsh)", shell), "chsh -s $(which zsh)")
	}

	// Check zsh modules
	zshDDir := filepath.Join(dotfilesDir, "zsh/zsh.d")
	if entries, err := os.ReadDir(zshDDir); err == nil {
		moduleCount := 0
		for _, e := range entries {
			if strings.HasSuffix(e.Name(), ".zsh") {
				moduleCount++
			}
		}
		state.pass(fmt.Sprintf("Found %d zsh modules in zsh.d/", moduleCount))
	} else {
		state.warn("zsh.d/ directory not found", "")
	}

	// Check Powerlevel10k
	if _, err := os.Stat(filepath.Join(home, ".p10k.zsh")); err == nil {
		state.pass("Powerlevel10k configuration exists")
	} else {
		state.warn("Powerlevel10k configuration missing", "")
	}
}

func checkClaudeCode(state *doctorState, home string) {
	state.pass("Claude CLI installed")

	// Check dotclaude
	if _, err := exec.LookPath("dotclaude"); err == nil {
		state.pass("dotclaude installed")

		// Check active profile
		profileCmd := exec.Command("dotclaude", "active")
		if out, err := profileCmd.Output(); err == nil {
			profile := strings.TrimSpace(string(out))
			if profile != "" && profile != "none" {
				state.pass(fmt.Sprintf("Active profile: %s", profile))
			} else {
				state.warn("No active profile", "dotclaude switch <profile>")
			}
		}

		// Check profiles.json
		if _, err := os.Stat(filepath.Join(home, ".claude/profiles.json")); err == nil {
			state.pass("profiles.json exists (vault syncable)")
		} else {
			state.info("profiles.json not found - run: dotclaude activate <profile>")
		}
	} else {
		state.info("dotclaude not installed (optional)")
		fmt.Println("     Manage Claude profiles across machines:")
		fmt.Println("     See: github.com/blackwell-systems/dotclaude")
	}
}

func checkTemplateSystem(state *doctorState, dotfilesDir string) {
	templatesDir := filepath.Join(dotfilesDir, "templates")
	generatedDir := filepath.Join(dotfilesDir, "generated")

	// Check if template system is configured
	if _, err := os.Stat(filepath.Join(templatesDir, "_variables.local.sh")); err == nil {
		state.pass("Template variables configured")

		// Check if templates are rendered
		if entries, err := os.ReadDir(generatedDir); err == nil {
			generatedCount := 0
			for _, e := range entries {
				if !e.IsDir() {
					generatedCount++
				}
			}

			if generatedCount > 0 {
				state.pass(fmt.Sprintf("Found %d generated config(s)", generatedCount))

				// Check for stale templates
				staleCount := 0
				tmplDir := filepath.Join(templatesDir, "configs")
				if tmplEntries, err := os.ReadDir(tmplDir); err == nil {
					for _, te := range tmplEntries {
						if !strings.HasSuffix(te.Name(), ".tmpl") {
							continue
						}
						basename := strings.TrimSuffix(te.Name(), ".tmpl")
						tmplPath := filepath.Join(tmplDir, te.Name())
						genPath := filepath.Join(generatedDir, basename)

						tmplInfo, _ := os.Stat(tmplPath)
						genInfo, err := os.Stat(genPath)
						if err == nil && tmplInfo.ModTime().After(genInfo.ModTime()) {
							staleCount++
						}
					}
				}

				if staleCount > 0 {
					state.warn(fmt.Sprintf("%d template(s) need re-rendering", staleCount), "dotfiles template render")
				} else {
					state.pass("All generated configs up to date")
				}
			} else {
				state.warn("No generated configs", "dotfiles template render")
			}
		} else {
			state.warn("Generated directory missing", fmt.Sprintf("mkdir -p \"%s\" && dotfiles template render", generatedDir))
		}
	} else {
		state.info("Template system not configured (optional)")
		state.info("Run 'dotfiles template init' to set up machine-specific configs")
	}
}

func printSummary(state *doctorState, fixMode bool) {
	fmt.Println()
	fmt.Printf("%s═══════════════════════════════════════════════════════════%s\n", "\033[1m", "\033[0m")
	fmt.Println()

	total := state.checksPassed + state.checksFailed + state.checksWarned

	// Calculate health score
	var healthScore int
	var scoreStatus, scoreIcon string
	var scoreColor func(a ...interface{}) string

	if state.checksFailed == 0 && state.checksWarned == 0 {
		healthScore = 100
		scoreStatus = "Healthy"
		scoreColor = state.green
		scoreIcon = "🟢"
	} else if state.checksFailed == 0 {
		healthScore = 100 - (state.checksWarned * 5)
		if healthScore >= 80 {
			scoreStatus = "Healthy"
			scoreColor = state.green
			scoreIcon = "🟢"
		} else {
			scoreStatus = "Minor Issues"
			scoreColor = state.yellow
			scoreIcon = "🟡"
		}
	} else {
		healthScore = 100 - (state.checksFailed * 10) - (state.checksWarned * 5)
		if healthScore < 0 {
			healthScore = 0
		}

		if healthScore >= 80 {
			scoreStatus = "Healthy"
			scoreColor = state.green
			scoreIcon = "🟢"
		} else if healthScore >= 60 {
			scoreStatus = "Minor Issues"
			scoreColor = state.yellow
			scoreIcon = "🟡"
		} else if healthScore >= 40 {
			scoreStatus = "Needs Work"
			scoreColor = state.yellow
			scoreIcon = "🟠"
		} else {
			scoreStatus = "Critical"
			scoreColor = state.red
			scoreIcon = "🔴"
		}
	}

	// Health score banner
	fmt.Printf("  %s  %sHealth Score: %s%s %s- %s%s\n",
		scoreIcon, state.bold(""), scoreColor(fmt.Sprintf("%d/100", healthScore)), "\033[0m",
		state.bold(""), scoreStatus, "\033[0m")
	fmt.Println()

	// Score interpretation
	fmt.Printf("  %s\n", state.dim("Score Interpretation:"))
	fmt.Printf("    🟢 %s  Healthy      - All checks passed or minor warnings\n", state.bold("80-100"))
	fmt.Printf("    🟡 %s   Minor Issues - Some warnings, safe to use\n", state.bold("60-79"))
	fmt.Printf("    🟠 %s   Needs Work   - Several issues, fix recommended\n", state.bold("40-59"))
	fmt.Printf("    🔴 %s    Critical     - Major problems, fix immediately\n", state.bold("0-39"))
	fmt.Println()

	// Results summary
	fmt.Printf("  %s\n", state.bold("Your Results:"))
	if state.checksFailed > 0 {
		fmt.Printf("    %s %d failed check(s)   %s\n", state.red("✗"), state.checksFailed,
			state.dim(fmt.Sprintf("(-%d points)", state.checksFailed*10)))
	}
	if state.checksWarned > 0 {
		fmt.Printf("    %s %d warning(s)        %s\n", state.yellow("!"), state.checksWarned,
			state.dim(fmt.Sprintf("(-%d points)", state.checksWarned*5)))
	}
	if state.checksPassed > 0 {
		fmt.Printf("    %s %d passed check(s)\n", state.green("✓"), state.checksPassed)
	}
	fmt.Println()

	// Quick fixes section
	if state.checksFailed > 0 || state.checksWarned > 0 {
		fmt.Printf("  %s\n", state.bold("Quick Fixes:"))
		fmt.Println()

		// Show failed checks with fixes
		if state.checksFailed > 0 {
			for i, check := range state.failedChecks {
				fmt.Printf("    %s %s\n", state.red("✗"), check)
				if i < len(state.failedFixes) && state.failedFixes[i] != "" {
					fmt.Printf("      %s %s\n", state.green("→"), state.dim(state.failedFixes[i]))
				}
			}
			fmt.Println()
		}

		// Show warnings with fixes (limit to first 3)
		if state.checksWarned > 0 {
			count := 0
			for i, check := range state.warnChecks {
				if count >= 3 {
					break
				}
				fmt.Printf("    %s %s\n", state.yellow("!"), check)
				if i < len(state.warnFixes) && state.warnFixes[i] != "" {
					fmt.Printf("      %s %s\n", state.green("→"), state.dim(state.warnFixes[i]))
				}
				count++
			}
			if len(state.warnChecks) > 3 {
				fmt.Printf("    %s\n", state.dim(fmt.Sprintf("... and %d more warning(s)", len(state.warnChecks)-3)))
			}
			fmt.Println()
		}

		// Auto-fix suggestion
		if !fixMode {
			fixable := 0
			for _, check := range state.failedChecks {
				if strings.Contains(check, "permissions") {
					fixable++
				}
			}
			if fixable > 0 {
				fmt.Printf("  %s\n", state.bold(fmt.Sprintf("Auto-fix available for %d issue(s):", fixable)))
				fmt.Printf("    %s dotfiles doctor --fix\n", state.green("→"))
				fmt.Println()
			}
		}

		// Estimated improvement
		potentialScore := 100 - (state.checksWarned * 2)
		if potentialScore > 100 {
			potentialScore = 100
		}
		fmt.Printf("  %s %s %s\n", state.bold("Potential Score:"),
			state.green(fmt.Sprintf("%d/100", potentialScore)),
			state.dim("(if all issues fixed)"))
		fmt.Println()
	}

	// Perfect score celebration
	if healthScore == 100 {
		fmt.Printf("  %s\n", state.green(state.bold("🎉 Perfect score! Your dotfiles are healthy.")))
		fmt.Println()
	}

	fmt.Printf("%s═══════════════════════════════════════════════════════════%s\n", "\033[1m", "\033[0m")
	fmt.Println()

	// Print total for reference
	_ = total
}

func saveMetrics(state *doctorState, dotfilesDir, home string) {
	metricsFile := filepath.Join(home, ".dotfiles-metrics.jsonl")

	// Get metadata
	timestamp := time.Now().UTC().Format("2006-01-02T15:04:05+00:00")

	gitBranch := "unknown"
	if cmd := exec.Command("git", "-C", dotfilesDir, "rev-parse", "--abbrev-ref", "HEAD"); cmd != nil {
		if out, err := cmd.Output(); err == nil {
			gitBranch = strings.TrimSpace(string(out))
		}
	}

	hostname := "unknown"
	if h, err := os.Hostname(); err == nil {
		hostname = h
	}

	osName := "unknown"
	if cmd := exec.Command("uname", "-s"); cmd != nil {
		if out, err := cmd.Output(); err == nil {
			osName = strings.TrimSpace(string(out))
		}
	}

	// Calculate health score for metrics
	healthScore := 100 - (state.checksFailed * 10) - (state.checksWarned * 5)
	if healthScore < 0 {
		healthScore = 0
	}

	// Create metrics entry
	metrics := map[string]interface{}{
		"timestamp":    timestamp,
		"health_score": healthScore,
		"errors":       state.checksFailed,
		"warnings":     state.checksWarned,
		"fixed":        0,
		"git_branch":   gitBranch,
		"hostname":     hostname,
		"os":           osName,
	}

	// Write as JSON line
	if data, err := json.Marshal(metrics); err == nil {
		f, err := os.OpenFile(metricsFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if err == nil {
			defer f.Close()
			f.WriteString(string(data) + "\n")
		}
	}
}
