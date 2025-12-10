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

// Hook point categories with descriptions
var hookCategories = []struct {
	Name   string
	Points []struct {
		Name string
		Desc string
	}
}{
	{
		Name: "Lifecycle",
		Points: []struct {
			Name string
			Desc string
		}{
			{"pre_install", "Before install.sh runs"},
			{"post_install", "After install.sh completes"},
			{"pre_bootstrap", "Before bootstrap script"},
			{"post_bootstrap", "After bootstrap completes"},
			{"pre_upgrade", "Before dotfiles upgrade"},
			{"post_upgrade", "After upgrade completes"},
		},
	},
	{
		Name: "Vault",
		Points: []struct {
			Name string
			Desc string
		}{
			{"pre_vault_pull", "Before restoring secrets"},
			{"post_vault_pull", "After secrets restored (e.g., ssh-add, chmod)"},
			{"pre_vault_push", "Before syncing to vault"},
			{"post_vault_push", "After vault sync"},
		},
	},
	{
		Name: "Doctor",
		Points: []struct {
			Name string
			Desc string
		}{
			{"pre_doctor", "Before health check"},
			{"post_doctor", "After health check (e.g., report to monitoring)"},
			{"doctor_check", "During doctor (adds custom checks)"},
		},
	},
	{
		Name: "Shell",
		Points: []struct {
			Name string
			Desc string
		}{
			{"shell_init", "End of .zshrc (load project-specific config)"},
			{"shell_exit", "Shell exit via zshexit"},
			{"directory_change", "On cd via chpwd (auto-activate envs)"},
		},
	},
	{
		Name: "Setup Wizard",
		Points: []struct {
			Name string
			Desc string
		}{
			{"pre_setup_phase", "Before each wizard phase"},
			{"post_setup_phase", "After each wizard phase"},
			{"setup_complete", "After all phases done"},
		},
	},
	{
		Name: "Template",
		Points: []struct {
			Name string
			Desc string
		}{
			{"pre_template_render", "Before template rendering (auto-decrypt .age files)"},
			{"post_template_render", "After templates rendered (validation, notifications)"},
		},
	},
	{
		Name: "Encryption",
		Points: []struct {
			Name string
			Desc string
		}{
			{"pre_encrypt", "Before file encryption (custom pre-processing)"},
			{"post_decrypt", "After file decryption (permission fixes, validation)"},
		},
	},
}

// HooksConfig represents the hooks.json configuration
type HooksConfig struct {
	Hooks    map[string][]HookEntry `json:"hooks"`
	Settings HookSettings           `json:"settings"`
}

// HookEntry represents a single hook configuration
type HookEntry struct {
	Name     string `json:"name"`
	Command  string `json:"command,omitempty"`
	Script   string `json:"script,omitempty"`
	Function string `json:"function,omitempty"`
	Enabled  *bool  `json:"enabled,omitempty"`
	FailOk   bool   `json:"fail_ok,omitempty"`
}

// HookSettings represents hook system settings
type HookSettings struct {
	FailFast bool `json:"fail_fast"`
	Verbose  bool `json:"verbose"`
	Timeout  int  `json:"timeout"`
}

func newHookCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "hook",
		Aliases: []string{"hooks"},
		Short:   "Hook system management",
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 {
				printHookHelp()
				return nil
			}
			return runHookList(args)
		},
	}

	// Set custom help function
	cmd.SetHelpFunc(func(cmd *cobra.Command, args []string) {
		printHookHelp()
	})

	listCmd := &cobra.Command{
		Use:     "list [point]",
		Aliases: []string{"ls"},
		Short:   "List hooks (all points or specific point)",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runHookList(args)
		},
	}

	runCmd := &cobra.Command{
		Use:   "run <point> [args]",
		Short: "Manually trigger hooks for a point",
		RunE: func(cmd *cobra.Command, args []string) error {
			verbose, _ := cmd.Flags().GetBool("verbose")
			return runHookRun(args, verbose)
		},
	}
	runCmd.Flags().BoolP("verbose", "v", false, "Show detailed output")

	cmd.AddCommand(
		listCmd,
		runCmd,
		&cobra.Command{
			Use:   "add <point> <script>",
			Short: "Add a hook script to a point",
			RunE: func(cmd *cobra.Command, args []string) error {
				return runHookAdd(args)
			},
		},
		&cobra.Command{
			Use:     "remove <point> <name>",
			Aliases: []string{"rm"},
			Short:   "Remove a hook script",
			RunE: func(cmd *cobra.Command, args []string) error {
				return runHookRemove(args)
			},
		},
		&cobra.Command{
			Use:   "points",
			Short: "List all available hook points",
			RunE: func(cmd *cobra.Command, args []string) error {
				return runHookPoints()
			},
		},
		&cobra.Command{
			Use:   "test <point>",
			Short: "Test hooks for a point (verbose dry-run)",
			RunE: func(cmd *cobra.Command, args []string) error {
				return runHookTest(args)
			},
		},
	)

	return cmd
}

