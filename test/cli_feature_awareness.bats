#!/usr/bin/env bats
# Unit tests for lib/_cli_features.sh - CLI Feature Awareness
# NOTE: These tests require zsh since the scripts use zsh syntax

setup() {
  export DOTFILES_DIR="${BATS_TEST_DIRNAME}/.."
  export CLI_FEATURES_SH="${DOTFILES_DIR}/lib/_cli_features.sh"
  export FEATURES_SH="${DOTFILES_DIR}/lib/_features.sh"

  # Create temporary config directory
  export TEST_CONFIG_DIR="${BATS_TEST_TMPDIR}/dotfiles"
  mkdir -p "$TEST_CONFIG_DIR"
  export CONFIG_FILE="$TEST_CONFIG_DIR/config.json"
}

teardown() {
  rm -rf "$TEST_CONFIG_DIR"
}

# ============================================================
# Function Existence Tests
# ============================================================

@test "cli_command_visible function exists" {
  run zsh -c "source '$FEATURES_SH'; source '$CLI_FEATURES_SH'; type cli_command_visible"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

@test "cli_require_feature function exists" {
  run zsh -c "source '$FEATURES_SH'; source '$CLI_FEATURES_SH'; type cli_require_feature"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

@test "cli_command_feature function exists" {
  run zsh -c "source '$FEATURES_SH'; source '$CLI_FEATURES_SH'; type cli_command_feature"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

@test "cli_section_visible function exists" {
  run zsh -c "source '$FEATURES_SH'; source '$CLI_FEATURES_SH'; type cli_section_visible"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

@test "_cli_feature_disabled_message function exists" {
  run zsh -c "source '$FEATURES_SH'; source '$CLI_FEATURES_SH'; type _cli_feature_disabled_message"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

# ============================================================
# Command-to-Feature Mapping Tests
# ============================================================

@test "cli_command_feature returns vault for vault command" {
  run zsh -c "source '$FEATURES_SH'; source '$CLI_FEATURES_SH'; cli_command_feature 'vault'"
  [ "$status" -eq 0 ]
  [ "$output" = "vault" ]
}

@test "cli_command_feature returns config_layers for config command" {
  run zsh -c "source '$FEATURES_SH'; source '$CLI_FEATURES_SH'; cli_command_feature 'config'"
  [ "$status" -eq 0 ]
  [ "$output" = "config_layers" ]
}

@test "cli_command_feature returns backup_auto for backup command" {
  run zsh -c "source '$FEATURES_SH'; source '$CLI_FEATURES_SH'; cli_command_feature 'backup'"
  [ "$status" -eq 0 ]
  [ "$output" = "backup_auto" ]
}

@test "cli_command_feature returns templates for template command" {
  run zsh -c "source '$FEATURES_SH'; source '$CLI_FEATURES_SH'; cli_command_feature 'template'"
  [ "$status" -eq 0 ]
  [ "$output" = "templates" ]
}

@test "cli_command_feature returns empty for core command (status)" {
  run zsh -c "source '$FEATURES_SH'; source '$CLI_FEATURES_SH'; cli_command_feature 'status'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "cli_command_feature returns empty for core command (doctor)" {
  run zsh -c "source '$FEATURES_SH'; source '$CLI_FEATURES_SH'; cli_command_feature 'doctor'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ============================================================
# Command Visibility Tests
# ============================================================

@test "cli_command_visible returns 0 for core commands" {
  run zsh -c "source '$FEATURES_SH'; source '$CLI_FEATURES_SH'; cli_command_visible 'status' && echo 'visible'"
  [ "$status" -eq 0 ]
  [ "$output" = "visible" ]
}

@test "cli_command_visible returns 0 for unknown commands" {
  run zsh -c "source '$FEATURES_SH'; source '$CLI_FEATURES_SH'; cli_command_visible 'unknown_cmd' && echo 'visible'"
  [ "$status" -eq 0 ]
  [ "$output" = "visible" ]
}

@test "cli_command_visible checks feature_enabled for mapped commands" {
  # Create config with vault enabled
  echo '{"features": {"vault": true}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_command_visible 'vault' && echo 'visible' || echo 'hidden'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "visible" ]
}

@test "cli_command_visible returns 1 when feature disabled" {
  # Create config with vault disabled
  echo '{"features": {"vault": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_command_visible 'vault' && echo 'visible' || echo 'hidden'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "hidden" ]
}

# ============================================================
# Section Visibility Tests
# ============================================================

@test "cli_section_visible returns 0 for core sections" {
  run zsh -c "source '$FEATURES_SH'; source '$CLI_FEATURES_SH'; cli_section_visible 'core' && echo 'visible'"
  [ "$status" -eq 0 ]
  [ "$output" = "visible" ]
}

@test "cli_section_visible returns 0 for sections without feature mapping" {
  run zsh -c "source '$FEATURES_SH'; source '$CLI_FEATURES_SH'; cli_section_visible 'unknown_section' && echo 'visible'"
  [ "$status" -eq 0 ]
  [ "$output" = "visible" ]
}

# ============================================================
# Feature Require Tests
# ============================================================

@test "cli_require_feature passes when feature enabled" {
  echo '{"features": {"vault": true}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_require_feature 'vault' 'vault pull' && echo 'passed'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "passed" ]
}

@test "cli_require_feature fails when feature disabled" {
  echo '{"features": {"vault": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_require_feature 'vault' 'vault pull' 2>&1
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"not enabled"* ]]
}

@test "cli_require_feature shows enable hint when feature disabled" {
  echo '{"features": {"backup_auto": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_require_feature 'backup_auto' 'backup' 2>&1
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"dotfiles features enable backup_auto"* ]]
}

@test "cli_require_feature shows --force hint when feature disabled" {
  echo '{"features": {"templates": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_require_feature 'templates' 'template init' 2>&1
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"--force"* ]]
}

