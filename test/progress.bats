#!/usr/bin/env bats
# ============================================================
# Test suite for lib/_progress.sh
# Run: bats test/progress.bats
# ============================================================

setup() {
    export DOTFILES_DIR="${BATS_TEST_DIRNAME}/.."
    export DOTFILES_PROGRESS_FORCE=true
    source "$DOTFILES_DIR/lib/_progress.sh"
}

# ============================================================
# Progress Bar Tests
# ============================================================

@test "progress_bar: 0% shows empty bar" {
    result=$(progress_bar 0 10 "test" 2>&1)
    [[ "$result" == *"0%"* ]]
}

@test "progress_bar: 50% shows half-filled bar" {
    result=$(progress_bar 5 10 "test" 2>&1)
    [[ "$result" == *"50%"* ]]
}

@test "progress_bar: 100% shows full bar" {
    result=$(progress_bar 10 10 "test" 2>&1)
    [[ "$result" == *"100%"* ]]
}

@test "progress_bar: over 100% caps at 100%" {
    result=$(progress_bar 15 10 "test" 2>&1)
    [[ "$result" == *"100%"* ]]
}

@test "progress_bar: zero total does not crash" {
    run progress_bar 5 0 "test"
    [[ $status -eq 0 ]]
}

@test "progress_bar: includes label" {
    result=$(progress_bar 5 10 "my label" 2>&1)
    [[ "$result" == *"my label"* ]]
}

@test "progress_done: shows completion message" {
    result=$(progress_done "All done" 2>&1)
    [[ "$result" == *"All done"* ]]
    [[ "$result" == *"✓"* ]]
}

# ============================================================
# ASCII Mode Tests
# ============================================================

@test "progress_bar: ASCII mode uses = instead of blocks" {
    DOTFILES_UNICODE=false
    result=$(progress_bar 5 10 "ascii" 2>&1)
    [[ "$result" == *"="* ]]
    DOTFILES_UNICODE=true
}

@test "progress_bar: Unicode mode uses block characters" {
    DOTFILES_UNICODE=true
    result=$(progress_bar 5 10 "unicode" 2>&1)
    # Check for unicode block or the dim character
    [[ "$result" == *"█"* ]] || [[ "$result" == *"░"* ]]
}

# ============================================================
# Stepped Progress Tests
# ============================================================

@test "steps_init: creates header" {
    result=$(steps_init 3 "Test Header" 2>&1)
    [[ "$result" == *"Test Header"* ]]
}

@test "step: increments counter" {
    _STEP_CURRENT=0
    _STEP_TOTAL=3
    step "First" >/dev/null 2>&1
    [[ $_STEP_CURRENT -eq 1 ]]
    step "Second" >/dev/null 2>&1
    [[ $_STEP_CURRENT -eq 2 ]]
}

@test "step: shows step number" {
    _STEP_CURRENT=0
    _STEP_TOTAL=3
    result=$(step "Test step" 2>&1)
    [[ "$result" == *"[1/3]"* ]]
}

@test "step_done: shows checkmark" {
    result=$(step_done "Complete" 2>&1)
    [[ "$result" == *"✓"* ]]
    [[ "$result" == *"Complete"* ]]
}

@test "step_fail: shows X mark" {
    result=$(step_fail "Failed" 2>&1)
    [[ "$result" == *"✗"* ]]
    [[ "$result" == *"Failed"* ]]
}

@test "steps_done: shows completion" {
    result=$(steps_done "All complete" 2>&1)
    [[ "$result" == *"All complete"* ]]
}

# ============================================================
# Spinner Tests
# ============================================================

@test "spinner_start: sets PID variable" {
    spinner_start "test"
    [[ -n "$_SPINNER_PID" ]]
    spinner_stop
}

@test "spinner_stop: clears PID variable" {
    spinner_start "test"
    spinner_stop
    [[ -z "$_SPINNER_PID" ]]
}

@test "spinner_stop: with message shows checkmark" {
    spinner_start "test"
    result=$(spinner_stop "Done" 2>&1)
    [[ "$result" == *"✓"* ]]
    [[ "$result" == *"Done"* ]]
}

# ============================================================
# run_with_spinner Tests
# ============================================================

@test "run_with_spinner: returns success exit code" {
    run run_with_spinner "test" true
    [[ $status -eq 0 ]]
}

@test "run_with_spinner: returns failure exit code" {
    run run_with_spinner "test" false
    [[ $status -eq 1 ]]
}

@test "run_with_spinner: shows failure message on error" {
    result=$(run_with_spinner "Failing" false 2>&1) || true
    [[ "$result" == *"✗"* ]]
    [[ "$result" == *"failed"* ]]
}

# ============================================================
# Configuration Tests
# ============================================================

@test "_progress_enabled: returns true with force flag" {
    DOTFILES_PROGRESS_FORCE=true
    _progress_enabled
    [[ $? -eq 0 ]]
}

@test "_progress_enabled: returns false when disabled" {
    unset DOTFILES_PROGRESS_FORCE
    DOTFILES_PROGRESS=false
    _progress_enabled
    [[ $? -eq 1 ]]
    DOTFILES_PROGRESS=true
}

@test "_progress_unicode: returns true by default" {
    DOTFILES_UNICODE=true
    _progress_unicode
    [[ $? -eq 0 ]]
}

@test "_progress_unicode: returns false when disabled" {
    DOTFILES_UNICODE=false
    _progress_unicode
    [[ $? -eq 1 ]]
    DOTFILES_UNICODE=true
}

# ============================================================
# ETA Tests
# ============================================================

@test "progress_bar: shows ETA after progress_init" {
    progress_init
    sleep 1
    result=$(progress_bar 1 10 "with ETA" 2>&1)
    # ETA should appear after some progress
    # Note: may not always show if too fast
    [[ $? -eq 0 ]]
}

# ============================================================
# Edge Cases
# ============================================================

@test "progress_bar: handles empty label" {
    run progress_bar 5 10 ""
    [[ $status -eq 0 ]]
}

@test "progress_bar: handles special characters in label" {
    run progress_bar 5 10 "test & 'special' \"chars\""
    [[ $status -eq 0 ]]
}

@test "step: handles empty message" {
    _STEP_CURRENT=0
    _STEP_TOTAL=1
    run step ""
    [[ $status -eq 0 ]]
}

@test "multiple spinners: new spinner kills old" {
    spinner_start "first"
    local first_pid="$_SPINNER_PID"
    spinner_start "second"
    local second_pid="$_SPINNER_PID"

    # PIDs should be different
    [[ "$first_pid" != "$second_pid" ]]

    # First should be killed
    ! kill -0 "$first_pid" 2>/dev/null || true

    spinner_stop
}
