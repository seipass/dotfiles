"""Save a Wayland region capture without opening an editor."""
from datetime import datetime
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile


def main():
    ocr = "--ocr" in sys.argv
    if ocr and not shutil.which("tesseract"):
        subprocess.run(["notify-send", "Screen text recognition", "Install tesseract and its English language data."], check=False)
        return
    picker = subprocess.run(["slurp"], capture_output=True, text=True)
    if picker.returncode or not picker.stdout.strip():
        return
    folder = Path.home() / "Pictures" / "Screenshots"
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / (datetime.now().strftime("%Y-%m-%d_%H-%M-%S_%f") + ".png")
    if ocr:
        with tempfile.TemporaryDirectory() as temp:
            image = str(Path(temp) / "region.png")
            subprocess.run(["grim", "-g", picker.stdout.strip(), image], check=True)
            result = subprocess.check_output(["tesseract", image, "stdout"], text=True, timeout=30)
        text_path = path.with_suffix(".txt")
        text_path.write_text(result, encoding="utf-8")
        subprocess.run(["xdg-open", str(text_path)], check=False)
        return
    subprocess.run(["grim", "-g", picker.stdout.strip(), str(path)], check=True)
    subprocess.run(["notify-send", "Screenshot saved", str(path)], check=False)


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.SubprocessError):
        subprocess.run(["notify-send", "Screen capture failed", "Check the capture and text recognition tools."], check=False)
