// Package cli implements the blackdot command-line interface using Cobra.
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
  keys      - Manage SSH keys (list, load, unload, clear)
  gen       - Generate new ED25519 key pair
  list      - List configured SSH hosts
  agent     - Show SSH agent status and loaded keys
  fp        - Show fingerprint(s) in multiple formats
  copy      - Copy public key to remote host
  tunnel    - Create SSH port forward tunnel
  socks     - Create SOCKS5 proxy through SSH host
  status    - Show SSH status with banner
  load      - Add key to SSH agent
  unload    - Remove key from SSH agent
  clear     - Remove all keys from agent
  tunnels     - List active SSH connections
  add-host    - Add new host to SSH config
  remove-host - Remove host from SSH config`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runSSHStatusLocal()
		},
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
		newSSHLoadCmd(),
		newSSHUnloadCmd(),
		newSSHClearCmd(),
		newSSHTunnelsCmd(),
		newSSHAddHostCmd(),
		newSSHRemoveHostCmd(),
	)

	return cmd
}

// newSSHKeysCmd is the parent command for key operations.
// Called without a subcommand it lists keys (same as "keys list").
func newSSHKeysCmd() *cobra.Command {
	var keyDir string

	cmd := &cobra.Command{
		Use:   "keys",
		Short: "Manage SSH keys",
		Long: `Manage SSH keys — list, load into the agent, or unload.

Called without a subcommand it lists all keys in ~/.ssh.

