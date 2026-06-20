#!/bin/bash
#
# Produces a signed, notarized, stapled PostureTimer.dmg that opens with a
# normal double-click on any Mac. Notarizes the app first, staples it, builds
# the DMG around the stapled app, then notarizes and staples the DMG.
#
# Prerequisites:
#   - A "Developer ID Application: …" certificate in your keychain.
#   - A notarytool keychain profile, created once with:
#       xcrun notarytool store-credentials "posture-notary" \
#         --apple-id "you@example.com" --team-id "TEAMID" \
#         --password "app-specific-password"
#
# Usage:
#   CODESIGN_IDENTITY="Developer ID Application: NAME (TEAMID)" \
#   NOTARY_PROFILE="posture-notary" \
#   ./notarize.sh
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

: "${CODESIGN_IDENTITY:?Set CODESIGN_IDENTITY to your 'Developer ID Application: …' identity}"
PROFILE="${NOTARY_PROFILE:-posture-notary}"
APP="PostureTimer.app"
DMG="PostureTimer.dmg"

# 1. Build + Developer ID sign the app with hardened runtime.
export CODESIGN_IDENTITY
./build.sh release

# 2. Notarize the app, then staple the ticket into the bundle.
echo "▸ Notarizing app…"
ZIP="PostureTimer-notarize.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
rm -f "$ZIP"
xcrun stapler staple "$APP"

# 3. Build the DMG around the stapled app (no rebuild — that would void the staple).
echo "▸ Building DMG…"
rm -f "$DMG"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "PostureTimer" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG"

# 4. Notarize the DMG and staple it.
echo "▸ Notarizing DMG…"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"

echo "✓ Notarized & stapled $DMG"
spctl -a -vvv -t open --context context:primary-signature "$DMG" 2>&1 | head -3
