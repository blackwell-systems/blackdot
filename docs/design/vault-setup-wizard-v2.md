# Vault Setup Wizard v2 - Design Document

> **Status**: Draft - Under Review
> **Author**: Claude + User
> **Date**: 2025-12-05

---

## Problem Statement

The current vault setup has a fundamental flaw: it assumes auto-discovery from local filenames will match existing vault item names. This causes confusion when:

1. Users have existing vault items with their own naming conventions
2. Users set up a new machine (no local files to discover)
3. Auto-generated names don't match what's actually in the vault

### Current Failure Mode

```
User's Bitwarden:              Auto-Discovery Generates:
─────────────────              ─────────────────────────
SSH-GitHub-Blackwell      ≠    SSH-Blackwell
SSH-GitHub-Enterprise     ≠    SSH-Enterprise_ghub

Result: "MISSING" errors, confused users
```

---

## Design Principles

1. **Not confusing** - Simple, clear UX with minimal decision points
2. **Respect existing structures** - Don't force naming conventions
3. **Educate upfront** - User understands the system before making choices
4. **User-directed** - They guide us to their data, we don't scan randomly
5. **Backend-agnostic** - Works the same conceptually across all backends

---

## Proposed Flow

### Phase 1: Education

Before asking ANY questions, explain how the system works:

```
╔══════════════════════════════════════════════════════════════════╗
║                  How Vault Storage Works                         ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  This system stores your secrets as individual items in your    ║
║  vault. Each file (SSH key, config) becomes one vault item.     ║
║                                                                  ║
║  ┌─────────────────┐         ┌─────────────────────┐            ║
║  │ Local Machine   │  sync   │ Your Vault          │            ║
║  ├─────────────────┤ ◄─────► ├─────────────────────┤            ║
║  │ ~/.ssh/key      │         │ "SSH-MyKey"         │            ║
║  │ ~/.aws/creds    │         │ "AWS-Credentials"   │            ║
║  │ ~/.gitconfig    │         │ "Git-Config"        │            ║
║  └─────────────────┘         └─────────────────────┘            ║
║                                                                  ║
║  Item names can be anything you choose.                         ║
║  We just need to know which vault item maps to which file.      ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### Phase 2: Determine Starting Point

One simple question to branch the flow:

```
? Do you have existing secrets in your vault you want to use?

  [e] Existing  - I already have items in my vault (import them)
  [f] Fresh     - I'm starting new, create items from my local files
  [m] Manual    - I'll configure everything myself later

Choice [e/f/m]:
```

This is the KEY decision point. Everything else flows from here.

---

## Flow A: Existing Vault Items (Import)

User has items already. We need to find them without invasive scanning.

### Step A1: Ask Where to Look (Backend-Specific)

```
═══════════════════════════════════════════════════════════════════

  Where are your dotfiles secrets stored in Bitwarden?

  Most users organize secrets in a folder or use a naming prefix.

  Examples:
    • Folder named "dotfiles" or "secrets"
    • Items starting with "SSH-", "AWS-", "Dotfiles-"
    • A specific collection (for teams)

═══════════════════════════════════════════════════════════════════

? How should we find your secrets?

  [1] By folder     - All items in a specific folder
  [2] By prefix     - Items matching a name pattern (e.g., SSH-*)
  [3] Let me list   - I'll type the item names directly

Choice [1]:
```

**Backend variations:**

| Backend    | Option 1        | Option 2           | Option 3      |
|------------|-----------------|--------------------| --------------|
| Bitwarden  | Folder          | Name prefix        | Manual list   |
| 1Password  | Vault           | Tag or prefix      | Manual list   |
| pass       | Directory path  | Path prefix        | Manual list   |

### Step A2: Show Found Items, Confirm

```
Found 4 items in folder "dotfiles":

  1. SSH-GitHub-Blackwell     (secure note, 2.1 KB)
  2. SSH-GitHub-Enterprise    (secure note, 1.8 KB)
  3. AWS-Credentials          (secure note, 843 B)
  4. SSH-Config               (secure note, 1.2 KB)