Subcommands:
  list    - List SSH keys with fingerprints (default)
  load    - Add key to SSH agent
  unload  - Remove key from SSH agent
  clear   - Remove all keys from agent`,
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

	// Subcommands — these mirror the top-level ssh load/unload/clear
	// so that both "ssh keys unload <k>" and "ssh unload <k>" work.
	cmd.AddCommand(newSSHKeysListCmd())
	cmd.AddCommand(newSSHLoadCmd())
	cmd.AddCommand(newSSHUnloadCmd())
	cmd.AddCommand(newSSHClearCmd())

	return cmd
}

// newSSHKeysListCmd is the explicit "keys list" subcommand.
func newSSHKeysListCmd() *cobra.Command {
	var keyDir string

	cmd := &cobra.Command{
		Use:   "list",
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
	type keyRow struct {
		name  string
		bits  int
		ktype string
		fp    string
	}

	// Collect all .pub files
	pattern := filepath.Join(keyDir, "*.pub")
	matches, err := filepath.Glob(pattern)
	if err != nil {
		return fmt.Errorf("error searching for keys: %w", err)
	}
	sort.Strings(matches)

	var rows []keyRow
	for _, pubPath := range matches {
		name := strings.TrimSuffix(filepath.Base(pubPath), ".pub")
		pubData, err := os.ReadFile(pubPath)
		if err != nil {
			rows = append(rows, keyRow{name: name, ktype: "error", fp: err.Error()})
			continue
		}
		pubKey, _, _, _, err := ssh.ParseAuthorizedKey(pubData)
		if err != nil {
			rows = append(rows, keyRow{name: name, ktype: "parse error", fp: err.Error()})
			continue
		}
		rows = append(rows, keyRow{
			name:  name,
			bits:  getKeyBits(pubKey),
			ktype: pubKey.Type(),
			fp:    ssh.FingerprintSHA256(pubKey),
		})
	}

	box  := sshLogoColor()
	dim  := color.New(color.Faint)
	bold := color.New(color.Bold)

	const (
		hName = "Name"
		hBits = "Bits"
		hType = "Type"
		hFP   = "Fingerprint (SHA256)"
	)

	// Column widths — at least as wide as the header
	wName, wBits, wType, wFP := len(hName), len(hBits), len(hType), len(hFP)
	for _, r := range rows {
		if n := len(r.name); n > wName {
			wName = n
		}
		if n := len(fmt.Sprintf("%d", r.bits)); n > wBits {
			wBits = n
		}
		if n := len(r.ktype); n > wType {
			wType = n
		}
		if n := len(r.fp); n > wFP {
			wFP = n
		}
	}

	// Padded cell strings — width is set before coloring so ANSI codes
	// do not break column alignment.
	lpad := func(s string, w int) string { return fmt.Sprintf(" %-*s ", w, s) }
	rpad := func(s string, w int) string { return fmt.Sprintf(" %*s ", w, s) }

	// Horizontal rule builder
	seg  := func(w int) string { return strings.Repeat("─", w+2) }
	hLine := func(l, m, r string) string {
		return l + seg(wName) + m + seg(wBits) + m + seg(wType) + m + seg(wFP) + r
	}

	pipe := box.Sprint("│")

	fmt.Println()
	box.Printf("  %s\n", hLine("╭", "┬", "╮"))

	// Header row
	fmt.Printf("  %s%s%s%s%s%s%s%s%s\n",
		pipe,
		bold.Sprint(lpad(hName, wName)),
		pipe,
		bold.Sprint(rpad(hBits, wBits)),
		pipe,
		bold.Sprint(lpad(hType, wType)),
		pipe,
		bold.Sprint(lpad(hFP, wFP)),
		pipe,
	)

	box.Printf("  %s\n", hLine("├", "┼", "┤"))

	if len(rows) == 0 {
		// Single spanning row: inner width = 4 cols of padding + 3 interior separators
		innerTotal := wName + wBits + wType + wFP + 11
		fmt.Printf("  %s%s%s\n", pipe, dim.Sprint(fmt.Sprintf(" %-*s", innerTotal-1, "No SSH keys found")), pipe)
	} else {
		for _, r := range rows {
			bStr := fmt.Sprintf("%d", r.bits)
			fmt.Printf("  %s%s%s%s%s%s%s%s%s\n",
				pipe,
				lpad(r.name, wName),
				pipe,
				dim.Sprint(rpad(bStr, wBits)),
				pipe,
				lpad(r.ktype, wType),
				pipe,
				dim.Sprint(lpad(r.fp, wFP)),
				pipe,
			)
		}
	}

	box.Printf("  %s\n", hLine("╰", "┴", "╯"))
	fmt.Println()
	fmt.Printf("  %s\n\n", dim.Sprintf("%d key(s) in %s", len(rows), keyDir))
	return nil
}

// resolveSSHAgentPID returns the SSH agent PID and a display label.
// Handles platform-specific agent management:
//   - macOS: launchd manages the agent, never sets SSH_AGENT_PID
//   - Linux: ssh-agent -s or systemd user service
//   - Windows: OpenSSH service (ssh-agent), no pgrep
func resolveSSHAgentPID() (pid string, label string) {
	// 1. Check the standard env var (set by `eval $(ssh-agent -s)`)
	if envPID := os.Getenv("SSH_AGENT_PID"); envPID != "" {
		return envPID, envPID
	}

	authSock := os.Getenv("SSH_AUTH_SOCK")

	// 2. Platform-specific detection
	switch runtime.GOOS {
	case "darwin":
		isLaunchd := strings.Contains(authSock, "com.apple.launchd")
		if p := pgrepSSHAgent(); p != "" {
			if isLaunchd {
				return p, p + " (launchd)"
			}
			return p, p
		}
		if isLaunchd {
			return "", "launchd"
		}

	case "windows":
		// Windows OpenSSH agent runs as a service; query via sc/tasklist
		if out, err := exec.Command("tasklist", "/FI", "IMAGENAME eq ssh-agent.exe", "/FO", "CSV", "/NH").Output(); err == nil {
			line := strings.TrimSpace(string(out))
			// CSV format: "ssh-agent.exe","PID","Session","Session#","Mem Usage"
			if strings.Contains(line, "ssh-agent") {
				fields := strings.Split(line, ",")
				if len(fields) >= 2 {
					p := strings.Trim(fields[1], "\"")
					return p, p + " (service)"
				}
			}
		}
		// Named pipe socket means the Windows service is managing it
		if strings.Contains(authSock, "pipe") || strings.Contains(authSock, "openssh") {
			return "", "service"
		}

	default: // linux, freebsd, etc.
		if p := pgrepSSHAgent(); p != "" {
			return p, p
		}
	}

	return "", "unknown"
}

// pgrepSSHAgent tries to find the ssh-agent PID via pgrep (Unix only).
// Returns the first PID found, or empty string.
func pgrepSSHAgent() string {
	out, err := exec.Command("pgrep", "-x", "ssh-agent").Output()
	if err != nil {
		return ""
	}
	pids := strings.Fields(strings.TrimSpace(string(out)))
	if len(pids) > 0 {
		return pids[0]
	}
	return ""
}

// sshLogoColor returns the accent color used for SSH tool banners and grids.
// Matches the logo color logic in runSSHStatusLocal:
//   - Magenta: SSH agent is running (SSH_AUTH_SOCK set)
//   - Red:     no agent
func sshLogoColor() *color.Color {
	if os.Getenv("SSH_AUTH_SOCK") != "" {
		return color.New(color.FgMagenta)
	}
	return color.New(color.FgRed)
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
		return fmt.Errorf("failed to open key file '%s': %w", path, err)
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
		Use:     "list",
		Aliases: []string{"hosts"},
		Short:   "List configured SSH hosts",
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

	type hostRow struct {
		name     string
		hostname string
		user     string
		port     string
		identity string
	}

	hostRegex := regexp.MustCompile(`(?i)^Host\s+(.+)$`)
	kvRegex := regexp.MustCompile(`(?i)^\s+(HostName|User|Port|IdentityFile)\s+(.+)$`)

	var rows []hostRow
	var current *hostRow

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()

		if matches := hostRegex.FindStringSubmatch(line); matches != nil {
			// Save previous host
			if current != nil {
				rows = append(rows, *current)
			}
			hostnames := strings.Fields(matches[1])
			// Skip wildcard-only entries
			name := ""
			for _, h := range hostnames {
				if !strings.Contains(h, "*") && !strings.Contains(h, "?") {
					name = h
					break
				}
			}
			if name == "" {
				current = nil
				continue
			}
			current = &hostRow{name: name}
		} else if current != nil {
			if kv := kvRegex.FindStringSubmatch(line); kv != nil {
				switch strings.ToLower(kv[1]) {
				case "hostname":
					current.hostname = kv[2]
				case "user":
					current.user = kv[2]
				case "port":
					current.port = kv[2]
				case "identityfile":
					current.identity = kv[2]
				}
			}
		}
	}
	// Don't forget the last host
	if current != nil {
		rows = append(rows, *current)
	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf("error reading SSH config: %w", err)
	}

	// Deduplicate by name, keep first occurrence
	seen := make(map[string]bool)
	var deduped []hostRow
	for _, r := range rows {
		if !seen[r.name] {
			seen[r.name] = true
			deduped = append(deduped, r)
		}
	}
	rows = deduped

	// Sort by name
	sort.Slice(rows, func(i, j int) bool { return rows[i].name < rows[j].name })

	// Fill in defaults for display
	for i := range rows {
		if rows[i].hostname == "" {
			rows[i].hostname = "-"
		}
		if rows[i].user == "" {
			rows[i].user = "-"
		}
		if rows[i].port == "" {
			rows[i].port = "22"
		}
		if rows[i].identity == "" {
			rows[i].identity = "-"
		} else {
			// Shorten home dir paths for display
			rows[i].identity = strings.Replace(rows[i].identity, home, "~", 1)
		}
	}

	box := sshLogoColor()
	dim := color.New(color.Faint)
	bold := color.New(color.Bold)

	const (
		hHost     = "Host"
		hHostname = "HostName"
		hUser     = "User"
		hPort     = "Port"
		hIdentity = "IdentityFile"
	)

	// Column widths — at least as wide as the header
	wHost, wHostname, wUser, wPort, wIdentity := len(hHost), len(hHostname), len(hUser), len(hPort), len(hIdentity)
	for _, r := range rows {
		if n := len(r.name); n > wHost {
			wHost = n
		}
		if n := len(r.hostname); n > wHostname {
			wHostname = n
		}
		if n := len(r.user); n > wUser {
			wUser = n
		}
		if n := len(r.port); n > wPort {
			wPort = n
		}
		if n := len(r.identity); n > wIdentity {
			wIdentity = n
		}
	}

	// Padded cell helpers
	lpad := func(s string, w int) string { return fmt.Sprintf(" %-*s ", w, s) }
	rpad := func(s string, w int) string { return fmt.Sprintf(" %*s ", w, s) }

	// Horizontal rule builder
	seg := func(w int) string { return strings.Repeat("─", w+2) }
	hLine := func(l, m, r string) string {
		return l + seg(wHost) + m + seg(wHostname) + m + seg(wUser) + m + seg(wPort) + m + seg(wIdentity) + r
	}

	pipe := box.Sprint("│")

	fmt.Println()
	box.Printf("  %s\n", hLine("╭", "┬", "╮"))

	// Header row
	fmt.Printf("  %s%s%s%s%s%s%s%s%s%s%s\n",
		pipe,
		bold.Sprint(lpad(hHost, wHost)),
		pipe,
		bold.Sprint(lpad(hHostname, wHostname)),
		pipe,
		bold.Sprint(lpad(hUser, wUser)),
		pipe,
		bold.Sprint(rpad(hPort, wPort)),
		pipe,
		bold.Sprint(lpad(hIdentity, wIdentity)),
		pipe,
	)

	box.Printf("  %s\n", hLine("├", "┼", "┤"))

	if len(rows) == 0 {
		innerTotal := wHost + wHostname + wUser + wPort + wIdentity + 14
		fmt.Printf("  %s%s%s\n", pipe, dim.Sprint(fmt.Sprintf(" %-*s", innerTotal-1, "No SSH hosts configured")), pipe)
	} else {
		for _, r := range rows {
			fmt.Printf("  %s%s%s%s%s%s%s%s%s%s%s\n",
				pipe,
				lpad(r.name, wHost),
				pipe,
				dim.Sprint(lpad(r.hostname, wHostname)),
				pipe,
				lpad(r.user, wUser),
				pipe,
				dim.Sprint(rpad(r.port, wPort)),
				pipe,
				dim.Sprint(lpad(r.identity, wIdentity)),
				pipe,
			)
		}
	}

	box.Printf("  %s\n", hLine("╰", "┴", "╯"))
	fmt.Println()
	fmt.Printf("  %s\n\n", dim.Sprintf("%d host(s) in %s", len(rows), configPath))
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
	box := sshLogoColor()
	dim := color.New(color.Faint)
	bold := color.New(color.Bold)
	green := color.New(color.FgGreen)
	red := color.New(color.FgRed)

	// Check SSH_AUTH_SOCK
	authSock := os.Getenv("SSH_AUTH_SOCK")
	if authSock == "" {
		fmt.Println()
		fmt.Printf("  %s  %s\n", bold.Sprint("SSH Agent"), red.Sprint("○ not running"))
		fmt.Printf("  %s  %s\n", dim.Sprint("Socket"), dim.Sprint("not set"))
		fmt.Println()
		fmt.Printf("  Start the agent with:\n")
		if runtime.GOOS == "windows" {
			fmt.Println("    Start-Service ssh-agent")
		} else {
			fmt.Println("    eval \"$(ssh-agent -s)\"")
		}
		fmt.Println()
		return nil
	}

	_, agentLabel := resolveSSHAgentPID()

	fmt.Println()
	fmt.Printf("  %s  %s  %s\n", bold.Sprint("SSH Agent"), green.Sprint("● running"), dim.Sprintf("PID: %s", agentLabel))
	fmt.Printf("  %s  %s\n", dim.Sprint("Socket"), dim.Sprint(authSock))
	fmt.Println()

	// Try to list keys
	agentCmd := exec.Command("ssh-add", "-l")
	output, err := agentCmd.Output()

	type agentKeyRow struct {
		bits    string
		fp      string
		comment string
		ktype   string
	}

	var rows []agentKeyRow

	if err != nil {
		if strings.Contains(string(output), "no identities") || agentCmd.ProcessState.ExitCode() == 1 {
			// No keys — will show empty table
		} else {
			return fmt.Errorf("error listing keys: %w", err)
		}
	} else {
		// Parse ssh-add -l output: "256 SHA256:xxxxx comment (TYPE)"
		for _, line := range strings.Split(strings.TrimSpace(string(output)), "\n") {
			if line == "" {
				continue
			}
			fields := strings.Fields(line)
			if len(fields) < 4 {
				continue
			}
			bits := fields[0]
			fp := fields[1]
			// Last field is (TYPE), everything between is the comment
			ktype := strings.Trim(fields[len(fields)-1], "()")
			comment := strings.Join(fields[2:len(fields)-1], " ")
			rows = append(rows, agentKeyRow{bits: bits, fp: fp, comment: comment, ktype: ktype})
		}
	}

	const (
		hComment = "Comment"
		hBits    = "Bits"
		hType    = "Type"
		hFP      = "Fingerprint (SHA256)"
	)

	wComment, wBits, wType, wFP := len(hComment), len(hBits), len(hType), len(hFP)
	for _, r := range rows {
		if n := len(r.comment); n > wComment {
			wComment = n
		}
		if n := len(r.bits); n > wBits {
			wBits = n
		}
		if n := len(r.ktype); n > wType {
			wType = n
		}
		if n := len(r.fp); n > wFP {
			wFP = n
		}
	}

	lpad := func(s string, w int) string { return fmt.Sprintf(" %-*s ", w, s) }
	rpad := func(s string, w int) string { return fmt.Sprintf(" %*s ", w, s) }

	seg := func(w int) string { return strings.Repeat("─", w+2) }
	hLine := func(l, m, r string) string {
		return l + seg(wComment) + m + seg(wBits) + m + seg(wType) + m + seg(wFP) + r
	}

	pipe := box.Sprint("│")

	box.Printf("  %s\n", hLine("╭", "┬", "╮"))

	fmt.Printf("  %s%s%s%s%s%s%s%s%s\n",
		pipe,
		bold.Sprint(lpad(hComment, wComment)),
		pipe,
		bold.Sprint(rpad(hBits, wBits)),
		pipe,
		bold.Sprint(lpad(hType, wType)),
		pipe,
		bold.Sprint(lpad(hFP, wFP)),
		pipe,
	)

	box.Printf("  %s\n", hLine("├", "┼", "┤"))

	if len(rows) == 0 {
		innerTotal := wComment + wBits + wType + wFP + 11
		fmt.Printf("  %s%s%s\n", pipe, dim.Sprint(fmt.Sprintf(" %-*s", innerTotal-1, "No keys loaded")), pipe)
	} else {
		for _, r := range rows {
			fmt.Printf("  %s%s%s%s%s%s%s%s%s\n",
				pipe,
				lpad(r.comment, wComment),
				pipe,
				dim.Sprint(rpad(r.bits, wBits)),
				pipe,
				lpad(r.ktype, wType),
				pipe,
				dim.Sprint(lpad(r.fp, wFP)),
				pipe,
			)
		}
	}

	box.Printf("  %s\n", hLine("╰", "┴", "╯"))
	fmt.Println()
	fmt.Printf("  %s\n\n", dim.Sprintf("%d key(s) loaded in agent", len(rows)))
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

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to copy SSH key to '%s': %w", host, err)
	}
	return nil
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

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to create SSH tunnel to '%s': %w", host, err)
	}
	return nil
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

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to create SOCKS5 proxy through '%s': %w", host, err)
	}
	return nil
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

	// Color matches sshLogoColor() — magenta when agent active, red otherwise
	logoColor := sshLogoColor()

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
		_, agentLabel := resolveSSHAgentPID()
		fmt.Printf("    %s     %s %s\n", dim.Sprint("Agent"), green.Sprint("● running"), dim.Sprintf("(PID: %s)", agentLabel))

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

// =============================================================================
// SSH Agent Key Management
// =============================================================================

// newSSHLoadCmd adds key to agent
func newSSHLoadCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "load [key]",
		Short: "Add key to SSH agent",
		Long: `Add SSH key to the agent.

