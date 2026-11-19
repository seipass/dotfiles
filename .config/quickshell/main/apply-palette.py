#!/usr/bin/env python3
"""Generate shell colour tokens for the running QML palette."""
import colorsys
import hashlib
import json
import re
import sys
import os
from pathlib import Path
import subprocess
import tempfile

mode = sys.argv[1]
seed = sys.argv[2] if len(sys.argv) > 2 else ""
presets = {"blue": "#a9c7ff", "green": "#a6d0a0", "pink": "#ffb0ca"}
if mode == "auto":
    seed = seed if re.fullmatch(r"#[0-9a-fA-F]{6}", seed) else presets["pink"]
else:
    seed = presets.get(mode, presets["pink"])

if mode == "pink":
    colors = {
        "surface": "#191114", "surfaceContainer": "#261d20",
        "surfaceContainerHigh": "#31282a", "primary": "#ffb0ca",
        "primaryContainer": "#6f334a", "onPrimary": "#541d34",
        "onSurface": "#efdfe2", "onSurfaceVariant": "#d5c2c6",
        "outlineVariant": "#514347",
    }
else:
    rgb = tuple(int(seed[i:i+2], 16) / 255 for i in (1, 3, 5))
    hue, lightness, saturation = colorsys.rgb_to_hls(*rgb)
    saturation = max(0.28, min(0.70, saturation))

    def tone(light, sat):
        values = colorsys.hls_to_rgb(hue, light, sat)
        return "#" + "".join(f"{round(c * 255):02x}" for c in values)

    colors = {
        "surface": tone(0.085, 0.20),
        "surfaceContainer": tone(0.13, 0.17),
        "surfaceContainerHigh": tone(0.18, 0.16),
        "primary": tone(0.80, saturation),
        "primaryContainer": tone(0.32, saturation * 0.75),
        "onPrimary": tone(0.16, saturation * 0.75),
        "onSurface": tone(0.90, 0.18),
        "onSurfaceVariant": tone(0.77, 0.16),
        "outlineVariant": tone(0.29, 0.13),
    }

def update(path, text):
    if path.exists() and path.read_text() == text:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as file:
        file.write(text)
    os.replace(file.name, path)
    return True


def run(*args):
    try:
        subprocess.run(args, timeout=3, check=True, stdout=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError) as error:
        print(error, file=sys.stderr)


if "--sync-desktop" in sys.argv[3:]:
    home = Path.home()
    try:
        accent = colors["primary"][1:]
        update(home / ".config/hypr/generated-accent", accent + "\n")
        run("hyprctl", "eval", f'hl.config({{general={{col={{active_border="rgba({accent}ff)"}}}}}})')
        kitty = home / ".config/kitty"
        kitty_tokens = {
            "background": "surface", "foreground": "onSurface",
            "cursor": "primary", "cursor_text_color": "onPrimary",
            "selection_background": "primaryContainer", "selection_foreground": "onSurface",
            "url_color": "primary", "active_border_color": "primary",
            "inactive_border_color": "outlineVariant", "tab_bar_background": "surfaceContainer",
            "active_tab_background": "primary", "active_tab_foreground": "onPrimary",
            "inactive_tab_background": "surfaceContainerHigh", "inactive_tab_foreground": "onSurfaceVariant",
            "color0": "surfaceContainer", "color5": "primary", "color7": "onSurfaceVariant",
            "color13": "primary", "color15": "onSurface",
        }
        kitty_palette = "".join(f"{key} {colors[token]}\n" for key, token in kitty_tokens.items())
        if update(kitty / "shell-palette.conf", kitty_palette):
            # Existing Kitty instances already watch the main config, even
            # if this include did not exist when they started.
            config = kitty / "kitty.conf"
            text = config.read_text()
            if "include shell-palette.conf" in text.splitlines():
                text = re.sub(r"(?m)^# Shell palette revision: [0-9a-f]+\n", "", text)
                revision = hashlib.sha256(kitty_palette.encode()).hexdigest()[:12]
                config.write_text(text.replace("\ninclude shell-palette.conf\n",
                                                f"\n# Shell palette revision: {revision}\ninclude shell-palette.conf\n", 1))
        themes = Path(os.environ.get("XDG_DATA_HOME", home / ".local/share")) / "fcitx5/themes"
        tokens = dict(zip(
            ("#191114", "#514347", "#541d34", "#d5c2c6", "#efdfe2", "#ffb0ca"),
            (colors[k] for k in ("surface", "outlineVariant", "onPrimary", "onSurfaceVariant", "onSurface", "primary")),
        ))
        changed = False
        for source in (themes / "caelestia-shell").iterdir():
            if source.suffix in (".svg", ".conf"):
                text = re.sub(r"#[0-9a-fA-F]{6}", lambda m: tokens.get(m[0].lower(), m[0]), source.read_text())
                changed |= update(themes / "shell-live" / source.name, text.replace("Caelestia Shell", "Shell Live"))
        if changed:
            run("busctl", "--user", "call", "org.fcitx.Fcitx5", "/controller",
                "org.fcitx.Fcitx.Controller1", "ReloadAddonConfig", "s", "classicui")
    except OSError as error:
        print(error, file=sys.stderr)

print(json.dumps(colors))