? Import these items? [Y/n]:
```

### Step A3: Map to Local Paths

For each item, ask where it should live locally:

```
For each item, specify where it should be saved locally.
Press Enter to accept the suggested path, or type a new path.

  SSH-GitHub-Blackwell
    This looks like an SSH key.
    → Local path [~/.ssh/id_ed25519]: ~/.ssh/id_ed25519_blackwell

  SSH-GitHub-Enterprise
    This looks like an SSH key.
    → Local path [~/.ssh/id_ed25519]: ~/.ssh/id_ed25519_enterprise

  AWS-Credentials
    This looks like AWS credentials.
    → Local path [~/.aws/credentials]: ↵ (accept default)

  SSH-Config
    This looks like SSH config.
    → Local path [~/.ssh/config]: ↵ (accept default)
```

### Step A4: Save Configuration

```
Configuration saved to: ~/.config/dotfiles/vault-items.json

  Vault location: folder "dotfiles" (Bitwarden)
  Items configured: 4

Next steps:
  • Pull secrets:  dotfiles vault pull
  • Check status:  dotfiles vault status
```

---

## Flow B: Fresh Start (Create)

User has local files but no vault items yet.

### Step B1: Ask Where to Store

```
═══════════════════════════════════════════════════════════════════

  Where should we store your secrets in Bitwarden?

  We recommend creating a dedicated folder to keep things organized.

═══════════════════════════════════════════════════════════════════

? Choose storage location:

  [1] Create new folder "dotfiles" (recommended)
  [2] Use existing folder: [select]
  [3] No folder (items at root level)

Choice [1]:
```

### Step B2: Scan Local Files

```
Scanning for secrets in standard locations...

  ~/.ssh/
    ✓ id_ed25519_blackwell    (SSH key)
    ✓ id_ed25519_enterprise   (SSH key)
    ✓ config                  (SSH config)

  ~/.aws/
    ✓ credentials             (AWS credentials)
    ✓ config                  (AWS config)

  ~/.gitconfig                (Git config)

Found 6 items.
```

### Step B3: Confirm Names

```
Each item needs a name in your vault.
We suggest names based on filenames. Edit if you prefer different names.

  id_ed25519_blackwell   → [SSH-Blackwell]: SSH-GitHub-Blackwell
  id_ed25519_enterprise  → [SSH-Enterprise]: SSH-GitHub-Enterprise
  config (ssh)           → [SSH-Config]: ↵
  credentials (aws)      → [AWS-Credentials]: ↵
  config (aws)           → [AWS-Config]: ↵
  .gitconfig             → [Git-Config]: ↵
```

### Step B4: Create Items

```
Creating items in Bitwarden folder "dotfiles"...

  ✓ SSH-GitHub-Blackwell     created
  ✓ SSH-GitHub-Enterprise    created
  ✓ SSH-Config               created
  ✓ AWS-Credentials          created
  ✓ AWS-Config               created
  ✓ Git-Config               created

Configuration saved to: ~/.config/dotfiles/vault-items.json

Done! Your secrets are now backed up to Bitwarden.
```

---

## Flow C: Manual Configuration

For advanced users who want full control.

```
Manual configuration selected.

A template has been created at:
  ~/.config/dotfiles/vault-items.json

Edit this file to define your vault items:
  $EDITOR ~/.config/dotfiles/vault-items.json

See the example file for reference:
  ~/dotfiles/vault/vault-items.example.json

When ready, run:
  dotfiles vault pull    # To restore from vault
  dotfiles vault push    # To backup to vault
```

---

## Configuration Schema Updates

### New Fields in vault-items.json

```json
{
  "$schema": "...",

  "vault_location": {
    "backend": "bitwarden",
    "type": "folder",
    "value": "dotfiles"
  },

  "ssh_keys": { ... },
  "vault_items": { ... },
  "syncable_items": { ... }
}
```

### Backend-Specific Location Types

```json
// Bitwarden
{ "type": "folder", "value": "dotfiles" }
{ "type": "prefix", "value": "SSH-" }
{ "type": "collection", "value": "uuid-here" }

// 1Password
{ "type": "vault", "value": "Dotfiles" }
{ "type": "tag", "value": "dotfiles" }

// pass
{ "type": "directory", "value": "dotfiles/" }
```

---

## Re-Run Behavior

When `dotfiles vault setup` is run with existing config:

```
Existing configuration found.

  Backend: Bitwarden
  Location: folder "dotfiles"
  Items: 6 configured

? What would you like to do?

  [1] Add new items   - Scan for items not yet configured
  [2] Reconfigure     - Start fresh (backs up current config)
  [3] Cancel          - Keep current configuration

