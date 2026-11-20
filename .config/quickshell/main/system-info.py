"""Collect detailed, local read-only system and hardware specifications for the About page."""
import json
import os
import platform
import re
import shutil
import socket
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


# OS & Host
os_info = platform.freedesktop_os_release()
hostname = socket.gethostname()
os_id = os_info.get("ID", "linux")
logo_name = os_info.get("LOGO", f"{os_id}-logo")

# Find Distro Logo
distro_logo = ""
logo_candidates = [
    f"/usr/share/pixmaps/{logo_name}.svg",
    f"/usr/share/pixmaps/{logo_name}.png",
    f"/usr/share/pixmaps/{os_id}-logo.svg",
    f"/usr/share/pixmaps/{os_id}-logo.png",
    f"/usr/share/pixmaps/{os_id}.svg",
    f"/usr/share/pixmaps/{os_id}.png",
    f"/usr/share/pixmaps/{os_id}linux-logo.svg",
    f"/usr/share/pixmaps/{os_id}linux-logo.png",
    "/usr/share/pixmaps/archlinux-logo.svg",
    "/usr/share/pixmaps/archlinux-logo.png",
]
for candidate in logo_candidates:
    if os.path.isfile(candidate):
        distro_logo = "file://" + candidate
        break

# Uptime
uptime_str = "Unavailable"
try:
    with open("/proc/uptime") as f:
        up = float(f.read().split()[0])
        days = int(up // 86400)
        hours = int((up % 86400) // 3600)
        mins = int((up % 3600) // 60)
        if days > 0:
            uptime_str = f"{days}d {hours}h {mins}m"
        elif hours > 0:
            uptime_str = f"{hours}h {mins}m"
        else:
            uptime_str = f"{mins}m"
except Exception:
    pass

# CPU
cpu_match = re.search(r"^model name\s*:\s*(.+)$", read("/proc/cpuinfo"), re.M)
cpu_name = cpu_match.group(1).strip() if cpu_match else platform.machine()
cpu_cores = os.cpu_count() or 0

# Memory
mem_match = re.search(r"^MemTotal:\s*(\d+)", read("/proc/meminfo"), re.M)
memory_gib = f"{int(mem_match.group(1)) / 1048576:.1f} GiB" if mem_match else "Unavailable"

# Disk Storage
try:
    total_b, used_b, free_b = shutil.disk_usage("/")
    disk_total_gib = total_b // (1024**3)
    disk_used_gib = used_b // (1024**3)
    disk_pct = int((used_b / total_b) * 100)
    disk_str = f"{disk_used_gib} GiB used / {disk_total_gib} GiB ({disk_pct}%)"
except Exception:
    disk_str = "Unavailable"

# GPUs
gpu_lines = command("lspci", "-mm").splitlines()
gpus = []
for line in gpu_lines:
    fields = re.findall(r'"([^"]*)"', line)
    if len(fields) >= 3 and fields[0] in ("VGA compatible controller", "3D controller", "Display controller"):
        name = " ".join(fields[1:3])
        if name and name not in gpus:
            gpus.append(name)

# Hyprland & Wayland & Quickshell
hypr = parse_json(command("hyprctl", "version", "-j"), {})
monitors = parse_json(command("hyprctl", "monitors", "-j"), [])
qs_ver = command("qs", "--version") or command("quickshell", "--version")

# Hero Summary Info
summary = {
    "osPretty": os_info.get("PRETTY_NAME", "Linux"),
    "osId": os_id,
    "logoPath": distro_logo,
    "hostname": hostname,
    "uptime": uptime_str,
    "kernel": platform.release(),
    "arch": platform.machine(),
    "cpu": cpu_name,
    "cpuCores": f"{cpu_cores} Cores",
    "gpu": gpus[0] if gpus else "Integrated Graphics",
    "memory": memory_gib,
    "storage": disk_str,
    "hyprland": hypr.get("tag") or hypr.get("version", "Hyprland"),
    "quickshell": qs_ver or "Quickshell 0.3.2"
}

# Categorized Detail Tables
sections = [
    {
        "title": "System & Environment",
        "icon": "computer-symbolic",
        "rows": [
            ["Operating System", os_info.get("PRETTY_NAME", "Linux")],
            ["Kernel Release", platform.release()],
            ["System Architecture", platform.machine()],
            ["Hostname", hostname],
            ["System Uptime", uptime_str],
            ["Compositor", f"Hyprland {hypr.get('version') or hypr.get('tag', '')}".strip()],
            ["Shell Framework", qs_ver or "Quickshell"],
        ]
    },
    {
        "title": "Hardware Specifications",
        "icon": "preferences-system-devices-symbolic",
        "rows": [
            ["Processor", f"{cpu_name} ({cpu_cores} Threads)"],
            ["Graphics Accelerator", "\n".join(gpus) or "Generic DRM Controller"],
            ["Physical Memory", f"{memory_gib} Available"],
            ["Primary Storage (/)", disk_str],
        ]
    },
    {
        "title": "Connected Displays",
        "icon": "video-display-symbolic",
        "rows": [
            [
                m.get("name", "Display"),
                f"{m.get('width', 0)} × {m.get('height', 0)}  ·  {m.get('refreshRate', 60):.2f} Hz  ·  {m.get('scale', 1):g}× Scale"
            ]
            for m in monitors
        ] or [["Display", "No external displays detected"]]
    }
]

print(json.dumps({
    "summary": summary,
    "sections": sections
}))