func getHooksDir() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "dotfiles", "hooks")
}

func getHooksConfigPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "dotfiles", "hooks.json")
}

func isValidHookPoint(point string) bool {
	for _, cat := range hookCategories {
		for _, p := range cat.Points {
			if p.Name == point {
				return true
			}
		}
	}
	return false
}

func getAllHookPoints() []string {
	var points []string
	for _, cat := range hookCategories {
		for _, p := range cat.Points {
			points = append(points, p.Name)
		}
	}
	return points
}

func loadHooksConfig() (*HooksConfig, error) {
	configPath := getHooksConfigPath()
	data, err := os.ReadFile(configPath)
	if err != nil {
		if os.IsNotExist(err) {
			return &HooksConfig{
				Hooks:    make(map[string][]HookEntry),
				Settings: HookSettings{Timeout: 30},
			}, nil
		}
		return nil, err
	}

	var config HooksConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	if config.Hooks == nil {
		config.Hooks = make(map[string][]HookEntry)
	}

	return &config, nil
}

func runHookList(args []string) error {
	bold := color.New(color.Bold).SprintFunc()
	cyan := color.New(color.FgCyan).SprintFunc()
	green := color.New(color.FgGreen).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()
	dim := color.New(color.Faint).SprintFunc()

	hooksDir := getHooksDir()
	config, _ := loadHooksConfig()

	if len(args) > 0 {
		// List hooks for specific point
		point := args[0]
		if !isValidHookPoint(point) {
			fmt.Printf("%s Invalid hook point: %s\n", color.RedString("[FAIL]"), point)
			fmt.Println()
			fmt.Println("Valid hook points:")
			for _, p := range getAllHookPoints() {
				fmt.Printf("  %s\n", p)
			}
			return fmt.Errorf("invalid hook point: %s", point)
		}

		fmt.Printf("%s\n", bold(fmt.Sprintf("Hooks for: %s", cyan(point))))
		fmt.Println("═══════════════════════════════════════════════════════════════")
		fmt.Println()

		hasHooks := false

		// File-based hooks
		pointDir := filepath.Join(hooksDir, point)
		var allFiles []string

		if shFiles, err := filepath.Glob(filepath.Join(pointDir, "*.sh")); err == nil {
			allFiles = append(allFiles, shFiles...)
		}
		if zshFiles, err := filepath.Glob(filepath.Join(pointDir, "*.zsh")); err == nil {
			allFiles = append(allFiles, zshFiles...)
		}

		if len(allFiles) > 0 {
			fmt.Printf("%s %s\n", bold("File-based hooks:"), dim(fmt.Sprintf("(%s)", pointDir)))
			hasHooks = true
			for _, f := range allFiles {
				name := filepath.Base(f)
				info, err := os.Stat(f)
				if err != nil {
					continue
				}
				if info.Mode()&0111 != 0 {
					fmt.Printf("  %s %s %s\n", green("●"), name, dim("(executable)"))
				} else {
					fmt.Printf("  %s %s %s\n", yellow("○"), name, dim("(not executable - will be skipped)"))
				}
			}
			fmt.Println()
		}

		// JSON configured hooks
		if hooks, ok := config.Hooks[point]; ok && len(hooks) > 0 {
			fmt.Printf("%s %s\n", bold("JSON configured:"), dim(fmt.Sprintf("(%s)", getHooksConfigPath())))
			hasHooks = true
			for _, hook := range hooks {
				enabled := hook.Enabled == nil || *hook.Enabled
				typeLabel := ""
				if hook.Command != "" {
					typeLabel = "command"
				} else if hook.Script != "" {
					typeLabel = "script: " + hook.Script
				} else if hook.Function != "" {
					typeLabel = "function: " + hook.Function
				}

				if enabled {
					fmt.Printf("  %s %s %s\n", green("●"), hook.Name, dim(fmt.Sprintf("(%s)", typeLabel)))
				} else {
					fmt.Printf("  %s %s %s\n", dim("○"), hook.Name, dim(fmt.Sprintf("(disabled, %s)", typeLabel)))
				}
			}
			fmt.Println()
		}

		if !hasHooks {
			fmt.Printf("%s\n", dim("No hooks registered for this point."))
			fmt.Println()
			fmt.Println("Add hooks by:")
			fmt.Printf("  1. Creating scripts in: %s/\n", pointDir)
			fmt.Printf("  2. Adding to JSON config: %s\n", getHooksConfigPath())
		}
	} else {
		// List all hook points
		fmt.Println(bold("Hook System"))
		fmt.Println("═══════════════════════════════════════════════════════════════")
		fmt.Println()

		for _, cat := range hookCategories {
			fmt.Printf("%s\n", bold(cyan(cat.Name)))
			fmt.Println("───────────────────────────────────────────────────────────────")

			for _, p := range cat.Points {
				count := 0

				// Count file-based hooks
				pointDir := filepath.Join(hooksDir, p.Name)
				if shFiles, err := filepath.Glob(filepath.Join(pointDir, "*.sh")); err == nil {
					count += len(shFiles)
				}
				if zshFiles, err := filepath.Glob(filepath.Join(pointDir, "*.zsh")); err == nil {
					count += len(zshFiles)
				}

				// Count JSON hooks
				if hooks, ok := config.Hooks[p.Name]; ok {
					count += len(hooks)
				}

				if count > 0 {
					fmt.Printf("  %s %-25s %d hook(s)\n", green("●"), p.Name, count)
				} else {
					fmt.Printf("  %s %-25s %s\n", dim("○"), p.Name, dim("no hooks"))
				}
			}
			fmt.Println()
		}

		fmt.Printf("%s\n", dim("Use 'blackdot hook list <point>' for details on a specific point."))
	}

	return nil
}

