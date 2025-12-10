#!/usr/bin/env bats
# Unit tests for lib/_config_layers.sh
# NOTE: These tests require zsh since _config_layers.sh uses zsh syntax

setup() {
  # Path to the script under test
  export CONFIG_LAYERS_SH="${BATS_TEST_DIRNAME}/../lib/_config_layers.sh"

  # Create temporary config directories
  export TEST_CONFIG_DIR="${BATS_TEST_TMPDIR}/dotfiles"
  export TEST_PROJECT_DIR="${BATS_TEST_TMPDIR}/project"
  mkdir -p "$TEST_CONFIG_DIR" "$TEST_PROJECT_DIR"

  # Set up config layer paths for testing
  export CONFIG_LAYER_USER="$TEST_CONFIG_DIR/config.json"
  export CONFIG_LAYER_MACHINE="$TEST_CONFIG_DIR/machine.json"
}

teardown() {
  rm -rf "$TEST_CONFIG_DIR" "$TEST_PROJECT_DIR"
}

# ============================================================
# Function Existence Tests
# ============================================================

@test "config_get_layered function exists" {
  run zsh -c "set +e; source '$CONFIG_LAYERS_SH'; type config_get_layered"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

@test "config_set_layered function exists" {
  run zsh -c "set +e; source '$CONFIG_LAYERS_SH'; type config_set_layered"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

@test "config_show_layers function exists" {
  run zsh -c "set +e; source '$CONFIG_LAYERS_SH'; type config_show_layers"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

@test "config_get_with_source function exists" {
  run zsh -c "set +e; source '$CONFIG_LAYERS_SH'; type config_get_with_source"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}

# ============================================================
# Default Value Tests
# ============================================================

@test "config_get_layered returns default for nonexistent key" {
  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    export CONFIG_LAYER_MACHINE='$CONFIG_LAYER_MACHINE'
    config_get_layered 'nonexistent.key' 'default_value'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "default_value" ]
}

@test "config_get_layered returns empty string when no default" {
  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    export CONFIG_LAYER_MACHINE='$CONFIG_LAYER_MACHINE'
    result=\$(config_get_layered 'nonexistent.key')
    echo \"|\$result|\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "||" ]
}

# ============================================================
# Environment Variable Override Tests
# ============================================================

@test "environment variable overrides all other layers" {
  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    export BLACKDOT_VAULT_BACKEND='env_value'
    config_get_layered 'vault.backend' 'default'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "env_value" ]
}

@test "environment variable with nested key" {
  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    export BLACKDOT_FEATURES_DEBUG='true'
    config_get_layered 'features.debug' 'false'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

# ============================================================
# User Config Tests
# ============================================================

@test "config_get_layered reads from user config file" {
  echo '{"vault": {"backend": "bitwarden"}}' > "$CONFIG_LAYER_USER"

  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    export CONFIG_LAYER_MACHINE='$CONFIG_LAYER_MACHINE'
    config_get_layered 'vault.backend' 'default'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "bitwarden" ]
}

@test "environment variable overrides user config" {
  echo '{"vault": {"backend": "bitwarden"}}' > "$CONFIG_LAYER_USER"

  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    export BLACKDOT_VAULT_BACKEND='1password'
    config_get_layered 'vault.backend' 'default'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "1password" ]
}

# ============================================================
# Machine Config Tests
# ============================================================

@test "machine config overrides user config" {
  echo '{"vault": {"backend": "user_value"}}' > "$CONFIG_LAYER_USER"
  echo '{"vault": {"backend": "machine_value"}}' > "$CONFIG_LAYER_MACHINE"

  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    export CONFIG_LAYER_MACHINE='$CONFIG_LAYER_MACHINE'
    config_get_layered 'vault.backend' 'default'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "machine_value" ]
}

# ============================================================
# Project Config Tests
# ============================================================

@test "project config overrides machine config" {
  echo '{"vault": {"backend": "machine_value"}}' > "$CONFIG_LAYER_MACHINE"
  echo '{"vault": {"backend": "project_value"}}' > "$TEST_PROJECT_DIR/.blackdot.json"

  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    export CONFIG_LAYER_MACHINE='$CONFIG_LAYER_MACHINE'
    cd '$TEST_PROJECT_DIR'
    config_get_layered 'vault.backend' 'default'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "project_value" ]
}

# ============================================================
# Boolean Function Tests
# ============================================================

@test "config_get_layered_bool returns 0 for true" {
  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    export BLACKDOT_FEATURE_ENABLED='true'
    if config_get_layered_bool 'feature.enabled' 'false'; then
      echo 'passed'
    else
      echo 'failed'
    fi
  "
  [ "$status" -eq 0 ]
  [ "$output" = "passed" ]
}

