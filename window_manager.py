"""Original window management helpers.

Provides basic device window operations such as launching the home screen
and recent apps.
"""

from __future__ import annotations

from adb_client import AdbClient


class WindowManager:
    """Manages Android device windows/tasks via ADB."""

    def __init__(self, adb: AdbClient) -> None:
        self.adb = adb

    def home(self, serial: str) -> None:
        """Return to the home screen."""
        self.adb.keyevent(serial, 3)  # KEYCODE_HOME

    def recent_apps(self, serial: str) -> None:
        """Open the recent-apps overview."""
        self.adb.keyevent(serial, 187)  # KEYCODE_APP_SWITCH

    def lock(self, serial: str) -> None:
        """Lock the device screen."""
        self.adb.keyevent(serial, 26)  # KEYCODE_POWER

    def notifications(self, serial: str) -> None:
        """Expand the notification drawer."""
        self.adb.expand_notifications(serial)
