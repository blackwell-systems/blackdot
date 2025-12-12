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

// DevcontainerService represents a supporting service (database, cache, etc.)
type DevcontainerService struct {
	Name        string
	Image       string
	Description string
	Ports       []string          // Exposed ports
	Environment map[string]string // Environment variables
	Volumes     []string          // Volume mounts
	EnvVars     map[string]string // Environment variables to set in app container
}

// Available services for docker-compose
var devcontainerServices = []DevcontainerService{
	{
		Name:        "postgres",
		Image:       "postgres:16-alpine",
		Description: "PostgreSQL 16 database",
		Ports:       []string{"5432:5432"},
		Environment: map[string]string{
			"POSTGRES_DB":       "app",
			"POSTGRES_USER":     "dev",
			"POSTGRES_PASSWORD": "dev",
		},
		Volumes: []string{"postgres-data:/var/lib/postgresql/data"},
		EnvVars: map[string]string{
			"DATABASE_URL": "postgres://dev:dev@postgres:5432/app?sslmode=disable",
			"DB_HOST":      "postgres",
			"DB_PORT":      "5432",
			"DB_USER":      "dev",
			"DB_PASSWORD":  "dev",
			"DB_NAME":      "app",
		},
	},
	{
		Name:        "redis",
		Image:       "redis:7-alpine",
		Description: "Redis 7 cache/queue",
		Ports:       []string{"6379:6379"},
		Environment: map[string]string{},
		Volumes:     []string{"redis-data:/data"},
		EnvVars: map[string]string{
			"REDIS_URL":  "redis://redis:6379",
			"REDIS_HOST": "redis",
			"REDIS_PORT": "6379",
		},
	},
	{
		Name:        "mysql",
		Image:       "mysql:8",
		Description: "MySQL 8 database",
		Ports:       []string{"3306:3306"},
		Environment: map[string]string{
			"MYSQL_ROOT_PASSWORD": "root",
			"MYSQL_DATABASE":      "app",
			"MYSQL_USER":          "dev",
			"MYSQL_PASSWORD":      "dev",
		},
		Volumes: []string{"mysql-data:/var/lib/mysql"},
		EnvVars: map[string]string{
			"DATABASE_URL": "mysql://dev:dev@mysql:3306/app",
			"DB_HOST":      "mysql",
			"DB_PORT":      "3306",
			"DB_USER":      "dev",
			"DB_PASSWORD":  "dev",
			"DB_NAME":      "app",
		},
	},
	{
		Name:        "mongo",
		Image:       "mongo:7",
		Description: "MongoDB 7 document database",
		Ports:       []string{"27017:27017"},
		Environment: map[string]string{
			"MONGO_INITDB_ROOT_USERNAME": "dev",
			"MONGO_INITDB_ROOT_PASSWORD": "dev",
		},
		Volumes: []string{"mongo-data:/data/db"},
		EnvVars: map[string]string{
			"MONGO_URL":  "mongodb://dev:dev@mongo:27017",
			"MONGO_HOST": "mongo",
			"MONGO_PORT": "27017",
		},
	},
	{
		Name:        "sqlite",
		Image:       "",
		Description: "SQLite (file-based, no container needed)",
		Ports:       []string{},
		Environment: map[string]string{},
		Volumes:     []string{},
		EnvVars: map[string]string{
			"DATABASE_URL": "sqlite:///workspace/data/app.db",
			"SQLITE_PATH":  "/workspace/data/app.db",
		},
	},
	{
		Name:        "localstack",
		Image:       "localstack/localstack:latest",
		Description: "LocalStack AWS services emulator",
		Ports:       []string{"4566:4566"},
		Environment: map[string]string{
			"SERVICES":              "s3,sqs,sns,dynamodb,lambda,secretsmanager",
			"DEFAULT_REGION":        "us-east-1",
			"DOCKER_HOST":           "unix:///var/run/docker.sock",
			"LAMBDA_EXECUTOR":       "docker",
			"LAMBDA_REMOTE_DOCKER":  "false",
			"LAMBDA_DOCKER_NETWORK": "host",
		},
		Volumes: []string{
			"localstack-data:/var/lib/localstack",
			"/var/run/docker.sock:/var/run/docker.sock",
		},
		EnvVars: map[string]string{
			"AWS_ENDPOINT_URL":      "http://localstack:4566",
			"AWS_ACCESS_KEY_ID":     "test",
			"AWS_SECRET_ACCESS_KEY": "test",
			"AWS_DEFAULT_REGION":    "us-east-1",
		},
	},
	{
		Name:        "minio",
		Image:       "minio/minio:latest",
		Description: "MinIO S3-compatible storage",
		Ports:       []string{"9000:9000", "9001:9001"},
		Environment: map[string]string{
			"MINIO_ROOT_USER":     "minioadmin",
			"MINIO_ROOT_PASSWORD": "minioadmin",
		},
		Volumes: []string{"minio-data:/data"},
		EnvVars: map[string]string{
			"MINIO_ENDPOINT":          "http://minio:9000",
			"MINIO_CONSOLE":           "http://minio:9001",
			"MINIO_ACCESS_KEY":        "minioadmin",
			"MINIO_SECRET_KEY":        "minioadmin",
		},
	},
}

