#!/bin/sh
# Builds the iPad viewer into one installable file: build/ipad/MacDown.ipa
#
#   Tools/ipad/build-ipa.sh                          unsigned .ipa (sign it with Sideloadly or AltStore)
#   DEVELOPMENT_TEAM=ABCDE12345 Tools/ipad/build-ipa.sh   signed .ipa for devices registered to that team
#
# Optional: BUNDLE_ID=com.you.vaultviewer (a free Apple ID needs an id nobody else uses).
set -e
cd "$(dirname "$0")/../.."
OUT="$PWD/build/ipad"
rm -rf "$OUT"; mkdir -p "$OUT"

ruby Tools/ipad/make_project.rb

if [ -z "$DEVELOPMENT_TEAM" ]; then
  echo "Building unsigned..."
  xcodebuild -project Viewer/VaultViewer.xcodeproj -scheme VaultViewer -configuration Release \
    -destination 'generic/platform=iOS' -derivedDataPath "$OUT/derived" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -quiet build
  mkdir -p "$OUT/Payload"
  cp -R "$OUT/derived/Build/Products/Release-iphoneos/MacDown.app" "$OUT/Payload/"
  (cd "$OUT" && zip -qr -y MacDown.ipa Payload)
  rm -rf "$OUT/Payload"
  echo "Unsigned: $OUT/MacDown.ipa  (sign and install it with Sideloadly or AltStore)"
else
  echo "Building signed for team $DEVELOPMENT_TEAM..."
  cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>debugging</string>
  <key>teamID</key><string>$DEVELOPMENT_TEAM</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
  xcodebuild -project Viewer/VaultViewer.xcodeproj -scheme VaultViewer -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$OUT/MacDown.xcarchive" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" -allowProvisioningUpdates -quiet archive
  xcodebuild -exportArchive -archivePath "$OUT/MacDown.xcarchive" -exportPath "$OUT/export" \
    -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates -quiet
  cp "$OUT/export/MacDown.ipa" "$OUT/MacDown.ipa"
  echo "Signed: $OUT/MacDown.ipa"
  echo "Install with:  xcrun devicectl device install app --device <your iPad> $OUT/MacDown.ipa"
fi