If no key is specified, adds default keys.
Key can be a full path or just the name (will search in ~/.ssh/).

Examples:
  blackdot tools ssh load                    # Load default keys
  blackdot tools ssh load github             # Load ~/.ssh/id_ed25519_github
  blackdot tools ssh load ~/.ssh/id_rsa      # Load specific key`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 {
				return sshLoadDefault()
			}
			return sshLoadKey(args[0])
		},
	}
}

func sshLoadDefault() error {
	fmt.Println("Loading default SSH keys...")
	cmd := exec.Command("ssh-add")
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to load default keys: %w", err)
	}

	fmt.Println("\nCurrently loaded keys:")
	listCmd := exec.Command("ssh-add", "-l")
	listCmd.Stdout = os.Stdout
	listCmd.Stderr = os.Stderr
	if err := listCmd.Run(); err != nil {
		return fmt.Errorf("failed to list loaded keys: %w", err)
	}
	return nil
}

func sshLoadKey(key string) error {
	home, _ := os.UserHomeDir()
	sshDir := filepath.Join(home, ".ssh")

	// Try to find the key
	keyPath := key
	if _, err := os.Stat(keyPath); os.IsNotExist(err) {
		// Try in .ssh directory
		keyPath = filepath.Join(sshDir, key)
		if _, err := os.Stat(keyPath); os.IsNotExist(err) {
			// Try with id_ed25519_ prefix
			keyPath = filepath.Join(sshDir, "id_ed25519_"+key)
			if _, err := os.Stat(keyPath); os.IsNotExist(err) {
				// Try with id_rsa_ prefix
				keyPath = filepath.Join(sshDir, "id_rsa_"+key)
				if _, err := os.Stat(keyPath); os.IsNotExist(err) {
					return fmt.Errorf("key not found: %s\n\nAvailable keys:\n%s", key, listAvailableKeys(sshDir))
				}
			}
		}
	}

	cmd := exec.Command("ssh-add", keyPath)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to add key: %w", err)
	}

	fmt.Println("\nCurrently loaded keys:")
	listCmd := exec.Command("ssh-add", "-l")
	listCmd.Stdout = os.Stdout
	listCmd.Stderr = os.Stderr
	if err := listCmd.Run(); err != nil {
		return fmt.Errorf("failed to list loaded keys: %w", err)
	}
	return nil
}

