#!/usr/bin/env zsh
# ============================================================
# Test script for lib/_progress.sh
# Run: zsh test/test_progress.sh
# ============================================================

# Get directory paths
SCRIPT_DIR="${0:A:h}"
DOTFILES_DIR="${SCRIPT_DIR:h}"

# Source the progress library
source "$DOTFILES_DIR/lib/_progress.sh"

# Set up cleanup trap
trap 'progress_cleanup' EXIT INT TERM

echo "=============================================="
echo "Progress Indicator Test Suite"
echo "=============================================="
echo ""

# ============================================================
# Test 1: Spinner
# ============================================================
echo "Test 1: Spinner (3 seconds)"
echo "  You should see an animated spinner..."
spinner_start "Processing data"
sleep 3
spinner_stop "Data processed successfully"
echo ""

# ============================================================
# Test 2: Spinner with early stop
# ============================================================
echo "Test 2: Spinner with quick stop (1 second)"
spinner_start "Quick operation"
sleep 1
spinner_stop
echo "  Spinner stopped (no message)"
echo ""

# ============================================================
# Test 3: Progress bar - basic
# ============================================================
echo "Test 3: Progress bar (10 items)"
echo "  You should see a filling progress bar..."
progress_init
for i in {1..10}; do
    progress_bar $i 10 "Item $i of 10"
    sleep 0.3
done
progress_done "Processed 10 items"
echo ""

# ============================================================
# Test 4: Progress bar with ETA
# ============================================================
echo "Test 4: Progress bar with ETA (5 items, slower)"
echo "  You should see ETA countdown..."
progress_init
for i in {1..5}; do
    progress_bar $i 5 "Processing"
    sleep 1
done
progress_done "Completed with ETA tracking"
echo ""

# ============================================================
# Test 5: Stepped progress
# ============================================================
echo "Test 5: Stepped progress (3 phases)"
steps_init 3 "Installation"

step "Downloading packages"
sleep 0.5
step_done "Downloaded 5 packages"

step "Installing dependencies"
sleep 0.5
step_done "Installed 12 dependencies"

step "Configuring system"
sleep 0.5
step_done "Configuration complete"

steps_done "Installation complete"
echo ""

# ============================================================
# Test 6: run_with_spinner helper
# ============================================================
echo "Test 6: run_with_spinner helper"
echo "  Running 'sleep 2' with spinner..."
run_with_spinner "Sleeping for 2 seconds" sleep 2
echo "  Command completed"
echo ""

# ============================================================
# Test 7: Progress bar edge cases
# ============================================================
echo "Test 7: Edge cases"

echo "  7a: 0% progress"
progress_bar 0 10 "Starting"
echo ""

echo "  7b: 100% progress"
progress_bar 10 10 "Complete"
echo ""

echo "  7c: Over 100% (should cap at 100%)"
progress_bar 15 10 "Overflow test"
echo ""

echo "  7d: Zero total (should not crash)"
progress_bar 5 0 "Zero total"
echo ""

# ============================================================
# Test 8: ASCII mode
# ============================================================
echo ""
echo "Test 8: ASCII mode (unicode disabled)"
DOTFILES_UNICODE=false

progress_init
for i in {1..5}; do
    progress_bar $i 5 "ASCII mode"
    sleep 0.2
done
progress_done "ASCII mode complete"

# Reset
DOTFILES_UNICODE=true
echo ""

# ============================================================
# Test 9: Long labels
# ============================================================
echo "Test 9: Long labels"
progress_init
progress_bar 5 10 "This is a very long label that describes what we are doing in great detail"
echo ""
progress_done "Long label test complete"
echo ""

# ============================================================
# Summary
# ============================================================
echo "=============================================="
echo "All tests completed!"
echo ""
echo "Manual verification checklist:"
echo "  [ ] Spinner animated smoothly"
echo "  [ ] Progress bar filled left to right"
echo "  [ ] ETA displayed and counted down"
echo "  [ ] Stepped progress showed [1/3], [2/3], [3/3]"
echo "  [ ] Cursor is visible at the end"
echo "  [ ] No visual artifacts or leftover characters"
echo "=============================================="
