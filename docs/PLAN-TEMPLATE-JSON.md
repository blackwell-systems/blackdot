# Template System Enhancement: JSON Support

> **Status:** Planning
> **Goal:** Add JSON configuration support alongside existing shell format

---

## Problem Statement

The current shell-based array syntax is awkward:

```zsh
# Hard to read, easy to mess up field order
SSH_HOSTS=(
    "github|github.com|git|~/.ssh/id_ed25519|"
    "work|server.company.com|deploy|~/.ssh/id_work|ProxyJump bastion"
)
```

JSON would be much cleaner:

```json
{
  "ssh_hosts": [
    {
      "name": "github",
      "hostname": "github.com",
      "user": "git",
      "identity": "~/.ssh/id_ed25519"
    }
  ]
}
```

**Constraint:** No new dependencies. jq is already required for the vault system.

---

## Design Options

### Option A: JSON-First (All or Nothing)

```
If _config.local.json exists → use JSON only
Else → use shell files (current behavior)
```

**Pros:** Simple, clear precedence
**Cons:** Can't mix formats, migration is all-or-nothing

### Option B: Hybrid (Shell for Vars, JSON for Arrays)

```
Variables: _variables.local.sh (shell)
Arrays:    _arrays.local.json (JSON)
```

**Pros:** Right tool for each job, comments for vars, structure for arrays
**Cons:** Two files to manage

### Option C: Full Parallel (Both Everywhere)

```
Load order:
1. _variables.sh (shell defaults)
2. _variables.local.sh (shell overrides)
3. _config.local.json (JSON overrides - highest priority)
```

**Pros:** Maximum flexibility
**Cons:** Complex precedence, potential confusion

---

## Recommended Approach: Option B (Hybrid)

Use shell for simple variables (where comments help):
```zsh
# _variables.local.sh
TMPL_DEFAULTS[git_name]="John Doe"
TMPL_DEFAULTS[git_email]="john@example.com"
# GPG key for commit signing
TMPL_DEFAULTS[git_signing_key]="ABC123"
```

Use JSON for structured arrays (where clarity matters):
```json
// _arrays.local.json
{
  "ssh_hosts": [
    {
      "name": "github",
      "hostname": "github.com",
      "user": "git",
      "identity": "~/.ssh/id_ed25519"
    },
    {
      "name": "work-server",
      "hostname": "server.company.com",
      "user": "deploy",
      "identity": "~/.ssh/id_work",
      "extra": "ProxyJump bastion"
    }
  ]
}
```

---

## Implementation Plan

### Phase 1: JSON Array Loading

Update `load_template_arrays()` in `lib/_templates.sh`:

```zsh
load_template_arrays() {
    local json_file="${TEMPLATES_DIR}/_arrays.local.json"

    # Priority 1: JSON file (if exists)
    if [[ -f "$json_file" ]] && command -v jq &>/dev/null; then
        debug "Loading arrays from JSON: $json_file"

        # Load ssh_hosts array
        if jq -e '.ssh_hosts' "$json_file" &>/dev/null; then
            local items
            items=$(jq -r '.ssh_hosts[] | "\(.name)|\(.hostname)|\(.user)|\(.identity // "")|\(.extra // "")"' "$json_file")
            TMPL_ARRAYS_ssh_hosts=("${(@f)items}")
            debug "Loaded ${#TMPL_ARRAYS_ssh_hosts[@]} SSH hosts from JSON"
        fi

        return 0
    fi

    # Priority 2: Shell arrays (fallback)
    if (( ${#SSH_HOSTS[@]} > 0 )); then
        TMPL_ARRAYS_ssh_hosts=("${SSH_HOSTS[@]}")
        debug "Loaded ${#TMPL_ARRAYS_ssh_hosts[@]} SSH hosts from shell"
    fi
}
```

### Phase 2: JSON Schema Validation

Create `templates/_arrays.schema.json` for validation:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "ssh_hosts": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["name", "hostname", "user"],
        "properties": {
          "name": { "type": "string" },
          "hostname": { "type": "string" },
          "user": { "type": "string" },
          "identity": { "type": "string" },
          "extra": { "type": "string" }
        }
      }
    }
  }
}
```

Validate on load:
```zsh
if ! jq -e '.' "$json_file" &>/dev/null; then
    fail "Invalid JSON in $json_file"
    return 1
