#!/usr/bin/env bash
#
# macOS System Settings
#
# Apply with: ./apply-settings.sh
# Customize with: ./discover-settings.sh --generate (captures YOUR current settings)
#
# WARNING: Review these settings before applying!
# Some settings require logout/restart to take effect.
#
set -euo pipefail

echo "Applying macOS settings..."

# Close System Preferences to prevent conflicts
osascript -e 'tell application "System Preferences" to quit' 2>/dev/null || true

###############################################################################
# Trackpad                                                                    #
###############################################################################

# Tap to click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# Tracking speed (0-3, where 3 is fastest)
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2.0

# Three finger drag
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true

# Natural scrolling (set to false for "traditional" scrolling)
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool true

###############################################################################
# Mouse                                                                       #
###############################################################################

# Mouse tracking speed (0-3)
defaults write NSGlobalDomain com.apple.mouse.scaling -float 2.5

###############################################################################
# Keyboard                                                                    #
###############################################################################

# Fast key repeat rate (lower = faster, default 2)
defaults write NSGlobalDomain KeyRepeat -int 2

# Short delay until repeat (lower = shorter, default 15)
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Disable auto-capitalization
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Disable smart quotes (annoying for developers)
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable smart dashes
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable period substitution (double-space to period)
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

###############################################################################
# Dock                                                                        #
###############################################################################

# Dock icon size
defaults write com.apple.dock tilesize -int 48

# Auto-hide dock
defaults write com.apple.dock autohide -bool true

# Remove auto-hide delay
defaults write com.apple.dock autohide-delay -float 0

# Speed up auto-hide animation
defaults write com.apple.dock autohide-time-modifier -float 0.3

# Don't show recent apps in Dock
defaults write com.apple.dock show-recents -bool false

# Minimize windows to application icon
defaults write com.apple.dock minimize-to-application -bool true

# Don't animate opening applications
defaults write com.apple.dock launchanim -bool false

###############################################################################
# Finder                                                                      #
###############################################################################

# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Default to list view (icnv=icon, clmv=column, Flwv=cover flow, Nlsv=list)
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Disable warning when changing file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Disable .DS_Store on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Disable .DS_Store on USB volumes
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# New Finder windows open to home directory
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"

###############################################################################
# Screenshots                                                                 #
###############################################################################

# Screenshot location (default: Desktop)
defaults write com.apple.screencapture location -string "${HOME}/Desktop"

# Screenshot format (png, jpg, pdf, gif, tiff)
defaults write com.apple.screencapture type -string "png"

# Disable screenshot shadow
defaults write com.apple.screencapture disable-shadow -bool true

###############################################################################
# Menu Bar                                                                    #
###############################################################################

# Show battery percentage
defaults write com.apple.menuextra.battery ShowPercent -string "YES"

###############################################################################
# Misc                                                                        #
###############################################################################

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk (not iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Disable "Are you sure you want to open this application?" dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Disable the crash reporter
defaults write com.apple.CrashReporter DialogType -string "none"

# Require password immediately after sleep or screen saver
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

###############################################################################
# Activity Monitor                                                            #
###############################################################################

# Show the main window when launching Activity Monitor
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true

# Show all processes
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# Sort by CPU usage
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

###############################################################################
# TextEdit                                                                    #
###############################################################################

# Use plain text mode by default
defaults write com.apple.TextEdit RichText -int 0

# Open and save files as UTF-8
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

###############################################################################
# Apply Changes                                                               #
###############################################################################

echo ""
echo "Restarting affected applications..."

# Restart Dock
killall Dock 2>/dev/null || true

# Restart Finder
killall Finder 2>/dev/null || true

# Restart SystemUIServer (menu bar)
killall SystemUIServer 2>/dev/null || true

echo ""
echo "Done! Some changes may require logout/restart."