@test "cli_require_feature passes with --force flag" {
  echo '{"features": {"vault": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_require_feature 'vault' 'vault pull' --force && echo 'passed'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "passed" ]
}

@test "cli_require_feature passes with -f short flag" {
  echo '{"features": {"vault": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_require_feature 'vault' 'vault pull' -f && echo 'passed'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "passed" ]
}

@test "cli_require_feature filters --force from CLI_FILTERED_ARGS" {
  echo '{"features": {"vault": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_require_feature 'vault' 'vault pull' --force arg1 arg2
    echo \"\${CLI_FILTERED_ARGS[*]}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"arg1"* ]]
  [[ "$output" == *"arg2"* ]]
  [[ "$output" != *"--force"* ]]
}

# ============================================================
# CLI_COMMAND_FEATURES Mapping Completeness Tests
# ============================================================

@test "vault commands are mapped to vault feature" {
  run zsh -c "
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    # Note: drift is mapped to drift_check, not vault
    for cmd in vault sync diff secrets; do
      feature=\$(cli_command_feature \"\$cmd\")
      if [[ \"\$feature\" != 'vault' ]]; then
        echo \"FAIL: \$cmd -> \$feature (expected vault)\"
        exit 1
      fi
    done
    echo 'all vault commands mapped correctly'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"all vault commands mapped correctly"* ]]
}

@test "backup commands are mapped to backup_auto feature" {
  run zsh -c "
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    for cmd in backup rollback; do
      feature=\$(cli_command_feature \"\$cmd\")
      if [[ \"\$feature\" != 'backup_auto' ]]; then
        echo \"FAIL: \$cmd -> \$feature (expected backup_auto)\"
        exit 1
      fi
    done
    echo 'all backup commands mapped correctly'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"all backup commands mapped correctly"* ]]
}

@test "core commands have no feature mapping" {
  run zsh -c "
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    for cmd in status doctor lint packages upgrade setup migrate uninstall features help; do
      feature=\$(cli_command_feature \"\$cmd\")
      if [[ -n \"\$feature\" ]]; then
        echo \"FAIL: \$cmd has feature mapping '\$feature' (should be empty)\"
        exit 1
      fi
    done
    echo 'all core commands have no feature mapping'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"all core commands have no feature mapping"* ]]
}

# ============================================================
# Feature Indicator Tests
# ============================================================

@test "cli_feature_indicator returns filled circle for enabled feature" {
  echo '{"features": {"vault": true}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_feature_indicator 'vault'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"●"* ]]
}

@test "cli_feature_indicator returns empty circle for disabled feature" {
  echo '{"features": {"vault": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_feature_indicator 'vault'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"○"* ]]
}

# ============================================================
# Hidden Features Tests
# ============================================================

@test "cli_hidden_features lists disabled features" {
  echo '{"features": {"vault": false, "backup_auto": false, "templates": true}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_hidden_features
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"vault"* ]] || [[ "$output" == *"backup_auto"* ]]
}

# ============================================================
# Environment Variable Override Tests
# ============================================================

@test "DOTFILES_CLI_SHOW_ALL makes hidden commands visible" {
  echo '{"features": {"vault": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    export DOTFILES_CLI_SHOW_ALL=true
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_command_visible 'vault' && echo 'visible' || echo 'hidden'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "visible" ]
}

@test "DOTFILES_CLI_SHOW_ALL=1 also works" {
  echo '{"features": {"vault": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    export DOTFILES_CLI_SHOW_ALL=1
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_command_visible 'vault' && echo 'visible' || echo 'hidden'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "visible" ]
}

@test "DOTFILES_FORCE bypasses feature guard" {
  echo '{"features": {"vault": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    export DOTFILES_FORCE=true
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_require_feature 'vault' 'vault pull' && echo 'allowed' || echo 'blocked'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "allowed" ]
}

@test "DOTFILES_FORCE=1 also works" {
  echo '{"features": {"vault": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    export DOTFILES_FORCE=1
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_require_feature 'vault' 'vault pull' && echo 'allowed' || echo 'blocked'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "allowed" ]
}

# ============================================================
# cli_feature_filter Meta-Feature Tests
# ============================================================

@test "cli_feature_filter disabled makes all commands visible" {
  echo '{"features": {"vault": false, "cli_feature_filter": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_command_visible 'vault' && echo 'visible' || echo 'hidden'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "visible" ]
}

@test "cli_feature_filter disabled bypasses feature guard" {
  echo '{"features": {"vault": false, "cli_feature_filter": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_require_feature 'vault' 'vault pull' && echo 'allowed' || echo 'blocked'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "allowed" ]
}

@test "cli_feature_filter disabled affects sections too" {
  echo '{"features": {"vault": false, "cli_feature_filter": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    source '$CLI_FEATURES_SH'
    cli_section_visible 'Vault Operations' && echo 'visible' || echo 'hidden'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "visible" ]
}
