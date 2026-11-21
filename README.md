# seipass's Hyprland + Quickshell Dotfiles

An Arch Linux / Hyprland desktop rice built around **Quickshell** with a **Material Design 3 Expressive** visual language, wallpaper-driven dynamic theming, a **Dynamic Island**, zero-dependency **Wayland text + image clipboard history**, **real-time Japanese earthquake alerts**, **multi-provider AI quota tracking**, and a matching **Qt6 SDDM greeter theme**.

> **Preview screenshots:** Put screenshots in `screenshots/` when publishing if desired.

---

## Highlights

### Dynamic Material You Palette Sync
Changing your wallpaper or preset (`auto`, `pink`, `blue`, `green`) in Quick Tools triggers `apply-palette.py --sync-desktop`, regenerating consistent M3 dark surface and accent tokens across:
- **Quickshell** (`LivePalette.qml` + QML components)
- **Hyprland** active window border (`~/.config/hypr/generated-accent` + live `hyprctl eval`)
- **Kitty** (`~/.config/kitty/shell-palette.conf`)
- **GTK 3 & GTK 4** (`shell-palette.css` + `gsettings`)
- **Qt 6** (`~/.config/qt6ct/colors/shell-live.conf`)
- **Fcitx 5** (`shell-live` theme derived from `caelestia-shell`)

### Quickshell Desktop Shell (`main`)
- **Dynamic Island (`DynamicIsland.qml`)**:
  - Morphs smoothly between compact pill views and expanded drawers.
  - Built-in views: **MPRIS Music Player**, **Earthquake Monitor** (`EarthquakePanel.qml` powered by P2PQuake API with both zero-dep RFC 6455 WebSocket live streaming and configurable polling), **Dashboard** (clock, `wttr.in` weather, volume, workspace overview), and drop-in **Custom QML slot extensions** ([`ISLAND-EXTENSIONS.md`](.config/quickshell/main/ISLAND-EXTENSIONS.md)).
- **Vertical Rail, Dock & Launcher (`VerticalBar.qml`, `Taskbar.qml`, `Launcher.qml`)**:
  - Multi-monitor aware taskbar with pin/reorder state and hover preview menus.
  - Raycast-style centered launcher (`Super + Space`), Emoji search (`Super + .`), and inline `/` commands:
    - `/calc` (math & constants), `/time` (timezone conversion & duration math), `/color` (`HEX` / `rgb()` / `hsl()`), `/qr` (offline SVG QR generator), `/weather` (`wttr.in`), `/web`.
- **Zero-Dependency Image + Text Clipboard (`ClipboardPopup.qml`, `clipboard-daemon.py`)**:
  - Uses Wayland `ext_data_control_v1` (`zwlr_data_control_manager_v1` fallback) directly from Python stdlib — **no `wl-clipboard` or `cliphist` required**.
  - Captures text and images (`PNG`, `WebP`, `JPEG`, `GIF`, `BMP`) with image previews, resolution/size badges, search, keyboard navigation, and click/Enter re-copy at cursor position (`Super + V`).
- **Multi-Provider AI Quota Indicator (`QuotaBadge.qml`, `ai-usage.py`)**:
  - Displays rate-limit / usage bars for Codex CLI, Antigravity, OpenCode, Claude Code, Gemini CLI, Mistral, and Command Code.
- **Clean Separation: Quick Tools vs System Settings**:
  - **Quick Tools (`SidebarTools.qml`)**: Wallpaper browser, dynamic colors, Dynamic Island / bar layout, weather city search (Open-Meteo Geocoding), region capture/OCR/translate (`grim` + `slurp` / `flameshot` + `tesseract`), clipboard history, daily tools (notes/stopwatch/timer), plus quick Audio/Brightness/Network/Bluetooth tiles.
  - **System Settings (`SettingsWindow.qml`)**: Wi-Fi (`nmcli`), Bluetooth (`bluetoothctl`), Sound & Display (`wpctl`, `ddcutil`, `brightnessctl`), Maintenance (`htop`, `journalctl`, `checkupdates`, shell reload), and a **Fastfetch × M3 About page** (`SystemAbout.qml` + `system-info.py`) with Arch ASCII art, live load/memory/storage telemetry, hwmon temperatures, clickable palette swatches, and one-click fetch copy.
- **Accessible Power Menu (`PowerMenu.qml`)**:
  - Full-width high-contrast Shutdown action with two-step confirmation, keyboard navigation (`Tab` / arrows / `Enter` / `Esc`), Reboot, Suspend, and Hyprland Logout.

### Hyprland (`hyprland.lua`)
- Configured in Lua (`hyprland-lua` / `hl.*`) with custom spring/bezier animations, rounded corners, blur, Japanese IME (`fcitx5` + `mozc`), and pointer-monitor aware Flameshot capture (`flameshot-screen.py`).

### Afterglow SDDM Theme (`.local/share/sddm/themes/afterglow`)
- Material Design 3 Qt6 SDDM theme matching Quickshell tokens (`theme.conf`), with session selector, show/hide password toggle, user quick-fill, and `Esc` to close in `--test-mode`.

---

## Keybindings (`hyprland.lua`)

