"""Original volume control module.

Adjusts Android device media volume via ADB keyevents.
"""

from __future__ import annotations

from adb_client import AdbClient


class VolumeControl:
    """Controls device volume through ADB."""

    def __init__(self, adb: AdbClient) -> None:
        self.adb = adb

    def up(self, serial: str) -> None:
        """Raise the volume by one step."""
        self.adb.keyevent(serial, 24)  # KEYCODE_VOLUME_UP

    def down(self, serial: str) -> None:
        """Lower the volume by one step."""
        self.adb.keyevent(serial, 25)  # KEYCODE_VOLUME_DOWN

    def mute(self, serial: str) -> None:
        """Toggle media volume mute."""
        self.adb.keyevent(serial, 164)  # KEYCODE_VOLUME_MUTE
