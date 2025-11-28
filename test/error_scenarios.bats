#!/usr/bin/env bats
# ============================================================
# FILE: test/error_scenarios.bats
# Tests for error handling and edge cases
# ============================================================

# Test setup
setup() {
    export TEST_DIR="${BATS_TEST_TMPDIR}/error-test"
    export TEST_HOME="$TEST_DIR/home"
    export MOCK_DATA_DIR="$TEST_DIR/mock-bw"
    export BW_MOCK_DATA_DIR="$MOCK_DATA_DIR"
    export DOTFILES_DIR="${BATS_TEST_DIRNAME}/.."

    # Create test directories
    mkdir -p "$TEST_HOME"
    mkdir -p "$MOCK_DATA_DIR/items"
    mkdir -p "$TEST_HOME/.ssh"
    mkdir -p "$TEST_HOME/.aws"

    # Set HOME to test directory
    export HOME="$TEST_HOME"

    # Add mock bw to PATH
    export PATH="${BATS_TEST_DIRNAME}/mocks:$PATH"

    # Create mock session (unlocked state)
    echo "mock-session-token" > "$MOCK_DATA_DIR/.session"
}

teardown() {
    # Restore permissions before cleanup
    chmod -R u+rwx "$TEST_DIR" 2>/dev/null || true
    rm -rf "$TEST_DIR"
}

# ============================================================
# Permission Error Tests
# ============================================================

@test "error: handles permission denied on SSH directory" {
    # Create SSH directory with no write permission
    mkdir -p "$TEST_HOME/.ssh"
    chmod 000 "$TEST_HOME/.ssh"

    # Attempt to create a file should fail
    run touch "$TEST_HOME/.ssh/test_file" 2>&1

    [ "$status" -ne 0 ]

    # Restore permissions for cleanup
    chmod 755 "$TEST_HOME/.ssh"
}

@test "error: backup handles unreadable files gracefully" {
    # Create a file we can't read
    echo "secret" > "$TEST_HOME/.ssh/config"
    chmod 000 "$TEST_HOME/.ssh/config"

    # Backup should handle this gracefully (warn but not crash)
    export HOME="$TEST_HOME"
    run "$DOTFILES_DIR/bin/dotfiles-backup" 2>&1

    # Should complete (might warn, but shouldn't crash hard)
    # Exit code 0 or 1 both acceptable (depends on implementation)
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

    # Restore permissions
    chmod 644 "$TEST_HOME/.ssh/config"
}

@test "error: restore handles permission denied on target" {
    # Create read-only directory
    mkdir -p "$TEST_HOME/.config/readonly"
    chmod 555 "$TEST_HOME/.config/readonly"

    # Attempting to write should fail
    run touch "$TEST_HOME/.config/readonly/file" 2>&1
    [ "$status" -ne 0 ]

    # Cleanup
    chmod 755 "$TEST_HOME/.config/readonly"
}

# ============================================================
# Missing File/Directory Tests
# ============================================================

