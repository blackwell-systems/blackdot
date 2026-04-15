# Distribution

This document tracks blackdot's distribution channels — what's live, what's planned, and implementation notes for each.

---

## Current State

| Channel | Status | Command |
|---------|--------|---------|
| GitHub Releases (binaries) | ✅ Live | Download from [releases page](https://github.com/blackwell-systems/blackdot/releases) |
| curl installer (Unix) | ✅ Live | `curl -fsSL .../install.sh \| bash` |
| PowerShell installer (Windows) | ✅ Live | `irm .../install-windows.ps1 \| iex` |
| Homebrew tap | ✅ Live | `brew install blackwell-systems/tap/blackdot` |
| Scoop | ✅ Live | `scoop bucket add blackwell-systems https://github.com/blackwell-systems/scoop-bucket && scoop install blackdot` |
| go install | ✅ Live | `go install github.com/blackwell-systems/blackdot/v4/cmd/blackdot@latest` |
| Devcontainer feature (ghcr.io) | ✅ Live | `ghcr.io/blackwell-systems/blackdot:1` |
| Winget | ⏳ PR pending | `winget install BlackwellSystems.blackdot` (pending review) |
| Docker (demo/bootstrap) | ✅ In repo | `docker/Dockerfile` — not published to registry |
| AUR | ❌ Not started | — |

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

Formula is updated automatically on each release via goreleaser.

**Future:** Consider submitting to homebrew-core once stable (removes tap requirement).

---

### 2. Winget — ⏳ PR Pending

**Impact:** Windows users with winget (default in Windows 11).

**Install command:**
```powershell
winget install BlackwellSystems.blackdot
```

PR submitted to `microsoft/winget-pkgs`. Pending review.

**TODO — Auto-update on release:**
Add step to `release.yml` to auto-submit winget update PRs using `wingetcreate` CLI.

---

### 3. Scoop — ✅ Done

**Bucket:** `blackwell-systems/scoop-bucket`

**Install command:**
```powershell
scoop bucket add blackwell-systems https://github.com/blackwell-systems/scoop-bucket
scoop install blackdot
```

Managed via goreleaser (`scoops:` block in `.goreleaser.yaml`). Auto-updated on release.

---

### 4. Devcontainer Feature — ✅ Live

**Registry:** `ghcr.io/blackwell-systems/blackdot:1`

The devcontainer feature is published to GitHub Container Registry and available for use in devcontainer.json configurations.

**Usage:**
```json
{
  "features": {
    "ghcr.io/blackwell-systems/blackdot:1": {
      "preset": "developer"
    }
  }
}
```

See [Devcontainer Support](devcontainers.md) for full documentation.

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

goreleaser handles Homebrew tap and Scoop bucket updates automatically on release. The remaining TODO items:

```yaml
# TODO: Add to release.yml after binaries are uploaded:
- name: Submit Winget update
  run: |
    # Use wingetcreate to auto-generate and submit PR
    wingetcreate update BlackwellSystems.blackdot \
      --version $VERSION \
      --urls "https://github.com/.../blackdot-windows-amd64.exe" \
      --submit
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
| Homebrew tap | — | ✅ Live | `blackwell-systems/homebrew-tap`, Formula/blackdot.rb |
| Scoop | — | ✅ Live | `blackwell-systems/scoop-bucket`, blackdot.json |
| go install | — | ✅ Live | `github.com/blackwell-systems/blackdot/v4/cmd/blackdot@latest` |
| Devcontainer (ghcr.io) | — | ✅ Live | `ghcr.io/blackwell-systems/blackdot:1` |
| Winget | — | ⏳ PR pending | PR to `microsoft/winget-pkgs` |
| AUR | — | ❌ Not started | Low priority |
| Docker image | — | ❌ Not started | Publish from existing Dockerfiles |
