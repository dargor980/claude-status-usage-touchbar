#!/bin/zsh

set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "Usage: $0 <binary-path> <output-dir> <version> [bundle-name]"
  exit 1
fi

BINARY_PATH="$1"
OUTPUT_DIR="$2"
VERSION="$3"
BUNDLE_NAME="${4:-claudeBar.app}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_DIR="$OUTPUT_DIR/$BUNDLE_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY_PATH" "$MACOS_DIR/claudebar"
chmod +x "$MACOS_DIR/claudebar"
cp "$REPO_ROOT/claudebar.config.json" "$RESOURCES_DIR/claudebar.config.json"

# Bundle the helper scripts so BTT actions can reference them via
# CLAUDEBAR_APP_PATH or a fixed Resources/scripts path.
BUNDLE_SCRIPTS_DIR="$RESOURCES_DIR/scripts"
mkdir -p "$BUNDLE_SCRIPTS_DIR"
for py in \
  claudebar_btt_widget.py \
  claudebar_btt_action.py \
  claudebar_statusline_capture.py; do
  [[ -f "$REPO_ROOT/scripts/$py" ]] && cp "$REPO_ROOT/scripts/$py" "$BUNDLE_SCRIPTS_DIR/$py"
done

# Bundle the generated preset if it exists.
[[ -f "$REPO_ROOT/claudebar.bttpreset" ]] && \
  cp "$REPO_ROOT/claudebar.bttpreset" "$RESOURCES_DIR/claudebar.bttpreset"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>claudeBar</string>
  <key>CFBundleExecutable</key>
  <string>claudebar</string>
  <key>CFBundleIdentifier</key>
  <string>com.germancontreras.claudebar</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>claudeBar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <!-- Hide from Dock; claudeBar lives exclusively in the menu bar. -->
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <!-- Required so macOS shows a meaningful prompt when claudeBar
       uses JXA/AppleScript to push updates to BetterTouchTool. -->
  <key>NSAppleEventsUsageDescription</key>
  <string>claudeBar needs to communicate with BetterTouchTool to update Touch Bar widgets.</string>
</dict>
</plist>
EOF

echo "Created app bundle at $APP_DIR"
