#!/usr/bin/env python3
"""
Generate a BetterTouchTool preset (.bttpreset) for claudeBar Touch Bar widgets.

Usage:
    python3 scripts/claudebar_btt_generate_preset.py [--scripts-dir PATH]

The generated preset contains two Touch Bar widgets:
  - claudeBar title widget  (shows usage + session info, tap = resume session)
  - claudeBar task widget   (shows current task)

Both widgets use fixed canonical UUIDs so that claudeBar can push direct updates
without requiring UUID env var configuration.  After importing the preset into
BetterTouchTool, launching claudeBar without any env vars is sufficient.

Tested with BetterTouchTool 4.x.  Field names may vary in older versions.
"""

import json
import os
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Canonical widget UUIDs.
# These are embedded in the preset and referenced by claudeBar as defaults
# when CLAUDEBAR_BTT_TITLE_WIDGET_UUID / CLAUDEBAR_BTT_TASK_WIDGET_UUID are
# not set.  Keep these stable across versions.
# ---------------------------------------------------------------------------
TITLE_WIDGET_UUID = "CB000001-CB00-CB00-CB00-CB0000000001"
TASK_WIDGET_UUID = "CB000001-CB00-CB00-CB00-CB0000000002"


def main() -> None:
    scripts_dir = (
        Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent.resolve()
    )

    widget_py = str(scripts_dir / "claudebar_btt_widget.py")
    action_py = str(scripts_dir / "claudebar_btt_action.py")

    preset = [
        _title_widget(widget_py, action_py),
        _task_widget(widget_py),
    ]

    out = Path(__file__).parent.parent / "claudebar.bttpreset"
    out.write_text(json.dumps(preset, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"Preset written to: {out}")
    print()
    print(f"Title widget UUID : {TITLE_WIDGET_UUID}")
    print(f"Task widget UUID  : {TASK_WIDGET_UUID}")
    print()
    print("Next steps:")
    print("  1. Open BetterTouchTool → Preferences → Presets → Import Preset")
    print(f"     Select: {out}")
    print("  2. Enable the two new 'claudeBar' widgets in Touch Bar.")
    print("  3. Launch claudeBar (no extra env vars needed with this preset):")
    exe = Path(__file__).parent.parent / ".build/scratch/arm64-apple-macosx/debug/claudebar"
    print(f"     {exe}")
    print()
    print("claudeBar defaults to the canonical UUIDs above when the")
    print("CLAUDEBAR_BTT_TITLE_WIDGET_UUID env var is absent.")


# ---------------------------------------------------------------------------
# Widget builders
# ---------------------------------------------------------------------------

def _title_widget(widget_py: str, action_py: str) -> dict:
    """
    Touch Bar shell-script widget that shows usage/session title.

    BTTTriggerType 642 = Shell Script / Task Touch Bar button.
    The button polls BTTShellTaskActionScript for its display text.
    BTTPredefinedActionType 206 = Run Shell Script on tap.

    Note: BTT uses BTTShellTaskActionScript for *both* the polling display
    script and the tap action when no separate action field is available.
    In BTT 4.x the tap action takes precedence, so we rely on claudeBar's
    push updates (update_touch_bar_widget) for real-time text and use the
    polling script only as a first-render / fallback.
    """
    return {
        "BTTTriggerType": 642,
        "BTTTriggerClass": "BTTTriggerTypeTouchBar",
        "BTTPredefinedActionType": 206,
        "BTTPredefinedActionName": "Run Shell Script / Task",
        "BTTShellTaskActionScript": f"/usr/bin/python3 {action_py} resume",
        "BTTTouchBarButtonName": "claudeBar ⟳",
        "BTTTouchBarButtonColor": "75, 75, 75, 255.000000",
        "BTTTouchBarAlwaysShowButton": 0,
        "BTTEnabled2": 1,
        "BTTEnabled": 1,
        "BTTUUID": TITLE_WIDGET_UUID,
        "BTTRefreshInterval": 2,
        "BTTOrder": 0,
        "BTTDisplayOrder": 0,
        "BTTRequiredModifierKeys": [],
    }


def _task_widget(widget_py: str) -> dict:
    """
    Touch Bar shell-script widget that shows the current task.
    No tap action; updated solely via claudeBar push.
    """
    return {
        "BTTTriggerType": 642,
        "BTTTriggerClass": "BTTTriggerTypeTouchBar",
        "BTTPredefinedActionType": -1,
        "BTTPredefinedActionName": "No Action",
        "BTTShellTaskActionScript": f"/usr/bin/python3 {widget_py} task",
        "BTTTouchBarButtonName": "⟳",
        "BTTTouchBarButtonColor": "50, 50, 50, 255.000000",
        "BTTTouchBarAlwaysShowButton": 0,
        "BTTEnabled2": 1,
        "BTTEnabled": 1,
        "BTTUUID": TASK_WIDGET_UUID,
        "BTTRefreshInterval": 2,
        "BTTOrder": 1,
        "BTTDisplayOrder": 1,
        "BTTRequiredModifierKeys": [],
    }


if __name__ == "__main__":
    main()
