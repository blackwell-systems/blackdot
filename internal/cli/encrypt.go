package cli

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// Patterns for files that should be encrypted
var encryptPatterns = []string{
	"*.secret",
	"*.private",
	"*credentials*",
	"_variables.local.sh",
	"_arrays.local.json",
}

func newEncryptCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "encrypt",
		Short: "Age encryption management for dotfiles",
		RunE: func(cmd *cobra.Command, args []string) error {
			// If first arg is a file, treat as encrypt shortcut
			if len(args) > 0 {
				if _, err := os.Stat(args[0]); err == nil {
					return runEncryptFile(cmd, args)
				}
			}
			printEncryptHelp()
			return nil
		},
	}

	// Set custom help function
	cmd.SetHelpFunc(func(cmd *cobra.Command, args []string) {
		printEncryptHelp()
	})

	// Add subcommands
	initCmd := &cobra.Command{
		Use:   "init",
		Short: "Initialize age encryption (generate key pair)",
		RunE:  runEncryptInit,
	}
	initCmd.Flags().BoolP("force", "f", false, "Force regeneration of keys")

	encryptCmd := &cobra.Command{
		Use:   "file <file>",
		Short: "Encrypt a file",
		RunE:  runEncryptFile,
	}
	encryptCmd.Flags().BoolP("keep", "k", false, "Keep original file")
	encryptCmd.Flags().BoolP("dry-run", "n", false, "Show what would be done")

	decryptCmd := &cobra.Command{
		Use:   "decrypt <file>",
		Short: "Decrypt a .age file",
		RunE:  runDecryptFile,
	}
	decryptCmd.Flags().BoolP("keep", "k", false, "Keep encrypted file")
	decryptCmd.Flags().BoolP("dry-run", "n", false, "Show what would be done")

	editCmd := &cobra.Command{
		Use:   "edit <file>",
		Short: "Decrypt, edit in $EDITOR, re-encrypt",
		RunE:  runEncryptEdit,
	}

	cmd.AddCommand(
		initCmd,
		encryptCmd,
		decryptCmd,
		editCmd,
		&cobra.Command{
			Use:   "list",
			Short: "List encrypted and unencrypted sensitive files",
			RunE:  runEncryptList,
		},
		&cobra.Command{
			Use:   "status",
			Short: "Show encryption status and key info",
			RunE:  runEncryptStatus,
		},
		&cobra.Command{
			Use:   "push-key",
			Short: "Push private key to vault for backup",
			RunE:  runEncryptPushKey,
		},
	)

	return cmd
}

func getEncryptionDir() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "dotfiles")
}

func getAgeKeyFile() string {
	return filepath.Join(getEncryptionDir(), "age-key.txt")
}

func getAgeRecipientsFile() string {
	return filepath.Join(getEncryptionDir(), "age-recipients.txt")
}

func isAgeInstalled() bool {
	_, err := exec.LookPath("age")
	return err == nil
}

func isEncryptionInitialized() bool {
	keyFile := getAgeKeyFile()
	recipientsFile := getAgeRecipientsFile()
	_, err1 := os.Stat(keyFile)
	_, err2 := os.Stat(recipientsFile)
	return err1 == nil && err2 == nil
}

func getPublicKey() (string, error) {
	data, err := os.ReadFile(getAgeRecipientsFile())
	if err != nil {
		return "", err
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) > 0 {
		return lines[0], nil
	}
	return "", fmt.Errorf("no public key found")
}

