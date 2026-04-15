#!/usr/bin/env python3

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def to_capture_window(window):
    if not isinstance(window, dict):
        return None

    used_percentage = window.get("used_percentage")
    resets_at = window.get("resets_at")

    if used_percentage is None:
        return None

    return {
        "used_percentage": used_percentage,
        "resets_at": resets_at,
    }


def format_percent(window):
    if not isinstance(window, dict):
        return "--"

    value = window.get("used_percentage")
    if value is None:
        return "--"

    if isinstance(value, (int, float)):
        return f"{value:.0f}%"

    return str(value)


def main():
    raw_input = sys.stdin.read()
    if not raw_input.strip():
        print("claudeBar")
        return

    payload = json.loads(raw_input)
    rate_limits = payload.get("rate_limits") or {}

    capture_payload = {
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "model": payload.get("model"),
        "session_id": payload.get("session_id"),
        "rate_limits": {
            "five_hour": to_capture_window(rate_limits.get("five_hour")),
            "seven_day": to_capture_window(rate_limits.get("seven_day")),
        },
    }

    output_path = Path(
        os.environ.get(
            "CLAUDEBAR_STATUSLINE_CAPTURE_PATH",
            os.path.expanduser("~/.claude/claudebar-statusline.json"),
        )
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(capture_payload), encoding="utf-8")

    print(
        "claudeBar 5h {five} · 7d {seven}".format(
            five=format_percent(rate_limits.get("five_hour")),
            seven=format_percent(rate_limits.get("seven_day")),
        )
    )


if __name__ == "__main__":
    main()
