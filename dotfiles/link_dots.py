from pathlib import Path
import subprocess
import sys
import os

files = {
    "config.fish": "~/.config/fish/config.fish",
    "dunstrc": "~/.config/dunst/dunstrc",
    "fix_gnome.sh": "~/.local/bin/fix_gnome.sh",
    "lock": "~/.local/bin/lock",
    "run_sway_env": "~/.local/bin/run_sway_env",
    "settings.ini": "~/.config/gtk-3.0/settings.ini",
    "sway_config": "~/.config/sway/config",
    "zed.json": "~/.config/zed/settings.json",
    "xkb_custom": "~/.config/xkb/symbols/custom",
    "sway_custom.desktop": "/usr/share/wayland-sessions/sway_custom.desktop",
    "take-screenshot": "~/.local/bin/take-screenshot",
    "take-screenshot-window": "~/.local/bin/take-screenshot-window",
    "waybar_config": "~/.config/waybar/config",
    "waybar_style.css": "~/.config/waybar/style.css",
    "wezterm.lua": "~/.wezterm.lua"
}

packages = [
    "sway",
    "waybar",
    "firefox",
    "zed",
    "ttc-iosevka",
    "otf-font-awesome",
    "dunst",
    "slurp",
    "grim",
    "wezterm",
    "ttf-fira-code",
    "network-manager-applet",
    "kanshi",
    "bemenu-wayland",
    "pavucontrol",
    "swaylock",
    "jq"
]

subprocess.run(["sudo", "pacman", "-S", *packages])

this = Path(sys.argv[0]).parent
print(this)

for src, trg in files.items():
    real_src = this / src
    real_trg = Path(trg).expanduser()
    os.makedirs(real_trg.parent, exist_ok=True)
    if not real_trg.exists():
        subprocess.run(["sudo", "ln", "-s", real_src.absolute(), real_trg])
        subprocess.run(["sudo", "chown", "osmarks:osmarks", real_trg])
        print(real_trg)
