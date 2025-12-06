#!/usr/bin/env zsh
# ============================================================
# Age Encryption Library
# Provides file encryption using the 'age' tool
# https://github.com/FiloSottile/age
# ============================================================

set -euo pipefail

# ============================================================
# Configuration
# ============================================================
ENCRYPTION_DIR="${ENCRYPTION_DIR:-$HOME/.config/dotfiles}"
AGE_KEY_FILE="${AGE_KEY_FILE:-$ENCRYPTION_DIR/age-key.txt}"
AGE_RECIPIENTS_FILE="${AGE_RECIPIENTS_FILE:-$ENCRYPTION_DIR/age-recipients.txt}"

# Patterns for files that should be encrypted
ENCRYPT_PATTERNS=(
    "*.secret"
    "*.private"
    "*credentials*"
    "_variables.local.sh"
    "_arrays.local.json"
)

# ============================================================
# Core Functions
# ============================================================

# Check if age is installed
encryption_available() {
    command -v age >/dev/null 2>&1
}

# Check if encryption is initialized (keys exist)
encryption_initialized() {
    [[ -f "$AGE_KEY_FILE" ]] && [[ -f "$AGE_RECIPIENTS_FILE" ]]
}

# Get the public key (recipient)
encryption_get_public_key() {
    if [[ -f "$AGE_RECIPIENTS_FILE" ]]; then
        head -1 "$AGE_RECIPIENTS_FILE"
    else
        return 1
    fi
}

# Initialize encryption - generate new key pair
encryption_init() {
    local force="${1:-false}"

    if ! encryption_available; then
        echo "Error: 'age' is not installed. Install with: brew install age" >&2
        return 1
    fi

    # Check if already initialized
    if encryption_initialized && [[ "$force" != "true" ]]; then
        echo "Encryption already initialized."
        echo "Key file: $AGE_KEY_FILE"
        echo "Public key: $(encryption_get_public_key)"
        echo ""
        echo "Use --force to regenerate keys (WARNING: will lose access to encrypted files)"
        return 0
    fi

    # Create directory
    mkdir -p "$ENCRYPTION_DIR"

    # Generate new key pair
    echo "Generating new age key pair..."
    age-keygen -o "$AGE_KEY_FILE" 2>&1 | tee "$AGE_RECIPIENTS_FILE.tmp"

    # Extract public key from keygen output
    grep "^age1" "$AGE_RECIPIENTS_FILE.tmp" > "$AGE_RECIPIENTS_FILE" 2>/dev/null || \
    grep "public key:" "$AGE_KEY_FILE" | sed 's/.*: //' > "$AGE_RECIPIENTS_FILE"
    rm -f "$AGE_RECIPIENTS_FILE.tmp"

    # Secure the private key
    chmod 600 "$AGE_KEY_FILE"
    chmod 644 "$AGE_RECIPIENTS_FILE"

    echo ""
    echo "Encryption initialized!"
    echo "  Private key: $AGE_KEY_FILE (keep this safe!)"
    echo "  Public key:  $(cat "$AGE_RECIPIENTS_FILE")"
    echo ""
    echo "IMPORTANT: Back up your private key to your vault:"
    echo "  dotfiles vault push-key  # Store key in vault for recovery"
}

# Encrypt a file
# Usage: encrypt_file <input> [output]
# If output not specified, creates <input>.age and removes original
encrypt_file() {
    local input="$1"
    local output="${2:-${input}.age}"
    local keep_original="${3:-false}"

    if ! encryption_available; then
        echo "Error: 'age' is not installed" >&2
        return 1
    fi

    if ! encryption_initialized; then
        echo "Error: Encryption not initialized. Run: dotfiles encrypt init" >&2
        return 1
    fi

    if [[ ! -f "$input" ]]; then
        echo "Error: File not found: $input" >&2
        return 1
    fi

    # Already encrypted?
    if [[ "$input" == *.age ]]; then
        echo "Error: File appears to already be encrypted: $input" >&2
        return 1
    fi

    # Encrypt using recipients file
    age -R "$AGE_RECIPIENTS_FILE" -o "$output" "$input"

    if [[ "$keep_original" != "true" ]]; then
        # Securely remove original
        rm -f "$input"
        echo "Encrypted: $input -> $output (original removed)"
    else
        echo "Encrypted: $input -> $output (original kept)"
    fi
}

# Decrypt a file
# Usage: decrypt_file <input> [output]
# If output not specified, removes .age extension
decrypt_file() {
    local input="$1"
    local output="${2:-${input%.age}}"
    local keep_encrypted="${3:-false}"

    if ! encryption_available; then
        echo "Error: 'age' is not installed" >&2
        return 1
    fi

    if ! encryption_initialized; then
        echo "Error: Encryption not initialized. Run: dotfiles encrypt init" >&2
        return 1
    fi

    if [[ ! -f "$input" ]]; then
        echo "Error: File not found: $input" >&2
        return 1
    fi

    # Must be .age file
    if [[ "$input" != *.age ]]; then
        echo "Error: Expected .age file: $input" >&2
        return 1
    fi

    # Decrypt using private key
    age -d -i "$AGE_KEY_FILE" -o "$output" "$input"

    if [[ "$keep_encrypted" != "true" ]]; then
        rm -f "$input"
        echo "Decrypted: $input -> $output (encrypted removed)"
    else
        echo "Decrypted: $input -> $output (encrypted kept)"
    fi
}

