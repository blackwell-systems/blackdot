# Go vs Bash CLI Parity Audit

> **Date:** 2025-12-07
> **Auditor:** Claude
> **Status:** Complete

---

## 1. Command Inventory

### Bash Commands (bin/dotfiles-*)

| Command | Go Version | Status |
|---------|------------|--------|
| `dotfiles-backup` | ✅ | Full parity |
| `dotfiles-config` | ⚠️ | 5/8 subcommands |
| `dotfiles-diff` | ✅ | Full parity |
| `dotfiles-doctor` | ✅ | Full parity |
| `dotfiles-drift` | ✅ | Full parity |
| `dotfiles-encrypt` | ✅ | Full parity |
| `dotfiles-features` | ✅ | Full parity |
| `dotfiles-go` | ⊘ | Wrapper - not needed |
| `dotfiles-hook` | ✅ | Full parity + enhancements |
| `dotfiles-lint` | ✅ | Full parity |
| `dotfiles-metrics` | ✅ | Full parity |
| `dotfiles-migrate` | ⊘ | Dropped (one-time v2→v3) |
| `dotfiles-migrate-config` | ⊘ | Dropped (helper) |
| `dotfiles-migrate-vault-schema` | ⊘ | Dropped (helper) |
| `dotfiles-packages` | ✅ | Full parity |
| `dotfiles-setup` | ✅ | Full parity |
| `dotfiles-sync` | ✅ | Full parity |
| `dotfiles-template` | ⚠️ | 6/11 subcommands |
| `dotfiles-uninstall` | ✅ | Full parity |
| `dotfiles-vault` | ⚠️ | 8/13 subcommands |

### Go-Only Commands (Enhancements)

| Command | Description |
|---------|-------------|
| `status` | Visual dashboard - NEW |
| `version` | Build info - NEW |

---

## 2. Detailed Flag/Subcommand Comparison

### Full Parity Commands (13)

| Command | Notes |
|---------|-------|
| `backup` | Go uses explicit subcommands (create, list, restore, clean) |
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
| `uninstall` | Flags: `--dry-run/-n`, `--keep-secrets/-k` |

### Partial Parity Commands (3)

#### config (5/8 subcommands)

| Subcommand | Go | Description |
|------------|-----|-------------|
| `get` | ✅ | Get config value |
| `set` | ✅ | Set config value |
| `show` | ✅ | Show value from all layers |
| `list` | ✅ | Show layer status |
| `merged` | ✅ | Show merged config |
| `source` | ❌ | Get value with source info (JSON) |
| `init` | ❌ | Initialize a config layer |
| `edit` | ❌ | Edit config file in $EDITOR |

#### template (6/11 subcommands)

| Subcommand | Go | Description |
|------------|-----|-------------|
| `init` | ✅ | Interactive setup |
| `render` | ✅ | Render templates |
| `diff` | ✅ | Show differences |
| `vars` | ✅ | List variables |
| `link` | ✅ | Create symlinks |
| `list` | ✅ | Show available templates |
| `check` | ❌ | Validate template syntax |
| `filters` | ❌ | List available filters |
| `edit` | ❌ | Open in $EDITOR |
| `arrays` | ❌ | Manage JSON/shell arrays |
| `vault` | ❌ | Sync variables with vault |

#### vault (8/13 subcommands)

| Subcommand | Go | Description |
|------------|-----|-------------|
| `unlock` | ✅ | Unlock vault |
| `lock` | ✅ | Lock vault |
| `status` | ✅ | Show vault status |
| `list` | ✅ | List vault items |
| `get` | ✅ | Get a vault item (Go only) |
| `sync` | ✅ | Sync vault |
| `backend` | ✅ | Show/set backend |
| `health` | ✅ | Health check (Go only) |
| `quick` | ❌ | Quick status check |
| `restore` | ❌ | Restore secrets from vault |
| `push` | ❌ | Push secrets to vault |
| `scan` | ❌ | Scan for local secrets |
| `check` | ❌ | Check vault items exist |
| `validate` | ❌ | Validate schema |
| `init` | ❌ | Initialize vault setup |

---

## 3. Parity Score

### Command-Level
- Full parity: **13/16 (81%)**
- Partial parity: **3/16 (19%)**

### Subcommand-Level
- config: **5/8 (62%)**
- template: **6/11 (55%)**
- vault: **8/13 (62%)**
- Total missing: **15 subcommands**

---

## 4. Recommendations

### Priority 1 - Critical for Full Replacement
These are needed before Go can fully replace bash:

| Subcommand | Reason |
|------------|--------|
| `vault restore` | Users need this to pull secrets on new machines |
| `vault push` | Users need this to backup secrets |
| `vault init` | First-time vault setup |

### Priority 2 - Useful but Can Fallback
These improve UX but bash fallback works:

| Subcommand | Reason |
|------------|--------|
| `config edit` | Convenience - can use $EDITOR directly |
| `config init` | Can create machine.json manually |
| `template edit` | Convenience - can use $EDITOR directly |
| `template check` | Syntax validation (render catches errors) |
| `vault validate` | Schema validation (sync checks this) |

### Priority 3 - Nice to Have
These are optional enhancements:

| Subcommand | Reason |
|------------|--------|
| `config source` | Debug tool - shows where config comes from |
| `vault quick` | Faster status check (status works fine) |
| `vault scan` | Secret discovery (manual is fine) |
| `vault check` | Item existence (restore catches this) |
| `template filters` | Reference doc (can use help text) |
| `template arrays` | Array management (can edit JSON) |
| `template vault` | Variable sync (can use vault restore/push) |

---

## 5. Action Items

### Immediate (to claim "full parity")
- [ ] Implement `vault restore`
- [ ] Implement `vault push`
- [ ] Implement `vault init`

### Before Deprecating Bash
- [ ] Implement `config edit`
- [ ] Implement `template check`
- [ ] Add `vault validate`

### Optional Enhancements
- [ ] `config source` (debugging)
- [ ] `vault quick` (performance)
- [ ] `template filters` (documentation)

---

## 6. Conclusion

The Go CLI has achieved **81% command-level parity** with the bash implementation. All daily-use commands have full parity. The remaining gaps are primarily in advanced vault and template management features that can fall back to bash if needed.

**Recommended next step:** Implement `vault restore`, `vault push`, and `vault init` to enable full standalone Go operation.
