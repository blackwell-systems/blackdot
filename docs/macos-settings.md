# macOS System Settings

Automated configuration for macOS developer environments using `defaults` commands.

## Overview

The `macos/settings.sh` script applies developer-optimized macOS system preferences:

- **Keyboard & Mouse** – Fast key repeat, precise tracking
- **Dock** – Auto-hide, minimal animations, no recents
- **Finder** – Show all files, extensions, path bar, list view
- **Safari** – Developer tools, privacy settings
- **Spotlight** – Optimized indexing for development
- **Screenshots** – PNG format, no shadow
- **Hot Corners** – Quick access shortcuts
- **Energy** – Never sleep when plugged in
- **Security** – Require password immediately

## Usage

```bash
# Review settings that will be applied
./macos/apply-settings.sh --dry-run

# Apply settings
./macos/apply-settings.sh

# Create backup before applying
./macos/apply-settings.sh --backup
```

**Note:** Some settings require logout or restart to take effect.

---

## Settings Categories

### Trackpad

```bash
# Tap to click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

# Three finger drag
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true

# Tracking speed (0-3, 3 = fastest)
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2.0
```

### Keyboard

```bash
# Fast key repeat (lower = faster)
defaults write NSGlobalDomain KeyRepeat -int 2

# Short delay until repeat
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Disable auto-correct, smart quotes, smart dashes (annoying for developers)
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
```

### Dock

```bash
# Auto-hide dock with no delay
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0

# Don't show recent apps
defaults write com.apple.dock show-recents -bool false

# Minimize windows to application icon
defaults write com.apple.dock minimize-to-application -bool true
```

### Finder

```bash
# Show all file extensions and hidden files
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show path bar and status bar
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true

# Default to list view
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Keep folders on top when sorting
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Disable .DS_Store on network/USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Allow quitting Finder with Cmd+Q
defaults write com.apple.finder QuitMenuItem -bool true
```

### Safari (Developer Settings)

```bash
# Show full URL in address bar
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# Enable developer menu and web inspector
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true

# Enable "Do Not Track"
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true

# Don't open "safe" files after downloading
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
```

### Spotlight

```bash
# Optimized indexing order (apps, system prefs, dirs, PDFs, docs first)
defaults write com.apple.spotlight orderedItems -array \
  '{"enabled" = 1;"name" = "APPLICATIONS";}' \
  '{"enabled" = 1;"name" = "SYSTEM_PREFS";}' \
  '{"enabled" = 1;"name" = "DIRECTORIES";}' \
  '{"enabled" = 1;"name" = "PDF";}' \
  '{"enabled" = 1;"name" = "DOCUMENTS";}' \
  '{"enabled" = 0;"name" = "FONTS";}' \
  '{"enabled" = 0;"name" = "MESSAGES";}' \
  '{"enabled" = 0;"name" = "IMAGES";}' \
  '{"enabled" = 0;"name" = "MUSIC";}' \
  '{"enabled" = 0;"name" = "MOVIES";}'
```

### Hot Corners

```bash
# Bottom-left: Start screen saver
defaults write com.apple.dock wvous-bl-corner -int 5

# Bottom-right: Desktop
defaults write com.apple.dock wvous-br-corner -int 4
```

**Available actions:**
- `0` = No-op
- `2` = Mission Control
- `3` = Show application windows
- `4` = Desktop
- `5` = Start screen saver
- `10` = Put display to sleep
- `11` = Launchpad
- `13` = Lock Screen

### Energy & Power

```bash
# Never sleep when on power adapter
sudo pmset -c displaysleep 15
sudo pmset -c sleep 0

# Sleep after 5 min on battery
sudo pmset -b displaysleep 5
sudo pmset -b sleep 10

# Enable lid wakeup
sudo pmset -a lidwake 1
```

### Bluetooth Audio

```bash
# Increase sound quality for Bluetooth headphones
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40
```

---

## Customization

### Discover Current Settings

```bash
# Generate settings.sh from your current macOS preferences
./macos/discover-settings.sh --generate
```

### Create Snapshots

```bash
# Save current settings to timestamped snapshot
./macos/discover-settings.sh --snapshot
```

### Modify Settings

Edit `macos/settings.sh` and add your own preferences:

```bash
# Example: Change screenshot format to JPG
defaults write com.apple.screencapture type -string "jpg"

# Example: Set dock to bottom (instead of left/right)
defaults write com.apple.dock orientation -string "bottom"
```

---

## Security Considerations

- **Requires sudo** for some settings (pmset, Spotlight)
- **Scripts are idempotent** – safe to run multiple times
- **No destructive changes** – only applies preferences
- **Reversible** – manually reset via System Preferences or `defaults delete`

---

## Related Tools

- **discover-settings.sh** – Reverse-engineer current macOS settings
- **apply-settings.sh** – Apply settings from `settings.sh`

---

**Learn More:**
- [Main Documentation](/)
- [macOS Scripts](https://github.com/blackwell-systems/blackdot/tree/main/macos)
- [GitHub Repository](https://github.com/blackwell-systems/blackdot)
