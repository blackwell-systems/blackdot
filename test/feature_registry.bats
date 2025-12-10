#!/usr/bin/env bats
# Unit tests for lib/_features.sh - Feature Registry
# NOTE: These tests require zsh since _features.sh uses zsh syntax

setup() {
  export BLACKDOT_DIR="${BATS_TEST_DIRNAME}/.."
  export FEATURES_SH="${BLACKDOT_DIR}/lib/_features.sh"

  # Create temporary config directory
  export TEST_CONFIG_DIR="${BATS_TEST_TMPDIR}/dotfiles"
  mkdir -p "$TEST_CONFIG_DIR"
  export CONFIG_FILE="$TEST_CONFIG_DIR/config.json"
  export CONFIG_DIR="$TEST_CONFIG_DIR"
}

teardown() {
  rm -rf "$TEST_CONFIG_DIR"
}

# ============================================================
# Function Existence Tests
# ============================================================

@test "feature_enabled function exists" {
  run zsh -c "source '$FEATURES_SH'; type feature_enabled"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

@test "feature_enable function exists" {
  run zsh -c "source '$FEATURES_SH'; type feature_enable"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

@test "feature_disable function exists" {
  run zsh -c "source '$FEATURES_SH'; type feature_disable"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

@test "feature_exists function exists" {
  run zsh -c "source '$FEATURES_SH'; type feature_exists"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

@test "feature_list function exists" {
  run zsh -c "source '$FEATURES_SH'; type feature_list"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

@test "feature_persist function exists" {
  run zsh -c "source '$FEATURES_SH'; type feature_persist"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

@test "feature_status function exists" {
  run zsh -c "source '$FEATURES_SH'; type feature_status"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

# ============================================================
# Feature Existence Tests
# ============================================================

@test "feature_exists returns 0 for known feature vault" {
  run zsh -c "source '$FEATURES_SH'; feature_exists 'vault' && echo 'exists'"
  [ "$status" -eq 0 ]
  [ "$output" = "exists" ]
}

@test "feature_exists returns 0 for known feature shell" {
  run zsh -c "source '$FEATURES_SH'; feature_exists 'shell' && echo 'exists'"
  [ "$status" -eq 0 ]
  [ "$output" = "exists" ]
}

@test "feature_exists returns 1 for unknown feature" {
  run zsh -c "source '$FEATURES_SH'; feature_exists 'nonexistent_feature' && echo 'exists' || echo 'not found'"
  [ "$status" -eq 0 ]
  [ "$output" = "not found" ]
}

# ============================================================
# Core Feature Tests
# ============================================================

@test "core feature shell is always enabled" {
  run zsh -c "source '$FEATURES_SH'; feature_enabled 'shell' && echo 'enabled'"
  [ "$status" -eq 0 ]
  [ "$output" = "enabled" ]
}

@test "core features cannot be disabled" {
  run zsh -c "
    source '$FEATURES_SH'
    # Core features stay enabled even after disable attempt
    feature_disable 'shell' 2>&1 || true
    feature_enabled 'shell' && echo 'still enabled' || echo 'disabled'
  "
  # Shell should remain enabled (core features can't be disabled)
  [[ "$output" == *"still enabled"* ]]
}

# ============================================================
# Feature Enable/Disable Tests
# ============================================================

@test "feature_enable enables a disabled feature" {
  echo '{"features": {"vault": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    export CONFIG_DIR='$CONFIG_DIR'
    source '$FEATURES_SH'
    feature_enable 'vault'
    feature_enabled 'vault' && echo 'enabled'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "enabled" ]
}

@test "feature_disable disables an enabled feature" {
  echo '{"features": {"vault": true}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    export CONFIG_DIR='$CONFIG_DIR'
    source '$FEATURES_SH'
    feature_disable 'vault'
    feature_enabled 'vault' || echo 'disabled'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "disabled" ]
}

# ============================================================
# Feature Persistence Tests
# ============================================================

@test "feature_persist saves feature state to config" {
  echo '{}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    export CONFIG_DIR='$CONFIG_DIR'
    source '$FEATURES_SH'
    feature_persist 'vault' 'true'
    cat '$CONFIG_FILE'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'"vault"'* ]]
  [[ "$output" == *'true'* ]]
}

@test "feature_persist creates config file if not exists" {
  rm -f "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    export CONFIG_DIR='$CONFIG_DIR'
    source '$FEATURES_SH'
    feature_persist 'vault' 'true'
    [ -f '$CONFIG_FILE' ] && echo 'config created'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"config created"* ]]
}

# ============================================================
# Environment Variable Override Tests
# ============================================================

@test "SKIP_WORKSPACE_SYMLINK=true disables workspace_symlink" {
  run zsh -c "
    export SKIP_WORKSPACE_SYMLINK=true
    source '$FEATURES_SH'
    feature_enabled 'workspace_symlink' || echo 'disabled'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "disabled" ]
}

@test "SKIP_CLAUDE_SETUP=true disables claude_integration" {
  run zsh -c "
    export SKIP_CLAUDE_SETUP=true
    source '$FEATURES_SH'
    feature_enabled 'claude_integration' || echo 'disabled'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "disabled" ]
}

