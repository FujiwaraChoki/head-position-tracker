#!/bin/bash
# Regenerates AppIcon.icns from the SF Symbol defined in make_icon.swift.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

swift make_icon.swift
iconutil -c icns AppIcon.iconset -o AppIcon.icns
rm -rf AppIcon.iconset
echo "✓ AppIcon.icns"
