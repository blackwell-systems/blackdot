package cli

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

func newPackagesCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "packages",
		Aliases: []string{"pkg"},
		Short:   "Check/install Brewfile packages",
		Long: `Package discovery and management.

Compares installed Homebrew packages against Brewfile.
Respects saved tier preference from config.json.

Modes:
  (default)     Show package status overview
  --check, -c   Show what's missing from Brewfile
  --install, -i Install missing packages
  --outdated, -o Show outdated packages

Tiers:
  minimal     ~18 packages  - Essentials only
  enhanced    ~43 packages  - Modern tools, no containers
  full        ~61 packages  - Everything (Docker, etc.)

Examples:
  blackdot packages                        # Status overview
  blackdot packages --check                # See what needs installing
  blackdot packages --install              # Install from saved tier
  blackdot packages --install --tier minimal  # Install minimal tier`,
		RunE: runPackages,
	}

	cmd.Flags().BoolP("check", "c", false, "Show what's missing from Brewfile")
	cmd.Flags().BoolP("install", "i", false, "Install missing packages")
	cmd.Flags().BoolP("outdated", "o", false, "Show outdated packages")
	cmd.Flags().StringP("tier", "t", "", "Use specific tier (minimal/enhanced/full)")

	return cmd
}

func runPackages(cmd *cobra.Command, args []string) error {
	checkMode, _ := cmd.Flags().GetBool("check")
	installMode, _ := cmd.Flags().GetBool("install")
	outdatedMode, _ := cmd.Flags().GetBool("outdated")
	tierOverride, _ := cmd.Flags().GetString("tier")

	// Colors
	bold := color.New(color.Bold).SprintFunc()
	dim := color.New(color.Faint).SprintFunc()
	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()
	red := color.New(color.FgRed).SprintFunc()
	cyan := color.New(color.FgCyan).SprintFunc()

	// Check for Homebrew
	if _, err := exec.LookPath("brew"); err != nil {
		fmt.Printf("%s Homebrew not installed\n", red("[FAIL]"))
		fmt.Println("Install with: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
		return fmt.Errorf("homebrew not installed")
	}

	// Determine dotfiles directory
	dotfilesDir := os.Getenv("BLACKDOT_DIR")
	if dotfilesDir == "" {
		home, _ := os.UserHomeDir()
		dotfilesDir = filepath.Join(home, ".blackdot")
	}

	// Determine tier
	tier := getPackageTier(tierOverride, dotfilesDir)

	// Map tier to Brewfile
	var brewfilePath string
	switch tier {
	case "minimal":
		brewfilePath = filepath.Join(dotfilesDir, "Brewfile.minimal")
	case "enhanced":
		brewfilePath = filepath.Join(dotfilesDir, "Brewfile.enhanced")
	default:
		brewfilePath = filepath.Join(dotfilesDir, "Brewfile")
		tier = "full"
	}

	// Check Brewfile exists, fall back to main if needed
	if _, err := os.Stat(brewfilePath); os.IsNotExist(err) {
		mainBrewfile := filepath.Join(dotfilesDir, "Brewfile")
		if _, err := os.Stat(mainBrewfile); err == nil {
			fmt.Printf("%s Brewfile for '%s' tier not found, using full Brewfile\n", yellow("[WARN]"), tier)
			brewfilePath = mainBrewfile
			tier = "full"
		} else {
			return fmt.Errorf("no Brewfile found at %s", brewfilePath)
		}
	}

	fmt.Println()
	fmt.Println(bold("Dotfiles Package Manager"))
	fmt.Println("========================")
	fmt.Printf("%s\n", dim(fmt.Sprintf("Tier: %s (%s)", tier, filepath.Base(brewfilePath))))
	fmt.Println()

	// Outdated mode
	if outdatedMode {
		fmt.Printf("%s Checking for outdated packages...\n", cyan("[INFO]"))
		fmt.Println()

		brewCmd := exec.Command("brew", "outdated")
		output, _ := brewCmd.Output()
		outdated := strings.TrimSpace(string(output))

		if outdated != "" {
			fmt.Println(outdated)
			fmt.Println()
			fmt.Printf("%s Run 'brew upgrade' to update packages\n", yellow("[WARN]"))
		} else {
			fmt.Printf("%s All packages are up to date\n", green("[OK]"))
		}
		return nil
	}

	// Parse Brewfile
	fmt.Printf("%s Analyzing Brewfile (%s tier)...\n", cyan("[INFO]"), tier)

	brewfileFormulas, brewfileCasks, err := parseBrewfile(brewfilePath)
	if err != nil {
		return fmt.Errorf("parsing Brewfile: %w", err)
	}

	// Get installed packages
	installedFormulas := getInstalledFormulas()
	installedCasks := getInstalledCasks()

	// Find missing packages
	missingFormulas := findMissing(brewfileFormulas, installedFormulas)
	missingCasks := findMissing(brewfileCasks, installedCasks)

	// Display results
	if checkMode || len(missingFormulas) > 0 || len(missingCasks) > 0 {
		fmt.Println()
		fmt.Printf("%s\n", bold(fmt.Sprintf("Brewfile Summary (%s):", tier)))
		fmt.Printf("  Formulas defined: %d\n", len(brewfileFormulas))
		fmt.Printf("  Casks defined: %d\n", len(brewfileCasks))
		fmt.Println()
		fmt.Printf("%s\n", bold("Installed:"))
		fmt.Printf("  Formulas: %d\n", len(installedFormulas))
		fmt.Printf("  Casks: %d\n", len(installedCasks))
		fmt.Println()
	}

	if len(missingFormulas) > 0 {
		fmt.Printf("%s Missing formulas (%d):\n", yellow("[WARN]"), len(missingFormulas))
		for _, formula := range missingFormulas {
			fmt.Printf("  - %s\n", formula)
		}
		fmt.Println()
	}

	if len(missingCasks) > 0 {
		fmt.Printf("%s Missing casks (%d):\n", yellow("[WARN]"), len(missingCasks))
		for _, cask := range missingCasks {
			fmt.Printf("  - %s\n", cask)
		}
		fmt.Println()
	}

	// Install mode
	if installMode {
		if len(missingFormulas) == 0 && len(missingCasks) == 0 {
			fmt.Printf("%s All Brewfile packages are installed (%s tier)\n", green("[OK]"), tier)
			return nil
		}

		fmt.Printf("%s Installing missing packages from %s tier...\n", cyan("[INFO]"), tier)
		fmt.Println()

		// Check if already all installed
		checkCmd := exec.Command("brew", "bundle", "check", "--file="+brewfilePath)
		if checkCmd.Run() == nil {
			fmt.Printf("%s All packages already installed\n", green("[OK]"))
			return nil
		}

		// Install via brew bundle
		installCmd := exec.Command("brew", "bundle", "install", "--file="+brewfilePath)
		installCmd.Stdout = os.Stdout
		installCmd.Stderr = os.Stderr
		if err := installCmd.Run(); err != nil {
			fmt.Printf("%s Some packages failed to install\n", red("[FAIL]"))
			return err
		}
		fmt.Printf("%s Packages installed successfully (%s tier)\n", green("[OK]"), tier)
		return nil
	}

	// Default summary mode
	if len(missingFormulas) == 0 && len(missingCasks) == 0 {
		fmt.Printf("%s All Brewfile packages are installed (%s tier)\n", green("[OK]"), tier)
	} else {
		totalMissing := len(missingFormulas) + len(missingCasks)
		fmt.Printf("%s %d package(s) missing from %s tier\n", yellow("[WARN]"), totalMissing, tier)
		fmt.Println()
		fmt.Println("Run 'blackdot packages --check' for details")
		fmt.Println("Run 'blackdot packages --install' to install")
		fmt.Println()
		fmt.Println(dim("Change tier with: blackdot packages --tier minimal|enhanced|full"))
	}

	// Suggest dotclaude for Claude users
	if _, err := exec.LookPath("claude"); err == nil {
		if _, err := exec.LookPath("dotclaude"); err != nil {
			fmt.Println()
			fmt.Printf("%s Claude Code detected without dotclaude\n", cyan("[INFO]"))
			fmt.Println("     Manage profiles across machines with dotclaude:")
			fmt.Println("     See: github.com/blackwell-systems/dotclaude")
		}
	}

	return nil
}

// getPackageTier determines which tier to use
// Priority: --tier flag > config.json > BREWFILE_TIER env > default (full)
func getPackageTier(tierOverride, dotfilesDir string) string {
	// 1. Command line override
	if tierOverride != "" {
		return tierOverride
	}

	// 2. Config file (packages.tier)
	home, _ := os.UserHomeDir()
	configPath := filepath.Join(home, ".config", "blackdot", "config.json")
	if data, err := os.ReadFile(configPath); err == nil {
		var cfg map[string]interface{}
		if json.Unmarshal(data, &cfg) == nil {
			if packages, ok := cfg["packages"].(map[string]interface{}); ok {
				if tier, ok := packages["tier"].(string); ok && tier != "" {
					return tier
				}
			}
		}
	}

	// 3. Environment variable
	if tier := os.Getenv("BREWFILE_TIER"); tier != "" {
		return tier
	}

	// 4. Default
	return "full"
}

// parseBrewfile extracts formula and cask names from a Brewfile
func parseBrewfile(path string) (formulas, casks []string, err error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, nil, err
	}
	defer file.Close()

	brewRe := regexp.MustCompile(`^brew\s+["']([^"']+)["']`)
	caskRe := regexp.MustCompile(`^cask\s+["']([^"']+)["']`)

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		// Skip comments and empty lines
		if strings.HasPrefix(line, "#") || line == "" {
			continue
		}

		if match := brewRe.FindStringSubmatch(line); match != nil {
			formulas = append(formulas, match[1])
		} else if match := caskRe.FindStringSubmatch(line); match != nil {
			casks = append(casks, match[1])
		}
	}

	return formulas, casks, scanner.Err()
}

// getInstalledFormulas returns list of installed Homebrew formulas
func getInstalledFormulas() []string {
	cmd := exec.Command("brew", "list", "--formula")
	output, err := cmd.Output()
	if err != nil {
		return nil
	}
	return strings.Fields(string(output))
}

// getInstalledCasks returns list of installed Homebrew casks
func getInstalledCasks() []string {
	cmd := exec.Command("brew", "list", "--cask")
	output, err := cmd.Output()
	if err != nil {
		return nil
	}
	return strings.Fields(string(output))
}

// findMissing returns items from wanted that are not in installed
func findMissing(wanted, installed []string) []string {
	installedSet := make(map[string]bool)
	for _, item := range installed {
		installedSet[item] = true
	}

	var missing []string
	for _, item := range wanted {
		if !installedSet[item] {
			missing = append(missing, item)
		}
	}
	return missing
}