func listAvailableKeys(sshDir string) string {
	files, _ := filepath.Glob(filepath.Join(sshDir, "id_*"))
	var keys []string
	for _, f := range files {
		if !strings.HasSuffix(f, ".pub") {
			keys = append(keys, "  "+filepath.Base(f))
		}
	}
	if len(keys) == 0 {
		return "  (no keys found)"
	}
	return strings.Join(keys, "\n")
}

// newSSHUnloadCmd removes key from agent
func newSSHUnloadCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "unload <key>",
		Short: "Remove key from SSH agent",
		Long: `Remove a specific SSH key from the agent.

Examples:
  blackdot tools ssh unload github
  blackdot tools ssh unload ~/.ssh/id_ed25519`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return sshUnloadKey(args[0])
		},
	}
}

func sshUnloadKey(key string) error {
	home, _ := os.UserHomeDir()
	sshDir := filepath.Join(home, ".ssh")

	// Try to find the key
	keyPath := key
	if _, err := os.Stat(keyPath); os.IsNotExist(err) {
		keyPath = filepath.Join(sshDir, key)
		if _, err := os.Stat(keyPath); os.IsNotExist(err) {
			keyPath = filepath.Join(sshDir, "id_ed25519_"+key)
			if _, err := os.Stat(keyPath); os.IsNotExist(err) {
				keyPath = filepath.Join(sshDir, "id_rsa_"+key)
			}
		}
	}

	// Try removing the private key
	cmd := exec.Command("ssh-add", "-d", keyPath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		// Try with .pub extension
		cmd = exec.Command("ssh-add", "-d", keyPath+".pub")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to remove key: %w", err)
		}
	}

	fmt.Println("Removed key from agent")
	return nil
}