func runEncryptInit(cmd *cobra.Command, args []string) error {
	force, _ := cmd.Flags().GetBool("force")

	if !isAgeInstalled() {
		fmt.Println(color.RedString("[FAIL]") + " 'age' is not installed")
		fmt.Println("Install with: brew install age")
		return fmt.Errorf("age not installed")
	}

	if isEncryptionInitialized() && !force {
		fmt.Println("Encryption already initialized.")
		fmt.Printf("Key file: %s\n", getAgeKeyFile())
		if pubKey, err := getPublicKey(); err == nil {
			fmt.Printf("Public key: %s\n", pubKey)
		}
		fmt.Println()
		fmt.Println("Use --force to regenerate keys (WARNING: will lose access to encrypted files)")
		return nil
	}

	// Create directory
	encDir := getEncryptionDir()
	if err := os.MkdirAll(encDir, 0755); err != nil {
		return fmt.Errorf("creating encryption directory: %w", err)
	}

	// Generate new key pair using age-keygen
	fmt.Println("Generating new age key pair...")

	keyFile := getAgeKeyFile()
	keygenCmd := exec.Command("age-keygen", "-o", keyFile)
	output, err := keygenCmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("generating key: %w", err)
	}

	// Extract public key from output or key file
	var publicKey string
	outputStr := string(output)

	// Try to find public key in output first
	for _, line := range strings.Split(outputStr, "\n") {
		if strings.HasPrefix(line, "age1") {
			publicKey = strings.TrimSpace(line)
			break
		}
		if strings.Contains(line, "Public key:") {
			parts := strings.SplitN(line, ":", 2)
			if len(parts) == 2 {
				publicKey = strings.TrimSpace(parts[1])
				break
			}
		}
	}

	// If not found in output, read from key file
	if publicKey == "" {
		keyContent, err := os.ReadFile(keyFile)
		if err == nil {
			for _, line := range strings.Split(string(keyContent), "\n") {
				if strings.Contains(line, "public key:") {
					parts := strings.SplitN(line, ":", 2)
					if len(parts) == 2 {
						publicKey = strings.TrimSpace(parts[1])
						break
					}
				}
			}
		}
	}

	// Write public key to recipients file
	recipientsFile := getAgeRecipientsFile()
	if publicKey != "" {
		if err := os.WriteFile(recipientsFile, []byte(publicKey+"\n"), 0644); err != nil {
			return fmt.Errorf("writing recipients file: %w", err)
		}
	}

	// Secure the private key
	if err := os.Chmod(keyFile, 0600); err != nil {
		return fmt.Errorf("securing key file: %w", err)
	}

	fmt.Println()
	fmt.Println(color.GreenString("[OK]") + " Encryption initialized!")
	fmt.Printf("  Private key: %s (keep this safe!)\n", keyFile)
	if publicKey != "" {
		fmt.Printf("  Public key:  %s\n", publicKey)
	}
	fmt.Println()
	fmt.Println("IMPORTANT: Back up your private key to your vault:")
	fmt.Println("  blackdot encrypt push-key")

	return nil
}

func runEncryptFile(cmd *cobra.Command, args []string) error {
	keep, _ := cmd.Flags().GetBool("keep")
	dryRun, _ := cmd.Flags().GetBool("dry-run")

	if len(args) == 0 {
		fmt.Println(color.RedString("[FAIL]") + " No file specified")
		fmt.Println("Usage: blackdot encrypt file <file>")
		return fmt.Errorf("no file specified")
	}

	inputFile := args[0]
	outputFile := inputFile + ".age"

	if dryRun {
		fmt.Printf("[DRY-RUN] Would encrypt: %s -> %s\n", inputFile, outputFile)
		return nil
	}

	if !isAgeInstalled() {
		fmt.Println(color.RedString("[FAIL]") + " 'age' is not installed")
		return fmt.Errorf("age not installed")
	}

	if !isEncryptionInitialized() {
		fmt.Println(color.RedString("[FAIL]") + " Encryption not initialized")
		fmt.Println("Run: blackdot encrypt init")
		return fmt.Errorf("encryption not initialized")
	}

	if _, err := os.Stat(inputFile); os.IsNotExist(err) {
		fmt.Printf("%s File not found: %s\n", color.RedString("[FAIL]"), inputFile)
		return fmt.Errorf("file not found: %s", inputFile)
	}

	if strings.HasSuffix(inputFile, ".age") {
		fmt.Printf("%s File appears to already be encrypted: %s\n", color.RedString("[FAIL]"), inputFile)
		return fmt.Errorf("file already encrypted")
	}

	// Encrypt using recipients file
	encryptCmd := exec.Command("age", "-R", getAgeRecipientsFile(), "-o", outputFile, inputFile)
	if err := encryptCmd.Run(); err != nil {
		return fmt.Errorf("encrypting file: %w", err)
	}

	if !keep {
		if err := os.Remove(inputFile); err != nil {
			return fmt.Errorf("removing original: %w", err)
		}
		fmt.Printf("%s Encrypted: %s -> %s (original removed)\n", color.GreenString("[OK]"), inputFile, outputFile)
	} else {
		fmt.Printf("%s Encrypted: %s -> %s (original kept)\n", color.GreenString("[OK]"), inputFile, outputFile)
	}

	return nil
}

