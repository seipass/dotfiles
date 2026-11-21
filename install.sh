#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
USE_LINK=0
WITH_SDDM=0
BACKUP_CREATED=0

usage() {
    cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Options:
  --copy         Copy files into $HOME (default; creates backups if files exist)
  --link         Symlink files from repo instead of copying
  --with-sddm    Install Afterglow SDDM theme into /usr/share/sddm/themes/afterglow (uses sudo)
  --dry-run      Print actions without modifying files
  -h, --help     Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --copy) USE_LINK=0 ;;
        --link) USE_LINK=1 ;;
        --with-sddm) WITH_SDDM=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '[dry-run]'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

backup_if_exists() {
    local dst="$1"
    if [[ -e "$dst" || -L "$dst" ]]; then
        local rel="${dst#"$HOME"/}"
        local bdst="$BACKUP_ROOT/$rel"
        run mkdir -p "$(dirname -- "$bdst")"
        run mv "$dst" "$bdst"
        BACKUP_CREATED=1
    fi
}

deploy_item() {
    local rel="$1"
    local src="$REPO_DIR/$rel"
    local dst="$HOME/$rel"
    if [[ ! -e "$src" ]]; then
        return 0
    fi
    run mkdir -p "$(dirname -- "$dst")"
    backup_if_exists "$dst"
    if [[ $USE_LINK -eq 1 ]]; then
        run ln -sfn "$src" "$dst"
    else
        run cp -a "$src" "$dst"
    fi
}

echo "==> Installing dotfiles from $REPO_DIR"
[[ $DRY_RUN -eq 1 ]] && echo "==> Dry-run mode enabled (no files will be modified)"

CONFIG_TARGETS=(
    ".config/fcitx5"
    ".config/gtk-3.0"
    ".config/gtk-4.0"
    ".config/hypr"
    ".config/kitty"
    ".config/qt6ct"
    ".config/user-dirs.dirs"
    ".config/user-dirs.locale"
)

for target in "${CONFIG_TARGETS[@]}"; do
    deploy_item "$target"
done

# Deploy Quickshell main config while preserving any existing runtime .ini state
QS_SRC="$REPO_DIR/.config/quickshell/main"
QS_DST="$HOME/.config/quickshell/main"
run mkdir -p "$QS_DST"
for item in "$QS_SRC"/*; do
    name="$(basename -- "$item")"
    case "$name" in
        dashboard.ini|taskbar.ini|daily-tools.ini|__pycache__) continue ;;
    esac
    deploy_item ".config/quickshell/main/$name"
done

# Deploy Fcitx5 themes
FCITX_THEMES_SRC="$REPO_DIR/.local/share/fcitx5/themes"
if [[ -d "$FCITX_THEMES_SRC" ]]; then
    for theme_dir in "$FCITX_THEMES_SRC"/*; do
        [[ -d "$theme_dir" ]] || continue
        deploy_item ".local/share/fcitx5/themes/$(basename -- "$theme_dir")"
    done
fi

# Resolve @HOME@ placeholder in qt6ct.conf when copied
QT6CT_DST="$HOME/.config/qt6ct/qt6ct.conf"
if [[ $USE_LINK -eq 0 ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "[dry-run] replace @HOME@ with $HOME in $QT6CT_DST"
    elif [[ -f "$QT6CT_DST" ]]; then
        python3 - "$QT6CT_DST" "$HOME" <<'PY'
import sys
from pathlib import Path

conf = Path(sys.argv[1])
home = sys.argv[2]
conf.write_text(conf.read_text().replace("@HOME@", home))
PY
    fi
elif [[ -f "$QT6CT_DST" ]]; then
    echo "Note: --link used; apply-palette.py --sync-desktop will resolve @HOME@ in qt6ct.conf when palette sync runs."
fi

# Ensure helper scripts are executable
if [[ $DRY_RUN -eq 0 ]]; then
    find "$QS_DST" "$HOME/.config/hypr" -maxdepth 1 -type f -name '*.py' -exec chmod +x {} + 2>/dev/null || true
else
    echo "[dry-run] chmod +x Python helper scripts in $QS_DST and $HOME/.config/hypr"
fi

# Initialize live palette tokens (Qt6, GTK3/4, Kitty, Hyprland, Fcitx5)
if [[ -f "$QS_DST/apply-palette.py" ]] && command -v python3 >/dev/null 2>&1; then
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "[dry-run] python3 $QS_DST/apply-palette.py pink --sync-desktop"
    else
        python3 "$QS_DST/apply-palette.py" pink "" --sync-desktop >/dev/null 2>&1 || true
    fi
fi

# Optional SDDM theme installation
SDDM_SRC="$REPO_DIR/.local/share/sddm/themes/afterglow"
if [[ $WITH_SDDM -eq 1 && -d "$SDDM_SRC" ]]; then
    echo "==> Installing Afterglow SDDM theme to /usr/share/sddm/themes/afterglow"
    run sudo mkdir -p /usr/share/sddm/themes
    run sudo rm -rf /usr/share/sddm/themes/afterglow
    run sudo cp -a "$SDDM_SRC" /usr/share/sddm/themes/afterglow
    echo "    Activate in /etc/sddm.conf.d/afterglow.conf with:"
    echo "      [Theme]"
    echo "      Current=afterglow"
fi

echo ""
echo "==> Done!"
if [[ $BACKUP_CREATED -eq 1 ]]; then
    echo "    Existing files backed up to: $BACKUP_ROOT"
fi
cat <<'EOF'

Next steps:
  1. Edit ~/.config/hypr/hyprland.lua to match your monitor names/rates and kb_layout.
  2. Start Quickshell (or reload Hyprland):
       qs --no-duplicate --config main --daemonize
  3. Open Quick Tools (rail settings icon) -> Wallpapers / Colors to pick a wallpaper and generate your Material You palette.
  4. Optional SDDM theme test:
       ./install.sh --with-sddm
       sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/afterglow
EOF
