package cli

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

func newDockerToolsCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "docker",
		Short: "Docker container tools",
		Long: `Docker container management, inspection, and cleanup tools.

Cross-platform Docker tools that work on Linux, macOS, and Windows.
Feature-gated: requires 'docker_tools' feature to be enabled.`,
	}

	cmd.AddCommand(newDockerPsCmd())
	cmd.AddCommand(newDockerImagesCmd())
	cmd.AddCommand(newDockerIPCmd())
	cmd.AddCommand(newDockerEnvCmd())
	cmd.AddCommand(newDockerPortsCmd())
	cmd.AddCommand(newDockerStatsCmd())
	cmd.AddCommand(newDockerVolsCmd())
	cmd.AddCommand(newDockerNetsCmd())
	cmd.AddCommand(newDockerCleanCmd())
	cmd.AddCommand(newDockerPruneCmd())
	cmd.AddCommand(newDockerInspectCmd())
	cmd.AddCommand(newDockerStatusCmd())

	return cmd
}

// newDockerPsCmd lists running containers
func newDockerPsCmd() *cobra.Command {
	var all bool

	cmd := &cobra.Command{
		Use:   "ps",
		Short: "List containers",
		Long:  `List Docker containers with formatted output.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return dockerPs(all)
		},
	}

	cmd.Flags().BoolVarP(&all, "all", "a", false, "Show all containers (including stopped)")

	return cmd
}

func dockerPs(all bool) error {
	if err := checkDockerRunning(); err != nil {
		return err
	}

	args := []string{"ps", "--format", "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"}
	if all {
		args = append(args, "-a")
	}

	cmd := exec.Command("docker", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// newDockerImagesCmd lists images
func newDockerImagesCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "images",
		Short: "List Docker images",
		Long:  `List Docker images with size information.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return dockerImages()
		},
	}
}

func dockerImages() error {
	if err := checkDockerRunning(); err != nil {
		return err
	}

	cmd := exec.Command("docker", "images", "--format", "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// newDockerIPCmd gets container IP address
func newDockerIPCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "ip <container>",
		Short: "Get container IP address",
		Long:  `Get the IP address of a running container.`,
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return dockerIP(args[0])
		},
	}
}

func dockerIP(container string) error {
	if err := checkDockerRunning(); err != nil {
		return err
	}

	cmd := exec.Command("docker", "inspect", "-f", "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}", container)
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get IP for container '%s': %w", container, err)
	}

	ip := strings.TrimSpace(string(output))
	if ip == "" {
		return fmt.Errorf("container '%s' has no IP address (not running?)", container)
	}

	fmt.Println(ip)
	return nil
}

// newDockerEnvCmd shows container environment variables
func newDockerEnvCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "env <container>",
		Short: "Show container environment variables",
		Long:  `Display environment variables from a container.`,
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return dockerEnv(args[0])
		},
	}
}

func dockerEnv(container string) error {
	if err := checkDockerRunning(); err != nil {
		return err
	}

	// Try exec env first (works for running containers)
	cmd := exec.Command("docker", "exec", container, "env")
	output, err := cmd.Output()
	if err == nil {
		fmt.Print(string(output))
		return nil
	}

	// Fall back to inspect (works for stopped containers too)
	cmd = exec.Command("docker", "inspect", "-f", "{{range .Config.Env}}{{println .}}{{end}}", container)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// newDockerPortsCmd shows exposed ports
func newDockerPortsCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "ports",
		Short: "Show all container ports",
		Long:  `Display all containers and their exposed ports.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return dockerPorts()
		},
	}
}

func dockerPorts() error {
	if err := checkDockerRunning(); err != nil {
		return err
	}

	PrintHeader("Container Ports")

	cmd := exec.Command("docker", "ps", "--format", "{{.Names}}\t{{.Ports}}")
	output, err := cmd.Output()
	if err != nil {
		return err
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) == 0 || (len(lines) == 1 && lines[0] == "") {
		fmt.Println("No running containers")
		return nil
	}

	for _, line := range lines {
		if line != "" {
			fmt.Printf("  %s\n", line)
		}
	}

	return nil
}

// newDockerStatsCmd shows container stats
func newDockerStatsCmd() *cobra.Command {
	var follow bool

	cmd := &cobra.Command{
		Use:   "stats",
		Short: "Show container resource usage",
		Long:  `Display CPU, memory, and network usage for containers.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return dockerStats(follow)
		},
	}

	cmd.Flags().BoolVarP(&follow, "follow", "f", false, "Stream stats continuously")

	return cmd
}

