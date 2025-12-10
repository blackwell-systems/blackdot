# Go vs Bash CLI Parity Audit

> **Date:** 2025-12-08
> **Auditor:** Claude
> **Status:** COMPLETE - Full Parity Achieved

---

## 1. Command Inventory

### Bash Commands (bin/blackdot-*)

| Command | Go Version | Status |
|---------|------------|--------|
| `blackdot-backup` | ✅ | Full parity |
| `blackdot-config` | ✅ | Full parity (8/8 subcommands) |
| `blackdot-diff` | ✅ | Full parity |
| `blackdot-doctor` | ✅ | Full parity |
| `blackdot-drift` | ✅ | Full parity |
| `blackdot-encrypt` | ✅ | Full parity |
| `blackdot-features` | ✅ | Full parity |
| `blackdot-go` | ⊘ | Wrapper - not needed |
| `blackdot-hook` | ✅ | Full parity + enhancements |
| `blackdot-lint` | ✅ | Full parity |
| `blackdot-metrics` | ✅ | Full parity |
| `blackdot-migrate` | ⊘ | Dropped (one-time v2→v3) |
| `blackdot-migrate-config` | ⊘ | Dropped (helper) |
| `blackdot-migrate-vault-schema` | ⊘ | Dropped (helper) |
| `blackdot-packages` | ✅ | Full parity |
| `blackdot-setup` | ✅ | Full parity |
| `blackdot-sync` | ✅ | Full parity |
| `blackdot-template` | ✅ | Full parity (11/11 subcommands) |
| `blackdot-uninstall` | ✅ | Full parity |
| `blackdot-vault` | ✅ | Full parity (15/15 subcommands) |

### Go-Only Commands (Enhancements)

| Command | Description |
|---------|-------------|
| `status` | Visual dashboard - NEW |
| `version` | Build info - NEW |
| `tools` | Cross-platform developer tools - NEW |
| `import-chezmoi` | Migrate from chezmoi - NEW |

### Tools Subcommands (Cross-Platform)

| Tool Category | Commands |
|---------------|----------|
| `tools ssh` | keys, gen, list, agent, fp, copy, tunnel, socks, status |
| `tools aws` | profiles, who, login, switch, assume, clear, status |
| `tools cdk` | init, env, env-clear, outputs, context, status |
| `tools go` | new, init, test, cover, lint, outdated, update, build-all, bench, info |
| `tools rust` | new, update, switch, lint, fix, outdated, expand, info |
| `tools python` | new, clean, venv, test, cover, info |
| `tools docker` | ps, images, ip, env, ports, stats, vols, nets, inspect, clean, prune, status |
| `tools claude` | status, bedrock, max, switch, init, env |

**Total:** 8 tool categories, 50+ subcommands

---

## 2. Detailed Flag/Subcommand Comparison

### Full Parity Commands (16)

All commands now have full parity with their bash counterparts.

| Command | Notes |
|---------|-------|
| `backup` | Go uses explicit subcommands (create, list, restore, clean) |
| `config` | All 8 subcommands implemented |
| `diff` | Flags: `--sync/-s`, `--restore/-r` |
| `doctor` | Flags: `--fix/-f`, `--quick/-q` |
| `drift` | Flags: `--quick/-q` |
| `encrypt` | Go uses `file` instead of `encrypt` subcommand |
| `features` | Go uses `show` instead of `status` subcommand |
| `hook` | Go adds `--timeout`, `--fail-fast` |
| `lint` | Flags: `--fix/-f`, `--verbose/-v` |
| `metrics` | Flags: `--graph/-g`, `--all/-a` |
| `packages` | Flags: `--check/-c`, `--install/-i`, `--outdated/-o`, `--tier/-t` |
| `setup` | Flags: `--status/-s`, `--reset/-r` |
| `sync` | Flags: `--dry-run/-n`, `--force-local/-l`, `--force-vault/-v`, `--verbose`, `--all/-a` |
| `template` | All 11 subcommands implemented including vault sync |
| `uninstall` | Flags: `--dry-run/-n`, `--keep-secrets/-k` |
| `vault` | All 15 subcommands implemented |

