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

# 版本号注入：APP_VERSION 环境变量覆盖产物版本；未设置时保留仓库根 Info.plist 的默认值
if [[ -n "${APP_VERSION:-}" ]]; then
  if ! [[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "APP_VERSION must be semver x.y.z (got: $APP_VERSION). Pre-release tags go directly in the root Info.plist." >&2
    exit 1
  fi
  PLIST="$BUNDLE/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${APP_VERSION//./}" "$PLIST"
fi

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
