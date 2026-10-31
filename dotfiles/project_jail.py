#!/usr/bin/env python3

# Automatically put shell sessions in bwrap when navigating to a project folder.
# Supply chain attack mitigation.
# Written by GPT-5.4 and adapted slightly by hand and GPT-6.

import json
import os
import subprocess
import shutil
import stat
import sys
from pathlib import Path

CONFIG_PATH = Path.home() / ".config" / "jails.json"
MARKER_ENV = "IN_PROJECT_JAIL"
ANTIJACK_SYSCALL_FILTER = Path.home() / ".config" / "jail-antijack"

# this is not great because it shares the caches, but oh well
PROFILES = {
    "rust": [
        ("ro", "~/.cargo/bin"),
        ("rw", "~/.cargo/git"),
        ("rw", "~/.cargo/registry"),
        ("ro", "~/.rustup")
    ],
    "node": [
        ("rw", "~/.npm"),
        ("rw", "~/.cache/node-gyp"),
    ],
    "python": [
        ("rw", "~/.cache/uv"),
        ("rw", "~/.cache/pip"),
    ],
    "gpu": [
        ("ro", "/sys"),
        ("dev", "/dev/dri"),
        ("dev", "/dev/ipu0"),
        ("dev", "/dev/ipu0_ex"),
        ("dev", "/dev/ipu0_mem"),
        ("dev", "/dev/ipu0_p2p"),
    ],
    "codex": [
        ("rw", "~/.codex")
    ],
    "go": [
        ("rw", "~/go"),
    ],
    "git": [("ro", "~/.gitconfig")],
    "claude": [
        ("rw", "~/.claude")
    ],
    "misc": [("ro", "~/.local/bin")],
    # Bind the bus directory, not individual bus nodes, so libusb sees hotplug.
    # Host device permissions/udev ACLs still apply.
    "usb": [("ro", "/sys"), ("dev", "/dev/bus/usb")]
}

# Preserve the user's development environment, but remove host service
# addresses. Selected Wayland/audio endpoints are restored after mounting them.
HOST_SERVICE_ENV = (
    "DBUS_SESSION_BUS_ADDRESS", "DBUS_SYSTEM_BUS_ADDRESS",
    "SSH_AUTH_SOCK", "SSH_AGENT_PID", "GPG_AGENT_INFO",
    "DISPLAY", "XAUTHORITY", "SESSION_MANAGER",
    "WAYLAND_DISPLAY", "WAYLAND_SOCKET", "PULSE_SERVER", "PIPEWIRE_REMOTE",
)


def desktop_socket_args(runtime_dir: str) -> list[str]:
    """Expose individual desktop sockets, never the session bus/agent directory."""
    cmd = []
    runtime = Path(runtime_dir)
    wayland = os.environ.get("WAYLAND_DISPLAY")
    sockets = [
        (runtime / "pulse/native", "PULSE_SERVER", f"unix:{runtime}/pulse/native"),
        (runtime / "pipewire-0", None, None),
    ]
    if wayland:
        path = Path(wayland)
        if not path.is_absolute():
            path = runtime / path
        # Do not allow a display variable to expose an arbitrary host socket.
        if path.parent == runtime and path.name.startswith("wayland-"):
            sockets.append((path, "WAYLAND_DISPLAY", wayland))
    for path, variable, value in sockets:
        try:
            # Reject symlinks as well as non-sockets.
            if not stat.S_ISSOCK(path.lstat().st_mode):
                continue
        except FileNotFoundError:
            continue
        cmd += ["--ro-bind", str(path), str(path)]
        if variable:
            cmd += ["--setenv", variable, value]
    return cmd

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

