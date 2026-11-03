from unittest.mock import MagicMock
from adb_client import AdbClient
from volume_control import VolumeControl
from window_manager import WindowManager


def test_volume_control():
    adb = AdbClient()
    adb.keyevent = MagicMock()
    vol = VolumeControl(adb)

    vol.up("ser1")
    adb.keyevent.assert_called_with("ser1", 24)

    vol.down("ser1")
    adb.keyevent.assert_called_with("ser1", 25)

    vol.mute("ser1")
    adb.keyevent.assert_called_with("ser1", 164)


def test_window_manager():
    adb = AdbClient()
    adb.keyevent = MagicMock()
    adb.expand_notifications = MagicMock()
    wm = WindowManager(adb)

    wm.home("ser1")
    adb.keyevent.assert_called_with("ser1", 3)

    wm.recent_apps("ser1")
    adb.keyevent.assert_called_with("ser1", 187)

    wm.lock("ser1")
    adb.keyevent.assert_called_with("ser1", 26)

    wm.notifications("ser1")
    adb.expand_notifications.assert_called_with("ser1")
