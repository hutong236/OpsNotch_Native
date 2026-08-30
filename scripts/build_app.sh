#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This packaging script must run on macOS."
  exit 1
fi

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$ROOT/build/Ops Notch.app"
CONTENTS="$APP/Contents"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/OpsNotch" "$CONTENTS/MacOS/OpsNotch"
cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"

if command -v iconutil >/dev/null 2>&1; then
  iconutil -c icns "$ROOT/Assets/AppIcon.iconset" -o "$CONTENTS/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - "$APP"

echo "Built: $APP"
echo "Run:   open \"$APP\""