func runDecryptFile(cmd *cobra.Command, args []string) error {
	keep, _ := cmd.Flags().GetBool("keep")
	dryRun, _ := cmd.Flags().GetBool("dry-run")

	if len(args) == 0 {
		fmt.Println(color.RedString("[FAIL]") + " No file specified")
		fmt.Println("Usage: blackdot encrypt decrypt <file.age>")
		return fmt.Errorf("no file specified")
	}

	inputFile := args[0]
	outputFile := strings.TrimSuffix(inputFile, ".age")

	if dryRun {
		fmt.Printf("[DRY-RUN] Would decrypt: %s -> %s\n", inputFile, outputFile)
		return nil
	}

	if !isAgeInstalled() {
		fmt.Println(color.RedString("[FAIL]") + " 'age' is not installed")
		return fmt.Errorf("age not installed")
	}

	if !isEncryptionInitialized() {
		fmt.Println(color.RedString("[FAIL]") + " Encryption not initialized")
		fmt.Println("Run: blackdot encrypt init")
		return fmt.Errorf("encryption not initialized")
	}

	if _, err := os.Stat(inputFile); os.IsNotExist(err) {
		fmt.Printf("%s File not found: %s\n", color.RedString("[FAIL]"), inputFile)
		return fmt.Errorf("file not found: %s", inputFile)
	}

	if !strings.HasSuffix(inputFile, ".age") {
		fmt.Printf("%s Expected .age file: %s\n", color.RedString("[FAIL]"), inputFile)
		return fmt.Errorf("expected .age file")
	}

	// Decrypt using private key
	decryptCmd := exec.Command("age", "-d", "-i", getAgeKeyFile(), "-o", outputFile, inputFile)
	if err := decryptCmd.Run(); err != nil {
		return fmt.Errorf("decrypting file: %w", err)
	}

	if !keep {
		if err := os.Remove(inputFile); err != nil {
			return fmt.Errorf("removing encrypted: %w", err)
		}
		fmt.Printf("%s Decrypted: %s -> %s (encrypted removed)\n", color.GreenString("[OK]"), inputFile, outputFile)
	} else {
		fmt.Printf("%s Decrypted: %s -> %s (encrypted kept)\n", color.GreenString("[OK]"), inputFile, outputFile)
	}

	return nil
}

func runEncryptEdit(cmd *cobra.Command, args []string) error {
	if len(args) == 0 {
		fmt.Println(color.RedString("[FAIL]") + " No file specified")
		fmt.Println("Usage: blackdot encrypt edit <file>")
		return fmt.Errorf("no file specified")
	}

	if !isEncryptionInitialized() {
		fmt.Println(color.RedString("[FAIL]") + " Encryption not initialized")
		return fmt.Errorf("encryption not initialized")
	}

	file := args[0]
	editor := os.Getenv("EDITOR")
	if editor == "" {
		editor = "vi"
	}

	if strings.HasSuffix(file, ".age") {
		// Decrypt to temp file
		tempFile := strings.TrimSuffix(file, ".age")

		// Decrypt (keep encrypted)
		decryptCmd := exec.Command("age", "-d", "-i", getAgeKeyFile(), "-o", tempFile, file)
		if err := decryptCmd.Run(); err != nil {
			return fmt.Errorf("decrypting for edit: %w", err)
		}

		// Edit
		editCmd := exec.Command(editor, tempFile)
		editCmd.Stdin = os.Stdin
		editCmd.Stdout = os.Stdout
		editCmd.Stderr = os.Stderr
		if err := editCmd.Run(); err != nil {
			return fmt.Errorf("editing file: %w", err)
		}

		// Re-encrypt (removes temp file)
		encryptCmd := exec.Command("age", "-R", getAgeRecipientsFile(), "-o", file, tempFile)
		if err := encryptCmd.Run(); err != nil {
			return fmt.Errorf("re-encrypting: %w", err)
		}
		os.Remove(tempFile)

		fmt.Printf("%s Edited and re-encrypted: %s\n", color.GreenString("[OK]"), file)
	} else {
		// File not encrypted, edit then encrypt
		editCmd := exec.Command(editor, file)
		editCmd.Stdin = os.Stdin
		editCmd.Stdout = os.Stdout
		editCmd.Stderr = os.Stderr
		if err := editCmd.Run(); err != nil {
			return fmt.Errorf("editing file: %w", err)
		}

		// Encrypt
		outputFile := file + ".age"
		encryptCmd := exec.Command("age", "-R", getAgeRecipientsFile(), "-o", outputFile, file)
		if err := encryptCmd.Run(); err != nil {
			return fmt.Errorf("encrypting: %w", err)
		}
		os.Remove(file)

		fmt.Printf("%s Encrypted: %s -> %s\n", color.GreenString("[OK]"), file, outputFile)
	}

	return nil
}

