#!/usr/bin/env bats
# Unit tests for dotfiles CLI commands
# Tests the various dotfiles-*.sh scripts

setup() {
  export DOTFILES_DIR="${BATS_TEST_DIRNAME}/.."
  export TEST_TMP="${BATS_TEST_TMPDIR}/dotfiles-test"
  mkdir -p "$TEST_TMP"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ============================================================
# bin/dotfiles-backup Tests
# ============================================================

@test "backup script exists and is executable" {
  [ -x "$DOTFILES_DIR/bin/dotfiles-backup" ]
}

@test "backup --help shows usage" {
  run "$DOTFILES_DIR/bin/dotfiles-backup" --help

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Usage" ]]
  [[ "${output}" =~ "backup" ]]
}

@test "backup --list handles no existing backups" {
  export HOME="$TEST_TMP"
  run "$DOTFILES_DIR/bin/dotfiles-backup" --list

  # Returns 1 when no backups exist (warning state)
  [ "$status" -eq 1 ]
  [[ "${output}" =~ "No backups found" ]]
}

# ============================================================
# bin/dotfiles-diff Tests
# ============================================================

@test "diff script exists and is executable" {
  [ -x "$DOTFILES_DIR/bin/dotfiles-diff" ]
}

@test "diff --help shows usage" {
  run "$DOTFILES_DIR/bin/dotfiles-diff" --help

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Usage" ]]
  [[ "${output}" =~ "diff" ]]
}

# ============================================================
# bin/dotfiles-doctor Tests
# ============================================================

@test "doctor script exists and is executable" {
  [ -x "$DOTFILES_DIR/bin/dotfiles-doctor" ]
}

@test "doctor --help shows usage" {
  run "$DOTFILES_DIR/bin/dotfiles-doctor" --help

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Usage" ]] || [[ "${output}" =~ "doctor" ]]
}

# ============================================================
# bin/dotfiles-drift Tests
# ============================================================

@test "drift script exists and is executable" {
  [ -x "$DOTFILES_DIR/bin/dotfiles-drift" ]
}

# ============================================================
# bin/dotfiles-setup Tests
# ============================================================

@test "setup script exists and is executable" {
  [ -x "$DOTFILES_DIR/bin/dotfiles-setup" ]
}

# ============================================================
# bin/dotfiles-uninstall Tests
# ============================================================

@test "uninstall script exists and is executable" {
  [ -x "$DOTFILES_DIR/bin/dotfiles-uninstall" ]
}

@test "uninstall --help shows usage" {
  run "$DOTFILES_DIR/bin/dotfiles-uninstall" --help

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Usage" ]]
  [[ "${output}" =~ "uninstall" ]]
}

@test "uninstall --dry-run reports what would be removed" {
  export HOME="$TEST_TMP"

  # Create a fake symlink to test
  mkdir -p "$TEST_TMP/.config/ghostty"
  ln -sf /nonexistent "$TEST_TMP/.zshrc"

  run "$DOTFILES_DIR/bin/dotfiles-uninstall" --dry-run

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "DRY RUN" ]]
}

# ============================================================
# install.sh Tests
# ============================================================

@test "install script exists and is executable" {
  [ -x "$DOTFILES_DIR/install.sh" ]
}

@test "install --help shows usage" {
  run "$DOTFILES_DIR/install.sh" --help

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Usage" ]] || [[ "${output}" =~ "install" ]] || [[ "${output}" =~ "Dotfiles" ]]
}

# ============================================================
# Script Syntax Validation
# ============================================================

@test "all shell scripts have valid bash syntax" {
  # Check all .sh files for basic syntax
  for script in "$DOTFILES_DIR"/*.sh; do
    if [[ -f "$script" ]]; then
      run bash -n "$script"
      [ "$status" -eq 0 ] || echo "Syntax error in: $script"
      [ "$status" -eq 0 ]
    fi
  done
}

@test "vault scripts have valid zsh syntax" {
  for script in "$DOTFILES_DIR/vault"/*.sh; do
    if [[ -f "$script" ]]; then
      run zsh -n "$script"
      [ "$status" -eq 0 ] || echo "Syntax error in: $script"
      [ "$status" -eq 0 ]
    fi
  done
}
