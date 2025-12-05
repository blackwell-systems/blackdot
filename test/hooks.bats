#!/usr/bin/env bats
# Unit tests for lib/_hooks.sh - Hook System
# NOTE: These tests require zsh since _hooks.sh uses zsh syntax

setup() {
    export DOTFILES_DIR="${BATS_TEST_DIRNAME}/.."
    export HOOKS_SH="${DOTFILES_DIR}/lib/_hooks.sh"
    export FEATURES_SH="${DOTFILES_DIR}/lib/_features.sh"

    # Create temporary config/hooks directory
    export TEST_CONFIG_DIR="${BATS_TEST_TMPDIR}/dotfiles"
    export TEST_HOOKS_DIR="${BATS_TEST_TMPDIR}/hooks"
    mkdir -p "$TEST_CONFIG_DIR"
    mkdir -p "$TEST_HOOKS_DIR"

    # Set hook system config for tests
    export DOTFILES_HOOKS_DIR="$TEST_HOOKS_DIR"
    export DOTFILES_HOOKS_CONFIG="$TEST_CONFIG_DIR/hooks.json"
    export DOTFILES_HOOKS_VERBOSE="false"
    export DOTFILES_HOOKS_DISABLED="false"
}

teardown() {
    rm -rf "$TEST_CONFIG_DIR"
    rm -rf "$TEST_HOOKS_DIR"
}

# ============================================================
# Function Existence Tests
# ============================================================

@test "hook_register function exists" {
    run zsh -c "source '$HOOKS_SH'; type hook_register"
    [ "$status" -eq 0 ]
    [[ "$output" == *"function"* ]]
}

@test "hook_unregister function exists" {
    run zsh -c "source '$HOOKS_SH'; type hook_unregister"
    [ "$status" -eq 0 ]
    [[ "$output" == *"function"* ]]
}

@test "hook_run function exists" {
    run zsh -c "source '$HOOKS_SH'; type hook_run"
    [ "$status" -eq 0 ]
    [[ "$output" == *"function"* ]]
}

@test "hook_list function exists" {
    run zsh -c "source '$HOOKS_SH'; type hook_list"
    [ "$status" -eq 0 ]
    [[ "$output" == *"function"* ]]
}

@test "hook_valid_point function exists" {
    run zsh -c "source '$HOOKS_SH'; type hook_valid_point"
    [ "$status" -eq 0 ]
    [[ "$output" == *"function"* ]]
}

@test "hook_init function exists" {
    run zsh -c "source '$HOOKS_SH'; type hook_init"
    [ "$status" -eq 0 ]
    [[ "$output" == *"function"* ]]
}

@test "hook_points function exists" {
    run zsh -c "source '$HOOKS_SH'; type hook_points"
    [ "$status" -eq 0 ]
    [[ "$output" == *"function"* ]]
}

@test "hook_clear function exists" {
    run zsh -c "source '$HOOKS_SH'; type hook_clear"
    [ "$status" -eq 0 ]
    [[ "$output" == *"function"* ]]
}

# ============================================================
# Hook Point Validation Tests
# ============================================================

@test "hook_valid_point returns 0 for valid point post_vault_pull" {
    run zsh -c "source '$HOOKS_SH'; hook_valid_point 'post_vault_pull'"
    [ "$status" -eq 0 ]
}

@test "hook_valid_point returns 0 for valid point shell_init" {
    run zsh -c "source '$HOOKS_SH'; hook_valid_point 'shell_init'"
    [ "$status" -eq 0 ]
}

@test "hook_valid_point returns 0 for valid point pre_bootstrap" {
    run zsh -c "source '$HOOKS_SH'; hook_valid_point 'pre_bootstrap'"
    [ "$status" -eq 0 ]
}

@test "hook_valid_point returns 1 for invalid point" {
    run zsh -c "source '$HOOKS_SH'; hook_valid_point 'invalid_hook'"
    [ "$status" -eq 1 ]
}

