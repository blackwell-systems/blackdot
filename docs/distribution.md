# Distribution

This document tracks blackdot's distribution channels — what's live, what's planned, and implementation notes for each.

---

## Current State

| Channel | Status | Command |
|---------|--------|---------|
| GitHub Releases (binaries) | ✅ Live | Download from [releases page](https://github.com/blackwell-systems/blackdot/releases) |
| curl installer (Unix) | ✅ Live | `curl -fsSL .../install.sh \| bash` |
| PowerShell installer (Windows) | ✅ Live | `irm .../install-windows.ps1 \| iex` |
| Homebrew tap | ✅ Formula added | `brew install blackwell-systems/tap/blackdot` |
| Docker (demo/bootstrap) | ✅ In repo | `docker/Dockerfile` — not published |
| Devcontainer feature (ghcr.io) | ⚠️ Broken | Last publish failed Dec 2025 |
| Winget | ❌ Missing | — |
| Scoop | ❌ Missing | — |
| AUR | ❌ Missing | — |

### What ships in a release

The `release.yml` workflow builds and attaches to every tag:

- `blackdot-linux-amd64`
- `blackdot-linux-arm64`
- `blackdot-darwin-amd64`
- `blackdot-darwin-arm64`
- `blackdot-windows-amd64.exe`
- `blackdot-windows-arm64.exe`
- `blackdot-<version>.tar.gz` (source)
- `blackdot-<version>.zip` (source)
- `SHA256SUMS.txt`

---

## Priority Roadmap

### 1. Homebrew Tap — ✅ Done

**Tap:** `blackwell-systems/homebrew-tap` (at `workspace/code/homebrew-tap`)  
**Formula:** `Formula/blackdot.rb` — added alongside 6 other tools in the tap

**Install command:**
```bash
brew tap blackwell-systems/tap
brew install blackdot
# or one-liner:
brew install blackwell-systems/tap/blackdot
```

**Current version:** v4.0.0-rc5 (pinned, needs update on each release)

**TODO — Auto-update on release:**  
The formula SHA256 hashes must be updated manually right now. Add a step to `release.yml` to automatically update the formula after binaries are built. The `homebrew-formula-updater` tool (at `workspace/code/homebrew-formula-updater`) may handle this.

**Future:** Consider submitting to homebrew-core once stable (removes tap requirement).

---

### 2. Winget — High Priority

**Impact:** Windows users with winget (default in Windows 11). Already done for shelfctl — same process.

**What to build:**
- PR to `microsoft/winget-pkgs`
- Manifest at `manifests/b/BlackwellSystems/blackdot/<version>/`

**Install command (target):**
```powershell
winget install BlackwellSystems.blackdot
```

**Implementation:**
1. Create the three manifest files:
   - `BlackwellSystems.blackdot.yaml` (version manifest)
   - `BlackwellSystems.blackdot.installer.yaml` (installer manifest — references the `.exe`)
   - `BlackwellSystems.blackdot.locale.en-US.yaml` (locale manifest)
2. Submit PR to `microsoft/winget-pkgs` (same as shelfctl PR #358438)
3. Add step to `release.yml` to auto-submit winget update PRs on release

**Auto-update option:** Use `wingetcreate` CLI in the release workflow to auto-generate and submit PRs.

---

### 3. Scoop — Medium Priority

**Impact:** Popular with Windows developers who prefer lightweight package managers. Simpler than winget for dev tools.

**What to build:**
- New repo: `blackwell-systems/scoop-bucket` (or add to existing if one exists)
- Manifest: `blackdot.json`

**Install command (target):**
```powershell
scoop bucket add blackwell-systems https://github.com/blackwell-systems/scoop-bucket
scoop install blackdot
```

**Implementation:**
```json
{
  "version": "4.0.0",
  "description": "Developer dotfiles and environment management CLI",
  "homepage": "https://github.com/blackwell-systems/blackdot",
  "license": "MIT",
  "architecture": {
    "64bit": {
      "url": "https://github.com/blackwell-systems/blackdot/releases/download/v4.0.0/blackdot-windows-amd64.exe",
      "hash": "<sha256>",
      "bin": [["blackdot-windows-amd64.exe", "blackdot"]]
    },
    "arm64": {
      "url": "https://github.com/blackwell-systems/blackdot/releases/download/v4.0.0/blackdot-windows-arm64.exe",
      "hash": "<sha256>",
      "bin": [["blackdot-windows-arm64.exe", "blackdot"]]
    }
  },
  "checkver": {
    "github": "https://github.com/blackwell-systems/blackdot"
  },
  "autoupdate": {
    "architecture": {
      "64bit": {
        "url": "https://github.com/blackwell-systems/blackdot/releases/download/v$version/blackdot-windows-amd64.exe"
      },
      "arm64": {
        "url": "https://github.com/blackwell-systems/blackdot/releases/download/v$version/blackdot-windows-arm64.exe"
      }
    }
  }
}
```

---

### 4. Fix Devcontainer Feature — Medium Priority

**Impact:** `ghcr.io/blackwell-systems/blackdot:1` is used in devcontainer.json files. Currently stale (Dec 2025).

**Problem:** The `devcontainer-feature.yml` workflow last ran December 12, 2025 and failed. The feature has not been republished since.

**Fix:**
1. Investigate the failure (`gh run view 20179626405`)
2. Fix the workflow
3. Add trigger on `release.yml` completion to republish the devcontainer feature
4. Verify `ghcr.io/blackwell-systems/blackdot:1` resolves correctly after fix

---

### 5. AUR — Low Priority

**Impact:** Arch Linux / Manjaro users. Small audience but vocal developer community.

**What to build:**
- `PKGBUILD` in an AUR package `blackdot-bin`
- Maintained in a separate `aur-blackdot` repo (AUR convention)

**Install command (target):**
```bash
yay -S blackdot-bin
# or
paru -S blackdot-bin
```

**Note:** AUR packages require a maintainer with an Arch account. Lower priority until there's actual Linux user demand.

---

## Release Workflow Improvements

The current `release.yml` builds binaries but doesn't update any package managers. Once package managers are set up, add these steps:

```yaml
# After binaries are uploaded to GitHub Release:
- name: Update Homebrew formula
  run: |
    # Update SHA256 hashes in blackwell-systems/homebrew-tap
    # Trigger via repository_dispatch or direct push

- name: Submit Winget update
  run: |
    # Use wingetcreate to auto-generate and submit PR
    wingetcreate update BlackwellSystems.blackdot \
      --version $VERSION \
      --urls "https://github.com/.../blackdot-windows-amd64.exe" \
      --submit

- name: Update Scoop manifest
  run: |
    # Push updated blackdot.json to scoop bucket repo
```

---

## Docker / Container Image

There are Dockerfiles in `docker/` for bootstrap demos but no published image. Options:

### Option A: Bootstrap demo image (easy)
Publish `ghcr.io/blackwell-systems/blackdot:latest` — a container with blackdot pre-installed for trying it out.

### Option B: Dev base image (more useful)
Publish a base development image with blackdot, common tools, and shell config pre-loaded. Useful as a base for devcontainers.

**Both would be published from `release.yml` after a tag push.**

---

## Install Script Improvements

The current `install.sh` works but could be extended:

- [ ] Support `--version <tag>` flag to pin a specific version
- [ ] Add checksum verification by default (currently optional via `BLACKDOT_SKIP_CHECKSUM`)
- [ ] Print upgrade instructions when blackdot is already installed
- [ ] Support `BLACKDOT_INSTALL_DIR` env var for custom install location

---

## Tracking

| Channel | Owner | Status | Notes |
|---------|-------|--------|-------|
| Homebrew tap | — | Not started | Create `blackwell-systems/homebrew-tap` |
| Winget | — | Not started | Mirror shelfctl PR process |
| Scoop | — | Not started | Create `blackwell-systems/scoop-bucket` |
| Devcontainer (ghcr.io) | — | Broken | Fix workflow, re-publish |
| AUR | — | Not started | Low priority |
| Docker image | — | Not started | Publish from existing Dockerfiles |
