// Package cli implements the dotfiles command-line interface using Cobra.
package cli

import (
	"bufio"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/pem"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
	"golang.org/x/crypto/ssh"
)

// newToolsSSHCmd creates the ssh tools subcommand
func newToolsSSHCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "ssh",
		Short: "SSH key and connection management",
		Long: `SSH key and connection management tools.

Cross-platform SSH utilities for managing keys, agents, and connections.
Works on Linux, macOS, and Windows.

Commands:
  keys     - List all SSH keys with fingerprints
  gen      - Generate new ED25519 key pair
  list     - List configured SSH hosts
  agent    - Show SSH agent status and loaded keys
  fp       - Show fingerprint(s) in multiple formats
  copy     - Copy public key to remote host
  tunnel   - Create SSH port forward tunnel
  socks    - Create SOCKS5 proxy through SSH host`,
	}

	// Add SSH subcommands
	cmd.AddCommand(
		newSSHKeysCmd(),
		newSSHGenCmd(),
		newSSHListCmd(),
		newSSHAgentCmd(),
		newSSHFingerprintCmd(),
		newSSHCopyCmd(),
		newSSHTunnelCmd(),
		newSSHSocksCmd(),
		newSSHStatusCmdLocal(),
	)

	return cmd
}

// newSSHKeysCmd lists SSH keys with fingerprints
func newSSHKeysCmd() *cobra.Command {
	var keyDir string

	cmd := &cobra.Command{
		Use:   "keys",
		Short: "List SSH keys with fingerprints",
		Long: `List all SSH keys in the specified directory with their fingerprints.

Shows key name, bit size, type, and SHA256 fingerprint.
Default directory is ~/.ssh`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if keyDir == "" {
				home, err := os.UserHomeDir()
				if err != nil {
					return fmt.Errorf("cannot determine home directory: %w", err)
				}
				keyDir = filepath.Join(home, ".ssh")
			}

			return runSSHKeys(keyDir)
		},
	}

	cmd.Flags().StringVarP(&keyDir, "dir", "d", "", "SSH key directory (default: ~/.ssh)")

	return cmd
}

func runSSHKeys(keyDir string) error {
	fmt.Printf("SSH Keys in %s:\n", keyDir)
	fmt.Println("──────────────────────────────────────")

	// Find all .pub files
	pattern := filepath.Join(keyDir, "*.pub")
	matches, err := filepath.Glob(pattern)
	if err != nil {
		return fmt.Errorf("error searching for keys: %w", err)
	}

	if len(matches) == 0 {
		fmt.Println("  No SSH keys found")
		fmt.Println()
		return nil
	}

	// Sort by name
	sort.Strings(matches)

	for _, pubPath := range matches {
		name := strings.TrimSuffix(filepath.Base(pubPath), ".pub")

		// Read public key
		pubData, err := os.ReadFile(pubPath)
		if err != nil {
			fmt.Printf("  %-20s (error reading: %v)\n", name, err)
			continue
		}

		// Parse public key
		pubKey, comment, _, _, err := ssh.ParseAuthorizedKey(pubData)
		if err != nil {
			fmt.Printf("  %-20s (error parsing: %v)\n", name, err)
			continue
		}

		// Get fingerprint
		fp := ssh.FingerprintSHA256(pubKey)

		// Get key type and size
		keyType := pubKey.Type()
		bits := getKeyBits(pubKey)

		// Use comment if available, otherwise use filename
		displayName := name
		if comment != "" && comment != name {
			displayName = name
		}

		fmt.Printf("  %-20s %4d %s (%s)\n", displayName, bits, keyType, fp)
	}

	fmt.Println()
	return nil
}

// getKeyBits returns the bit size for a public key
func getKeyBits(pubKey ssh.PublicKey) int {
	switch pubKey.Type() {
	case "ssh-ed25519":
		return 256
	case "ssh-rsa":
		// RSA key size varies, approximate from key data
		return len(pubKey.Marshal()) * 4 // rough approximation
	case "ecdsa-sha2-nistp256":
		return 256
	case "ecdsa-sha2-nistp384":
		return 384
	case "ecdsa-sha2-nistp521":
		return 521
	default:
		return 0
	}
}

