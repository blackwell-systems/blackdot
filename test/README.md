# Unit Tests

This directory contains unit tests for the blackdot repository, using [bats-core](https://github.com/bats-core/bats-core) (Bash Automated Testing System).

## Prerequisites

Install bats-core:

```bash
# macOS
brew install bats-core

# Linux (Ubuntu/Debian)
sudo apt-get install bats

# Or install from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

## Running Tests

```bash
# Run all tests
bats test/

# Run specific test file
bats test/vault_common.bats

# Run with verbose output
bats -t test/

# Run with timing information
bats --timing test/
```

## Test Structure

- **vault_common.bats** - Tests for `vault/_common.sh` functions
  - Data structure helpers (get_ssh_key_paths, get_required_items, etc.)
  - Path manipulation functions
  - Logging functions
  - Prerequisite checks (mocked)

## Writing Tests

Example test structure:

```bash
#!/usr/bin/env bats

setup() {
  # Load the script under test
  source "$(dirname "$BATS_TEST_DIRNAME")/vault/_common.sh"
}

@test "function_name returns expected output" {
  run function_name arg1 arg2
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "expected output" ]
}
```

## Coverage

Current test coverage:
- ✅ vault/_common.sh data structure helpers
- ✅ vault/_common.sh path functions
- ✅ vault/_common.sh logging functions
- ⏳ vault restoration scripts (future)
- ⏳ vault health check scripts (future)

## CI Integration

Tests are automatically run in GitHub Actions on every push:

```yaml
- name: Run unit tests
  run: bats test/
```
