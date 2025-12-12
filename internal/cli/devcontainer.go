package cli

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/spf13/cobra"
)

// DevcontainerImage represents a base image option
type DevcontainerImage struct {
	Name        string
	Image       string
	Description string
	Extensions  []string // VS Code extensions to recommend
}

// Common devcontainer base images from Microsoft
var devcontainerImages = []DevcontainerImage{
	{
		Name:        "Go 1.23",
		Image:       "mcr.microsoft.com/devcontainers/go:1.23",
		Description: "Go development with tools",
		Extensions:  []string{"golang.go"},
	},
	{
		Name:        "Rust",
		Image:       "mcr.microsoft.com/devcontainers/rust:latest",
		Description: "Rust development with cargo",
		Extensions:  []string{"rust-lang.rust-analyzer"},
	},
	{
		Name:        "Python 3.13",
		Image:       "mcr.microsoft.com/devcontainers/python:3.13",
		Description: "Python development",
		Extensions:  []string{"ms-python.python"},
	},
	{
		Name:        "Node 22 (TypeScript)",
		Image:       "mcr.microsoft.com/devcontainers/typescript-node:22",
		Description: "Node.js LTS with TypeScript",
		Extensions:  []string{"dbaeumer.vscode-eslint"},
	},
	{
		Name:        "Java 21",
		Image:       "mcr.microsoft.com/devcontainers/java:21",
		Description: "Java development (LTS)",
		Extensions:  []string{"vscjava.vscode-java-pack"},
	},
	{
		Name:        "Ubuntu",
		Image:       "mcr.microsoft.com/devcontainers/base:ubuntu",
		Description: "Base Ubuntu image",
		Extensions:  []string{},
	},
	{
		Name:        "Alpine",
		Image:       "mcr.microsoft.com/devcontainers/base:alpine",
		Description: "Lightweight Alpine image",
		Extensions:  []string{},
	},
	{
		Name:        "Debian",
		Image:       "mcr.microsoft.com/devcontainers/base:debian",
		Description: "Base Debian image",
		Extensions:  []string{},
	},
}

// DevcontainerPreset represents a blackdot preset option
type DevcontainerPreset struct {
	Name        string
	Description string
}

var devcontainerPresets = []DevcontainerPreset{
	{"minimal", "Shell config only (fastest startup)"},
	{"developer", "Vault, AWS, Git hooks, modern CLI tools"},
	{"claude", "Claude Code integration + vault + git hooks"},
	{"full", "All features enabled"},
}

// DevcontainerConfig represents the generated devcontainer.json
type DevcontainerConfig struct {
	Name             string                       `json:"name"`
	Image            string                       `json:"image"`
	Features         map[string]map[string]string `json:"features"`
	PostStartCommand string                       `json:"postStartCommand"`
	Customizations   *DevcontainerCustomizations  `json:"customizations,omitempty"`
	RemoteUser       string                       `json:"remoteUser,omitempty"`
	Mounts           []string                     `json:"mounts,omitempty"`
	ContainerEnv     map[string]string            `json:"containerEnv,omitempty"`
}

type DevcontainerCustomizations struct {
	VSCode *VSCodeCustomizations `json:"vscode,omitempty"`
}

type VSCodeCustomizations struct {
	Extensions []string `json:"extensions,omitempty"`
}

func newDevcontainerCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "devcontainer",
		Short: "Manage devcontainer configuration",
		Long: `Generate and manage devcontainer configuration for your project.

Devcontainers provide reproducible development environments that work with
GitHub Codespaces, VS Code Remote Containers, and other compatible tools.

Blackdot integrates with devcontainers to bring your vault-backed
configuration into containerized environments.`,
	}

	cmd.AddCommand(
		newDevcontainerInitCmd(),
		newDevcontainerImagesCmd(),
	)

	return cmd
}

