"""Collect detailed, local read-only system and hardware specifications for the About page."""
import glob
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


def read_hwmon_temps():
    temps = {}
    for name_path in sorted(glob.glob("/sys/class/hwmon/hwmon*/name")):
        sensor = read(name_path).strip().lower()
        temp_path = os.path.join(os.path.dirname(name_path), "temp1_input")
        raw = read(temp_path).strip()
        if raw.isdigit():
            temps[sensor] = round(int(raw) / 1000.0)
    return temps


def short_cpu_name(raw_cpu):
    cleaned = re.sub(r"\(R\)|\(TM\)|CPU|Processor|with Radeon.*$", "", raw_cpu, flags=re.I)
    cleaned = re.sub(r"\b\d+-Core\b", "", cleaned, flags=re.I)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned or raw_cpu


def short_gpu_name(raw_gpu):
    brackets = re.findall(r"\[([^\]]+)\]", raw_gpu)
    if brackets:
        preferred = [b for b in brackets if b.upper() not in ("AMD/ATI", "INTEL", "NVIDIA")]
        if preferred:
            name = preferred[-1].split("/")[0].strip()
            if "AMD" in raw_gpu.upper() and not name.upper().startswith("AMD"):
                return f"AMD {name}"
            return name
    return raw_gpu


def count_packages():
    parts = []
    pacman_dir = "/var/lib/pacman/local"
    if os.path.isdir(pacman_dir):
        try:
            cnt = sum(1 for entry in os.scandir(pacman_dir) if entry.is_dir())
            if cnt > 0:
                parts.append(f"{cnt} (pacman)")
        except OSError:
            pass
    flatpak_dir = "/var/lib/flatpak/app"
    if os.path.isdir(flatpak_dir):
        try:
            cnt = sum(1 for entry in os.scandir(flatpak_dir) if entry.is_dir())
            if cnt > 0:
                parts.append(f"{cnt} (flatpak)")
        except OSError:
            pass
    return ", ".join(parts) if parts else "Unavailable"


# OS & Host & User
os_info = platform.freedesktop_os_release()
hostname = socket.gethostname()
user = os.environ.get("USER") or "user"
os_id = os_info.get("ID", "linux")
os_pretty = os_info.get("PRETTY_NAME", "Linux")
kernel_rel = platform.release()
arch = platform.machine()
user_shell = os.path.basename(os.environ.get("SHELL", "sh"))

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

# Sensors
hwmon = read_hwmon_temps()
cpu_temp = hwmon.get("k10temp") or hwmon.get("coretemp") or hwmon.get("zenpower")
gpu_temp = hwmon.get("amdgpu") or hwmon.get("nouveau") or hwmon.get("radeon")
nvme_temp = hwmon.get("nvme")

# CPU
cpu_match = re.search(r"^model name\s*:\s*(.+)$", read("/proc/cpuinfo"), re.M)
cpu_name = cpu_match.group(1).strip() if cpu_match else arch
cpu_short = short_cpu_name(cpu_name)
cpu_cores = os.cpu_count() or 1
try:
    load1 = os.getloadavg()[0]
    cpu_load_pct = max(0, min(100, round((load1 / cpu_cores) * 100)))
    load_str = f"{load1:.2f}"
except OSError:
    cpu_load_pct = 0
    load_str = "—"

# Memory
meminfo = read("/proc/meminfo")
mem_total_m = re.search(r"^MemTotal:\s*(\d+)", meminfo, re.M)
mem_avail_m = re.search(r"^MemAvailable:\s*(\d+)", meminfo, re.M)
if mem_total_m:
    total_kb = int(mem_total_m.group(1))
    avail_kb = int(mem_avail_m.group(1)) if mem_avail_m else 0
    used_kb = max(0, total_kb - avail_kb)
    mem_total_gib = total_kb / 1048576.0
    mem_used_gib = used_kb / 1048576.0
    mem_pct = round((used_kb / total_kb) * 100) if total_kb > 0 else 0
    memory_gib = f"{mem_used_gib:.1f} / {mem_total_gib:.1f} GiB"
else:
    mem_pct = 0
    memory_gib = "Unavailable"

# Disk Storage
try:
    total_b, used_b, free_b = shutil.disk_usage("/")
    disk_total_gib = total_b // (1024**3)
    disk_used_gib = used_b // (1024**3)
    disk_pct = int((used_b / total_b) * 100)
    disk_short = f"{disk_used_gib} / {disk_total_gib} GiB"
    disk_str = f"{disk_used_gib} GiB used / {disk_total_gib} GiB ({disk_pct}%)"