# Edit an encrypted file (decrypt, edit, re-encrypt)
encrypt_edit() {
    local file="$1"
    local editor="${EDITOR:-vi}"
    local temp_file

    if ! encryption_initialized; then
        echo "Error: Encryption not initialized" >&2
        return 1
    fi

    # Determine if file is encrypted
    if [[ "$file" == *.age ]]; then
        # Decrypt to temp file
        temp_file="${file%.age}"
        decrypt_file "$file" "$temp_file" true

        # Edit
        "$editor" "$temp_file"

        # Re-encrypt
        encrypt_file "$temp_file" "$file"
    else
        # File not encrypted, just edit then encrypt
        "$editor" "$file"
        encrypt_file "$file"
    fi
}

# List all encrypted files in dotfiles
encrypt_list() {
    local dotfiles_dir="${DOTFILES_DIR:-$HOME/workspace/dotfiles}"

    echo "Encrypted files (.age):"
    find "$dotfiles_dir" -name "*.age" -type f 2>/dev/null | while read -r file; do
        local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        printf "  %s (%d bytes)\n" "$file" "$size"
    done

    echo ""
    echo "Files that should be encrypted:"
    for pattern in "${ENCRYPT_PATTERNS[@]}"; do
        find "$dotfiles_dir" -name "$pattern" -type f ! -name "*.age" 2>/dev/null | while read -r file; do
            echo "  [UNENCRYPTED] $file"
        done
    done
}

# Check encryption status
encrypt_status() {
    echo "Age Encryption Status"
    echo "====================="
    echo ""

    if encryption_available; then
        echo "age installed: $(age --version 2>&1 | head -1)"
    else
        echo "age installed: NO (install with: brew install age)"
        return 1
    fi

    if encryption_initialized; then
        echo "Keys initialized: YES"
        echo "  Private key: $AGE_KEY_FILE"
        echo "  Public key:  $(encryption_get_public_key)"
    else
        echo "Keys initialized: NO"
        echo "  Run: dotfiles encrypt init"
        return 1
    fi

    echo ""

    # Count encrypted files
    local dotfiles_dir="${DOTFILES_DIR:-$HOME/workspace/dotfiles}"
    local encrypted_count=$(find "$dotfiles_dir" -name "*.age" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "Encrypted files: $encrypted_count"
}

# ============================================================
# Hook Integration Functions
# ============================================================

# Hook: Auto-decrypt before template rendering
# Called by pre_template_render hook
encryption_hook_pre_template() {
    local templates_dir="${DOTFILES_DIR:-$HOME/workspace/dotfiles}/templates"

    if ! encryption_initialized; then
        return 0  # No keys, skip silently
    fi

    # Decrypt any .age files in templates directory
    find "$templates_dir" -name "*.age" -type f 2>/dev/null | while read -r file; do
        local decrypted="${file%.age}"
        if [[ ! -f "$decrypted" ]] || [[ "$file" -nt "$decrypted" ]]; then
            echo "Decrypting: $file"
            decrypt_file "$file" "$decrypted" true
        fi
    done
}

# Hook: Restore age key from vault
# Called by post_vault_pull hook
encryption_hook_post_vault_pull() {
    local vault_item="Age-Private-Key"

    # Check if vault has the key
    if command -v dotfiles >/dev/null 2>&1; then
        local key_content
        key_content=$(dotfiles vault get "$vault_item" 2>/dev/null) || return 0

        if [[ -n "$key_content" ]] && [[ ! -f "$AGE_KEY_FILE" ]]; then
            echo "Restoring age key from vault..."
            mkdir -p "$ENCRYPTION_DIR"
            echo "$key_content" > "$AGE_KEY_FILE"
            chmod 600 "$AGE_KEY_FILE"

            # Extract public key
            grep "public key:" "$AGE_KEY_FILE" | sed 's/.*: //' > "$AGE_RECIPIENTS_FILE"
            chmod 644 "$AGE_RECIPIENTS_FILE"

            echo "Age key restored from vault"
        fi
    fi
}

# Hook: Push age key to vault
encryption_push_key_to_vault() {
    if ! encryption_initialized; then
        echo "Error: Encryption not initialized" >&2
        return 1
    fi

    local vault_item="Age-Private-Key"
    local key_content
    key_content=$(cat "$AGE_KEY_FILE")

    echo "Pushing age key to vault as '$vault_item'..."
    if command -v dotfiles >/dev/null 2>&1; then
        # Create or update vault item with key content
        echo "$key_content" | dotfiles vault set "$vault_item" --stdin 2>/dev/null || {
            echo "Note: Vault push not implemented yet. Manually save this key:"
            echo "  Item name: $vault_item"
            echo "  Content: (contents of $AGE_KEY_FILE)"
        }
    fi
}