func dockerStats(follow bool) error {
	if err := checkDockerRunning(); err != nil {
		return err
	}

	args := []string{"stats", "--format", "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"}
	if !follow {
		args = append(args, "--no-stream")
	}

	cmd := exec.Command("docker", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// newDockerVolsCmd lists volumes
func newDockerVolsCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "vols",
		Short: "List Docker volumes",
		Long:  `Display all Docker volumes with details.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return dockerVols()
		},
	}
}

func dockerVols() error {
	if err := checkDockerRunning(); err != nil {
		return err
	}

	PrintHeader("Docker Volumes")

	cmd := exec.Command("docker", "volume", "ls", "--format", "{{.Name}}\t{{.Driver}}")
	output, err := cmd.Output()
	if err != nil {
		return err
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	for _, line := range lines {
		if line != "" {
			fmt.Printf("  %s\n", line)
		}
	}

	fmt.Printf("\nTotal: %d volumes\n", len(lines))

	return nil
}

// newDockerNetsCmd lists networks
func newDockerNetsCmd() *cobra.Command {
	var inspect string

	cmd := &cobra.Command{
		Use:   "nets",
		Short: "List Docker networks",
		Long:  `Display Docker networks or inspect a specific network.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if inspect != "" {
				return dockerNetInspect(inspect)
			}
			return dockerNets()
		},
	}

	cmd.Flags().StringVarP(&inspect, "inspect", "i", "", "Show containers on this network")

	return cmd
}

