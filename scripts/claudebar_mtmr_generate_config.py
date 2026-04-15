#!/usr/bin/env python3
"""
Generate an MTMR (My TouchBar My Rules) configuration snippet for claudeBar.

Usage:
    python3 scripts/claudebar_mtmr_generate_config.py           # snippet only
    python3 scripts/claudebar_mtmr_generate_config.py --install # merge into MTMR config

MTMR is an open-source Touch Bar customizer (github.com/Toxblh/MTMR).
Install with:  brew install --cask mtmr

The generated snippet adds two claudeBar items to the Touch Bar:
  - Title chip: usage percentages, tapping opens the active Claude session
  - Task chip:  current task description

With --install, the script writes directly to:
    ~/Library/Application Support/MTMR/items.json
(existing items are preserved; claudeBar items are replaced if already present)
"""

import json
import os
import stat
import sys
from pathlib import Path

MTMR_ITEMS_PATH = (
    Path.home() / "Library" / "Application Support" / "MTMR" / "items.json"
)
_CLAUDEBAR_MARKER = "claudeBar"


def main() -> None:
    install_mode = "--install" in sys.argv

    scripts_dir = Path(__file__).parent.resolve()

    for name in ("claudebar_btt_widget.py", "claudebar_btt_action.py"):
        path = scripts_dir / name
        if path.exists():
            path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    widget_py = str(scripts_dir / "claudebar_btt_widget.py")
    action_py = str(scripts_dir / "claudebar_btt_action.py")

    title_sh      = _write_wrapper(scripts_dir, "claudebar_mtmr_title.sh",
                                   f"/usr/bin/python3 {widget_py} title")
    session_pct_sh = _write_wrapper(scripts_dir, "claudebar_mtmr_session_pct.sh",
                                    f"/usr/bin/python3 {widget_py} session_pct")
    week_pct_sh   = _write_wrapper(scripts_dir, "claudebar_mtmr_week_pct.sh",
                                   f"/usr/bin/python3 {widget_py} week_pct")
    task_sh       = _write_wrapper(scripts_dir, "claudebar_mtmr_task.sh",
                                   f"/usr/bin/python3 {widget_py} task")
    resume_sh     = _write_wrapper(scripts_dir, "claudebar_mtmr_resume.sh",
                                   f"/usr/bin/python3 {action_py} resume")

    claudebar_items = _build_items(session_pct_sh, week_pct_sh, task_sh, resume_sh)

    # Always write the standalone snippet.
    out = Path(__file__).parent.parent / "claudebar-mtmr.json"
    out.write_text(json.dumps(claudebar_items, indent=2, ensure_ascii=False),
                   encoding="utf-8")
    print(f"Snippet written to: {out}")

    if install_mode:
        _merge_into_mtmr(claudebar_items)
    else:
        print()
        print("To install automatically, run:")
        print("  python3 scripts/claudebar_mtmr_generate_config.py --install")
        print()
        print("Or manually:")
        print("  MTMR -> right-click icon -> Preferences -> paste claudebar-mtmr.json")
        print("  Click 'Touch it!' to apply.")


# ---------------------------------------------------------------------------
# MTMR items.json merge
# ---------------------------------------------------------------------------

def _merge_into_mtmr(claudebar_items: list) -> None:
    MTMR_ITEMS_PATH.parent.mkdir(parents=True, exist_ok=True)

    if MTMR_ITEMS_PATH.exists():
        try:
            existing = json.loads(MTMR_ITEMS_PATH.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            existing = []
        # Back up before modifying.
        backup = MTMR_ITEMS_PATH.with_suffix(".json.bak")
        backup.write_text(json.dumps(existing, indent=2, ensure_ascii=False),
                          encoding="utf-8")
        print(f"Backup written to: {backup}")
    else:
        # Fresh install — start with escape key.
        existing = [{"type": "escape", "width": 32}]

    # Remove any existing claudeBar items so re-runs are idempotent.
    kept = [i for i in existing
            if _CLAUDEBAR_MARKER not in i.get("_comment", "")]

    # Insert claudeBar items right after the 'escape' key if present.
    insert_at = 1 if kept and kept[0].get("type") == "escape" else 0
    for offset, item in enumerate(claudebar_items):
        kept.insert(insert_at + offset, item)

    MTMR_ITEMS_PATH.write_text(json.dumps(kept, indent=2, ensure_ascii=False),
                                encoding="utf-8")
    print(f"Installed {len(claudebar_items)} claudeBar items into {MTMR_ITEMS_PATH}")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _write_wrapper(scripts_dir: Path, name: str, command: str) -> str:
    path = scripts_dir / name
    path.write_text(
        f"#!/usr/bin/env bash\nexec {command}\n",
        encoding="utf-8",
    )
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    return str(path)


def _build_items(
    session_pct_sh: str,
    week_pct_sh: str,
    task_sh: str,
    resume_sh: str,
) -> list:
    base = {"refreshInterval": 2, "bordered": False}
    return [
        {
            **base,
            "_comment": "claudeBar — session usage (tap = resume)",
            "type": "shellScriptTitledButton",
            "source": {"filePath": session_pct_sh},
            "align": "center",
            "width": 90,
            "action": {"type": "shellScript", "filePath": resume_sh},
        },
        {
            **base,
            "_comment": "claudeBar — weekly usage",
            "type": "shellScriptTitledButton",
            "source": {"filePath": week_pct_sh},
            "align": "center",
            "width": 90,
        },
        {
            **base,
            "_comment": "claudeBar — current task",
            "type": "shellScriptTitledButton",
            "source": {"filePath": task_sh},
            "align": "left",
            "width": 180,
        },
    ]


if __name__ == "__main__":
    main()
