#!/usr/bin/env bats
# Unit tests for vault/_common.sh
# NOTE: These tests require zsh since vault/_common.sh uses zsh syntax

setup() {
  # Path to the script under test
  export COMMON_SH="${BATS_TEST_DIRNAME}/../vault/_common.sh"

  # Create a temporary test config file
  export TEST_CONFIG_DIR="${BATS_TEST_TMPDIR}/dotfiles"
  mkdir -p "$TEST_CONFIG_DIR"
  export VAULT_CONFIG_FILE="$TEST_CONFIG_DIR/vault-items.json"

  # Write test configuration (matches vault-items.example.json)
  cat > "$VAULT_CONFIG_FILE" <<'EOF'
{
  "ssh_keys": {
    "SSH-GitHub": "~/.ssh/id_ed25519_github",
    "SSH-GitLab": "~/.ssh/id_ed25519_gitlab"
  },

  "vault_items": {
    "SSH-GitHub": {
      "path": "~/.ssh/id_ed25519_github",
      "required": true,
      "type": "sshkey"
    },
    "SSH-GitLab": {
      "path": "~/.ssh/id_ed25519_gitlab",
      "required": false,
      "type": "sshkey"
    },
    "SSH-Config": {
      "path": "~/.ssh/config",
      "required": true,
      "type": "file"
    },
    "AWS-Config": {
      "path": "~/.aws/config",
      "required": true,
      "type": "file"
    },
    "AWS-Credentials": {
      "path": "~/.aws/credentials",
      "required": true,
      "type": "file"
    },
    "Git-Config": {
      "path": "~/.gitconfig",
      "required": true,
      "type": "file"
    },
    "Environment-Secrets": {
      "path": "~/.local/env.secrets",
      "required": false,
      "type": "file"
    }
  },

  "syncable_items": {
    "SSH-Config": "~/.ssh/config",
    "AWS-Config": "~/.aws/config",
    "AWS-Credentials": "~/.aws/credentials",
    "Git-Config": "~/.gitconfig",
    "Environment-Secrets": "~/.local/env.secrets",
    "Claude-Profiles": "~/.claude/profiles.json"
  },

  "aws_expected_profiles": [
    "default"
  ]
}
EOF
}

teardown() {
  # Clean up test config
  rm -rf "$TEST_CONFIG_DIR"
}

# Helper function to invoke zsh functions with test config
zsh_eval() {
  zsh -c "export VAULT_CONFIG_FILE='$VAULT_CONFIG_FILE'; source '$COMMON_SH'; $*"
}

# Helper function to get zsh variable value with test config
zsh_var() {
  zsh -c "export VAULT_CONFIG_FILE='$VAULT_CONFIG_FILE'; source '$COMMON_SH'; echo \"\${$1}\""
}

# ============================================================
# SSH Key Functions
# ============================================================

@test "get_ssh_key_paths returns all SSH key paths sorted" {
  run zsh_eval "get_ssh_key_paths"

  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]

  # Should be sorted and contain .ssh paths from test config
  [[ "${lines[0]}" =~ \.ssh/id_ed25519_github ]]
  [[ "${lines[1]}" =~ \.ssh/id_ed25519_gitlab ]]
}

@test "get_ssh_key_items returns all SSH key item names sorted" {
  run zsh_eval "get_ssh_key_items"

  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]

  # Should contain SSH key item names from test config
  [[ "${output}" =~ "SSH-GitHub" ]]
  [[ "${output}" =~ "SSH-GitLab" ]]
}

# ============================================================
# Dotfiles Item Functions
# ============================================================

@test "get_required_items returns only required items" {
  run zsh_eval "get_required_items"

  [ "$status" -eq 0 ]

  # Should contain required items from test config
  [[ "${output}" =~ "SSH-GitHub" ]]
  [[ "${output}" =~ "SSH-Config" ]]
  [[ "${output}" =~ "AWS-Config" ]]
  [[ "${output}" =~ "AWS-Credentials" ]]
  [[ "${output}" =~ "Git-Config" ]]

  # Should NOT contain optional items
  [[ ! "${output}" =~ "SSH-GitLab" ]]
  [[ ! "${output}" =~ "Environment-Secrets" ]]
}