Choice [1]:
```

---

## Error Handling

### No Items Found in Specified Location

```
No items found in folder "dotfiles".

This could mean:
  • The folder is empty (new setup)
  • Items are in a different location
  • Vault sync is needed

? What would you like to do?

  [1] Scan local files instead (create new items)
  [2] Try a different location
  [3] Cancel and troubleshoot

Choice:
```

### Backend Not Logged In

```
✗ Not logged in to Bitwarden.

Please log in first:
  bw login

Then run setup again:
  dotfiles vault setup
```

### Vault Locked

```
✗ Bitwarden vault is locked.

Please unlock:
  export BW_SESSION="$(bw unlock --raw)"

Then run setup again:
  dotfiles vault setup
```

---

## Implementation Notes

### Files to Modify

| File | Changes |
|------|---------|
| `vault/init-vault.sh` | Complete rewrite with new wizard flow |
| `vault/discover-secrets.sh` | Add `--from-vault` mode, respect location config |
| `lib/_vault.sh` | Add `vault_location` schema validation |
| `vault/vault-items.schema.json` | Add `vault_location` field |
| `vault/backends/*.sh` | Add `vault_backend_list_folders()` or equivalent |

### New Backend Interface Functions

Each backend needs to implement:

```zsh
# List available organizational units (folders/vaults/directories)
vault_backend_list_locations()

# List items in a specific location
vault_backend_list_items_in_location "$location_type" "$location_value"

# Create item in specific location
vault_backend_create_item_in_location "$name" "$content" "$location_type" "$location_value"
```

---

## Open Questions

1. **Should we support multiple locations?** (e.g., SSH keys in one folder, AWS in another)
   - Adds complexity, maybe v2.1?

2. **What about shared/team vaults?** (Bitwarden organizations, 1Password shared vaults)
   - Important but can be Phase 2

3. **Should location be optional?** (Some users might not want to use folders)
   - Yes, "prefix" and "manual list" options handle this

---

## Appendix: Current vs Proposed Comparison

| Aspect | Current | Proposed |
|--------|---------|----------|
| First question | "Auto-discover or manual?" | "Existing items or fresh start?" |
| Name source | Local filenames | User's existing names OR user-confirmed names |
| Location tracking | None | Stored in config |
| Re-run behavior | Potentially destructive | Safe with backup option |
| User agency | Low (we decide names) | High (they confirm everything) |

---

---

# Backend Implementation Plans

## Current State Analysis

| Backend | Location Concept | Current Implementation | Config Variable |
|---------|------------------|------------------------|-----------------|
| Bitwarden | Folders | Not used | None |
| 1Password | Vaults | `ONEPASSWORD_VAULT` (hardcoded "Personal") | Env var only |
| pass | Directories | `PASS_PREFIX` (default "dotfiles") | Env var only |

**Key Insight**: pass already implements the prefix/directory concept we want. We need to bring Bitwarden and 1Password to parity.

---

## Bitwarden Implementation

### Current Behavior
- No folder awareness
- Items searched globally by name
- Creates items at root level

### New Functions Needed

```zsh
# List available folders
vault_backend_list_locations() {
    bw list folders --session "$SESSION" | jq -r '.[].name'
}

# List items in a specific folder
vault_backend_list_items_in_location() {
    local folder_name="$1"
    local folder_id=$(bw list folders --session "$SESSION" | jq -r ".[] | select(.name == \"$folder_name\") | .id")
    bw list items --folderid "$folder_id" --session "$SESSION"
}

# Create item in specific folder
vault_backend_create_item_in_location() {
    local item_name="$1"
    local content="$2"
    local folder_name="$3"
    local folder_id=$(bw list folders --session "$SESSION" | jq -r ".[] | select(.name == \"$folder_name\") | .id")
    # Create with folderId in JSON template
}

# Create folder if doesn't exist
vault_backend_create_location() {
    local folder_name="$1"
    echo "{\"name\": \"$folder_name\"}" | bw encode | bw create folder --session "$SESSION"
}
```

### Location Types
```json
{ "type": "folder", "value": "dotfiles" }
{ "type": "prefix", "value": "SSH-" }  // Fallback: filter by name pattern
{ "type": "none", "value": null }      // Search all (legacy behavior)
```

### Breaking Changes
- None for existing users (backward compatible)
- New config field `vault_location` is optional

### Migration Path
1. Existing users without `vault_location` → continue global search
2. New users → wizard sets `vault_location`
3. Existing users can run `dotfiles vault setup` to add folder organization

---

## 1Password Implementation

### Current Behavior
- Uses `ONEPASSWORD_VAULT` env var (defaults to "Personal")
- All items in one vault
- No tag support

### New Functions Needed

```zsh
# List available vaults
vault_backend_list_locations() {
    op vault list --format json | jq -r '.[].name'
}

# List items in specific vault (already implemented, just needs exposure)
vault_backend_list_items_in_location() {
    local vault_name="$1"
    op item list --vault "$vault_name" --format json
}

# List items by tag
vault_backend_list_items_by_tag() {
    local tag="$1"
    op item list --tags "$tag" --format json
}

# Create item in specific vault (already supported via ONEPASSWORD_VAULT)
vault_backend_create_item_in_location() {
    # Update ONEPASSWORD_VAULT temporarily or pass --vault
}
```

### Location Types
```json
{ "type": "vault", "value": "Dotfiles" }     // Dedicated vault
{ "type": "tag", "value": "dotfiles" }       // Tag-based organization
{ "type": "vault+tag", "value": {"vault": "Personal", "tag": "dotfiles"} }
```

### Breaking Changes
- `ONEPASSWORD_VAULT` env var behavior changes
- Old: Hardcoded fallback to "Personal"
- New: Read from config, env var as override

### Migration Path
1. Read existing `ONEPASSWORD_VAULT` env var → write to config
2. Config takes precedence over hardcoded default
3. Env var still works as override for advanced users

---

## pass Implementation

### Current Behavior
- Uses `PASS_PREFIX` env var (defaults to "dotfiles")
- Items stored as `dotfiles/Item-Name`
- Already has location awareness!

### Changes Needed
Minimal - mostly just expose to config:

```zsh
# List available directories (prefixes)
vault_backend_list_locations() {
    find "$PASSWORD_STORE_DIR" -maxdepth 1 -type d -not -name ".*" | xargs -n1 basename
}

# Already implemented via PASS_PREFIX
vault_backend_list_items_in_location() {
    local prefix="$1"
    PASS_PREFIX="$prefix" vault_backend_list_items
}
```

### Location Types
```json
{ "type": "directory", "value": "dotfiles" }
{ "type": "directory", "value": "work/dotfiles" }  // Nested supported
```

### Breaking Changes
- None - pass already works this way
- Just moving config from env var to JSON

### Migration Path
1. Read `PASS_PREFIX` env var → write to config
2. Config takes precedence
3. Env var still works as override

---

## Unified Interface Changes

### New Functions in `lib/_vault.sh`

```zsh
# Get configured location
vault_get_location() {
    # Returns: { "type": "folder", "value": "dotfiles" }
    jq -r '.vault_location // empty' "$VAULT_CONFIG_FILE"
}

# Set location in config
vault_set_location() {
    local type="$1"
    local value="$2"
    # Update vault_location in config
}

# List available locations (delegates to backend)
vault_list_locations() {
    _ensure_backend_loaded || return 1
    vault_backend_list_locations "$@"
}

# List items in location (delegates to backend)
vault_list_items_in_location() {
    _ensure_backend_loaded || return 1
    vault_backend_list_items_in_location "$@"
}
```

### Updated Interface Spec (`_interface.md`)

Add to required functions:

```markdown
### `vault_backend_list_locations`

List available organizational units (folders/vaults/directories).

​```bash
vault_backend_list_locations(session)
# Returns: JSON array of location names
# Format: ["Personal", "Work", "Dotfiles"]
​```

### `vault_backend_list_items_in_location`

List items within a specific location.

​```bash
vault_backend_list_items_in_location(location_type, location_value, session)
# Args: location_type  - "folder", "vault", "directory", "tag", "prefix"
#       location_value - The location identifier
#       session        - Session token
# Returns: JSON array of items
​```
```

---

## Schema Changes

### Updated `vault-items.schema.json`

```json
{
  "properties": {
    "vault_location": {
      "type": "object",
      "description": "Where to find/store dotfiles items in the vault",
      "properties": {
        "type": {
          "type": "string",
          "enum": ["folder", "vault", "tag", "directory", "prefix", "none"],
          "description": "Location type (backend-specific)"
        },
        "value": {
          "oneOf": [
            { "type": "string" },
            { "type": "null" },
            { "type": "object" }
          ],
          "description": "Location identifier"
        }
      },
      "required": ["type", "value"]
    }
  }
}
```

### Example Configurations

**Bitwarden with folder:**
```json
{
  "vault_location": {
    "type": "folder",
    "value": "dotfiles"
  },
  "vault_items": { ... }
}
```

**1Password with vault:**
```json
{
  "vault_location": {
    "type": "vault",
    "value": "Dotfiles"
  },
  "vault_items": { ... }
}
```

**pass with directory:**
```json
{
  "vault_location": {
    "type": "directory",
    "value": "dotfiles"
  },
  "vault_items": { ... }
}
```

**Legacy/no location (backward compatible):**
```json
{
  "vault_items": { ... }
}
```

---

## Implementation Order

### Phase 1: Core Infrastructure
1. Update schema with `vault_location` field
2. Add `vault_list_locations()` and `vault_list_items_in_location()` to abstraction layer
3. Update `_interface.md` with new required functions

### Phase 2: Bitwarden Backend
1. Implement `vault_backend_list_locations()` (folder listing)
2. Implement `vault_backend_list_items_in_location()`
3. Implement `vault_backend_create_location()` (create folder)
4. Update `vault_backend_create_item()` to respect location

### Phase 3: 1Password Backend
1. Implement location functions for vaults
2. Add tag support as alternative location type
3. Migrate from `ONEPASSWORD_VAULT` env var to config

### Phase 4: pass Backend
1. Expose existing `PASS_PREFIX` behavior to config
2. Implement `vault_backend_list_locations()` (directory listing)
3. Already has location-aware operations

### Phase 5: Wizard Rewrite
1. Rewrite `init-vault.sh` with new flow
2. Add vault-scanning mode to `discover-secrets.sh`
3. Update all vault commands to respect `vault_location`

### Phase 6: Documentation & Testing
1. Update all docs
2. Add integration tests per backend
3. Migration guide for existing users

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Break existing users | Medium | High | Backward compatible: no `vault_location` = legacy behavior |
| Backend-specific bugs | High | Medium | Implement one at a time, test thoroughly |
| Complex wizard UX | Medium | Medium | User testing, iterate on prompts |
| 1Password API changes | Low | High | Pin to op v2.x, document requirements |

---

## Success Criteria

1. **New user onboarding**: Complete setup in < 2 minutes
2. **Existing vault users**: Import items without renaming
3. **New machine restore**: Pull secrets without local files
4. **No naming conflicts**: Config names match vault names always
5. **Backend parity**: Same UX regardless of backend choice

---

# Final Assessment: Is This The Right Move?

## Arguments FOR Full Redesign

1. **Solves the root cause** - Naming mismatch can't happen when names come from vault
2. **Better new-machine experience** - No chicken-and-egg problem
3. **Respects user autonomy** - Their naming, their organization
4. **Educational** - Users understand the system before committing
5. **Backend parity** - pass already works this way, others should too
6. **Scales to teams** - Folder/vault organization matters for shared secrets

## Arguments AGAINST

1. **Complexity** - More code, more failure modes
2. **Time investment** - Multi-phase implementation
3. **Testing burden** - Need to test 3 backends × multiple flows
4. **Over-engineering?** - Most users might be fine with minimal fix

## Verdict

**Proceed with redesign.** Reasons:

1. The minimal fix (mismatch detection) is a bandaid - it doesn't help new-machine setup
2. pass already has this model and it works well - we're just catching up
3. "Best dotfiles system" means handling edge cases gracefully
4. The abstraction layer already exists - we're extending, not rewriting
5. Breaking changes are acceptable (per user) - better to do it right once

## Recommended Approach

1. **Start with Bitwarden** (you can test it)
2. **Implement incrementally** (ship after each phase works)
3. **Keep backward compatibility** (no `vault_location` = legacy mode)
4. **Document aggressively** (the wizard IS the documentation)

---

## Feedback Requested

1. Does the backend-specific plan make sense for each backend?
2. Is the phased implementation order correct?
3. Any concerns about the breaking changes and migration paths?
4. Ready to proceed with Phase 1?
