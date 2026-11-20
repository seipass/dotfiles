"""Read the newest Codex quota snapshot without accessing credentials."""
import json
import math
import os
from pathlib import Path


def snapshot(home):
    newest = {}
    files = sorted((home / "sessions").rglob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)
    for path in files[:12]:
        with path.open("rb") as stream:
            start = max(0, stream.seek(0, 2) - 2_000_000)
            stream.seek(start)
            if start:
                stream.readline()
            for line in stream:
                try:
                    event = json.loads(line)
                except (ValueError, UnicodeError):
                    continue
                if event.get("type") != "event_msg":
                    continue
                payload = event.get("payload") or {}
                limits = payload.get("rate_limits") or {}
                timestamp = event.get("timestamp") or ""
                if limits.get("limit_id") not in (None, "codex") or timestamp <= newest.get("timestamp", ""):
                    continue
                windows = []
                for name in ("primary", "secondary"):
                    window = limits.get(name) or {}
                    used = window.get("used_percent")
                    if isinstance(used, (int, float)) and math.isfinite(used):
                        windows.append({"used": min(100, max(0, used)), "minutes": window.get("window_minutes"),
                                        "reset": window.get("resets_at")})
                if windows:
                    newest = {"timestamp": timestamp, "windows": windows}
    return newest


if __name__ == "__main__":
    try:
        print(json.dumps(snapshot(Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")))))
    except OSError:
        print("{}")
