from unittest.mock import MagicMock
from adb_client import AdbClient, Device
from device_manager import DeviceManager


def test_device_manager_detection():
    adb = AdbClient()
    mgr = DeviceManager(adb)

    # Case 1: No devices
    adb.list_devices = MagicMock(return_value=[])
    selected, needs_sel = mgr.auto_detect()
    assert selected is None
    assert needs_sel is True

    # Case 2: One online device
    dev1 = Device(serial="dev1", state="device", model="Pixel 7")
    adb.list_devices = MagicMock(return_value=[dev1])
    selected, needs_sel = mgr.auto_detect()
    assert selected == dev1
    assert needs_sel is False
    assert mgr.selected == dev1

    # Case 3: Multiple devices
    dev2 = Device(serial="dev2", state="device", model="Galaxy S23")
    adb.list_devices = MagicMock(return_value=[dev1, dev2])
    selected, needs_sel = mgr.auto_detect()
    assert selected is None
    assert needs_sel is True

    # Case 4: Explicit select
    chosen = mgr.select("dev2")
    assert chosen == dev2
    assert mgr.selected == dev2