// newSSHGenCmd generates new ED25519 key pair
func newSSHGenCmd() *cobra.Command {
	var comment string
	var noPassphrase bool

	cmd := &cobra.Command{
		Use:   "gen <name>",
		Short: "Generate new ED25519 key pair",
		Long: `Generate a new ED25519 SSH key pair.

Creates key at ~/.ssh/id_ed25519_<name> with optional comment.
ED25519 keys are recommended for their security and performance.

Examples:
  blackdot tools ssh gen github
  blackdot tools ssh gen work --comment "Work laptop"
  blackdot tools ssh gen deploy --no-passphrase`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			name := args[0]
			if comment == "" {
				comment = name + " key"
			}
			return runSSHGen(name, comment, noPassphrase)
		},
	}

	cmd.Flags().StringVarP(&comment, "comment", "c", "", "Key comment (default: '<name> key')")
	cmd.Flags().BoolVar(&noPassphrase, "no-passphrase", false, "Generate key without passphrase")

	return cmd
}

func runSSHGen(name, comment string, noPassphrase bool) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("cannot determine home directory: %w", err)
	}

	keyPath := filepath.Join(home, ".ssh", fmt.Sprintf("id_ed25519_%s", name))

	// Check if key already exists
	if _, err := os.Stat(keyPath); err == nil {
		return fmt.Errorf("key already exists: %s\nDelete it first if you want to regenerate", keyPath)
	}

	// Ensure .ssh directory exists
	sshDir := filepath.Join(home, ".ssh")
	if err := os.MkdirAll(sshDir, 0700); err != nil {
		return fmt.Errorf("cannot create .ssh directory: %w", err)
	}

	fmt.Printf("Generating ED25519 key: %s\n", keyPath)

	// If not no-passphrase, use ssh-keygen for passphrase prompting
	if !noPassphrase {
		// Use ssh-keygen for interactive passphrase
		args := []string{"-t", "ed25519", "-f", keyPath, "-C", comment}
		cmd := exec.Command("ssh-keygen", args...)
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr

		if err := cmd.Run(); err != nil {
			return fmt.Errorf("ssh-keygen failed: %w", err)
		}
	} else {
		// Generate key without passphrase using pure Go
		pubKey, privKey, err := ed25519.GenerateKey(rand.Reader)
		if err != nil {
			return fmt.Errorf("failed to generate key: %w", err)
		}

		// Write private key in OpenSSH format
		if err := writeED25519PrivateKey(keyPath, privKey, comment); err != nil {
			return fmt.Errorf("failed to write private key: %w", err)
		}

		// Write public key
		sshPubKey, err := ssh.NewPublicKey(pubKey)
		if err != nil {
			return fmt.Errorf("failed to create SSH public key: %w", err)
		}

		pubKeyData := ssh.MarshalAuthorizedKey(sshPubKey)
		// Add comment to public key
		pubKeyLine := strings.TrimSpace(string(pubKeyData)) + " " + comment + "\n"

		if err := os.WriteFile(keyPath+".pub", []byte(pubKeyLine), 0644); err != nil {
			return fmt.Errorf("failed to write public key: %w", err)
		}
	}

	// Ensure permissions
	os.Chmod(keyPath, 0600)
	os.Chmod(keyPath+".pub", 0644)

	fmt.Println()
	fmt.Println("Key generated successfully!")
	fmt.Println("Public key:")

	pubData, err := os.ReadFile(keyPath + ".pub")
	if err == nil {
		fmt.Print(string(pubData))
	}

	return nil
}

// writeED25519PrivateKey writes an ED25519 private key in OpenSSH format
func writeED25519PrivateKey(path string, privKey ed25519.PrivateKey, comment string) error {
	// OpenSSH private key format is complex, use ssh-keygen as fallback
	// For now, write in PEM format (works with most tools)
	block := &pem.Block{
		Type:  "OPENSSH PRIVATE KEY",
		Bytes: marshalED25519PrivateKey(privKey, comment),
	}

	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		return err
	}
	defer file.Close()

	return pem.Encode(file, block)
}