@test "get_optional_items returns only optional items" {
  run zsh_eval "get_optional_items"

  [ "$status" -eq 0 ]

  # Should contain optional items from test config
  [[ "${output}" =~ "Environment-Secrets" ]]
  [[ "${output}" =~ "SSH-GitLab" ]]
}

@test "get_item_path returns correct path for valid item" {
  run zsh_eval "get_item_path SSH-Config"

  [ "$status" -eq 0 ]
  [[ "${output}" =~ /.ssh/config$ ]]
}

@test "get_item_path returns correct path for SSH key item" {
  run zsh_eval "get_item_path SSH-GitHub"

  [ "$status" -eq 0 ]
  [[ "${output}" =~ /.ssh/id_ed25519_github$ ]]
}

@test "get_item_path returns empty for non-existent item" {
  run zsh_eval "get_item_path NonExistent-Item"

  # Function will still return 0 even if item doesn't exist
  # It just outputs an empty string
  [ -z "$output" ]
}

@test "is_protected_item returns true for protected items" {
  run zsh_eval "is_protected_item SSH-Config"
  [ "$status" -eq 0 ]

  run zsh_eval "is_protected_item Git-Config"
  [ "$status" -eq 0 ]
}

@test "is_protected_item returns false for non-protected items" {
  run zsh_eval "is_protected_item Random-Item"
  [ "$status" -eq 1 ]
}

# ============================================================
# Logging Functions
# ============================================================

@test "info() outputs with INFO prefix" {
  run zsh_eval "info 'test message'"

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "INFO" ]]
  [[ "${output}" =~ "test message" ]]
}

@test "pass() outputs with OK prefix" {
  run zsh_eval "pass 'success message'"

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "OK" ]]
  [[ "${output}" =~ "success message" ]]
}

@test "warn() outputs with WARN prefix" {
  run zsh_eval "warn 'warning message'"

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "WARN" ]]
  [[ "${output}" =~ "warning message" ]]
}

@test "fail() outputs with FAIL prefix" {
  run zsh_eval "fail 'error message'"

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "FAIL" ]]
  [[ "${output}" =~ "error message" ]]
}

@test "dry() outputs with DRY-RUN prefix" {
  run zsh_eval "dry 'dry run message'"

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "DRY-RUN" ]]
  [[ "${output}" =~ "dry run message" ]]
}

@test "debug() outputs only when DEBUG=1" {
  # Without DEBUG set, should produce no output
  run zsh_eval "unset DEBUG; debug 'debug message'"
  [ -z "$output" ]

  # With DEBUG=1, should output
  run zsh -c "export DEBUG=1 VAULT_CONFIG_FILE='$VAULT_CONFIG_FILE'; source '$COMMON_SH'; debug 'debug message'"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "DEBUG" ]]
  [[ "${output}" =~ "debug message" ]]
}

# ============================================================
# Session Management
# ============================================================

@test "SESSION_FILE points to vault directory" {
  result=$(zsh_var "SESSION_FILE")
  [[ "$result" =~ vault/\.vault-session$ ]]
}

@test "VAULT_DIR is set to vault directory" {
  result=$(zsh_var "VAULT_DIR")
  [[ "$result" =~ vault$ ]]
}

# ============================================================
# Multiple Sourcing Prevention
# ============================================================

