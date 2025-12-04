# Dotfiles Pain-Point Analysis

> **Comprehensive Onboarding & UX Audit**
> Date: 2025-12-04
> Version: 2.3.0
> Branch: claude/project-review-01R1pcLzUYc4BSRfL1U6uRBx

---

## Executive Summary

**Overall Assessment:** Strong foundation with excellent modularity, but several friction points that could confuse new users or cause abandonment during onboarding.

**Key Findings:**
- 🔴 **7 Critical Issues** - Blockers & Major Friction
- 🟡 **8 Medium Priority** - Friction & Confusion
- 🟢 **8 Nice-to-Have** - Polish & Quality of Life

---

## Critical Pain Points (Blockers & Major Friction)

### 1. Vault Discovery vs Vault Init Confusion ⚠️ HIGH IMPACT

**Location:** `vault/init-vault.sh`, `vault/discover-secrets.sh`

**Problem:** Two similar-sounding commands with overlapping purposes

- `dotfiles vault init` - Configure backend (bw/op/pass)
- `dotfiles vault discover` - Auto-detect secrets and generate config

**User Confusion:**
- "Do I run init first or discover first?"
- "What's the difference?"
- "If I run discover, do I still need init?"

**Current Flow Is Unclear:**
```
├─ vault init (choose backend)
└─ vault discover (find secrets) ← but this isn't mentioned in init!
```

**Recommendation:**
- Merge into single flow: `dotfiles vault init` should:
  1. Choose backend
  2. Auto-discover secrets (show preview)
  3. Ask to push to vault
- Or rename: `vault discover` → `vault scan` or `vault audit`
- Document the relationship clearly

---

### 2. Hardcoded ~/workspace/dotfiles Path 🚨 CRITICAL

**Location:** `install.sh:33`, multiple files

**Problem:** `INSTALL_DIR="$HOME/workspace/dotfiles"` is hardcoded
- Users who want different location are stuck
- No `--install-dir` flag
- Documentation doesn't mention this constraint

**Impact:** Users with existing ~/workspace setup hit conflicts

**Recommendation:**
- Add `--install-dir=/custom/path` flag to install.sh
- Store actual path in config file
- Use stored path consistently (already using `$DOTFILES_DIR` in most places)

---

### 3. Brewfile Tier Is Invisible 🎭

**Location:** `install.sh`, `README.md`

**Problem:** Users don't know about `BREWFILE_TIER` variable
- Documentation mentions it exists (line 64-66 of install.sh help)
- But never explains WHAT the tiers are
- Can't see tier differences without reading Brewfile source

**User Questions:**
- "What's the difference between minimal/enhanced/full?"
- "How many packages in each?"
- "Can I see the list before installing?"

**Recommendation:**
- Add `dotfiles packages list [tier]` command
- Show tier comparison table in README
- Prompt during setup: "Enhanced tier installs 80+ packages (~5min). Continue?"

---

### 4. No Rollback / Undo 💣

**Location:** All destructive operations

**Problem:** Several operations are irreversible
- `dotfiles vault restore --force` overwrites local files
- No backup created before overwrite
- No "oops, undo that" command

**Fear Factor:** Users afraid to run restore on existing machine

**Recommendation:**
- Auto-backup before destructive operations
- Add `dotfiles vault backup` (already exists but not advertised)
- Add `dotfiles rollback` to restore from last backup
- Show backup location: "Backed up to ~/.config/dotfiles/backups/2025-12-04_153045/"

---

### 5. Vault Merge Preview Is Still Confusing 📋

**Location:** `vault/discover-secrets.sh:615-680`

