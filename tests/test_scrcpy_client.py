import subprocess
from unittest.mock import MagicMock, patch

from scrcpy_client import ScrcpyClient


def test_scrcpy_is_available():
    with patch("shutil.which", return_value="/usr/bin/scrcpy"):
        client = ScrcpyClient()
        assert client.is_available() is True

    with patch("shutil.which", return_value=None):
        client = ScrcpyClient(scrcpy_path="missing_scrcpy")
        assert client.is_available() is False


def test_scrcpy_start_command_line():
    client = ScrcpyClient(scrcpy_path="/usr/bin/scrcpy")
    mock_proc = MagicMock(spec=subprocess.Popen)
    mock_proc.poll.return_value = None

    with patch("subprocess.Popen", return_value=mock_proc) as mock_popen:
        proc = client.start(
            serial="device123",
            bitrate="4M",
            max_size=1920,
            fullscreen=True,
            window_title="DeX Test",
            always_on_top=True,
            start_app="com.android.chrome",
            stay_awake=True,
            turn_screen_off=True,
            new_display="1920x1080/240",
        )

        assert proc == mock_proc
        assert client.is_running() is True

        called_args = mock_popen.call_args[0][0]
        assert called_args == [
            "/usr/bin/scrcpy",
            "-b",
            "4M",
            "--max-size",
            "1920",
            "--window-title",
            "DeX Test",
            "--always-on-top",
            "--stay-awake",
            "--fullscreen",
            "--turn-screen-off",
            "--new-display=1920x1080/240",
            "--no-vd-system-decorations",
            "--start-app=com.android.chrome",
            "--serial",
            "device123",
        ]


def test_scrcpy_stop():
    client = ScrcpyClient()
    mock_proc = MagicMock(spec=subprocess.Popen)
    mock_proc.poll.return_value = None
    client._process = mock_proc

    client.stop()
    mock_proc.terminate.assert_called_once()
    mock_proc.wait.assert_called_once_with(timeout=5)
    assert client.is_running() is False
