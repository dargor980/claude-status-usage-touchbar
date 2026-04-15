#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# claudebar_install.sh
#
# Builds claudeBar, creates an app bundle, and installs it as a macOS login
# item via launchd.  After running this script claudeBar starts at login and
# restarts on crash.
#
# Usage:
#   bash scripts/claudebar_install.sh [--app-dir DIR]
#
#   --app-dir DIR   Where to place claudeBar.app (default: ~/Applications)
#
# Override BTT widget UUIDs (canonical preset UUIDs are used by default):
#   CLAUDEBAR_BTT_TITLE_WIDGET_UUID=<uuid> bash scripts/claudebar_install.sh
#   CLAUDEBAR_BTT_TASK_WIDGET_UUID=<uuid>  bash scripts/claudebar_install.sh
#
# Uninstall:
#   launchctl unload ~/Library/LaunchAgents/com.claudebar.plist
#   rm ~/Library/LaunchAgents/com.claudebar.plist
#   rm -rf ~/Applications/claudeBar.app   # or wherever you installed it
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BINARY_PATH="$REPO_DIR/.build/scratch/arm64-apple-macosx/debug/claudebar"
PLIST_PATH="$HOME/Library/LaunchAgents/com.claudebar.plist"
LABEL="com.claudebar"
APP_DIR="$HOME/Applications"

# Parse optional --app-dir argument.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-dir) APP_DIR="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

APP_PATH="$APP_DIR/claudeBar.app"
APP_BINARY="$APP_PATH/Contents/MacOS/claudebar"

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
echo "==> Building claudeBar..."
CLANG_MODULE_CACHE_PATH="$REPO_DIR/.build/module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$REPO_DIR/.build/module-cache" \
/Library/Developer/CommandLineTools/usr/bin/swift build \
  --scratch-path "$REPO_DIR/.build/scratch" 2>&1 | grep -E "^(error:|Build complete)"

if [[ ! -f "$BINARY_PATH" ]]; then
  echo "ERROR: binary not found at $BINARY_PATH" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Create app bundle
# ---------------------------------------------------------------------------
echo "==> Creating app bundle at $APP_PATH..."
mkdir -p "$APP_DIR"
rm -rf "$APP_PATH"
"$REPO_DIR/scripts/build-app-bundle.sh" "$BINARY_PATH" "$APP_DIR" "0.1.0"

# ---------------------------------------------------------------------------
# BetterTouchTool widget UUIDs (defaults to canonical preset UUIDs)
# ---------------------------------------------------------------------------
TITLE_UUID="${CLAUDEBAR_BTT_TITLE_WIDGET_UUID:-CB000001-CB00-CB00-CB00-CB0000000001}"
TASK_UUID="${CLAUDEBAR_BTT_TASK_WIDGET_UUID:-CB000001-CB00-CB00-CB00-CB0000000002}"

echo ""
echo "==> Configuring with BTT widget UUIDs:"
echo "      Title : $TITLE_UUID"
echo "      Task  : $TASK_UUID"
echo "    (Override with CLAUDEBAR_BTT_TITLE_WIDGET_UUID / CLAUDEBAR_BTT_TASK_WIDGET_UUID)"

# ---------------------------------------------------------------------------
# Write LaunchAgent plist
# ---------------------------------------------------------------------------
mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>

  <key>ProgramArguments</key>
  <array>
    <string>${APP_BINARY}</string>
  </array>

  <key>EnvironmentVariables</key>
  <dict>
    <key>CLAUDEBAR_BTT_TITLE_WIDGET_UUID</key>
    <string>${TITLE_UUID}</string>
    <key>CLAUDEBAR_BTT_TASK_WIDGET_UUID</key>
    <string>${TASK_UUID}</string>
  </dict>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>

  <key>StandardOutPath</key>
  <string>/tmp/claudebar.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/claudebar.stderr.log</string>

  <key>ThrottleInterval</key>
  <integer>5</integer>
</dict>
</plist>
PLIST

echo "==> LaunchAgent written to $PLIST_PATH"

# ---------------------------------------------------------------------------
# Load / reload agent
# ---------------------------------------------------------------------------
if launchctl list "$LABEL" &>/dev/null; then
  echo "==> Reloading existing agent..."
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
fi

launchctl load "$PLIST_PATH"
echo "==> claudeBar loaded and running."
echo ""
echo "    App  : $APP_PATH"
echo "    Logs : /tmp/claudebar.stdout.log  /tmp/claudebar.stderr.log"
echo ""
echo "To uninstall:"
echo "  launchctl unload $PLIST_PATH && rm $PLIST_PATH"
echo "  rm -rf $APP_PATH"
