import subprocess
from unittest.mock import MagicMock, patch
import pytest

from adb_client import AdbClient, Device


def test_device_dataclass():
    dev = Device(serial="abc123", state="device", model="Pixel 7")
    assert dev.serial == "abc123"
    assert dev.state == "device"
    assert dev.model == "Pixel 7"


def test_adb_is_available():
    with patch("shutil.which", return_value="/usr/bin/adb"):
        client = AdbClient()
        assert client.is_available() is True

    with patch("shutil.which", return_value=None):
        client = AdbClient(adb_path="nonexistent_adb")
        assert client.is_available() is False


def test_adb_list_devices_empty():
    client = AdbClient()
    mock_res = subprocess.CompletedProcess(
        args=["adb", "devices", "-l"],
        returncode=0,
        stdout="List of devices attached\n\n",
        stderr="",
    )
    with patch.object(client, "_run", return_value=mock_res):
        devs = client.list_devices()
        assert devs == []


def test_adb_list_devices_parsing():
    client = AdbClient()
    output = """List of devices attached
ZD222H7659             device usb:1-1 product:moto_g54_5G model:moto_g54_5G device:cancunf transport_id:1
emulator-5554          offline transport_id:2
unauth123              unauthorized usb:1-2 transport_id:3
"""
    mock_res = subprocess.CompletedProcess(
        args=["adb", "devices", "-l"],
        returncode=0,
        stdout=output,
        stderr="",
    )
    with patch.object(client, "_run", return_value=mock_res):
        devs = client.list_devices()
        assert len(devs) == 3

        assert devs[0].serial == "ZD222H7659"
        assert devs[0].state == "device"
        assert devs[0].model == "moto_g54_5G"

        assert devs[1].serial == "emulator-5554"
        assert devs[1].state == "offline"
        assert devs[1].model is None

        assert devs[2].serial == "unauth123"
        assert devs[2].state == "unauthorized"


def test_adb_keyevent_and_input():
    client = AdbClient()
    with patch.object(client, "_run") as mock_run:
        client.keyevent("dev1", 3)
        mock_run.assert_called_with(["shell", "input", "keyevent", "3"], serial="dev1")

        client.tap("dev1", 100, 200)
        mock_run.assert_called_with(["shell", "input", "tap", "100", "200"], serial="dev1")

        client.swipe("dev1", 10, 20, 30, 40)
        mock_run.assert_called_with(["shell", "input", "swipe", "10", "20", "30", "40"], serial="dev1")


def test_adb_get_launcher_activities():
    client = AdbClient()
    output = """priority=0 people=0 analyze=false
  com.android.chrome/com.google.android.apps.chrome.Main
  com.google.android.calculator/com.android.calculator2.Calculator
"""
    mock_res = subprocess.CompletedProcess(
        args=[],
        returncode=0,
        stdout=output,
        stderr="",
    )
    with patch.object(client, "_run", return_value=mock_res):
        activities = client.get_launcher_activities("dev1")
        assert activities == [
            ("com.android.chrome", "com.google.android.apps.chrome.Main"),
            ("com.google.android.calculator", "com.android.calculator2.Calculator"),
        ]


def test_adb_get_property():
    client = AdbClient()
    mock_res = subprocess.CompletedProcess(
        args=[],
        returncode=0,
        stdout="Pixel 7 Pro\n",
        stderr="",
    )
    with patch.object(client, "_run", return_value=mock_res):
        prop = client.get_property("dev1", "ro.product.model")
        assert prop == "Pixel 7 Pro"
