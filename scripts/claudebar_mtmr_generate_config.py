#!/usr/bin/env python3
"""
Generate an MTMR (My TouchBar My Rules) configuration snippet for claudeBar.

Usage:
    python3 scripts/claudebar_mtmr_generate_config.py

MTMR is an open-source Touch Bar customizer (github.com/Toxblh/MTMR).
Install with:  brew install --cask mtmr

The generated snippet adds two claudeBar items to the Touch Bar:
  - Title chip: usage percentages, tapping opens the active Claude session
  - Task chip:  current task description

After generating, merge the snippet into MTMR's items.json:
    ~/Library/Application Support/MTMR/items.json

Or open MTMR → right-click menu bar icon → Preferences → paste into editor.
"""

import json
import os
import stat
import sys
from pathlib import Path


def main() -> None:
    scripts_dir = Path(__file__).parent.resolve()

    # Ensure the Python helper scripts are executable so MTMR can call them
    # directly (MTMR executes filePath as a process, not via a shell).
    for name in ("claudebar_btt_widget.py", "claudebar_btt_action.py"):
        path = scripts_dir / name
        if path.exists():
            path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    widget_py = str(scripts_dir / "claudebar_btt_widget.py")
    action_py = str(scripts_dir / "claudebar_btt_action.py")

    # MTMR calls filePath as an executable.  The Python scripts have a
    # #!/usr/bin/env python3 shebang so they run directly once chmod +x'd.
    # We pass the mode argument via a thin wrapper script for clarity.
    title_sh = _write_wrapper(scripts_dir, "claudebar_mtmr_title.sh",
                              f"/usr/bin/python3 {widget_py} title")
    task_sh  = _write_wrapper(scripts_dir, "claudebar_mtmr_task.sh",
                              f"/usr/bin/python3 {widget_py} task")
    resume_sh = _write_wrapper(scripts_dir, "claudebar_mtmr_resume.sh",
                               f"/usr/bin/python3 {action_py} resume")

    items = _build_items(title_sh, task_sh, resume_sh)

    out = Path(__file__).parent.parent / "claudebar-mtmr.json"
    out.write_text(json.dumps(items, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"MTMR snippet written to: {out}")
    print()
    print("Installation:")
    print("  1. brew install --cask mtmr")
    print("  2. Launch MTMR and allow accessibility permissions when prompted.")
    print("  3. Right-click the MTMR icon in the menu bar -> Preferences")
    print(f"     Paste the contents of {out} into the editor")
    print("     (merge with existing items — keep 'escape' and other items you want)")
    print("  4. Click 'Touch it!' to apply.")
    print()
    print("claudeBar writes the bridge file automatically.")
    print("MTMR polls it every 2 seconds — no BTT required.")


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


def _build_items(title_sh: str, task_sh: str, resume_sh: str) -> list:
    return [
        {
            "_comment": "claudeBar — usage title + resume action",
            "type": "shellScriptTitledButton",
            "source": {"filePath": title_sh},
            "refreshInterval": 2,
            "align": "left",
            "width": 220,
            "bordered": False,
            "action": {"type": "shellScript", "filePath": resume_sh},
        },
        {
            "_comment": "claudeBar — current task",
            "type": "shellScriptTitledButton",
            "source": {"filePath": task_sh},
            "refreshInterval": 2,
            "align": "left",
            "width": 200,
            "bordered": False,
        },
    ]


if __name__ == "__main__":
    main()
