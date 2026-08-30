#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP_NAME="Ops Notch"
PRODUCT="OpsNotch"
BUNDLE="$ROOT/dist/$APP_NAME.app"
MODE="${1:-}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Ops Notch Native requires macOS."
  exit 1
fi

pkill -x "$PRODUCT" 2>/dev/null || true
swift build
BIN_DIR="$(swift build --show-bin-path)"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN_DIR/$PRODUCT" "$BUNDLE/Contents/MacOS/$PRODUCT"
cp "$ROOT/Info.plist" "$BUNDLE/Contents/Info.plist"
if command -v iconutil >/dev/null 2>&1; then
  iconutil -c icns "$ROOT/Assets/AppIcon.iconset" -o "$BUNDLE/Contents/Resources/AppIcon.icns" || true
fi
codesign --force --deep --sign - "$BUNDLE" >/dev/null 2>&1 || true

case "$MODE" in
  --debug)
    exec lldb "$BUNDLE/Contents/MacOS/$PRODUCT"
    ;;
  --logs)
    /usr/bin/open -n "$BUNDLE"
    exec /usr/bin/log stream --info --predicate 'process == "OpsNotch"'
    ;;
  --telemetry)
    /usr/bin/open -n "$BUNDLE"
    exec /usr/bin/log stream --info --predicate 'process == "OpsNotch"'
    ;;
  --verify)
    /usr/bin/open -n "$BUNDLE"
    sleep 1
    pgrep -x "$PRODUCT" >/dev/null
    echo "PASS: $APP_NAME is running"
    ;;
  *)
    /usr/bin/open -n "$BUNDLE"
    echo "Launched: $BUNDLE"
    ;;
esac
