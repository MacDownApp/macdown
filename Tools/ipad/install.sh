#!/bin/sh
# Builds MacDown for iPhone/iPad, signed with your Apple ID's team, and installs it on a connected device.
#
#   Tools/ipad/install.sh [device name or UDID]      (default: the first connected iPhone or iPad)
#
# Why this exists: Xcode's own Run first copies the device's system symbols, which can take a very long
# time (or hang) on a new iOS version, and the app is then built but never installed. This script installs
# with `devicectl`, which does not need that step.
#
# Needs: the device connected, unlocked, with Developer Mode on; Xcode signed in with your Apple ID once
# (that creates the signing certificate and the Personal Team).
set -e
cd "$(dirname "$0")/../.."

# Your team id: DEVELOPMENT_TEAM from the environment, or the team Xcode knows.
TEAM="${DEVELOPMENT_TEAM:-$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null | grep -o 'teamID = [A-Z0-9]*' | head -1 | sed 's/teamID = //')}"
if [ -z "$TEAM" ]; then echo "No team found. Sign in to Xcode (Settings > Accounts) or set DEVELOPMENT_TEAM=..."; exit 1; fi

DEVICE="$1"
if [ -z "$DEVICE" ]; then
  DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '/connected/ && /(iPhone|iPad)/ {for(i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) {print $i; exit}}')
fi
if [ -z "$DEVICE" ]; then echo "No connected iPhone or iPad found. Connect and unlock it, then try again."; exit 1; fi

ruby Tools/ipad/make_project.rb
OUT="$PWD/build/ipad-signed"
echo "Building for team $TEAM..."
xcodebuild -project Viewer/VaultViewer.xcodeproj -scheme VaultViewer -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$OUT" \
  DEVELOPMENT_TEAM="$TEAM" -allowProvisioningUpdates -quiet build

APP="$OUT/Build/Products/Release-iphoneos/MacDown.app"
echo "Installing on $DEVICE..."
xcrun devicectl device install app --device "$DEVICE" "$APP"
echo "Done. Open MacDown on the device. (First time: Settings > General > VPN & Device Management > trust your Apple ID.)"