func newDevcontainerInitCmd() *cobra.Command {
	var (
		image   string
		preset  string
		output  string
		force   bool
		noVSExt bool
	)

	cmd := &cobra.Command{
		Use:   "init",
		Short: "Generate devcontainer configuration",
		Long: `Generate a .devcontainer/devcontainer.json file for your project.

This command creates a devcontainer configuration that includes:
  - A Microsoft base image for your language/platform
  - The blackdot devcontainer feature for config management
  - VS Code extension recommendations

Examples:
  blackdot devcontainer init                    # Interactive mode
  blackdot devcontainer init --image go --preset developer
  blackdot devcontainer init --image python --preset claude --force`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runDevcontainerInit(image, preset, output, force, noVSExt)
		},
	}

	cmd.Flags().StringVar(&image, "image", "", "Base image (go, rust, python, node, java, ubuntu, alpine, debian)")
	cmd.Flags().StringVar(&preset, "preset", "", "Blackdot preset (minimal, developer, claude, full)")
	cmd.Flags().StringVarP(&output, "output", "o", ".devcontainer", "Output directory")
	cmd.Flags().BoolVarP(&force, "force", "f", false, "Overwrite existing configuration")
	cmd.Flags().BoolVar(&noVSExt, "no-extensions", false, "Skip VS Code extension recommendations")

	return cmd
}

func newDevcontainerImagesCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "images",
		Short: "List available base images",
		Long:  `List all available Microsoft devcontainer base images.`,
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println()
			BoldCyan.Println("Available Devcontainer Base Images")
			fmt.Println(strings.Repeat("─", 50))
			fmt.Println()

			for i, img := range devcontainerImages {
				fmt.Printf("  %d. ", i+1)
				Bold.Print(img.Name)
				fmt.Println()
				Dim.Printf("     %s\n", img.Image)
				Dim.Printf("     %s\n", img.Description)
				fmt.Println()
			}
		},
	}
}

func runDevcontainerInit(imageFlag, presetFlag, outputDir string, force, noVSExt bool) error {
	fmt.Println()
	BoldCyan.Println("Blackdot Devcontainer Setup")
	fmt.Println(strings.Repeat("═", 30))
	fmt.Println()

	// Select image
	var selectedImage DevcontainerImage
	if imageFlag != "" {
		// Find image by short name
		found := false
		for _, img := range devcontainerImages {
			shortName := strings.ToLower(strings.Split(img.Name, " ")[0])
			if strings.ToLower(imageFlag) == shortName {
				selectedImage = img
				found = true
				break
			}
		}
		if !found {
			return fmt.Errorf("unknown image: %s (use 'blackdot devcontainer images' to list available images)", imageFlag)
		}
	} else {
		// Interactive selection
		img, err := selectImage()
		if err != nil {
			return err
		}
		selectedImage = img
	}

	// Select preset
	var selectedPreset string
	if presetFlag != "" {
		// Validate preset
		valid := false
		for _, p := range devcontainerPresets {
			if strings.ToLower(presetFlag) == p.Name {
				selectedPreset = p.Name
				valid = true
				break
			}
		}
		if !valid {
			return fmt.Errorf("unknown preset: %s (valid: minimal, developer, claude, full)", presetFlag)
		}
	} else {
		// Interactive selection
		preset, err := selectPreset()
		if err != nil {
			return err
		}
		selectedPreset = preset
	}

	// Check output directory
	devcontainerPath := filepath.Join(outputDir, "devcontainer.json")
	if _, err := os.Stat(devcontainerPath); err == nil && !force {
		return fmt.Errorf("devcontainer.json already exists (use --force to overwrite)")
	}

	// Generate configuration
	config := generateDevcontainerConfig(selectedImage, selectedPreset, noVSExt)

	// Create output directory
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		return fmt.Errorf("creating output directory: %w", err)
	}

	// Write devcontainer.json
	jsonData, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return fmt.Errorf("marshaling config: %w", err)
	}

	if err := os.WriteFile(devcontainerPath, jsonData, 0644); err != nil {
		return fmt.Errorf("writing devcontainer.json: %w", err)
	}

	// Success output
	fmt.Println()
	Pass("Generated %s", devcontainerPath)
	fmt.Println()

	// Summary
	Dim.Println("Configuration:")
	fmt.Printf("  Image:  %s\n", selectedImage.Image)
	fmt.Printf("  Preset: %s\n", selectedPreset)
	fmt.Printf("  SSH agent forwarding: enabled\n")
	if len(selectedImage.Extensions) > 0 && !noVSExt {
		fmt.Printf("  VS Code extensions: %s\n", strings.Join(selectedImage.Extensions, ", "))
	}
	fmt.Println()

	// Next steps
	BoldCyan.Println("Next steps:")
	fmt.Println("  1. Commit .devcontainer/ to your repository")
	fmt.Println("  2. Open in VS Code or GitHub Codespaces")
	fmt.Println("  3. Run 'blackdot setup' when the container starts")
	fmt.Println()

	return nil
}

