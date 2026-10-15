#!/usr/bin/env bash
# Builds an UNSIGNED MemoryGarden.ipa for SideStore / AltStore / Sideloadly.
# SideStore re-signs it on the phone with that phone's free Apple ID — no paid account needed.
#
#   ./distribution/build-ipa.sh            → build/MemoryGarden.ipa
#
# Requires: macOS with Xcode 26+ and XcodeGen (brew install xcodegen).
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || { echo "Install XcodeGen first: brew install xcodegen"; exit 1; }
xcodegen generate --quiet

rm -rf build/MemoryGarden.xcarchive build/Payload build/MemoryGarden.ipa
FORMAT=(cat)
command -v xcbeautify >/dev/null && FORMAT=(xcbeautify)
xcodebuild archive \
  -project MemoryGarden.xcodeproj \
  -scheme MemoryGarden \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/MemoryGarden.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  | "${FORMAT[@]}"

APP=build/MemoryGarden.xcarchive/Products/Applications/MemoryGarden.app
[ -d "$APP" ] || { echo "Archive failed — see the log above."; exit 1; }

mkdir -p build/Payload
cp -R "$APP" build/Payload/
(cd build && zip -qry MemoryGarden.ipa Payload)
rm -rf build/Payload

SIZE=$(stat -f%z build/MemoryGarden.ipa)
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Info.plist")
echo "✅ build/MemoryGarden.ipa  (version $VERSION, $SIZE bytes)"
echo "   AirDrop it to the phone → Share → SideStore, or see docs/INSTALL.md."
echo "   For one-tap updates, bump 'version'/'size' in distribution/sidestore-source.json."