func runHookRun(args []string, verbose bool) error {
	if len(args) == 0 {
		fmt.Println(color.RedString("[FAIL]") + " Hook point required")
		fmt.Println("Usage: dotfiles hook run [--verbose] <point> [args...]")
		return fmt.Errorf("hook point required")
	}

	point := args[0]
	hookArgs := args[1:]

	if !isValidHookPoint(point) {
		fmt.Printf("%s Invalid hook point: %s\n", color.RedString("[FAIL]"), point)
		return fmt.Errorf("invalid hook point: %s", point)
	}

	fmt.Printf("%s Running hooks for: %s\n", color.CyanString("[INFO]"), point)

	failed := false
	hooksDir := getHooksDir()
	config, _ := loadHooksConfig()
	timeout := 30
	if config.Settings.Timeout > 0 {
		timeout = config.Settings.Timeout
	}

	// Run file-based hooks
	pointDir := filepath.Join(hooksDir, point)
	patterns := []string{"*.sh", "*.zsh"}
	for _, pattern := range patterns {
		files, err := filepath.Glob(filepath.Join(pointDir, pattern))
		if err != nil {
			continue
		}
		for _, script := range files {
			info, err := os.Stat(script)
			if err != nil || info.Mode()&0111 == 0 {
				if verbose {
					fmt.Printf("  Skipping non-executable: %s\n", script)
				}
				continue
			}

			if verbose {
				fmt.Printf("  Running: %s\n", script)
			}

			cmd := exec.Command(script, hookArgs...)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr

			done := make(chan error)
			go func() {
				done <- cmd.Run()
			}()

			select {
			case err := <-done:
				if err != nil {
					fmt.Printf("  Hook failed: %s (%v)\n", script, err)
					failed = true
					if config.Settings.FailFast {
						return fmt.Errorf("hook failed: %s", script)
					}
				}
			case <-time.After(time.Duration(timeout) * time.Second):
				if cmd.Process != nil {
					cmd.Process.Kill()
				}
				fmt.Printf("  Hook timed out: %s\n", script)
				failed = true
			}
		}
	}

	// Run JSON configured hooks
	if hooks, ok := config.Hooks[point]; ok {
		for _, hook := range hooks {
			enabled := hook.Enabled == nil || *hook.Enabled
			if !enabled {
				if verbose {
					fmt.Printf("  Skipping disabled: %s\n", hook.Name)
				}
				continue
			}

			var err error
			if hook.Command != "" {
				if verbose {
					fmt.Printf("  Running command (%s): %s\n", hook.Name, hook.Command)
				}
				cmd := exec.Command("sh", "-c", hook.Command)
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				err = cmd.Run()
			} else if hook.Script != "" {
				script := hook.Script
				if strings.HasPrefix(script, "~") {
					home, _ := os.UserHomeDir()
					script = filepath.Join(home, script[1:])
				}
				if verbose {
					fmt.Printf("  Running script (%s): %s\n", hook.Name, script)
				}
				cmd := exec.Command(script, hookArgs...)
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				err = cmd.Run()
			}

			if err != nil && !hook.FailOk {
				fmt.Printf("  Hook failed: %s (%v)\n", hook.Name, err)
				failed = true
				if config.Settings.FailFast {
					return fmt.Errorf("hook failed: %s", hook.Name)
				}
			}
		}
	}

	if failed {
		fmt.Println(color.RedString("[FAIL]") + " One or more hooks failed")
		return fmt.Errorf("one or more hooks failed")
	}

	fmt.Println(color.GreenString("[OK]") + " Hooks completed successfully")
	return nil
}