// DevcontainerConfig represents the generated devcontainer.json
type DevcontainerConfig struct {
	Name              string                       `json:"name"`
	Image             string                       `json:"image,omitempty"`
	DockerComposeFile string                       `json:"dockerComposeFile,omitempty"`
	Service           string                       `json:"service,omitempty"`
	Features          map[string]map[string]string `json:"features"`
	PostStartCommand  string                       `json:"postStartCommand"`
	Customizations    *DevcontainerCustomizations  `json:"customizations,omitempty"`
	RemoteUser        string                       `json:"remoteUser,omitempty"`
	Mounts            []string                     `json:"mounts,omitempty"`
	ContainerEnv      map[string]string            `json:"containerEnv,omitempty"`
	WorkspaceFolder   string                       `json:"workspaceFolder,omitempty"`
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
		newDevcontainerServicesCmd(),
	)

	return cmd
}

func newDevcontainerInitCmd() *cobra.Command {
	var (
		image    string
		preset   string
		output   string
		force    bool
		noVSExt  bool
		services []string
	)

	cmd := &cobra.Command{
		Use:   "init",
		Short: "Generate devcontainer configuration",
		Long: `Generate a .devcontainer/devcontainer.json file for your project.

This command creates a devcontainer configuration that includes:
  - A Microsoft base image for your language/platform
  - The blackdot devcontainer feature for config management
  - VS Code extension recommendations
  - Optional supporting services (postgres, redis, etc.)

Examples:
  blackdot devcontainer init                    # Interactive mode
  blackdot devcontainer init --image go --preset developer
  blackdot devcontainer init --image python --preset claude --force
  blackdot devcontainer init --image go --services postgres,redis
  blackdot devcontainer init --image node --services postgres,redis,localstack`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runDevcontainerInit(image, preset, output, force, noVSExt, services)
		},
	}

	cmd.Flags().StringVar(&image, "image", "", "Base image (go, rust, python, node, java, ubuntu, alpine, debian)")
	cmd.Flags().StringVar(&preset, "preset", "", "Blackdot preset (minimal, developer, claude, full)")
	cmd.Flags().StringVarP(&output, "output", "o", ".devcontainer", "Output directory")
	cmd.Flags().BoolVarP(&force, "force", "f", false, "Overwrite existing configuration")
	cmd.Flags().BoolVar(&noVSExt, "no-extensions", false, "Skip VS Code extension recommendations")
	cmd.Flags().StringSliceVar(&services, "services", nil, "Supporting services (postgres, redis, mysql, mongo, sqlite, localstack, minio)")

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

func newDevcontainerServicesCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "services",
		Short: "List available supporting services",
		Long:  `List all available supporting services for docker-compose integration.`,
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println()
			BoldCyan.Println("Available Supporting Services")
			fmt.Println(strings.Repeat("─", 50))
			fmt.Println()

			for _, svc := range devcontainerServices {
				fmt.Print("  ")
				Bold.Print(svc.Name)
				fmt.Print(strings.Repeat(" ", 12-len(svc.Name)))
				Dim.Printf("- %s\n", svc.Description)
				if svc.Image != "" {
					Dim.Printf("              Image: %s\n", svc.Image)
				}
			}
			fmt.Println()
			fmt.Println("Usage: blackdot devcontainer init --services postgres,redis")
			fmt.Println()
		},
	}
}

func runDevcontainerInit(imageFlag, presetFlag, outputDir string, force, noVSExt bool, servicesFlag []string) error {
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

	// Validate and resolve services
	var selectedServices []DevcontainerService
	if len(servicesFlag) > 0 {
		for _, svcName := range servicesFlag {
			found := false
			for _, svc := range devcontainerServices {
				if strings.ToLower(svcName) == svc.Name {
					selectedServices = append(selectedServices, svc)
					found = true
					break
				}
			}
			if !found {
				return fmt.Errorf("unknown service: %s (use 'blackdot devcontainer services' to list available services)", svcName)
			}
		}
	}

	// Check output directory
	devcontainerPath := filepath.Join(outputDir, "devcontainer.json")
	if _, err := os.Stat(devcontainerPath); err == nil && !force {
		return fmt.Errorf("devcontainer.json already exists (use --force to overwrite)")
	}

	// Create output directory
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		return fmt.Errorf("creating output directory: %w", err)
	}

	// Generate configuration based on whether services are requested
	var config DevcontainerConfig
	if len(selectedServices) > 0 {
		// Generate docker-compose based config
		config = generateDevcontainerConfigWithCompose(selectedImage, selectedPreset, noVSExt, selectedServices)

		// Generate docker-compose.yml
		composePath := filepath.Join(outputDir, "docker-compose.yml")
		composeContent := generateDockerCompose(selectedImage, selectedServices)
		if err := os.WriteFile(composePath, []byte(composeContent), 0644); err != nil {
			return fmt.Errorf("writing docker-compose.yml: %w", err)
		}
		Pass("Generated %s", composePath)

		// Generate .env.example
		envPath := filepath.Join(outputDir, ".env.example")
		envContent := generateEnvExample(selectedServices)
		if err := os.WriteFile(envPath, []byte(envContent), 0644); err != nil {
			return fmt.Errorf("writing .env.example: %w", err)
		}
		Pass("Generated %s", envPath)
	} else {
		// Generate simple image-based config
		config = generateDevcontainerConfig(selectedImage, selectedPreset, noVSExt)
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
	if len(selectedServices) > 0 {
		var svcNames []string
		for _, svc := range selectedServices {
			svcNames = append(svcNames, svc.Name)
		}
		fmt.Printf("  Services: %s\n", strings.Join(svcNames, ", "))
	}
	fmt.Println()

	// Next steps
	BoldCyan.Println("Next steps:")
	fmt.Println("  1. Commit .devcontainer/ to your repository")
	fmt.Println("  2. Open in VS Code or GitHub Codespaces")
	fmt.Println("  3. Run 'blackdot setup' when the container starts")
	if len(selectedServices) > 0 {
		fmt.Println("  4. Copy .env.example to .env and customize if needed")
	}
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

func generateDevcontainerConfigWithCompose(image DevcontainerImage, preset string, noVSExt bool, services []DevcontainerService) DevcontainerConfig {
	// Collect environment variables from all services
	envVars := map[string]string{
		"SSH_AUTH_SOCK": "/ssh-agent",
	}
	for _, svc := range services {
		for k, v := range svc.EnvVars {
			envVars[k] = v
		}
	}

	config := DevcontainerConfig{
		Name:              "Development Container",
		DockerComposeFile: "docker-compose.yml",
		Service:           "app",
		WorkspaceFolder:   "/workspace",
		Features: map[string]map[string]string{
			"ghcr.io/blackwell-systems/blackdot:1": {
				"preset":  preset,
				"version": "latest",
			},
		},
		PostStartCommand: fmt.Sprintf("blackdot setup --preset %s", preset),
		RemoteUser:       "vscode",
		ContainerEnv:     envVars,
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

func generateDockerCompose(image DevcontainerImage, services []DevcontainerService) string {
	var sb strings.Builder

	sb.WriteString("# Generated by blackdot devcontainer init\n")
	sb.WriteString("# https://github.com/blackwell-systems/blackdot\n\n")
	sb.WriteString("services:\n")

	// App service
	sb.WriteString("  app:\n")
	sb.WriteString(fmt.Sprintf("    image: %s\n", image.Image))
	sb.WriteString("    volumes:\n")
	sb.WriteString("      - ..:/workspace:cached\n")
	sb.WriteString("      - ${SSH_AUTH_SOCK:-/dev/null}:/ssh-agent\n")
	sb.WriteString("    environment:\n")
	sb.WriteString("      - SSH_AUTH_SOCK=/ssh-agent\n")

	// Add service-specific env vars
	for _, svc := range services {
		for k, v := range svc.EnvVars {
			sb.WriteString(fmt.Sprintf("      - %s=%s\n", k, v))
		}
	}

	sb.WriteString("    command: sleep infinity\n")

	// Add depends_on for services that have images (not sqlite)
	var deps []string
	for _, svc := range services {
		if svc.Image != "" {
			deps = append(deps, svc.Name)
		}
	}
	if len(deps) > 0 {
		sb.WriteString("    depends_on:\n")
		for _, dep := range deps {
			sb.WriteString(fmt.Sprintf("      - %s\n", dep))
		}
	}
	sb.WriteString("\n")

	// Service definitions
	for _, svc := range services {
		if svc.Image == "" {
			continue // Skip sqlite (no container)
		}

		sb.WriteString(fmt.Sprintf("  %s:\n", svc.Name))
		sb.WriteString(fmt.Sprintf("    image: %s\n", svc.Image))

		if len(svc.Ports) > 0 {
			sb.WriteString("    ports:\n")
			for _, port := range svc.Ports {
				sb.WriteString(fmt.Sprintf("      - \"%s\"\n", port))
			}
		}

		if len(svc.Environment) > 0 {
			sb.WriteString("    environment:\n")
			for k, v := range svc.Environment {
				sb.WriteString(fmt.Sprintf("      %s: %s\n", k, v))
			}
		}

		if len(svc.Volumes) > 0 {
			sb.WriteString("    volumes:\n")
			for _, vol := range svc.Volumes {
				sb.WriteString(fmt.Sprintf("      - %s\n", vol))
			}
		}

		// Special handling for minio - add command
		if svc.Name == "minio" {
			sb.WriteString("    command: server /data --console-address \":9001\"\n")
		}

		sb.WriteString("\n")
	}

	// Volumes section
	var volumes []string
	for _, svc := range services {
		for _, vol := range svc.Volumes {
			// Extract volume name (part before :)
			parts := strings.Split(vol, ":")
			if len(parts) >= 2 && !strings.HasPrefix(parts[0], "/") && !strings.HasPrefix(parts[0], ".") {
				volumes = append(volumes, parts[0])
			}
		}
	}

	if len(volumes) > 0 {
		sb.WriteString("volumes:\n")
		seen := make(map[string]bool)
		for _, vol := range volumes {
			if !seen[vol] {
				sb.WriteString(fmt.Sprintf("  %s:\n", vol))
				seen[vol] = true
			}
		}
	}

	return sb.String()
}

func generateEnvExample(services []DevcontainerService) string {
	var sb strings.Builder

	sb.WriteString("# Environment variables for services\n")
	sb.WriteString("# Copy this file to .env and customize as needed\n")
	sb.WriteString("# Generated by blackdot devcontainer init\n\n")

	for _, svc := range services {
		if len(svc.EnvVars) == 0 {
			continue
		}

		sb.WriteString(fmt.Sprintf("# %s\n", svc.Description))
		for k, v := range svc.EnvVars {
			sb.WriteString(fmt.Sprintf("%s=%s\n", k, v))
		}
		sb.WriteString("\n")
	}

	return sb.String()
}
