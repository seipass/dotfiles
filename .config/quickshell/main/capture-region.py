"""Save a Wayland region capture without opening an editor."""
from datetime import datetime
from pathlib import Path
import subprocess


def main():
    picker = subprocess.run(["slurp"], capture_output=True, text=True)
    if picker.returncode or not picker.stdout.strip():
        return
    folder = Path.home() / "Pictures" / "Screenshots"
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / (datetime.now().strftime("%Y-%m-%d_%H-%M-%S_%f") + ".png")
    subprocess.run(["grim", "-g", picker.stdout.strip(), str(path)], check=True)
    subprocess.run(["notify-send", "Screenshot saved", str(path)], check=False)


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.CalledProcessError):
        subprocess.run(["notify-send", "Screenshot failed", "Check that grim and slurp are installed."], check=False)
