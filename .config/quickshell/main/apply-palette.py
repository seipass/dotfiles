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
sync_desktop = "--sync-desktop" in sys.argv[2:]
extra_args = [arg for arg in sys.argv[2:] if arg != "--sync-desktop"]
seed = extra_args[0] if extra_args else ""
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


def build_fcitx5_theme(c, name="Shell Live", description="Borderless Material 3 Expressive theme matching HaDE"):
    theme_conf = f"""[Metadata]
Name={name}
Name[ja]={name}
Version=2
Author=HaDE
Description={description}
ScaleWithDPI=True

[InputPanel]
NormalColor={c['onSurface']}
HighlightCandidateColor={c['onSurface']}
CandidateLabelColor={c['onSurfaceVariant']}
HighlightCandidateLabelColor={c['primary']}
LabelTextSizeFactor=88
CandidateCommentColor={c['onSurfaceVariant']}
HighlightCandidateCommentColor={c['onSurfaceVariant']}
CommentTextSizeFactor=86
HighlightColor={c['onPrimary']}
HighlightBackgroundColor={c['primary']}
FullWidthHighlight=True
PageButtonAlignment=Last Candidate

[InputPanel/TextMargin]
Left=14
Right=14
Top=6
Bottom=6

[InputPanel/ContentMargin]
Left=8
Right=8
Top=8
Bottom=8

[InputPanel/ShadowMargin]
Left=0
Right=0
Top=0
Bottom=0

[InputPanel/Background]
Image=background.svg
Color={c['surfaceContainerHigh']}
BorderColor={c['surfaceContainerHigh']}
BorderWidth=0

[InputPanel/Background/Margin]
Left=20
Right=20
Top=20
Bottom=20

[InputPanel/Highlight]
Image=highlight.svg
Color={c['primaryContainer']}

[InputPanel/Highlight/Margin]
Left=14
Right=14
Top=14
Bottom=14

[InputPanel/Highlight/HighlightClickMargin]
Left=0
Right=0
Top=0
Bottom=0

[InputPanel/PrevPage]
Image=prev.svg

[InputPanel/PrevPage/ClickMargin]
Left=6
Right=6
Top=4
Bottom=4

[InputPanel/NextPage]
Image=next.svg

[InputPanel/NextPage/ClickMargin]
Left=6
Right=6
Top=4
Bottom=4

[Menu]
NormalColor={c['onSurface']}
HighlightCandidateColor={c['onSurface']}
Spacing=2

[Menu/Background]
Image=background.svg
Color={c['surfaceContainerHigh']}
BorderColor={c['surfaceContainerHigh']}
BorderWidth=0

[Menu/Background/Margin]
Left=20
Right=20
Top=20
Bottom=20

[Menu/ContentMargin]
Left=8
Right=8
Top=8
Bottom=8

[Menu/Highlight]
Image=highlight.svg
Color={c['primaryContainer']}

[Menu/Highlight/Margin]
Left=14
Right=14
Top=14
Bottom=14

[Menu/CheckBox]
Image=check.svg

[Menu/SubMenu]
Image=next.svg

[Menu/TextMargin]
Left=12
Right=12
Top=6
Bottom=6

[Menu/Separator]
Color={c['outlineVariant']}
"""
    background_svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">\n'
        f'  <rect x="0" y="0" width="64" height="64" rx="20" ry="20" fill="{c["surfaceContainerHigh"]}"/>\n'
        "</svg>\n"
    )
    highlight_svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">\n'
        f'  <rect x="0" y="0" width="48" height="48" rx="14" ry="14" fill="{c["primaryContainer"]}"/>\n'
        "</svg>\n"
    )
    prev_svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">\n'
        f'  <path d="M10 3.75 5.75 8 10 12.25" fill="none" stroke="{c["onSurfaceVariant"]}" '
        'stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>\n'
        "</svg>\n"
    )
    next_svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">\n'
        f'  <path d="M6 3.75 10.25 8 6 12.25" fill="none" stroke="{c["onSurfaceVariant"]}" '
        'stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>\n'
        "</svg>\n"
    )
    check_svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">\n'
        f'  <path d="M3.2 8.4 6.5 11.6 12.8 4.8" fill="none" stroke="{c["primary"]}" '
        'stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>\n'
        "</svg>\n"
    )
    return {
        "theme.conf": theme_conf,
        "background.svg": background_svg,
        "highlight.svg": highlight_svg,
        "prev.svg": prev_svg,
        "next.svg": next_svg,
        "check.svg": check_svg,
    }