def build_bwrap_command(entry: dict, cwd: Path, fd: int) -> list[str]:
    bwrap = shutil.which("bwrap")
    if not bwrap:
        print("project-jail: bwrap not found in PATH", file=sys.stderr)
        sys.exit(1)

    shell = os.environ.get("SHELL", "/usr/bin/fish")
    home = Path.home()
    project_root = resolve_path(str(entry["path"]))

    state_dir = Path(os.environ.get("XDG_STATE_HOME", home / ".local" / "state")) / "project-jails"
    sandbox_name = entry.get("name") or project_root.name
    sandbox_home = state_dir / sandbox_name / Path(os.path.expanduser("~")).relative_to("/")

    ensure_dir(sandbox_home)

    ro_binds = [
        "/usr",
        "/bin",
        "/sbin",
        "/lib",
        "/lib64",
        "/opt",
        "/etc",
    ]
    dev_binds = []

    home = os.path.expanduser("~")

    cmd = [
        bwrap,
        "--unshare-all",
        "--share-net",
        "--die-with-parent",
        "--proc", "/proc",
        "--dev", "/dev",
        "--tmpfs", "/dev/shm",
        "--tmpfs", "/tmp",
        "--bind", str(sandbox_home), home,
        "--setenv", "HOME", home,
        "--setenv", "USER", os.environ.get("USER", ""),
        "--setenv", "LOGNAME", os.environ.get("LOGNAME", ""),
        "--setenv", MARKER_ENV, "1",
        "--setenv", "PROJECT_ROOT", str(project_root),
        # Real chown to an unmapped ID returns EINVAL, which fakeroot does not
        # suppress. Keep ownership changes entirely in fakeroot's database.
        "--setenv", "FAKEROOTDONTTRYCHOWN", "1",
        "--chdir", str(cwd),
        "--seccomp", str(fd)
    ]
    for variable in HOST_SERVICE_ENV:
        cmd += ["--unsetenv", variable]

    rw_binds = []

    for profile in entry["profile"]:
        for mode, path in PROFILES[profile]:
            path = str(resolve_path(path))
            if mode == "rw":
                rw_binds.append(path)
            elif mode == "ro":
                ro_binds.append(path)
            elif mode == "dev":
                dev_binds.append(path)
            else:
                raise ValueError(f"Unknown mount mode: {mode}")

    if "usb" in entry["profile"]:
        # Serial/HID interfaces live outside usbfs. Individual binds cover
        # devices present at entry; reconnecting these requires a new jail.
        for pattern in ("ttyUSB*", "ttyACM*", "hidraw*"):
            dev_binds.extend(str(path) for path in sorted(Path("/dev").glob(pattern)))
        ro_binds.append("/dev/serial")

    for path in ro_binds:
        if Path(path).exists():
            cmd += ["--ro-bind", path, path]

    for path in rw_binds:
        if Path(path).exists():
            cmd += ["--bind", path, path]

    for path in dev_binds:
        if Path(path).exists():
            cmd += ["--dev-bind", path, path]

    # A private runtime directory hides systemd/D-Bus, SSH/GPG agents and other
    # host control sockets. Keep Wayland/audio working via selected sockets.
    runtime_dir = f"/run/user/{os.getuid()}"
    host_runtime = os.environ.get("XDG_RUNTIME_DIR")
    if host_runtime and Path(host_runtime).is_absolute():
        runtime_dir = host_runtime
    cmd += ["--perms", "0700", "--tmpfs", runtime_dir]
    cmd += ["--setenv", "XDG_RUNTIME_DIR", runtime_dir]
    if host_runtime:
        cmd += desktop_socket_args(runtime_dir)

    cmd += ["--setenv", "fish_color_cwd", "red"]

    cmd += ["--setenv", "SHELL", shell]

    # Mount the selected project tree at the same absolute path.
    cmd += ["--bind", str(project_root), str(project_root)]

    cmd += [
        shell,
        "-i",
    ]
    #print(cmd)
    print(f"-> sandbox profile {entry['profile']} for {sandbox_name}", flush=True)
    return cmd

def main() -> int:
    if os.environ.get(MARKER_ENV) == "1":
        return 0

    cwd = Path.cwd().resolve()
    config = load_config()
    entry = find_matching_entry(cwd, config)
    if not entry:
        return 2

    if not ANTIJACK_SYSCALL_FILTER.exists():
        subprocess.run(["antijack", "-o", ANTIJACK_SYSCALL_FILTER]).check_returncode()

    # TODO: seccomp filter is not invulnerable and this would ideally be pty-based
    f = open(ANTIJACK_SYSCALL_FILTER, "rb")
    fd = f.fileno()
    os.set_inheritable(fd, True)

    cmd = build_bwrap_command(entry, cwd, fd)
    os.execvp(cmd[0], cmd)
    return 1

if __name__ == "__main__":
    raise SystemExit(main())
