#!/usr/bin/env python3

import json
import os
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
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "title"
    payload = load_payload()

    if payload is None:
        print("claudeBar --")
        return

    if mode == "task":
        print(payload.get("compactTask") or "claudeBar · sin tarea")
        return

    if mode == "session":
        session = payload.get("session") or {}
        print(session.get("projectName") or "Sin sesion")
        return

    if mode == "json":
        print(json.dumps(payload))
        return

    print(payload.get("compactTitle") or "claudeBar --")


if __name__ == "__main__":
    main()