@test "sourcing _common.sh multiple times is safe" {
  run zsh -c "
    export VAULT_CONFIG_FILE='$VAULT_CONFIG_FILE'
    source '$COMMON_SH'
    [ -n \"\${_VAULT_COMMON_LOADED}\" ] || exit 1
    source '$COMMON_SH'
    [ -n \"\${_VAULT_COMMON_LOADED}\" ] || exit 1
  "

  [ "$status" -eq 0 ]
}

# ============================================================
# Data Structure Validation
# ============================================================

@test "SSH_KEYS array is properly defined" {
  run zsh -c "export VAULT_CONFIG_FILE='$VAULT_CONFIG_FILE'; source '$COMMON_SH'; echo \${#SSH_KEYS[@]}"

  [ "$status" -eq 0 ]
  [ "$output" -gt 0 ]
}

@test "DOTFILES_ITEMS array is properly defined" {
  run zsh -c "export VAULT_CONFIG_FILE='$VAULT_CONFIG_FILE'; source '$COMMON_SH'; echo \${#DOTFILES_ITEMS[@]}"

  [ "$status" -eq 0 ]
  [ "$output" -gt 0 ]
}

@test "SYNCABLE_ITEMS array is properly defined" {
  run zsh -c "export VAULT_CONFIG_FILE='$VAULT_CONFIG_FILE'; source '$COMMON_SH'; echo \${#SYNCABLE_ITEMS[@]}"

  [ "$status" -eq 0 ]
  [ "$output" -gt 0 ]

  # Check that SSH-Config is in SYNCABLE_ITEMS
  run zsh -c "export VAULT_CONFIG_FILE='$VAULT_CONFIG_FILE'; source '$COMMON_SH'; echo \"\${SYNCABLE_ITEMS[SSH-Config]}\""
  [ "$status" -eq 0 ]
  [[ "${output}" =~ /.ssh/config$ ]]
}

@test "AWS_EXPECTED_PROFILES array is defined" {
  run zsh -c "export VAULT_CONFIG_FILE='$VAULT_CONFIG_FILE'; source '$COMMON_SH'; echo \${#AWS_EXPECTED_PROFILES[@]}"

  [ "$status" -eq 0 ]
  [ "$output" -gt 0 ]

  # Should contain "default"
  run zsh -c "export VAULT_CONFIG_FILE='$VAULT_CONFIG_FILE'; source '$COMMON_SH'; echo \"\${AWS_EXPECTED_PROFILES[@]}\""
  [[ "${output}" =~ "default" ]]
}

# ============================================================
# Color Codes (TTY Detection)
# ============================================================

@test "color codes are defined (may be empty in non-TTY)" {
  # In non-TTY environment (like CI), they'll be empty but should still be defined
  run zsh -c "export VAULT_CONFIG_FILE='$VAULT_CONFIG_FILE'; source '$COMMON_SH'; echo \"\${RED+defined}\""
  [ "$status" -eq 0 ]
  [ "$output" = "defined" ]

  run zsh -c "export VAULT_CONFIG_FILE='$VAULT_CONFIG_FILE'; source '$COMMON_SH'; echo \"\${GREEN+defined}\""
  [ "$status" -eq 0 ]
  [ "$output" = "defined" ]

  run zsh -c "export VAULT_CONFIG_FILE='$VAULT_CONFIG_FILE'; source '$COMMON_SH'; echo \"\${NC+defined}\""
  [ "$status" -eq 0 ]
  [ "$output" = "defined" ]
}

# ============================================================
# Config Loading Tests
# ============================================================

@test "vault: load_vault_config loads SSH_KEYS from config" {
  run zsh_eval "echo \${#SSH_KEYS[@]}"

  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
}

@test "vault: SSH-GitHub in SSH_KEYS" {
  run zsh_eval "echo \"\${SSH_KEYS[SSH-GitHub]}\""

  [ "$status" -eq 0 ]
  [[ "${output}" =~ \.ssh/id_ed25519_github$ ]]
}

@test "vault: SSH-GitLab in SSH_KEYS" {
  run zsh_eval "echo \"\${SSH_KEYS[SSH-GitLab]}\""

  [ "$status" -eq 0 ]
  [[ "${output}" =~ \.ssh/id_ed25519_gitlab$ ]]
}

@test "vault: Claude-Profiles in SYNCABLE_ITEMS" {
  run zsh_eval "echo \"\${SYNCABLE_ITEMS[Claude-Profiles]}\""

  [ "$status" -eq 0 ]
  [[ "${output}" =~ \.claude/profiles.json$ ]]
}

@test "vault: Claude-Profiles points to profiles.json" {
  run zsh_eval "echo \"\${SYNCABLE_ITEMS[Claude-Profiles]}\""

  [ "$status" -eq 0 ]
  [[ "${output}" =~ profiles\.json$ ]]
}
