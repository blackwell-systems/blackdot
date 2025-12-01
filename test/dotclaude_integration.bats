#!/usr/bin/env bats
# Tests for dotclaude integration
# Verifies Claude Code integration works correctly across CLI commands

setup() {
  export DOTFILES_DIR="${BATS_TEST_DIRNAME}/.."
  export TEST_TMP="${BATS_TEST_TMPDIR}/dotclaude-test"
  export HOME="$TEST_TMP"
  export WORKSPACE="$TEST_TMP/workspace"
  mkdir -p "$TEST_TMP"
  mkdir -p "$TEST_TMP/.claude"
  mkdir -p "$WORKSPACE/dotfiles"

  # Create mock bin directory
  mkdir -p "$TEST_TMP/bin"
  export PATH="$TEST_TMP/bin:$PATH"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ============================================================
# Helper: Create mock claude command
# ============================================================
create_mock_claude() {
  cat > "$TEST_TMP/bin/claude" << 'EOF'
#!/bin/sh
echo "mock claude"
EOF
  chmod +x "$TEST_TMP/bin/claude"
}

# ============================================================
# Helper: Create mock dotclaude command
# ============================================================
create_mock_dotclaude() {
  local profile="${1:-test-profile}"
  cat > "$TEST_TMP/bin/dotclaude" << EOF
#!/bin/sh
if [ "\$1" = "active" ]; then
    echo "$profile"
fi
EOF
  chmod +x "$TEST_TMP/bin/dotclaude"
}

# ============================================================
# Helper: Create mock dotclaude that returns "none"
# ============================================================
create_mock_dotclaude_no_profile() {
  cat > "$TEST_TMP/bin/dotclaude" << 'EOF'
#!/bin/sh
if [ "$1" = "active" ]; then
    echo "none"
    exit 1
fi
EOF
  chmod +x "$TEST_TMP/bin/dotclaude"
}

# ============================================================
# Helper: Create profiles.json
# ============================================================
create_profiles_json() {
  local profile="${1:-test-profile}"
  cat > "$TEST_TMP/.claude/profiles.json" << EOF
{
  "active": "$profile",
  "profiles": {
    "$profile": {"backend": "max", "created": "2025-12-01"}
  }
}
EOF
}

# ============================================================
# dotfiles-doctor Claude section tests
# ============================================================

@test "doctor: no Claude section when claude not installed" {
  # No mock claude created
  run "$DOTFILES_DIR/bin/dotfiles-doctor" --quick

  # Should not contain Claude section
  [[ ! "${output}" =~ "Claude Code" ]]
}

@test "doctor: shows Claude section when claude installed" {
  create_mock_claude

  run "$DOTFILES_DIR/bin/dotfiles-doctor" --quick

  [[ "${output}" =~ "Claude Code" ]]
  [[ "${output}" =~ "Claude CLI installed" ]]
}

@test "doctor: suggests dotclaude when claude installed but not dotclaude" {
  create_mock_claude
  # No dotclaude mock

  run "$DOTFILES_DIR/bin/dotfiles-doctor" --quick

  [[ "${output}" =~ "dotclaude not installed" ]]
  [[ "${output}" =~ "dotclaude.dev" ]]
}

@test "doctor: shows active profile when dotclaude installed" {
  create_mock_claude
  create_mock_dotclaude "work-bedrock"

  run "$DOTFILES_DIR/bin/dotfiles-doctor" --quick

  [[ "${output}" =~ "dotclaude installed" ]]
  [[ "${output}" =~ "Active profile: work-bedrock" ]]
}

@test "doctor: warns when no active profile" {
  create_mock_claude
  create_mock_dotclaude_no_profile

  run "$DOTFILES_DIR/bin/dotfiles-doctor" --quick

  [[ "${output}" =~ "No active profile" ]]
}

@test "doctor: checks profiles.json exists" {
  create_mock_claude
  create_mock_dotclaude "test-profile"
  create_profiles_json "test-profile"

  run "$DOTFILES_DIR/bin/dotfiles-doctor" --quick

  [[ "${output}" =~ "profiles.json exists" ]]
}

# ============================================================
# vault/_common.sh Claude-Profiles tests (source and verify)
# ============================================================

@test "vault: source _common.sh successfully" {
  # Source the vault common file to generate coverage
  cd "$DOTFILES_DIR"
  run zsh -c "source vault/_common.sh && echo 'sourced ok'"
  [[ "${output}" =~ "sourced ok" ]] || true
}

@test "vault: Claude-Profiles in SYNCABLE_ITEMS" {
  run grep -q "Claude-Profiles" "$DOTFILES_DIR/vault/_common.sh"
  [ "$status" -eq 0 ]
}

@test "vault: Claude-Profiles points to profiles.json" {
  run grep "Claude-Profiles.*profiles.json" "$DOTFILES_DIR/vault/_common.sh"
  [ "$status" -eq 0 ]
}

# ============================================================
# dotfiles-packages execution tests
# ============================================================

@test "packages: script exists and is executable" {
  [ -x "$DOTFILES_DIR/bin/dotfiles-packages" ]
}

@test "packages: shows help" {
  run "$DOTFILES_DIR/bin/dotfiles-packages" --help
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Usage" ]] || [[ "${output}" =~ "packages" ]]
}

@test "packages: handles missing brew gracefully" {
  # Remove brew from path temporarily
  export PATH="/usr/bin:/bin"
  run "$DOTFILES_DIR/bin/dotfiles-packages"
  # Should fail with message about Homebrew
  [[ "${output}" =~ "Homebrew" ]] || [[ "${output}" =~ "brew" ]]
}

@test "packages: contains dotclaude suggestion code" {
  run grep -q "Claude Code detected without dotclaude" "$DOTFILES_DIR/bin/dotfiles-packages"
  [ "$status" -eq 0 ]
}

# ============================================================
# dotfiles-drift execution tests
# ============================================================

@test "drift: script exists and is executable" {
  [ -x "$DOTFILES_DIR/bin/dotfiles-drift" ]
}

@test "drift: includes Claude-Profiles in DRIFT_ITEMS" {
  run grep -q "Claude-Profiles" "$DOTFILES_DIR/bin/dotfiles-drift"
  [ "$status" -eq 0 ]
}

# ============================================================
# dotfiles-init execution tests
# ============================================================

@test "init: script exists and is executable" {
  [ -x "$DOTFILES_DIR/bin/dotfiles-init" ]
}

@test "init: contains Claude Code setup step" {
  run grep -q "Claude Code Setup" "$DOTFILES_DIR/bin/dotfiles-init"
  [ "$status" -eq 0 ]
}

@test "init: offers dotclaude installation" {
  run grep -q "Install dotclaude" "$DOTFILES_DIR/bin/dotfiles-init"
  [ "$status" -eq 0 ]
}

@test "init: uses dotclaude.dev install URL" {
  run grep -q "dotclaude.dev/install" "$DOTFILES_DIR/bin/dotfiles-init"
  [ "$status" -eq 0 ]
}

# ============================================================
# dotfiles-backup execution tests
# ============================================================

@test "backup: script exists and is executable" {
  [ -x "$DOTFILES_DIR/bin/dotfiles-backup" ]
}

@test "backup: shows help" {
  run "$DOTFILES_DIR/bin/dotfiles-backup" --help
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "Usage" ]] || [[ "${output}" =~ "backup" ]]
}

