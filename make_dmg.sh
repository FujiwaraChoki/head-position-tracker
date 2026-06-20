#!/bin/bash
#
# Builds PostureTimer.app (via build.sh) and packages it into a distributable,
# compressed disk image with a drag-to-Applications shortcut.
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP="PostureTimer.app"
VOL="PostureTimer"
DMG="PostureTimer.dmg"

# Ensure we have a fresh, signed app bundle.
./build.sh release

echo "▸ Staging disk image…"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "▸ Creating ${DMG}…"
rm -f "$DMG"
hdiutil create \
    -volname "$VOL" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG" >/dev/null

# Sign the disk image itself with the same Developer ID, when one is configured.
SIGN_ID="${CODESIGN_IDENTITY:--}"
if [ "$SIGN_ID" != "-" ]; then
  echo "▸ Signing ${DMG} (Developer ID)…"
  codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
  codesign --verify --verbose=2 "$DMG"
fi

SIZE="$(du -h "$DMG" | cut -f1)"
echo "✓ Built ${DMG} (${SIZE})"
echo "  Open it, then drag PostureTimer to Applications."
