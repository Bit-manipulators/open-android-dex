import time
from unittest.mock import MagicMock
from adb_client import AdbClient, Device
from scrcpy_client import ScrcpyClient
from boot_manager import BootManager, BootEvent


def test_boot_manager_success():
    adb = AdbClient()
    adb.is_available = MagicMock(return_value=True)
    adb.start_server = MagicMock(return_value=MagicMock(returncode=0))
    dev = Device(serial="dev1", state="device", model="Pixel 7")
    adb.list_devices = MagicMock(return_value=[dev])
    adb.get_property = MagicMock(side_effect=lambda s, prop: {
        "ro.product.model": "Pixel 7",
        "ro.product.brand": "Google",
        "ro.build.version.release": "14",
    }.get(prop, ""))

    scrcpy = ScrcpyClient()
    scrcpy.is_available = MagicMock(return_value=True)

    boot = BootManager(adb, scrcpy)
    events = []
    boot.start(None, lambda ev: events.append(ev))

    # Wait for thread to finish
    for _ in range(50):
        if not boot.running:
            break
        time.sleep(0.02)

    assert len(events) >= 5
    last = events[-1]
    assert last.is_error is False
    assert last.progress == 1.00
    assert last.device == dev
    assert last.device_info["model"] == "Pixel 7"
