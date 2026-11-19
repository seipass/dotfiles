"""Collect local, read-only system information for the About page."""
import json
import platform
import re
import subprocess
from pathlib import Path


def command(*args):
    try:
        return subprocess.check_output(args, text=True, timeout=2, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def read(path):
    try:
        return Path(path).read_text(errors="replace")
    except OSError:
        return ""


def parse_json(text, default):
    try:
        return json.loads(text)
    except ValueError:
        return default


os_info = platform.freedesktop_os_release()
cpu = re.search(r"^model name\s*:\s*(.+)$", read("/proc/cpuinfo"), re.M)
memory = re.search(r"^MemTotal:\s*(\d+)", read("/proc/meminfo"), re.M)
gpu_lines = command("lspci", "-mm").splitlines()
gpus = []
for line in gpu_lines:
    fields = re.findall(r'"([^"]*)"', line)
    if len(fields) >= 3 and fields[0] in ("VGA compatible controller", "3D controller", "Display controller"):
        gpus.append(" ".join(fields[1:3]))

hypr = parse_json(command("hyprctl", "version", "-j"), {})
monitors = parse_json(command("hyprctl", "monitors", "-j"), [])
print(json.dumps([
    {"title": "Software", "rows": [
        ["Operating System", os_info.get("PRETTY_NAME", "")],
        ["Kernel", platform.release()],
        ["Hyprland", hypr.get("version") or hypr.get("tag", "")],
        ["Quickshell", command("qs", "--version") or command("quickshell", "--version")],
    ]},
    {"title": "Hardware", "rows": [
        ["Processor", cpu.group(1) if cpu else platform.machine()],
        ["Graphics", "\n".join(gpus) or (" · ".join(p.name for p in Path("/sys/class/drm").glob("card[0-9]") if (p / "device").exists()))],
        ["Memory", f"{int(memory.group(1)) / 1048576:.1f} GiB usable" if memory else ""],
    ]},
    {"title": "Displays", "rows": [
        [m["name"], f'{m["width"]} × {m["height"]} · {m["refreshRate"]:.2f} Hz · {m["scale"]:g}× scale']
        for m in monitors
    ] or [["Displays", ""]]},
]))
