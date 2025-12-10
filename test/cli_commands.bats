#!/usr/bin/env bats
# Unit tests for dotfiles CLI commands
# Tests the various dotfiles-*.sh scripts

setup() {
  export BLACKDOT_DIR="${BATS_TEST_DIRNAME}/.."
  export TEST_TMP="${BATS_TEST_TMPDIR}/dotfiles-test"
  mkdir -p "$TEST_TMP"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ============================================================
# bin/blackdot-backup Tests
# ============================================================

@test "backup script exists and is executable" {
  [ -x "$BLACKDOT_DIR/bin/blackdot-backup" ]
}

@test "backup --help shows usage" {
  run "$BLACKDOT_DIR/bin/blackdot-backup" --help

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "USAGE" ]]
  [[ "${output}" =~ "backup" ]]
}

@test "backup --list handles no existing backups" {
  export HOME="$TEST_TMP"
  run "$BLACKDOT_DIR/bin/blackdot-backup" --list

  # Returns 1 when no backups exist (warning state)
  [ "$status" -eq 1 ]
  [[ "${output}" =~ "No backups found" ]]
}

# ============================================================
# bin/blackdot-diff Tests
# ============================================================

@test "diff script exists and is executable" {
  [ -x "$BLACKDOT_DIR/bin/blackdot-diff" ]
}

@test "diff --help shows usage" {
  run "$BLACKDOT_DIR/bin/blackdot-diff" --help

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Usage" ]]
  [[ "${output}" =~ "diff" ]]
}

# ============================================================
# bin/blackdot-doctor Tests
# ============================================================

@test "doctor script exists and is executable" {
  [ -x "$BLACKDOT_DIR/bin/blackdot-doctor" ]
}

@test "doctor --help shows usage" {
  run "$BLACKDOT_DIR/bin/blackdot-doctor" --help

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Usage" ]] || [[ "${output}" =~ "doctor" ]]
}

# ============================================================
# bin/blackdot-drift Tests
# ============================================================

@test "drift script exists and is executable" {
  [ -x "$BLACKDOT_DIR/bin/blackdot-drift" ]
}

# ============================================================
# bin/blackdot-setup Tests
# ============================================================

@test "setup script exists and is executable" {
  [ -x "$BLACKDOT_DIR/bin/blackdot-setup" ]
}

# ============================================================
# bin/blackdot-uninstall Tests
# ============================================================

@test "uninstall script exists and is executable" {
  [ -x "$BLACKDOT_DIR/bin/blackdot-uninstall" ]
}

@test "uninstall --help shows usage" {
  run "$BLACKDOT_DIR/bin/blackdot-uninstall" --help

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Usage" ]]
  [[ "${output}" =~ "uninstall" ]]
}

@test "uninstall --dry-run reports what would be removed" {
  export HOME="$TEST_TMP"

  # Create a fake symlink to test
  mkdir -p "$TEST_TMP/.config/ghostty"
  ln -sf /nonexistent "$TEST_TMP/.zshrc"

  run "$BLACKDOT_DIR/bin/blackdot-uninstall" --dry-run

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "DRY RUN" ]]
}

# ============================================================
# install.sh Tests
# ============================================================

@test "install script exists and is executable" {
  [ -x "$BLACKDOT_DIR/install.sh" ]
}

@test "install --help shows usage" {
  run "$BLACKDOT_DIR/install.sh" --help

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Usage" ]] || [[ "${output}" =~ "install" ]] || [[ "${output}" =~ "Dotfiles" ]]
}

# ============================================================
# Script Syntax Validation
# ============================================================

@test "all shell scripts have valid bash syntax" {
  # Check all .sh files for basic syntax
  for script in "$BLACKDOT_DIR"/*.sh; do
    if [[ -f "$script" ]]; then
      run bash -n "$script"
      [ "$status" -eq 0 ] || echo "Syntax error in: $script"
      [ "$status" -eq 0 ]
    fi
  done
}

@test "vault scripts have valid zsh syntax" {
  for script in "$BLACKDOT_DIR/vault"/*.sh; do
    if [[ -f "$script" ]]; then
      run zsh -n "$script"
      [ "$status" -eq 0 ] || echo "Syntax error in: $script"
      [ "$status" -eq 0 ]
    fi
  done
}