@test "hook_valid_point returns 1 for empty string" {
    run zsh -c "source '$HOOKS_SH'; hook_valid_point ''"
    [ "$status" -eq 1 ]
}

@test "hook_points lists all hook points" {
    run zsh -c "source '$HOOKS_SH'; hook_points"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pre_install"* ]]
    [[ "$output" == *"post_vault_pull"* ]]
    [[ "$output" == *"shell_init"* ]]
}

# ============================================================
# Hook Registration Tests
# ============================================================

@test "hook_register registers function successfully" {
    run zsh -c "
        source '$HOOKS_SH'
        test_func() { echo 'test'; }
        hook_register 'post_vault_pull' 'test_func'
        echo \"\${HOOKS[post_vault_pull]}\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"test_func"* ]]
}

@test "hook_register fails for invalid hook point" {
    run zsh -c "
        source '$HOOKS_SH'
        test_func() { echo 'test'; }
        hook_register 'invalid_point' 'test_func'
    "
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid hook point"* ]]
}

@test "hook_register fails for missing function" {
    run zsh -c "
        source '$HOOKS_SH'
        hook_register 'post_vault_pull' 'nonexistent_func'
    "
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "hook_register fails with missing arguments" {
    run zsh -c "
        source '$HOOKS_SH'
        hook_register 'post_vault_pull'
    "
    [ "$status" -eq 1 ]
    [[ "$output" == *"missing arguments"* ]]
}

@test "hook_register is idempotent (no duplicate registration)" {
    run zsh -c "
        source '$HOOKS_SH'
        test_func() { echo 'test'; }
        hook_register 'post_vault_pull' 'test_func'
        hook_register 'post_vault_pull' 'test_func'
        echo \"\${HOOKS[post_vault_pull]}\"
    "
    [ "$status" -eq 0 ]
    # Should only have one instance of test_func
    [[ "$output" == "test_func" ]]
}

@test "hook_register allows multiple different functions" {
    run zsh -c "
        source '$HOOKS_SH'
        func_a() { echo 'a'; }
        func_b() { echo 'b'; }
        hook_register 'post_vault_pull' 'func_a'
        hook_register 'post_vault_pull' 'func_b'
        echo \"\${HOOKS[post_vault_pull]}\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"func_a"* ]]
    [[ "$output" == *"func_b"* ]]
}

# ============================================================
# Hook Unregister Tests
# ============================================================

@test "hook_unregister removes function" {
    run zsh -c "
        source '$HOOKS_SH'
        test_func() { echo 'test'; }
        hook_register 'post_vault_pull' 'test_func'
        hook_unregister 'post_vault_pull' 'test_func'
        echo \"\${HOOKS[post_vault_pull]:-empty}\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == "empty" ]] || [[ "$output" == "" ]]
}

@test "hook_unregister is safe on non-existent hook" {
    run zsh -c "
        source '$HOOKS_SH'
        hook_unregister 'post_vault_pull' 'nonexistent'
    "
    [ "$status" -eq 0 ]
}

@test "hook_unregister only removes specified function" {
    run zsh -c "
        source '$HOOKS_SH'
        func_a() { echo 'a'; }
        func_b() { echo 'b'; }
        hook_register 'post_vault_pull' 'func_a'
        hook_register 'post_vault_pull' 'func_b'
        hook_unregister 'post_vault_pull' 'func_a'
        echo \"\${HOOKS[post_vault_pull]}\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" != *"func_a"* ]]
    [[ "$output" == *"func_b"* ]]
}

# ============================================================
# Hook Execution Tests
# ============================================================

@test "hook_run executes registered function" {
    run zsh -c "
        source '$HOOKS_SH'
        test_func() { echo 'hook executed'; }
        hook_register 'post_vault_pull' 'test_func'
        hook_run 'post_vault_pull'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"hook executed"* ]]
}

