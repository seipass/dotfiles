#!/usr/bin/env python3
"""Start Flameshot's editor on the monitor under the pointer."""
import json
import os
import subprocess


def output(*args):
    return subprocess.check_output(args, text=True, timeout=3).strip()


try:
    cursor = json.loads(output("hyprctl", "cursorpos", "-j"))
    monitors = json.loads(output("hyprctl", "monitors", "-j"))
    screens = json.loads(output("qs", "ipc", "--config", "main", "call", "displayInfo", "screens"))
    selected = None
    for monitor in monitors:
        width, height = monitor["width"], monitor["height"]
        if monitor.get("transform", 0) % 2:
            width, height = height, width
        width /= monitor["scale"]
        height /= monitor["scale"]
        if (monitor["x"] <= cursor["x"] < monitor["x"] + width
                and monitor["y"] <= cursor["y"] < monitor["y"] + height):
            selected = monitor["name"]
            break
    if selected not in screens:
        selected = next((m["name"] for m in monitors if m.get("focused")), None)
    if selected not in screens:
        raise ValueError("monitor not found")
    os.execlp("flameshot", "flameshot", "screen", "--edit", "--number", str(screens.index(selected)))
except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError):
    os.execlp("flameshot", "flameshot", "gui")
