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
# vault/_common.sh Claude-Profiles tests
# ============================================================

@test "vault: Claude-Profiles in SYNCABLE_ITEMS" {
  run grep -q "Claude-Profiles" "$DOTFILES_DIR/vault/_common.sh"
  [ "$status" -eq 0 ]
}

@test "vault: Claude-Profiles points to profiles.json" {
  run grep "Claude-Profiles.*profiles.json" "$DOTFILES_DIR/vault/_common.sh"
  [ "$status" -eq 0 ]
}

# ============================================================
# dotfiles-drift Claude-Profiles tests
# ============================================================

@test "drift: includes Claude-Profiles in DRIFT_ITEMS" {
  run grep -q "Claude-Profiles" "$DOTFILES_DIR/bin/dotfiles-drift"
  [ "$status" -eq 0 ]
}

# ============================================================
# dotfiles-packages Claude suggestion tests
# ============================================================

@test "packages: contains dotclaude suggestion code" {
  run grep -q "Claude Code detected without dotclaude" "$DOTFILES_DIR/bin/dotfiles-packages"
  [ "$status" -eq 0 ]
}

@test "packages: checks for claude command" {
  run grep -q "command -v claude" "$DOTFILES_DIR/bin/dotfiles-packages"
  [ "$status" -eq 0 ]
}

# ============================================================
# dotfiles-init Claude setup tests
# ============================================================

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
# zsh status function tests (source and test)
# ============================================================

@test "status function: contains profile variable" {
  run grep -q "s_profile" "$DOTFILES_DIR/zsh/zsh.d/50-functions.zsh"
  [ "$status" -eq 0 ]
}

@test "status function: checks for dotclaude command" {
  run grep -q "command -v dotclaude" "$DOTFILES_DIR/zsh/zsh.d/50-functions.zsh"
  [ "$status" -eq 0 ]
}

@test "status function: calls dotclaude active" {
  run grep -q "dotclaude active" "$DOTFILES_DIR/zsh/zsh.d/50-functions.zsh"
  [ "$status" -eq 0 ]
}

@test "status function: shows profile line" {
  run grep -q 'echo.*profile.*s_profile' "$DOTFILES_DIR/zsh/zsh.d/50-functions.zsh"
  [ "$status" -eq 0 ]
}