@test "hook_run executes multiple functions in order" {
    run zsh -c "
        source '$HOOKS_SH'
        func_first() { echo 'first'; }
        func_second() { echo 'second'; }
        hook_register 'post_vault_pull' 'func_first'
        hook_register 'post_vault_pull' 'func_second'
        hook_run 'post_vault_pull'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"first"* ]]
    [[ "$output" == *"second"* ]]
}

@test "hook_run passes arguments to hooks" {
    run zsh -c "
        source '$HOOKS_SH'
        test_func() { echo \"args: \$@\"; }
        hook_register 'post_vault_pull' 'test_func'
        hook_run 'post_vault_pull' 'arg1' 'arg2'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"args: arg1 arg2"* ]]
}

@test "hook_run returns 1 if any hook fails" {
    run zsh -c "
        source '$HOOKS_SH'
        failing_func() { return 1; }
        hook_register 'post_vault_pull' 'failing_func'
        hook_run 'post_vault_pull'
    "
    [ "$status" -eq 1 ]
}

@test "hook_run continues on failure when fail_fast=false" {
    run zsh -c "
        source '$HOOKS_SH'
        export HOOKS_FAIL_FAST=false
        failing_func() { echo 'failing'; return 1; }
        passing_func() { echo 'passing'; }
        hook_register 'post_vault_pull' 'failing_func'
        hook_register 'post_vault_pull' 'passing_func'
        hook_run 'post_vault_pull'
    "
    [[ "$output" == *"failing"* ]]
    [[ "$output" == *"passing"* ]]
}

@test "hook_run stops on failure when fail_fast=true" {
    run zsh -c "
        source '$HOOKS_SH'
        export HOOKS_FAIL_FAST=true
        failing_func() { echo 'failing'; return 1; }
        passing_func() { echo 'passing'; }
        hook_register 'post_vault_pull' 'failing_func'
        hook_register 'post_vault_pull' 'passing_func'
        hook_run 'post_vault_pull'
    "
    [ "$status" -eq 1 ]
    [[ "$output" == *"failing"* ]]
    [[ "$output" != *"passing"* ]]
}

@test "hook_run is skipped when HOOKS_DISABLED=true" {
    run zsh -c "
        source '$HOOKS_SH'
        export HOOKS_DISABLED=true
        test_func() { echo 'should not run'; }
        hook_register 'post_vault_pull' 'test_func'
        hook_run 'post_vault_pull'
        echo 'done'
    "
    [ "$status" -eq 0 ]
    [[ "$output" != *"should not run"* ]]
    [[ "$output" == *"done"* ]]
}

@test "hook_run fails for invalid hook point" {
    run zsh -c "
        source '$HOOKS_SH'
        hook_run 'invalid_point'
    "
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid hook point"* ]]
}

# ============================================================
# File-Based Hook Tests
# ============================================================

@test "hook_run executes file-based hooks" {
    # Create a test hook script
    mkdir -p "${TEST_HOOKS_DIR}/post_vault_pull"
    cat > "${TEST_HOOKS_DIR}/post_vault_pull/10-test.sh" << 'EOF'
#!/bin/bash
echo "file hook executed"
EOF
    chmod +x "${TEST_HOOKS_DIR}/post_vault_pull/10-test.sh"

    run zsh -c "
        export DOTFILES_HOOKS_DIR='$TEST_HOOKS_DIR'
        source '$HOOKS_SH'
        hook_run 'post_vault_pull'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"file hook executed"* ]]
}

@test "hook_run skips non-executable file hooks" {
    mkdir -p "${TEST_HOOKS_DIR}/post_vault_pull"
    cat > "${TEST_HOOKS_DIR}/post_vault_pull/10-noexec.sh" << 'EOF'
#!/bin/bash
echo "should not run"
EOF
    # Intentionally NOT making it executable

    run zsh -c "
        export DOTFILES_HOOKS_DIR='$TEST_HOOKS_DIR'
        source '$HOOKS_SH'
        hook_run 'post_vault_pull'
        echo 'done'
    "
    [ "$status" -eq 0 ]
    [[ "$output" != *"should not run"* ]]
}

