#!/usr/bin/env python3
"""Collect usage and rate-limit snapshots across AI coding harnesses & providers."""
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import select
import shutil
import sqlite3
import subprocess
import time

NOW = time.time()
NOW_ISO = datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
WIN_5H = 5 * 3600
WIN_7D = 7 * 86400


def iso_from_ts(ts):
    if not ts or ts <= 0:
        return ""
    if ts > 1e12:
        ts /= 1000.0
    return datetime.fromtimestamp(ts, tz=timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def parse_ts(value):
    if isinstance(value, (int, float)):
        return value / 1000.0 if value > 1e12 else float(value)
    if isinstance(value, str) and value:
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
        except ValueError:
            return 0.0
    return 0.0


def fmt_tokens(n):
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M tok"
    if n >= 1_000:
        return f"{n / 1_000:.1f}k tok"
    return f"{n} tok"


# ── 1. Codex ──────────────────────────────────────────────────────────────────
def codex_live():
    cli = shutil.which("codex") or str(Path.home() / ".local/bin/codex")
    if not Path(cli).exists():
        return {}
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
            deadline = time.monotonic() + 5
            pending = b""
            while (remaining := deadline - time.monotonic()) > 0 and select.select([proc.stdout], [], [], remaining)[0]:
                chunk = os.read(proc.stdout.fileno(), 65536)
                if not chunk:
                    break
                pending += chunk
                while b"\n" in pending:
                    line, pending = pending.split(b"\n", 1)
                    try:
                        response = json.loads(line)
                    except ValueError:
                        continue
                    if response.get("id") != 2:
                        continue
                    result = response.get("result") or {}
                    limits = result.get("rateLimits") or {}
                    windows = []
                    for name in ("primary", "secondary"):
                        item = limits.get(name)
                        if item and isinstance(item.get("usedPercent"), (int, float)) and item.get("windowDurationMins"):
                            mins = item["windowDurationMins"]
                            label = f"{mins // 1440}d" if mins >= 1440 else f"{mins // 60}h"
                            used = min(100, max(0, item["usedPercent"]))
                            windows.append({
                                "label": label, "used": used, "minutes": mins,
                                "reset": item.get("resetsAt", 0),
                                "detail": f"{round(used)}% used",
                            })
                    reset_raw = result.get("rateLimitResetCredits") or {}
                    raw_credits = reset_raw.get("credits") or []
                    avail_credits = [
                        {
                            "id": c.get("id", ""),
                            "title": c.get("title") or "Full reset",
                            "expiresAt": c.get("expiresAt", 0),
                            "status": c.get("status", ""),
                        }
                        for c in raw_credits if c.get("status") == "available"
                    ]
                    avail_credits.sort(key=lambda c: c.get("expiresAt") or 9_999_999_999)
                    reset_bank = {
                        "available": int(reset_raw.get("availableCount", len(avail_credits))),
                        "credits": avail_credits,
                    }
                    return {"timestamp": NOW_ISO, "windows": windows, "live": True, "resetBank": reset_bank} if windows else {}
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=1)
            except subprocess.TimeoutExpired:
                proc.kill()
    return {}


def codex_local(home):
    newest = {}
    sessions = home / "sessions"
    if not sessions.is_dir():
        return {}
    files = sorted(sessions.rglob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)
    for path in files[:10]:
        try:
            with path.open("rb") as stream:
                start = max(0, stream.seek(0, 2) - 1_500_000)
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
                        w = limits.get(name) or {}
                        used = w.get("used_percent")
                        if isinstance(used, (int, float)) and math.isfinite(used):
                            mins = w.get("window_minutes") or (300 if name == "primary" else 10080)
                            label = f"{mins // 1440}d" if mins >= 1440 else f"{mins // 60}h"
                            clamped = min(100, max(0, used))
                            windows.append({
                                "label": label, "used": clamped, "minutes": mins,
                                "reset": w.get("resets_at", 0),
                                "detail": f"{round(clamped)}% used",
                            })
                    if windows:
                        newest = {"timestamp": timestamp, "windows": windows, "live": False}
        except OSError:
            continue
    return newest


