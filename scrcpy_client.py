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
        window_title: str = "Android Dex",
    ) -> subprocess.Popen:
        """Launch scrcpy and return the process handle."""
        if self.is_running():
            raise RuntimeError("scrcpy is already running")

        args: List[str] = [
            self.scrcpy_path,
            "--bit-rate",
            bitrate,
            "--max-size",
            str(max_size),
            "--window-title",
            window_title,
        ]
        if fullscreen:
            args.append("--fullscreen")
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