@test "hook_run executes file hooks in alphabetical order" {
    mkdir -p "${TEST_HOOKS_DIR}/post_vault_pull"

    cat > "${TEST_HOOKS_DIR}/post_vault_pull/20-second.sh" << 'EOF'
#!/bin/bash
echo "second"
EOF
    chmod +x "${TEST_HOOKS_DIR}/post_vault_pull/20-second.sh"

    cat > "${TEST_HOOKS_DIR}/post_vault_pull/10-first.sh" << 'EOF'
#!/bin/bash
echo "first"
EOF
    chmod +x "${TEST_HOOKS_DIR}/post_vault_pull/10-first.sh"

    run zsh -c "
        export DOTFILES_HOOKS_DIR='$TEST_HOOKS_DIR'
        source '$HOOKS_SH'
        hook_run 'post_vault_pull'
    "
    [ "$status" -eq 0 ]
    # First should come before second
    first_pos=$(echo "$output" | grep -n "first" | cut -d: -f1)
    second_pos=$(echo "$output" | grep -n "second" | cut -d: -f1)
    [ "$first_pos" -lt "$second_pos" ]
}

# ============================================================
# JSON Config Hook Tests
# ============================================================

@test "hook_run executes JSON-configured command hooks" {
    cat > "${TEST_CONFIG_DIR}/hooks.json" << 'EOF'
{
  "hooks": {
    "post_vault_pull": [
      {
        "name": "test-cmd",
        "command": "echo json_hook_ran",
        "enabled": true
      }
    ]
  }
}
EOF

    run zsh -c "
        export DOTFILES_HOOKS_CONFIG='${TEST_CONFIG_DIR}/hooks.json'
        source '$HOOKS_SH'
        hook_run 'post_vault_pull'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"json_hook_ran"* ]]
}

@test "hook_run respects JSON enabled=false" {
    cat > "${TEST_CONFIG_DIR}/hooks.json" << 'EOF'
{
  "hooks": {
    "post_vault_pull": [
      {
        "name": "disabled-hook",
        "command": "echo should_not_run",
        "enabled": false
      }
    ]
  }
}
EOF

    run zsh -c "
        export DOTFILES_HOOKS_CONFIG='${TEST_CONFIG_DIR}/hooks.json'
        source '$HOOKS_SH'
        hook_run 'post_vault_pull'
        echo done
    "
    [ "$status" -eq 0 ]
    [[ "$output" != *"should_not_run"* ]]
}

@test "hook_run respects JSON fail_ok=true" {
    cat > "${TEST_CONFIG_DIR}/hooks.json" << 'EOF'
{
  "hooks": {
    "post_vault_pull": [
      {
        "name": "failing-ok",
        "command": "exit 1",
        "enabled": true,
        "fail_ok": true
      },
      {
        "name": "after-fail",
        "command": "echo after_fail_ok",
        "enabled": true
      }
    ]
  }
}
EOF

    run zsh -c "
        export DOTFILES_HOOKS_CONFIG='${TEST_CONFIG_DIR}/hooks.json'
        source '$HOOKS_SH'
        hook_run 'post_vault_pull'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"after_fail_ok"* ]]
}

# ============================================================
# Hook List Tests
# ============================================================

@test "hook_list shows all hook points" {
    run zsh -c "
        source '$HOOKS_SH'
        hook_list
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"All hook points"* ]]
    [[ "$output" == *"pre_vault_pull"* ]]
    [[ "$output" == *"post_vault_pull"* ]]
}

@test "hook_list shows specific point details" {
    run zsh -c "
        source '$HOOKS_SH'
        test_func() { echo test; }
        hook_register 'post_vault_pull' 'test_func'
        hook_list 'post_vault_pull'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"Hooks for: post_vault_pull"* ]]
    [[ "$output" == *"test_func"* ]]
}

