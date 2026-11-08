"""Original ADB client wrapper.

Talks to Android devices through the Android Debug Bridge (adb) using
subprocess calls. No third-party ADB libraries are used.
"""

from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass
from typing import List, Optional


@dataclass
class Device:
    """Represents a connected Android device."""

    serial: str
    state: str
    model: Optional[str] = None


class AdbClient:
    """Thin wrapper around the adb command-line tool."""

    def __init__(self, adb_path: Optional[str] = None) -> None:
        self.adb_path = adb_path or shutil.which("adb") or shutil.which("adb.exe") or "adb"

    def _run(self, args: List[str], serial: Optional[str] = None) -> subprocess.CompletedProcess:
        cmd = [self.adb_path]
        if serial:
            cmd.extend(["-s", serial])
        cmd.extend(args)
        return subprocess.run(cmd, capture_output=True, text=True, check=False)

    def is_available(self) -> bool:
        """Return True if the adb executable can be found."""
        return shutil.which(self.adb_path) is not None

    def start_server(self) -> subprocess.CompletedProcess:
        """Ensure the local adb server is running."""
        return self._run(["start-server"])

    def list_devices(self) -> List[Device]:
        """Return a list of currently connected devices."""
        result = self._run(["devices", "-l"])
        devices: List[Device] = []
        for line in result.stdout.splitlines():
            line = line.strip()
            if not line or line.startswith("List of devices"):
                continue
            parts = line.split()
            if len(parts) < 2:
                continue
            serial = parts[0]
            state = parts[1]
            model = None
            for part in parts[2:]:
                if part.startswith("model:"):
                    model = part.split(":", 1)[1]
                    break
            devices.append(Device(serial=serial, state=state, model=model))
        return devices

    def shell(self, serial: str, command: str) -> subprocess.CompletedProcess:
        """Run an arbitrary shell command on the device."""
        return self._run(["shell", command], serial=serial)

    def keyevent(self, serial: str, keycode: int) -> subprocess.CompletedProcess:
        """Send a keyevent to the device."""
        return self._run(["shell", "input", "keyevent", str(keycode)], serial=serial)

    def tap(self, serial: str, x: int, y: int) -> subprocess.CompletedProcess:
        """Tap a screen coordinate."""
        return self._run(["shell", "input", "tap", str(x), str(y)], serial=serial)

    def swipe(
        self,
        serial: str,
        x1: int,
        y1: int,
        x2: int,
        y2: int,
        duration: Optional[int] = None,
    ) -> subprocess.CompletedProcess:
        """Swipe from one coordinate to another with optional duration in ms."""
        args = ["shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2)]
        if duration is not None:
            args.append(str(duration))
        return self._run(args, serial=serial)

    def start_activity(
        self, serial: str, intent: str, data_uri: Optional[str] = None
    ) -> subprocess.CompletedProcess:
        """Start an Android activity via an intent string or action with optional data URI."""
        cmd = ["shell", "am", "start"]
        parts = intent.split()
        if len(parts) > 1 and "-d" in parts:
            d_idx = parts.index("-d")
            action = " ".join(parts[:d_idx])
            cmd.extend(["-a", action, "-d"] + parts[d_idx + 1:])
        else:
            cmd.extend(["-a", intent])
        if data_uri:
            cmd.extend(["-d", data_uri])
        return self._run(cmd, serial=serial)

    def start_component(self, serial: str, component: str) -> subprocess.CompletedProcess:
        """Start an Android component via package/activity (am start -n)."""
        return self._run(["shell", "am", "start", "-n", component], serial=serial)

    def expand_notifications(self, serial: str) -> subprocess.CompletedProcess:
        """Expand the notification drawer."""
        return self._run(["shell", "cmd", "statusbar", "expand-notifications"], serial=serial)

    def take_screenshot(self, serial: str) -> Optional[bytes]:
        """Capture a raw PNG screenshot from the device."""
        cmd = [self.adb_path, "-s", serial, "exec-out", "screencap", "-p"]
        try:
            res = subprocess.run(cmd, capture_output=True, timeout=10)
            if res.returncode == 0 and res.stdout.startswith(b"\x89PNG"):
                return res.stdout
        except Exception:
            pass
        return None

    def get_launcher_activities(self, serial: str) -> List[tuple[str, str]]:
        """Return list of (package, activity) for all launchable apps."""
        res = self._run(
            ["shell", "cmd", "package", "query-activities", "--brief", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER"],
            serial=serial,
        )
        activities: List[tuple[str, str]] = []
        for line in res.stdout.splitlines():
            line = line.strip()
            if "/" in line and not line.startswith("priority=") and not line.startswith("Activity"):
                parts = line.split("/", 1)
                pkg = parts[0].strip()
                act = parts[1].strip()
                activities.append((pkg, act))
        return activities

    def get_property(self, serial: str, prop: str) -> str:
        """Get a single system property from the device."""
        result = self._run(["shell", "getprop", prop], serial=serial)
        return result.stdout.strip()
