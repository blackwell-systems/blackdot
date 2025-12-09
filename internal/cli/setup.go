package cli

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// Setup phases
var setupPhases = []string{"workspace", "symlinks", "packages", "vault", "secrets", "claude", "template"}

// titleCase capitalizes the first letter of a string (replacement for deprecated strings.Title)
func titleCase(s string) string {
	if len(s) == 0 {
		return s
	}
	return strings.ToUpper(s[:1]) + s[1:]
}

// Phase descriptions
var phaseDescriptions = map[string]string{
	"workspace": "Configure workspace directory",
	"symlinks":  "Link shell config files",
	"packages":  "Install Homebrew packages",
	"vault":     "Configure secret backend",
	"secrets":   "Manage SSH keys, AWS, Git config",
	"claude":    "Claude Code integration",
	"template":  "Machine-specific configs",
}

func newSetupCmd() *cobra.Command {
	var reset bool
	var status bool

	cmd := &cobra.Command{
		Use:   "setup",
		Short: "Interactive setup wizard for dotfiles",
		Long: `Dotfiles Setup - Unified configuration wizard

The setup wizard will:
  1. Check current configuration status
  2. Guide you through any pending setup steps
  3. Save your preferences for future sessions

Your progress is saved automatically. If interrupted, just
run 'dotfiles setup' again to continue where you left off.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runSetup(reset, status)
		},
	}

	cmd.Flags().BoolVarP(&reset, "reset", "r", false, "Reset state and re-run setup from beginning")
	cmd.Flags().BoolVarP(&status, "status", "s", false, "Show current setup status only")

	return cmd
}

// SetupConfig holds config for setup
type SetupConfig struct {
	Version  int                    `json:"version"`
	Setup    SetupState             `json:"setup"`
	Vault    VaultConfig            `json:"vault,omitempty"`
	Paths    PathsConfig            `json:"paths,omitempty"`
	Packages PackagesConfig         `json:"packages,omitempty"`
	Features map[string]bool        `json:"features,omitempty"`
	Extra    map[string]interface{} `json:"-"`
}

type SetupState struct {
	Completed []string `json:"completed,omitempty"`
	Timestamp string   `json:"timestamp,omitempty"`
}

type VaultConfig struct {
	Backend  string `json:"backend,omitempty"`
	LastSync string `json:"last_sync,omitempty"`
}

type PathsConfig struct {
	WorkspaceTarget string `json:"workspace_target,omitempty"`
}

type PackagesConfig struct {
	Tier string `json:"tier,omitempty"`
}

func runSetup(reset, statusOnly bool) error {
	cyan := color.New(color.FgCyan).SprintFunc()
	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()
	bold := color.New(color.Bold).SprintFunc()
	dim := color.New(color.Faint).SprintFunc()

	// Load config
	cfg, err := loadSetupConfig()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// Infer state from existing system
	inferState(cfg)

	// Handle --status flag
	if statusOnly {
		showSetupStatus(cfg)
		return nil
	}

	// Handle --reset flag
	if reset {
		fmt.Print("Reset all setup progress? [y/N]: ")
		if confirm := readInput(); strings.EqualFold(confirm, "y") {
			cfg.Setup.Completed = []string{}
			if err := saveSetupConfig(cfg); err != nil {
				return fmt.Errorf("failed to reset state: %w", err)
			}
			fmt.Printf("%s State reset\n", green("✓"))
		} else {
			fmt.Println("Reset cancelled")
			return nil
		}
	}

	// Show banner
	fmt.Println()
	fmt.Println(cyan(`    ____        __  _____ __`))
	fmt.Println(cyan(`   / __ \____  / /_/ __(_) /__  _____`))
	fmt.Println(cyan(`  / / / / __ \/ __/ /_/ / / _ \/ ___/`))
	fmt.Println(cyan(` / /_/ / /_/ / /_/ __/ / /  __(__  )`))
	fmt.Println(cyan(`/_____/\____/\__/_/ /_/_/\___/____/`))
	fmt.Println()
	fmt.Println(bold("              Setup Wizard"))
	fmt.Println()

	// Show current status
	showSetupStatus(cfg)

	// Check if setup is needed
	if !needsSetup(cfg) {
		fmt.Printf("%s%s\n", green(bold("All setup complete!")), "")
		fmt.Println()
		fmt.Println("Run 'dotfiles doctor' to verify health.")
		fmt.Println("Run 'dotfiles setup --reset' to reconfigure.")
		return nil
	}

	fmt.Println("Let's complete your setup...")
	fmt.Println()

	// Show overview
	fmt.Println(cyan("═══════════════════════════════════════════════════════════════"))
	fmt.Println(bold("                    Setup Wizard Overview"))
	fmt.Println(cyan("═══════════════════════════════════════════════════════════════"))
	fmt.Println()
	fmt.Println(bold("This wizard will guide you through 7 steps:"))
	fmt.Println()
	fmt.Printf("  %s %s         - Configure workspace directory\n", cyan("1."), bold("Workspace"))
	fmt.Printf("     %s\n", dim("Default: ~/workspace (target for /workspace symlink)"))
	fmt.Println()
	fmt.Printf("  %s %s          - Link shell config files\n", cyan("2."), bold("Symlinks"))
	fmt.Printf("     %s\n", dim("~/.zshrc, ~/.p10k.zsh, ~/.claude"))
	fmt.Println()
	fmt.Printf("  %s %s          - Install Homebrew packages\n", cyan("3."), bold("Packages"))
	fmt.Printf("     %s\n", dim("Choose: minimal (18) | enhanced (43) | full (61)"))
	fmt.Println()
	fmt.Printf("  %s %s             - Configure secret backend\n", cyan("4."), bold("Vault"))
	fmt.Printf("     %s\n", dim("Bitwarden, 1Password, or pass"))
	fmt.Println()
	fmt.Printf("  %s %s           - Manage SSH keys, AWS, Git config\n", cyan("5."), bold("Secrets"))
	fmt.Printf("     %s\n", dim("Auto-discover and sync to vault"))
	fmt.Println()
	fmt.Printf("  %s %s       - AI assistant integration\n", cyan("6."), bold("Claude Code"))
	fmt.Printf("     %s\n", dim("Optional: dotclaude + portable sessions"))
	fmt.Println()
	fmt.Printf("  %s %s         - Machine-specific configs\n", cyan("7."), bold("Templates"))
	fmt.Printf("     %s\n", dim("Optional: work vs personal configs"))
	fmt.Println()
	fmt.Printf("%s %s - Progress is saved automatically\n", green("✓"), bold("Safe to exit anytime"))
	fmt.Printf("%s %s - Just run 'dotfiles setup' again\n", green("✓"), bold("Resume anytime"))
	fmt.Println()
	fmt.Println(cyan("═══════════════════════════════════════════════════════════════"))
	fmt.Println()

	fmt.Print("Press Enter to begin setup...")
	readInput()
	fmt.Println()

	// Run each phase
	phaseFuncs := map[string]func(*SetupConfig) error{
		"workspace": phaseWorkspace,
		"symlinks":  phaseSymlinks,
		"packages":  phasePackages,
		"vault":     phaseVault,
		"secrets":   phaseSecrets,
		"claude":    phaseClaude,
		"template":  phaseTemplate,
	}

	for _, phase := range setupPhases {
		if !isPhaseCompleted(cfg, phase) {
			if fn, ok := phaseFuncs[phase]; ok {
				if err := fn(cfg); err != nil {
					fmt.Printf("%s Phase %s failed: %v\n", yellow("!"), phase, err)
					// Continue even if phase fails
				}
				// Save config after each phase
				if err := saveSetupConfig(cfg); err != nil {
					fmt.Printf("%s Failed to save config: %v\n", yellow("!"), err)
				}
			}
		}
	}

	// Final status
	fmt.Println("═══════════════════════════════════════════════════════════")
	showSetupStatus(cfg)

	if !needsSetup(cfg) {
		fmt.Println()
		fmt.Println(green(bold("╔════════════════════════════════════════════════════════════╗")))
		fmt.Println(green(bold("║              Setup Complete!                               ║")))
		fmt.Println(green(bold("╚════════════════════════════════════════════════════════════╝")))
		fmt.Println()

		// Offer feature preset selection
		showPresetSelection(cfg)
		showNextSteps(cfg)
	} else {
		fmt.Printf("%s Some steps were skipped or failed.\n", yellow("!"))
		fmt.Println("Run 'dotfiles setup' again to continue.")
	}

	return nil
}

// loadSetupConfig loads the setup configuration
func loadSetupConfig() (*SetupConfig, error) {
	configPath := filepath.Join(ConfigDir(), "config.json")

	cfg := &SetupConfig{
		Version:  3,
		Features: make(map[string]bool),
	}

	data, err := os.ReadFile(configPath)
	if err != nil {
		if os.IsNotExist(err) {
			return cfg, nil
		}
		return nil, err
	}

	if err := json.Unmarshal(data, cfg); err != nil {
		return nil, err
	}

	return cfg, nil
}

// saveSetupConfig saves the setup configuration
func saveSetupConfig(cfg *SetupConfig) error {
	configDir := ConfigDir()
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return err
	}

	configPath := filepath.Join(configDir, "config.json")
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(configPath, data, 0644)
}

// isPhaseCompleted checks if a phase is in the completed list
func isPhaseCompleted(cfg *SetupConfig, phase string) bool {
	for _, p := range cfg.Setup.Completed {
		if p == phase {
			return true
		}
	}
	return false
}

// markPhaseComplete adds a phase to the completed list
func markPhaseComplete(cfg *SetupConfig, phase string) {
	if !isPhaseCompleted(cfg, phase) {
		cfg.Setup.Completed = append(cfg.Setup.Completed, phase)
	}
}

// needsSetup checks if any required phases are incomplete
func needsSetup(cfg *SetupConfig) bool {
	requiredPhases := []string{"workspace", "symlinks", "vault", "secrets"}
	for _, phase := range requiredPhases {
		if !isPhaseCompleted(cfg, phase) {
			return true
		}
	}
	return false
}

// inferState auto-detects existing setup from system state
func inferState(cfg *SetupConfig) {
	home, _ := os.UserHomeDir()

	// Infer workspace: if config exists or /workspace symlink exists
	if !isPhaseCompleted(cfg, "workspace") {
		if cfg.Paths.WorkspaceTarget != "" {
			markPhaseComplete(cfg, "workspace")
		} else if info, err := os.Lstat("/workspace"); err == nil && info.Mode()&os.ModeSymlink != 0 {
			markPhaseComplete(cfg, "workspace")
		}
	}

	// Infer symlinks: if ~/.zshrc points to our dotfiles
	if !isPhaseCompleted(cfg, "symlinks") {
		zshrcPath := filepath.Join(home, ".zshrc")
		if target, err := os.Readlink(zshrcPath); err == nil {
			if strings.Contains(target, "dotfiles/zsh/zshrc") {
				markPhaseComplete(cfg, "symlinks")
			}
		}
	}

	// Infer packages: if brew is available and a tier is set
	if !isPhaseCompleted(cfg, "packages") {
		if cfg.Packages.Tier != "" {
			if _, err := exec.LookPath("brew"); err == nil {
				markPhaseComplete(cfg, "packages")
			}
		}
	}

	// Infer vault: if a backend is configured
	if !isPhaseCompleted(cfg, "vault") {
		if cfg.Vault.Backend != "" {
			markPhaseComplete(cfg, "vault")
		}
	}

	// Infer claude: if dotclaude is installed or claude not available
	if !isPhaseCompleted(cfg, "claude") {
		if _, err := exec.LookPath("dotclaude"); err == nil {
			markPhaseComplete(cfg, "claude")
		} else if _, err := exec.LookPath("claude"); err != nil {
			// Claude not installed, skip this phase
			markPhaseComplete(cfg, "claude")
		}
	}

	// Infer template: if _variables.local.sh exists
	if !isPhaseCompleted(cfg, "template") {
		templateFile := filepath.Join(DotfilesDir(), "templates", "_variables.local.sh")
		if _, err := os.Stat(templateFile); err == nil {
			markPhaseComplete(cfg, "template")
		}
	}
}

// showSetupStatus displays current setup status
func showSetupStatus(cfg *SetupConfig) {
	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()
	dim := color.New(color.Faint).SprintFunc()
	bold := color.New(color.Bold).SprintFunc()

	fmt.Println()
	fmt.Println(bold("Current Status:"))
	fmt.Println("───────────────")

	for _, phase := range setupPhases {
		desc := phaseDescriptions[phase]
		if isPhaseCompleted(cfg, phase) {
			extra := ""
			switch phase {
			case "workspace":
				if cfg.Paths.WorkspaceTarget != "" {
					extra = fmt.Sprintf(" %s", dim(fmt.Sprintf("(→ %s)", cfg.Paths.WorkspaceTarget)))
				}
			case "vault":
				if cfg.Vault.Backend == "none" {
					fmt.Printf("  %s %s %s\n", yellow("[⊘]"), titleCase(phase), dim("(Skipped - run 'dotfiles vault init')"))
					continue
				} else if cfg.Vault.Backend != "" {
					extra = fmt.Sprintf(" %s", dim(fmt.Sprintf("(%s)", cfg.Vault.Backend)))
				}
			}
			fmt.Printf("  %s %s%s\n", green("[✓]"), titleCase(phase), extra)
		} else {
			fmt.Printf("  %s %s %s\n", yellow("[ ]"), titleCase(phase), dim(fmt.Sprintf("(%s)", desc)))
		}
	}
	fmt.Println()
}

// showProgress displays a progress bar for the current step
func showProgress(current, total int, stepName string) {
	cyan := color.New(color.FgCyan).SprintFunc()
	bold := color.New(color.Bold).SprintFunc()

	if total == 0 {
		return
	}
	if current > total {
		current = total
	}

	percent := current * 100 / total
	filled := current * 20 / total
	if filled > 20 {
		filled = 20
	}
	empty := 20 - filled
	if empty < 0 {
		empty = 0
	}

	bar := strings.Repeat("█", filled) + strings.Repeat("░", empty)

	fmt.Println()
	fmt.Println(cyan("╔═══════════════════════════════════════════════════════════════╗"))
	fmt.Printf("%s %s\n", cyan("║"), bold(fmt.Sprintf("Step %d of %d: %s", current, total, stepName)))
	fmt.Println(cyan("╠═══════════════════════════════════════════════════════════════╣"))
	fmt.Printf("%s %s %s\n", cyan("║"), bar, bold(fmt.Sprintf("%d%%", percent)))
	fmt.Println(cyan("╚═══════════════════════════════════════════════════════════════╝"))
	fmt.Println()
}

// readInput reads a line of input from stdin
func readInput() string {
	reader := bufio.NewReader(os.Stdin)
	input, _ := reader.ReadString('\n')
	return strings.TrimSpace(input)
}

// ============================================================
// Phase Implementations
// ============================================================

func phaseWorkspace(cfg *SetupConfig) error {
	showProgress(1, 7, "Workspace Configuration")

	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()

	if isPhaseCompleted(cfg, "workspace") {
		fmt.Printf("%s Workspace already configured: %s\n", green("✓"), cfg.Paths.WorkspaceTarget)
		fmt.Print("Reconfigure workspace target? [y/N]: ")
		if !strings.EqualFold(readInput(), "y") {
			return nil
		}
	}

	home, _ := os.UserHomeDir()
	defaultTarget := filepath.Join(home, "workspace")
	if envTarget := os.Getenv("WORKSPACE_TARGET"); envTarget != "" {
		defaultTarget = envTarget
	}

	fmt.Println("The workspace directory is where dotfiles and projects are stored.")
	fmt.Println("The /workspace symlink will point to this directory for Claude Code portability.")
	fmt.Println()
	fmt.Printf("Current target: %s\n", defaultTarget)
	fmt.Println()
	fmt.Println("Examples:")
	fmt.Println("  ~/workspace     (default)")
	fmt.Println("  ~/code")
	fmt.Println("  ~/dev")
	fmt.Println("  ~/projects")
	fmt.Println()
	fmt.Printf("Workspace directory [%s]: ", defaultTarget)
	userTarget := readInput()

	finalTarget := defaultTarget
	if userTarget != "" {
		finalTarget = userTarget
	}
	// Expand ~ if present
	if strings.HasPrefix(finalTarget, "~/") {
		finalTarget = filepath.Join(home, finalTarget[2:])
	}

	cfg.Paths.WorkspaceTarget = finalTarget

	// Create directory if needed
	if _, err := os.Stat(finalTarget); os.IsNotExist(err) {
		fmt.Println()
		fmt.Print("Directory doesn't exist. Create it? [Y/n]: ")
		if input := readInput(); input == "" || strings.EqualFold(input, "y") {
			if err := os.MkdirAll(finalTarget, 0755); err != nil {
				return fmt.Errorf("failed to create directory: %w", err)
			}
			fmt.Printf("%s Created %s\n", green("✓"), finalTarget)
		}
	}

	// Check/update /workspace symlink
	if info, err := os.Lstat("/workspace"); err == nil && info.Mode()&os.ModeSymlink != 0 {
		currentLink, _ := os.Readlink("/workspace")
		if currentLink != finalTarget {
			fmt.Println()
			fmt.Printf("Current /workspace → %s\n", currentLink)
			fmt.Printf("Update symlink to → %s? [Y/n]: ", finalTarget)
			if input := readInput(); input == "" || strings.EqualFold(input, "y") {
				cmd := exec.Command("sudo", "ln", "-sfn", finalTarget, "/workspace")
				if err := cmd.Run(); err != nil {
					fmt.Printf("%s Failed to update symlink (may need sudo permissions)\n", yellow("!"))
				} else {
					fmt.Printf("%s Updated /workspace → %s\n", green("✓"), finalTarget)
				}
			}
		} else {
			fmt.Printf("%s Symlink /workspace → %s already correct\n", green("✓"), finalTarget)
		}
	} else if _, err := os.Stat("/workspace"); os.IsNotExist(err) {
		fmt.Println()
		fmt.Printf("Create /workspace symlink to %s? [Y/n]: ", finalTarget)
		if input := readInput(); input == "" || strings.EqualFold(input, "y") {
			cmd := exec.Command("sudo", "ln", "-sfn", finalTarget, "/workspace")
			if err := cmd.Run(); err != nil {
				fmt.Printf("%s Failed to create symlink (may need sudo permissions)\n", yellow("!"))
			} else {
				fmt.Printf("%s Created /workspace → %s\n", green("✓"), finalTarget)
			}
		}
	}

	markPhaseComplete(cfg, "workspace")
	cfg.Features["workspace_symlink"] = true
	fmt.Printf("%s Workspace configured: %s\n", green("✓"), finalTarget)
	return nil
}

func phaseSymlinks(cfg *SetupConfig) error {
	showProgress(2, 7, "Symlinks")

	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()

	if isPhaseCompleted(cfg, "symlinks") {
		fmt.Printf("%s Symlinks already configured\n", green("✓"))
		return nil
	}

	dotfilesDir := DotfilesDir()
	fmt.Println("This will link your shell configuration files.")
	fmt.Println()
	fmt.Println("Files to link:")
	fmt.Printf("  ~/.zshrc     → %s/zsh/zshrc\n", dotfilesDir)
	fmt.Printf("  ~/.p10k.zsh  → %s/zsh/p10k.zsh\n", dotfilesDir)
	fmt.Println()

	fmt.Print("Create symlinks? [Y/n]: ")
	if input := readInput(); strings.EqualFold(input, "n") {
		fmt.Printf("%s Skipped symlinks\n", yellow("!"))
		return nil
	}

	// Run bootstrap script
	bootstrapScript := filepath.Join(dotfilesDir, "bootstrap", "bootstrap-dotfiles.sh")
	if _, err := os.Stat(bootstrapScript); err != nil {
		return fmt.Errorf("bootstrap-dotfiles.sh not found")
	}

	cmd := exec.Command("bash", bootstrapScript)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("bootstrap failed: %w", err)
	}

	markPhaseComplete(cfg, "symlinks")
	fmt.Printf("%s Symlinks created\n", green("✓"))
	return nil
}

func phasePackages(cfg *SetupConfig) error {
	showProgress(3, 7, "Packages")

	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()
	bold := color.New(color.Bold).SprintFunc()
	dim := color.New(color.Faint).SprintFunc()

	if isPhaseCompleted(cfg, "packages") {
		fmt.Printf("%s Packages already installed\n", green("✓"))
		return nil
	}

	// Check if Homebrew is available
	if _, err := exec.LookPath("brew"); err != nil {
		fmt.Printf("%s Homebrew not installed - skipping package installation\n", yellow("!"))
		fmt.Println("Install Homebrew and run 'dotfiles packages' later.")
		return nil
	}

	dotfilesDir := DotfilesDir()
	fmt.Println("This will install packages from Brewfile using Homebrew.")

	// Count packages for each tier
	countPackages := func(filename string) int {
		path := filepath.Join(dotfilesDir, filename)
		data, err := os.ReadFile(path)
		if err != nil {
			return 0
		}
		count := 0
		for _, line := range strings.Split(string(data), "\n") {
			line = strings.TrimSpace(line)
			if strings.HasPrefix(line, "brew ") || strings.HasPrefix(line, "cask ") ||
				strings.HasPrefix(line, "mas ") || strings.HasPrefix(line, "tap ") {
				count++
			}
		}
		return count
	}

	minimalCount := countPackages("Brewfile.minimal")
	if minimalCount == 0 {
		minimalCount = 18
	}
	enhancedCount := countPackages("Brewfile.enhanced")
	if enhancedCount == 0 {
		enhancedCount = 43
	}
	fullCount := countPackages("Brewfile")
	if fullCount == 0 {
		fullCount = 61
	}

	selectedTier := cfg.Packages.Tier

	if selectedTier == "" {
		fmt.Println(bold("Which package tier would you like?"))
		fmt.Println()
		fmt.Printf("  %s minimal    %d packages (~2 min)   %s\n", green("1)"), minimalCount, dim("# Essentials only"))
		fmt.Printf("  %s enhanced   %d packages (~5 min)   %s %s\n", green("2)"), enhancedCount, dim("# Modern tools, no containers"), bold("← RECOMMENDED"))
		fmt.Printf("  %s full       %d packages (~10 min)  %s\n", green("3)"), fullCount, dim("# Everything (Docker, etc.)"))
		fmt.Println()
		fmt.Printf("%s\n", dim("Tip: You can always add more packages later with 'brew install <package>'"))
		fmt.Println()
		fmt.Print("Your choice [2]: ")
		choice := readInput()
		if choice == "" {
			choice = "2"
		}

		switch choice {
		case "1":
			selectedTier = "minimal"
		case "2":
			selectedTier = "enhanced"
		case "3":
			selectedTier = "full"
		default:
			fmt.Printf("%s Invalid choice, using enhanced tier\n", yellow("!"))
			selectedTier = "enhanced"
		}

		cfg.Packages.Tier = selectedTier
		fmt.Printf("Selected tier: %s\n", selectedTier)
		fmt.Println()
	} else {
		fmt.Printf("%s Using saved tier preference: %s\n", green("✓"), selectedTier)
		fmt.Println()
	}

	// Determine brewfile and package count
	var brewfile string
	var packageCount int
	var timeEstimate string

	switch selectedTier {
	case "minimal":
		brewfile = filepath.Join(dotfilesDir, "Brewfile.minimal")
		packageCount = minimalCount
		timeEstimate = "~2 min"
	case "enhanced":
		brewfile = filepath.Join(dotfilesDir, "Brewfile.enhanced")
		packageCount = enhancedCount
		timeEstimate = "~5 min"
	case "full":
		brewfile = filepath.Join(dotfilesDir, "Brewfile")
		packageCount = fullCount
		timeEstimate = "~10 min"
	default:
		brewfile = filepath.Join(dotfilesDir, "Brewfile")
		packageCount = fullCount
		timeEstimate = "~10 min"
	}

	fmt.Printf("This will install %d packages (%s).\n", packageCount, timeEstimate)
	fmt.Print("Install packages? [Y/n]: ")
	if input := readInput(); strings.EqualFold(input, "n") {
		fmt.Printf("%s Skipped packages\n", yellow("!"))
		return nil
	}

	fmt.Printf("Running brew bundle with %s tier...\n", selectedTier)

	cmd := exec.Command("brew", "bundle", "--file="+brewfile)
	cmd.Dir = dotfilesDir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Printf("%s Some packages may have failed - continuing\n", yellow("!"))
		fmt.Printf("Run 'brew bundle --file=%s' to retry failed packages\n", brewfile)
	}

	markPhaseComplete(cfg, "packages")
	fmt.Printf("%s Packages installed successfully (%s tier)\n", green("✓"), selectedTier)
	return nil
}

func phaseVault(cfg *SetupConfig) error {
	showProgress(4, 7, "Vault Configuration")

	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()
	red := color.New(color.FgRed).SprintFunc()

	if isPhaseCompleted(cfg, "vault") {
		if cfg.Vault.Backend != "" && cfg.Vault.Backend != "none" {
			fmt.Printf("%s Vault already configured (%s)\n", green("✓"), cfg.Vault.Backend)
		} else if cfg.Vault.Backend == "none" {
			fmt.Printf("%s Vault was skipped previously\n", yellow("!"))
		} else {
			fmt.Printf("%s Vault already configured\n", green("✓"))
		}

		fmt.Println()
		fmt.Print("Reconfigure vault? [y/N]: ")
		if !strings.EqualFold(readInput(), "y") {
			if cfg.Vault.Backend == "none" {
				fmt.Println("Run 'dotfiles vault init' anytime to configure vault")
			}
			return nil
		}
	}

	// Detect available vault backends
	available := []string{}
	if _, err := exec.LookPath("bw"); err == nil {
		available = append(available, "bitwarden")
	}
	if _, err := exec.LookPath("op"); err == nil {
		available = append(available, "1password")
	}
	if _, err := exec.LookPath("pass"); err == nil {
		available = append(available, "pass")
	}

	if len(available) == 0 {
		fmt.Println("No vault CLI detected. Vault features are optional.")
		fmt.Println()
		fmt.Println("Supported vault backends:")
		fmt.Println("  • Bitwarden:  brew install bitwarden-cli")
		fmt.Println("  • 1Password:  brew install 1password-cli")
		fmt.Println("  • pass:       brew install pass")
		fmt.Println()
		fmt.Print("Skip vault setup? [Y/n]: ")
		if input := readInput(); input == "" || strings.EqualFold(input, "y") {
			fmt.Printf("%s Skipped vault setup\n", yellow("!"))
			cfg.Vault.Backend = "none"
			markPhaseComplete(cfg, "vault")
			fmt.Println()
			fmt.Println("Run 'dotfiles vault init' anytime to configure vault")
			return nil
		}
		fmt.Println("Please install a vault CLI and run 'dotfiles setup' again.")
		return fmt.Errorf("no vault CLI available")
	}

	fmt.Println("Available vault backends:")
	for i, backend := range available {
		fmt.Printf("  %d) %s\n", i+1, backend)
	}
	fmt.Printf("  %d) Skip (configure secrets manually)\n", len(available)+1)

	fmt.Print("Select vault backend [1]: ")
	choice := readInput()
	if choice == "" {
		choice = "1"
	}

	var choiceNum int
	fmt.Sscanf(choice, "%d", &choiceNum)

	if choiceNum == len(available)+1 {
		fmt.Printf("%s Skipped vault setup\n", yellow("!"))
		cfg.Vault.Backend = "none"
		markPhaseComplete(cfg, "vault")
		fmt.Println()
		fmt.Println("Run 'dotfiles vault init' anytime to configure vault")
		return nil
	}

	if choiceNum < 1 || choiceNum > len(available) {
		return fmt.Errorf("invalid selection")
	}

	selected := available[choiceNum-1]
	cfg.Vault.Backend = selected
	os.Setenv("DOTFILES_VAULT_BACKEND", selected)
	fmt.Printf("Using vault backend: %s\n", selected)

	// Check/create vault items configuration
	vaultConfig := filepath.Join(ConfigDir(), "vault-items.json")
	vaultExample := filepath.Join(DotfilesDir(), "vault", "vault-items.example.json")

	if _, err := os.Stat(vaultConfig); os.IsNotExist(err) {
		fmt.Println("Vault items configuration needed.")
		fmt.Println()
		fmt.Println("This config defines which secrets to manage:")
		fmt.Println("  • SSH keys (names and paths)")
		fmt.Println("  • Config files (AWS, Git, etc.)")
		fmt.Println()

		// Copy example
		if _, err := os.Stat(vaultExample); err == nil {
			if err := os.MkdirAll(ConfigDir(), 0755); err != nil {
				return err
			}
			data, err := os.ReadFile(vaultExample)
			if err != nil {
				return err
			}
			if err := os.WriteFile(vaultConfig, data, 0644); err != nil {
				return err
			}
			fmt.Printf("%s Created %s\n", green("✓"), vaultConfig)
			fmt.Println()
			fmt.Println("Please customize your vault items configuration.")
			fmt.Println("Edit the file to match your vault item names and paths.")
			fmt.Println()
			fmt.Print("Open editor now? [Y/n]: ")
			if input := readInput(); input == "" || strings.EqualFold(input, "y") {
				editor := os.Getenv("EDITOR")
				if editor == "" {
					editor = "vim"
				}
				cmd := exec.Command(editor, vaultConfig)
				cmd.Stdin = os.Stdin
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				cmd.Run()
			}
		} else {
			fmt.Printf("%s Example config not found: %s\n", red("✗"), vaultExample)
			return fmt.Errorf("vault example not found")
		}
	} else {
		fmt.Printf("%s Vault items config exists\n", green("✓"))
	}

	// Backend-specific login hints (actual login would be done via bash vault commands)
	fmt.Println()
	switch selected {
	case "bitwarden":
		fmt.Println("To unlock Bitwarden:")
		fmt.Println("  export BW_SESSION=\"$(bw unlock --raw)\"")
	case "1password":
		fmt.Println("To sign in to 1Password:")
		fmt.Println("  eval $(op signin)")
	case "pass":
		fmt.Println("Ensure GPG agent is running for pass")
	}

	markPhaseComplete(cfg, "vault")
	cfg.Features["vault"] = true
	fmt.Printf("%s Vault configured\n", green("✓"))
	return nil
}

func phaseSecrets(cfg *SetupConfig) error {
	showProgress(5, 7, "Secrets Management")

	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()

	if isPhaseCompleted(cfg, "secrets") {
		fmt.Printf("%s Secrets already configured\n", green("✓"))
		return nil
	}

	if cfg.Vault.Backend == "none" {
		fmt.Printf("%s Vault not configured - skipping secrets\n", yellow("!"))
		fmt.Println("Configure secrets manually in ~/.ssh, ~/.aws, ~/.gitconfig")
		markPhaseComplete(cfg, "secrets")
		return nil
	}

	fmt.Println("Secrets management allows syncing SSH keys, AWS config, and Git config")
	fmt.Println("between your local machine and your vault backend.")
	fmt.Println()
	fmt.Println("Available actions:")
	fmt.Println("  1) Scan local secrets and show status")
	fmt.Println("  2) Push local secrets to vault")
	fmt.Println("  3) Pull secrets from vault")
	fmt.Println("  4) Skip for now")
	fmt.Println()
	fmt.Print("Select action [4]: ")
	choice := readInput()
	if choice == "" {
		choice = "4"
	}

	dotfilesDir := DotfilesDir()

	switch choice {
	case "1":
		// Run drift check using Go CLI
		home, _ := os.UserHomeDir()
		green := color.New(color.FgGreen).SprintFunc()
		yellow := color.New(color.FgYellow).SprintFunc()
		cyan := color.New(color.FgCyan).SprintFunc()
		dim := color.New(color.Faint).SprintFunc()
		runDriftFull(home, green, yellow, cyan, dim)
	case "2":
		// Push to vault
		syncScript := filepath.Join(dotfilesDir, "vault", "sync-to-vault.sh")
		if _, err := os.Stat(syncScript); err == nil {
			cmd := exec.Command("bash", syncScript, "--all")
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			cmd.Run()
		}
	case "3":
		// Pull from vault
		restoreScript := filepath.Join(dotfilesDir, "vault", "restore.sh")
		if _, err := os.Stat(restoreScript); err == nil {
			cmd := exec.Command("bash", restoreScript, "--force")
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			cmd.Run()
		}
	default:
		fmt.Printf("%s Skipped secrets management\n", yellow("!"))
		fmt.Println("Run 'dotfiles sync' anytime to manage secrets")
	}

	markPhaseComplete(cfg, "secrets")
	fmt.Printf("%s Secrets phase complete\n", green("✓"))
	return nil
}

func phaseClaude(cfg *SetupConfig) error {
	showProgress(6, 7, "Claude Code (Optional)")

	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()

	if isPhaseCompleted(cfg, "claude") {
		fmt.Printf("%s Claude Code already configured\n", green("✓"))
		return nil
	}

	// Check if Claude is installed
	if _, err := exec.LookPath("claude"); err != nil {
		fmt.Println("Claude Code not detected - skipping")
		markPhaseComplete(cfg, "claude")
		return nil
	}

	// Check if dotclaude is installed
	if _, err := exec.LookPath("dotclaude"); err == nil {
		fmt.Printf("%s dotclaude already installed\n", green("✓"))
		markPhaseComplete(cfg, "claude")
		cfg.Features["claude_integration"] = true
		cfg.Features["dotclaude"] = true
		return nil
	}

	fmt.Println("Claude Code detected. dotclaude helps manage profiles across machines.")
	fmt.Print("Install dotclaude? [Y/n]: ")

	if input := readInput(); input == "" || strings.EqualFold(input, "y") {
		fmt.Println("Installing dotclaude...")
		cmd := exec.Command("bash", "-c", "curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotclaude/main/install.sh | bash")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			fmt.Printf("%s dotclaude installation failed - continuing\n", yellow("!"))
		} else {
			fmt.Printf("%s dotclaude installed\n", green("✓"))
			cfg.Features["claude_integration"] = true
			cfg.Features["dotclaude"] = true
		}
	} else {
		fmt.Println("Skipped dotclaude installation")
		fmt.Println("You can install later with: curl -fsSL https://dotclaude.sh | bash")
	}

	markPhaseComplete(cfg, "claude")
	return nil
}

func phaseTemplate(cfg *SetupConfig) error {
	showProgress(7, 7, "Machine-Specific Templates (Optional)")

	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()

	if isPhaseCompleted(cfg, "template") {
		fmt.Printf("%s Templates already configured\n", green("✓"))
		return nil
	}

	fmt.Println("Templates let you customize configs per machine (gitconfig, ssh-config, etc.).")
	fmt.Println("Examples:")
	fmt.Println("  • Work vs personal git email")
	fmt.Println("  • Different SSH keys per machine")
	fmt.Println("  • Machine-specific environment variables")
	fmt.Print("Setup machine-specific config templates? [y/N]: ")

	if strings.EqualFold(readInput(), "y") {
		fmt.Println("Initializing template system...")
		fmt.Println()

		templateCmd := filepath.Join(DotfilesDir(), "bin", "dotfiles-template")
		if _, err := os.Stat(templateCmd); err == nil {
			cmd := exec.Command("bash", templateCmd, "init")
			cmd.Stdin = os.Stdin
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				fmt.Printf("%s Template initialization skipped or failed\n", yellow("!"))
			} else {
				fmt.Printf("%s Templates configured\n", green("✓"))
				cfg.Features["templates"] = true
				fmt.Println()
				fmt.Println("Run 'dotfiles template render' to generate configs from your templates")
			}
		}
	} else {
		fmt.Println("Skipped template setup")
		fmt.Println()
		fmt.Println("You can enable templates later with: dotfiles template init")
	}

	markPhaseComplete(cfg, "template")
	return nil
}

// showPresetSelection offers feature preset selection
func showPresetSelection(cfg *SetupConfig) {
	bold := color.New(color.Bold).SprintFunc()
	green := color.New(color.FgGreen).SprintFunc()

	fmt.Println(bold("Feature Presets"))
	fmt.Println("Presets enable groups of shell features for different use cases.")
	fmt.Println()
	fmt.Println("  1) minimal    - Shell basics only (fastest startup)")
	fmt.Println("  2) developer  - + vault, git hooks, modern CLI tools")
	fmt.Println("  3) claude     - + Claude Code integration, workspace symlink")
	fmt.Println("  4) full       - All features enabled")
	fmt.Println("  5) Skip       - Configure features manually later")
	fmt.Println()
	fmt.Print("Select a preset [3]: ")
	choice := readInput()
	if choice == "" {
		choice = "3"
	}

	presets := map[string][]string{
		"minimal":   {"shell_basics", "aliases", "completions"},
		"developer": {"shell_basics", "aliases", "completions", "vault", "git_hooks", "modern_cli"},
		"claude":    {"shell_basics", "aliases", "completions", "vault", "git_hooks", "modern_cli", "claude_integration", "workspace_symlink"},
		"full":      {"shell_basics", "aliases", "completions", "vault", "git_hooks", "modern_cli", "claude_integration", "workspace_symlink", "templates", "dotclaude"},
	}

	var selectedPreset string
	switch choice {
	case "1":
		selectedPreset = "minimal"
	case "2":
		selectedPreset = "developer"
	case "3":
		selectedPreset = "claude"
	case "4":
		selectedPreset = "full"
	default:
		fmt.Println("Skipped preset selection")
		fmt.Println("Configure later with: dotfiles features preset <name> --persist")
		return
	}

	if features, ok := presets[selectedPreset]; ok {
		for _, f := range features {
			cfg.Features[f] = true
		}
		if err := saveSetupConfig(cfg); err != nil {
			fmt.Printf("Warning: failed to save preset: %v\n", err)
		}
		fmt.Printf("%s Applied '%s' preset\n", green("✓"), selectedPreset)
	}
	fmt.Println()
}

// showNextSteps displays dynamic next steps
func showNextSteps(cfg *SetupConfig) {
	cyan := color.New(color.FgCyan).SprintFunc()
	blue := color.New(color.FgBlue).SprintFunc()
	bold := color.New(color.Bold).SprintFunc()
	dim := color.New(color.Faint).SprintFunc()

	fmt.Println("Next steps based on your configuration:")
	fmt.Println()

	// Vault-specific next steps
	if cfg.Vault.Backend != "" && cfg.Vault.Backend != "none" {
		fmt.Printf("  %s Vault configured (%s)\n", cyan("✓"), cfg.Vault.Backend)
		fmt.Printf("    %s %s    %s\n", dim("→"), bold("dotfiles vault validate"), dim("# Validate vault schema (recommended)"))
		fmt.Printf("    %s %s     %s\n", dim("→"), bold("dotfiles vault restore"), dim("# Restore your secrets"))
		fmt.Println()
	}

	// Template-specific next steps
	templateFile := filepath.Join(DotfilesDir(), "templates", "_variables.local.sh")
	if _, err := os.Stat(templateFile); err == nil {
		fmt.Printf("  %s Templates configured\n", cyan("✓"))
		fmt.Printf("    %s %s   %s\n", dim("→"), bold("dotfiles template render"), dim("# Generate configs"))
		fmt.Println()
	}

	// Always show health check
	fmt.Printf("  %s Health check:\n", blue("ℹ"))
	fmt.Printf("    %s %s             %s\n", dim("→"), bold("dotfiles doctor"), dim("# Verify everything works"))
	fmt.Println()

	// Show helpful commands
	fmt.Printf("  %s Explore commands:\n", blue("ℹ"))
	fmt.Printf("    %s %s             %s\n", dim("→"), bold("dotfiles status"), dim("# Visual dashboard"))
	fmt.Printf("    %s %s               %s\n", dim("→"), bold("dotfiles help"), dim("# See all commands"))
	fmt.Println()

	// Check for installed tools and show relevant aliases
	hasFeatures := false
	features := []string{}

	if _, err := exec.LookPath("eza"); err == nil {
		features = append(features, fmt.Sprintf("    %s %s                %s", dim("→"), bold("ll, la, lt"), dim("# Enhanced ls (eza with icons)")))
		hasFeatures = true
	}
	if _, err := exec.LookPath("git"); err == nil {
		features = append(features, fmt.Sprintf("    %s %s              %s", dim("→"), bold("gst, gd, gco"), dim("# Git shortcuts")))
		hasFeatures = true
	}
	if _, err := exec.LookPath("fzf"); err == nil {
		features = append(features, fmt.Sprintf("    %s %s                    %s", dim("→"), bold("Ctrl+R"), dim("# Fuzzy history search (fzf)")))
		hasFeatures = true
	}
	if _, err := exec.LookPath("zoxide"); err == nil {
		features = append(features, fmt.Sprintf("    %s %s             %s", dim("→"), bold("z [directory]"), dim("# Smart cd (learns your habits)")))
		hasFeatures = true
	}
	if _, err := exec.LookPath("yazi"); err == nil {
		features = append(features, fmt.Sprintf("    %s %s                         %s", dim("→"), bold("y"), dim("# Terminal file manager (yazi)")))
		hasFeatures = true
	}

	if hasFeatures {
		fmt.Printf("  %s Your new shell features:\n", blue("ℹ"))
		for _, f := range features {
			fmt.Println(f)
		}
		fmt.Println()
	}

	// Documentation link
	fmt.Printf("  %s\n", dim("📚 Docs: https://github.com/blackwell-systems/dotfiles/docs"))
}