except Exception:
    disk_pct = 0
    disk_short = "Unavailable"
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
gpu_short = short_gpu_name(gpus[0]) if gpus else "Integrated Graphics"

# Hyprland & Quickshell
hypr = parse_json(command("hyprctl", "version", "-j"), {})
monitors_raw = parse_json(command("hyprctl", "monitors", "-j"), [])
qs_ver_raw = command("qs", "--version") or command("quickshell", "--version")
qs_ver_short = re.sub(r"\s*\(.*?\)", "", qs_ver_raw).strip() or "Quickshell"
hypr_tag = hypr.get("tag") or hypr.get("version") or ""
wm_str = f"Hyprland {hypr_tag}".strip()
packages_str = count_packages()

monitors = []
for m in sorted(monitors_raw, key=lambda x: (x.get("x", 0), x.get("y", 0))):
    monitors.append({
        "name": m.get("name", "Display"),
        "width": m.get("width", 0),
        "height": m.get("height", 0),
        "res": f"{m.get('width', 0)}×{m.get('height', 0)}",
        "refresh": f"{round(m.get('refreshRate', 60))} Hz",
        "refreshExact": f"{m.get('refreshRate', 60):.2f} Hz",
        "scale": f"{m.get('scale', 1):g}×",
        "focused": bool(m.get("focused", False)),
    })

fetch_rows = [
    ["os", f"{os_pretty} {arch}"],
    ["kernel", kernel_rel],
    ["wm", wm_str],
    ["shell", f"{qs_ver_short} · {user_shell}"],
    ["pkgs", packages_str],
    ["uptime", uptime_str],
    ["cpu", f"{cpu_short} ({cpu_cores}T)" + (f" · {cpu_temp}°C" if cpu_temp is not None else "")],
    ["gpu", gpu_short + (f" · {gpu_temp}°C" if gpu_temp is not None else "")],
    ["memory", f"{memory_gib} ({mem_pct}%)"],
]

fetch_lines = [f"{user}@{hostname}", "-" * len(f"{user}@{hostname}")]
for k, v in fetch_rows:
    fetch_lines.append(f"{k:<8} {v}")
fetch_text = "\n".join(fetch_lines)

# Hero Summary Info
summary = {
    "user": user,
    "hostname": hostname,
    "userAtHost": f"{user}@{hostname}",
    "osPretty": os_pretty,
    "osId": os_id,
    "uptime": uptime_str,
    "kernel": kernel_rel,
    "arch": arch,
    "shell": user_shell,
    "packages": packages_str,
    "cpu": cpu_name,
    "cpuShort": cpu_short,
    "cpuCores": f"{cpu_cores} Threads",
    "cpuLoad": load_str,
    "cpuLoadPct": cpu_load_pct,
    "cpuTemp": f"{cpu_temp}°C" if cpu_temp is not None else "",
    "gpu": gpus[0] if gpus else "Integrated Graphics",
    "gpuShort": gpu_short,
    "gpuTemp": f"{gpu_temp}°C" if gpu_temp is not None else "",
    "memory": memory_gib,
    "memPct": mem_pct,
    "storage": disk_short,
    "storageFull": disk_str,
    "diskPct": disk_pct,
    "nvmeTemp": f"{nvme_temp}°C" if nvme_temp is not None else "",
    "hyprland": wm_str,
    "quickshell": qs_ver_short,
    "fetchText": fetch_text,
}

# Categorized Detail Tables
sections = [
    {
        "title": "Environment & Rice Stack",
        "icon": "computer-symbolic",
        "rows": [
            ["Operating System", f"{os_pretty} ({arch})"],
            ["Kernel Release", kernel_rel],
            ["Compositor", wm_str],
            ["Shell Framework", qs_ver_raw or "Quickshell"],
            ["Login Shell", user_shell],
            ["Packages", packages_str],
            ["Hostname", hostname],
            ["System Uptime", uptime_str],
        ],
    },
    {
        "title": "Hardware Specifications",
        "icon": "preferences-system-devices-symbolic",
        "rows": [
            ["Processor", f"{cpu_name} ({cpu_cores} Threads)"],
            ["Graphics", "\n".join(gpus) or "Generic DRM Controller"],
            ["Memory", f"{memory_gib} ({mem_pct}% used)"],
            ["Root Storage (/)", disk_str],
        ],
    },
]

print(json.dumps({
    "summary": summary,
    "fetchRows": fetch_rows,
    "monitors": monitors,
    "sections": sections,
}))
