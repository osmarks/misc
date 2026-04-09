#!/usr/bin/env python3

# Automatically put shell sessions in bwrap when navigating to a project folder.
# Supply chain attack mitigation.
# Written by GPT-5.4 and adapted slightly by hand.

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


CONFIG_PATH = Path.home() / ".config" / "jails.json"
MARKER_ENV = "IN_PROJECT_JAIL"

PROFILES = {
    "rust": [
        ("rw", "~/.cargo/bin"),
        ("rw", "~/.cargo/git"),
        ("ro", "~/.gitconfig")
    ],
    "node": [
        ("rw", "~/.npm"),
        ("rw", "~/.cache/node-gyp"),
        ("ro", "~/.gitconfig")
    ],
    "python": []
}

def load_config() -> dict[str, dict]:
    with CONFIG_PATH.open("r", encoding="utf-8") as f:
        res = json.load(f)
        for path, entry in res.items():
            entry["path"] = path
        return res

def resolve_path(p: str) -> Path:
    return Path(os.path.expandvars(os.path.expanduser(p))).resolve()

def find_matching_entry(cwd: Path, config: dict[str, dict]) -> dict | None:
    best: tuple[int, dict] | None = None

    for path, entry in config.items():
        try:
            root = resolve_path(str(path))
            cwd.relative_to(root)
        except Exception:
            continue

        score = len(root.parts)
        if best is None or score > best[0]:
            best = (score, entry)

    return best[1] if best else None

def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)

def build_bwrap_command(entry: dict, cwd: Path) -> list[str]:
    bwrap = shutil.which("bwrap")
    if not bwrap:
        print("project-jail: bwrap not found in PATH", file=sys.stderr)
        sys.exit(1)

    shell = os.environ.get("SHELL", "/usr/bin/fish")
    home = Path.home()
    project_root = resolve_path(str(entry["path"]))

    state_dir = Path(os.environ.get("XDG_STATE_HOME", home / ".local" / "state")) / "project-jails"
    sandbox_name = entry.get("name") or project_root.name
    sandbox_home = state_dir / sandbox_name / "home"
    sandbox_tmp = state_dir / sandbox_name / "tmp"

    ensure_dir(sandbox_home)
    ensure_dir(sandbox_tmp)

    ro_binds = [
        "/usr",
        "/bin",
        "/sbin",
        "/lib",
        "/lib64",
        "/opt",
        "/etc",
    ]
    dev_binds = [
        "/dev/dri",   # GPU
        "/dev/shm",   # shared memory
    ]

    cmd = [
        bwrap,
        "--unshare-all",
        "--share-net",
        "--die-with-parent",
        "--proc", "/proc",
        "--dev", "/dev",
        "--tmpfs", "/tmp",
        "--dir", str(sandbox_home),
        "--setenv", "HOME", str(sandbox_home),
        "--setenv", "USER", os.environ.get("USER", ""),
        "--setenv", "LOGNAME", os.environ.get("LOGNAME", ""),
        "--setenv", MARKER_ENV, "1",
        "--setenv", "PROJECT_ROOT", str(project_root),
        "--chdir", str(cwd),
    ]

    rw_binds = []

    profile = PROFILES[entry["profile"]]
    for type, path in profile:
        path = str(resolve_path(path))
        if type == "rw":
            rw_binds.append(path)
        elif type == "ro":
            ro_binds.append(path)
        else:
            assert False

    for path in ro_binds:
        if Path(path).exists():
            cmd += ["--ro-bind", path, path]

    for path in rw_binds:
        if Path(path).exists():
            cmd += ["--bind", path, path]

    for path in dev_binds:
        if Path(path).exists():
            cmd += ["--dev-bind", path, path]

    runtime_dir = os.environ.get("XDG_RUNTIME_DIR")
    if runtime_dir and Path(runtime_dir).exists():
        cmd += ["--bind", runtime_dir, runtime_dir]
        cmd += ["--setenv", "XDG_RUNTIME_DIR", runtime_dir]

    cmd += ["--setenv", "fish_color_cwd", "red"]

    envs = ["WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "PULSE_SERVER"]

    for env in envs:
        if res := os.environ.get(env):
            cmd += ["--setenv", env, res]

    # Mount the selected project tree at the same absolute path.
    cmd += ["--bind", str(project_root), str(project_root)]

    # Minimal env cleanup.
    cmd += [
        shell,
        "-i",
    ]
    print(f"-> sandbox profile {entry['profile']} for {entry['name']}")
    return cmd

def main() -> int:
    if os.environ.get(MARKER_ENV) == "1":
        return 0

    cwd = Path.cwd().resolve()
    config = load_config()
    entry = find_matching_entry(cwd, config)
    if not entry:
        return 2

    cmd = build_bwrap_command(entry, cwd)
    os.execvp(cmd[0], cmd)
    return 1

if __name__ == "__main__":
    raise SystemExit(main())
