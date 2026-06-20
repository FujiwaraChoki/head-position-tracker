#!/bin/bash
#
# Builds PostureTimer and assembles a proper .app bundle so that:
#   - Info.plist (with NSMotionUsageDescription) is present, and
#   - the binary is code-signed,
# both of which macOS requires before it will hand over AirPods motion data.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP="PostureTimer.app"

echo "▸ Compiling ($CONFIG)…"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/PostureTimer"

echo "▸ Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/PostureTimer"
cp "Info.plist" "$APP/Contents/Info.plist"

if [ -f "AppIcon.icns" ]; then
  cp "AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
else
  echo "  (no AppIcon.icns — run ./make_icon.sh to generate one)"
fi

# Set CODESIGN_IDENTITY to a "Developer ID Application: …" identity to produce a
# distributable, hardened-runtime build. Defaults to ad-hoc signing for local use.
SIGN_ID="${CODESIGN_IDENTITY:--}"
if [ "$SIGN_ID" = "-" ]; then
  echo "▸ Code-signing (ad-hoc)…"
  codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 || \
    codesign --force --sign - "$APP"
else
  echo "▸ Code-signing (Developer ID, hardened runtime)…"
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
fi

echo "✓ Built $APP"
echo "  Run it with:  open $APP"
echo "  (Put your AirPods in first. macOS will ask for Motion & Fitness permission on the first focus session.)"