func runHookAdd(args []string) error {
	if len(args) < 2 {
		fmt.Println(color.RedString("[FAIL]") + " Both hook point and script path required")
		fmt.Println("Usage: dotfiles hook add <point> <script>")
		return fmt.Errorf("missing arguments")
	}

	point := args[0]
	script := args[1]

	if !isValidHookPoint(point) {
		fmt.Printf("%s Invalid hook point: %s\n", color.RedString("[FAIL]"), point)
		return fmt.Errorf("invalid hook point: %s", point)
	}

	// Check script exists
	if _, err := os.Stat(script); os.IsNotExist(err) {
		fmt.Printf("%s Script not found: %s\n", color.RedString("[FAIL]"), script)
		return fmt.Errorf("script not found: %s", script)
	}

	// Create hooks directory
	hooksDir := getHooksDir()
	pointDir := filepath.Join(hooksDir, point)
	if err := os.MkdirAll(pointDir, 0755); err != nil {
		return fmt.Errorf("creating hooks directory: %w", err)
	}

	// Copy script
	basename := filepath.Base(script)
	dest := filepath.Join(pointDir, basename)

	if _, err := os.Stat(dest); err == nil {
		fmt.Printf("%s Hook already exists: %s\n", color.YellowString("[WARN]"), dest)
		fmt.Print("Overwrite? [y/N] ")
		var response string
		fmt.Scanln(&response)
		if response != "y" && response != "Y" {
			fmt.Println(color.CyanString("[INFO]") + " Cancelled")
			return nil
		}
	}

	// Read and write script
	content, err := os.ReadFile(script)
	if err != nil {
		return fmt.Errorf("reading script: %w", err)
	}

	if err := os.WriteFile(dest, content, 0755); err != nil {
		return fmt.Errorf("writing script: %w", err)
	}

	fmt.Printf("%s Added hook: %s\n", color.GreenString("[OK]"), dest)
	fmt.Printf("%s Hook will run during: %s\n", color.CyanString("[INFO]"), point)
	return nil
}

func runHookRemove(args []string) error {
	if len(args) < 2 {
		fmt.Println(color.RedString("[FAIL]") + " Both hook point and hook name required")
		fmt.Println("Usage: dotfiles hook remove <point> <name>")
		return fmt.Errorf("missing arguments")
	}

	point := args[0]
	name := args[1]

	if !isValidHookPoint(point) {
		fmt.Printf("%s Invalid hook point: %s\n", color.RedString("[FAIL]"), point)
		return fmt.Errorf("invalid hook point: %s", point)
	}

	hooksDir := getHooksDir()
	hookPath := filepath.Join(hooksDir, point, name)

	if _, err := os.Stat(hookPath); os.IsNotExist(err) {
		fmt.Printf("%s Hook not found: %s\n", color.RedString("[FAIL]"), hookPath)
		fmt.Println()
		pointDir := filepath.Join(hooksDir, point)
		fmt.Printf("Available hooks in %s:\n", pointDir)
		if files, err := filepath.Glob(filepath.Join(pointDir, "*")); err == nil && len(files) > 0 {
			for _, f := range files {
				fmt.Printf("  %s\n", filepath.Base(f))
			}
		} else {
			fmt.Println("  (none)")
		}
		return fmt.Errorf("hook not found")
	}

	if err := os.Remove(hookPath); err != nil {
		return fmt.Errorf("removing hook: %w", err)
	}

	fmt.Printf("%s Removed hook: %s\n", color.GreenString("[OK]"), hookPath)
	return nil
}

func runHookPoints() error {
	bold := color.New(color.Bold).SprintFunc()
	cyan := color.New(color.FgCyan).SprintFunc()

	fmt.Println(bold("Available Hook Points"))
	fmt.Println("═══════════════════════════════════════════════════════════════")
	fmt.Println()

	for _, cat := range hookCategories {
		fmt.Println(cyan(cat.Name + " Hooks"))
		for _, p := range cat.Points {
			fmt.Printf("  %-22s %s\n", p.Name, p.Desc)
		}
		fmt.Println()
	}

	return nil
}