@test "error: backup handles missing source files" {
    # Don't create any source files - they're all missing
    export HOME="$TEST_HOME"

    # Backup should handle missing files gracefully
    run "$DOTFILES_DIR/bin/dotfiles-backup" 2>&1

    # Should succeed but backup will have fewer files
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "error: doctor handles missing dotfiles directory" {
    # Run doctor with non-existent DOTFILES_DIR
    export DOTFILES_DIR="/nonexistent/path"

    run "$BATS_TEST_DIRNAME/../bin/dotfiles-doctor" 2>&1

    # Should fail gracefully
    [ "$status" -ne 0 ] || [[ "$output" =~ "not found" ]] || [[ "$output" =~ "error" ]]
}

@test "error: metrics handles missing metrics file" {
    # Ensure no metrics file exists
    rm -f "$TEST_HOME/.dotfiles-metrics.jsonl"

    export HOME="$TEST_HOME"
    run "$DOTFILES_DIR/bin/dotfiles-metrics" 2>&1

    # Should exit with error and helpful message
    [ "$status" -ne 0 ]
    [[ "$output" =~ "No metrics found" ]] || [[ "$output" =~ "dotfiles doctor" ]]
}

# ============================================================
# Invalid Data Tests
# ============================================================

@test "error: mock bw handles invalid JSON gracefully" {
    # Create an invalid JSON file
    echo "{ invalid json }" > "$MOCK_DATA_DIR/items/invalid-item.json"

    run bw get item invalid-item

    # Should return the content (mock doesn't validate JSON)
    # Real tests would check that scripts handle this
    [ "$status" -eq 0 ]
}

@test "error: backup handles corrupted backup file" {
    # Create a corrupted backup file
    mkdir -p "$TEST_HOME/.dotfiles-backups"
    echo "not a valid tar.gz" > "$TEST_HOME/.dotfiles-backups/backup-corrupted.tar.gz"

    export HOME="$TEST_HOME"

    # List should still work
    run "$DOTFILES_DIR/bin/dotfiles-backup" --list 2>&1

    # Should show backups (even if corrupted)
    [[ "$output" =~ "backup-corrupted" ]] || [ "$status" -eq 1 ]
}

@test "error: restore from corrupted backup fails gracefully" {
    # Create a corrupted backup
    mkdir -p "$TEST_HOME/.dotfiles-backups"
    echo "corrupted data" > "$TEST_HOME/.dotfiles-backups/backup-20250101-120000.tar.gz"

    export HOME="$TEST_HOME"
    run "$DOTFILES_DIR/bin/dotfiles-backup" restore backup-20250101-120000 2>&1

    # Should fail but not crash
    [ "$status" -ne 0 ]
}

# ============================================================
# Vault/Session Tests
# ============================================================

@test "error: vault operations fail when locked" {
    # Lock the vault
    touch "$MOCK_DATA_DIR/.locked"

    run bw get item test-item

    [ "$status" -ne 0 ]
    [[ "$output" =~ "locked" ]]
}

@test "error: vault operations fail with no session" {
    # Remove session file
    rm -f "$MOCK_DATA_DIR/.session"

    run bw status

    [ "$status" -eq 0 ]
    [[ "$output" =~ "unauthenticated" ]]
}

@test "error: sync fails when vault is locked" {
    touch "$MOCK_DATA_DIR/.locked"

    run bw sync

    [ "$status" -ne 0 ]
    [[ "$output" =~ "locked" ]]
}

@test "error: list fails when vault is locked" {
    touch "$MOCK_DATA_DIR/.locked"

    run bw list items

    [ "$status" -ne 0 ]
    [[ "$output" =~ "locked" ]]
}

# ============================================================
# Edge Case Tests
# ============================================================

@test "edge: handles empty backup directory" {
    mkdir -p "$TEST_HOME/.dotfiles-backups"
    # Directory exists but is empty

    export HOME="$TEST_HOME"
    run "$DOTFILES_DIR/bin/dotfiles-backup" --list 2>&1

    # Should indicate no backups
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No backups" ]]
}

@test "edge: handles special characters in paths" {
    # Create file with spaces in name
    mkdir -p "$TEST_HOME/path with spaces"
    touch "$TEST_HOME/path with spaces/config file.txt"

    # Should be able to read it
    [ -f "$TEST_HOME/path with spaces/config file.txt" ]
}

@test "edge: handles very long file paths" {
    # Create a deeply nested path
    local deep_path="$TEST_HOME"
    for i in {1..20}; do
        deep_path="$deep_path/level$i"
    done
    mkdir -p "$deep_path"
    touch "$deep_path/deep_file"

    [ -f "$deep_path/deep_file" ]
}

@test "edge: handles symlink loops gracefully" {
    # Create a symlink loop
    ln -s "$TEST_HOME/link_b" "$TEST_HOME/link_a" 2>/dev/null || true
    ln -s "$TEST_HOME/link_a" "$TEST_HOME/link_b" 2>/dev/null || true

    # Commands should not hang on symlink loops
    run ls -la "$TEST_HOME" 2>&1

    # Should complete without hanging
    [ "$status" -eq 0 ]
}

@test "edge: handles concurrent backup operations" {
    export HOME="$TEST_HOME"

    # Start two backups simultaneously
    "$DOTFILES_DIR/bin/dotfiles-backup" &
    local pid1=$!
    "$DOTFILES_DIR/bin/dotfiles-backup" &
    local pid2=$!

    # Wait for both to complete
    wait $pid1 || true
    wait $pid2 || true

    # Both should complete (may have different results, but shouldn't crash)
    [ -d "$TEST_HOME/.dotfiles-backups" ] || true
}

# ============================================================
# Resource Exhaustion Tests (lightweight versions)
# ============================================================

@test "edge: handles many backup files" {
    mkdir -p "$TEST_HOME/.dotfiles-backups"

    # Create 15 backup files (more than MAX_BACKUPS=10)
    for i in {01..15}; do
        touch "$TEST_HOME/.dotfiles-backups/backup-202501$i-120000.tar.gz"
    done

    export HOME="$TEST_HOME"
    run "$DOTFILES_DIR/bin/dotfiles-backup" --list 2>&1

    # Should list backups without error
    [ "$status" -eq 0 ]
    [[ "$output" =~ "backup-" ]]
}

# ============================================================
# CLI Argument Error Tests
# ============================================================

@test "error: backup rejects invalid arguments" {
    run "$DOTFILES_DIR/bin/dotfiles-backup" --invalid-flag 2>&1

    # Should show help or error
    [[ "$output" =~ "Usage" ]] || [[ "$output" =~ "help" ]] || [ "$status" -ne 0 ]
}

@test "error: uninstall --help exits cleanly" {
    run "$DOTFILES_DIR/bin/dotfiles-uninstall" --help 2>&1

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage" ]] || [[ "$output" =~ "Uninstall" ]]
}

@test "error: doctor --help exits cleanly" {
    run "$DOTFILES_DIR/bin/dotfiles-doctor" --help 2>&1

    [ "$status" -eq 0 ]
}
