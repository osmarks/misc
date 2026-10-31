"""Run with python3 -m unittest -v test_project_jail."""

import contextlib
import io
import json
import os
from pathlib import Path
import shutil
import socket
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import project_jail as jail


class ProjectJailTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="project-jail-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.project = self.root / "project"
        self.runtime = self.root / "runtime"
        for path in (self.home, self.project, self.runtime):
            path.mkdir()
        self.env = patch.dict(os.environ, {
            "HOME": str(self.home),
            "XDG_STATE_HOME": str(self.root / "state"),
            "XDG_RUNTIME_DIR": str(self.runtime),
            "SHELL": "/bin/sh",
            "WAYLAND_DISPLAY": "wayland-0",
        })
        self.env.start()
        self.addCleanup(self.env.stop)

    def command(self, profiles=(), fd=3):
        entry = {"path": str(self.project), "profile": list(profiles)}
        with contextlib.redirect_stdout(io.StringIO()):
            return jail.build_bwrap_command(entry, self.project, fd)

    def bind_socket(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        sock = socket.socket(socket.AF_UNIX)
        self.addCleanup(sock.close)
        sock.bind(str(path))

    def test_devices_are_profile_scoped(self):
        # Simulate hardware absent on CI without needing mknod or real devices.
        with patch.object(Path, "exists", return_value=True), patch.object(
            Path, "glob", side_effect=lambda pattern: {
                "ttyUSB*": [Path("/dev/ttyUSB0")],
                "ttyACM*": [Path("/dev/ttyACM0")],
                "hidraw*": [Path("/dev/hidraw0")],
            }[pattern]
        ):
            default = self.command()
            usb = self.command(["usb"])
            gpu = self.command(["gpu"])
        self.assertNotIn("--dev-bind", default)
        for device in ("/dev/bus/usb", "/dev/ttyUSB0", "/dev/ttyACM0", "/dev/hidraw0"):
            index = usb.index(device)
            self.assertEqual(usb[index - 1:index + 2], ["--dev-bind", device, device])
        self.assertNotIn("/dev/dri", usb)
        self.assertIn("/dev/dri", gpu)
        for command in (usb, gpu):
            index = command.index("/sys")
            self.assertEqual(command[index - 1], "--ro-bind")

    def test_only_selected_desktop_sockets_are_exposed(self):
        for name in ("wayland-0", "bus", "ssh-agent", "pulse/native", "pipewire-0"):
            self.bind_socket(self.runtime / name)
        args = jail.desktop_socket_args(str(self.runtime))
        for name in ("wayland-0", "pulse/native", "pipewire-0"):
            self.assertIn(str(self.runtime / name), args)
        for name in ("bus", "ssh-agent"):
            self.assertNotIn(str(self.runtime / name), args)
        (self.runtime / "wayland-0").unlink()
        (self.runtime / "wayland-0").symlink_to(self.runtime / "bus")
        args = jail.desktop_socket_args(str(self.runtime))
        self.assertNotIn("WAYLAND_DISPLAY", args)
        with patch.dict(os.environ, {"WAYLAND_DISPLAY": str(self.runtime / "bus")}):
            self.assertNotIn("WAYLAND_DISPLAY", jail.desktop_socket_args(str(self.runtime)))

    @unittest.skipUnless(shutil.which("bwrap") and shutil.which("fakeroot"),
                         "integration test requires bwrap and fakeroot")
    def test_running_jail(self):
        cargo_bin = self.home / ".cargo/bin"
        cargo_bin.mkdir(parents=True)
        (cargo_bin / "host-tool").write_text("host executable")
        (self.runtime / "host-secret").write_text("must not be visible")
        self.bind_socket(self.runtime / "bus")
        self.bind_socket(self.runtime / "wayland-0")
        env = {
            "PROJECT_JAIL_CUSTOM_SETTING": "preserved",
            "DBUS_SESSION_BUS_ADDRESS": f"unix:path={self.runtime}/bus",
            "SSH_AUTH_SOCK": str(self.runtime / "ssh-agent"),
            "DISPLAY": ":0",
        }
        # This test checks mount/environment policy, not the external antijack
        # program. Supply a valid allow-all BPF program for --seccomp.
        with tempfile.TemporaryFile() as seccomp, patch.dict(os.environ, env):
            seccomp.write(struct.pack("HBBI", 0x06, 0, 0, 0x7fff0000))
            seccomp.seek(0)
            cmd = self.command(["rust", "usb"], seccomp.fileno())
            probe = r'''
import json, os, pathlib, stat, subprocess
home = pathlib.Path.home()
runtime = pathlib.Path(os.environ["XDG_RUNTIME_DIR"])
assert not (runtime / "host-secret").exists()
assert not (runtime / "bus").exists()
assert stat.S_ISSOCK((runtime / "wayland-0").stat().st_mode)
assert stat.S_IMODE(runtime.stat().st_mode) == 0o700
assert os.environ["PROJECT_JAIL_CUSTOM_SETTING"] == "preserved"
assert not any(key in os.environ for key in ("DBUS_SESSION_BUS_ADDRESS", "SSH_AUTH_SOCK", "DISPLAY"))
assert os.environ["WAYLAND_DISPLAY"] == "wayland-0"
assert os.environ["FAKEROOTDONTTRYCHOWN"] == "1"
try:
    (home / ".cargo/bin/host-tool").write_text("overwritten")
except OSError:
    pass
else:
    raise AssertionError("host executable is writable")
assert not os.access("/sys", os.W_OK)
pathlib.Path("/dev/shm/private").write_text("private")
pathlib.Path("project-write").write_text("writable")
result = subprocess.run(["fakeroot", "sh", "-ec",
    "touch /tmp/owned; chown 123:456 /tmp/owned; stat -c %u:%g /tmp/owned"],
    text=True, capture_output=True, timeout=10, check=True)
assert result.stdout.strip() == "123:456", result.stdout
assert pathlib.Path("/tmp/owned").stat().st_uid == os.getuid()
print(json.dumps({"shm_device": pathlib.Path("/dev/shm").stat().st_dev}))
'''
            result = subprocess.run(cmd[:-2] + ["/usr/bin/python3", "-c", probe],
                                    pass_fds=(seccomp.fileno(),), capture_output=True,
                                    text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotEqual(json.loads(result.stdout)["shm_device"], Path("/dev/shm").stat().st_dev)
        self.assertEqual((self.project / "project-write").read_text(), "writable")
        self.assertEqual((cargo_bin / "host-tool").read_text(), "host executable")


if __name__ == "__main__":
    unittest.main()
