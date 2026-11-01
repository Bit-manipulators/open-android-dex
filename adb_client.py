"""Original ADB client wrapper.

Communicates with Android devices through the Android Debug Bridge (adb)
using subprocess calls. No third-party ADB libraries are used.
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
        self.adb_path = adb_path or shutil.which("adb") or "adb"

    def _run(self, args: List[str], serial: Optional[str] = None) -> subprocess.CompletedProcess:
        cmd = [self.adb_path]
        if serial:
            cmd.extend(["-s", serial])
        cmd.extend(args)
        return subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=False,
        )

    def is_available(self) -> bool:
        """Return True if the adb executable can be found."""
        return shutil.which(self.adb_path) is not None

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

    def get_property(self, serial: str, prop: str) -> str:
        """Get a single system property from the device."""
        result = self._run(["shell", "getprop", prop], serial=serial)
        return result.stdout.strip()

    def shell(self, serial: str, command: str) -> subprocess.CompletedProcess:
        """Run an arbitrary shell command on the device."""
        return self._run(["shell", command], serial=serial)

    def start_activity(self, serial: str, intent: str) -> subprocess.CompletedProcess:
        """Start an Android activity via an intent string."""
        return self._run(["shell", "am", "start", "-a", intent], serial=serial)

    def keyevent(self, serial: str, keycode: int) -> subprocess.CompletedProcess:
        """Send a keyevent to the device."""
        return self._run(["shell", "input", "keyevent", str(keycode)], serial=serial)

    def tap(self, serial: str, x: int, y: int) -> subprocess.CompletedProcess:
        """Tap a screen coordinate."""
        return self._run(["shell", "input", "tap", str(x), str(y)], serial=serial)

    def swipe(self, serial: str, x1: int, y1: int, x2: int, y2: int) -> subprocess.CompletedProcess:
        """Swipe from one coordinate to another."""
        return self._run(
            ["shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2)],
            serial=serial,
        )
