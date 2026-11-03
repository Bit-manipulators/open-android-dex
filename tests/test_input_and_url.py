from unittest.mock import MagicMock
from adb_client import AdbClient
import input_controller
from input_controller import InputController
from url_launcher import UrlLauncher


def test_input_controller_keycodes():
    assert input_controller.KEYCODE_HOME == 3
    assert input_controller.KEYCODE_BACK == 4
    assert input_controller.KEYCODE_POWER == 26
    assert input_controller.KEYCODE_ENTER == 66
    assert input_controller.KEYCODE_SPACE == 62
    assert input_controller.KEYCODE_APP_SWITCH == 187
    # Android keycode for DEL / Backspace is 67. Keycode 111 is ESCAPE.
    assert input_controller.KEYCODE_DEL == 67, f"KEYCODE_DEL is {input_controller.KEYCODE_DEL}, expected 67 (Backspace)"


def test_input_controller_delete():
    adb = AdbClient()
    adb.keyevent = MagicMock()
    inp = InputController(adb)
    inp.delete("ser1")
    # Must send KEYCODE_DEL (67), not KEYCODE_ESCAPE (111)
    adb.keyevent.assert_called_with("ser1", 67)


def test_url_launcher_intent_structure():
    adb = AdbClient()
    adb._run = MagicMock()
    launcher = UrlLauncher(adb)
    launcher.open("ser1", "https://google.com")

    # Verify that 'am start' is called with separate '-a' and '-d' arguments,
    # NOT a combined string '-a "android.intent.action.VIEW -d https://google.com"'
    adb._run.assert_called_once()
    called_args = adb._run.call_args[0][0]
    # Check that -d is an independent argument passed to am start
    assert "-d" in called_args, f"'-d' flag not separated in args: {called_args}"
    assert "https://google.com" in called_args, f"URL not separated in args: {called_args}"