| Keybind | Action |
| :--- | :--- |
| `Super + Return` | Open terminal (`kitty`) |
| `Super + Space` | Toggle App Launcher (`/calc`, `/time`, `/color`, `/qr`, `/weather`, `/web`) |
| `Super + .` | Open Emoji Picker |
| `Super + V` | Toggle Clipboard History popup at cursor (Text + Images) |
| `Super + Shift + V` | Toggle floating window |
| `Super + Q` / `Super + C` | Close active window |
| `Super + F` | Toggle fullscreen |
| `Super + E` | Open file manager (`dolphin`) |
| `Super + R` | Open `wofi` |
| `Super + P` | Toggle pseudo-tiling |
| `Super + J` | Toggle split orientation |
| `Super + Shift + S` | Screenshot active pointer monitor with Flameshot |
| `Super + S` / `Super + Alt + S` | Toggle / move window to scratchpad (`special:magic`) |
| `Super + Arrows` | Move window focus |
| `Super + [0-9]` / `Shift + [0-9]` | Switch to / move window to workspace `1–10` |
| `Super + LMB` / `RMB` | Drag / resize window |
| `XF86Audio*` / `XF86MonBrightness*` | Volume (`wpctl`), Brightness (`brightnessctl`), Media (`playerctl`) |

---

## Directory Structure

```text
.
├── .config/
│   ├── fcitx5/conf/classicui.conf
│   ├── gtk-3.0/               # gtk.css, settings.ini, shell-palette.css
│   ├── gtk-4.0/               # gtk.css, settings.ini, shell-palette.css
│   ├── hypr/                  # hyprland.lua, flameshot-screen.py, generated-accent
│   ├── kitty/                 # kitty.conf, shell-palette.conf
│   ├── qt6ct/                 # qt6ct.conf, colors/shell-live.conf
│   ├── quickshell/main/       # QML shell components & Python helpers
│   ├── user-dirs.dirs
│   └── user-dirs.locale
├── .local/share/
│   ├── fcitx5/themes/         # caelestia-shell & shell-live Fcitx5 themes
│   └── sddm/themes/afterglow/ # M3 Qt6 SDDM theme + theme.conf
├── install.sh                 # Safe installer with automatic backups
├── LICENSE
└── README.md
```

---

## Dependencies (Arch Linux)

### Core
- **Compositor & Shell**: `hyprland` (with Lua config support), `quickshell`, `qt6-declarative`, `qt6-svg`, `qt6-5compat`
- **Terminal & Runtime**: `kitty`, `python`, `python-dbus`, `python-gobject`, `curl`
- **Audio & Connectivity**: `pipewire`, `wireplumber`, `networkmanager`, `bluez-utils`
- **Portals & Theming**: `xdg-desktop-portal`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`, `qt6ct`, `breeze` / `adwaita-icon-theme`

### Recommended / Optional
- **IME**: `fcitx5`, `fcitx5-mozc`
- **Screenshots & OCR**: `flameshot`, `grim`, `slurp`, `tesseract` + `tesseract-data-eng`
- **Display Brightness & Audio UI**: `ddcutil`, `brightnessctl`, `pavucontrol`, `playerctl`, `network-manager-applet` (`nm-connection-editor`)
- **Maintenance & Apps**: `htop`, `pacman-contrib` (`checkupdates`), `dolphin`, `wofi`, `sddm`
- **Fonts**: `Doto` & `Google Sans Flex` (both bundled under SIL OFL 1.1; uses `Ndot 55` automatically if installed locally), `Ioskeley Mono Term`, `Adwaita Sans`, `Noto Sans CJK JP`

---

## Installation

```bash
git clone https://github.com/seipass/dotfiles.git
cd dotfiles
./install.sh --dry-run   # preview changes first
./install.sh             # backs up existing configs to ~/.local/state/dotfiles-backup-*
```

To also install the Afterglow SDDM greeter theme:

```bash
./install.sh --with-sddm
```

### Post-Install Adjustments
1. **Monitor Layout**: Update `hl.monitor(...)` entries (`DP-3`, `HDMI-A-1`, `DP-2`) in `~/.config/hypr/hyprland.lua` to match `hyprctl monitors`.
2. **Keyboard Layout**: Update `kb_layout = "jp"` in `~/.config/hypr/hyprland.lua` if you use another layout.
3. **Palette Sync**: Open **Quick Tools → Colors** (or choose a wallpaper in **Wallpapers**) to generate and sync your active Material You color scheme.
4. **Custom Island Module**: `.config/quickshell/main/VM600PEBattery.qml` is an example hardware-specific Dynamic Island extension (`~/vm600pe-battery.py`); see [`ISLAND-EXTENSIONS.md`](.config/quickshell/main/ISLAND-EXTENSIONS.md) to build your own.

---

## Third-Party Assets & Licensing

- Dotfiles & original QML/Python code: [MIT License](LICENSE).
- `Doto.ttf`: Licensed under SIL Open Font License 1.1 (see `Doto-OFL.txt`).
- `GoogleSansFlex.ttf`: Licensed under SIL Open Font License 1.1 (see `OFL.txt`).
- `codex-badge.svg`: Mozilla Public License 2.0 (see `.config/quickshell/main/codex-badge-LICENSE`).
- `launcher-data/emoji.json` & `launcher-data/qrcode/`: See `emoji-LICENSE` and `qrcode-LICENSE`.
