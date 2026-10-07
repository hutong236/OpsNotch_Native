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

# 版本号注入：Git prerelease tag 与 macOS Bundle 版本分离。
# APP_VERSION 必须保持 numeric x.y.z；APP_BUILD 默认沿用旧的去点规则，也可由 release parser 显式传入。
if [[ -n "${APP_VERSION:-}" ]]; then
  if ! [[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "APP_VERSION must be numeric semver x.y.z (got: $APP_VERSION)."
    exit 1
  fi
  APP_BUILD_VALUE="${APP_BUILD:-${APP_VERSION//./}}"
  if ! [[ "$APP_BUILD_VALUE" =~ ^[0-9]+$ ]]; then
    echo "APP_BUILD must contain digits only (got: $APP_BUILD_VALUE)."
    exit 1
  fi
  PLIST="$CONTENTS/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_BUILD_VALUE" "$PLIST"
fi

if command -v iconutil >/dev/null 2>&1; then
  iconutil -c icns "$ROOT/Assets/AppIcon.iconset" -o "$CONTENTS/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - "$APP"

echo "Built: $APP"
echo "Run:   open \"$APP\""