def collect_codex():
    codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    installed = bool(shutil.which("codex") or (Path.home() / ".local/bin/codex").exists() or codex_home.is_dir())
    data = {}
    if installed:
        try:
            data = codex_live()
        except (OSError, ValueError, subprocess.SubprocessError):
            data = {}
        if not data:
            data = codex_local(codex_home)
    windows = data.get("windows") or []
    return {
        "id": "codex",
        "name": "Codex",
        "short": "CDX",
        "installed": installed,
        "live": bool(data.get("live")),
        "status": "Live" if data.get("live") else ("Local" if windows else ("Installed" if installed else "Not installed")),
        "windows": windows,
        "resetBank": data.get("resetBank"),
        "timestamp": data.get("timestamp", ""),
        "hasPercent": True,
    }


# ── 2. Antigravity ────────────────────────────────────────────────────────────
def collect_antigravity():
    home = Path.home()
    cli = shutil.which("agy") or shutil.which("antigravity") or str(home / ".local/bin/agy")
    agy_dir = home / ".gemini/antigravity-cli"
    installed = Path(cli).exists() or agy_dir.is_dir() or (home / ".gemini/antigravity").is_dir()
    c5h = c7d = 0
    sessions_7d = set()
    latest_ts = 0.0
    hist = agy_dir / "history.jsonl"
    if hist.is_file():
        try:
            for line in hist.read_text(errors="ignore").splitlines()[-2000:]:
                try:
                    item = json.loads(line)
                except ValueError:
                    continue
                ts = parse_ts(item.get("timestamp", 0))
                if ts > latest_ts:
                    latest_ts = ts
                age = NOW - ts
                if 0 <= age <= WIN_7D:
                    c7d += 1
                    cid = item.get("conversationId")
                    if cid:
                        sessions_7d.add(cid)
                    if age <= WIN_5H:
                        c5h += 1
        except OSError:
            pass
    windows = []
    if installed and (c5h > 0 or c7d > 0):
        windows = [
            {"label": "5h", "used": min(100, round(c5h / 40 * 100)), "minutes": 300, "reset": 0,
             "detail": f"{c5h} prompts"},
            {"label": "7d", "used": min(100, round(c7d / 300 * 100)), "minutes": 10080, "reset": 0,
             "detail": f"{c7d} prompts · {len(sessions_7d)} chats"},
        ]
    return {
        "id": "antigravity",
        "name": "Antigravity",
        "short": "AGY",
        "installed": installed,
        "live": False,
        "status": "Active" if c5h > 0 else ("Local" if c7d > 0 else ("Installed" if installed else "Not installed")),
        "windows": windows,
        "timestamp": iso_from_ts(latest_ts),
        "hasPercent": False,
    }


# ── 3. Opencode ───────────────────────────────────────────────────────────────
def collect_opencode():
    home = Path.home()
    db_path = home / ".local/share/opencode/opencode.db"
    installed = bool(shutil.which("opencode") or db_path.is_file() or (home / ".config/opencode").is_dir())
    c5h = c7d = 0
    limit_hit = False
    latest_ts = 0.0
    last_model = ""
    if db_path.is_file():
        try:
            conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=2)
            cur = conn.cursor()
            cutoff_7d_ms = int((NOW - WIN_7D) * 1000)
            cutoff_5h_ms = int((NOW - WIN_5H) * 1000)
            cur.execute(
                "SELECT time_created, data FROM session_message WHERE time_created >= ? ORDER BY time_created DESC LIMIT 1500",
                (cutoff_7d_ms,),
            )
            for ts_ms, raw in cur.fetchall():
                ts = ts_ms / 1000.0 if ts_ms > 1e12 else float(ts_ms)
                if ts > latest_ts:
                    latest_ts = ts
                try:
                    msg = json.loads(raw)
                except ValueError:
                    continue
                err = msg.get("error") or {}
                if err.get("type") == "provider.free-limit" or err.get("status") == 429:
                    if ts_ms >= cutoff_5h_ms:
                        limit_hit = True
                if msg.get("model"):
                    c7d += 1
                    if ts_ms >= cutoff_5h_ms:
                        c5h += 1
                    if not last_model:
                        last_model = msg["model"].get("id", "")
            conn.close()
        except (sqlite3.Error, OSError):
            pass
    windows = []
    if installed and (c5h > 0 or c7d > 0 or limit_hit):
        p5 = 100 if limit_hit else min(100, round(c5h / 50 * 100))
        d5 = "Limit reached (429)" if limit_hit else f"{c5h} reqs"
        d7 = f"{c7d} reqs" + (f" · {last_model}" if last_model else "")
        windows = [
            {"label": "5h", "used": p5, "minutes": 300, "reset": 0, "detail": d5, "alert": limit_hit},
            {"label": "7d", "used": min(100, round(c7d / 350 * 100)), "minutes": 10080, "reset": 0, "detail": d7},
        ]
    return {
        "id": "opencode",
        "name": "Opencode",
        "short": "OPC",
        "installed": installed,
        "live": False,
        "status": "Limit hit" if limit_hit else ("Active" if c5h > 0 else ("Local" if c7d > 0 else ("Installed" if installed else "Not installed"))),
        "windows": windows,
        "timestamp": iso_from_ts(latest_ts),
        "hasPercent": limit_hit,
    }


