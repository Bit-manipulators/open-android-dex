"""Original scrcpy launcher wrapper.

Starts and manages a scrcpy process for screen mirroring and control.
"""

from __future__ import annotations

import shutil
import subprocess
from typing import List, Optional


class ScrcpyClient:
    """Wrapper around the scrcpy executable."""

    def __init__(self, scrcpy_path: Optional[str] = None) -> None:
        self.scrcpy_path = scrcpy_path or shutil.which("scrcpy") or "scrcpy"
        self._process: Optional[subprocess.Popen] = None

    def is_available(self) -> bool:
        """Return True if scrcpy can be found on PATH."""
        return shutil.which(self.scrcpy_path) is not None

    def is_running(self) -> bool:
        """Return True if a scrcpy process is currently active."""
        return self._process is not None and self._process.poll() is None

    def start(
        self,
        serial: Optional[str] = None,
        bitrate: str = "8M",
        max_size: int = 1024,
        fullscreen: bool = False,
        window_title: str = "Open Android Dex",
        always_on_top: bool = True,
        start_app: Optional[str] = None,
        stay_awake: bool = True,
        turn_screen_off: bool = False,
        new_display: Optional[str] = None,
    ) -> subprocess.Popen:
        """Launch scrcpy and return the process handle."""
        if self.is_running():
            return self._process

        args: List[str] = [
            self.scrcpy_path,
            "-b",
            bitrate,
            "--max-size",
            str(max_size),
            "--window-title",
            window_title,
        ]
        if always_on_top:
            args.append("--always-on-top")
        if stay_awake:
            args.append("--stay-awake")
        if fullscreen:
            args.append("--fullscreen")
        if turn_screen_off:
            args.append("--turn-screen-off")
        if new_display:
            args.append(f"--new-display={new_display}")
        if start_app:
            args.append(f"--start-app={start_app}")
        if serial:
            args.extend(["--serial", serial])

        self._process = subprocess.Popen(
            args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        return self._process

    def stop(self) -> None:
        """Terminate the running scrcpy process, if any."""
        if self._process is not None and self.is_running():
            self._process.terminate()
            try:
                self._process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self._process.kill()
        self._process = None