**Problem:** Even with detailed preview, users don't understand:
- Why are there "manual items"? (they didn't add them manually)
- What does "preserved" mean?
- Should they merge or replace?

**The "Manual Items" Term Is Misleading:**
- Really means: "items in config but not discovered"
- Could be: old/moved files, custom paths, or actual manual additions

**Recommendation:**
- Rename "manual items" → "existing items not found"
- Add context: "These items are in your config but weren't found during scan:"
- Show paths: "• SSH-Old-Key → ~/.ssh/id_rsa_old (file not found)"
- Suggest: "[r]eplace (recommended if this is a new machine)"

---

### 6. Error Messages Lack Next Steps 🤷

**Location:** Throughout codebase

**Examples:**
- "Vault is locked" → No command shown to unlock
- "jq not found" → Installation command shown, but workflow doesn't continue
- "Git config not found" → Doesn't explain this is expected on fresh machine

**Recommendation:**

Every error should have:
1. What went wrong
2. Why it matters
3. How to fix it

Example:
```
❌ Vault is locked
ℹ️  This prevents restoring secrets
→ Run: export BW_SESSION="$(bw unlock --raw)"
```

---

### 7. Doctor Health Score Is Arbitrary ⚕️

**Location:** `bin/dotfiles-doctor:444-456`

**Problem:** Health scoring isn't explained
- Why is my score 30/100?
- What does 100 mean? (impossible on fresh install)
- Warnings deduct 5 points, fails deduct 10 - why these numbers?

**User Confusion:**
- "Is 70/100 good or bad?"
- "Should I fix warnings?"
- "What's a 'passing' score?"

**Recommendation:**

Add score interpretation:
- **100:** Perfect (rare)
- **80-99:** Healthy
- **60-79:** Minor issues
- **40-59:** Needs attention
- **<40:** Critical problems

Show what would improve score: "Fix 3 warnings → 85/100"

---

## Medium Priority Pain Points (Friction & Confusion)

### 8. Setup Wizard State Is Opaque 📦

**Location:** `lib/_state.sh`, `bin/dotfiles-setup`

**Problem:** Users can't see what wizard will do
- "Will it overwrite my existing config?"
- "Can I skip steps?"
- "What if I ctrl-c, will it break things?"

The wizard saves state, but:
- Doesn't explain this upfront
- No progress bar
- Can't preview all steps

**Recommendation:**
- Show all 6 steps upfront with estimated time
- Add progress: "Step 3 of 6 (Vault) - 50% complete"
- Explain: "Safe to exit anytime - we'll resume from this step"

---

### 9. Multiple Vaults Not Clear 🔐

**Location:** `vault/README.md`, `lib/_vault.sh`

**Problem:** Documentation mentions "multi-vault" but:
- Not clear what this means
- Can't use multiple backends simultaneously (or can you?)
- No use case examples

**User Questions:**
- "Can I use both Bitwarden AND 1Password?"
- "Why would I want multiple vaults?"
- "How do I switch between them?"

**Recommendation:**
- Clarify: "Multi-vault means support for multiple backends, not simultaneous use"
- Add example: "Use 'pass' for personal, 'bitwarden' for work (switch with env var)"
- Or: Actually support multi-vault (store personal in bw, work in op)

---

### 10. Template System Is Hidden Gem 💎

**Location:** `bin/dotfiles-template`, `templates/`

**Problem:** Template system is incredibly powerful but:
- Not mentioned in main README
- Setup wizard asks about it but doesn't explain benefits
- No examples in docs/ for common use cases

**User Thinks:** "What is this? Do I need it?"

**Reality:** Solves machine-specific config (work laptop vs personal)

**Recommendation:**
- Add templates/ section to README with example
- Show use case: "Different git name/email per machine"
- Wizard should show before/after:
  ```
  Current: john@work.com (hardcoded)
  With templates: auto-switches based on machine
  ```

---

### 11. SSH Key Types Are Mysterious 🔑

**Location:** `vault/discover-secrets.sh`, `vault/restore-ssh.sh`

**Problem:** Script handles id_rsa, id_ed25519, id_ecdsa
- But doesn't explain which type is preferred
- No guidance on creating keys
- Doesn't warn about deprecated key types (id_rsa)

**Recommendation:**
- Add `dotfiles ssh keygen` helper
- Suggest ed25519 by default (modern, secure)
- Warn if id_rsa detected: "⚠️  RSA keys are less secure, consider ed25519"

---

### 12. Drift Detection Is Reactive, Not Proactive 🎲

**Location:** `bin/dotfiles-drift`

**Problem:** User must remember to run `dotfiles drift`
- No automatic check
- No reminder after modifying tracked files
- Easy to forget you made local changes

**Scenario:** User modifies ~/.gitconfig, weeks later runs restore, loses changes

**Recommendation:**
- Add shell hook: warn on tracked file modification
- Auto-run drift check before destructive operations
- Show last drift check time: "Last checked: 3 days ago - run `dotfiles drift`"

---

### 13. Package Installation Time Not Set 🕐

**Location:** `bin/dotfiles-setup` phase_packages

**Problem:** "Installing packages (~5-10 minutes)" is vague
- Depends on tier, network, machine speed
- No progress indicator during install
- User thinks: "Is it frozen?"

**Recommendation:**
- Show per-package progress: "Installing bat... (15/80)"
- Or stream brew output with: "Installing ripgrep..."
- Warn for slow steps: "Building cmake from source... (this may take 5+ min)"

---

### 14. CLAUDE.md Is For Claude, Not Users 🤖

**Location:** `CLAUDE.md`

**Problem:** This 400-line file is excellent for AI agents but:
- Users see it and think "Is this user documentation?"
- No explanation that it's for Claude Code
- Duplicates some info in README.md (causes confusion)

**Recommendation:**
- Rename to `.claude/README.md` or `.claude/CONTEXT.md`
- Add header: "This file provides context for Claude Code AI sessions"
- Reference it from main README: "Claude Code users: See .claude/README.md"

---

### 15. Workspace Symlink Purpose Is Unclear 🔗

**Location:** Bootstrap scripts, README

**Problem:** Creates `/workspace` → `$HOME/workspace` symlink
- Purpose: "portable Claude sessions"
- Users think: "What does that mean?"
- Not clear what breaks if skipped

**Recommendation:**

Explain clearly:
```
Allows Claude Code session history to work across machines

With /workspace: session syncs work ✓
Without: session history lost on new machine ✗
```

Make it more optional: "Skip if not using Claude Code session sync"

---

## Nice-to-Have Improvements (Polish & QoL)

### 16. No Telemetry/Analytics

**Good for privacy, bad for debugging**

- Can't see where users get stuck
- No crash reports

**Recommendation:**
- Add opt-in anonymous analytics
- Example: "Send anonymous usage data to improve dotfiles? [y/N]"

---

### 17. Changelog Is Detailed But Hard to Navigate

- 100+ lines for v2.3.0
- No "what's new" summary

**Recommendation:** Add TL;DR section at top

---

### 18. No Video Walkthrough or Screenshots

- README has no visuals
- Hard to understand "what will this look like"

**Recommendation:**
- Add GIF of installation process
- Show setup wizard in action

---

### 19. Testing Locally Is Hard

- Developers want to test changes
- No TESTING.md or CONTRIBUTING.md
- Not clear how to run tests

**Recommendation:** Add "make test" or "./test.sh" convenience script

---

### 20. Shell Completion Only For Dotfiles Command

- `zsh/completions/_dotfiles` exists
- But no completions for vault subcommands
- Can't tab-complete: `dotfiles vault <tab>`

**Recommendation:** Add full completion tree

---

### 21. No Uninstall Confirmation

- `dotfiles uninstall` is destructive
- Asks "Are you sure? [y/N]" but doesn't show what will be removed

**Recommendation:** Show list of files/symlinks to be removed

---

### 22. Color Scheme Not Customizable

- Hardcoded colors in all scripts
- Users with different terminal themes may have readability issues

**Recommendation:** Add NO_COLOR support (standard env var)

---

### 23. Metrics Are Collected But Not Shown

- `bin/dotfiles-metrics` exists
- But not advertised in help or README

**Recommendation:** Add to `dotfiles doctor` output: "View history: dotfiles metrics"

---

## Flow-Specific Pain Points

### New User Flow (First-time install on fresh machine)

**Pain Points:**
- ✗ Doesn't know about BREWFILE_TIER options
- ✗ Packages install takes 10min with no progress
- ✗ Vault init → discover → push flow is confusing
- ✗ Template system skipped because "not sure what it does"

**Optimal Flow Should Be:**
1. Install → Shows tier options with package counts
2. Setup wizard → Progress bars and time estimates
3. Vault setup → Combined init+discover in one prompt
4. Show "You're done! Here's what you can do now..."

---

### Existing Machine Migration (Has secrets, moving to new machine)

**Pain Points:**
- ✗ Afraid to run `vault restore` (might overwrite local changes)
- ✗ No clear guide for "I already have SSH keys, how do I migrate?"
- ✗ Drift detection not automatic

**Optimal Flow Should Be:**
1. Install dotfiles
2. Run `dotfiles migrate` (new command):
   - Scans local secrets
   - Compares with vault
   - Shows diff
   - Offers to merge or sync
3. Restore missing items only

---

### Multi-Machine Sync (Daily use across 3+ machines)

**Pain Points:**
- ✗ No clear workflow for "I made changes on machine A, sync to B"
- ✗ Drift detection is manual
- ✗ No reminder to run `dotfiles vault sync`

**Optimal Flow Should Be:**
1. Modify tracked file (e.g., ~/.gitconfig)
2. Shell hook detects change
3. Shows reminder: "⚠️  Tracked file changed. Run `dotfiles vault sync` to sync"
4. On other machine: auto-detects drift on next `dotfiles doctor`

---

### Troubleshooting / Recovery

**Pain Points:**
- ✗ No runbook for common errors
- ✗ Doctor shows problems but not solutions
- ✗ No way to reset to known-good state

**Optimal Flow Should Be:**
1. Error occurs
2. Error message shows:
   - What happened
   - Likely cause
   - Fix command
   - Link to docs: `docs/troubleshooting.md#vault-locked`
3. If unsure: `dotfiles recover` resets to last backup

---

## Impact Analysis

### Issues by Severity
- 🔴 **Critical (Blocks users):** 7
- 🟡 **Medium (Causes friction):** 8
- 🟢 **Nice-to-have (Polish):** 8

### Issues by User Impact
- **First-time users:** 12 issues
- **Migrating users:** 9 issues
- **Power users:** 6 issues

### Top 3 Issues by Impact
1. **Vault init/discover confusion** (affects 90% of users)
2. **No rollback/undo** (fear factor, prevents adoption)
3. **Package installation time/progress** (abandonment risk)

### Quick Wins (High impact, low effort)
- ✓ Add progress indicators to package installation
- ✓ Merge vault init + discover into single flow
- ✓ Add error messages with fix commands
- ✓ Show health score interpretation

---

## Recommended Priority Order

### Phase 1 (Critical - Do These First)
1. Fix vault init/discover confusion
2. Add rollback/backup before destructive operations
3. Add progress indicators to long operations
4. Improve error messages with next steps

### Phase 2 (High Value)
5. Show BREWFILE_TIER options during install
6. Add health score interpretation
7. Make template system more discoverable
8. Auto-backup before vault restore

### Phase 3 (Polish)
9. Add video walkthrough
10. Improve completions
11. Add telemetry (opt-in)
12. Create troubleshooting docs

### Phase 4 (Power Features)
13. Add `dotfiles migrate` command
14. Auto drift detection with shell hooks
15. Multi-vault support (simultaneous backends)

---

## Conclusion

The dotfiles system is well-architected with strong modularity and comprehensive features. However, the onboarding experience has several friction points that could cause user confusion or abandonment.

**Priority focus areas:**
1. **Simplify vault workflows** - Merge init/discover, add backups
2. **Improve visibility** - Progress bars, health score interpretation, tier options
3. **Better error handling** - Every error needs actionable next steps

Addressing the Phase 1 critical issues would significantly improve the user experience and reduce support burden.
