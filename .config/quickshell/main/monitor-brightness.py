"""Read or adjust brightness on the display that owns the sidebar."""
from pathlib import Path
import re
import shutil
import subprocess
import sys


def main(connector, action):
    if action not in ("read", "up", "down") or not re.fullmatch(r"[A-Za-z0-9-]+", connector):
        raise ValueError("Invalid screen or action")
    if shutil.which("ddcutil"):
        for link in Path("/sys/class/drm").glob(f"card*-{connector}/ddc"):
            bus = re.fullmatch(r"i2c-(\d+)", link.resolve().name)
            if not bus:
                continue
            base = ["ddcutil", "--bus", bus[1]]
            if action != "read":
                subprocess.run([*base, "setvcp", "10", "+" if action == "up" else "-", "5"], timeout=6,
                               check=True, stdout=subprocess.DEVNULL)
            output = subprocess.check_output([*base, "--terse", "getvcp", "10"], text=True, timeout=6)
            value = re.search(r"VCP 10 C (\d+) (\d+)", output)
            if value and int(value[2]):
                print(round(int(value[1]) * 100 / int(value[2])))
                return
    if connector.startswith(("eDP-", "LVDS-", "DSI-")) and shutil.which("brightnessctl"):
        base = ["brightnessctl", "-c", "backlight"]
        if action != "read":
            subprocess.run([*base, "--min-value=1", "set", "+5%" if action == "up" else "5%-"],
                           timeout=3, check=True, stdout=subprocess.DEVNULL)
        output = subprocess.check_output([*base, "-m", "info"], text=True, timeout=3)
        value = re.search(r",(\d+)%,", output)
        if value:
            print(value[1])
            return
    raise ValueError("No supported brightness control for this display")


if __name__ == "__main__":
    try:
        main(*sys.argv[1:])
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        sys.exit(str(error))