# ── 4. Claude Code ────────────────────────────────────────────────────────────
def collect_claude():
    home = Path.home()
    claude_dir = home / ".claude"
    installed = bool(shutil.which("claude") or claude_dir.is_dir())
    c5h = c7d = tok5h = tok7d = 0
    latest_ts = 0.0
    projects = claude_dir / "projects"
    if projects.is_dir():
        files = sorted(projects.rglob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)
        for path in files[:20]:
            try:
                if NOW - path.stat().st_mtime > WIN_7D:
                    continue
                for line in path.read_text(errors="ignore").splitlines():
                    try:
                        ev = json.loads(line)
                    except ValueError:
                        continue
                    ts = parse_ts(ev.get("timestamp", 0))
                    if ts > latest_ts:
                        latest_ts = ts
                    age = NOW - ts
                    if not (0 <= age <= WIN_7D):
                        continue
                    usage = (ev.get("message") or {}).get("usage") or {}
                    toks = int(usage.get("input_tokens", 0)) + int(usage.get("output_tokens", 0))
                    if toks > 0 or ev.get("type") == "assistant":
                        c7d += 1
                        tok7d += toks
                        if age <= WIN_5H:
                            c5h += 1
                            tok5h += toks
            except OSError:
                continue
    windows = []
    if installed and (c5h > 0 or c7d > 0):
        windows = [
            {"label": "5h", "used": min(100, round(c5h / 45 * 100)), "minutes": 300, "reset": 0,
             "detail": f"{c5h} msgs" + (f" · {fmt_tokens(tok5h)}" if tok5h else "")},
            {"label": "7d", "used": min(100, round(c7d / 300 * 100)), "minutes": 10080, "reset": 0,
             "detail": f"{c7d} msgs" + (f" · {fmt_tokens(tok7d)}" if tok7d else "")},
        ]
    return {
        "id": "claude",
        "name": "Claude Code",
        "short": "CLD",
        "installed": installed,
        "live": False,
        "status": "Active" if c5h > 0 else ("Local" if c7d > 0 else ("Installed" if installed else "Not installed")),
        "windows": windows,
        "timestamp": iso_from_ts(latest_ts),
        "hasPercent": False,
    }


# ── 5. Mistral (Vibe / Mistral CLI) ───────────────────────────────────────────
def collect_mistral():
    home = Path.home()
    dirs = [home / ".vibe", home / ".mistral", home / ".config/mistral"]
    installed = bool(shutil.which("vibe") or shutil.which("mistral") or any(d.is_dir() for d in dirs))
    c5h = c7d = 0
    latest_ts = 0.0
    for base in dirs:
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*.json*"), key=lambda p: p.stat().st_mtime, reverse=True)[:15]:
            try:
                mt = path.stat().st_mtime
                if mt > latest_ts:
                    latest_ts = mt
                age = NOW - mt
                if age <= WIN_7D:
                    c7d += 1
                    if age <= WIN_5H:
                        c5h += 1
            except OSError:
                continue
    windows = []
    if installed and (c5h > 0 or c7d > 0):
        windows = [
            {"label": "5h", "used": min(100, round(c5h / 20 * 100)), "minutes": 300, "reset": 0, "detail": f"{c5h} sessions"},
            {"label": "7d", "used": min(100, round(c7d / 100 * 100)), "minutes": 10080, "reset": 0, "detail": f"{c7d} sessions"},
        ]
    return {
        "id": "mistral",
        "name": "Mistral",
        "short": "MST",
        "installed": installed,
        "live": False,
        "status": "Active" if c5h > 0 else ("Local" if c7d > 0 else ("Installed" if installed else "Not installed")),
        "windows": windows,
        "timestamp": iso_from_ts(latest_ts),
        "hasPercent": False,
    }