---

## 3. Subcommand Details

### config (8/8 subcommands) ✅

| Subcommand | Go | Description |
|------------|-----|-------------|
| `get` | ✅ | Get config value with layer resolution |
| `set` | ✅ | Set config value in specific layer |
| `show` | ✅ | Show value from all layers |
| `list` | ✅ | Show layer status |
| `merged` | ✅ | Show merged config from all layers |
| `source` | ✅ | Get value with source info (JSON output) |
| `init` | ✅ | Initialize machine or project config |
| `edit` | ✅ | Edit config file in $EDITOR |

### template (11/11 subcommands) ✅

| Subcommand | Go | Description |
|------------|-----|-------------|
| `init` | ✅ | Interactive setup - creates _variables.local.sh |
| `render` | ✅ | Render templates to generated/ |
| `check` | ✅ | Validate template syntax |
| `diff` | ✅ | Show differences from rendered |
| `vars` | ✅ | List all variables |
| `filters` | ✅ | List available pipeline filters |
| `edit` | ✅ | Open _variables.local.sh in $EDITOR |
| `link` | ✅ | Create symlinks from generated/ |
| `list` | ✅ | Show available templates |
| `arrays` | ✅ | Manage JSON/shell arrays for {{#each}} |
| `vault` | ✅ | Sync variables with vault (push/pull/diff/sync/status) |

### vault (15/15 subcommands) ✅

| Subcommand | Go | Description |
|------------|-----|-------------|
| `unlock` | ✅ | Unlock vault |
| `lock` | ✅ | Lock vault |
| `status` | ✅ | Show vault status |
| `list` | ✅ | List vault items |
| `get` | ✅ | Get a vault item |
| `sync` | ✅ | Sync vault with remote |
| `backend` | ✅ | Show/set backend |
| `health` | ✅ | Health check |
| `quick` | ✅ | Quick status check (login/unlock only) |
| `restore` | ✅ | Restore secrets from vault (--force, --dry-run) |
| `push` | ✅ | Push secrets to vault (--force, --dry-run, --all) |
| `scan` | ✅ | Scan for local secrets to add |
| `check` | ✅ | Check required vault items exist |
| `validate` | ✅ | Validate vault-items.json schema |
| `init` | ✅ | Initialize vault setup wizard |

---

## 4. Parity Score

### Final Results
- **Command-Level Parity:** 16/16 (100%)
- **Subcommand-Level Parity:** 34/34 (100%)
- **All implementations are native Go** (no shell script delegation)

---

## 5. Implementation Summary

All 15 missing subcommands were implemented on 2025-12-08:

### Vault (7 new subcommands)
- `quick` - Native Go implementation for fast status check
- `restore` - Full restore with backup, permissions, dry-run support
- `push` - Push with sync comparison, create/update logic
- `scan` - Secret discovery scanning SSH, AWS, Git configs
- `check` - Verify required items exist in vault
- `validate` - JSON schema validation with detailed errors
- `init` - Interactive setup wizard with backend detection

### Config (3 new subcommands)
- `source` - Returns JSON with value and source layer
- `init` - Creates machine.json or .blackdot.json
- `edit` - Opens config in $EDITOR

### Template (5 new subcommands)
- `check` - Validates template syntax by test-rendering
- `filters` - Lists 16 available pipeline filters
- `edit` - Opens _variables.local.sh in $EDITOR
- `arrays` - Lists/validates JSON arrays for {{#each}}
- `vault` - Full sync with push/pull/diff/sync/status

---

## 6. Conclusion

The Go CLI has achieved **100% parity** with the bash implementation. All commands and subcommands are now available in Go with native implementations. The Go CLI can now fully replace the bash implementation for all use cases.

**Key achievements:**
- All vault operations work without shell delegation
- Config layering fully implemented (env > project > machine > user)
- Template vault sync for machine-portable configurations
- Native Go implementations for better portability and testing
