#!/usr/bin/env bash
# Builds an UNSIGNED MemoryGarden.ipa for SideStore / AltStore / Sideloadly.
# SideStore re-signs it on the phone with that phone's free Apple ID — no paid account needed.
#
#   ./distribution/build-ipa.sh            → build/MemoryGarden.ipa
#
# Requires: macOS with Xcode 26+ and XcodeGen (brew install xcodegen).
# No Mac? GitHub Actions runs this for you (.github/workflows/build-ipa.yml).
# Optional env: MG_VERSION=0.2.0 MG_BUILD=7 to stamp the version.
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
  ${MG_VERSION:+MARKETING_VERSION=$MG_VERSION} ${MG_BUILD:+CURRENT_PROJECT_VERSION=$MG_BUILD} \
  | "${FORMAT[@]}"

APP=build/MemoryGarden.xcarchive/Products/Applications/MemoryGarden.app
[ -d "$APP" ] || { echo "Archive failed — see the log above."; exit 1; }

# Unsigned builds carry no entitlements, so SideStore wouldn't know about the App Group the
# widget needs. Embed them with an ad-hoc signature (ldid); SideStore re-signs on the phone.
GROUP=$(awk '/APP_GROUP_ID:/ {print $2; exit}' project.yml)
if command -v ldid >/dev/null; then
  mkdir -p build/ent
  for pair in "Widgets/MemoryGardenWidgets.entitlements:$APP/PlugIns/MemoryGardenWidgets.appex" "App/MemoryGarden.entitlements:$APP"; do
    src=${pair%%:*}; target=${pair#*:}
    out="build/ent/$(basename "$src")"
    sed "s/\$(APP_GROUP_ID)/$GROUP/g" "$src" > "$out"
    bin="$target/$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$target/Info.plist")"
    ldid -S"$out" "$bin"   # extension first, then the app
  done
  echo "Embedded entitlements (App Group: $GROUP)"
else
  echo "⚠️  ldid not found (brew install ldid) — the widget may show sample data after sideloading."
fi

mkdir -p build/Payload
cp -R "$APP" build/Payload/
(cd build && zip -qry MemoryGarden.ipa Payload)
rm -rf build/Payload

SIZE=$(stat -f%z build/MemoryGarden.ipa)
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Info.plist")
echo "✅ build/MemoryGarden.ipa  (version $VERSION, $SIZE bytes)"
echo "   Releases: push a tag (git tag v$VERSION && git push origin v$VERSION) and CI publishes it."
echo "   Installing: docs/INSTALL.md or https://mxhddd.github.io/Memory-App/"