func dockerNets() error {
	if err := checkDockerRunning(); err != nil {
		return err
	}

	PrintHeader("Docker Networks")

	cmd := exec.Command("docker", "network", "ls", "--format", "table {{.Name}}\t{{.Driver}}\t{{.Scope}}")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func dockerNetInspect(network string) error {
	if err := checkDockerRunning(); err != nil {
		return err
	}

	fmt.Printf("Containers on network '%s':\n", network)
	fmt.Println(strings.Repeat("─", 40))

	cmd := exec.Command("docker", "network", "inspect", network, "-f", "{{range .Containers}}{{.Name}} ({{.IPv4Address}})\n{{end}}")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// newDockerCleanCmd removes stopped containers and dangling images
func newDockerCleanCmd() *cobra.Command {
	var dryRun bool

	cmd := &cobra.Command{
		Use:   "clean",
		Short: "Remove stopped containers and dangling images",
		Long: `Clean up Docker by removing:
  - Stopped containers
  - Dangling images

This is a safe cleanup operation that won't remove running containers
or images that are in use.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return dockerClean(dryRun)
		},
	}

	cmd.Flags().BoolVarP(&dryRun, "dry-run", "n", false, "Show what would be removed")

	return cmd
}

func dockerClean(dryRun bool) error {
	if err := checkDockerRunning(); err != nil {
		return err
	}

	PrintHeader("Docker Cleanup")

	if dryRun {
		fmt.Println("(DRY RUN - no changes will be made)")
		fmt.Println()
	}

	// Count stopped containers
	cmd := exec.Command("docker", "ps", "-aq", "-f", "status=exited")
	output, _ := cmd.Output()
	stoppedContainers := strings.Split(strings.TrimSpace(string(output)), "\n")
	stoppedCount := 0
	for _, c := range stoppedContainers {
		if c != "" {
			stoppedCount++
		}
	}

	// Count dangling images
	cmd = exec.Command("docker", "images", "-f", "dangling=true", "-q")
	output, _ = cmd.Output()
	danglingImages := strings.Split(strings.TrimSpace(string(output)), "\n")
	danglingCount := 0
	for _, i := range danglingImages {
		if i != "" {
			danglingCount++
		}
	}

	if stoppedCount > 0 {
		fmt.Printf("Stopped containers: %d\n", stoppedCount)
		if !dryRun {
			Info("Removing stopped containers...")
			cmd = exec.Command("docker", "container", "prune", "-f")
			cmd.Stdout = os.Stdout
			cmd.Run()
		} else {
			fmt.Println("Would remove stopped containers")
		}
	} else {
		fmt.Println("No stopped containers to remove")
	}

	fmt.Println()

	if danglingCount > 0 {
		fmt.Printf("Dangling images: %d\n", danglingCount)
		if !dryRun {
			Info("Removing dangling images...")
			cmd = exec.Command("docker", "image", "prune", "-f")
			cmd.Stdout = os.Stdout
			cmd.Run()
		} else {
			fmt.Println("Would remove dangling images")
		}
	} else {
		fmt.Println("No dangling images to remove")
	}

	fmt.Println()
	Pass("Done!")

	return nil
}

// newDockerPruneCmd does system prune
func newDockerPruneCmd() *cobra.Command {
	var all bool
	var force bool

	cmd := &cobra.Command{
		Use:   "prune",
		Short: "System prune (clean all unused resources)",
		Long: `Remove unused Docker resources:
  - Stopped containers
  - Networks not used by containers
  - Dangling images
  - Dangling build cache

With --all: Also removes ALL unused images (not just dangling).`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return dockerPrune(all, force)
		},
	}

	cmd.Flags().BoolVarP(&all, "all", "a", false, "Remove all unused images, not just dangling")
	cmd.Flags().BoolVarP(&force, "force", "f", false, "Skip confirmation prompt")

	return cmd
}

func dockerPrune(all, force bool) error {
	if err := checkDockerRunning(); err != nil {
		return err
	}

	fmt.Println("This will remove:")
	fmt.Println("  - All stopped containers")
	fmt.Println("  - All networks not used by containers")
	if all {
		fmt.Println("  - ALL unused images (not just dangling)")
		fmt.Println("  - All build cache")
	} else {
		fmt.Println("  - Dangling images")
		fmt.Println("  - Dangling build cache")
	}
	fmt.Println()

	args := []string{"system", "prune"}
	if all {
		args = append(args, "-a", "--volumes")
	}
	if force {
		args = append(args, "-f")
	}

	cmd := exec.Command("docker", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// newDockerInspectCmd inspects containers with optional jq filtering
func newDockerInspectCmd() *cobra.Command {
	var path string

	cmd := &cobra.Command{
		Use:   "inspect <container>",
		Short: "Inspect container with optional JSON path",
		Long: `Inspect a container and optionally filter with a JSON path.

Examples:
  blackdot tools docker inspect myapp
  blackdot tools docker inspect myapp --path .NetworkSettings
  blackdot tools docker inspect myapp --path .Config.Env`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return dockerInspect(args[0], path)
		},
	}

	cmd.Flags().StringVarP(&path, "path", "p", "", "JSON path to extract (e.g., .NetworkSettings)")

	return cmd
}

func dockerInspect(container, jsonPath string) error {
	if err := checkDockerRunning(); err != nil {
		return err
	}

	cmd := exec.Command("docker", "inspect", container)
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to inspect container '%s': %w", container, err)
	}

	if jsonPath == "" {
		// Pretty print the full JSON
		var prettyJSON bytes.Buffer
		if err := json.Indent(&prettyJSON, output, "", "  "); err != nil {
			fmt.Print(string(output))
			return nil
		}
		fmt.Println(prettyJSON.String())
		return nil
	}

	// Parse and extract path
	var data []map[string]interface{}
	if err := json.Unmarshal(output, &data); err != nil {
		return fmt.Errorf("failed to parse inspect output: %w", err)
	}

	if len(data) == 0 {
		return fmt.Errorf("no data returned for container '%s'", container)
	}

	// Simple path extraction (supports .Key.SubKey format)
	result := extractJSONPath(data[0], jsonPath)
	if result == nil {
		return fmt.Errorf("path '%s' not found", jsonPath)
	}

	output, _ = json.MarshalIndent(result, "", "  ")
	fmt.Println(string(output))

	return nil
}

// extractJSONPath extracts a value from a map using dot notation
func extractJSONPath(data map[string]interface{}, path string) interface{} {
	// Remove leading dot
	path = strings.TrimPrefix(path, ".")
	parts := strings.Split(path, ".")

	var current interface{} = data
	for _, part := range parts {
		if part == "" {
			continue
		}
		if m, ok := current.(map[string]interface{}); ok {
			current = m[part]
		} else {
			return nil
		}
	}
	return current
}

// newDockerStatusCmd shows Docker status with ASCII art
func newDockerStatusCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show Docker status",
		Long:  `Display Docker daemon status and resource counts.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return dockerStatus()
		},
	}
}

func dockerStatus() error {
	// Check if Docker is running
	daemonRunning := checkDockerRunning() == nil
	containersRunning := 0

	if daemonRunning {
		cmd := exec.Command("docker", "ps", "-q")
		output, _ := cmd.Output()
		containers := strings.Split(strings.TrimSpace(string(output)), "\n")
		for _, c := range containers {
			if c != "" {
				containersRunning++
			}
		}
	}

	// Choose color based on status
	var logoColor string
	if !daemonRunning {
		logoColor = "\033[31m" // Red
	} else if containersRunning > 0 {
		logoColor = "\033[32m" // Green
	} else {
		logoColor = "\033[36m" // Cyan (Docker blue)
	}
	reset := "\033[0m"

	fmt.Println()
	fmt.Printf("%s  ██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗     ████████╗ ██████╗  ██████╗ ██╗     ███████╗%s\n", logoColor, reset)
	fmt.Printf("%s  ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝%s\n", logoColor, reset)
	fmt.Printf("%s  ██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝       ██║   ██║   ██║██║   ██║██║     ███████╗%s\n", logoColor, reset)
	fmt.Printf("%s  ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗       ██║   ██║   ██║██║   ██║██║     ╚════██║%s\n", logoColor, reset)
	fmt.Printf("%s  ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║       ██║   ╚██████╔╝╚██████╔╝███████╗███████║%s\n", logoColor, reset)
	fmt.Printf("%s  ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝%s\n", logoColor, reset)
	fmt.Println()

	printDockerCommands()
	fmt.Println()

	// Current status section
	fmt.Println("  \033[1mCurrent Status\033[0m")
	fmt.Println("  " + strings.Repeat("─", 40))

	if daemonRunning {
		fmt.Println("    Daemon      \033[32m● running\033[0m")

		// Get counts
		cmd := exec.Command("docker", "ps", "-aq")
		output, _ := cmd.Output()
		totalContainers := countNonEmpty(strings.Split(strings.TrimSpace(string(output)), "\n"))
		fmt.Printf("    Containers  \033[36m%d running\033[0m / %d total\n", containersRunning, totalContainers)

		cmd = exec.Command("docker", "images", "-q")
		output, _ = cmd.Output()
		images := countNonEmpty(strings.Split(strings.TrimSpace(string(output)), "\n"))
		fmt.Printf("    Images      \033[36m%d\033[0m\n", images)

		cmd = exec.Command("docker", "volume", "ls", "-q")
		output, _ = cmd.Output()
		volumes := countNonEmpty(strings.Split(strings.TrimSpace(string(output)), "\n"))
		fmt.Printf("    Volumes     \033[36m%d\033[0m\n", volumes)

		cmd = exec.Command("docker", "network", "ls", "-q")
		output, _ = cmd.Output()
		networks := countNonEmpty(strings.Split(strings.TrimSpace(string(output)), "\n"))
		fmt.Printf("    Networks    \033[36m%d\033[0m\n", networks)

		// Check compose version
		cmd = exec.Command("docker", "compose", "version", "--short")
		if output, err := cmd.Output(); err == nil {
			fmt.Printf("    Compose     \033[32mv%s\033[0m\n", strings.TrimSpace(string(output)))
		}
	} else {
		fmt.Println("    Daemon      \033[31m○ not running\033[0m")
		fmt.Println("                \033[90mStart with: sudo systemctl start docker\033[0m")
	}

	fmt.Println()

	return nil
}

func printDockerCommands() {
	muted := "\033[90m"
	cyan := "\033[36m"
	reset := "\033[0m"
	box := "\033[37m"

	fmt.Printf("  %s╭─────────────────────────────────────────────────────────────────╮%s\n", box, reset)
	fmt.Printf("  %s│%s  %sCONTAINER COMMANDS%s                                              %s│%s\n", box, reset, "\033[1m", reset, box, reset)
	fmt.Printf("  %s├─────────────────────────────────────────────────────────────────┤%s\n", box, reset)
	fmt.Printf("  %s│%s  %sps%s                  %slist running containers%s                      %s│%s\n", box, reset, cyan, reset, muted, reset, box, reset)
	fmt.Printf("  %s│%s  %sps -a%s               %slist all containers%s                         %s│%s\n", box, reset, cyan, reset, muted, reset, box, reset)
	fmt.Printf("  %s│%s  %simages%s              %slist images%s                                 %s│%s\n", box, reset, cyan, reset, muted, reset, box, reset)
	fmt.Printf("  %s│%s  %sip%s <container>      %sget container IP address%s                    %s│%s\n", box, reset, cyan, reset, muted, reset, box, reset)
	fmt.Printf("  %s│%s  %senv%s <container>     %sshow container env vars%s                     %s│%s\n", box, reset, cyan, reset, muted, reset, box, reset)
	fmt.Printf("  %s├─────────────────────────────────────────────────────────────────┤%s\n", box, reset)
	fmt.Printf("  %s│%s  %sINSPECTION%s                                                       %s│%s\n", box, reset, "\033[1m", reset, box, reset)
	fmt.Printf("  %s├─────────────────────────────────────────────────────────────────┤%s\n", box, reset)
	fmt.Printf("  %s│%s  %sports%s               %sshow all container ports%s                    %s│%s\n", box, reset, cyan, reset, muted, reset, box, reset)
	fmt.Printf("  %s│%s  %sstats%s               %sshow resource usage%s                         %s│%s\n", box, reset, cyan, reset, muted, reset, box, reset)
	fmt.Printf("  %s│%s  %svols%s                %slist volumes%s                                %s│%s\n", box, reset, cyan, reset, muted, reset, box, reset)
	fmt.Printf("  %s│%s  %snets%s                %slist networks%s                               %s│%s\n", box, reset, cyan, reset, muted, reset, box, reset)
	fmt.Printf("  %s│%s  %sinspect%s <c> [-p]    %sinspect with JSON path%s                      %s│%s\n", box, reset, cyan, reset, muted, reset, box, reset)
	fmt.Printf("  %s├─────────────────────────────────────────────────────────────────┤%s\n", box, reset)
	fmt.Printf("  %s│%s  %sCLEANUP%s                                                          %s│%s\n", box, reset, "\033[1m", reset, box, reset)
	fmt.Printf("  %s├─────────────────────────────────────────────────────────────────┤%s\n", box, reset)
	fmt.Printf("  %s│%s  %sclean%s               %sremove stopped + dangling%s                   %s│%s\n", box, reset, cyan, reset, muted, reset, box, reset)
	fmt.Printf("  %s│%s  %sprune%s               %ssystem prune (interactive)%s                  %s│%s\n", box, reset, cyan, reset, muted, reset, box, reset)
	fmt.Printf("  %s│%s  %sprune -a%s            %saggressive cleanup (all unused)%s             %s│%s\n", box, reset, cyan, reset, muted, reset, box, reset)
	fmt.Printf("  %s╰─────────────────────────────────────────────────────────────────╯%s\n", box, reset)
}

// checkDockerRunning verifies Docker daemon is available
func checkDockerRunning() error {
	cmd := exec.Command("docker", "info")
	cmd.Stdout = nil
	cmd.Stderr = nil
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("Docker daemon is not running. Start with: sudo systemctl start docker")
	}
	return nil
}

// countNonEmpty counts non-empty strings in a slice
func countNonEmpty(slice []string) int {
	count := 0
	for _, s := range slice {
		if s != "" {
			count++
		}
	}
	return count
}

// buildHere builds Docker image with current directory name as tag
func buildHere(noCache bool) error {
	if err := checkDockerRunning(); err != nil {
		return err
	}

	cwd, err := os.Getwd()
	if err != nil {
		return err
	}

	tag := filepath.Base(cwd)
	fmt.Printf("Building image: %s\n", tag)

	args := []string{"build", "-t", tag, "."}
	if noCache {
		args = []string{"build", "--no-cache", "-t", tag, "."}
	}

	cmd := exec.Command("docker", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
