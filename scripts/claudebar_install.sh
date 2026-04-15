#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# claudebar_install.sh
#
# Installs claudeBar as a macOS login item via launchd.
# After running this script, claudeBar starts automatically at login and
# restarts if it crashes.
#
# Usage:
#   bash scripts/claudebar_install.sh
#
# The script builds claudeBar, writes a LaunchAgent plist, and loads it.
# Uninstall:
#   launchctl unload ~/Library/LaunchAgents/com.claudebar.plist
#   rm ~/Library/LaunchAgents/com.claudebar.plist
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BINARY_PATH="$REPO_DIR/.build/scratch/arm64-apple-macosx/debug/claudebar"
PLIST_PATH="$HOME/Library/LaunchAgents/com.claudebar.plist"
LABEL="com.claudebar"

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
echo "==> Building claudeBar…"
CLANG_MODULE_CACHE_PATH="$REPO_DIR/.build/module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$REPO_DIR/.build/module-cache" \
/Library/Developer/CommandLineTools/usr/bin/swift build \
  --scratch-path "$REPO_DIR/.build/scratch" 2>&1 | grep -E "^(error:|warning: |Build complete)"

if [[ ! -f "$BINARY_PATH" ]]; then
  echo "ERROR: binary not found at $BINARY_PATH" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# BetterTouchTool widget UUIDs (defaults to canonical preset UUIDs)
# ---------------------------------------------------------------------------
TITLE_UUID="${CLAUDEBAR_BTT_TITLE_WIDGET_UUID:-CB000001-CB00-CB00-CB00-CB0000000001}"
TASK_UUID="${CLAUDEBAR_BTT_TASK_WIDGET_UUID:-CB000001-CB00-CB00-CB00-CB0000000002}"

echo ""
echo "==> Configuring with BTT widget UUIDs:"
echo "      Title : $TITLE_UUID"
echo "      Task  : $TASK_UUID"
echo ""
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
    <string>${BINARY_PATH}</string>
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

echo "==> LaunchAgent written to: $PLIST_PATH"

# ---------------------------------------------------------------------------
# Load / reload agent
# ---------------------------------------------------------------------------
if launchctl list "$LABEL" &>/dev/null; then
  echo "==> Reloading existing agent…"
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
fi

launchctl load "$PLIST_PATH"
echo "==> claudeBar loaded and running."
echo ""
echo "    Logs:  /tmp/claudebar.stdout.log  /tmp/claudebar.stderr.log"
echo ""
echo "To uninstall:"
echo "  launchctl unload $PLIST_PATH && rm $PLIST_PATH"