func runEncryptList(cmd *cobra.Command, args []string) error {
	home, _ := os.UserHomeDir()
	dotfilesDir := os.Getenv("BLACKDOT_DIR")
	if dotfilesDir == "" {
		dotfilesDir = filepath.Join(home, ".dotfiles")
	}

	bold := color.New(color.Bold).SprintFunc()
	yellow := color.New(color.FgYellow).SprintFunc()

	fmt.Println(bold("Encrypted files (.age):"))
	foundEncrypted := false
	filepath.Walk(dotfilesDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if !info.IsDir() && strings.HasSuffix(path, ".age") {
			foundEncrypted = true
			fmt.Printf("  %s (%d bytes)\n", path, info.Size())
		}
		return nil
	})
	if !foundEncrypted {
		fmt.Println("  (none)")
	}

	fmt.Println()
	fmt.Println(bold("Files that should be encrypted:"))
	foundUnencrypted := false
	for _, pattern := range encryptPatterns {
		filepath.Walk(dotfilesDir, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return nil
			}
			if info.IsDir() {
				return nil
			}
			if strings.HasSuffix(path, ".age") {
				return nil
			}
			matched, _ := filepath.Match(pattern, filepath.Base(path))
			if matched {
				foundUnencrypted = true
				fmt.Printf("  %s %s\n", yellow("[UNENCRYPTED]"), path)
			}
			return nil
		})
	}
	if !foundUnencrypted {
		fmt.Println("  (none)")
	}

	return nil
}

func runEncryptStatus(cmd *cobra.Command, args []string) error {
	bold := color.New(color.Bold).SprintFunc()
	green := color.New(color.FgGreen).SprintFunc()
	red := color.New(color.FgRed).SprintFunc()

	fmt.Println(bold("Age Encryption Status"))
	fmt.Println("=====================")
	fmt.Println()

	if isAgeInstalled() {
		versionCmd := exec.Command("age", "--version")
		output, _ := versionCmd.Output()
		version := strings.TrimSpace(string(output))
		if version == "" {
			version = "(installed)"
		}
		fmt.Printf("age installed: %s\n", green(version))
	} else {
		fmt.Printf("age installed: %s (install with: brew install age)\n", red("NO"))
		return fmt.Errorf("age not installed")
	}

	if isEncryptionInitialized() {
		fmt.Printf("Keys initialized: %s\n", green("YES"))
		fmt.Printf("  Private key: %s\n", getAgeKeyFile())
		if pubKey, err := getPublicKey(); err == nil {
			fmt.Printf("  Public key:  %s\n", pubKey)
		}
	} else {
		fmt.Printf("Keys initialized: %s\n", red("NO"))
		fmt.Println("  Run: blackdot encrypt init")
		return fmt.Errorf("encryption not initialized")
	}

	fmt.Println()

	// Count encrypted files
	home, _ := os.UserHomeDir()
	dotfilesDir := os.Getenv("BLACKDOT_DIR")
	if dotfilesDir == "" {
		dotfilesDir = filepath.Join(home, ".dotfiles")
	}

	count := 0
	filepath.Walk(dotfilesDir, func(path string, info os.FileInfo, err error) error {
		if err == nil && !info.IsDir() && strings.HasSuffix(path, ".age") {
			count++
		}
		return nil
	})
	fmt.Printf("Encrypted files: %d\n", count)

	return nil
}

