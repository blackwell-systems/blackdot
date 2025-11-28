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
# dotfiles-backup.sh Tests
# ============================================================

@test "backup script exists and is executable" {
  [ -x "$DOTFILES_DIR/dotfiles-backup.sh" ]
}

@test "backup --help shows usage" {
  run "$DOTFILES_DIR/dotfiles-backup.sh" --help

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Usage" ]]
  [[ "${output}" =~ "backup" ]]
}

@test "backup --list works without existing backups" {
  export HOME="$TEST_TMP"
  run "$DOTFILES_DIR/dotfiles-backup.sh" --list

  # Should succeed even with no backups
  [ "$status" -eq 0 ]
}

# ============================================================
# dotfiles-diff.sh Tests
# ============================================================

@test "diff script exists and is executable" {
  [ -x "$DOTFILES_DIR/dotfiles-diff.sh" ]
}

@test "diff --help shows usage" {
  run "$DOTFILES_DIR/dotfiles-diff.sh" --help

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Usage" ]]
  [[ "${output}" =~ "diff" ]]
}

# ============================================================
# dotfiles-doctor.sh Tests
# ============================================================

@test "doctor script exists and is executable" {
  [ -x "$DOTFILES_DIR/dotfiles-doctor.sh" ]
}

@test "doctor --help shows usage" {
  run "$DOTFILES_DIR/dotfiles-doctor.sh" --help

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Usage" ]] || [[ "${output}" =~ "doctor" ]]
}

# ============================================================
# dotfiles-drift.sh Tests
# ============================================================

@test "drift script exists and is executable" {
  [ -x "$DOTFILES_DIR/dotfiles-drift.sh" ]
}

# ============================================================
# dotfiles-init.sh Tests
# ============================================================

@test "init script exists and is executable" {
  [ -x "$DOTFILES_DIR/dotfiles-init.sh" ]
}

# ============================================================
# uninstall.sh Tests
# ============================================================

@test "uninstall script exists and is executable" {
  [ -x "$DOTFILES_DIR/uninstall.sh" ]
}

@test "uninstall --help shows usage" {
  run "$DOTFILES_DIR/uninstall.sh" --help

  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Usage" ]]
  [[ "${output}" =~ "uninstall" ]]
}

@test "uninstall --dry-run reports what would be removed" {
  export HOME="$TEST_TMP"

  # Create a fake symlink to test
  mkdir -p "$TEST_TMP/.config/ghostty"
  ln -sf /nonexistent "$TEST_TMP/.zshrc"

  run "$DOTFILES_DIR/uninstall.sh" --dry-run

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
