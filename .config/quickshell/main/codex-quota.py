"""Read current Codex limits through its local app server."""
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import select
import shutil
import subprocess
import time


def live_snapshot():
    cli = shutil.which("codex") or str(Path.home() / ".local/bin/codex")
    messages = [
        {"id": 1, "method": "initialize", "params": {"clientInfo": {"name": "quickshell-quota", "version": "1.0.0"}}},
        {"method": "initialized"},
        {"id": 2, "method": "account/rateLimits/read"},
    ]
    with subprocess.Popen([cli, "app-server"], stdin=subprocess.PIPE,
                          stdout=subprocess.PIPE, stderr=subprocess.DEVNULL) as proc:
        try:
            proc.stdin.write("".join(json.dumps(msg) + "\n" for msg in messages).encode())
            proc.stdin.flush()
            deadline = time.monotonic() + 8
            pending = b""
            while (remaining := deadline - time.monotonic()) > 0 and select.select([proc.stdout], [], [], remaining)[0]:
                chunk = os.read(proc.stdout.fileno(), 65536)
                if not chunk:
                    break
                pending += chunk
                while b"\n" in pending:
                    line, pending = pending.split(b"\n", 1)
                    response = json.loads(line)
                    if response.get("id") != 2:
                        continue
                    limits = (response.get("result") or {}).get("rateLimits") or {}
                    windows = [{"used": min(100, max(0, item["usedPercent"])),
                                "minutes": item["windowDurationMins"], "reset": item.get("resetsAt")}
                               for name in ("primary", "secondary")
                               if (item := limits.get(name)) and isinstance(item.get("usedPercent"), (int, float))
                               and item.get("windowDurationMins")]
                    timestamp = datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
                    return {"timestamp": timestamp, "windows": windows, "live": True} if windows else {}
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=1)
            except subprocess.TimeoutExpired:
                proc.kill()
        return {}


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
        current = live_snapshot()
    except (OSError, ValueError, subprocess.SubprocessError):
        current = {}
    try:
        print(json.dumps(current or snapshot(Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")))))
    except OSError:
        print("{}")