@test "hook_list fails for invalid point" {
    run zsh -c "
        source '$HOOKS_SH'
        hook_list 'invalid_point'
    "
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid hook point"* ]]
}

# ============================================================
# Hook Clear Tests
# ============================================================

@test "hook_clear removes all registered hooks" {
    run zsh -c "
        source '$HOOKS_SH'
        func_a() { echo a; }
        func_b() { echo b; }
        hook_register 'post_vault_pull' 'func_a'
        hook_register 'shell_init' 'func_b'
        hook_clear
        echo \"pull: \${HOOKS[post_vault_pull]:-empty}\"
        echo \"init: \${HOOKS[shell_init]:-empty}\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"pull: empty"* ]]
    [[ "$output" == *"init: empty"* ]]
}

# ============================================================
# Hook Init Tests
# ============================================================

@test "hook_init loads settings from JSON config" {
    cat > "${TEST_CONFIG_DIR}/hooks.json" << 'EOF'
{
  "settings": {
    "fail_fast": true,
    "verbose": true,
    "timeout": 60
  }
}
EOF

    run zsh -c "
        export DOTFILES_HOOKS_CONFIG='${TEST_CONFIG_DIR}/hooks.json'
        source '$HOOKS_SH'
        hook_init
        echo \"fail_fast=\$HOOKS_FAIL_FAST\"
        echo \"verbose=\$HOOKS_VERBOSE\"
        echo \"timeout=\$HOOKS_TIMEOUT\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"fail_fast=true"* ]]
    [[ "$output" == *"verbose=true"* ]]
    [[ "$output" == *"timeout=60"* ]]
}

# ============================================================
# Feature Integration Tests
# ============================================================

@test "hook_run respects hooks feature disabled" {
    run zsh -c "
        source '$FEATURES_SH'
        source '$HOOKS_SH'
        feature_disable 'hooks'
        test_func() { echo 'should not run'; }
        hook_register 'post_vault_pull' 'test_func'
        hook_run 'post_vault_pull'
        echo 'done'
    "
    [ "$status" -eq 0 ]
    [[ "$output" != *"should not run"* ]]
    [[ "$output" == *"done"* ]]
}

@test "hook_run respects parent feature (vault) disabled for vault hooks" {
    run zsh -c "
        source '$FEATURES_SH'
        source '$HOOKS_SH'
        feature_disable 'vault'
        test_func() { echo 'vault hook'; }
        hook_register 'post_vault_pull' 'test_func'
        hook_run 'post_vault_pull'
        echo 'done'
    "
    [ "$status" -eq 0 ]
    [[ "$output" != *"vault hook"* ]]
    [[ "$output" == *"done"* ]]
}

@test "hooks feature is registered in feature registry" {
    run zsh -c "
        source '$FEATURES_SH'
        feature_exists 'hooks' && echo 'exists'
    "
    [ "$status" -eq 0 ]
    [ "$output" = "exists" ]
}

# ============================================================
# Flag Tests
# ============================================================

@test "hook_run --verbose shows detailed output" {
    run zsh -c "
        source '$HOOKS_SH'
        test_func() { echo 'output'; }
        hook_register 'post_vault_pull' 'test_func'
        hook_run --verbose 'post_vault_pull'
    " 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" == *"hook_run: running hooks for post_vault_pull"* ]]
    [[ "$output" == *"hook_exec_func: test_func"* ]]
}

@test "hook_run --no-hooks skips execution" {
    run zsh -c "
        source '$HOOKS_SH'
        test_func() { echo 'should not run'; }
        hook_register 'post_vault_pull' 'test_func'
        hook_run --no-hooks 'post_vault_pull'
        echo 'done'
    "
    [ "$status" -eq 0 ]
    [[ "$output" != *"should not run"* ]]
    [[ "$output" == *"done"* ]]
}

@test "hook_run --verbose --no-hooks shows skip message" {
    run zsh -c "
        source '$HOOKS_SH'
        hook_run --verbose --no-hooks 'post_vault_pull'
    " 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipped via --no-hooks"* ]]
}

