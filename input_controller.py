"""Original input controller.

Translates desktop key and mouse events into Android input events via ADB.
"""

from __future__ import annotations

from adb_client import AdbClient


# Android keyevent codes (original constants).
KEYCODE_HOME = 3
KEYCODE_BACK = 4
KEYCODE_MENU = 82
KEYCODE_VOLUME_UP = 24
KEYCODE_VOLUME_DOWN = 25
KEYCODE_POWER = 26
KEYCODE_ENTER = 66
KEYCODE_DEL = 67
KEYCODE_FORWARD_DEL = 112
KEYCODE_ESCAPE = 111
KEYCODE_SPACE = 62
KEYCODE_APP_SWITCH = 187


class InputController:
    """Sends input events to an Android device through ADB."""

    def __init__(self, adb: AdbClient) -> None:
        self.adb = adb

    def send_key(self, serial: str, keycode: int) -> None:
        """Send a keyevent to the device."""
        self.adb.keyevent(serial, keycode)

    def home(self, serial: str) -> None:
        """Press the home button."""
        self.send_key(serial, KEYCODE_HOME)

    def back(self, serial: str) -> None:
        """Press the back button."""
        self.send_key(serial, KEYCODE_BACK)

    def menu(self, serial: str) -> None:
        """Press the menu button."""
        self.send_key(serial, KEYCODE_MENU)

    def volume_up(self, serial: str) -> None:
        """Increase device volume."""
        self.send_key(serial, KEYCODE_VOLUME_UP)

    def volume_down(self, serial: str) -> None:
        """Decrease device volume."""
        self.send_key(serial, KEYCODE_VOLUME_DOWN)

    def power(self, serial: str) -> None:
        """Press the power button."""
        self.send_key(serial, KEYCODE_POWER)

    def enter(self, serial: str) -> None:
        """Press enter."""
        self.send_key(serial, KEYCODE_ENTER)

    def delete(self, serial: str) -> None:
        """Press delete/backspace."""
        self.send_key(serial, KEYCODE_DEL)

    def forward_delete(self, serial: str) -> None:
        """Press forward delete."""
        self.send_key(serial, KEYCODE_FORWARD_DEL)

    def escape(self, serial: str) -> None:
        """Press escape."""
        self.send_key(serial, KEYCODE_ESCAPE)

    def space(self, serial: str) -> None:
        """Press space."""
        self.send_key(serial, KEYCODE_SPACE)

    def recent_apps(self, serial: str) -> None:
        """Open the recent-apps overview."""
        self.send_key(serial, KEYCODE_APP_SWITCH)

    def tap(self, serial: str, x: int, y: int) -> None:
        """Tap a screen coordinate."""
        self.adb.tap(serial, x, y)

    def swipe(
        self,
        serial: str,
        x1: int,
        y1: int,
        x2: int,
        y2: int,
        duration: int | None = None,
    ) -> None:
        """Swipe between two coordinates."""
        self.adb.swipe(serial, x1, y1, x2, y2, duration=duration)

    def scroll(
        self,
        serial: str,
        x: int,
        y: int,
        dx: int = 0,
        dy: int = 0,
        duration: int = 100,
    ) -> None:
        """Two-finger touchpad scroll gesture at coordinate (x, y) with delta (dx, dy).

        In natural scrolling:
        Positive dy (scrolling down) swipes upwards (content moves up).
        Positive dx (scrolling right) swipes leftwards (content moves left).
        """
        x2 = x - dx
        y2 = y - dy
        self.adb.swipe(serial, x, y, x2, y2, duration=duration)