# ── 6. Command Code ───────────────────────────────────────────────────────────
def collect_command_code():
    home = Path.home()
    dirs = [home / ".command-code", home / ".config/command-code"]
    installed = bool(shutil.which("command-code") or shutil.which("cmd") or any(d.is_dir() for d in dirs))
    c5h = c7d = 0
    latest_ts = 0.0
    for base in dirs:
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*.json*"), key=lambda p: p.stat().st_mtime, reverse=True)[:15]:
            try:
                mt = path.stat().st_mtime
                if mt > latest_ts:
                    latest_ts = mt
                age = NOW - mt
                if age <= WIN_7D:
                    c7d += 1
                    if age <= WIN_5H:
                        c5h += 1
            except OSError:
                continue
    windows = []
    if installed and (c5h > 0 or c7d > 0):
        windows = [
            {"label": "5h", "used": min(100, round(c5h / 20 * 100)), "minutes": 300, "reset": 0, "detail": f"{c5h} sessions"},
            {"label": "7d", "used": min(100, round(c7d / 100 * 100)), "minutes": 10080, "reset": 0, "detail": f"{c7d} sessions"},
        ]
    return {
        "id": "command-code",
        "name": "Command Code",
        "short": "CMD",
        "installed": installed,
        "live": False,
        "status": "Active" if c5h > 0 else ("Local" if c7d > 0 else ("Installed" if installed else "Not installed")),
        "windows": windows,
        "timestamp": iso_from_ts(latest_ts),
        "hasPercent": False,
    }


# ── 7. Gemini CLI ─────────────────────────────────────────────────────────────
def collect_gemini():
    home = Path.home()
    gem_tmp = home / ".gemini/tmp"
    installed = bool(shutil.which("gemini") or gem_tmp.is_dir())
    c5h = c7d = 0
    latest_ts = 0.0
    if gem_tmp.is_dir():
        for path in sorted(gem_tmp.rglob("session-*.json"), key=lambda p: p.stat().st_mtime, reverse=True)[:15]:
            try:
                mt = path.stat().st_mtime
                if mt > latest_ts:
                    latest_ts = mt
                age = NOW - mt
                if age <= WIN_7D:
                    c7d += 1
                    if age <= WIN_5H:
                        c5h += 1
            except OSError:
                continue
    windows = []
    if installed and (c5h > 0 or c7d > 0):
        windows = [
            {"label": "5h", "used": min(100, round(c5h / 20 * 100)), "minutes": 300, "reset": 0, "detail": f"{c5h} sessions"},
            {"label": "7d", "used": min(100, round(c7d / 100 * 100)), "minutes": 10080, "reset": 0, "detail": f"{c7d} sessions"},
        ]
    return {
        "id": "gemini",
        "name": "Gemini CLI",
        "short": "GEM",
        "installed": installed,
        "live": False,
        "status": "Active" if c5h > 0 else ("Local" if c7d > 0 else ("Installed" if installed else "Not installed")),
        "windows": windows,
        "timestamp": iso_from_ts(latest_ts),
        "hasPercent": False,
    }


if __name__ == "__main__":
    providers = [
        collect_codex(),
        collect_antigravity(),
        collect_opencode(),
        collect_claude(),
        collect_mistral(),
        collect_command_code(),
        collect_gemini(),
    ]
    print(json.dumps({"timestamp": NOW_ISO, "providers": providers}))