// newSSHClearCmd removes all keys from agent
func newSSHClearCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "clear",
		Short: "Remove all keys from SSH agent",
		Long:  `Remove all loaded keys from the SSH agent.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return sshClearAgent()
		},
	}
}

func sshClearAgent() error {
	fmt.Println("Removing all keys from SSH agent...")
	cmd := exec.Command("ssh-add", "-D")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to clear agent: %w", err)
	}
	fmt.Println("Done. No keys loaded.")
	return nil
}

// =============================================================================
// SSH Connection Management
// =============================================================================

// newSSHTunnelsCmd lists active SSH connections
func newSSHTunnelsCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "tunnels",
		Short: "List active SSH connections",
		Long:  `List all active SSH connections and tunnels.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return sshListTunnels()
		},
	}
}

func sshListTunnels() error {
	fmt.Println("Active SSH Connections:")
	fmt.Println(strings.Repeat("─", 40))

	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		// Windows: use tasklist
		cmd = exec.Command("tasklist", "/FI", "IMAGENAME eq ssh.exe", "/FO", "LIST")
	} else {
		// Unix: use ps
		cmd = exec.Command("sh", "-c", "ps aux | grep '[s]sh ' | grep -v grep")
	}

	output, err := cmd.Output()
	if err != nil || len(strings.TrimSpace(string(output))) == 0 {
		fmt.Println("  No active SSH connections")
		return nil
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	for _, line := range lines {
		if line != "" {
			if runtime.GOOS == "windows" {
				fmt.Printf("  %s\n", line)
			} else {
				parts := strings.Fields(line)
				if len(parts) >= 11 {
					pid := parts[1]
					cmdStr := strings.Join(parts[10:], " ")
					fmt.Printf("  PID %s: %s\n", pid, cmdStr)
				}
			}
		}
	}

	return nil
}