if sync_desktop:
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
        changed = False
        for filename, content in build_fcitx5_theme(colors).items():
            changed |= update(themes / "shell-live" / filename, content)
        if changed:
            run("busctl", "--user", "call", "org.fcitx.Fcitx5", "/controller",
                "org.fcitx.Fcitx.Controller1", "ReloadAddonConfig", "s", "classicui")
    except OSError as error:
        print(error, file=sys.stderr)
    try:
        def argb(hex_color, alpha="ff"):
            return f"#{alpha}{hex_color[1:]}"

        c = colors
        qt_active = [
            argb(c["onSurface"]), argb(c["surfaceContainerHigh"]), argb(c["outlineVariant"]),
            argb(c["surfaceContainerHigh"]), argb(c["surface"]), argb(c["outlineVariant"]),
            argb(c["onSurface"]), argb(c["onSurface"]), argb(c["onSurface"]),
            argb(c["surfaceContainer"]), argb(c["surface"]), "#ff0b0e12",
            argb(c["primary"]), argb(c["onPrimary"]), argb(c["primary"]), argb(c["onSurfaceVariant"]),
            argb(c["surfaceContainerHigh"]), argb(c["surface"]), argb(c["surfaceContainerHigh"]),
            argb(c["onSurface"]), argb(c["onSurfaceVariant"], "80"), argb(c["primary"]),
        ]
        qt_disabled = [
            argb(c["onSurfaceVariant"]), argb(c["surfaceContainer"]), argb(c["outlineVariant"]),
            argb(c["surfaceContainerHigh"]), argb(c["surface"]), argb(c["outlineVariant"]),
            argb(c["onSurfaceVariant"]), argb(c["onSurfaceVariant"]), argb(c["onSurfaceVariant"]),
            argb(c["surfaceContainer"]), argb(c["surface"]), "#ff0b0e12",
            argb(c["primaryContainer"]), argb(c["onSurfaceVariant"]), argb(c["onSurfaceVariant"]),
            argb(c["onSurfaceVariant"]), argb(c["surfaceContainerHigh"]), argb(c["surface"]),
            argb(c["surfaceContainerHigh"]), argb(c["onSurfaceVariant"]), argb(c["onSurfaceVariant"], "66"),
            argb(c["primaryContainer"]),
        ]
        qt_inactive = list(qt_active)
        qt_inactive[12] = argb(c["primaryContainer"])
        qt_inactive[13] = argb(c["onSurface"])
        qt_inactive[21] = argb(c["primaryContainer"])
        qt_scheme = (
            "[ColorScheme]\n"
            f"active_colors={', '.join(qt_active)}\n"
            f"disabled_colors={', '.join(qt_disabled)}\n"
            f"inactive_colors={', '.join(qt_inactive)}\n"
        )
        update(home / ".config/qt6ct/colors/shell-live.conf", qt_scheme)
        qt6ct_conf = home / ".config/qt6ct/qt6ct.conf"
        if qt6ct_conf.is_file():
            scheme_path = str(home / ".config/qt6ct/colors/shell-live.conf")
            conf_text = qt6ct_conf.read_text()
            if re.search(r"(?m)^color_scheme_path=", conf_text):
                new_conf = re.sub(r"(?m)^color_scheme_path=.*$", f"color_scheme_path={scheme_path}", conf_text)
                if new_conf != conf_text:
                    update(qt6ct_conf, new_conf)

        gtk3_css = "\n".join([
            f"@define-color accent_bg_color {c['primary']};",
            f"@define-color accent_fg_color {c['onPrimary']};",
            f"@define-color accent_color {c['primary']};",
            f"@define-color theme_bg_color {c['surface']};",
            f"@define-color theme_fg_color {c['onSurface']};",
            f"@define-color theme_base_color {c['surfaceContainer']};",
            f"@define-color theme_text_color {c['onSurface']};",
            f"@define-color theme_selected_bg_color {c['primaryContainer']};",
            f"@define-color theme_selected_fg_color {c['onSurface']};",
            f"@define-color insensitive_bg_color {c['surface']};",
            f"@define-color insensitive_fg_color {c['onSurfaceVariant']};",
            f"@define-color insensitive_base_color {c['surfaceContainer']};",
            f"@define-color theme_unfocused_bg_color {c['surface']};",
            f"@define-color theme_unfocused_fg_color {c['onSurfaceVariant']};",
            f"@define-color theme_unfocused_base_color {c['surfaceContainer']};",
            f"@define-color theme_unfocused_text_color {c['onSurface']};",
            f"@define-color theme_unfocused_selected_bg_color {c['primaryContainer']};",
            f"@define-color theme_unfocused_selected_fg_color {c['onSurface']};",
            f"@define-color borders {c['outlineVariant']};",
            f"@define-color unfocused_borders {c['outlineVariant']};",
            f"@define-color content_view_bg {c['surfaceContainer']};",
            f"@define-color text_view_bg {c['surfaceContainer']};",
            f"@define-color headerbar_bg_color {c['surface']};",
            f"@define-color headerbar_fg_color {c['onSurface']};",
            f"@define-color headerbar_border_color {c['outlineVariant']};",
            f"@define-color popover_bg_color {c['surfaceContainerHigh']};",
            f"@define-color popover_fg_color {c['onSurface']};",
        ]) + "\n"
        gtk4_css = "\n".join([
            f"@define-color accent_bg_color {c['primary']};",
            f"@define-color accent_fg_color {c['onPrimary']};",
            f"@define-color accent_color {c['primary']};",
            f"@define-color window_bg_color {c['surface']};",
            f"@define-color window_fg_color {c['onSurface']};",
            f"@define-color view_bg_color {c['surfaceContainer']};",
            f"@define-color view_fg_color {c['onSurface']};",
            f"@define-color headerbar_bg_color {c['surface']};",
            f"@define-color headerbar_fg_color {c['onSurface']};",
            f"@define-color headerbar_border_color {c['outlineVariant']};",
            f"@define-color headerbar_backdrop_color {c['surface']};",
            "@define-color headerbar_shade_color rgba(0, 0, 0, 0.36);",
            f"@define-color card_bg_color {c['surfaceContainer']};",
            f"@define-color card_fg_color {c['onSurface']};",
            f"@define-color dialog_bg_color {c['surfaceContainer']};",
            f"@define-color dialog_fg_color {c['onSurface']};",
            f"@define-color popover_bg_color {c['surfaceContainerHigh']};",
            f"@define-color popover_fg_color {c['onSurface']};",
            f"@define-color sidebar_bg_color {c['surfaceContainer']};",
            f"@define-color sidebar_fg_color {c['onSurface']};",
            f"@define-color sidebar_backdrop_color {c['surface']};",
            f"@define-color secondary_sidebar_bg_color {c['surfaceContainer']};",
            f"@define-color secondary_sidebar_fg_color {c['onSurface']};",
            "@define-color shade_color rgba(0, 0, 0, 0.36);",
            f"@define-color scrollbar_outline_color {c['outlineVariant']};",
        ]) + "\n"
        for version, css in (("gtk-3.0", gtk3_css), ("gtk-4.0", gtk4_css)):
            gtk_dir = home / ".config" / version
            update(gtk_dir / "shell-palette.css", css)
            gtk_main = gtk_dir / "gtk.css"
            if not gtk_main.exists():
                update(gtk_main, '@import url("shell-palette.css");\n')
        run("gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark")
        run("gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "Adwaita-dark")
        run("gsettings", "set", "org.gnome.desktop.interface", "icon-theme", "Adwaita")
        run("gsettings", "set", "org.gnome.desktop.interface", "font-name", "Adwaita Sans 10")
        run("gsettings", "set", "org.gnome.desktop.interface", "monospace-font-name", "Ioskeley Mono Term 10")
    except OSError as error:
        print(error, file=sys.stderr)

print(json.dumps(colors))