func runHookTest(args []string) error {
	if len(args) == 0 {
		fmt.Println(color.RedString("[FAIL]") + " Hook point required")
		fmt.Println("Usage: dotfiles hook test <point>")
		return fmt.Errorf("hook point required")
	}

	point := args[0]

	if !isValidHookPoint(point) {
		fmt.Printf("%s Invalid hook point: %s\n", color.RedString("[FAIL]"), point)
		return fmt.Errorf("invalid hook point: %s", point)
	}

	bold := color.New(color.Bold).SprintFunc()
	cyan := color.New(color.FgCyan).SprintFunc()

	fmt.Printf("%s\n", bold(fmt.Sprintf("Testing hooks for: %s", cyan(point))))
	fmt.Println("═══════════════════════════════════════════════════════════════")
	fmt.Println()

	// Show what would run
	runHookList([]string{point})

	fmt.Println("───────────────────────────────────────────────────────────────")
	fmt.Println(bold("Executing with --verbose:"))
	fmt.Println()

	// Run with verbose
	err := runHookRun([]string{point}, true)

	fmt.Println()
	if err != nil {
		fmt.Printf("%s One or more hooks failed\n", color.RedString("[FAIL]"))
		return err
	}

	fmt.Printf("%s All hooks completed successfully\n", color.GreenString("[OK]"))
	return nil
}

// printHookHelp prints styled help matching ZSH format
func printHookHelp() {
	// Title
	BoldCyan.Print("dotfiles hook")
	fmt.Print(" - Hook system management\n")
	fmt.Println()
	Bold.Print("Usage:")
	fmt.Print(" dotfiles hook <command> [options]\n")
	fmt.Println()

	// Commands
	BoldCyan.Println("Commands:")
	printCmd("list [point]", "List hooks (all points or specific point)")
	printCmd("run <point>", "Manually trigger hooks for a point")
	printCmd("add <point> <script>", "Add a hook script to a point")
	printCmd("remove <point> <name>", "Remove a hook script")
	printCmd("points", "List all available hook points")
	printCmd("test <point>", "Test hooks for a point (verbose dry-run)")
	fmt.Println()

	// Hook Points by Category
	BoldCyan.Println("Hook Points:")
	fmt.Println()

	for _, cat := range hookCategories {
		fmt.Print("  ")
		Yellow.Print(cat.Name)
		fmt.Println()
		for _, p := range cat.Points {
			fmt.Print("    ")
			Dim.Printf("%-24s", p.Name)
			Dim.Println(p.Desc)
		}
		fmt.Println()
	}

	// Configuration
	BoldCyan.Println("Configuration:")
	fmt.Print("  ")
	Yellow.Print("Hooks directory")
	fmt.Print("   ")
	Dim.Println("~/.config/dotfiles/hooks/")
	fmt.Print("  ")
	Yellow.Print("JSON config")
	fmt.Print("       ")
	Dim.Println("~/.config/dotfiles/hooks.json")
	fmt.Println()

	// Examples
	BoldCyan.Println("Examples:")
	Dim.Println("  # List all hooks")
	fmt.Println("  dotfiles hook list")
	fmt.Println()
	Dim.Println("  # List hooks for specific point")
	fmt.Println("  dotfiles hook list post_vault_pull")
	fmt.Println()
	Dim.Println("  # Run hooks manually")
	fmt.Println("  dotfiles hook run shell_init --verbose")
	fmt.Println()
	Dim.Println("  # Add a hook script")
	fmt.Println("  dotfiles hook add post_vault_pull ~/scripts/ssh-add-keys.sh")
	fmt.Println()

	// Environment Variables
	BoldCyan.Println("Environment Variables:")
	fmt.Print("  ")
	Yellow.Print("BLACKDOT_HOOKS_DISABLED")
	fmt.Print("  ")
	Dim.Println("Disable all hooks (true/false)")
	fmt.Print("  ")
	Yellow.Print("BLACKDOT_HOOKS_VERBOSE")
	fmt.Print("   ")
	Dim.Println("Enable verbose output (true/false)")
	fmt.Print("  ")
	Yellow.Print("BLACKDOT_HOOKS_FAIL_FAST")
	fmt.Print("  ")
	Dim.Println("Stop on first failure (true/false)")
	fmt.Print("  ")
	Yellow.Print("BLACKDOT_HOOKS_TIMEOUT")
	fmt.Print("    ")
	Dim.Println("Hook timeout in seconds (default: 30)")
}