@test "BLACKDOT_SKIP_DRIFT_CHECK=1 disables drift_check" {
  run zsh -c "
    export BLACKDOT_SKIP_DRIFT_CHECK=1
    source '$FEATURES_SH'
    feature_enabled 'drift_check' || echo 'disabled'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "disabled" ]
}

@test "BLACKDOT_FEATURE_VAULT=true enables vault" {
  echo '{"features": {"vault": false}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    export BLACKDOT_FEATURE_VAULT=true
    source '$FEATURES_SH'
    feature_enabled 'vault' && echo 'enabled'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "enabled" ]
}

@test "BLACKDOT_FEATURE_VAULT=false disables vault" {
  echo '{"features": {"vault": true}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    export BLACKDOT_FEATURE_VAULT=false
    source '$FEATURES_SH'
    feature_enabled 'vault' || echo 'disabled'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "disabled" ]
}

# ============================================================
# Feature List Tests
# ============================================================

@test "feature_list returns all features" {
  run zsh -c "source '$FEATURES_SH'; feature_list | wc -l"
  [ "$status" -eq 0 ]
  # Should have at least 10 features
  [ "$output" -ge 10 ]
}

@test "feature_list with category returns only that category" {
  run zsh -c "source '$FEATURES_SH'; feature_list 'core'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"shell"* ]]
}

@test "feature_list optional includes vault" {
  run zsh -c "source '$FEATURES_SH'; feature_list 'optional'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"vault"* ]]
}

@test "feature_list integration includes modern_cli" {
  run zsh -c "source '$FEATURES_SH'; feature_list 'integration'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"modern_cli"* ]]
}

# ============================================================
# Feature Metadata Tests
# ============================================================

@test "_feature_meta returns correct category" {
  run zsh -c "source '$FEATURES_SH'; _feature_meta 'shell' 'category'"
  [ "$status" -eq 0 ]
  [ "$output" = "core" ]
}

@test "_feature_meta returns correct category for optional" {
  run zsh -c "source '$FEATURES_SH'; _feature_meta 'vault' 'category'"
  [ "$status" -eq 0 ]
  [ "$output" = "optional" ]
}

@test "_feature_meta returns description" {
  run zsh -c "source '$FEATURES_SH'; _feature_meta 'vault' 'description'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"vault"* ]] || [[ "$output" == *"secret"* ]]
}

# ============================================================
# Feature Preset Tests
# ============================================================

@test "feature_preset_list shows available presets" {
  run zsh -c "source '$FEATURES_SH'; feature_preset_list"
  [ "$status" -eq 0 ]
  [[ "$output" == *"minimal"* ]]
  [[ "$output" == *"developer"* ]]
  [[ "$output" == *"claude"* ]]
  [[ "$output" == *"full"* ]]
}

@test "feature_preset_enable minimal enables only shell" {
  run zsh -c "
    source '$FEATURES_SH'
    feature_preset_enable 'minimal'
    feature_enabled 'shell' && echo 'shell enabled'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"shell enabled"* ]]
}

@test "feature_preset_enable developer enables vault and git_hooks" {
  run zsh -c "
    source '$FEATURES_SH'
    feature_preset_enable 'developer'
    feature_enabled 'vault' && feature_enabled 'git_hooks' && echo 'dev features enabled'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"dev features enabled"* ]]
}

# ============================================================
# Dependency Resolution Tests
# ============================================================

@test "enabling feature auto-enables dependencies" {
  run zsh -c "
    source '$FEATURES_SH'
    # claude_integration depends on workspace_symlink
    feature_enable 'claude_integration'
    feature_enabled 'workspace_symlink' && echo 'dep enabled'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"dep enabled"* ]]
}

# ============================================================
# Feature Status Tests
# ============================================================

@test "feature_status shows enabled state" {
  echo '{"features": {"vault": true}}' > "$CONFIG_FILE"

  run zsh -c "
    export CONFIG_FILE='$CONFIG_FILE'
    source '$FEATURES_SH'
    feature_status 'vault'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"enabled"* ]] || [[ "$output" == *"true"* ]]
}

@test "feature_status_all returns JSON" {
  run zsh -c "source '$FEATURES_SH'; feature_status_all"
  [ "$status" -eq 0 ]
  # Should be valid JSON with features
  [[ "$output" == *"{"* ]]
  [[ "$output" == *"shell"* ]]
}

# ============================================================
# Feature Registry Completeness Tests
# ============================================================

@test "shell feature is registered" {
  run zsh -c "source '$FEATURES_SH'; feature_exists 'shell' && echo 'found'"
  [ "$status" -eq 0 ]
  [ "$output" = "found" ]
}

@test "vault feature is registered" {
  run zsh -c "source '$FEATURES_SH'; feature_exists 'vault' && echo 'found'"
  [ "$status" -eq 0 ]
  [ "$output" = "found" ]
}

@test "cli_feature_filter feature is registered" {
  run zsh -c "source '$FEATURES_SH'; feature_exists 'cli_feature_filter' && echo 'found'"
  [ "$status" -eq 0 ]
  [ "$output" = "found" ]
}

@test "config_layers feature is registered" {
  run zsh -c "source '$FEATURES_SH'; feature_exists 'config_layers' && echo 'found'"
  [ "$status" -eq 0 ]
  [ "$output" = "found" ]
}