// newSSHAddHostCmd adds a new host to SSH config
func newSSHAddHostCmd() *cobra.Command {
	var hostname, user, port, identity string

	cmd := &cobra.Command{
		Use:   "add-host <name>",
		Short: "Add new host to SSH config",
		Long: `Add a new host entry to ~/.ssh/config.

Example:
  blackdot tools ssh add-host myserver --hostname 192.168.1.100 --user admin`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return sshAddHost(args[0], hostname, user, port, identity)
		},
	}

	cmd.Flags().StringVar(&hostname, "hostname", "", "Hostname or IP address (required)")
	cmd.Flags().StringVarP(&user, "user", "u", "", "Username (defaults to current user)")
	cmd.Flags().StringVarP(&port, "port", "p", "22", "Port number")
	cmd.Flags().StringVarP(&identity, "identity", "i", "", "Identity file path")
	cmd.MarkFlagRequired("hostname")

	return cmd
}

func sshAddHost(name, hostname, user, port, identity string) error {
	home, _ := os.UserHomeDir()
	configPath := filepath.Join(home, ".ssh", "config")

	// Default user to current user
	if user == "" {
		user = os.Getenv("USER")
		if user == "" {
			user = os.Getenv("USERNAME") // Windows
		}
	}

	// Build host entry
	var entry strings.Builder
	entry.WriteString("\n")
	entry.WriteString(fmt.Sprintf("Host %s\n", name))
	entry.WriteString(fmt.Sprintf("    HostName %s\n", hostname))
	entry.WriteString(fmt.Sprintf("    User %s\n", user))
	if port != "22" {
		entry.WriteString(fmt.Sprintf("    Port %s\n", port))
	}
	if identity != "" {
		entry.WriteString(fmt.Sprintf("    IdentityFile %s\n", identity))
	}

	// Ensure .ssh directory exists
	sshDir := filepath.Join(home, ".ssh")
	if err := os.MkdirAll(sshDir, 0700); err != nil {
		return fmt.Errorf("failed to create .ssh directory: %w", err)
	}

	// Append to config
	f, err := os.OpenFile(configPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return fmt.Errorf("failed to open SSH config: %w", err)
	}
	defer f.Close()

	if _, err := f.WriteString(entry.String()); err != nil {
		return fmt.Errorf("failed to write to SSH config: %w", err)
	}

	fmt.Printf("Added host '%s' to %s\n", name, configPath)
	fmt.Printf("Connect with: ssh %s\n", name)
	return nil
}