func selectImage() (DevcontainerImage, error) {
	BoldCyan.Println("Select base image:")
	fmt.Println()

	for i, img := range devcontainerImages {
		fmt.Printf("  %d. ", i+1)
		Yellow.Print(img.Name)
		Dim.Printf(" - %s\n", img.Description)
	}

	fmt.Println()
	fmt.Print("Enter selection (1-", len(devcontainerImages), "): ")

	reader := bufio.NewReader(os.Stdin)
	input, err := reader.ReadString('\n')
	if err != nil {
		return DevcontainerImage{}, fmt.Errorf("reading input: %w", err)
	}

	input = strings.TrimSpace(input)
	num, err := strconv.Atoi(input)
	if err != nil || num < 1 || num > len(devcontainerImages) {
		return DevcontainerImage{}, fmt.Errorf("invalid selection: %s", input)
	}

	fmt.Println()
	return devcontainerImages[num-1], nil
}

func selectPreset() (string, error) {
	BoldCyan.Println("Select blackdot preset:")
	fmt.Println()

	for i, preset := range devcontainerPresets {
		fmt.Printf("  %d. ", i+1)
		Yellow.Print(preset.Name)
		fmt.Print(strings.Repeat(" ", 12-len(preset.Name)))
		Dim.Printf("- %s\n", preset.Description)
	}

	fmt.Println()
	fmt.Print("Enter selection (1-", len(devcontainerPresets), "): ")

	reader := bufio.NewReader(os.Stdin)
	input, err := reader.ReadString('\n')
	if err != nil {
		return "", fmt.Errorf("reading input: %w", err)
	}

	input = strings.TrimSpace(input)
	num, err := strconv.Atoi(input)
	if err != nil || num < 1 || num > len(devcontainerPresets) {
		return "", fmt.Errorf("invalid selection: %s", input)
	}

	fmt.Println()
	return devcontainerPresets[num-1].Name, nil
}

func generateDevcontainerConfig(image DevcontainerImage, preset string, noVSExt bool) DevcontainerConfig {
	config := DevcontainerConfig{
		Name:  "Development Container",
		Image: image.Image,
		Features: map[string]map[string]string{
			"ghcr.io/blackwell-systems/blackdot:1": {
				"preset":  preset,
				"version": "latest",
			},
		},
		PostStartCommand: fmt.Sprintf("blackdot setup --preset %s", preset),
		RemoteUser:       "vscode",
		// SSH agent forwarding - mount host socket into container
		Mounts: []string{
			"source=${localEnv:SSH_AUTH_SOCK},target=/ssh-agent,type=bind,consistency=cached",
		},
		ContainerEnv: map[string]string{
			"SSH_AUTH_SOCK": "/ssh-agent",
		},
	}

	// Add VS Code extensions if available and not disabled
	if len(image.Extensions) > 0 && !noVSExt {
		config.Customizations = &DevcontainerCustomizations{
			VSCode: &VSCodeCustomizations{
				Extensions: image.Extensions,
			},
		}
	}

	return config
}