// marshalED25519PrivateKey marshals an ED25519 private key to OpenSSH format
func marshalED25519PrivateKey(privKey ed25519.PrivateKey, comment string) []byte {
	pubKey := privKey.Public().(ed25519.PublicKey)

	// OpenSSH private key format
	// See: https://github.com/openssh/openssh-portable/blob/master/PROTOCOL.key

	// Auth magic
	magic := []byte("openssh-key-v1\x00")

	// Cipher and KDF (none for no passphrase)
	cipherName := "none"
	kdfName := "none"
	kdfOptions := []byte{}

	// Number of keys
	numKeys := uint32(1)

	// Public key
	sshPubKey, _ := ssh.NewPublicKey(pubKey)
	pubKeyBytes := sshPubKey.Marshal()

	// Private section (includes check integers, key data, comment, padding)
	checkInt := make([]byte, 4)
	rand.Read(checkInt)

	// Build private section
	privSection := make([]byte, 0, 256)
	// Check integers (must match)
	privSection = append(privSection, checkInt...)
	privSection = append(privSection, checkInt...)
	// Key type
	privSection = appendString(privSection, "ssh-ed25519")
	// Public key (32 bytes)
	privSection = appendBytes(privSection, pubKey)
	// Private key (64 bytes = seed + public)
	privSection = appendBytes(privSection, privKey)
	// Comment
	privSection = appendString(privSection, comment)
	// Padding
	for i := 1; len(privSection)%8 != 0; i++ {
		privSection = append(privSection, byte(i))
	}

	// Build full key
	result := make([]byte, 0, 512)
	result = append(result, magic...)
	result = appendString(result, cipherName)
	result = appendString(result, kdfName)
	result = appendBytes(result, kdfOptions)
	result = appendUint32(result, numKeys)
	result = appendBytes(result, pubKeyBytes)
	result = appendBytes(result, privSection)

	return result
}

func appendString(b []byte, s string) []byte {
	return appendBytes(b, []byte(s))
}

func appendBytes(b []byte, data []byte) []byte {
	b = appendUint32(b, uint32(len(data)))
	return append(b, data...)
}

func appendUint32(b []byte, v uint32) []byte {
	return append(b, byte(v>>24), byte(v>>16), byte(v>>8), byte(v))
}

// newSSHListCmd lists configured SSH hosts
func newSSHListCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "list",
		Short: "List configured SSH hosts",
		Long: `List all hosts configured in ~/.ssh/config.

Shows host aliases that can be used with ssh command.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runSSHList()
		},
	}

	return cmd
}

func runSSHList() error {
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("cannot determine home directory: %w", err)
	}

	configPath := filepath.Join(home, ".ssh", "config")

	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		fmt.Println("No SSH config found at ~/.ssh/config")
		return nil
	}

	file, err := os.Open(configPath)
	if err != nil {
		return fmt.Errorf("cannot open SSH config: %w", err)
	}
	defer file.Close()

	fmt.Println("SSH Hosts:")
	fmt.Println("──────────────────────────────────────")

	hostRegex := regexp.MustCompile(`(?i)^Host\s+(.+)$`)
	var hosts []string

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if matches := hostRegex.FindStringSubmatch(line); matches != nil {
			// Split on whitespace to handle multiple hosts on one line
			hostnames := strings.Fields(matches[1])
			for _, h := range hostnames {
				// Skip wildcards
				if !strings.Contains(h, "*") && !strings.Contains(h, "?") {
					hosts = append(hosts, h)
				}
			}
		}
	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf("error reading SSH config: %w", err)
	}

	// Sort and deduplicate
	sort.Strings(hosts)
	seen := make(map[string]bool)
	for _, h := range hosts {
		if !seen[h] {
			seen[h] = true
			fmt.Printf("  %s\n", h)
		}
	}

	fmt.Println()
	fmt.Printf("Total: %d hosts\n", len(seen))

	return nil
}

// newSSHAgentCmd shows SSH agent status
func newSSHAgentCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "agent",
		Short: "Show SSH agent status",
		Long: `Show SSH agent status and currently loaded keys.

Displays agent PID, socket path, and lists all loaded keys.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runSSHAgent()
		},
	}

	return cmd
}