func runEncryptPushKey(cmd *cobra.Command, args []string) error {
	if !isEncryptionInitialized() {
		fmt.Println(color.RedString("[FAIL]") + " Encryption not initialized")
		return fmt.Errorf("encryption not initialized")
	}

	keyFile := getAgeKeyFile()
	keyContent, err := os.ReadFile(keyFile)
	if err != nil {
		return fmt.Errorf("reading key file: %w", err)
	}

	vaultItem := "Age-Private-Key"
	fmt.Printf("Pushing age key to vault as '%s'...\n", vaultItem)

	// Try to use blackdot vault set
	dotfilesCmd := exec.Command("dotfiles", "vault", "set", vaultItem, "--stdin")
	dotfilesCmd.Stdin = strings.NewReader(string(keyContent))
	if err := dotfilesCmd.Run(); err != nil {
		fmt.Println()
		fmt.Println(color.YellowString("[NOTE]") + " Vault push not implemented yet. Manually save this key:")
		fmt.Printf("  Item name: %s\n", vaultItem)
		fmt.Printf("  Content: (contents of %s)\n", keyFile)
		fmt.Println()
		fmt.Println("To view the key:")
		fmt.Printf("  cat %s\n", keyFile)

		// Offer to show the key
		fmt.Print("\nShow key contents now? [y/N] ")
		reader := bufio.NewReader(os.Stdin)
		response, _ := reader.ReadString('\n')
		if strings.TrimSpace(strings.ToLower(response)) == "y" {
			fmt.Println()
			fmt.Println(string(keyContent))
		}
	} else {
		fmt.Println(color.GreenString("[OK]") + " Key pushed to vault")
	}

	return nil
}

// printEncryptHelp prints styled help matching ZSH format
func printEncryptHelp() {
	// Title
	BoldCyan.Print("blackdot encrypt")
	fmt.Print(" - Age encryption management\n")
	fmt.Println()
	Bold.Print("Usage:")
	fmt.Print(" blackdot encrypt <command> [options]\n")
	fmt.Println()

	// Commands
	BoldCyan.Println("Commands:")
	printCmd("init", "Initialize age encryption (generate key pair)")
	printCmd("file <file>", "Encrypt a file (creates <file>.age)")
	printCmd("decrypt <file>", "Decrypt a .age file (restores original)")
	printCmd("edit <file>", "Decrypt, open in $EDITOR, re-encrypt on save")
	printCmd("list", "List encrypted and unencrypted sensitive files")
	printCmd("status", "Show encryption status and key info")
	printCmd("push-key", "Push private key to vault for backup/recovery")
	fmt.Println()

	// Options
	BoldCyan.Println("Options:")
	fmt.Print("  ")
	Yellow.Print("-k, --keep")
	fmt.Print("      ")
	Dim.Println("Keep original file when encrypting/decrypting")
	fmt.Print("  ")
	Yellow.Print("-f, --force")
	fmt.Print("     ")
	Dim.Println("Force operation (e.g., regenerate keys)")
	fmt.Print("  ")
	Yellow.Print("-n, --dry-run")
	fmt.Print("   ")
	Dim.Println("Show what would be done")
	fmt.Println()

	// Examples
	BoldCyan.Println("Examples:")
	Dim.Println("  # First-time setup")
	fmt.Println("  blackdot encrypt init")
	fmt.Println()
	Dim.Println("  # Encrypt sensitive template variables")
	fmt.Println("  blackdot encrypt templates/_variables.local.sh")
	fmt.Println()
	Dim.Println("  # Decrypt to view/use")
	fmt.Println("  blackdot encrypt decrypt templates/_variables.local.sh.age")
	fmt.Println()
	Dim.Println("  # Edit encrypted file directly")
	fmt.Println("  blackdot encrypt edit templates/_variables.local.sh.age")
	fmt.Println()
	Dim.Println("  # Backup key to vault")
	fmt.Println("  blackdot encrypt push-key")
	fmt.Println()

	// Hook Integration
	BoldCyan.Println("Hook Integration:")
	Dim.Println("  The encryption system integrates with blackdot hooks:")
	fmt.Println()
	fmt.Print("  ")
	Yellow.Print("pre_template_render")
	fmt.Print("  ")
	Dim.Println("Auto-decrypts .age files before rendering")
	fmt.Print("  ")
	Yellow.Print("post_vault_pull")
	fmt.Print("      ")
	Dim.Println("Restores age key from vault if missing locally")
	fmt.Println()

	// Security Notes
	BoldCyan.Println("Security:")
	Dim.Println("  - Private key stored in ~/.config/blackdot/age-key.txt (mode 600)")
	Dim.Println("  - Back up your private key: blackdot encrypt push-key")
	Dim.Println("  - Without the private key, encrypted files cannot be recovered")
	Dim.Println("  - Public key can be safely shared for others to encrypt files for you")
}