// newSSHRemoveHostCmd removes a host from SSH config
func newSSHRemoveHostCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "remove-host <name>",
		Short: "Remove host from SSH config",
		Long: `Remove a host entry from ~/.ssh/config.

Removes the Host block and all its directives (HostName, User, Port, etc.).

Example:
  blackdot tools ssh remove-host myserver`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return sshRemoveHost(args[0])
		},
	}
}

func sshRemoveHost(name string) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("cannot determine home directory: %w", err)
	}

	configPath := filepath.Join(home, ".ssh", "config")

	data, err := os.ReadFile(configPath)
	if err != nil {
		return fmt.Errorf("cannot read SSH config: %w", err)
	}

	lines := strings.Split(string(data), "\n")
	hostRegex := regexp.MustCompile(`(?i)^Host\s+(.+)$`)

	var result []string
	skipping := false
	found := false

	for _, line := range lines {
		if matches := hostRegex.FindStringSubmatch(line); matches != nil {
			// Check if this Host line contains our target
			hostnames := strings.Fields(matches[1])
			isTarget := false
			for _, h := range hostnames {
				if h == name {
					isTarget = true
					break
				}
			}
			if isTarget {
				skipping = true
				found = true
				// Remove any preceding blank line we already added
				for len(result) > 0 && strings.TrimSpace(result[len(result)-1]) == "" {
					result = result[:len(result)-1]
				}
				continue
			}
			skipping = false
		} else if skipping {
			// Skip indented lines (directives) belonging to the removed host
			trimmed := strings.TrimSpace(line)
			if trimmed == "" || strings.HasPrefix(line, " ") || strings.HasPrefix(line, "\t") {
				continue
			}
			// Non-indented, non-empty, non-Host line — stop skipping
			skipping = false
		}

		if !skipping {
			result = append(result, line)
		}
	}

	if !found {
		return fmt.Errorf("host '%s' not found in %s", name, configPath)
	}

	// Clean up trailing blank lines
	for len(result) > 0 && strings.TrimSpace(result[len(result)-1]) == "" {
		result = result[:len(result)-1]
	}
	output := strings.Join(result, "\n") + "\n"

	if err := os.WriteFile(configPath, []byte(output), 0600); err != nil {
		return fmt.Errorf("failed to write SSH config: %w", err)
	}

	fmt.Printf("Removed host '%s' from %s\n", name, configPath)
	return nil
}
