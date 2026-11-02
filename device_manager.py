"""Device selection manager.

Original implementation of the target-device selection state machine,
modeled on the behavior documented in public architecture notes:
auto-select when exactly one device is present, otherwise require an
explicit user selection. No code or data was taken from any
closed-source application.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional, Tuple

from adb_client import AdbClient, Device


class DeviceManager:
    """Tracks which connected Android device is the active target."""

    def __init__(self, adb: AdbClient) -> None:
        self.adb = adb
        self.selected: Optional[Device] = None

    def online_devices(self) -> List[Device]:
        """Return devices that are connected and authorized."""
        return [dev for dev in self.adb.list_devices() if dev.state == "device"]

    def all_devices(self) -> List[Device]:
        """Return every device entry, including unauthorized/offline ones."""
        return self.adb.list_devices()

    def auto_detect(self) -> Tuple[Optional[Device], bool]:
        """Detect devices and select one if unambiguous.

        Returns a tuple ``(selected, needs_selection)``:

        * Exactly one online device → it is selected automatically.
        * Zero devices → ``needs_selection`` is True (nothing to pick yet).
        * Two or more devices → ``needs_selection`` is True; the user must
          choose one in the device list.
        """
        devs = self.online_devices()
        if len(devs) == 1:
            self.selected = devs[0]
            return self.selected, False
        self.selected = None
        return None, True

    def select(self, serial: str) -> Optional[Device]:
        """Explicitly select a device by serial (from the picker UI)."""
        for dev in self.all_devices():
            if dev.serial == serial:
                self.selected = dev if dev.state == "device" else None
                return self.selected
        return None
