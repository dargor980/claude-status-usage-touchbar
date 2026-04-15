#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# setup_mtmr.sh
#
# One-command installer for claudeBar + MTMR Touch Bar integration.
#
# What it does:
#   1. Builds claudeBar and installs it as a macOS login item
#   2. Installs MTMR (open-source Touch Bar customizer) via Homebrew
#   3. Writes claudeBar widgets into MTMR's items.json
#   4. Restarts MTMR so changes take effect
#
# Usage:
#   bash scripts/setup_mtmr.sh
#
# Requirements:
#   - Homebrew (brew.sh)
#   - Swift Command Line Tools
#   - macOS 13+
#
# To uninstall:
#   launchctl unload ~/Library/LaunchAgents/com.claudebar.plist
#   rm ~/Library/LaunchAgents/com.claudebar.plist
#   rm -rf ~/Applications/claudeBar.app
#   brew uninstall --cask mtmr   # optional
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ---------------------------------------------------------------------------
# Step 1: claudeBar
# ---------------------------------------------------------------------------
echo "=== Step 1/4: Installing claudeBar ==="
bash "$REPO_DIR/scripts/claudebar_install.sh"

# ---------------------------------------------------------------------------
# Step 2: MTMR
# ---------------------------------------------------------------------------
echo ""
echo "=== Step 2/4: Installing MTMR ==="

MTMR_APP="/Applications/MTMR.app"

if [[ -d "$MTMR_APP" ]]; then
    echo "    MTMR already installed at $MTMR_APP"
else
    if ! command -v brew &>/dev/null; then
        echo "ERROR: Homebrew not found. Install it from https://brew.sh and re-run." >&2
        exit 1
    fi
    brew install --cask mtmr
fi

# ---------------------------------------------------------------------------
# Step 3: Generate wrappers + merge into MTMR items.json
# ---------------------------------------------------------------------------
echo ""
echo "=== Step 3/4: Configuring MTMR ==="
python3 "$REPO_DIR/scripts/claudebar_mtmr_generate_config.py" --install

# ---------------------------------------------------------------------------
# Step 4: Restart MTMR
# ---------------------------------------------------------------------------
echo ""
echo "=== Step 4/4: Starting MTMR ==="

# Kill any running instance so it reloads the config.
if pgrep -x MTMR &>/dev/null; then
    echo "    Restarting MTMR..."
    killall MTMR 2>/dev/null || true
    sleep 1
fi

open "$MTMR_APP"
echo "    MTMR launched."

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  Setup complete."
echo ""
echo "  claudeBar is running as a login item and will start"
echo "  automatically at every login."
echo ""
echo "  MTMR shows two persistent Touch Bar widgets:"
echo "    - Usage + session (tap to resume)"
echo "    - Current task"
echo ""
echo "  If macOS prompts for Accessibility permission, grant it"
echo "  to MTMR so it can control the Touch Bar."
echo "============================================================"