@test "config_get_layered_bool returns 1 for false" {
  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    export BLACKDOT_FEATURE_DISABLED='false'
    if config_get_layered_bool 'feature.disabled' 'true'; then
      echo 'failed'
    else
      echo 'passed'
    fi
  "
  [ "$status" -eq 0 ]
  [ "$output" = "passed" ]
}

# ============================================================
# config_set_layered Tests
# ============================================================

@test "config_set_layered creates user config if not exists" {
  rm -f "$CONFIG_LAYER_USER"

  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    config_set_layered 'user' 'test.key' 'value'
    cat '$CONFIG_LAYER_USER'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'"test"'* ]]
  [[ "$output" == *'"key"'* ]]
  [[ "$output" == *'"value"'* ]]
}

@test "config_set_layered writes string values correctly" {
  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    config_set_layered 'user' 'vault.backend' 'bitwarden'
    cat '$CONFIG_LAYER_USER'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'"backend": "bitwarden"'* ]]
}

@test "config_set_layered writes boolean true as JSON boolean" {
  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    config_set_layered 'user' 'features.enabled' 'true'
    cat '$CONFIG_LAYER_USER'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'"enabled": true'* ]]
}

@test "config_set_layered writes boolean false as JSON boolean" {
  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    config_set_layered 'user' 'features.disabled' 'false'
    cat '$CONFIG_LAYER_USER'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'"disabled": false'* ]]
}

@test "config_set_layered writes numbers as JSON numbers" {
  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    config_set_layered 'user' 'settings.timeout' '30'
    cat '$CONFIG_LAYER_USER'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'"timeout": 30'* ]]
}

@test "config_set_layered rejects invalid layer" {
  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    config_set_layered 'invalid' 'test.key' 'value' 2>&1
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid layer"* ]]
}

# ============================================================
# config_get_with_source Tests
# ============================================================

@test "config_get_with_source reports env source" {
  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    export BLACKDOT_TEST_KEY='env_value'
    config_get_with_source 'test.key' 'default'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'"source":"env"'* ]]
  [[ "$output" == *'"value":"env_value"'* ]]
}

@test "config_get_with_source reports user source" {
  echo '{"test": {"key": "user_value"}}' > "$CONFIG_LAYER_USER"

  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    export CONFIG_LAYER_MACHINE='$CONFIG_LAYER_MACHINE'
    config_get_with_source 'test.key' 'default'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'"source":"user"'* ]]
  [[ "$output" == *'"value":"user_value"'* ]]
}

@test "config_get_with_source reports default source" {
  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    export CONFIG_LAYER_MACHINE='$CONFIG_LAYER_MACHINE'
    config_get_with_source 'nonexistent.key' 'fallback'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'"source":"default"'* ]]
  [[ "$output" == *'"value":"fallback"'* ]]
}

# ============================================================
# config_show_layers Tests
# ============================================================

@test "config_show_layers displays all layers" {
  echo '{"vault": {"backend": "user_value"}}' > "$CONFIG_LAYER_USER"

  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_USER='$CONFIG_LAYER_USER'
    export CONFIG_LAYER_MACHINE='$CONFIG_LAYER_MACHINE'
    config_show_layers 'vault.backend'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Configuration layers for: vault.backend"* ]]
  [[ "$output" == *"env:"* ]]
  [[ "$output" == *"user:"* ]]
  [[ "$output" == *"user_value"* ]]
  [[ "$output" == *"resolved:"* ]]
}

# ============================================================
# Layer Initialization Tests
# ============================================================

@test "config_init_machine creates machine config" {
  rm -f "$CONFIG_LAYER_MACHINE"

  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    export CONFIG_LAYER_MACHINE='$CONFIG_LAYER_MACHINE'
    config_init_machine 'test-machine'
    cat '$CONFIG_LAYER_MACHINE'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'"machine_id": "test-machine"'* ]]
  [[ "$output" == *'"version": 1'* ]]
}

@test "config_init_machine fails if config exists" {
  echo '{}' > "$CONFIG_LAYER_MACHINE"

  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'
    export CONFIG_LAYER_MACHINE='$CONFIG_LAYER_MACHINE'
    config_init_machine 'test-machine' 2>&1
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}

@test "config_init_project creates project config" {
  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    cd '$TEST_PROJECT_DIR'
    config_init_project
    cat '.blackdot.json'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'"version": 1'* ]]
}

# ============================================================
# Feature Registry Integration Test
# ============================================================

@test "_config_layers_enabled returns true by default" {
  run zsh -c "
    set +e; source '$CONFIG_LAYERS_SH'; set -e
    if _config_layers_enabled; then
      echo 'enabled'
    else
      echo 'disabled'
    fi
  "
  [ "$status" -eq 0 ]
  [ "$output" = "enabled" ]
}