# ============================================================
# Multiple Sourcing Protection
# ============================================================

@test "hooks library prevents multiple sourcing" {
    run zsh -c "
        source '$HOOKS_SH'
        source '$HOOKS_SH'
        source '$HOOKS_SH'
        echo 'sourced multiple times without error'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"sourced multiple times without error"* ]]
}

# ============================================================
# CLI Command Tests (bin/dotfiles-hook)
# ============================================================

@test "dotfiles-hook command exists and is executable" {
    [ -x "${DOTFILES_DIR}/bin/dotfiles-hook" ]
}

@test "dotfiles-hook --help shows usage" {
    run "${DOTFILES_DIR}/bin/dotfiles-hook" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"Commands:"* ]]
}

@test "dotfiles-hook list shows all hook points" {
    run "${DOTFILES_DIR}/bin/dotfiles-hook" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"Hook System"* ]]
    [[ "$output" == *"Lifecycle"* ]]
    [[ "$output" == *"Vault"* ]]
}

@test "dotfiles-hook list <point> shows specific point" {
    run "${DOTFILES_DIR}/bin/dotfiles-hook" list post_vault_pull
    [ "$status" -eq 0 ]
    # Output has ANSI color codes, so check parts separately
    [[ "$output" == *"Hooks for:"* ]]
    [[ "$output" == *"post_vault_pull"* ]]
}

@test "dotfiles-hook list fails for invalid point" {
    run "${DOTFILES_DIR}/bin/dotfiles-hook" list invalid_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid hook point"* ]]
}

@test "dotfiles-hook points lists all hook points with descriptions" {
    run "${DOTFILES_DIR}/bin/dotfiles-hook" points
    [ "$status" -eq 0 ]
    [[ "$output" == *"Available Hook Points"* ]]
    [[ "$output" == *"pre_vault_pull"* ]]
    [[ "$output" == *"Before restoring secrets"* ]]
}

@test "dotfiles-hook run requires point argument" {
    run "${DOTFILES_DIR}/bin/dotfiles-hook" run
    [ "$status" -eq 1 ]
    [[ "$output" == *"Hook point required"* ]]
}

@test "dotfiles-hook run fails for invalid point" {
    run "${DOTFILES_DIR}/bin/dotfiles-hook" run invalid_hook
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid hook point"* ]]
}

@test "dotfiles-hook run succeeds with no hooks" {
    run "${DOTFILES_DIR}/bin/dotfiles-hook" run post_vault_pull
    [ "$status" -eq 0 ]
    [[ "$output" == *"Hooks completed successfully"* ]]
}

@test "dotfiles-hook run --verbose shows detailed output" {
    run "${DOTFILES_DIR}/bin/dotfiles-hook" run --verbose post_vault_pull
    [ "$status" -eq 0 ]
    [[ "$output" == *"running hooks"* ]] || [[ "$output" == *"Hooks completed"* ]]
}

@test "dotfiles-hook add requires both arguments" {
    run "${DOTFILES_DIR}/bin/dotfiles-hook" add post_vault_pull
    [ "$status" -eq 1 ]
    [[ "$output" == *"required"* ]]
}

