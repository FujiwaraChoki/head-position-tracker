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

SIZE="$(du -h "$DMG" | cut -f1)"
echo "✓ Built ${DMG} (${SIZE})"
echo "  Open it, then drag PostureTimer to Applications."