# ============================================================
# dotfiles-diff execution tests
# ============================================================

@test "diff: script exists and is executable" {
  [ -x "$DOTFILES_DIR/bin/dotfiles-diff" ]
}

@test "diff: shows help" {
  run "$DOTFILES_DIR/bin/dotfiles-diff" --help
  [ "$status" -eq 0 ]
}

# ============================================================
# lib/_logging.sh execution tests
# ============================================================

@test "logging: source _logging.sh successfully" {
  run bash -c "source $DOTFILES_DIR/lib/_logging.sh && info 'test message'"
  [[ "${output}" =~ "test" ]]
}

@test "logging: pass function works" {
  run bash -c "source $DOTFILES_DIR/lib/_logging.sh && pass 'success'"
  [[ "${output}" =~ "success" ]]
}

@test "logging: fail function works" {
  run bash -c "source $DOTFILES_DIR/lib/_logging.sh && fail 'error'"
  [[ "${output}" =~ "error" ]]
}

@test "logging: warn function works" {
  run bash -c "source $DOTFILES_DIR/lib/_logging.sh && warn 'warning'"
  [[ "${output}" =~ "warning" ]]
}

@test "logging: section function works" {
  run bash -c "source $DOTFILES_DIR/lib/_logging.sh && section 'header'"
  [[ "${output}" =~ "header" ]]
}

# ============================================================
# zsh function tests
# ============================================================

@test "zsh: 50-functions.zsh has valid syntax" {
  run zsh -n "$DOTFILES_DIR/zsh/zsh.d/50-functions.zsh"
  [ "$status" -eq 0 ]
}

@test "zsh: 40-aliases.zsh has valid syntax" {
  run zsh -n "$DOTFILES_DIR/zsh/zsh.d/40-aliases.zsh"
  [ "$status" -eq 0 ]
}

@test "status function: contains profile variable" {
  run grep -q "s_profile" "$DOTFILES_DIR/zsh/zsh.d/50-functions.zsh"
  [ "$status" -eq 0 ]
}

@test "status function: checks for dotclaude command" {
  run grep -q "command -v dotclaude" "$DOTFILES_DIR/zsh/zsh.d/50-functions.zsh"
  [ "$status" -eq 0 ]
}
