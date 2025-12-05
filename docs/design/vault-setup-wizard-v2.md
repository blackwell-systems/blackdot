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

## Feedback Requested

1. Does the Existing vs Fresh split make sense as the primary branch?
2. Is the "where to look" step clear enough without being overwhelming?
3. Any flows missing for edge cases?
4. Naming suggestions for the location config field?