@test "dotfiles-hook add fails for non-existent script" {
    run "${DOTFILES_DIR}/bin/dotfiles-hook" add post_vault_pull /nonexistent/script.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "dotfiles-hook remove requires both arguments" {
    run "${DOTFILES_DIR}/bin/dotfiles-hook" remove post_vault_pull
    [ "$status" -eq 1 ]
    [[ "$output" == *"required"* ]]
}

@test "dotfiles-hook test requires point argument" {
    run "${DOTFILES_DIR}/bin/dotfiles-hook" test
    [ "$status" -eq 1 ]
    [[ "$output" == *"Hook point required"* ]]
}

@test "dotfiles-hook test shows hooks and runs them" {
    run "${DOTFILES_DIR}/bin/dotfiles-hook" test post_vault_pull
    [ "$status" -eq 0 ]
    # Output has ANSI color codes, so check parts separately
    [[ "$output" == *"Testing hooks for:"* ]]
    [[ "$output" == *"post_vault_pull"* ]]
}

# ============================================================
# CLI Feature Awareness Integration
# ============================================================

@test "hook command is registered in CLI_COMMAND_FEATURES" {
    run zsh -c "
        source '${DOTFILES_DIR}/lib/_cli_features.sh'
        echo \"\${CLI_COMMAND_FEATURES[hook]}\"
    "
    [ "$status" -eq 0 ]
    [ "$output" = "hooks" ]
}

@test "hook subcommands are registered in CLI_SUBCOMMAND_FEATURES" {
    run zsh -c "
        source '${DOTFILES_DIR}/lib/_cli_features.sh'
        echo \"\${CLI_SUBCOMMAND_FEATURES[hook:list]}\"
        echo \"\${CLI_SUBCOMMAND_FEATURES[hook:run]}\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"hooks"* ]]
}

# ============================================================
# Integration Tests - Hooks in Other Files
# ============================================================

@test "bin/dotfiles-sync sources hooks library" {
    grep -q "source.*_hooks.sh" "${DOTFILES_DIR}/bin/dotfiles-sync"
}

@test "bin/dotfiles-sync has vault hook calls" {
    grep -q "hook_run.*pre_vault" "${DOTFILES_DIR}/bin/dotfiles-sync"
    grep -q "hook_run.*post_vault" "${DOTFILES_DIR}/bin/dotfiles-sync"
}

@test "bootstrap/_common.sh has run_hook function" {
    grep -q "run_hook()" "${DOTFILES_DIR}/bootstrap/_common.sh"
}

@test "bootstrap/bootstrap-mac.sh has bootstrap hooks" {
    grep -q "run_hook.*pre_bootstrap" "${DOTFILES_DIR}/bootstrap/bootstrap-mac.sh"
    grep -q "run_hook.*post_bootstrap" "${DOTFILES_DIR}/bootstrap/bootstrap-mac.sh"
}

@test "bootstrap/bootstrap-linux.sh has bootstrap hooks" {
    grep -q "run_hook.*pre_bootstrap" "${DOTFILES_DIR}/bootstrap/bootstrap-linux.sh"
    grep -q "run_hook.*post_bootstrap" "${DOTFILES_DIR}/bootstrap/bootstrap-linux.sh"
}

@test "install.sh has install hooks" {
    grep -q "run_hook.*pre_install" "${DOTFILES_DIR}/install.sh"
    grep -q "run_hook.*post_install" "${DOTFILES_DIR}/install.sh"
}

@test "zsh/zsh.d/90-integrations.zsh has shell hooks" {
    grep -q "hook_run.*shell_init" "${DOTFILES_DIR}/zsh/zsh.d/90-integrations.zsh"
    grep -q "hook_run.*directory_change" "${DOTFILES_DIR}/zsh/zsh.d/90-integrations.zsh"
    grep -q "hook_run.*shell_exit" "${DOTFILES_DIR}/zsh/zsh.d/90-integrations.zsh"
}

@test "bin/dotfiles-doctor has doctor hooks" {
    grep -q "run_hook.*pre_doctor" "${DOTFILES_DIR}/bin/dotfiles-doctor"
    grep -q "run_hook.*post_doctor" "${DOTFILES_DIR}/bin/dotfiles-doctor"
    grep -q "run_hook.*doctor_check" "${DOTFILES_DIR}/bin/dotfiles-doctor"
}

@test "run_hook in _common.sh handles missing zsh gracefully" {
    # Test that run_hook returns 0 even when hooks can't run
    run bash -c "
        DOTFILES_DIR='${DOTFILES_DIR}'
        source '${DOTFILES_DIR}/bootstrap/_common.sh'
        run_hook 'pre_bootstrap'
        echo 'success'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"success"* ]]
}