func runSSHAgent() error {
	fmt.Println("SSH Agent Status:")
	fmt.Println("──────────────────────────────────────")

	// Check SSH_AUTH_SOCK
	authSock := os.Getenv("SSH_AUTH_SOCK")
	if authSock == "" {
		fmt.Println("  Status: ○ not running")
		fmt.Println("  Socket: not set")
		fmt.Println()
		fmt.Println("Start the agent with:")
		if runtime.GOOS == "windows" {
			fmt.Println("  Start-Service ssh-agent")
		} else {
			fmt.Println("  eval \"$(ssh-agent -s)\"")
		}
		return nil
	}

	// Try to list keys
	cmd := exec.Command("ssh-add", "-l")
	output, err := cmd.Output()

	agentPID := os.Getenv("SSH_AGENT_PID")
	if agentPID == "" {
		agentPID = "unknown"
	}

	fmt.Printf("  PID:    %s\n", agentPID)
	fmt.Printf("  Socket: %s\n", authSock)
	fmt.Println()
	fmt.Println("Loaded keys:")

	if err != nil {
		// Check if it's "no identities" message
		if strings.Contains(string(output), "no identities") || cmd.ProcessState.ExitCode() == 1 {
			fmt.Println("  (no keys loaded)")
		} else {
			fmt.Printf("  (error listing keys: %v)\n", err)
		}
	} else {
		// Parse and display keys
		lines := strings.Split(strings.TrimSpace(string(output)), "\n")
		for _, line := range lines {
			if line != "" {
				fmt.Printf("  %s\n", line)
			}
		}
	}

	fmt.Println()
	return nil
}

// newSSHFingerprintCmd shows key fingerprints
func newSSHFingerprintCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "fp [key]",
		Short: "Show fingerprint(s) in multiple formats",
		Long: `Show SSH key fingerprints in SHA256 and MD5 formats.

If no key is specified, shows fingerprints for all keys.

Examples:
  blackdot tools ssh fp           # All keys
  blackdot tools ssh fp github    # Specific key`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) > 0 {
				return runSSHFingerprint(args[0])
			}
			return runSSHFingerprintAll()
		},
	}

	return cmd
}

func runSSHFingerprintAll() error {
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("cannot determine home directory: %w", err)
	}

	sshDir := filepath.Join(home, ".ssh")
	pattern := filepath.Join(sshDir, "*.pub")
	matches, err := filepath.Glob(pattern)
	if err != nil {
		return fmt.Errorf("error searching for keys: %w", err)
	}

	if len(matches) == 0 {
		fmt.Println("No SSH keys found")
		return nil
	}

	fmt.Println("SSH Key Fingerprints:")
	fmt.Println("──────────────────────────────────────")

	for _, pubPath := range matches {
		name := filepath.Base(pubPath)

		pubData, err := os.ReadFile(pubPath)
		if err != nil {
			continue
		}

		pubKey, _, _, _, err := ssh.ParseAuthorizedKey(pubData)
		if err != nil {
			continue
		}

		fmt.Println()
		fmt.Printf("%s:\n", name)
		fmt.Printf("  SHA256: %s\n", ssh.FingerprintSHA256(pubKey))
		fmt.Printf("  MD5:    %s\n", ssh.FingerprintLegacyMD5(pubKey))
	}

	return nil
}

func runSSHFingerprint(keyName string) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("cannot determine home directory: %w", err)
	}

	sshDir := filepath.Join(home, ".ssh")

	// Try various path patterns
	candidates := []string{
		keyName,
		keyName + ".pub",
		filepath.Join(sshDir, keyName),
		filepath.Join(sshDir, keyName+".pub"),
		filepath.Join(sshDir, "id_ed25519_"+keyName+".pub"),
		filepath.Join(sshDir, "id_rsa_"+keyName+".pub"),
	}

	var pubPath string
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			pubPath = c
			break
		}
	}

	if pubPath == "" {
		return fmt.Errorf("key not found: %s", keyName)
	}

	// Ensure we have the .pub file
	if !strings.HasSuffix(pubPath, ".pub") {
		pubPath = pubPath + ".pub"
	}

	pubData, err := os.ReadFile(pubPath)
	if err != nil {
		return fmt.Errorf("cannot read key: %w", err)
	}

	pubKey, _, _, _, err := ssh.ParseAuthorizedKey(pubData)
	if err != nil {
		return fmt.Errorf("cannot parse key: %w", err)
	}

	fmt.Printf("Fingerprints for %s:\n", filepath.Base(pubPath))
	fmt.Printf("  SHA256: %s\n", ssh.FingerprintSHA256(pubKey))
	fmt.Printf("  MD5:    %s\n", ssh.FingerprintLegacyMD5(pubKey))

	return nil
}

