"""Original URL launcher.

Opens a web URL on the Android device through an intent.
"""

from __future__ import annotations

from .adb_client import AdbClient


class UrlLauncher:
    """Launches URLs on the Android device."""

    def __init__(self, adb: AdbClient) -> None:
        self.adb = adb

    def open(self, serial: str, url: str) -> None:
        """Open the given URL in the device's default browser."""
        intent = f"android.intent.action.VIEW -d {url}"
        self.adb.start_activity(serial, intent)