fi
```

### Phase 3: Template CLI Support

Add `dotfiles template arrays` command:

```bash
# Show arrays from active source (JSON or shell)
dotfiles template arrays

# Validate JSON arrays file
dotfiles template arrays --validate

# Convert shell arrays to JSON (migration helper)
dotfiles template arrays --export-json > _arrays.local.json
```

### Phase 4: Documentation

Update `docs/templates.md`:
- Add "JSON Arrays" section
- Show both formats side-by-side
- Explain precedence (JSON > shell)
- Migration guide

---

## File Structure (After Implementation)

```
templates/
├── _variables.sh              # Default variables (shell)
├── _variables.local.sh        # User variables (shell, gitignored)
├── _variables.local.sh.example
├── _arrays.local.json         # User arrays (JSON, gitignored) ← NEW
├── _arrays.local.json.example # Example JSON arrays ← NEW
├── _arrays.schema.json        # JSON schema for validation ← NEW
└── configs/
    └── *.tmpl
```

---

## Precedence Rules

### Variables
1. Environment (`DOTFILES_TMPL_*`) - highest
2. `_variables.local.sh` (user)
3. Machine-type (`TMPL_WORK` / `TMPL_PERSONAL`)
4. `_variables.sh` (defaults)
5. Auto-detected - lowest

### Arrays
1. `_arrays.local.json` (if exists) - highest
2. Shell arrays in `_variables.local.sh` (fallback)
3. Shell arrays in `_variables.sh` (defaults) - lowest

---

## Migration Path

### For Existing Users

No action required - shell arrays continue to work.

### To Adopt JSON

1. Create `_arrays.local.json`:
   ```json
   {
     "ssh_hosts": [
       {"name": "github", "hostname": "github.com", "user": "git", "identity": "~/.ssh/id_ed25519"}
     ]
   }
   ```

2. Remove `SSH_HOSTS` from `_variables.local.sh` (optional - JSON takes precedence)

3. Run `dotfiles template render`

### Auto-Migration Helper

```bash
# Export current shell arrays to JSON
dotfiles template arrays --export-json > templates/_arrays.local.json

# Then remove SSH_HOSTS from _variables.local.sh
```

---

## Future Extensions

### More Array Types

```json
{
  "ssh_hosts": [...],
  "git_includes": [
    {"path": "~/.gitconfig-work", "condition": "gitdir:~/work/"}
  ],
  "path_aliases": [
    {"name": "ws", "path": "~/workspace"},
    {"name": "dots", "path": "~/.dotfiles"}
  ]
}
```

### Full JSON Config (Optional Future)

If users want everything in JSON:

```json
{
  "defaults": {
    "git_name": "John Doe",
    "git_email": "john@example.com"
  },
  "work": {
    "git_email": "john@company.com"
  },
  "personal": {
    "git_email": "john@personal.com"
  },
  "ssh_hosts": [...]
}
```

This would be opt-in and wouldn't replace shell support.

---

## Checklist

- [ ] Implement `load_template_arrays()` JSON support
- [ ] Create `_arrays.local.json.example`
- [ ] Create `_arrays.schema.json`
- [ ] Add `dotfiles template arrays` command
- [ ] Add JSON validation on load
- [ ] Update `docs/templates.md`
- [ ] Update `docs/CHANGELOG.md`
- [ ] Add tests for JSON array loading
- [ ] Create migration helper (`--export-json`)

---

## Questions to Resolve

1. **Should JSON completely replace shell, or always be additive?**
   - Recommendation: JSON takes precedence, shell is fallback

2. **Should we support comments in JSON?**
   - Standard JSON: No
   - Could strip `//` comments before parsing (simple regex)
   - Or just accept no comments (JSON is self-documenting with good field names)

3. **What if both JSON and shell define the same array?**
   - Recommendation: JSON wins (don't merge)

---

**Document Status:** Planning
**Owner:** Blackwell Systems Team
