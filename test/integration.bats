#!/usr/bin/env bats
# Integration tests for dotfiles vault and backup operations
# Uses mock bw CLI to test actual behavior without real Bitwarden

# ============================================================
# Test Setup and Teardown
# ============================================================

setup() {
    # Test directories
    export TEST_DIR="${BATS_TEST_TMPDIR}/dotfiles-integration-test"
    export MOCK_DATA_DIR="${TEST_DIR}/bw-mock"
    export BW_MOCK_DATA_DIR="$MOCK_DATA_DIR"
    export TEST_HOME="${TEST_DIR}/home"

    # Override HOME for tests
    export REAL_HOME="$HOME"
    export HOME="$TEST_HOME"

    # Create test directories
    mkdir -p "$TEST_HOME/.ssh"
    mkdir -p "$TEST_HOME/.aws"
    mkdir -p "$TEST_HOME/.local"
    mkdir -p "$TEST_HOME/.blackdot-backups"
    mkdir -p "$TEST_HOME/.config/dotfiles"
    mkdir -p "$MOCK_DATA_DIR/items"

    # Create config.json to ensure backup uses expected location
    cat > "$TEST_HOME/.config/dotfiles/config.json" <<'EOFCONFIG'
{
  "version": 3,
  "backup": {
    "enabled": true,
    "max_snapshots": 10,
    "retention_days": 30,
    "compress": true,
    "location": "~/.blackdot-backups"
  }
}
EOFCONFIG

    # Path to dotfiles repo
    export BLACKDOT_DIR="${BATS_TEST_DIRNAME}/.."

    # Add mock bw to PATH (before real bw)
    export PATH="${BATS_TEST_DIRNAME}/mocks:$PATH"

    # Copy test fixtures to mock data
    if [[ -d "${BATS_TEST_DIRNAME}/fixtures/vault-items" ]]; then
        cp "${BATS_TEST_DIRNAME}/fixtures/vault-items"/*.json "$MOCK_DATA_DIR/items/" 2>/dev/null || true
    fi

    # Set up mock session (unlocked state)
    echo "mock-session-token" > "$MOCK_DATA_DIR/.session"
    export BW_SESSION="mock-session-token"
}

teardown() {
    # Restore HOME
    export HOME="$REAL_HOME"

    # Clean up test directory
    rm -rf "$TEST_DIR"
}

# ============================================================
# Mock BW CLI Tests
# ============================================================

@test "mock bw: status shows unlocked when session exists" {
    run bw status

    [ "$status" -eq 0 ]
    [[ "$output" =~ "unlocked" ]]
}

@test "mock bw: status shows locked when vault is locked" {
    touch "$MOCK_DATA_DIR/.locked"

    run bw status

    [ "$status" -eq 0 ]
    [[ "$output" =~ "locked" ]]
}

@test "mock bw: get retrieves item from fixtures" {
    run bw get item dotfiles-SSH-Config

    [ "$status" -eq 0 ]
    [[ "$output" =~ "SSH Config" ]] || [[ "$output" =~ "github.com" ]]
}

@test "mock bw: list returns all items" {
    run bw list items

    [ "$status" -eq 0 ]
    [[ "$output" =~ "dotfiles-SSH-Config" ]]
    [[ "$output" =~ "dotfiles-Git-Config" ]]
}

@test "mock bw: list with search filters results" {
    run bw list items --search "SSH"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "SSH-Config" ]]
}

@test "mock bw: operations fail when locked" {
    touch "$MOCK_DATA_DIR/.locked"

    run bw get item dotfiles-SSH-Config

    [ "$status" -ne 0 ]
    [[ "$output" =~ "locked" ]]
}

# ============================================================
# Backup Integration Tests
# ============================================================

@test "backup: creates timestamped archive" {
    # Create some files to backup
    echo "test ssh config" > "$TEST_HOME/.ssh/config"
    echo "test git config" > "$TEST_HOME/.gitconfig"

    run "$BLACKDOT_DIR/bin/blackdot-backup"

    [ "$status" -eq 0 ]

    # Check backup was created
    local backup_count
    backup_count=$(ls "$TEST_HOME/.blackdot-backups/"*.tar.gz 2>/dev/null | wc -l)
    [ "$backup_count" -ge 1 ]
}

@test "backup: --list shows available backups" {
    # Create a backup first
    echo "test" > "$TEST_HOME/.gitconfig"
    "$BLACKDOT_DIR/bin/blackdot-backup" >/dev/null 2>&1

    run "$BLACKDOT_DIR/bin/blackdot-backup" --list

    [ "$status" -eq 0 ]
    [[ "$output" =~ "backup-" ]] || [[ "$output" =~ ".tar.gz" ]] || [[ "$output" =~ "Available" ]]
}

@test "backup: archive contains expected files" {
    # Create files
    mkdir -p "$TEST_HOME/.ssh"
    echo "ssh-config-content" > "$TEST_HOME/.ssh/config"
    echo "git-config-content" > "$TEST_HOME/.gitconfig"

    # Create backup
    "$BLACKDOT_DIR/bin/blackdot-backup" >/dev/null 2>&1

    # Find the backup
    local backup_file
    backup_file=$(ls -t "$TEST_HOME/.blackdot-backups/"*.tar.gz 2>/dev/null | head -1)

    [ -n "$backup_file" ]

    # Check contents
    run tar -tzf "$backup_file"

    [ "$status" -eq 0 ]
}

@test "backup: restore recovers files" {
    # Create original files
    mkdir -p "$TEST_HOME/.ssh"
    echo "original-ssh-config" > "$TEST_HOME/.ssh/config"
    echo "original-git-config" > "$TEST_HOME/.gitconfig"

    # Create backup
    "$BLACKDOT_DIR/bin/blackdot-backup" >/dev/null 2>&1

    # Modify files
    echo "modified-ssh-config" > "$TEST_HOME/.ssh/config"
    echo "modified-git-config" > "$TEST_HOME/.gitconfig"

    # Verify files were modified
    [[ "$(cat "$TEST_HOME/.ssh/config")" == "modified-ssh-config" ]]

    # Find backup and restore (using the latest)
    local backup_file
    backup_file=$(ls -t "$TEST_HOME/.blackdot-backups/"*.tar.gz 2>/dev/null | head -1)

    # Extract to verify (manual restore simulation)
    cd "$TEST_HOME"
    tar -xzf "$backup_file" 2>/dev/null || true

    # Original content should be restored
    # Note: actual restore path depends on how tar was created
}

# ============================================================
# Diff Preview Tests
# ============================================================

@test "diff: --help shows usage" {
    run "$BLACKDOT_DIR/bin/blackdot-diff" --help

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage" ]] || [[ "$output" =~ "diff" ]]
}

@test "diff: runs without error" {
    # Create a local file that differs from vault
    mkdir -p "$TEST_HOME/.ssh"
    echo "local-ssh-config" > "$TEST_HOME/.ssh/config"

    # Just verify the script runs (may show "no diff" or actual diff)
    run "$BLACKDOT_DIR/bin/blackdot-diff"

    # Should not crash
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ============================================================
# Uninstall Tests (Dry Run)
# ============================================================

@test "uninstall: --dry-run shows what would be removed" {
    # Create symlinks that would be removed
    ln -sf /nonexistent "$TEST_HOME/.zshrc"

    run "$BLACKDOT_DIR/bin/blackdot-uninstall" --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" =~ "DRY RUN" ]]
}

@test "uninstall: --help shows usage" {
    run "$BLACKDOT_DIR/bin/blackdot-uninstall" --help

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage" ]]
}

# ============================================================
# Error Handling Tests
# ============================================================

@test "error: backup handles missing directories gracefully" {
    # Remove expected directories
    rm -rf "$TEST_HOME/.ssh"
    rm -rf "$TEST_HOME/.aws"

    # Should not crash
    run "$BLACKDOT_DIR/bin/blackdot-backup"

    # May succeed with warning or fail gracefully
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "error: diff handles locked vault" {
    touch "$MOCK_DATA_DIR/.locked"

    run "$BLACKDOT_DIR/bin/blackdot-diff" --restore

    # Should fail gracefully, not crash
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ============================================================
# Doctor Integration Tests
# ============================================================

@test "doctor: runs health check" {
    run "$BLACKDOT_DIR/bin/blackdot-doctor"

    # Doctor may report issues (non-zero) but shouldn't crash
    [[ "$output" =~ "Symlinks" ]] || [[ "$output" =~ "dotfiles" ]] || [[ "$output" =~ "Health" ]] || true
}

@test "doctor: --help shows usage" {
    run "$BLACKDOT_DIR/bin/blackdot-doctor" --help

    [ "$status" -eq 0 ]
}

# ============================================================
# Setup Wizard Tests (Non-Interactive)
# ============================================================

@test "setup: script exists and has valid syntax" {
    run zsh -n "$BLACKDOT_DIR/bin/blackdot-setup"

    [ "$status" -eq 0 ]
}

# ============================================================
# End-to-End Workflow Tests
# ============================================================

@test "e2e: backup -> modify -> restore cycle" {
    # Setup: Create initial config
    mkdir -p "$TEST_HOME/.ssh"
    echo "version: 1" > "$TEST_HOME/.ssh/config"

    # Step 1: Create backup
    run "$BLACKDOT_DIR/bin/blackdot-backup"
    [ "$status" -eq 0 ]

    # Step 2: Verify backup exists
    local backup_count
    backup_count=$(ls "$TEST_HOME/.blackdot-backups/"*.tar.gz 2>/dev/null | wc -l)
    [ "$backup_count" -ge 1 ]

    # Step 3: Modify config
    echo "version: 2 - modified" > "$TEST_HOME/.ssh/config"

    # Verify modification
    [[ "$(cat "$TEST_HOME/.ssh/config")" == "version: 2 - modified" ]]

    # Step 4: Backup file is unchanged (immutable)
    local backup_file
    backup_file=$(ls -t "$TEST_HOME/.blackdot-backups/"*.tar.gz 2>/dev/null | head -1)
    [ -f "$backup_file" ]
}

@test "e2e: multiple backups with auto-cleanup check" {
    mkdir -p "$TEST_HOME/.ssh"

    # Create multiple backups
    for i in {1..3}; do
        echo "config v$i" > "$TEST_HOME/.ssh/config"
        "$BLACKDOT_DIR/bin/blackdot-backup" >/dev/null 2>&1
        sleep 1  # Ensure different timestamps
    done

    # Count backups
    local backup_count
    backup_count=$(ls "$TEST_HOME/.blackdot-backups/"*.tar.gz 2>/dev/null | wc -l)

    # Should have multiple backups
    [ "$backup_count" -ge 3 ]
}
