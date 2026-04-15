#!/usr/bin/env python3

import json
import os
import subprocess
import sys
from pathlib import Path


def bridge_path():
    return Path(
        os.environ.get(
            "CLAUDEBAR_TOUCHBAR_BRIDGE_PATH",
            os.path.expanduser("~/.claude/claudebar-touchbar.json"),
        )
    )


def load_payload():
    path = bridge_path()
    if not path.exists():
        raise SystemExit("claudeBar bridge payload not found")
    return json.loads(path.read_text(encoding="utf-8"))


def resume():
    payload = load_payload()
    url = payload.get("resumeURL")
    if not url:
        raise SystemExit("claudeBar has no resume URL for the current session")
    subprocess.run(["open", url], check=True)


def show_dashboard():
    app_path = os.environ.get("CLAUDEBAR_APP_PATH")
    if app_path:
        subprocess.run(["open", app_path], check=True)
        return

    raise SystemExit(
        "Set CLAUDEBAR_APP_PATH if you want BetterTouchTool to open claudeBar directly"
    )


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "resume"

    if action == "resume":
        resume()
        return

    if action == "dashboard":
        show_dashboard()
        return

    raise SystemExit(f"Unknown action: {action}")


if __name__ == "__main__":
    main()
