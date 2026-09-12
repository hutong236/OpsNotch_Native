#!/bin/bash
set -euo pipefail

DEMO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DEMO_ROOT"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "FinderSpaceDemo requires macOS and the Xcode Command Line Tools."
  exit 1
fi
DEMO_MODE="${1:---run}"
case "$DEMO_MODE" in
  --run|--build-only|--probe) ;;
  *) echo "Usage: $0 [--run|--build-only|--probe]"; exit 2 ;;
esac
if [[ "$DEMO_MODE" == "--run" ]]; then
  pkill -x FinderSpaceDemo 2>/dev/null || true
fi
swift build --product FinderSpaceDemo
DEMO_BIN_DIR="$(swift build --show-bin-path)"
DEMO_APP="$DEMO_ROOT/dist/FinderSpaceDemo.app"
mkdir -p "$DEMO_APP/Contents/MacOS"
cp "$DEMO_BIN_DIR/FinderSpaceDemo" "$DEMO_APP/Contents/MacOS/FinderSpaceDemo"
DEMO_COMMIT="$(git rev-parse HEAD)"
cat > "$DEMO_APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>FinderSpaceDemo</string>
  <key>CFBundleIdentifier</key><string>lab.hutong.opsnotch.finder-space-demo</string>
  <key>CFBundleName</key><string>FinderSpaceDemo</string>
  <key>CFBundleShortVersionString</key><string>0.2.0</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>DemoSourceCommit</key><string>$DEMO_COMMIT</string>
</dict></plist>
EOF
codesign --force --sign - "$DEMO_APP"
codesign --verify --deep --strict "$DEMO_APP"
if [[ "$DEMO_MODE" == "--run" ]]; then
  open -n "$DEMO_APP"
elif [[ "$DEMO_MODE" == "--probe" ]]; then
  # Diagnostic CLI mode: use only a temporary window owned by the demo.
  "$DEMO_APP/Contents/MacOS/FinderSpaceDemo" --probe
else
  echo "Built: $DEMO_APP"
fi