// newSSHCopyCmd copies public key to remote host
func newSSHCopyCmd() *cobra.Command {
	var keyPath string

	cmd := &cobra.Command{
		Use:   "copy <host>",
		Short: "Copy public key to remote host",
		Long: `Copy SSH public key to remote host's authorized_keys.

Uses ssh-copy-id under the hood.

Examples:
  blackdot tools ssh copy myserver
  blackdot tools ssh copy user@host --key ~/.ssh/id_ed25519_work.pub`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return runSSHCopy(args[0], keyPath)
		},
	}

	cmd.Flags().StringVarP(&keyPath, "key", "k", "", "Specific key to copy")

	return cmd
}

func runSSHCopy(host, keyPath string) error {
	args := []string{}
	if keyPath != "" {
		args = append(args, "-i", keyPath)
	}
	args = append(args, host)

	cmd := exec.Command("ssh-copy-id", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

// newSSHTunnelCmd creates port forward tunnel
func newSSHTunnelCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "tunnel <host> <local_port> [remote_port]",
		Short: "Create SSH port forward tunnel",
		Long: `Create an SSH port forwarding tunnel.

Forwards localhost:local_port to host:remote_port.
If remote_port is not specified, uses the same as local_port.

Examples:
  blackdot tools ssh tunnel myserver 8080 80
  blackdot tools ssh tunnel db-server 5432`,
		Args: cobra.RangeArgs(2, 3),
		RunE: func(cmd *cobra.Command, args []string) error {
			host := args[0]
			localPort := args[1]
			remotePort := localPort
			if len(args) > 2 {
				remotePort = args[2]
			}
			return runSSHTunnel(host, localPort, remotePort)
		},
	}

	return cmd
}

func runSSHTunnel(host, localPort, remotePort string) error {
	fmt.Printf("Creating tunnel: localhost:%s -> %s:%s\n", localPort, host, remotePort)
	fmt.Println("Press Ctrl+C to close tunnel")

	tunnelSpec := fmt.Sprintf("%s:localhost:%s", localPort, remotePort)
	cmd := exec.Command("ssh", "-N", "-L", tunnelSpec, host)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

// newSSHSocksCmd creates SOCKS5 proxy
func newSSHSocksCmd() *cobra.Command {
	var port string

	cmd := &cobra.Command{
		Use:   "socks <host>",
		Short: "Create SOCKS5 proxy through SSH host",
		Long: `Create a SOCKS5 proxy through an SSH host.

Configure browser/apps to use socks5://localhost:<port>

Examples:
  blackdot tools ssh socks myserver
  blackdot tools ssh socks myserver --port 9050`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return runSSHSocks(args[0], port)
		},
	}

	cmd.Flags().StringVarP(&port, "port", "p", "1080", "Local SOCKS5 port")

	return cmd
}

func runSSHSocks(host, port string) error {
	fmt.Printf("Creating SOCKS5 proxy on localhost:%s through %s\n", port, host)
	fmt.Printf("Configure apps to use: socks5://localhost:%s\n", port)
	fmt.Println("Press Ctrl+C to close proxy")

	cmd := exec.Command("ssh", "-N", "-D", port, host)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

// newSSHStatusCmdLocal creates SSH status command with banner
func newSSHStatusCmdLocal() *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show SSH status with banner",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runSSHStatusLocal()
		},
	}
}

func runSSHStatusLocal() error {
	home, _ := os.UserHomeDir()
	sshDir := filepath.Join(home, ".ssh")

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

	// Count hosts
	hostCount := 0
	configPath := filepath.Join(sshDir, "config")
	if file, err := os.Open(configPath); err == nil {
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
	keyFiles, _ := filepath.Glob(filepath.Join(sshDir, "*.pub"))
	fmt.Printf("    %s      %s\n", dim.Sprint("Keys"), cyan.Sprintf("%d available", len(keyFiles)))

	fmt.Println()
	return nil
}
